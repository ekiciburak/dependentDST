From DST Require Import sort.unscoped sort.sort sort.beta sort.sortcheck processes.process.
From Paco Require Import paco.
Require Import String List ZArith Relations Nat.
Local Open Scope string_scope.
Import ListNotations.
Require Import Setoid Morphisms.

Inductive mqueue: Type := 
  | nilq: mqueue
  | mesq: participant -> label -> sort -> mqueue -> mqueue.

Fixpoint conq (m1 m2: mqueue): mqueue :=
  match m1 with
    | nilq         => m2
    | mesq p l v q => mesq p l v (conq q m2)
  end.

Inductive session: Type :=
  | sind: participant -> process -> mqueue -> session
  | spar: session -> session -> session.

Notation "p '<--' P '|' h" :=  (sind p P h) (at level 50, no associativity).
Notation "s1 '|||' s2" :=  (spar s1 s2) (at level 50, no associativity): type_scope.

Inductive qcong: relation mqueue :=
  | qcons : forall {A B: Type} q1 q2 l1 l2 v1 v2 h1 h2, q1 <> q2 -> 
                                             qcong (conq h1 (conq (mesq q1 l1 v1 nilq) (conq (mesq q2 l2 v2 nilq) h2)))
                                                   (conq h1 (conq (mesq q2 l2 v2 nilq) (conq (mesq q1 l1 v1 nilq) h2)))
  | qnilL : forall h, qcong (conq nilq h) h
  | qnilR : forall h, qcong h (conq nilq h)
  | qassoc: forall h1 h2 h3, qcong (conq h1 (conq h2 h3)) (conq (conq h1 h2) h3).

Definition subst_expr (p: process) (l: label) (e: sort): process :=
  match p with
    | ps_receive s0 s1  => 
      let fix next lst :=
      match lst with
        | (pair (pair lbl (svar n)) P)::xs => 
          if String.eqb lbl l then
          let fix rec P :=
            match P with
              | ps_send pt l e1 P => ps_send pt l (subst_sort (e .: svar) e1) (rec P)
              | ps_ite e1 P Q     => ps_ite (subst_sort (e .: svar) e1) (rec P) (rec Q)
              | ps_receive s2 s3  => ps_receive s2 ((list_map (prod_map (prod_map (fun x => x) (fun x => x)) (rec))) s3)
              | ps_mu P e1        => ps_mu (rec P) (subst_sort (e .: svar) e1)
              | _                 => P
            end
          in rec P
          else next xs
       | (pair (pair lbl _) P)::xs => next xs
       | _                         => p
     end
     in next s1
    | _                            => p
  end.

Fixpoint inclevel (m: nat) (e: sort): sort :=
    match e with
      | svar n        => if Nat.leb m n then svar m else e
      | spair e1 e2   => spair (inclevel m e1) (inclevel m e2)
      | splus e1 e2   => splus (inclevel m e1) (inclevel m e2)
      | sminus e1 e2  => sminus (inclevel m e1) (inclevel m e2)
      | sgt e1 e2     => sgt (inclevel m e1) (inclevel m e2)
      | sproj1 e1     => sproj1 (inclevel m e1)
      | slambda e1 e2 => slambda e1 (inclevel (S m) e2)
      | spi e1 e2     => spi e1 (inclevel (S m) e2)
      | _             => e
    end.

Eval compute in (inclevel 0 (slambda sint (slambda sint (splus (svar 1) (svar 0))))).

Eval compute in (inclevel 0 (svar 0)).

Fixpoint inclevel_proc (m: nat) (s: process): process :=
  match s with
    | ps_mu p e        => ps_mu (inclevel_proc m p) (inclevel m e)
    | ps_send a l e1 p => ps_send a l (inclevel m e1) (inclevel_proc m p)
    | ps_receive s0 s1 => ps_receive ((fun x => x) s0) ((list_map (prod_map (prod_map (fun x => x) ((inclevel (S m))(* (ren_sort (unscoped.shift)) *))) (inclevel_proc (S m)))) s1)
    | ps_ite  s0 s1 s2 => ps_ite ((inclevel m) s0) ((inclevel_proc m) s1) ((inclevel_proc m) s2)
    | _                => s
  end.

Definition subst_sort2 (e: sort): sort :=
  let fix rec P :=
    match P with
      | spair e1 e2   => spair e1 (subst_sort ((e1 .: svar)) e2)
      | sproj1 e1     => sproj1 (rec e1)
      | slambda e1 e2 => slambda e1 (rec e2)
      | _             => P
    end
  in rec e.

