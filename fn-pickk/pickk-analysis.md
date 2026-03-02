# PickK: Why It Must Be an Ordinary Predicate (Not Functional)

## Summary for Discussion with PCSAT Authors

### Context

In our relational cost analysis via cell morphing, we introduce a predicate
`PickK(state, kp)` that selects which array cell to track at each step.
A natural question: should PickK be a functional predicate (`FN_PickK`)
since it semantically selects "one cell per step"?

**Answer: No. PickK must be an ordinary predicate. We tested FN_PickK and
it produces SAT (fails to verify) on problems where ordinary PickK produces
UNSAT (verifies successfully).**

### What PickK Does

Cell morphing tracks one distinguished array cell `k` through two parallel
program executions. PickK re-selects which cell to track at each loop
iteration, enabling the proof to "inspect" multiple positions:

```
PickK(state, kp)   — "at this state, the proof focuses on cell kp"
```

Two defining clauses pin its behavior:

```
(* Searching: when we haven't yet found d0 equal positions, inspect position i *)
PickK(state, i) :- Inv(state), i < n, d < d0.

(* Settled: when prophecy fulfilled, keep current cell *)
PickK(state, k) :- Inv(state), d >= d0.
```

PickK is consumed in the transition clause:

```
Inv(state') :- Inv(state), PickK(state, kp), ...(transition logic)...
```

### The Connection to d and d0

The prophecy variable d0 represents a promise: "the two arrays share at
least d0 equal positions." The counter d tracks how many equal positions
the proof has discovered so far. The cost bound we prove is n - d0.

**PickK is the mechanism that makes d grow toward d0.** Here's how:

```
Step i: PickK says kp = i (searching, since d < d0).
        The transition must handle i = kp (a HIT):
          A1[i] = A2[i]?  YES → HIT-equal:   c' = c,     d' = d + 1  ← d grows!
                           NO  → HIT-unequal: c' = c + 1, d' = d

Step i+1: If d still < d0, PickK says kp = i+1. Another inspection.
          Again, HIT-equal increments d.

...continue until d reaches d0...

Step j (d = d0): PickK switches to kp = k (settled).
        Most steps are MISS: c' = c + 1, d' = d.
        No more searching needed.

At termination (i = n):
  d ≥ d0 (prophecy fulfilled)
  c ≤ (n - d0): the d0 HIT-equal steps had cost 0, rest had cost 1.
```

**Without the searching clause**, kp is never forced to equal i, so the
condition `i = kp` is never forced to be true, d never increments, d stays
at 0, and the bound degrades to c ≤ n (trivial). The entire d/d0 mechanism
becomes dead.

**The causal chain:**

```
Searching clause forces kp = i
  → Transition must handle HIT case (i = kp)
    → HIT-equal increments d
      → d grows toward d0
        → At termination, d ≥ d0 is achievable
          → Only n - d0 steps paid worst-case cost
            → Tight bound c ≤ n - d0
```

Remove any link and the chain breaks.

### Why FN_PickK Fails

**Experiment**: Replace `PickK` with `FN_PickK`, remove the two defining
clauses, keep everything else identical.

**Result**: SAT (verification fails) on CountPositive cost bound `c > n - d0`,
which returns UNSAT (verifies) with ordinary PickK.

**Root cause**: As a functional predicate, PCSat has an existential reading:
"find ONE function kp = f(state) that makes the invariant work." PCSat
discovers the lazy strategy `kp = k` (always keep current cell, never search):
- Position i is never inspected (no HIT at position i)
- Counter d never increments (no equal positions discovered)
- The bound degrades to c ≤ n (trivial, since d0 effectively = 0)
- Goal `c > n - d0` becomes satisfiable for small d0

Ordinary PickK gives a universal reading: "the invariant must work for ALL
kp values the defining clauses require, including kp = i during searching."
This forces Inv to handle the hard cases that make d grow.

### The Mechanism: Two-Sided Squeeze

PickK as an ordinary predicate creates a **squeeze between lower and upper bounds**:

```
LOWER BOUND (defining clauses, PickK in head):
  "PickK MUST include (state, i) when d < d0"     — forces searching
  "PickK MUST include (state, k) when d >= d0"     — allows settling

UPPER BOUND (transition clause, PickK in body):
  "For ALL (state, kp) in PickK, the invariant must be preserved"
```

The lower bound forces the proof to handle the **searching case** (kp = i).
This means the invariant must account for:
  1. Inspecting position i and finding equality → d increments (HIT-equal)
  2. Inspecting position i and finding inequality → c increments (HIT-unequal)
  3. Position i is not the current kp → c increments (MISS)

This case analysis, forced by the lower bound, is what produces the tight
bound: after n steps, d ≥ d0 positions were HIT-equal (cost 0 each), and
at most n - d0 were HIT-unequal or MISS (cost 1 each), giving c ≤ n - d0.

### Comparison: PickK vs Scheduler

PickK and the scheduler predicates (SchTF, SchFT, SchTT) from the CAV 2021
paper share the same structural pattern: ordinary predicates squeezed between
lower and upper bounds.

**Scheduler structure:**

```
LOWER BOUND (head disjunction + fairness):
  SchTF(s), SchFT(s), SchTT(s) :- Inv(s), prog1_active or prog2_active.
  z1 > 0 :- Inv(s), SchTF(s), z2 > 0.    (* fairness *)

UPPER BOUND (transition clauses):
  Inv(s') :- Inv(s), SchTF(s), T1(s1, s1'), s2' = s2.
  Inv(s') :- Inv(s), SchFT(s), T2(s2, s2'), s1' = s1.
  Inv(s') :- Inv(s), SchTT(s), T1(s1, s1'), T2(s2, s2').
```

