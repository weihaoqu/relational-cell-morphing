# Kruskal MST Monotonicity: Sync Works, Async Fails — A Debugging Case Study

A tutorial on verifying monotonicity of Kruskal's MST cost using relational cell morphing. The synchronized model succeeds trivially. The asynchronous model appears to succeed but is vacuous — and discovering why revealed a new failure mode with implications for all future encodings.

---

## Verification Results

### Synchronized Model (single counter) — GENUINE ✓

| Goal | Result | Time | Meaning |
|------|--------|------|---------|
| `c1 > c2` | **UNSAT** | fast | **Monotonicity VERIFIED ✓** |
| `c1 <= c2` | **SAT** | fast | Bound achievable ✓ |

### Asynchronous Model (two counters + scheduler) — VACUOUS ✗

| Goal | Result | Time | Meaning |
|------|--------|------|---------|
| `c1 > c2` at termination | **UNSAT** | 2s | Looks verified... but vacuous |
| `c1 >= 0` at termination | **SAT** | 8s | Standard sanity check **passes** |
| `c2 > c1` at termination | **UNSAT** | 2.2s | Symmetric with violation (warning!) |
| `n > 0` at termination | **SAT** | 22s | Non-vacuity check **passes** |
| Mid-exec `c1 > c2` | **SAT** | 22.5s | Vacuous SAT (TT-only schedule) |

### Diagnostic Chain — Proved Async is Vacuous

| Test | Result | Time | What it tells us |
|------|--------|------|-----------------|
| No-SKIP variant | UNSAT | 2s | SKIP is not the factor |
| Add `k < n-1` | UNSAT | 2.7s | Bounded k is not the factor |
| `i1 = i2` mid-exec | UNSAT | 7s | Runs CAN desynchronize |
| `c1 > 0` terminal | UNSAT | 1s | Not universal (wk1=0 case) |
| `c1 = 0` terminal | UNSAT | 18m | Costs not universally zero |
| **NO-HIT variant** | **UNSAT** | **6s** | **HIT is irrelevant!** |
| **Remove `wk1 ≤ wk2`** | **UNSAT** | **16s** | **Precondition is dead!** |

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

1. **Processes edges in sorted order**: Fixed iteration order, independent of weight values
2. **Add/skip decision depends on union-find**: Same components → skip, different → add
3. **Union-find is weight-independent**: The STRUCTURE of the MST depends only on which edges connect different components — not on their weights
4. **Cost is a running sum**: `cost' = cost + w[e]` when an edge is added
5. **MST has exactly n-1 edges**: For n vertices, the loop adds exactly n-1 edges

### The Critical Insight for Encoding Design

```
Kruskal counter tracks EDGES ADDED (0, 1, ..., n-2)
                  NOT edges SCANNED

This distinction will matter enormously for the async model.
```

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
```

### Why Is This True? (Informal Argument)

```
Key fact: Union-find decisions depend on WHICH edges were added,
          not their WEIGHTS.

Both runs process edges in the same sorted order.
At each step, both runs see the same union-find state.
Therefore both runs make the SAME add/skip decision.
Therefore both MSTs contain the SAME set of edges.

cost(MST_1) = Σ_{e∈MST} w1[e]
            ≤ Σ_{e∈MST} w2[e]     (w1[e] ≤ w2[e] for each edge)
            = cost(MST_2)

QED.
```

The argument depends on both runs choosing the same edges. This is why the synchronized model is natural for Kruskal.

### Example

```
Edges sorted by weight:   e1  e2  e3  e4  e5  e6
Run 1 weights:             1   2   3   4   5   6
Run 2 weights:             2   3   4   5   6   7
Pointwise: 1≤2, 2≤3, 3≤4, 4≤5, 5≤6, 6≤7  ✓

Both runs:  ADD  ADD  SKIP  ADD  SKIP  ADD   (same decisions!)
              ↑    ↑          ↑          ↑
MST edges: {e1, e2, e4, e6}  (same set)