Fixpoint inclevelA (m: nat) (k: nat) (e: sort): sort :=
  match e with
    | svar n        => if ltb m (k+n) then (svar (k+n)) else svar m
    | spair e1 e2   => spair (inclevelA m k e1) (inclevelA m k e2)
    | splus e1 e2   => splus (inclevelA m k e1) (inclevelA m k e2)
    | sminus e1 e2  => sminus (inclevelA m k e1) (inclevelA m k e2)
    | sgt e1 e2     => sgt (inclevelA m k e1) (inclevelA m k e2)
    | sproj1 e1     => sproj1 (inclevelA m k e1)
    | slambda e1 e2 => slambda (inclevelA (S m) k e1) (inclevelA (S m) k e2)
    | spi e1 e2     => spi (inclevelA (S m) k e1) (inclevelA (S m) k e2)
    | _             => e
  end.

Fixpoint inclevel_procA (m: nat) (n: nat) (s: process): process :=
  match s with
    | ps_mu p e        => ps_mu (inclevel_procA m n p) e
    | ps_send a l e1 p => ps_send a l (inclevelA m n e1) (inclevel_procA m n p)
    | ps_receive s0 s1 => ps_receive ((fun x => x) s0) ((list_map (prod_map (prod_map (fun x => x) ((fun x => x)(* (ren_sort (unscoped.shift)) *))) (inclevel_procA m n))) s1)
    | ps_ite  s0 s1 s2 => ps_ite ((inclevelA m n) s0) ((inclevel_procA m n) s1) ((inclevel_procA m n) s2)
    | _                => s
  end.

Fixpoint subst_proc_sort (m: nat) (n: nat) (e: sort) (p: process) : process :=
  match p with
    | ps_send pt l e1 P => (ps_send pt l (subst_sort (((beta e) .: svar)) e1) (subst_proc_sort m n e P))
    | ps_ite e1 P Q     => (ps_ite (subst_sort ((beta e) .: svar) e1) (subst_proc_sort m n e P) (subst_proc_sort m n e Q))
    | ps_receive s2 s3  => inclevel_procA m n (ps_receive s2 ((list_map (prod_map (prod_map (fun x => x) (subst_sort (((beta e) .: svar)) ) (* (ren_sort (unscoped.shift) ) *))(fun x => x))) s3))
    | ps_mu P e1        => (ps_mu (subst_proc_sort m (S n) e P) (subst_sort (((beta e) .: svar)) e1))
    | _                 => p
  end.

Fixpoint unfold_muP (m: nat) (n: nat) (s: process): process :=
  match s with
    | ps_mu p e        => subst_process (e .: svar) ((ps_mu (subst_proc_sort m (S n) e p) e) .: ps_var) p
    | ps_send a l e1 p => ps_send a l e1 (unfold_muP m n p)
    | ps_receive s0 s1 => ps_receive s0 ((list_map (prod_map (prod_map (fun x => x) ((fun x => x) )) (unfold_muP m n))) s1)
    | ps_ite  s0 s1 s2 => ps_ite s0 ((unfold_muP m n) s1) ((unfold_muP m n) s2)
    | _                => s
  end.

Fixpoint unfold_muPn (n: nat) (s: process): process :=
  match n with
    | O   => s
    | S k => unfold_muPn k (unfold_muP 0 1 s)
  end.

Definition rec_game: process :=
  ps_receive "Carol" (cons (pair (pair "l1" (svar 0)) 
             (ps_mu (ps_send "Carol" "l2" (svar 0) 
                    (ps_receive "Carol" (cons (pair (pair "correct" (svar 0)) 
                        (ps_send "Alice" "l3" (slambda (spi sint sint) (slambda sint (splus (svar 1) (splus (svar 3) (svar 1))))) ps_end))
                                        (cons (pair (pair "wrong" (svar 0)) (ps_var 0)) nil))))
                    (sproj1 (spair (sminus (svar 0) (sci 1)) (sgt (sminus (svar 0) (sci 1)) (sci 0)))))) nil).

Print rec_game.
(* 
Let mm := Eval compute in (unfold_muPn 5 rec_game).

Print mm.

Eval compute in (subst_expr mm "l1" (sci 15)).

Definition rec_game2: process :=
             (ps_mu (ps_send "Carol" "l2" (svar 0) 
                    (ps_receive "Carol" (cons (pair (pair "correct" (svar 0)) (ps_send "Alice" "l3" (slambda sint (splus (svar 1) (svar 2))) ps_end))
                                        (cons (pair (pair "wrong" (svar 0)) (ps_var 0)) nil))))
                    (sproj1 (spair (sminus (svar 0) (sci 1)) (sgt (sminus (svar 0) (sci 1)) (sci 0))))).

Let mm2 := Eval compute in (unfold_muPn 4 rec_game2).

Print mm2.
 *)
