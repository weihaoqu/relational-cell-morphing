# Kruskal MST Monotonicity (Async): A Debugging Case Study

A step-by-step account of encoding Kruskal's MST cost monotonicity in the asynchronous cell morphing framework, discovering it was vacuous, and developing new diagnostic techniques to detect a previously-unknown failure mode.

**Bottom line:** The async Kruskal encoding returns UNSAT in 2 seconds, but the result is **vacuous** — the precondition `wk1 ≤ wk2` plays no role. The synchronized model is the correct approach for Kruskal. This tutorial documents how we discovered the vacuity and what it teaches about encoding design.

---

## Verification Results

### Asynchronous Model — VACUOUS

| Goal | Result | Time | Meaning |
|------|--------|------|---------|
| `c1 > c2` at termination | **UNSAT** | 2s | Looks verified... |
| `c1 >= 0` at termination | **SAT** | 8s | Standard sanity check passes! |
| `c2 > c1` at termination | **UNSAT** | 2.2s | Symmetric with violation |
| `n > 0` at termination | **SAT** | 22s | Non-vacuity check passes! |
| Mid-exec `c1 > c2` | **SAT** | 22.5s | Vacuous SAT (TT-only) |

### Diagnostic Chain — Revealed Vacuity

| Test | Result | Time | What it tells us |
|------|--------|------|-----------------|
| No-SKIP variant | UNSAT | 2s | SKIP is not the factor |
| Add `k < n-1` | UNSAT | 2.7s | Bounded k is not the factor |
| `i1 = i2` mid-exec | UNSAT | 7s | Runs CAN desynchronize |
| `c1 > 0` terminal | UNSAT | 1s | Not universal (wk1=0 case) |
| `c1 = 0` terminal | UNSAT | 18m | Costs not universally zero |
| **NO-HIT variant** | **UNSAT** | **6s** | **HIT is irrelevant!** |
| **Remove `wk1 <= wk2`** | **UNSAT** | **16s** | **Precondition is dead!** |

### Synchronized Model — GENUINE (reference)

| Goal | Result | Time | Meaning |
|------|--------|------|---------|
| `c1 > c2` | **UNSAT** | fast | **Monotonicity VERIFIED ✓** |
| `c1 <= c2` | **SAT** | fast | Bound achievable ✓ |

---

## Part 1: The Algorithm

```
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
```

### Key Observations

1. **Processes edges in sorted order**: Fixed iteration order, independent of weights
2. **Add/skip decision depends on union-find**: Same components → skip, different → add
3. **Counter tracks edges ADDED to MST** (0 to n-1), NOT edges scanned
4. **Cost is a running sum**: `cost' = cost + w[e]` when edge is added

---

## Part 2: The Property — Monotonicity

```
PROPERTY: Monotonicity of MST cost under pointwise ordering

∀e. w1[e] ≤ w2[e]  ⟹  cost(MST_1) ≤ cost(MST_2)
    ~~~~~~~~~~~~~~~~     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    INPUT: every edge        OUTPUT: MST cost
    weight in G1 ≤ G2        of G1 ≤ MST cost of G2
```

### Assumption: Non-Negative Weights

```
ASSUMPTION: ∀e. w[e] ≥ 0

This ensures costs are non-decreasing: cost' = cost + w[e] ≥ cost.
Without this, MISS ADD would be unconstrained.
```

### Why Is This True? (Informal Argument)

```
Claim: If both runs add the SAME set of edges (same MST structure),
then cost1 = Σ w1[e] ≤ Σ w2[e] = cost2 (pointwise ≤ on each edge).

Key insight: The add/skip decision depends on union-find state,
which depends on WHICH edges were added — not their WEIGHTS.
Since both runs process edges in the same sorted order and
union-find is weight-independent, both runs add the SAME edges.

Therefore: cost(MST_1) = Σ_{e∈MST} w1[e] ≤ Σ_{e∈MST} w2[e] = cost(MST_2).
```