cost_1 = 1 + 2 + 4 + 6 = 13
cost_2 = 2 + 3 + 5 + 7 = 17
Result: 13 ≤ 17  ✓
```

---

## Part 3: How Kruskal Compares to ArraySum

Both are monotonicity proofs using cell morphing. Same framework, different algorithms.

| Aspect | ArraySum | Kruskal |
|--------|----------|---------|
| Update | `s += A[i]` (every element) | `cost += w[e]` (only when added) |
| Skip? | Never — every element processed | Yes — edges can be skipped |
| Counter means | Position scanned (0..n-1) | Edges added (0..n-2) |
| HIT guard | `i = k` (forced at one step) | None in async (see Part 9) |
| Sync valid? | Yes (fixed scan order) | **Yes** (weight-independent decisions) |
| Async valid? | Yes (genuine, 47s) | **Vacuous** (see Part 9) |

---

# PART A: SYNCHRONIZED MODEL (GENUINE)

---

## Part 4: Why Synchronized Works for Kruskal

Both runs process edges in the **same fixed order** and make the **same add/skip decisions** because union-find is weight-independent. When both runs always act identically, a single counter suffices.

The critical advantage: when both runs ADD the same edge simultaneously, we can assert `c1' <= c2'` because:

```
Both ADD distinguished edge k:     c1' = c1 + wk1 ≤ c2 + wk2 = c2'
                                    ↑               ↑
                                  c1 ≤ c2      wk1 ≤ wk2
                                (induction)   (precondition)

Both ADD other edge (same edge!):   c1' = c1 + w1[e] ≤ c2 + w2[e] = c2'
                                     ↑                  ↑
                                   c1 ≤ c2         w1[e] ≤ w2[e]
                                 (induction)    (universal precondition)

Both SKIP:                          c1' = c1 ≤ c2 = c2'   trivially
```

The monotone bound `c1' <= c2'` holds at every transition. The invariant is simply `c1 ≤ c2`.

---

## Part 5: Synchronized State Variables

```
Inv(i, k, wk1, wk2, c1, c2, n)
```

| Variable | Type | Meaning | Changes? |
|----------|------|---------|----------|
| `i` | int | Edges added to MST (both runs) | Yes (0 → n-1) |
| `k` | int | Distinguished edge index | **Never** |
| `wk1` | real | Weight of edge k in G1 | **Never** |
| `wk2` | real | Weight of edge k in G2 | **Never** |
| `c1` | real | MST cost in run 1 | Yes (non-decreasing) |
| `c2` | real | MST cost in run 2 | Yes (non-decreasing) |
| `n` | int | Number of vertices | **Never** |

**7 variables.** The leanest encoding in our portfolio.

### What's Missing Compared to Kruskal Robustness (11 variables)

| Dropped | Why |
|---------|-----|
| `i2` | Synchronized — single counter |
| `bk:bool` | Direction known: wk1 ≤ wk2 |
| `bc:bool` | Direction known: c1 ≤ c2 |
| `eps` | No quantitative bound |

---

## Part 6: Synchronized Encoding

### Initialization

```prolog
Inv(i, k, wk1, wk2, c1, c2, n) :-
    i = 0,
    n > 0,
    0 <= k,
    (* Monotone precondition *)
    wk1 <= wk2,
    c1 = 0, c2 = 0.
