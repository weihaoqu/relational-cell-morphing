(*
CountPositive(A: array, n: size)
    cost := 0
    for i = 0 to n-1:
        if A[i] > 0: cost++
    return cost
*)

(*
==========================================================================
STAGE 2a: PickK + Prophecy — Discovering Multiple Equal Positions
==========================================================================

PROPERTY: Relative execution cost under replace metric.
  If A1 and A2 share at least d0 equal positions,
  then cost1 - cost2 <= n - d0.

WHAT CHANGED FROM STAGE 1:
  Stage 1 (fixed k):   bound = n - 1     (one tracked position)
  Stage 2a (PickK):    bound = n - d0    (d0 tracked positions)

NEW INGREDIENTS:
  1. PickK: functional predicate that re-focuses the distinguished cell
     - Searching (d < d0): kp = i  (inspect current position)
     - Settled  (d >= d0): kp = k  (keep current cell)

  2. Prophecy d0: universally quantified — "at least d0 positions equal"
     PCSAT proves the bound for ALL d0 >= 0 simultaneously.

  3. Counter d: how many equal positions discovered so far
     When d >= d0 at termination, prophecy is fulfilled.

  4. Wit: witness predicate providing fresh cell values after refocus
     PCSAT synthesizes its interpretation.

RESULTS:
  c > n - d0  =>  UNSAT in 2.5 seconds
  (vs Stage 1: n-1 in 4.5s, cannot prove n-2)

State: i, n, k, ak1, ak2, bk, d, d0, c  (9 Inv variables)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, n, k, ak1, ak2, bk, d, d0, c) :-
  i = 0, n > 0,
  0 <= k, k < n,
  (ak1 = ak2 and bk = 1) or (ak1 <> ak2 and bk = 0),
  d = 0,
  d0 >= 0,
  c = 0.


(******************************************************************************)
(* TRANSITION                                                                 *)
(*                                                                            *)
(* HIT equal (i=kp, bkp=1): same branch, c'=c, d'=d+1 (bank it!)           *)
(* HIT unequal (i=kp, bkp=0): may disagree, c'=c+1, d'=d                   *)
(* MISS (i<>kp): unknown, c'=c+1, d'=d                                      *)
(******************************************************************************)

Inv(i', n, kp, ak1', ak2', bk', d', d0, c') :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  i < n,
  PickK(i, n, k, ak1, ak2, bk, d, d0, c, kp),
  Wit(i, n, kp, ak1p, ak2p, bkp, d, d0, c),
  (
    (i = kp and bkp = 1
     and c' = c
     and d' = d + 1)
    or
    (i = kp and bkp = 0
     and c' = c + 1
     and d' = d)
    or
    (i <> kp
     and c' = c + 1
     and d' = d)
  ),
  i' = i + 1,
  ak1' = ak1p,
  ak2' = ak2p,
  (ak1' = ak2' and bk' = 1 or ak1' <> ak2' and bk' = 0).


(******************************************************************************)
(* WITNESS                                                                    *)
(******************************************************************************)

Wit(i, n, k, ak1, ak2, bk, d, d0, c) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  i < n.


(******************************************************************************)
(* PICKK                                                                      *)
(******************************************************************************)

PickK(i, n, k, ak1, ak2, bk, d, d0, c, i) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  i < n, d < d0.

PickK(i, n, k, ak1, ak2, bk, d, d0, c, k) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  d >= d0.


(******************************************************************************)
(* GOAL                                                                       *)
(******************************************************************************)

c > n - d0 :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  n <= i,
  d >= d0.