This is why the **synchronized model works perfectly** — both runs make identical add/skip decisions.

---

## Part 3: Why Try Asynchronous?

The synchronized model already verifies Kruskal monotonicity trivially. So why try async?

1. **Consistency**: ArraySum and ArrayMax were verified in async. Can Kruskal be too?
2. **Stronger result**: Async proves monotonicity under ALL interleavings
3. **Research question**: Does the SKIP case help or hurt?

The async model is a natural experiment. It turned out to fail — but the failure taught us something important.

---

## Part 4: The Critical Structural Difference

```
┌─────────────────────────────────────────────────────────────────────────┐
│              WHY KRUSKAL ASYNC IS DIFFERENT FROM ARRAYSUM                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ArraySum:                                                              │
│     Counter i = SCAN POSITION (0, 1, 2, ..., n-1)                      │
│     Distinguished cell k is a scan position in [0, n-1]                │
│                                                                         │
│     HIT guard:  i = k   → MUST use HIT (exactly one step)             │
│     MISS guard: i ≠ k   → MUST use MISS (all other steps)             │
│                                                                         │
│     The guards create a HARD PARTITION.                                 │
│     The solver CANNOT avoid HIT. It fires exactly once.                │
│                                                                         │
│  Kruskal:                                                               │
│     Counter i = EDGES ADDED (0, 1, 2, ..., n-2)                       │
│     Distinguished cell k is an edge index — NOT a scan position!       │
│                                                                         │
│     HIT: available at ANY add step (no guard)                          │
│     MISS: available at ANY add step (no guard)                         │
│                                                                         │
│     NO hard partition. HIT and MISS overlap completely.                │
│     The solver CAN avoid HIT entirely (use MISS everywhere).          │
│                                                                         │
│  CONSEQUENCE:                                                           │
│     MISS ADD: c1' >= c1         (non-negative weight)                  │
│     HIT ADD:  c1' = c1 + wk1   (wk1 >= 0, so c1' >= c1)              │
│                                                                         │
│     MISS SUBSUMES HIT!                                                  │
│     Every HIT trace is also a valid MISS trace.                        │
│     The solver has no reason to use HIT.                                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 5: The Encoding

### State Variables

```
Inv(i1, i2, k, wk1, wk2, c1, c2, n)
```

| Variable | Type | Meaning | Changes? |
|----------|------|---------|----------|
| `i1` | int | Edges added in run 1 | Yes (0 → n-1) |
| `i2` | int | Edges added in run 2 | Yes (0 → n-1) |
| `k` | int | Distinguished edge index | **Never** |
| `wk1` | real | Weight of edge k in G1 | **Never** |
| `wk2` | real | Weight of edge k in G2 | **Never** |
| `c1` | real | MST cost in run 1 | Yes (non-decreasing) |
| `c2` | real | MST cost in run 2 | Yes (non-decreasing) |
| `n` | int | Number of vertices | **Never** |

**8 variables.** Same count as ArraySum and ArrayMax.

### Initialization

```prolog
Inv(i1, i2, k, wk1, wk2, c1, c2, n) :-
    i1 = 0, i2 = 0,
    n > 0,
    0 <= k, k < n - 1,
    0 <= wk1, wk1 <= wk2,
    c1 = 0, c2 = 0.
```

### TF Transition — Only Run 1 Steps

```prolog
Inv(i1', i2, k, wk1, wk2, c1', c2, n) :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    SchTF(i1, i2, k, wk1, wk2, c1, c2, n),
    (
        (* HIT ADD: add distinguished edge k *)
        i1 < n - 1 and i1' = i1 + 1 and
        c1' = c1 + wk1
    ) or (
        (* MISS ADD: add other edge *)
        i1 < n - 1 and i1' = i1 + 1 and
        c1' >= c1
    ) or (
        (* SKIP: edge not added to MST *)
        i1 < n - 1 and i1' = i1 and c1' = c1
    ) or (
        (* FINISHED *)
        i1 >= n - 1 and i1' = i1 and c1' = c1
    ).
