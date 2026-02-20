(*
ExpensiveBranch(A: array, n: size)
    cost := 0
    for i = 0 to n-1:
        if A[i] > 0:
            cost += 2        (* expensive operation, e.g. two array writes *)
    return cost
*)

(*
==========================================================================
Execution cost with NON-UNIT cost per branch
==========================================================================

PROPERTY: Relative execution cost under replace metric.
  If A1 and A2 share at least d0 equal positions,
  then |cost1 - cost2| <= 2 * (n - d0).

WHY THIS EXAMPLE:
  In countpositive, the branch costs +1. The bound is n - d0.
  Here, the branch costs +2. The bound is 2 * (n - d0).

  This shows the framework handles different cost MAGNITUDES.
  The coefficient 2 appears in the bound because each disagreeing
  position can change the cost difference by up to 2.

COST DIFFERENCE ANALYSIS per step:
  Run 1: cost1 += 2 if a1[i] > 0, else cost1 += 0
  Run 2: cost2 += 2 if a2[i] > 0, else cost2 += 0

  Equal (a1[i]=a2[i]): same branch => c' = c.
  Unequal, both positive: both += 2 => c' = c.
  Unequal, both non-positive: both += 0 => c' = c.
  Unequal, one positive, one not: |c' - c| = 2.

  Only when branches DISAGREE does cost change, and the change is +-2.

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
(* HIT equal (bkp=1): same branch => c' = c, d' = d + 1                     *)
(* HIT unequal (bkp=0): branches may disagree => |c'-c| <= 2               *)
(* MISS: unknown => |c'-c| <= 2                                              *)
(******************************************************************************)

Inv(i', n, kp, ak1', ak2', bk', d', d0, c') :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  i < n,
  PickK(i, n, k, ak1, ak2, bk, d, d0, c, kp),
  Wit(i, n, kp, ak1p, ak2p, bkp, d, d0, c),
  (
    (* HIT equal: same value => same branch => cost neutral *)
    (i = kp and bkp = 1
     and c' = c
     and d' = d + 1)
    or
    (* HIT unequal: branches may disagree, cost changes by at most 2 *)
    (i = kp and bkp = 0
     and c' <= c + 2 and c' >= c - 2
     and d' = d)
    or
    (* MISS: unknown, worst case +-2 *)
    (i <> kp
     and c' <= c + 2 and c' >= c - 2
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
(* GOAL: c > 2 * (n - d0) — UNSAT = verified                                 *)
(******************************************************************************)

c > 2 * (n - d0) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  n <= i,
  d >= d0.
