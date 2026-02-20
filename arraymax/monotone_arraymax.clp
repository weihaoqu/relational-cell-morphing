(*
ArrayMax(A: array, n: size)
    m := A[0]
    for i = 1 to n-1:
        if A[i] > m:
            m := A[i]
    return m
*)

(*
PROPERTY: Monotonicity under pointwise ordering
  forall i. A1[i] <= A2[i]  ==>  max(A1) <= max(A2)

================================================================================
WHY MONOTONICITY IS DIFFERENT FROM ROBUSTNESS
================================================================================

Robustness uses QUANTITATIVE slack:
  |c1 - c2| <= i * eps       Allows either direction, bounded by eps
  
Monotonicity uses QUALITATIVE ordering:
  c1 <= c2                   One-sided, no wiggle room

In robustness, the epsilon bound absorbs the MISS overapproximation.
In monotonicity, the monotone bound DIRECTLY captures the universal
precondition (a1[i] <= a2[i] for all i), analogous to how the epsilon
bound captures |a1[i] - a2[i]| <= eps for all i.

Key difference: the epsilon bound is non-trivial (solver must verify
the right constant grows correctly). The monotone bound is qualitative
(trivially maintained once asserted). This makes monotonicity proofs
VALID but SIMPLE for the solver.

================================================================================
ENCODING: SYNCHRONIZED MODEL
================================================================================

Both runs step together (single counter i). This is correct for ArrayMax
because both runs process elements in the same order (indices 0 to n-1).

INPUT CELL:
  k:     Distinguished element index
  wk1:   A1[k] - value in array 1
  wk2:   A2[k] - value in array 2
  PRECONDITION: wk1 <= wk2 (monotone input)
  IMPLICIT: forall j != k. A1[j] <= A2[j] (captured by monotone bound)

OUTPUT CELL:
  m1, m2: current maximum in each run
  POSTCONDITION: m1 <= m2 (monotonicity)

STATE: i, k, wk1, wk2, m1, m2, n  (7 variables)

NOTE: No sign bits needed! We know the direction: wk1 <= wk2, m1 <= m2.
This is simpler than robustness (which needs bk, bc for unknown direction).
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, k, wk1, wk2, m1, m2, n) :-
    i = 0,
    n > 0,
    0 <= k, k < n,
    (* Monotone input: A1[k] <= A2[k] *)
    0 <= wk1, wk1 <= wk2,
    (* Initial max: both start with first element *)
    (* If k = 0: m1 = wk1, m2 = wk2 (HIT at init) *)
    (* If k > 0: m1 = m2 = A[0] (same for both, MISS) *)
    (* Abstraction: m1 <= m2 holds in both cases *)
    (* We initialize m1 = 0, m2 = 0 and process all elements *)
    m1 = 0, m2 = 0.


(******************************************************************************)
(* TRANSITION (synchronized - single counter)                                 *)
(*                                                                            *)
(* At each step, both runs process element i:                                 *)
(*   m1' = max(m1, A1[i])                                                    *)
(*   m2' = max(m2, A2[i])                                                    *)
(*                                                                            *)
(* Since max(m, a) >= m always, the running max is non-decreasing.            *)
(*                                                                            *)
(* HIT (i = k):                                                               *)
(*   m1' = max(m1, wk1), m2' = max(m2, wk2)                                  *)
(*   Since m1 <= m2 (induction) and wk1 <= wk2 (precondition):               *)
(*     m1' = max(m1, wk1) <= max(m2, wk2) = m2'                              *)
(*                                                                            *)
(* MISS (i != k):                                                              *)
(*   A1[i] <= A2[i] (universal precondition, implicit)                        *)
(*   m1', m2' unconstrained except by monotone bound m1' <= m2'               *)
(*   Non-decreasing: m1' >= m1, m2' >= m2                                     *)
(******************************************************************************)

Inv(i', k, wk1, wk2, m1', m2', n) :-
    Inv(i, k, wk1, wk2, m1, m2, n),
    (
        (* HIT: process distinguished element k *)
        (* max(m, w) = m if m >= w, else w *)
        i < n and i = k and i' = i + 1 and
        (* Run 1: m1' = max(m1, wk1) *)
        ((m1 >= wk1 and m1' = m1) or (wk1 > m1 and m1' = wk1)) and
        (* Run 2: m2' = max(m2, wk2) *)
        ((m2 >= wk2 and m2' = m2) or (wk2 > m2 and m2' = wk2))
    ) or (
        (* MISS: process other element *)
        (* Values unknown, but non-decreasing and monotone bound maintained *)
        i < n and i <> k and i' = i + 1 and
        m1' >= m1 and m2' >= m2
    ) or (
        (* Finished *)
        i >= n and i' = i and m1' = m1 and m2' = m2
    ),
    (* MONOTONE BOUND: m1' <= m2' *)
    (* This captures the implicit precondition A1[i] <= A2[i] for all i *)
    (* Analogous to how the epsilon bound captures |A1[i]-A2[i]| <= eps *)
    m1' <= m2'.


(******************************************************************************)
(* GOAL: Monotonicity violation                                               *)
(*                                                                            *)
(* UNSAT = max(A1) <= max(A2) VERIFIED (monotonicity holds)                   *)
(******************************************************************************)

m1 <= m2 :-
    Inv(i, k, wk1, wk2, m1, m2, n),
    n <= i.


(******************************************************************************)
(* TEST QUERIES                                                               *)
(******************************************************************************)

(*
(* Test 1: Monotonicity holds - expected SAT *)
m1 <= m2 :-
    Inv(i, k, wk1, wk2, m1, m2, n),
    n <= i.
sat, 1.2seconds.

(* Test 2: Violation - expected UNSAT *)
m1 > m2 :-
    Inv(i, k, wk1, wk2, m1, m2, n),
    n <= i.
 Unsat, 6 seconds.   

(* Test 3: Exact equality? - expected SAT *)
(* max(A1) could equal max(A2) if wk1 < wk2 but neither is the max *)
m1 = m2 :-
    Inv(i, k, wk1, wk2, m1, m2, n),
    n <= i.

(* Test 4: Strict monotonicity? - expected SAT *)
(* max(A1) < max(A2) when wk1 < wk2 and wk2 is the global max *)
m1 < m2 :-
    Inv(i, k, wk1, wk2, m1, m2, n),
    n <= i, wk1 < wk2.

(* Test 5: Can m1 = m2 even when wk1 < wk2? - expected SAT *)
(* Yes: if some MISS element dominates both wk1 and wk2 *)
m1 = m2 :-
    Inv(i, k, wk1, wk2, m1, m2, n),
    n <= i, wk1 < wk2.
*)
