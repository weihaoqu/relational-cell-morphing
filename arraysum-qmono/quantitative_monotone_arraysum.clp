(*
ArraySum(A: array, n: size)
    s := 0
    for i = 0 to n-1:
        s := s + A[i]
    return s
*)

(*
PROPERTY: Quantitative Monotonicity
  forall i. 0 <= A2[i] - A1[i] <= eps
  ==> 0 <= ArraySum(A2) - ArraySum(A1) <= n * eps

This combines:
  - Monotonicity (lower bound: sum2 >= sum1)
  - One-sided robustness (upper bound: sum2 - sum1 <= n*eps)

The key advantage: since we know the direction (s2 >= s1), we do NOT
need sign bits. This is simpler than robustness (no bk, bc) while
giving the solver real quantitative work (unlike pure monotonicity
where the invariant is trivially m1 <= m2).

================================================================================
ENCODING: SYNCHRONIZED MODEL
================================================================================

Since direction is known, the transition bound is:
  0 <= s2' - s1' <= i' * eps

This is a ONE-SIDED epsilon bound — half the disjuncts of robustness.

State: i, k, wk1, wk2, s1, s2, n, eps  (8 variables, no booleans)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, k, wk1, wk2, s1, s2, n, eps) :-
    i = 0,
    n > 0,
    0 <= k, k < n,
    0 <= eps,
    (* Input precondition: 0 <= A2[k] - A1[k] <= eps *)
    0 <= wk1,
    0 <= wk2 - wk1,
    wk2 - wk1 <= eps,
    (* Both sums start at zero *)
    s1 = 0, s2 = 0.


(******************************************************************************)
(* TRANSITION (synchronized)                                                  *)
(*                                                                            *)
(* HIT: s1' = s1 + wk1, s2' = s2 + wk2                                      *)
(*   s2' - s1' = (s2 - s1) + (wk2 - wk1)                                    *)
(*             <= i*eps + eps = (i+1)*eps   ✓                                 *)
(*   s2' - s1' = (s2 - s1) + (wk2 - wk1) >= 0 + 0 = 0   ✓                  *)
(*                                                                            *)
(* MISS: both add unknown values where 0 <= a2 - a1 <= eps                   *)
(*   s2' - s1' = (s2 - s1) + (a2 - a1)                                       *)
(*             <= i*eps + eps = (i+1)*eps   ✓                                 *)
(*   s2' - s1' >= 0 + 0 = 0   ✓                                              *)
(*                                                                            *)
(* Bound: 0 <= s2' - s1' <= i' * eps (no sign bits needed!)                  *)
(******************************************************************************)

Inv(i', k, wk1, wk2, s1', s2', n, eps) :-
    Inv(i, k, wk1, wk2, s1, s2, n, eps),
    (
        (* HIT: process distinguished element k *)
        i < n and i = k and i' = i + 1 and
        s1' = s1 + wk1 and s2' = s2 + wk2
    ) or (
        (* MISS: process other element — unknown but bounded *)
        i < n and i <> k and i' = i + 1 and
        s1' >= s1 and s2' >= s2
    ) or (
        (* Finished: stutter *)
        i >= n and i' = i and s1' = s1 and s2' = s2
    ),
    (* QUANTITATIVE MONOTONE BOUND — one-sided epsilon bound *)
    (* Lower bound: s2' >= s1' (monotonicity) *)
    0 <= s2' - s1',
    (* Upper bound: s2' - s1' <= i' * eps (one-sided robustness) *)
    s2' - s1' <= i' * eps.


(******************************************************************************)
(* GOAL: Upper bound violation                                                *)
(*                                                                            *)
(* UNSAT = sum(A2) - sum(A1) <= n * eps VERIFIED                              *)
(* Combined with the transition bound 0 <= s2' - s1', this also proves        *)
(* monotonicity (sum(A2) >= sum(A1)) as a free bonus.                         *)
(******************************************************************************)

s2 - s1 > n * eps :-
    Inv(i, k, wk1, wk2, s1, s2, n, eps),
    n <= i.


(******************************************************************************)
(* TEST QUERIES                                                               *)
(******************************************************************************)

(*
(* Test 1: Upper bound violation — expected UNSAT *)
s2 - s1 > n * eps :-
    Inv(i, k, wk1, wk2, s1, s2, n, eps),
    n <= i.

(* Test 2: Monotonicity violation — expected UNSAT (subsumed by bound) *)
s1 > s2 :-
    Inv(i, k, wk1, wk2, s1, s2, n, eps),
    n <= i.

(* Test 3: Upper bound achievable — expected SAT *)
s2 - s1 <= n * eps :-
    Inv(i, k, wk1, wk2, s1, s2, n, eps),
    n <= i.

(* Test 4: Non-vacuity — expected SAT *)
s1 >= 0 :-
    Inv(i, k, wk1, wk2, s1, s2, n, eps),
    n <= i.

(* Test 5: Tighter bound? — expected SAT (bound is tight) *)
(* When all elements have gap exactly eps, total gap = n*eps *)
s2 - s1 > (n - 1) * eps :-
    Inv(i, k, wk1, wk2, s1, s2, n, eps),
    n <= i.
*)