```

### Key Difference: Four Cases (Not Three)

```
ArraySum:  HIT / MISS / FINISHED          (3 cases per run)
Kruskal:   HIT ADD / MISS ADD / SKIP / FINISHED  (4 cases per run)

SKIP is unique to Kruskal: the edge is considered but NOT added.
Counter i stays unchanged. Cost stays unchanged.
```

### What's NOT Here: No Position Guard

```
ArraySum TF:  i1 = k  and s1' = s1 + wk1       ← forced by position
              i1 <> k and s1' >= s1              ← forced by position

Kruskal TF:   c1' = c1 + wk1                    ← optional (any step)
              c1' >= c1                           ← optional (any step)
              
No i1 = k guard! Both HIT and MISS available at every ADD step.
```

### FT, TT, Scheduler, Fairness

Symmetric with TF (same structure as ArraySum/ArrayMax tutorials). FT handles run 2, TT handles both stepping simultaneously. Scheduler ensures fairness. Standard pattern.

### Goal

```prolog
c1 > c2 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2.
```

**Result: UNSAT in 2 seconds.** This was exciting — 23x faster than ArraySum (47s)!

---

## Part 6: Initial Sanity Checks — Everything Looks Fine

Following the established recipe from ArraySum:

| Check | Goal | Result | Time | Interpretation |
|-------|------|--------|------|----------------|
| 1 | `c1 >= 0` at termination | **SAT** | 8s | Non-vacuous ✓ (standard check passes) |
| 2 | `c2 > c1` at termination | UNSAT | 2.2s | Not universal (expected) |
| 3 | `n > 0` at termination | **SAT** | 22s | Non-vacuous ✓ |
| 4 | `c1 > c2` mid-exec | SAT | 22.5s | Vacuous SAT (TT-only, same as ArraySum) |

At this point, everything looked genuine. `c1 >= 0` SAT and `n > 0` SAT — both non-vacuity checks pass. The 2-second solve time seemed like a pleasant surprise.

But **2 seconds was suspicious.** ArraySum takes 47 seconds. ArrayMax takes 8m 35s. Why would Kruskal, with MORE disjuncts (4 cases vs 3), be faster?

---

## Part 7: The Investigation — What Explains 2 Seconds?

### Hypothesis 1: SKIP Enables Implicit Synchronization

The idea: SKIP lets one run idle while the other catches up, effectively recovering a synchronized invariant (c1 ≤ c2 at every step).

**Test: Remove SKIP entirely.**

| Variant | Result | Time |
|---------|--------|------|
| With SKIP (original) | UNSAT | 2s |
| Without SKIP | UNSAT | 2s |

**SKIP is not the factor.** Same speed without it.

### Hypothesis 2: Unbounded k Lets Solver Avoid HIT

Original init has `0 <= k` with no upper bound. If solver picks `k ≥ n-1`, HIT never fires.

**Test: Add `k < n - 1` to init.**

| Variant | Result | Time |
|---------|--------|------|
| Unbounded k | UNSAT | 2s |
| `k < n - 1` | UNSAT | 2.7s |

**Bounded k is not the factor.** Still fast.

### Hypothesis 3: Solver Uses Lockstep Schedule

Maybe the solver forces `i1 = i2` at all times.

**Test: Is `i1 = i2` universally true mid-execution?**

```prolog
i1 = i2 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    i1 < n - 1.
```

**Result: UNSAT (7s)** — meaning `i1 = i2` is NOT universal. Runs CAN desynchronize.

**Lockstep hypothesis killed.**

---

## Part 8: The Breakthrough — Remove HIT

### Hypothesis 4: MISS Subsumes HIT

Since MISS ADD (`c1' >= c1`) includes all behaviors of HIT ADD (`c1' = c1 + wk1`, `wk1 >= 0`), maybe HIT is completely irrelevant.

**Test: Remove HIT ADD from all transitions, keep only MISS ADD.**

| Variant | Result | Time |
|---------|--------|------|
| With HIT (original) | UNSAT | 2s |
| **Without HIT** | **UNSAT** | **6s** |

**HIT is irrelevant.** The solver never needed the exact `c1 + wk1` contribution.

### The Decisive Test: Remove the Precondition

If HIT is irrelevant, then `wk1` and `wk2` are dead variables. The precondition `wk1 <= wk2` should be dead too.

**Test: Remove `0 <= wk1, wk1 <= wk2` from init. Keep everything else.**

| Variant | Result | Time |
|---------|--------|------|
| With precondition | UNSAT | 2s |
| **Without precondition** | **UNSAT** | **16s** |

**The precondition is dead. The UNSAT is vacuous.**

---

## Part 9: Root Cause — Symmetry, Not Monotonicity

With HIT irrelevant, the only transition affecting costs is MISS ADD:

```
Run 1 at any ADD step:  c1' >= c1   (non-decreasing)
Run 2 at any ADD step:  c2' >= c2   (non-decreasing)
```

These are **structurally identical.** The solver sees two copies of the same abstract process. By symmetry, if any execution produces `c1 > c2`, there's a mirror execution producing `c2 > c1`. Neither `c1 > c2` nor `c2 > c1` can be universally true.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SYMMETRY ARGUMENT                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  The transitions for c1 and c2 are identical:                           │
│                                                                         │
│    c1' >= c1    (from MISS ADD, run 1)                                 │
│    c2' >= c2    (from MISS ADD, run 2)                                 │
│                                                                         │
│  There is no constraint relating c1 to c2 at any step.                 │
│  The two runs evolve independently with identical constraints.          │
│                                                                         │
│  By symmetry: swap c1 ↔ c2, i1 ↔ i2 in any trace,                    │
│  and you get another valid trace with reversed ordering.                │
│                                                                         │
│  Therefore: c1 > c2 at termination is UNSAT by symmetry.              │
│  And:       c2 > c1 at termination is ALSO UNSAT (same reason).       │
│                                                                         │
│  Confirmation: Check 2 (c2 > c1) returned UNSAT in 2.2s.              │
│  SYMMETRIC! This should have been the early warning sign.              │
│                                                                         │
│  The proof says nothing about monotonicity.                             │
│  It says "symmetric systems can't have asymmetric outcomes."            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 10: Three Types of Vacuity

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     VACUITY TAXONOMY                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  TYPE 1: ABSTRACT HIT (Dijkstra)                                        │
│     HIT = MISS = dv' >= 0 (identical transitions)                      │
│     Costs stuck at 0 through termination                                │
│     Detection: output > 0 at terminal → UNSAT                         │
│                                                                         │
│  TYPE 2: UNFORCED HIT (Kruskal async)      ← NEW                      │
│     HIT is explicit (c1' = c1 + wk1) BUT optional                     │
│     MISS subsumes HIT (c1' >= c1 includes c1' = c1 + wk1)             │
│     Costs DO grow, but identically in both runs (symmetric)            │
│     Precondition wk1 <= wk2 is dead                                   │
│     Detection: output >= 0 at terminal → SAT (PASSES!)                │
│     Detection: remove HIT → still UNSAT                                │
│     Detection: remove precondition → still UNSAT                       │
│                                                                         │
│  GENUINE (ArraySum, ArrayMax)                                           │
│     HIT is explicit AND forced (i = k guard)                           │
│     MISS does NOT subsume HIT (different guards)                       │
│     Precondition wk1 <= wk2 is alive (flows through HIT)              │
│     Detection: remove HIT → SAT (property needs it)                   │
│     Detection: remove precondition → SAT (property needs it)           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Why Type 2 is sneaky:** The standard sanity check (`c1 >= 0` SAT) catches Type 1 but NOT Type 2. Kruskal's costs genuinely grow (c1 = 0 at terminal is UNSAT after 18 minutes). The encoding has non-trivial states. It just doesn't use the monotonicity precondition.

---

## Part 11: The Updated Sanity Check Recipe

```
AFTER GETTING UNSAT:

Step 1: output >= 0 at termination → expected SAT
        If UNSAT: Type 1 vacuity (Dijkstra-style). STOP.

Step 2: Check for symmetry warning signs
        - Is UNSAT suspiciously fast? (2s for 8-variable async)
        - Does the reverse violation (c2 > c1) also return UNSAT?
        If both true: suspect Type 2 vacuity. Proceed to Step 3.

Step 3: Remove precondition (wk1 <= wk2) from init, re-run violation.
        If still UNSAT: Type 2 vacuity (precondition dead). STOP.
        If SAT: precondition is alive. GENUINELY VERIFIED.

Optional: Remove HIT entirely, re-run violation.
        If still UNSAT: confirms HIT is irrelevant (Type 2).
        If SAT: confirms HIT matters (genuine).
```

### Applied to All Encodings

| Algorithm | Step 1 | Step 2 | Step 3 | Verdict |
|-----------|--------|--------|--------|---------|
| **ArraySum** | `s1 >= 0` SAT ✓ | 47s (not fast), `s2 > s1` UNSAT (but expected for wk1=wk2) | Would give SAT | **GENUINE** |
| **ArrayMax** | `m1 >= 0` SAT ✓ | 8m35s (not fast) | Would give SAT | **GENUINE** |
| **Dijkstra** | `dv1 > 0` UNSAT ✗ | — | — | **Type 1 vacuous** |
| **Kruskal async** | `c1 >= 0` SAT ✓ | 2s (fast!), `c2 > c1` UNSAT (symmetric!) | UNSAT (dead) | **Type 2 vacuous** |

---

## Part 12: Comparison — Async Kruskal vs Sync Kruskal

| Aspect | Synchronized | Asynchronous |
|--------|-------------|--------------|
| **Counters** | 1 (`i`) | 2 (`i1, i2`) |
| **Variables** | 7 | 8 |
| **Monotone bound** | `c1' <= c2'` explicit | None |
| **HIT forced?** | N/A (sync processes same edge) | **No** (no position guard) |
| **MISS subsumes HIT?** | N/A (bound constrains MISS) | **Yes** |
| **Precondition alive?** | **Yes** (flows through bound) | **No** (dead) |
| **Result** | **GENUINE** | **VACUOUS** |
| **Solver time** | Fast | 2s (trivial by symmetry) |

### Why Sync Works

In the synchronized model, both runs process the **same edge** at each step. The monotone bound `c1' <= c2'` is stated explicitly as a transition constraint. It encodes the universal precondition: "every edge weight in G1 ≤ corresponding in G2."

This bound makes the precondition alive at every step. The invariant is trivially `c1 ≤ c2`.

### Why Async Fails

In the async model, there's no monotone bound (c1 ≤ c2 breaks mid-execution). Without the bound, the only constraint on costs comes from the transitions. Without a position guard, MISS subsumes HIT, and both runs have identical constraints. The precondition has nowhere to enter the proof.

---

## Part 13: Structural Criterion for Genuine Async Monotonicity

```
┌─────────────────────────────────────────────────────────────────────────┐
│           THREE REQUIREMENTS FOR GENUINE ASYNC MONOTONICITY              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. EXPLICIT HIT                                                        │
│     HIT must compute something concrete:                                │
│       ✓  s1' = s1 + wk1        (ArraySum)                              │
│       ✓  m1' = max(m1, wk1)    (ArrayMax)                              │
│       ✓  c1' = c1 + wk1        (Kruskal — this IS explicit)           │
│       ✗  dv1' >= 0              (Dijkstra — abstract, same as MISS)    │
│                                                                         │
│  2. POSITION GUARD (i = k)                                              │
│     HIT must be FORCED at exactly one step:                             │
│       ✓  i1 = k → must use HIT  (ArraySum, ArrayMax)                  │
│       ✓  i1 ≠ k → must use MISS (ArraySum, ArrayMax)                  │
│       ✗  No guard — HIT optional (Kruskal async)                      │
│                                                                         │
│     Requires: counter tracks SCAN POSITION, not derived quantity.       │
│     ArraySum: i = position being scanned (0, 1, ..., n-1)  ✓          │
│     Kruskal:  i = edges added (not positions scanned)       ✗          │
│                                                                         │
│  3. NON-DECREASING MISS                                                 │
│     MISS must give solver useful info:                                  │
│       ✓  s1' >= s1    (ArraySum — non-negative elements)               │
│       ✓  m1' >= m1    (ArrayMax — max never decreases)                 │
│       ✓  c1' >= c1    (Kruskal — non-negative weights)                │
│       ~  dv1' >= 0    (Dijkstra — too loose, no upper bound)           │
│                                                                         │
│  SCORE CARD:                                                            │
│     ArraySum:      ✓ ✓ ✓  → GENUINE                                   │
│     ArrayMax:      ✓ ✓ ✓  → GENUINE                                   │
│     Kruskal async: ✓ ✗ ✓  → VACUOUS (fails requirement 2)             │
│     Dijkstra:      ✗ ✗ ~  → VACUOUS (fails requirements 1 and 2)      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 14: Could We Fix the Async Kruskal Encoding?

