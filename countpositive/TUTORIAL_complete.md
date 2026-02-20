# Tutorial: Relational Cell Morphing for Execution Cost

*From fixed-k cell morphing to PickK + prophecy + epsilon.*

---

## The Story in One Page

We verify **relative execution cost** of programs on mutable arrays:
given two runs on related inputs, how much can their costs differ?

Standard cell morphing tracks ONE distinguished cell. This limits
the bound to detecting ONE "good" (equal) position. We extend it
with three new ingredients:

| Ingredient | What it does | Added in |
|------------|-------------|----------|
| **PickK** | Moves the spotlight — discovers multiple equal positions | Stage 2a |
| **Prophecy d0** | Parameterizes the bound by number of equal positions | Stage 2a |
| **Epsilon** | Bounds value-dependent cost at unequal positions | Stage 2b |

The progression:

```
Stage 1:  Fixed k           =>  cost1 - cost2 <= n - 1
Stage 2a: PickK + prophecy  =>  cost1 - cost2 <= n - d0          (tighter)
Stage 2b: + epsilon         =>  cost1 - cost2 <= (n - d0) * eps  (tightest)
```

---

## Stage 1: The Baseline — Fixed-k Cell Morphing

**File:** `stage1_fixedk.clp`

**Algorithm:** CountPositive — `if A[i] > 0: cost++`

**Encoding:** Track one cell `(k, ak1, ak2, bk)`, fixed at initialization.

```
  a1:  [ ? ][ ? ][ ak1 ][ ? ][ ? ]     k = 2, fixed forever
  a2:  [ ? ][ ? ][ ak2 ][ ? ][ ? ]     bk = 1 means ak1 = ak2
```

**Transition:**

| Case | Condition | Cost update |
|------|-----------|-------------|
| HIT equal | `i = k, bk = 1` | `c' = c` (same branch) |
| HIT unequal | `i = k, bk = 0` | `c' = c + 1` (worst case) |
| MISS | `i ≠ k` | `c' = c + 1` (unknown) |

**Bound:** `n - 1` (one equal position out of n).

**Results:**
- `c > n - 1` → **UNSAT** in 4.5s ← can prove this
- `c > n - 2` → **SAT** in 6s ← CANNOT do better

**The problem:** Even if ALL positions are equal, fixed-k only sees ONE.
The bound n-1 is the best it can ever achieve.

---

## Stage 2a: Adding PickK + Prophecy

**File:** `stage2a_pickk.clp`

**Same algorithm:** CountPositive

**Key change:** The distinguished cell MOVES.

```
Step 0:  PickK focuses on index 0        Step 2:  PickK focuses on index 2
  a1: [*ak1*][ ? ][ ? ][ ? ][ ? ]         a1: [ ? ][ ? ][*ak1*][ ? ][ ? ]
  a2: [*ak2*][ ? ][ ? ][ ? ][ ? ]         a2: [ ? ][ ? ][*ak2*][ ? ][ ? ]
       bkp=1? Yes! d=1                           bkp=1? Yes! d=2

Step 1:  PickK focuses on index 1        Step 3:  d >= d0, stop searching
  a1: [ ? ][*ak1*][ ? ][ ? ][ ? ]         a1: [ ? ][ ? ][ ak1 ][ ? ][ ? ]
  a2: [ ? ][*ak2*][ ? ][ ? ][ ? ]         a2: [ ? ][ ? ][ ak2 ][ ? ][ ? ]
       bkp=0, d stays 1                         keep k = 2
```

**New predicates:**

```prolog
(* PickK: two rules *)
PickK(..., i) :- Inv(...), i < n, d < d0.   (* searching: refocus *)
PickK(..., k) :- Inv(...), d >= d0.          (* settled: keep cell *)

(* Wit: provides fresh values at new focus *)
Wit(...) :- Inv(...), i < n.
```

**Transition — same three cases, but tracks d:**

| Case | Cost | Discovery |
|------|------|-----------|
| HIT equal (`i=kp, bkp=1`) | `c' = c` | `d' = d + 1` |
| HIT unequal (`i=kp, bkp=0`) | `c' = c + 1` | `d' = d` |
| MISS (`i≠kp`) | `c' = c + 1` | `d' = d` |

**Bound:** `n - d0` for any `d0 ≥ 0`.

**Result:** `c > n - d0` → **UNSAT** in 2.5s

**Why this is better:**
- Fixed-k: n-1 (one position), cannot prove n-2
- PickK: n-d0 for ANY d0 — if 50 positions are equal, bound is n-50

---

## Stage 2b: Adding Epsilon — Value-Dependent Cost

**File:** `stage2b_pickk_eps.clp`

**Algorithm:** ConditionalCost — `if A[i] > 0: cost += A[i]`

**Why Stage 2a is not enough:**
In CountPositive, cost changes by ±1 regardless of values.
In ConditionalCost, cost changes by `A[i]` — a VALUE.
Without epsilon, we cannot bound how much each unequal position contributes.

**Precondition (mixed metric):**
- d0 positions: `a1[i] = a2[i]` (replace metric)
- All positions: `|a1[i] - a2[i]| ≤ eps` (L∞ metric)

**Transition with epsilon:**

| Case | Cost | Why |
|------|------|-----|
| HIT equal | `c' = c` | `a1[i]=a2[i]` → identical contribution |
| HIT unequal | `c' ∈ [c-eps, c+eps]` | `max(x,0)` is 1-Lipschitz |
| MISS | `c' ∈ [c-eps, c+eps]` | universal precondition gives eps |