**PickK structure:**

```
LOWER BOUND (defining clauses):
  PickK(s, i) :- Inv(s), i < n, d < d0.   (* searching *)
  PickK(s, k) :- Inv(s), d >= d0.          (* settled *)

UPPER BOUND (transition clause):
  Inv(s') :- Inv(s), PickK(s, kp), Wit(...), transition_logic.
```

**Side-by-side comparison:**

```
                     SCHEDULER                       PICKK
Decides:             which program copy steps         which array cell to inspect
Lower bound:         disjunction + fairness           defining clauses
Lower bound says:    "at least one copy must          "position i must be inspected
                      progress if any can"             during searching (d < d0)"
Upper bound:         transition clauses               transition clause
Upper bound says:    "Inv preserved under             "Inv preserved under
                      this schedule choice"            this cell choice"
Squeeze forces:      Inv handles both copies'         Inv handles HIT at each position
                      progress fairly                  → d grows → tight bound
Without lower bound: trivial schedule (always TT)     trivial cell (always k)
                     → may fail to verify              → d stuck at 0 → bound trivial
Kind in pfwCSP:      ordinary (•)                     ordinary (•)
Why not functional:  fairness needs disjunctive       searching needs forced HITs
                      coverage of all modes             to drive d toward d0
```

**The key analogy:**

  Scheduler fairness says:
    "You cannot starve a program — if it can run, eventually it must run."
    Forces Inv to handle progress by both programs.

  PickK searching says:
    "You cannot skip inspection — during searching phase (d < d0),
     each position i must be examined to discover equal positions."
    Forces Inv to handle HITs that drive d toward d0.

**One structural difference in lower bounds:**

  Scheduler uses head disjunction (non-Horn):
    SchTF(s), SchFT(s), SchTT(s) :- Inv(s), progress.
    "At least one of these predicates must contain this state."
    → Disjunctive lower bound: at least one mode applies.

  PickK uses separate Horn clauses:
    PickK(s, i) :- Inv(s), searching.
    PickK(s, k) :- Inv(s), settled.
    "PickK must contain BOTH kinds of tuples."
    → Conjunctive lower bound: both modes' tuples are included.

  This makes PickK's constraint stronger: the invariant must simultaneously
  handle all searching tuples AND all settled tuples. The scheduler only
  requires at least one mode to apply per state.

**PickK is a scheduler for the proof, not for the programs.** Just as SchTF
decides "which program steps next," PickK decides "which cell the proof
inspects next." And just as scheduler fairness clauses prevent starving any
program, PickK's searching clause prevents skipping the inspection phase
that is essential for discovering equal positions and achieving a tight bound.

### What PickK Actually Is

PickK is a novel use of ordinary predicates that doesn't fit cleanly into
the existing pfwCSP categories:

- It is NOT a scheduler (it doesn't control which program copy steps)
- It is NOT a pure Skolem function (it has defining clauses that impose
  proof obligations, so it cannot be a functional predicate)
- It IS a **proof strategy predicate**: it specifies which cell to track,
  and its defining clauses ensure the invariant accounts for the tracking

### Comparison with pfwCSP Predicate Kinds

| Predicate | Kind | Role | Why this kind? |
|-----------|------|------|----------------|
| `Inv` | Ordinary (•) | Relational invariant | Standard |
| `SchTF/FT/TT` | Ordinary (•) | Scheduler | Constrained by fairness (disjunction + liveness) |
| `FN_DB` | Functional (λ) | Difference bound | Pure Skolem function, freely chosen |
| `FN_R` | Functional (λ) | Angelic ND resolver | Pure Skolem function, freely chosen |
| `WF_R` | Well-founded (⇓) | Termination witness | Must be well-founded |
| **PickK** | **Ordinary (•)** | **Cell selection** | **Defining clauses force searching → d grows → tight bound** |
| **Wit** | **Ordinary (•)** | **Fresh cell values** | **Provides witness domain for refocused cell** |

PickK differs from FN_R and FN_DB because:
- FN_R/FN_DB are pure existential witnesses (solver freely chooses)
- PickK has **defining clauses that impose structural proof obligations**
- These obligations force Inv to handle HIT cases that increment d
- This is what makes the cost bound tight (n - d0 instead of trivial n)

### Encoding Pattern (for reference)

The standard PickK encoding in sync model (5-6 clauses):

```
(* 1. Init *)
Inv(state) :- initial conditions, d = 0, d0 >= 0, c = 0.

(* 2. Transition — PickK in BODY *)
Inv(state') :- Inv(state), i < n,
    PickK(state, kp), Wit(i, n, kp, ak1p, ak2p, bkp, ...),
    (HIT-equal:   i=kp, bkp=1, c'=c,   d'=d+1) or
    (HIT-unequal: i=kp, bkp=0, c'=c+1, d'=d) or
    (MISS:        i<>kp,       c'=c+1, d'=d),
    ... bk maintenance ...

(* 3. Wit — provides fresh cell values *)
Wit(state) :- Inv(state), i < n.

(* 4. PickK searching — forces inspection, drives d toward d0 *)
PickK(state, i) :- Inv(state), i < n, d < d0.

(* 5. PickK settled — keeps current cell after prophecy fulfilled *)
PickK(state, k) :- Inv(state), d >= d0.

(* 6. Goal — violation unreachable *)
c > n - d0 :- Inv(state), n <= i, d >= d0.
```

Removing clauses 4 and 5 and renaming to FN_PickK: **SAT (fails).**
All 6 clauses with ordinary PickK: **UNSAT in 2.5s (verifies).**
