(*
ConditionalCost(A: array, n: size)
    cost := 0
    for i = 0 to n-1:
        if A[i] > 0:
            cost += A[i]        (* work proportional to value *)
    return cost
*)

(*
==========================================================================
STAGE 2b: PickK + Prophecy + Epsilon — Value-Dependent Execution Cost
==========================================================================

PROPERTY: Mixed metric (replace + Linf)
  Precondition:
    - At least d0 positions have a1[i] = a2[i]    (replace metric)
    - ALL positions have |a1[i] - a2[i]| <= eps    (Linf metric)
  Postcondition: cost1 - cost2 <= (n - d0) * eps

  where cost = total work done: sum of A[i] over positive entries.

WHAT CHANGED FROM STAGE 2a:
  Stage 2a: cost is +-1 per step (just counts branches)
            Pure counting suffices — doesnt need cell values
  Stage 2b: cost depends on VALUES (cost += A[i])
            Cell morphing is GENUINELY NEEDED for the eps bound

WHY EACH INGREDIENT IS NECESSARY:
  Without PickK:    fixed k, bound = (n-1)*eps      (one equal position)
  Without prophecy: cannot parameterize by d0
  Without epsilon:  cannot bound value-dependent cost contribution
  ALL THREE:        bound = (n-d0)*eps               (tightest)

COST DIFFERENCE ANALYSIS per step:
  Each run contributes max(A[i], 0) to cost.
  max(x,0) is 1-Lipschitz: |max(a,0) - max(b,0)| <= |a - b|.
  So when |a1[i] - a2[i]| <= eps, |contribution diff| <= eps.
  When a1[i] = a2[i], contribution diff = 0.

  d0 equal positions: 0 contribution to cost diff
  n-d0 other positions: at most eps each
  Total: cost1 - cost2 <= (n - d0) * eps

State: i, n, k, ak1, ak2, bk, d, d0, c, eps  (10 Inv variables)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, n, k, ak1, ak2, bk, d, d0, c, eps) :-
  i = 0, n > 0,
  0 <= k, k < n,
  eps >= 0,
  (ak1 = ak2 and bk = 1) or
  (ak1 <> ak2 and bk = 0 and ak2 - ak1 <= eps and ak1 - ak2 <= eps),
  d = 0,
  d0 >= 0, d0 <= n,
  c = 0.


(******************************************************************************)
(* TRANSITION                                                                 *)
(*                                                                            *)
(* HIT equal (bkp=1): a1[i]=a2[i] => identical cost => c'=c, d'=d+1        *)
(* HIT unequal (bkp=0): |ak1p-ak2p|<=eps => |cost diff|<=eps               *)
(* MISS: universal |a1[i]-a2[i]|<=eps => |cost diff|<=eps                   *)
(******************************************************************************)

Inv(i', n, kp, ak1', ak2', bk', d', d0, c', eps) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c, eps),
  i < n,
  PickK(i, n, k, ak1, ak2, bk, d, d0, c, eps, kp),
  Wit(i, n, kp, ak1p, ak2p, bkp, d, d0, c, eps),
  (
    (* HIT equal: identical values => identical cost *)
    (i = kp and bkp = 1
     and c' = c
     and d' = d + 1)
    or
    (* HIT unequal: Lipschitz gives |cost diff| <= eps *)
    (i = kp and bkp = 0
     and c' <= c + eps and c' >= c - eps
     and d' = d)
    or
    (* MISS: universal precondition, same Lipschitz bound *)
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
(* GOAL                                                                       *)
(******************************************************************************)

c > (n - d0) * eps :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c, eps),
  n <= i,
  d >= d0.