```

### Transition

```prolog
Inv(i', k, wk1, wk2, c1', c2', n) :-
    Inv(i, k, wk1, wk2, c1, c2, n),
    (
        (* Case 1: HIT ADD — both add distinguished edge k *)
        i < n - 1 and i' = i + 1 and
        c1' = c1 + wk1 and c2' = c2 + wk2
    ) or (
        (* Case 2: MISS ADD — both add other edge *)
        (* Weights unknown; constrained by monotone bound below *)
        i < n - 1 and i' = i + 1
    ) or (
        (* Case 3: SKIP — both skip current edge *)
        i < n - 1 and i' = i and c1' = c1 and c2' = c2
    ) or (
        (* Case 4: FINISHED — stutter *)
        i >= n - 1 and i' = i and c1' = c1 and c2' = c2
    ),
    (* MONOTONE BOUND — holds at every step *)
    c1' <= c2'.
```

### Case-by-Case Analysis

**Case 1: HIT ADD — Both add distinguished edge k**

```prolog
i < n - 1 and i' = i + 1 and c1' = c1 + wk1 and c2' = c2 + wk2
```

Exact weights known. Monotone bound: `c1 + wk1 ≤ c2 + wk2` holds when `c1 ≤ c2` (invariant) and `wk1 ≤ wk2` (precondition). ✓

**Case 2: MISS ADD — Both add another edge**

```prolog
i < n - 1 and i' = i + 1
```

Weights unknown. `c1'` and `c2'` are unconstrained except by the monotone bound `c1' <= c2'` below. The bound encodes the universal precondition: both runs add the **same** edge, and `w1[e] ≤ w2[e]`.

**Case 3: SKIP — Both skip**

```prolog
i < n - 1 and i' = i and c1' = c1 and c2' = c2
```

Costs unchanged, counter unchanged. Trivially `c1' ≤ c2'`. ✓

**Case 4: FINISHED — Stutter**

```prolog
i >= n - 1 and i' = i and c1' = c1 and c2' = c2
```

All n-1 edges added. State unchanged. ✓

### The Monotone Bound

```prolog
c1' <= c2'.
```

This single line plays the same structural role as the epsilon bound in robustness:

```
Robustness:    (bc' and 0 <= c2'-c1' and c2'-c1' <= i1'*eps) or
               (!bc' and 0 <= c1'-c2' and c1'-c2' <= i1'*eps)
                              ↓
Monotonicity:  c1' <= c2'
```

Both encode the universal input precondition. The robustness version requires sign bits and a quantitative bound. The monotonicity version is a single inequality.

### Goal

```prolog
(* Violation: UNSAT = monotonicity verified *)
c1 > c2 :-
    Inv(i, k, wk1, wk2, c1, c2, n),
    n - 1 <= i.
```

**Result: UNSAT (fast).** The invariant is trivially `c1 ≤ c2`:

1. **Init establishes it**: `c1 = 0 = c2` ✓
2. **Transitions preserve it**: `c1' ≤ c2'` stated explicitly ✓
3. **Goal contradicts it**: `c1 > c2` contradicts `c1 ≤ c2` ✓

---

## Part 7: Why the Monotone Bound Is Sound

```
┌─────────────────────────────────────────────────────────────────────────┐
│               WHY c1' <= c2' AT EVERY STEP                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Both runs process the SAME edge at each step (synchronized).          │
│  Both make the SAME decision (union-find is weight-independent).       │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │ HIT ADD (both add edge k):                                   │       │
│  │   c1' = c1 + wk1                                            │       │
│  │   c2' = c2 + wk2                                            │       │
│  │   c1 ≤ c2 (invariant) and wk1 ≤ wk2 (precondition)         │       │
│  │   → c1 + wk1 ≤ c2 + wk2                                    │       │
│  │   → c1' ≤ c2'  ✓                                           │       │
│  ├─────────────────────────────────────────────────────────────┤       │
│  │ MISS ADD (both add same other edge e):                       │       │
│  │   c1' = c1 + w1[e]                                          │       │
│  │   c2' = c2 + w2[e]                                          │       │
│  │   c1 ≤ c2 (invariant) and w1[e] ≤ w2[e] (universal precond)│       │
│  │   → c1 + w1[e] ≤ c2 + w2[e]                                │       │
│  │   → c1' ≤ c2'  ✓                                           │       │
│  ├─────────────────────────────────────────────────────────────┤       │
│  │ SKIP (both skip):                                            │       │
│  │   c1' = c1, c2' = c2                                        │       │
│  │   → c1' ≤ c2'  (trivially)  ✓                              │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                                                                         │
│  KEY: The synchronized model guarantees both runs process the           │
│  same edge. This means the universal precondition (w1[e] ≤ w2[e])     │
│  applies to the SAME element in both runs at every step.               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

# PART B: ASYNCHRONOUS MODEL (VACUOUS)

---

## Part 8: Why Try Asynchronous?

The synchronized model works. So why try async?

1. **Consistency**: ArraySum and ArrayMax were verified in async. Can Kruskal be too?
2. **Stronger result**: Async proves monotonicity under ALL interleavings, not just lockstep
3. **Research question**: The sync model requires both runs to process the same edge at each step. What if we relax this assumption?

The async model turned out to be vacuous — but discovering this was more valuable than a positive result.

---

## Part 9: The Critical Structural Difference

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
│     MISS SUBSUMES HIT.                                                  │
│     Every HIT trace is also a valid MISS trace.                        │
│     The solver has no reason to use HIT.                                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

This was not obvious when we wrote the encoding. The async model looked structurally similar to ArraySum. The difference only emerged through systematic diagnostic testing.

---

## Part 10: Asynchronous State Variables

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

**8 variables.** One more than synchronized (the extra counter).

---

## Part 11: Asynchronous Encoding

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
```

### Key Difference: No Monotone Bound, No Position Guard

```
Synchronized:   ...), c1' <= c2'.        ← bound present
Asynchronous:   ...).                     ← NO bound

