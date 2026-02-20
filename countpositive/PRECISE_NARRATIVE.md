# Relational Cost via PickK + Prophecy: Precise Claims and Evidence

---

## Claim 1: PickK is useful — it gives TIGHTER bounds than fixed-k

**The problem with fixed-k:**
Fixed-k tracks ONE distinguished cell, chosen at initialization, never moves.
For relative cost, this means: at most 1 position is known-equal.
Best possible bound: `n - 1`.

**PickK solves this:**
PickK re-focuses the distinguished cell at each step, discovering
MULTIPLE equal positions during execution.

**Evidence:**

| Encoding | Mechanism | Goal | Result | Time |
|----------|-----------|------|--------|------|
| `stage1_fixedk.clp` | Fixed k | `c > n - 1` | UNSAT | 4.5s |
| `stage1_fixedk.clp` | Fixed k | `c > n - 2` | **SAT** | 6s |
| `stage2a_pickk.clp` | PickK | `c > n - d0` | UNSAT | 2.5s |

**What this shows:**
- Fixed-k proves n-1 but CANNOT prove n-2 (SAT confirms the ceiling)
- PickK proves n-d0 for any d0 — strictly more powerful
- No performance penalty: PickK (2.5s) is faster than fixed-k (4.5s)

---

## Claim 2: Prophecy (d0) is useful — it parameterizes the bound

**The problem without prophecy:**
Without d0, you must commit to a specific number of equal positions.
The bound would be a constant, not a function of the input relationship.

**Prophecy solves this:**
d0 is universally quantified (`d0 >= 0` in Init). PCSAT proves the
bound FOR ALL d0 simultaneously. The user instantiates d0 based on
their knowledge:
- d0 = 0: no information → bound = n (trivial)
- d0 = n: identical arrays → bound = 0 (tight)
- 0 < d0 < n: partial knowledge → meaningful bound

**Evidence:**
The `stage2a_pickk.clp` encoding has `d0 >= 0` in Init and
`c > n - d0` with `d >= d0` in the goal. PCSAT returns UNSAT,
meaning the bound holds for ALL values of d0 in a single solve.

**What this shows:**
d0 is not a concrete number — it's a prophecy that PCSAT verifies
universally. This gives a family of bounds parameterized by input similarity.

---

## Claim 3: Together, PickK + prophecy give better relative cost bounds

**Evidence — sync model, all verified UNSAT:**

| File | Algorithm | Mutable? | Cost per step | Bound |
|------|-----------|----------|---------------|-------|
| `stage2a_pickk.clp` | CountPositive | No | ±1 | n - d0 |
| `count_in_range_sync.clp` | CountInRange | No | ±1 | n - d0 |
| `nested_branch_sync.clp` | ExpensiveBranch | No | ±2 | 2·(n - d0) |
| `inplacemap_sync.clp` | InplaceMap | **Yes** | ±1 | n - d0 |
| `stage2b_pickk_eps.clp` | ConditionalCost | No | ±eps | (n - d0)·eps |

**What the examples demonstrate:**

1. **CountPositive** (`stage2a_pickk.clp`):
   The core example. Branch cost ±1. Shows PickK + prophecy basics.

2. **CountInRange** (`count_in_range_sync.clp`):
   Different branch condition (`lo <= x <= hi` vs `x > 0`).
   Shows: the specific condition doesn't matter — only equality detection.

3. **ExpensiveBranch** (`nested_branch_sync.clp`):
   Branch costs ±2 instead of ±1. Bound becomes `2·(n-d0)`.
   Shows: non-unit cost coefficients are handled.

4. **InplaceMap** (`inplacemap_sync.clp`):
   Array values MUTATE: `A[i] = f(A[i])` where `f(x) = x>0 ? x+1 : 1`.
   Cell morphing tracks values that CHANGE during execution.
   Shows: PickK + prophecy works on mutable arrays, not just read-only scans.
   Also: direct improvement over prior work (async fixed-k, bound n-1, needs bk=1).

5. **ConditionalCost** (`stage2b_pickk_eps.clp`):
   Cost depends on VALUES: `cost += A[i]`. Requires epsilon.
   Shows: PickK + prophecy + epsilon combines to give (n-d0)·eps.
   This is the only example requiring all three ingredients.

---

## Limitation: Async model times out for cost

**Evidence:**

| Encoding | Model | Time |
|----------|-------|------|
| `countpositive.clp` (original) | Async + PickK | **Timeout** |
| `countpositive_opt.clp` | Async + PickK (n merged) | **Timeout** |
| `stage2a_pickk.clp` | Sync + PickK | 2.5s |

**Why async is slow:**
The async scheduler adds 6+ Horn clauses (SchTF, SchFT, SchTT +
fairness + disjunction). PCSAT must close the invariant under ALL
of them simultaneously. Combined with PickK (another unknown predicate),
this exceeds PCSAT's practical capacity for cost encodings.

**Why sync works for these examples:**
All five examples have deterministic iteration order (`for i = 0 to n-1`).
Both runs visit indices in the same sequence. There are no data-dependent
control-flow decisions that cause the runs to diverge. So lockstep (single
counter `i`) is sound — both runs genuinely step together.

**When async would be needed:**
Algorithms where runs make DIFFERENT decisions based on array values:
- Add/skip decisions (Kruskal MST: run 1 adds edge, run 2 skips)
- Early termination (linear search: run 1 finds at index 3, run 2 at index 7)
- Data-dependent loop bounds (while A[i] > 0: ...)

These are the examples to explore next for async + PickK cost.

---

## The Complete Progression for Presentation

### Part 1: Why PickK?

Show `stage1_fixedk.clp`:
- `c > n-1`: UNSAT (4.5s) — fixed-k proves this
- `c > n-2`: SAT (6s) — fixed-k CANNOT do better

Show `stage2a_pickk.clp`:
- `c > n-d0`: UNSAT (2.5s) — PickK breaks through the ceiling

### Part 2: Why prophecy?

Explain: d0 in `stage2a_pickk.clp` is universally quantified.
One PCSAT solve proves the bound for ALL d0.
The bound n-d0 is a FAMILY of bounds parameterized by input similarity.

### Part 3: Examples showing breadth

Show the 5 verified examples in the table above.
Highlight InplaceMap (mutable arrays) and ConditionalCost (needs epsilon).

### Part 4: Honest limitation

Show: async versions time out (countpositive.clp, countpositive_opt.clp).
Explain: all current cost examples use lockstep, which is sufficient for
deterministic-order loops.

### Part 5: Future work

Identify algorithms that genuinely need async for cost:
- Data-dependent control flow affecting BOTH cost and iteration order
- This is the next research challenge