Inductive pcong: relation process :=
  | pmuUnf: forall {A: Type} p e, pcong (ps_mu p e) (unfold_muP 0 0 p).

Inductive scong: relation session :=
  | sann   : forall p M, scong ((p <-- ps_end | nilq) ||| M) M
  | scomm  : forall M1 M2, scong (M1 ||| M2) (M2 ||| M1)
  | sassoc : forall M1 M2 M3, scong (M1 ||| M2 ||| M3) (M1 ||| (M2 ||| M3))
(*| sassoc2: forall M1 M2 M3, scong (M1 ||| M2 ||| M3) ((M1 ||| M2) ||| M3) *)
  | sassoc2: forall M1 M2 M3, scong (M1 ||| M2 ||| M3) (M1 ||| (M3 ||| M2))
  | scongl : forall p P Q h1 h2 M, pcong P Q -> qcong h1 h2 -> 
                                   scong ((p <-- P | h1) ||| M) ((p <-- Q | h2) ||| M).

Inductive beta: relation session :=
  | r_send : forall p q l e P hp M n, 
                                beta ((p <-- (ps_send q l e P) | hp) ||| M) 
                                     ((p <-- P | conq hp (mesq q l (betan n e) nilq)) ||| M)
  | r_rcv   : forall p q l xs v Q hp hq M,
                                beta ((p <-- ps_receive q xs | hp) ||| (q <-- Q | conq (mesq p l v nilq) hq) ||| M)
                                     ((p <-- subst_expr (ps_receive q xs) l v | hp)  ||| (q <-- Q | hq) ||| M)
  | r_cond_t: forall p P Q h M, beta ((p <-- ps_ite (scb true) P Q | h) ||| M) ((p <-- P | h) ||| M)
  | r_cond_f: forall p P Q h M, beta ((p <-- ps_ite (scb false) P Q | h) ||| M) ((p <-- Q | h) ||| M)
  | r_struct: forall M1 M1' M2 M2', scong M1 M1' -> scong M2' M2 -> beta M1' M2' -> beta M1 M2.

Declare Instance Equivalence_beta : Equivalence beta.
Declare Instance Equivalence_scong : Equivalence scong.

Inductive multi {X : Type} (R : relation X) : relation X :=
  | multi_refl : forall (x : X), multi R x x
  | multi_step : forall (x y z : X), R x y -> multi R y z -> multi R x z.

Definition beta_multistep := multi beta.

#[global]
Declare Instance RW_scong3: Proper (scong ==> scong ==> impl) beta.
#[global]
Declare Instance RW_scong4: Proper (scong ==> scong ==> impl) beta_multistep.

Local Open Scope string_scope.

Definition M1 (p q: participant) (l: label) : session :=
  (p <-- ps_receive q (cons (pair (pair l (svar 0)) ps_end) nil) | nilq) ||| (q <-- ps_send p l (sci 42) ps_end | nilq).

Definition M1' (p q: participant) (l: label): session :=
  (p <-- ps_end | nilq) ||| (q <-- ps_end | nilq).