ArraySum:       i1 = k and s1' = s1 + wk1   ← position guard
Kruskal async:  c1' = c1 + wk1              ← no guard (any step)
```

### FT Transition — Only Run 2 Steps

```prolog
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
```

### TT Transition — Both Step

```prolog
Inv(i1', i2', k, wk1, wk2, c1', c2', n) :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    SchTT(i1, i2, k, wk1, wk2, c1, c2, n),
    (* Run 1 *)
    (
        i1 < n - 1 and i1' = i1 + 1 and c1' = c1 + wk1
    ) or (
        i1 < n - 1 and i1' = i1 + 1 and c1' >= c1
    ) or (
        i1 < n - 1 and i1' = i1 and c1' = c1
    ) or (
        i1 >= n - 1 and i1' = i1 and c1' = c1
    ),
    (* Run 2 *)
    (
        i2 < n - 1 and i2' = i2 + 1 and c2' = c2 + wk2
    ) or (
        i2 < n - 1 and i2' = i2 + 1 and c2' >= c2
    ) or (
        i2 < n - 1 and i2' = i2 and c2' = c2
    ) or (
        i2 >= n - 1 and i2' = i2 and c2' = c2
    ).
```

### Scheduler and Fairness

```prolog
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
```

Standard pattern, identical to all previous async encodings.

### Goal

```prolog
c1 > c2 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2.
```

**Result: UNSAT in 2 seconds.**

At this point we were excited — 23x faster than ArraySum! But 2 seconds turned out to be a warning sign.

---

## Part 12: Initial Sanity Checks — Everything Looks Fine

Following the established recipe from the ArraySum/Dijkstra sessions:

| # | Goal | Result | Time | Interpretation |
|---|------|--------|------|----------------|
| 1 | `c1 >= 0` at termination | **SAT** | 8s | Non-vacuous ✓ |
| 2 | `c2 > c1` at termination | UNSAT | 2.2s | Not universal (expected) |
| 3 | `n > 0` at termination | **SAT** | 22s | Non-vacuous ✓ |
| 4 | `c1 > c2` mid-exec (i1>i2) | SAT | 22.5s | Vacuous SAT (TT-only) |

The `c1 >= 0` SAT check passes. The `n > 0` SAT check passes. By the recipe we developed from ArraySum, this encoding should be genuine.

But **2 seconds was suspicious.** ArraySum takes 47s with the same variable count. ArrayMax takes 8m 35s. Why would Kruskal — with MORE disjuncts per transition (4 cases vs 3) — be faster?

---

## Part 13: The Investigation — Five Hypotheses

### Hypothesis 1: SKIP Enables Implicit Synchronization

The idea: SKIP lets one run idle while the other catches up, effectively recovering a synchronized invariant.

**Test: Remove SKIP from all transitions.**

| Variant | Result | Time |
|---------|--------|------|
| With SKIP (original) | UNSAT | 2s |
| Without SKIP | UNSAT | 2s |

**Verdict: SKIP is not the factor.**

### Hypothesis 2: Unbounded k Lets Solver Avoid HIT

Original init has `0 <= k` with no upper bound. If the solver picks `k ≥ n-1`, HIT never fires.

**Test: Add `k < n - 1` to init.**

| Variant | Result | Time |
|---------|--------|------|
| Unbounded k | UNSAT | 2s |
| `k < n - 1` | UNSAT | 2.7s |

**Verdict: Bounded k is not the factor.**

### Hypothesis 3: Solver Uses Lockstep Schedule

Maybe the solver forces `i1 = i2` at all times (implicit synchronization without SKIP).

**Test: Is `i1 = i2` universally true mid-execution?**

```prolog
i1 = i2 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    i1 < n - 1.
```

**Result: UNSAT (7s)** — not universal. Runs CAN desynchronize.

**Verdict: Lockstep hypothesis killed.**

### Hypothesis 4: MISS Subsumes HIT — THE BREAKTHROUGH

Since MISS ADD (`c1' >= c1`) includes all behaviors of HIT ADD (`c1' = c1 + wk1` with `wk1 >= 0`), maybe HIT is irrelevant.

**Test: Remove HIT ADD from all transitions. Keep only MISS ADD, SKIP, FINISHED.**

| Variant | Result | Time |
|---------|--------|------|
| With HIT (original) | UNSAT | 2s |
| **Without HIT** | **UNSAT** | **6s** |

**HIT is irrelevant.** The solver never needed the exact `c1 + wk1` contribution.

### Hypothesis 5: Precondition Is Dead — THE CONFIRMATION

If HIT is irrelevant, then `wk1` and `wk2` are dead variables. The precondition `wk1 <= wk2` should be dead too.

**Test: Remove `0 <= wk1, wk1 <= wk2` from init. Keep everything else identical.**

| Variant | Result | Time |
|---------|--------|------|
| With precondition | UNSAT | 2s |
| **Without precondition** | **UNSAT** | **16s** |

**The precondition is dead. The UNSAT is vacuous.**

---

## Part 14: Root Cause — Symmetry, Not Monotonicity

With HIT irrelevant, the only transition affecting costs is MISS ADD:

```
Run 1 at any ADD step:  c1' >= c1   (non-decreasing)
Run 2 at any ADD step:  c2' >= c2   (non-decreasing)
```

These are **structurally identical.** The solver sees two copies of the same abstract process.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    THE SYMMETRY ARGUMENT                                 │
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

## Part 15: Three Types of Vacuity

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     VACUITY TAXONOMY                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  TYPE 1: ABSTRACT HIT (Dijkstra)                                        │
│     HIT = MISS = dv' >= 0 (identical transitions)                      │
│     Costs stuck at 0 through termination                                │
│     Detection: output > 0 at terminal → UNSAT (stuck at 0)            │
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
│  KEY: Type 2 is SNEAKY — it passes the standard sanity check!         │
│  Costs genuinely grow (c1 = 0 UNSAT after 18m).                       │
│  The encoding has non-trivial states.                                   │
│  It just doesn't use the monotonicity precondition.                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 16: The Updated Sanity Check Recipe

```
AFTER GETTING UNSAT:

