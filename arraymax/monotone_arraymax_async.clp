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
ASYNCHRONOUS MODEL — EXPERIMENTAL
================================================================================

This encoding uses two independent counters i1, i2 with a scheduler,
following the standard robustness/sensitivity pattern. This is HARDER
than the synchronized model because:

1. m1 <= m2 is NOT a valid mid-execution invariant.
   When i1 > i2, run 1 has seen more elements, so m1 could exceed m2.

2. We CANNOT put a monotone bound as a transition constraint.
   In TF, m1 grows but m2 doesn't — so m1' <= m2 can fail.

3. The MISS case is very UNCONSTRAINED.
   Only m1' >= m1 (non-decreasing). No epsilon-like bound.

QUESTION: Can PCSAT discover the invariant without help?

The "real" invariant is roughly:
  when i1 <= i2: m1 <= m2  (run 2 has seen everything run 1 has, plus more)
  when i1 > i2:  no simple bound on m1 vs m2

At termination: i1 = i2 = n, so the first case applies and m1 <= m2.

PREDICTION: PCSAT will likely struggle because the MISS case gives almost
no information. But this is an honest experiment.

State: i1, i2, k, wk1, wk2, m1, m2, n  (8 variables)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i1, i2, k, wk1, wk2, m1, m2, n) :-
    i1 = 0, i2 = 0,
    n > 0,
    0 <= k, k < n,
    0 <= wk1, wk1 <= wk2,
    m1 = 0, m2 = 0.


(******************************************************************************)
(* TF TRANSITION - Only run 1 steps                                           *)
(*                                                                            *)
(* HIT: m1' = max(m1, wk1), m2 unchanged                                     *)
(* MISS: m1' >= m1 (non-decreasing), m2 unchanged                            *)
(* Finished: stutter                                                          *)
(*                                                                            *)
(* NOTE: No monotone bound here. m1' can exceed m2 freely.                    *)
(******************************************************************************)

Inv(i1', i2, k, wk1, wk2, m1', m2, n) :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    SchTF(i1, i2, k, wk1, wk2, m1, m2, n),
    (
        (* HIT: process distinguished element k *)
        i1 < n and i1 = k and i1' = i1 + 1 and
        ((m1 >= wk1 and m1' = m1) or (wk1 > m1 and m1' = wk1))
    ) or (
        (* MISS: process other element — value unknown *)
        i1 < n and i1 <> k and i1' = i1 + 1 and
        m1' >= m1
    ) or (
        (* Finished *)
        i1 >= n and i1' = i1 and m1' = m1
    ).


(******************************************************************************)
(* FT TRANSITION - Only run 2 steps                                           *)
(******************************************************************************)

Inv(i1, i2', k, wk1, wk2, m1, m2', n) :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    SchFT(i1, i2, k, wk1, wk2, m1, m2, n),
    (
        (* HIT *)
        i2 < n and i2 = k and i2' = i2 + 1 and
        ((m2 >= wk2 and m2' = m2) or (wk2 > m2 and m2' = wk2))
    ) or (
        (* MISS *)
        i2 < n and i2 <> k and i2' = i2 + 1 and
        m2' >= m2
    ) or (
        (* Finished *)
        i2 >= n and i2' = i2 and m2' = m2
    ).


(******************************************************************************)
(* TT TRANSITION - Both runs step                                             *)
(*                                                                            *)
(* Cartesian product of run 1 and run 2 cases.                                *)
(* Run 1 and run 2 are at DIFFERENT indices (i1 != i2 in general).            *)
(* At most one can be at k.                                                   *)
(******************************************************************************)

Inv(i1', i2', k, wk1, wk2, m1', m2', n) :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    SchTT(i1, i2, k, wk1, wk2, m1, m2, n),
    (* Run 1 *)
    (
        i1 < n and i1 = k and i1' = i1 + 1 and
        ((m1 >= wk1 and m1' = m1) or (wk1 > m1 and m1' = wk1))
    ) or (
        i1 < n and i1 <> k and i1' = i1 + 1 and
        m1' >= m1
    ) or (
        i1 >= n and i1' = i1 and m1' = m1
    ),
    (* Run 2 *)
    (
        i2 < n and i2 = k and i2' = i2 + 1 and
        ((m2 >= wk2 and m2' = m2) or (wk2 > m2 and m2' = wk2))
    ) or (
        i2 < n and i2 <> k and i2' = i2 + 1 and
        m2' >= m2
    ) or (
        i2 >= n and i2' = i2 and m2' = m2
    ).


(******************************************************************************)
(* SCHEDULER FAIRNESS                                                         *)
(******************************************************************************)

i1 < n :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    SchTF(i1, i2, k, wk1, wk2, m1, m2, n),
    i2 < n.

i2 < n :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    SchFT(i1, i2, k, wk1, wk2, m1, m2, n),
    i1 < n.

SchTF(i1, i2, k, wk1, wk2, m1, m2, n),
SchFT(i1, i2, k, wk1, wk2, m1, m2, n),
SchTT(i1, i2, k, wk1, wk2, m1, m2, n) :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    i1 < n or i2 < n.


(******************************************************************************)
(* GOAL: Monotonicity violation at termination                                *)
(*                                                                            *)
(* UNSAT = monotonicity verified for all interleavings                        *)
(* SAT   = spurious counterexample (abstraction too loose)                    *)
(******************************************************************************)

(*m1 <= m2 :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    n <= i1, n <= i2.
*)

m1 > m2 :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    i1 > i2, i1 < n.

(******************************************************************************)
(* TEST QUERIES                                                               *)
(******************************************************************************)

(*
(* Test 1: Violation - expected UNSAT *)
m1 > m2 :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    n <= i1, n <= i2.
unsat,131
8:35.39 total

(* Test 2: Bound holds - expected SAT *)
m1 <= m2 :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    n <= i1, n <= i2.

(* Test 3: Mid-execution violation - expected SAT *)
(* This confirms m1 > m2 CAN happen during execution *)
m1 > m2 :-
    Inv(i1, i2, k, wk1, wk2, m1, m2, n),
    i1 > i2, i1 < n.
SAT, 5.6seconds
*)
