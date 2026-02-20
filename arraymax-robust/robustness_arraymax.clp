(*
ArrayMax(A: array, n: size)
    m := A[0]
    for i = 1 to n-1:
        if A[i] > m:
            m := A[i]
    return m
*)

(*
PROPERTY: ε-Robustness (constant bound, no growth with n)
  forall i. |A1[i] - A2[i]| <= eps  ==>  |max(A1) - max(A2)| <= eps

This is K=1 robustness: the max operation does NOT amplify perturbation.
Compare with ArraySum which gives K=n (sum amplifies by factor n).

================================================================================
WHY THE BOUND IS CONSTANT (not growing with i)
================================================================================

Key fact: max is 1-Lipschitz in L∞ norm.

  |max(m1, a1) - max(m2, a2)| <= max(|m1-m2|, |a1-a2|)

Proof sketch (case m1' = max(m1, a1) >= max(m2, a2) = m2'):
  If m1' = m1: m1' - m2' = m1 - m2' <= m1 - m2 <= |m1-m2| <= eps
  If m1' = a1: m1' - m2' = a1 - m2'
    If m2' = m2: a1 - m2 <= a1 - a2 + a2 - m2 <= eps + 0 = eps
                 (since a2 <= m2 in this case)
    If m2' = a2: a1 - a2 <= |a1-a2| <= eps

So |m1' - m2'| <= eps at every step, regardless of how many elements processed.

This means the epsilon bound is CONSTANT: |m1' - m2'| <= eps (not i'*eps).
The solver has real work: verify the constant bound survives the branching max.

================================================================================
ENCODING: SYNCHRONIZED MODEL
================================================================================

Like Kruskal robustness but with:
  - Branching HIT (max operation, 4 sub-cases)
  - CONSTANT epsilon bound (eps, not i*eps)
  - Non-decreasing output (m' >= m)

State: i, k, wk1, wk2, bk:bool, m1, m2, bm:bool, n, eps  (10 variables)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, k, wk1, wk2, bk:bool, m1, m2, bm:bool, n, eps) :-
    i = 0,
    n > 0,
    0 <= k, k < n,
    0 <= eps,
    (* Input precondition: |wk1 - wk2| <= eps *)
    (bk and 0 <= wk2 - wk1 and wk2 - wk1 <= eps) or
    (!bk and 0 <= wk1 - wk2 and wk1 - wk2 <= eps),
    (* Non-negative values *)
    0 <= wk1,
    0 <= wk2,
    (* Initial max: both start at 0 *)
    m1 = 0, m2 = 0.


(******************************************************************************)
(* TRANSITION (synchronized)                                                  *)
(*                                                                            *)
(* HIT: m1' = max(m1, wk1), m2' = max(m2, wk2)                              *)
(*   4 sub-cases of max x max. Each must satisfy |m1'-m2'| <= eps.           *)
(*                                                                            *)
(* MISS: m1' = max(m1, a1), m2' = max(m2, a2) where |a1-a2| <= eps          *)
(*   Values unknown, but non-decreasing and epsilon bound maintained.         *)
(*                                                                            *)
(* EPSILON BOUND: |m1' - m2'| <= eps  (CONSTANT — does not grow with i!)     *)
(******************************************************************************)

Inv(i', k, wk1, wk2, bk:bool, m1', m2', bm':bool, n, eps) :-
    Inv(i, k, wk1, wk2, bk:bool, m1, m2, bm:bool, n, eps),
    (
        (* HIT: process distinguished element k *)
        (* m1' = max(m1, wk1), m2' = max(m2, wk2) — 4 sub-cases *)
        i < n and i = k and i' = i + 1 and
        ((m1 >= wk1 and m1' = m1) or (wk1 > m1 and m1' = wk1)) and
        ((m2 >= wk2 and m2' = m2) or (wk2 > m2 and m2' = wk2))
    ) or (
        (* MISS: process other element — unknown but bounded *)
        i < n and i <> k and i' = i + 1 and
        m1' >= m1 and m2' >= m2
    ) or (
        (* Finished: stutter *)
        i >= n and i' = i and m1' = m1 and m2' = m2
    ),
    (* EPSILON BOUND — CONSTANT, not growing! *)
    (bm' and 0 <= m2' - m1' and m2' - m1' <= eps) or
    (!bm' and 0 <= m1' - m2' and m1' - m2' <= eps).


(******************************************************************************)
(* GOAL: Robustness violation                                                 *)
(*                                                                            *)
(* UNSAT = |max(A1) - max(A2)| <= eps VERIFIED (1-robust)                    *)
(******************************************************************************)

m1 - m2 > eps or m2 - m1 > eps :-
    Inv(i, k, wk1, wk2, bk:bool, m1, m2, bm:bool, n, eps),
    n <= i.


(******************************************************************************)
(* TEST QUERIES                                                               *)
(******************************************************************************)

(*
(* Test 1: Violation — expected UNSAT *)
m1 - m2 > eps or m2 - m1 > eps :-
    Inv(i, k, wk1, wk2, bk:bool, m1, m2, bm:bool, n, eps),
    n <= i.

(* Test 2: Bound achievable — expected SAT *)
m1 - m2 <= eps and m2 - m1 <= eps :-
    Inv(i, k, wk1, wk2, bk:bool, m1, m2, bm:bool, n, eps),
    n <= i.

(* Test 3: Tighter bound? — expected SAT (bound IS tight) *)
(* When wk1 differs from wk2 by eps and one of them IS the max *)
m1 - m2 > 0 or m2 - m1 > 0 :-
    Inv(i, k, wk1, wk2, bk:bool, m1, m2, bm:bool, n, eps),
    n <= i.

(* Test 4: Non-vacuity — expected SAT *)
m1 >= 0 :-
    Inv(i, k, wk1, wk2, bk:bool, m1, m2, bm:bool, n, eps),
    n <= i.

(* Test 5: Comparison with ArraySum robustness *)
(* ArraySum: |s1-s2| <= n*eps (K=n, amplifies) *)
(* ArrayMax: |m1-m2| <= eps   (K=1, no amplification) *)
(* This IS contraction relative to sum *)
*)