### Option A: Add a Scan Counter

Track WHICH edge is being considered (j), separate from edges added (i):

```prolog
Inv(i1, i2, j1, j2, k, wk1, wk2, c1, c2, n, m)
(* j = edges considered (0..m-1), i = edges added (0..n-2) *)
(* HIT guard: j1 = k *)
```

This adds 3 variables (j1, j2, m — total edges), making it an 11-variable encoding. The HIT guard `j1 = k` would force HIT at exactly one step, preventing MISS from subsuming it.

**Downside:** More variables means slower solving. And we need to know the total number of edges `m`, which is separate from `n` (vertices).

### Option B: Use the Synchronized Model

The sync model already works perfectly for Kruskal. Both runs process edges in the same order and make the same add/skip decisions (union-find is weight-independent). The monotone bound `c1' <= c2'` holds at every step.

**This is the pragmatic choice.** Async Kruskal adds complexity without benefit.

### When Does Async Matter?

Async is needed when the two runs might take **different paths** through the algorithm — different iteration orders or different branch decisions depending on input values. For Kruskal, this doesn't happen (union-find is weight-independent). For algorithms where data-dependent branching changes iteration order, async would be necessary — but those algorithms also make cell morphing harder in general.

---

## Part 15: The Early Warning Signs (In Retrospect)