Example redM1: forall (p q: participant) (l: label), beta_multistep (M1 p q l) (M1' p q l).
Proof. intros.
       unfold beta_multistep, M1, M1'.
       setoid_rewrite scomm.
       apply multi_step with (y := 
         ((q <-- ps_end | (conq nilq (mesq p l (sci 42) nilq))) ||| 
          (p <-- ps_receive q (cons (pair (pair l (svar 0)) ps_end) nil) | nilq))).
       apply r_send with (n := 1). simpl.
       setoid_rewrite scomm.
       apply multi_step with (y := 
         (((p <-- subst_expr (ps_receive q (cons (pair (pair l (svar 0)) ps_end) nil)) l (sci 42) | nilq) ||| 
          (q <-- ps_end | nilq)))).
       specialize (r_rcv p q l (cons (pair (pair l (svar 0)) ps_end) nil)
                         (sci 42) (ps_end) nilq nilq
                         (p <-- ps_end | nilq)
       ); intro HR.
       setoid_rewrite scomm in HR.
       setoid_rewrite sann in HR.
       exact HR.

       simpl.
       rewrite String.eqb_refl.
       apply multi_refl.
Qed.

(* Example 2 in "A Very Gentle Introduction to Multiparty Session Types" *)
Definition PAlice: process := 
  ps_send "Bob" "l1" (sci 50) (ps_receive "Carol" (cons (pair (pair "l3" (svar 0)) ps_end) nil)).

Definition PBob: process :=
  ps_receive "Alice" (cons (pair (pair "l1" (svar 0)) (ps_send "Carol" "l2" (sci 100) ps_end))
                     (cons (pair (pair "l4" (svar 0)) (ps_send "Carol" "l2" (sci 2) ps_end)) nil)).

Definition PCarol: process :=
  ps_receive "Bob" (cons (pair (pair "l2" (svar 0)) (ps_send "Alice" "l3" (splus (svar 0) (sci 1)) ps_end)) nil).

Definition MS: session := ("Alice" <-- PAlice | nilq) ||| ("Bob" <-- PBob | nilq) ||| ("Carol" <-- PCarol | nilq).

Definition MS': session := ("Alice" <-- ps_end | nilq) ||| ("Bob" <-- ps_end | nilq) ||| ("Carol" <-- ps_end | nilq).

Example redMS: beta_multistep MS MS'.
Proof. unfold beta_multistep, MS, MS', PAlice.
       apply multi_step with
       (y := (("Alice" <-- (ps_receive "Carol" (cons (pair (pair "l3" (svar 0)) ps_end) nil)) | conq nilq (mesq "Bob" "l1" (sci 50) nilq)) ||| 
             ("Bob" <-- PBob | nilq)) ||| ("Carol" <-- PCarol | nilq)).
       setoid_rewrite sassoc.
       apply r_send with (n := 1). simpl.

       setoid_rewrite sassoc.
       setoid_rewrite scomm.
       setoid_rewrite sassoc2.
       setoid_rewrite <- sassoc.

       unfold PBob at 1.

       apply multi_step with
       (y := ("Bob" <-- subst_expr (PBob) "l1" (sci 50) | nilq)
              ||| ("Alice" <-- (ps_receive "Carol" (cons (pair (pair "l3" (svar 0)) ps_end) nil)) | nilq)
              ||| ("Carol" <-- PCarol | nilq)).
       apply r_rcv.
       unfold PBob at 1.
       simpl.
(*        unfold PCarol. *)

       setoid_rewrite sassoc2.
       setoid_rewrite <- sassoc.

       apply multi_step with
       (y := ((("Bob" <-- ps_end | conq nilq (mesq "Carol" "l2" (sci 100) nilq) )
               ||| ("Carol" <-- (ps_receive "Bob" (cons (pair (pair "l2" (svar 0)) (ps_send "Alice" "l3" (splus (svar 0) (sci 1)) ps_end)) nil)) | nilq))
               ||| ("Alice" <-- (ps_receive "Carol" (cons (pair (pair "l3" (svar 0)) ps_end) nil)) | nilq))).
       setoid_rewrite sassoc.
       apply r_send with (n := 1). simpl.

       setoid_rewrite sassoc.
       setoid_rewrite scomm.
       setoid_rewrite sassoc2.
       setoid_rewrite <- sassoc.

       apply multi_step with
       (y := ((("Carol" <-- subst_expr (ps_receive "Bob" (cons (pair (pair "l2" (svar 0)) (ps_send "Alice" "l3" (splus (svar 0) (sci 1)) ps_end)) nil)) "l2" (sci 100) | nilq)
                 ||| ("Bob" <-- ps_end | nilq))
                 ||| ("Alice" <-- (ps_receive "Carol" (cons (pair (pair "l3" (svar 0)) ps_end) nil)) | nilq))).
       apply r_rcv. simpl.

       setoid_rewrite sassoc2.
       setoid_rewrite <- sassoc.

       apply multi_step with
       (y := ((("Carol" <-- ps_end | conq nilq (mesq "Alice" "l3" (sci 101) nilq) )
               ||| ("Alice" <-- (ps_receive "Carol" (cons (pair (pair "l3" (svar 0)) ps_end) nil)) | nilq))
               ||| ("Bob" <-- ps_end | nilq))).
       setoid_rewrite sassoc. simpl.
       apply r_send with (n := 1). simpl.

       setoid_rewrite sassoc.
       setoid_rewrite scomm.
       setoid_rewrite sassoc2.
       setoid_rewrite <- sassoc.

      apply multi_step with
      (y := ((("Alice" <-- subst_expr (ps_receive "Carol" (cons (pair (pair "l3" (svar 0)) ps_end) nil))
                                      "l3" (sci 101) | nilq) 
             ||| ("Carol" <-- ps_end | nilq))
             ||| ("Bob" <-- ps_end | nilq))).
      apply r_rcv. simpl.

      apply multi_refl.
Qed.

