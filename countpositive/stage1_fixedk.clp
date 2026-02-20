(*
CountPositive(A: array, n: size)
    cost := 0
    for i = 0 to n-1:
        if A[i] > 0: cost++
    return cost
*)

(*
==========================================================================
STAGE 1: Fixed-k Cell Morphing — The Baseline (No PickK, No Prophecy)
==========================================================================

PROPERTY: Relative execution cost.
  If a1[k] = a2[k] at some position k,
  then cost1 - cost2 <= n - 1.

  We track ONE distinguished cell k, chosen at initialization, never moved.
  That one position is cost-neutral (equal values => same branch).
  The remaining n-1 positions are unknown => worst case +1 each.

LIMITATION: The bound is n-1, regardless of how many equal positions exist.
  Even if a1[i] = a2[i] for ALL i, fixed-k only "sees" one of them.

  Test:  c > n - 1  =>  UNSAT  (can prove this)
         c > n - 2  =>  SAT    (cannot prove anything tighter!)

  This motivates PickK: dynamically discover MULTIPLE equal positions.

State: i, n, k, ak1, ak2, bk, c  (7 Inv variables)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, n, k, ak1, ak2, bk, c) :-
  i = 0, n > 0,
  0 <= k, k < n,
  (ak1 = ak2 and bk = 1) or (ak1 <> ak2 and bk = 0),
  c = 0.


(******************************************************************************)
(* TRANSITION — fixed k, no PickK                                             *)
(*                                                                            *)
(* HIT equal (i=k, bk=1): a1[k]=a2[k], same branch, cost neutral            *)
(* HIT unequal (i=k, bk=0): values differ, worst case +1                    *)
(* MISS (i<>k): unknown, worst case +1                                       *)
(******************************************************************************)

Inv(i', n, k, ak1, ak2, bk, c') :-
  Inv(i, n, k, ak1, ak2, bk, c),
  i < n,
  (
    (* HIT equal: cost neutral *)
    (i = k and bk = 1 and c' = c)
    or
    (* HIT unequal: worst case +1 *)
    (i = k and bk = 0 and c' = c + 1)
    or
    (* MISS: worst case +1 *)
    (i <> k and c' = c + 1)
  ),
  i' = i + 1.


(******************************************************************************)
(* GOALS — switch between these to demonstrate the limitation                 *)
(******************************************************************************)

(* Goal A: c > n - 1 — UNSAT (fixed-k CAN prove this) *)
c > n - 1 :-
  Inv(i, n, k, ak1, ak2, bk, c),
  n <= i.

(* Goal B: c > n - 2 — SAT (fixed-k CANNOT prove this)
c > n - 2 :-
  Inv(i, n, k, ak1, ak2, bk, c),
  n <= i.
*)