Looking back, there were clues that the result was vacuous:

1. **Suspiciously fast:** 2 seconds for an 8-variable async encoding, when ArraySum (same variables) takes 47s. Why would MORE disjuncts (4 cases vs 3) be FASTER?

2. **Symmetric violation and reverse:** Both `c1 > c2` and `c2 > c1` returned UNSAT in ~2s. For ArraySum, `s1 > s2` is UNSAT (47s) but `s2 > s1` is also UNSAT (4:23) — this is expected because `wk1 = wk2` makes equality possible. But for Kruskal, the identical speed suggests the proof doesn't use the asymmetry of the precondition.

3. **No position guard in the encoding:** The transitions have no `i = k` condition. This should have immediately raised the question: when is HIT forced?

**Lesson: "Suspiciously fast" is itself a diagnostic signal.** When an encoding verifies much faster than structurally similar ones, investigate why before celebrating.

---

## Part 16: Visual Summary

```
┌─────────────────────────────────────────────────────────────────────────┐
│          KRUSKAL ASYNC MONOTONICITY — VACUITY EXPOSED                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  INPUT: Graphs G1, G2 with w1[e] ≤ w2[e] for all e                    │
│                                                                         │
│  Distinguished edge k: wk1 = w1[k], wk2 = w2[k]                       │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │  PRECONDITION: 0 ≤ wk1 ≤ wk2   ← DEAD (never used!)       │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                           │                                             │
│                           ▼                                             │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │                  Kruskal ALGORITHM                           │       │
│  │                                                              │       │
│  │  For each edge:                                              │       │
│  │    if different components: ADD (cost += w[e])               │       │
│  │    else: SKIP                                                │       │
│  │                                                              │       │
│  │    ┌─────────────────────────────────────────────┐          │       │
│  │    │ HIT ADD (no guard — OPTIONAL):              │          │       │
│  │    │   c1' = c1 + wk1                            │          │       │
│  │    │   But MISS ADD (c1' >= c1) includes this!   │          │       │
│  │    │   → Solver ignores HIT entirely             │          │       │
│  │    ├─────────────────────────────────────────────┤          │       │
│  │    │ MISS ADD (no guard — ALWAYS AVAILABLE):     │          │       │
│  │    │   c1' >= c1      c2' >= c2                  │          │       │
│  │    │   SYMMETRIC! Same constraint for both runs. │          │       │
│  │    │   → Proof by symmetry, not monotonicity.    │          │       │
│  │    └─────────────────────────────────────────────┘          │       │
│  │                                                              │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                           │                                             │
│                           ▼                                             │
│  OUTPUT: cost(MST_1) and cost(MST_2)                                    │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │  POSTCONDITION: cost(MST_1) ≤ cost(MST_2)                   │       │
│  │                                                              │       │
│  │  UNSAT in 2s — BUT VACUOUS!                                 │       │
│  │    c1 > c2 UNSAT by symmetry (not by monotonicity)          │       │
│  │    c2 > c1 ALSO UNSAT (same reason!)                        │       │
│  │    Precondition dead. HIT irrelevant.                        │       │
│  │                                                              │       │
│  │  Use SYNCHRONIZED model instead.                             │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 17: Key Takeaways

1. **Kruskal async monotonicity is vacuous.** The UNSAT result (2s) proves nothing about monotonicity. The precondition `wk1 ≤ wk2` is dead. Use the synchronized model instead.

2. **New vacuity type discovered: MISS-subsumes-HIT.** When HIT has no position guard (`i = k`), MISS absorbs it. The solver uses MISS everywhere, making the runs symmetric. The precondition dies.

3. **The standard sanity check is insufficient.** `output >= 0` SAT catches Dijkstra-style vacuity (costs at 0) but NOT Kruskal-style vacuity (symmetric growth). Need deeper tests: remove HIT, remove precondition.

4. **Position guard is the structural criterion.** For genuine async monotonicity, the counter must track SCAN POSITION (not edges added, not relaxation steps). Only `i = k` creates a hard partition forcing HIT at exactly one step.

5. **"Suspiciously fast" is a diagnostic signal.** When an 8-variable async encoding solves in 2s but similar encodings take 47s–8m, investigate before celebrating.

6. **Systematic diagnosis works.** The diagnostic chain (no-SKIP → bounded k → lockstep test → no-HIT → no-precondition) methodically eliminated hypotheses until the root cause was found. This is the right methodology for investigating suspicious results.

7. **Negative results teach more than easy positives.** The Kruskal async failure sharpened our understanding of what makes cell morphing work: explicit HIT, position guard, non-decreasing MISS. All three are needed.

8. **The sync model is correct for Kruskal.** Union-find decisions are weight-independent, so both runs process the same edge set. The sync model captures this perfectly with the explicit monotone bound `c1' <= c2'`.

---

*Verdict: Async UNSAT (2s) is VACUOUS — precondition dead, proof by symmetry. Sync model is the correct approach. Diagnostic chain: no-SKIP (2s) → bounded k (2.7s) → lockstep UNSAT (7s) → no-HIT UNSAT (6s) → no-precondition UNSAT (16s). New vacuity type documented: MISS-subsumes-HIT, not caught by standard output >= 0 check.*
