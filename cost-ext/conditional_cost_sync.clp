(*
ConditionalCost(A: array, n: size)
    cost := 0
    for i = 0 to n-1:
        if A[i] > 0:
            cost += A[i]
    return cost
*)

(*
==========================================================================
Execution cost where cost DEPENDS ON ARRAY VALUES
==========================================================================

PROPERTY: Mixed metric (replace + Linf)
  Precondition:
    - At least d0 positions have a1[i] = a2[i]    (replace metric)
    - ALL positions have |a1[i] - a2[i]| <= eps    (Linf metric)
  Postcondition: cost1 - cost2 <= (n - d0) * eps

  where cost = sum of A[i] for all i where A[i] > 0.
  This is EXECUTION COST: the total work done by the conditional branch.

WHY THIS IS THE KEY EXAMPLE:
  1. The cost is genuinely VALUE-DEPENDENT: cost += A[i], not cost++.
     Countpositive has +-1 per step — pure counting suffices.
     Here, each step contributes up to |a1[i]|, which is unbounded
     without the eps precondition.

  2. PickK + prophecy alone (no eps) CANNOT bound this:
     At unequal positions, |a1[i] - a2[i]| is unknown.
     cost1 - cost2 could be arbitrarily large.
     The bound n-d0 is meaningless (cost is not +-1).

  3. PickK + prophecy + eps gives: (n-d0) * eps.
     d0 equal positions contribute 0 (same value, same branch).
     n-d0 unequal positions contribute at most eps each.
     (Because max(x,0) is 1-Lipschitz: |max(a1,0)-max(a2,0)| <= |a1-a2| <= eps)

  This is the ONLY example that requires ALL THREE ingredients.

COST DIFFERENCE ANALYSIS per step:
  Let f(x) = max(x, 0). Then cost contribution = f(A[i]).
  c' - c = f(a1[i]) - f(a2[i]).

  Case 1: a1[i]=a2[i] (equal). f(a1)=f(a2). Change = 0.
  Case 2: both > 0. Change = a1[i]-a2[i]. |change| <= eps.
  Case 3: both <= 0. f(a1)=f(a2)=0. Change = 0.
  Case 4: a1[i]>0, a2[i]<=0. a1[i] <= a2[i]+eps <= eps.
          Change = a1[i]-0 = a1[i] <= eps.
  Case 5: a1[i]<=0, a2[i]>0. Symmetric. |change| <= eps.

  All cases: |c' - c| <= eps. Equal positions: c' = c.

State: i, n, k, ak1, ak2, bk, d, d0, c, eps  (10 Inv variables)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, n, k, ak1, ak2, bk, d, d0, c, eps) :-
  i = 0, n > 0,
  0 <= k, k < n,
  eps >= 0,
  (* Input cell: equal or eps-close *)
  (ak1 = ak2 and bk = 1) or
  (ak1 <> ak2 and bk = 0 and ak2 - ak1 <= eps and ak1 - ak2 <= eps),
  d = 0,
  d0 >= 0, d0 <= n,
  c = 0.


(******************************************************************************)
(* TRANSITION                                                                 *)
(*                                                                            *)
(* cost_contribution(run_j) = max(A_j[i], 0)  (add A[i] only if positive)   *)
(* c = cost1 - cost2                                                          *)
(*                                                                            *)
(* HIT equal (bkp=1): a1[i]=a2[i] => same contribution => c'=c              *)
(* HIT unequal (bkp=0): |ak1p-ak2p|<=eps => |contribution diff|<=eps        *)
(* MISS: universal |a1[i]-a2[i]|<=eps => |contribution diff|<=eps            *)
(******************************************************************************)

Inv(i', n, kp, ak1', ak2', bk', d', d0, c', eps) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c, eps),
  i < n,
  PickK(i, n, k, ak1, ak2, bk, d, d0, c, eps, kp),
  Wit(i, n, kp, ak1p, ak2p, bkp, d, d0, c, eps),
  (
    (* HIT equal: identical values => identical cost contribution *)
    (i = kp and bkp = 1
     and c' = c
     and d' = d + 1)
    or
    (* HIT unequal: |ak1p-ak2p| <= eps *)
    (* |max(ak1p,0) - max(ak2p,0)| <= |ak1p-ak2p| <= eps *)
    (i = kp and bkp = 0
     and c' <= c + eps and c' >= c - eps
     and d' = d)
    or
    (* MISS: universal precondition |a1[i]-a2[i]| <= eps *)
    (* same Lipschitz argument gives |contribution diff| <= eps *)
    (i <> kp
     and c' <= c + eps and c' >= c - eps
     and d' = d)
  ),
  i' = i + 1,
  ak1' = ak1p,
  ak2' = ak2p,
  (ak1' = ak2' and bk' = 1) or
  (ak1' <> ak2' and bk' = 0 and ak2' - ak1' <= eps and ak1' - ak2' <= eps).


(******************************************************************************)
(* WITNESS                                                                    *)
(******************************************************************************)

Wit(i, n, k, ak1, ak2, bk, d, d0, c, eps) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c, eps),
  i < n.


(******************************************************************************)
(* PICKK                                                                      *)
(******************************************************************************)

PickK(i, n, k, ak1, ak2, bk, d, d0, c, eps, i) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c, eps),
  i < n, d < d0.

PickK(i, n, k, ak1, ak2, bk, d, d0, c, eps, k) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c, eps),
  d >= d0.


(******************************************************************************)
(* GOAL: c > (n - d0) * eps — UNSAT = verified                                *)
(******************************************************************************)

c > (n - d0) * eps :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c, eps),
  n <= i,
  d >= d0.
(*
unsat,15
docker run -it -v  coar:latest bash -c   0.02s user 0.02s system 0% cpu 11.489 total
*)