**Bound:** `(n - d0) · eps`

**Result:** `c > (n - d0) * eps` → **UNSAT** in 25s

**Why each ingredient is necessary:**

| Without... | Best possible bound | Why |
|-----------|-------------------|-----|
| Without PickK | `(n - 1) · eps` | Only 1 equal position |
| Without prophecy | Cannot parameterize by d0 | |
| Without epsilon | Cannot bound value-dependent cost | |
| **All three** | **(n - d0) · eps** | **Tightest** |

---

## Extensions: More Execution Cost Examples

All using sync + PickK + prophecy. All verified UNSAT.

### CountInRange — Different branch condition

**File:** `count_in_range_sync.clp`

```
if lo <= A[i] and A[i] <= hi: cost++
```

Bound: `n - d0`. Same as CountPositive but different branch condition.
Shows the framework generalizes — the specific condition doesn't matter,
only whether equal values produce the same branch.

### NestedBranch — Non-unit cost

**File:** `nested_branch_sync.clp`

```
if A[i] > 0: cost += 2     (* expensive operation *)
```

Bound: `2 · (n - d0)`. The cost coefficient 2 appears in the bound.
Shows the framework handles different cost magnitudes.

### InplaceMap — Mutable arrays

**File:** `inplacemap_sync.clp`

```
x = A[i]
A[i] = f(x)     (* f(x) = x > 0 ? x + 1 : 1 *)
```

Bound: `n - d0`. Cell values MUTATE during execution (`ak1' = f(ak1p)`).
Shows PickK + prophecy works with mutable arrays, not just read-only scans.

Key insight: `f` preserves equality. `ak1p = ak2p ⟹ f(ak1p) = f(ak2p)`.
So equal cells stay equal after mutation.

**Comparison with prior work:** The original async + fixed-k encoding
(`relational-map-cm-beta-singlek2.clp`) proves n-1 and requires `bk=1`
in the goal. PickK proves n-d0 without that restriction.

### ConditionalCost — Value-dependent (Stage 2b)

**File:** `stage2b_pickk_eps.clp` / `conditional_cost_sync.clp`

```
if A[i] > 0: cost += A[i]
```

Bound: `(n - d0) · eps`. The only example requiring all three ingredients.

---

## Summary Table

| File | Algorithm | Mutable? | Cost | Bound | Vars | Time |
|------|-----------|----------|------|-------|------|------|
| `stage1_fixedk.clp` | CountPositive | No | ±1 | n - 1 | 7 | 4.5s |
| `stage2a_pickk.clp` | CountPositive | No | ±1 | n - d0 | 9 | 2.5s |
| `stage2b_pickk_eps.clp` | ConditionalCost | No | ±eps | (n-d0)·eps | 10 | 25s |
| `count_in_range_sync.clp` | CountInRange | No | ±1 | n - d0 | 9 | ? |
| `nested_branch_sync.clp` | NestedBranch | No | ±2 | 2·(n-d0) | 9 | ? |
| `inplacemap_sync.clp` | InplaceMap | **Yes** | ±1 | n - d0 | 9 | ? |
| `conditional_cost_sync.clp` | ConditionalCost | No | ±eps | (n-d0)·eps | 10 | ? |

---

## Encoding Pattern Summary

All sync + PickK + prophecy encodings follow this template:

```prolog
(* Initialization *)
Inv(i, n, k, ak1, ak2, bk, d, d0, c, ...) :-
  i = 0, n > 0, 0 <= k, k < n,
  [input precondition on ak1, ak2],
  d = 0, d0 >= 0, c = 0.

(* Transition *)
Inv(i', n, kp, ak1', ak2', bk', d', d0, c', ...) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c, ...),
  i < n,
  PickK(..., kp),
  Wit(..., ak1p, ak2p, bkp, ...),
  (
    (i = kp and bkp = 1 and [cost neutral] and d' = d + 1)
    or
    (i = kp and bkp = 0 and [worst case cost] and d' = d)
    or
    (i <> kp and [worst case cost] and d' = d)
  ),
  i' = i + 1,
  [update cell values],
  [maintain bk'].

(* Wit *)
Wit(...) :- Inv(...), i < n.

(* PickK *)
PickK(..., i) :- Inv(...), i < n, d < d0.
PickK(..., k) :- Inv(...), d >= d0.

(* Goal *)
c > [bound] :- Inv(...), n <= i, d >= d0.
```

The only things that change between examples:
1. **Cost update** in the transition (±1, ±2, ±eps, ...)
2. **Cell mutation** in HIT cases (read-only vs mutable)
3. **Input precondition** (equality only, or equality + eps)
4. **Bound** in the goal (n-d0, 2·(n-d0), (n-d0)·eps, ...)

---

## What's Next

**Current status:** Sync model, all examples verified.

**Open directions:**
- **Async + PickK for cost:** Needed for algorithms where runs diverge
  (add/skip decisions). Currently a performance issue (~3hr for simplest case).
- **More complex algorithms:** Nested loops, multiple cost sources,
  data-dependent iteration counts.
- **Two-sided bounds:** Current encodings prove one-sided `c ≤ bound`.
  Full `|c| ≤ bound` follows by symmetric argument (swap runs).
