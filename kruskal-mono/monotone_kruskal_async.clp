(*
Kruskal(G : graph)
    for each node v in G:
        MakeSet(v)
    T := empty
    cost := 0
    for each edge (u,v) in G ordered by weight:
        if Find(u) != Find(v):
            T := T + {(u,v)}
            cost := cost + G[u,v]
            Union(u, v)
    return T, cost
*)

(*
PROPERTY: Monotonicity of MST cost under pointwise ordering
    forall e. w1[e] <= w2[e]  ==>  cost(MST_1) <= cost(MST_2)

================================================================================
ASYNCHRONOUS MODEL — VACUOUS (precondition is dead)
================================================================================

RESULTS:
    Violation c1 > c2 at termination:   UNSAT, 2s       (looks like verified)
    Non-vacuity c1 >= 0 at termination: SAT, 8s         (costs are non-negative)
    Reverse c2 > c1 at termination:     UNSAT, 2.2s     (symmetric!)
    n > 0 at termination:               SAT, 22s        (non-vacuity by this test)
    Mid-exec c1 > c2 at i1 > i2:        SAT, 22.5s      (vacuous SAT, TT-only)

DIAGNOSTIC CHAIN (revealed vacuity):
    No-SKIP variant:     UNSAT, 2s    → SKIP is not the factor
    k < n-1 added:       UNSAT, 2.7s  → bounded k is not the factor
    i1 = i2 mid-exec:    UNSAT, 7s    → runs CAN desynchronize
    c1 > 0 terminal:     UNSAT, 1s    → not universal (wk1=0)
    c1 = 0 terminal:     UNSAT, 18m   → costs not universally zero
    NO-HIT variant:      UNSAT, 6s    → HIT IS IRRELEVANT
    No wk1<=wk2 precond: UNSAT, 16s   → PRECONDITION IS DEAD

VERDICT: VACUOUS. The UNSAT result does NOT verify monotonicity.

================================================================================
ROOT CAUSE ANALYSIS
================================================================================

The problem is that Kruskal's counter tracks edges ADDED to MST,
NOT positions scanned. Compare:

    ArraySum:
        i scans positions 0, 1, 2, ..., n-1
        k is a position in [0, n-1]
        Guard: i1 = k → MUST use HIT (forced at exactly step k)
        Guard: i1 <> k → MUST use MISS (forced at all other steps)
        HIT is MANDATORY — the solver cannot avoid it.

    Kruskal:
        i counts edges added (0, 1, ..., n-2)
        k is an edge index — but NOT a scan position!
        NO guard: HIT and MISS are both available at EVERY step
        HIT is OPTIONAL — the solver can use MISS everywhere.

Without a position guard (i = k), MISS ADD (c1' >= c1) SUBSUMES
HIT ADD (c1' = c1 + wk1 with wk1 >= 0). The solver uses MISS at
every step, making the two runs perfectly symmetric:

    Run 1 transitions: c1' >= c1 (non-decreasing)
    Run 2 transitions: c2' >= c2 (non-decreasing)

    These are IDENTICAL in structure. By symmetry, any execution
    trace that produces c1 > c2 has a mirror trace producing c2 > c1.
    The solver finds this symmetric invariant trivially (2 seconds).

The precondition wk1 <= wk2 is dead because wk1 and wk2 never
appear in any MISS transition. The proof works by SYMMETRY of
unconstrained growth, not by MONOTONICITY of the accumulation.

================================================================================
CONTRAST WITH ARRAYSUM (genuine) and DIJKSTRA (vacuous)
================================================================================

Three forms of vacuity discovered:

    Dijkstra vacuity (session 2):
        HIT = MISS = dv' >= 0 (abstract, no upper bound)
        Costs stuck at 0 through termination
        Detection: c1 > 0 at terminal → UNSAT (stuck at 0)

    Kruskal async vacuity (this session):
        HIT subsumed by MISS (no position guard)
        Precondition wk1 <= wk2 is dead
        Costs NOT stuck at 0 (c1 = 0 UNSAT after 18m)
        Detection: no-HIT variant → still UNSAT

    ArraySum (genuine, non-vacuous):
        HIT FORCED by position guard (i = k)
        Precondition wk1 <= wk2 is ALIVE
        Detection: no-HIT would give SAT; precondition removal gives SAT

================================================================================
THE STRUCTURAL CRITERION (updated)
================================================================================

For cell morphing monotonicity to work in the async model:

    1. HIT must be FORCED, not optional
       → Requires a position guard: i = k (scan position = distinguished cell)
       → Counter must track SCAN POSITION, not just edges added

    2. MISS must NOT subsume HIT
       → The guard creates a hard partition: i=k → HIT only, i≠k → MISS only
       → Without this partition, MISS absorbs HIT

    3. The precondition must be ALIVE
       → It flows through HIT: c1' = c1 + wk1, c2' = c2 + wk2, wk1 <= wk2
       → If HIT never fires, precondition is dead

POTENTIAL FIX: Add a scan counter j that tracks which edge is being
CONSIDERED (not just added). Then HIT fires when j = k (forced).
But this adds variables and complicates the encoding significantly.
The sync model already works for Kruskal (c1' <= c2' as explicit bound).

State: i1, i2, k, wk1, wk2, c1, c2, n  (8 variables)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i1, i2, k, wk1, wk2, c1, c2, n) :-
    i1 = 0, i2 = 0,
    n > 0,
    0 <= k, k < n - 1,
    (* Non-negative weights + monotone precondition *)
    0 <= wk1, wk1 <= wk2,
    c1 = 0, c2 = 0.


(******************************************************************************)
(* TF TRANSITION - Only run 1 steps                                           *)
(******************************************************************************)

Inv(i1', i2, k, wk1, wk2, c1', c2, n) :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    SchTF(i1, i2, k, wk1, wk2, c1, c2, n),
    (
        (* HIT ADD: add distinguished edge k *)
        i1 < n - 1 and i1' = i1 + 1 and
        c1' = c1 + wk1
    ) or (
        (* MISS ADD: add other edge — weight unknown but non-negative *)
        i1 < n - 1 and i1' = i1 + 1 and
        c1' >= c1
    ) or (
        (* SKIP: edge not added to MST *)
        i1 < n - 1 and i1' = i1 and c1' = c1
    ) or (
        (* FINISHED *)
        i1 >= n - 1 and i1' = i1 and c1' = c1
    ).


(******************************************************************************)
(* FT TRANSITION - Only run 2 steps                                           *)
(******************************************************************************)

Inv(i1, i2', k, wk1, wk2, c1, c2', n) :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    SchFT(i1, i2, k, wk1, wk2, c1, c2, n),
    (
        (* HIT ADD *)
        i2 < n - 1 and i2' = i2 + 1 and
        c2' = c2 + wk2
    ) or (
        (* MISS ADD *)
        i2 < n - 1 and i2' = i2 + 1 and
        c2' >= c2
    ) or (
        (* SKIP *)
        i2 < n - 1 and i2' = i2 and c2' = c2
    ) or (
        (* FINISHED *)
        i2 >= n - 1 and i2' = i2 and c2' = c2
    ).


(******************************************************************************)
(* TT TRANSITION - Both runs step                                             *)
(******************************************************************************)

Inv(i1', i2', k, wk1, wk2, c1', c2', n) :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    SchTT(i1, i2, k, wk1, wk2, c1, c2, n),
    (* Run 1 *)
    (
        i1 < n - 1 and i1' = i1 + 1 and
        c1' = c1 + wk1
    ) or (
        i1 < n - 1 and i1' = i1 + 1 and
        c1' >= c1
    ) or (
        i1 < n - 1 and i1' = i1 and c1' = c1
    ) or (
        i1 >= n - 1 and i1' = i1 and c1' = c1
    ),
    (* Run 2 *)
    (
        i2 < n - 1 and i2' = i2 + 1 and
        c2' = c2 + wk2
    ) or (
        i2 < n - 1 and i2' = i2 + 1 and
        c2' >= c2
    ) or (
        i2 < n - 1 and i2' = i2 and c2' = c2
    ) or (
        i2 >= n - 1 and i2' = i2 and c2' = c2
    ).


(******************************************************************************)
(* SCHEDULER FAIRNESS                                                         *)
(******************************************************************************)

i1 < n - 1 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    SchTF(i1, i2, k, wk1, wk2, c1, c2, n),
    i2 < n - 1.

i2 < n - 1 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    SchFT(i1, i2, k, wk1, wk2, c1, c2, n),
    i1 < n - 1.

SchTF(i1, i2, k, wk1, wk2, c1, c2, n),
SchFT(i1, i2, k, wk1, wk2, c1, c2, n),
SchTT(i1, i2, k, wk1, wk2, c1, c2, n) :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    i1 < n - 1 or i2 < n - 1.


(******************************************************************************)
(* GOAL: Monotonicity violation at termination                                *)
(* RESULT: UNSAT, 2s — BUT VACUOUS (see header analysis)                     *)
(******************************************************************************)

(* c1 > c2 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2. *)


(******************************************************************************)
(* SANITY CHECKS                                                              *)
(******************************************************************************)

(* Check 1: c1 >= 0 — SAT, 8s (non-negative costs) *)
(* c1 >= 0 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2. *)

(* Check 2: c2 > c1 — UNSAT, 2.2s (symmetric with violation!) *)
(* c2 > c1 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2. *)

(* Check 3: n > 0 — SAT, 22s *)
(* n > 0 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2. *)

(* Check 4: mid-exec c1 > c2 — SAT, 22.5s (vacuous, TT-only) *)
(* c1 > c2 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    i1 > i2, i1 < n - 1. *)

(* Check B: c1 > 0 — UNSAT, 1s (not universal, wk1=0 allowed) *)
(* c1 > 0 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2. *)

(* Check C: i1 = i2 mid-exec — UNSAT, 7s (runs CAN desynchronize) *)
(* i1 = i2 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    i1 < n - 1. *)

(* Check E: c1 = 0 — UNSAT, 18m (costs not universally zero) *)
(* c1 = 0 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2. *)


(******************************************************************************)
(* DIAGNOSTIC VARIANTS (separate files)                                       *)
(******************************************************************************)

(* monotone_kruskal_async_noskip.clp: SKIP removed → UNSAT, 2s              *)
(* monotone_kruskal_async_nohit.clp:  HIT removed  → UNSAT, 6s  ← KEY      *)
(* wk1<=wk2 removed from init:                     → UNSAT, 16s ← DECISIVE *)