Step 1: output >= 0 at termination → expected SAT
        If UNSAT: Type 1 vacuity (Dijkstra-style). STOP.

Step 2: Check for symmetry warning signs
        - Is UNSAT suspiciously fast?
        - Does the reverse violation (c2 > c1) also return UNSAT
          with similar speed?
        If both: suspect Type 2 vacuity. Proceed to Step 3.

Step 3: Remove precondition (wk1 <= wk2) from init, re-run.
        If still UNSAT: Type 2 vacuity (precondition dead). STOP.
        If SAT: precondition is alive. GENUINELY VERIFIED. ✓

Optional: Remove HIT from all transitions, re-run.
        If still UNSAT: confirms HIT irrelevant (Type 2).
        If SAT: confirms HIT matters (genuine).
```

### Applied to All Encodings

| Algorithm | Step 1 | Step 2 | Step 3 | Verdict |
|-----------|--------|--------|--------|---------|
| ArraySum | `s1>=0` SAT ✓ | 47s, not suspicious | Would give SAT | **GENUINE ✓** |
| ArrayMax | `m1>=0` SAT ✓ | 8m35s, not suspicious | Would give SAT | **GENUINE ✓** |
| Dijkstra | `dv1>0` UNSAT ✗ | — | — | **Type 1 vacuous ✗** |
| Kruskal sync | bound explicit | — | — | **GENUINE ✓** |
| Kruskal async | `c1>=0` SAT ✓ | 2s + symmetric! | UNSAT (dead!) | **Type 2 vacuous ✗** |

---

## Part 17: Structural Criterion — Position Guard Required

```
┌─────────────────────────────────────────────────────────────────────────┐
│     THREE REQUIREMENTS FOR GENUINE ASYNC MONOTONICITY                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. EXPLICIT HIT                                                        │
│     HIT must compute something concrete:                                │
│       ✓  s1' = s1 + wk1        (ArraySum)                              │
│       ✓  m1' = max(m1, wk1)    (ArrayMax)                              │
│       ✓  c1' = c1 + wk1        (Kruskal — explicit, but...)           │
│       ✗  dv1' >= 0              (Dijkstra — abstract = MISS)           │
│                                                                         │
│  2. POSITION GUARD (i = k)                                              │
│     HIT must be FORCED at exactly one step:                             │
│       ✓  i1 = k → HIT; i1 ≠ k → MISS   (ArraySum, ArrayMax)         │
│       ✗  No guard — HIT optional          (Kruskal async)              │
│                                                                         │
│     Requires: counter tracks SCAN POSITION, not derived quantity        │
│       ✓  ArraySum: i = position scanned (0..n-1)                       │
│       ✗  Kruskal:  i = edges added (0..n-2)                            │
│                                                                         │
│  3. NON-DECREASING MISS                                                 │
│     MISS must give solver useful info:                                  │
│       ✓  s1' >= s1    (ArraySum)                                       │
│       ✓  m1' >= m1    (ArrayMax)                                       │
│       ✓  c1' >= c1    (Kruskal)                                        │
│       ~  dv1' >= 0    (Dijkstra — too loose)                           │
│                                                                         │
│  SCORECARD:                                                             │
│     ArraySum:      ✓ ✓ ✓  → GENUINE                                   │
│     ArrayMax:      ✓ ✓ ✓  → GENUINE                                   │
│     Kruskal async: ✓ ✗ ✓  → VACUOUS (fails #2)                        │
│     Dijkstra:      ✗ ✗ ~  → VACUOUS (fails #1 and #2)                 │
│     Kruskal sync:  ✓ n/a ✓ → GENUINE (sync doesn't need #2)           │
│                                                                         │
│  NOTE: Requirement #2 applies ONLY to async encodings.                  │
│  Sync encodings use the monotone bound instead.                         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 18: Sync vs Async — Side-by-Side Comparison

| Aspect | Synchronized | Asynchronous |
|--------|-------------|--------------|
| **Counters** | 1 (`i`) | 2 (`i1, i2`) |
| **Variables** | 7 | 8 |
| **Scheduler** | None | SchTF, SchFT, SchTT + fairness |
| **Monotone bound** | `c1' <= c2'` explicit | None |
| **HIT forced?** | N/A (both process same edge) | **No** (no position guard) |
| **MISS subsumes HIT?** | N/A (bound constrains MISS) | **Yes** |
| **Precondition alive?** | **Yes** (flows through bound) | **No** (dead) |
| **Result** | **GENUINE ✓** | **VACUOUS ✗** |
| **Solver time** | Fast | 2s (trivial by symmetry) |
| **Proves** | Monotonicity for lockstep | Nothing (symmetry, not monotonicity) |

### Why Sync Succeeds Where Async Fails

The synchronized model processes the **same edge** in both runs at each step. The monotone bound `c1' <= c2'` is a valid transition constraint because:

- HIT ADD: both add edge k → `c1 + wk1 ≤ c2 + wk2` (from invariant + precondition)
- MISS ADD: both add same edge e → `c1 + w1[e] ≤ c2 + w2[e]` (from invariant + universal precondition)

This bound makes the precondition **alive** at every step. The invariant is trivially `c1 ≤ c2`.

The async model cannot use this bound (c1 ≤ c2 breaks mid-execution when runs are at different indices). Without the bound, the precondition has no path into the proof. Without a position guard (`i = k`) to force HIT, the solver ignores it entirely.

---

## Part 19: The Early Warning Signs (In Retrospect)

```
┌─────────────────────────────────────────────────────────────────────────┐
│              WARNING SIGNS WE SHOULD HAVE CAUGHT EARLIER                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. SUSPICIOUSLY FAST                                                   │
│     2 seconds for an 8-variable async encoding.                        │
│     ArraySum (same variables): 47 seconds.                              │
│     ArrayMax (same variables): 8 minutes 35 seconds.                   │
│     Kruskal has MORE disjuncts (4 cases vs 3). Should be SLOWER.       │
│     → "Faster than it should be" = investigate.                        │
│                                                                         │
│  2. SYMMETRIC RESULTS                                                   │
│     c1 > c2 at terminal: UNSAT, 2.0s                                  │
│     c2 > c1 at terminal: UNSAT, 2.2s                                  │
│     Nearly identical speeds for violation and reverse!                  │
│     For ArraySum: s1 > s2 UNSAT (47s) vs s2 > s1 UNSAT (4:23).       │
│     The asymmetry in ArraySum reflects the precondition doing work.    │
│     The symmetry in Kruskal reflects the precondition NOT doing work.  │
│     → Similar-speed violation and reverse = suspect symmetry.          │
│                                                                         │
│  3. NO POSITION GUARD IN THE ENCODING                                  │
│     Looking at the transitions: no i = k condition anywhere.           │
│     This should immediately raise: "when is HIT forced?"              │
│     → No position guard = MISS can subsume HIT.                       │
│                                                                         │
│  LESSON: These are now part of our checklist.                           │
│  "Suspiciously fast" is itself a diagnostic signal.                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 20: Visual Summary

```
┌─────────────────────────────────────────────────────────────────────────┐
│      KRUSKAL MST MONOTONICITY — SYNC vs ASYNC                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  INPUT: Graphs G1, G2 with w1[e] ≤ w2[e] for all edges e              │
│                                                                         │
│  SYNCHRONIZED MODEL:                                                    │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │  Both runs process SAME edge, make SAME add/skip decision    │       │
│  │                                                              │       │
│  │  Monotone bound c1' <= c2' at EVERY step:                   │       │
│  │    HIT:  c1+wk1 ≤ c2+wk2  (c1≤c2 + wk1≤wk2)              │       │
│  │    MISS: c1+w1e ≤ c2+w2e  (c1≤c2 + w1e≤w2e)               │       │
│  │    SKIP: c1 ≤ c2          (trivially)                       │       │
│  │                                                              │       │
│  │  Invariant: c1 ≤ c2  (trivial)                              │       │
│  │  UNSAT: fast                                                 │       │
│  │  GENUINE ✓  Precondition alive at every step                │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                                                                         │
│  ASYNCHRONOUS MODEL:                                                    │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │  Runs proceed independently. No monotone bound.              │       │
│  │                                                              │       │
│  │  HIT ADD: c1' = c1 + wk1   ← explicit but OPTIONAL         │       │
│  │  MISS ADD: c1' >= c1        ← subsumes HIT (wk1 ≥ 0)      │       │
│  │                                                              │       │
│  │  No position guard (i = k). No hard partition.               │       │
│  │  Solver uses MISS everywhere. Runs become symmetric.         │       │
│  │  Precondition wk1 ≤ wk2 is DEAD.                           │       │
│  │                                                              │       │
│  │  UNSAT: 2s (by symmetry, not monotonicity)                  │       │
│  │  VACUOUS ✗  Standard sanity checks PASS but precondition    │       │
│  │             is dead. Proved by removing precondition: still  │       │
│  │             UNSAT (16s).                                     │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                                                                         │
│  VERDICT: Use the synchronized model for Kruskal.                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 21: Test Queries

### Synchronized Model

```prolog
(* PRIMARY: Violation — expected UNSAT *)
c1 > c2 :-
    Inv(i, k, wk1, wk2, c1, c2, n),
    n - 1 <= i.

(* SANITY: Bound holds — expected SAT *)
c1 <= c2 :-
    Inv(i, k, wk1, wk2, c1, c2, n),
    n - 1 <= i.
```

### Asynchronous Model

```prolog
(* PRIMARY: Violation — UNSAT in 2s (but VACUOUS) *)
c1 > c2 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2.

(* STANDARD SANITY: c1 >= 0 — SAT in 8s (PASSES, but insufficient!) *)
c1 >= 0 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2.

(* SYMMETRY WARNING: c2 > c1 — UNSAT in 2.2s (same speed as violation!) *)
c2 > c1 :-
    Inv(i1, i2, k, wk1, wk2, c1, c2, n),
    n - 1 <= i1, n - 1 <= i2.

(* DECISIVE: Remove wk1 <= wk2 from init, re-run violation *)
(* If still UNSAT: VACUOUS (precondition dead) *)
(* If SAT: GENUINE (precondition alive) *)
(* RESULT: UNSAT (16s) → VACUOUS *)
```

---

## Part 22: Key Takeaways

1. **Kruskal sync monotonicity is genuine.** The monotone bound `c1' ≤ c2'` holds at every transition because both runs process the same edge. Invariant is trivially `c1 ≤ c2`. Use this model.

2. **Kruskal async monotonicity is vacuous.** The UNSAT (2s) is a proof by symmetry, not monotonicity. The precondition `wk1 ≤ wk2` is dead. HIT is irrelevant.

3. **New vacuity type: MISS-subsumes-HIT.** When HIT has no position guard, MISS absorbs it. The solver uses MISS everywhere, making the runs symmetric. The standard sanity check (`output >= 0` SAT) does NOT detect this.

4. **Position guard is the structural criterion for async.** Counter must track SCAN POSITION (`i = k` forces HIT). Kruskal's counter tracks edges ADDED — no scan position exists to create the guard. All three requirements for genuine async: explicit HIT, position guard, non-decreasing MISS.

5. **"Suspiciously fast" is a diagnostic signal.** When an 8-variable async encoding (Kruskal: 2s) solves much faster than structurally similar ones (ArraySum: 47s, ArrayMax: 8m35s), investigate why. The solver found a shortcut that bypasses the property.

6. **Symmetric violation + reverse is a warning sign.** When `c1 > c2` and `c2 > c1` both return UNSAT at similar speed, the proof may be by symmetry. For genuine proofs (ArraySum), the violation and reverse have asymmetric solve times because the precondition creates real asymmetry.

7. **The updated sanity check recipe has three levels:** (a) `output >= 0` SAT catches Type 1 (Dijkstra-style, costs at 0); (b) symmetry/speed check flags suspicion; (c) removing the precondition catches Type 2 (Kruskal-style, dead precondition).

8. **Sync is the right model for Kruskal.** Union-find decisions are weight-independent, so both runs choose the same edges. The sync model captures this perfectly. Async is unnecessary and misleading.

9. **Negative results sharpen methodology.** This experiment upgraded our diagnostic toolkit: suspicion heuristics (speed, symmetry), structural criteria (position guard), and definitive tests (remove precondition). These apply to all future encodings.

---

*Synchronized: GENUINE — UNSAT (fast), invariant c1 ≤ c2, monotone bound c1' ≤ c2' at every step. Asynchronous: VACUOUS — UNSAT (2s) by symmetry, precondition dead, HIT irrelevant. Diagnostic chain: no-SKIP (2s) → bounded k (2.7s) → lockstep UNSAT (7s) → no-HIT UNSAT (6s) → no-precondition UNSAT (16s). New vacuity type documented: MISS-subsumes-HIT, not caught by standard output ≥ 0 check. Use synchronized model for Kruskal.*
