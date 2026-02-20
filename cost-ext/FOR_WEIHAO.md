# FOR_WEIHAO: Relational Cost Analysis via PickK + Prophecy in PCSAT

*A plain-language guide to what we built, why it works, and what we learned.*

---

## 1. The Big Picture

You have a research framework called **relational cell morphing** that verifies properties about programs running on two related arrays. Previous work proved robustness ("small input change → small output change") and sensitivity ("one element differs → bounded output change"). 

Now we're extending this to **relational cost** — proving that the *cost* (number of operations, accumulated values, etc.) of running a program on two related arrays differs by at most some bound.

The key challenge: cost depends on **many** array elements, not just one. Standard cell morphing tracks a single distinguished cell `k`. That's enough for robustness (where an epsilon bound absorbs the unknown cells) but not for cost (where each cell's contribution matters).

**The solution: PickK + prophecy.** Instead of one fixed cell, we dynamically re-focus the spotlight using a functional predicate `PickK`, and count how many "good" positions we discover using a prophecy variable `d0`.

---

## 2. Technical Architecture

### The Three Layers

Think of the encoding as three layers stacked on top of each other:

**Layer 1: Standard Cell Morphing** (from previous work)
- Track one distinguished cell `(k, ak1, ak2, bk)`
- HIT/MISS abstraction: when `i = k`, values are known; when `i ≠ k`, values are unknown
- This is the foundation — it gives us relational information at one position

**Layer 2: PickK (Existential Morphing)** ← NEW
- A functional predicate `PickK(state..., kp)` that re-chooses which cell to track
- Two modes: *searching* (move spotlight to current index) and *settled* (keep current cell)
- This lets us gather relational information at MULTIPLE positions across execution

**Layer 3: Prophecy Counting (d, d0)** ← NEW  
- `d0`: "I promise there exist at least d0 positions where A1[i] = A2[i]"
- `d`: counter of how many such positions we've actually found so far
- When `d ≥ d0`: prophecy fulfilled, stop searching
- The final bound is parameterized by `d0`

### How They Work Together

```
PickK says: "focus on index i right now"
              ↓
Cell morphing says: "at this index, bk=1 means values are equal"
              ↓
Prophecy says: "that's another good position! d' = d + 1"
              ↓
Cost tracking says: "equal values → same branch → cost unchanged"
              ↓
At termination: "found d ≥ d0 good positions, so cost diff ≤ n - d0"
```

### Synchronized vs Asynchronous Model

This was our **biggest discovery** of the session:

| Model | What it means | Extra predicates | Cost overhead |
|-------|---------------|------------------|---------------|
| Synchronized | Single counter `i`, both runs step together | Wit (witness) | **Zero** |
| Asynchronous | Two counters `i1, i2`, scheduler decides who steps | SchTF, SchFT, SchTT + fairness | **Massive** (3hr → 2.5s) |

For algorithms with deterministic iteration order (countpositive, arraysum, etc.), **always use synchronized**. The async scheduler adds 6+ Horn clauses that PCSAT must close invariants under, and this is the entire bottleneck.

Async is only needed when runs can make different control-flow decisions (e.g., Kruskal's algorithm where one run might add an edge that the other skips).

---

## 3. What Each File Does

### Encodings (in recommended testing order)

| File | What | Variables | Time | Teaches |
|------|------|-----------|------|---------|
| `countpositive_counting.clp` | Pure counting, no morphing | 5 | 5s | The property itself is simple |
| `countpositive_sync.clp` | Sync + PickK | 9 | **2.5s** | PickK has zero overhead |
| `countpositive_fixedk.clp` | Fixed k, no PickK | 7 | 4.5s | Fixed k can only prove n-1 |
| `arraysum_mixed_sync.clp` | Sync + PickK + eps | 10 | **25s** | PickK needed for value-dependent bounds |
| `countpositive.clp` | Async + PickK (original) | 11 | ~3hr | Async scheduler is the bottleneck |
| `countpositive_opt.clp` | Async + PickK + extra rule | 10 | >3hr | Extra clauses hurt (Dijkstra lesson) |
| `countpositive_v2.clp` | Async + PickK, merged n | 10 | >1hr | Merging n helps but not enough |

### Documentation
| File | Purpose |
|------|---------|
| `paper_strategy.md` | Paper narrative and testing plan |
| `evaluation_countpositive.md` | Initial evaluation of the PickK approach |
| `pcsat_performance_notes.md` | UNSAT vs SAT asymmetry analysis |

---

## 4. Technology Choices and Why

### Why PCSAT (not SMT arrays)?
PCSAT solves constrained Horn clauses (CHCs) over integers. By encoding array accesses as HIT/MISS on distinguished cells, we avoid SMT array theories entirely. The trade-off: we lose precision at MISS positions, but gain the ability to use PCSAT's powerful invariant synthesis.

### Why functional predicates for PickK?
PickK is a functional predicate (maps state → output) rather than a relation. This is the PCSat/pfwCSP way of expressing existential quantification: "there EXISTS a choice of kp such that the invariant is maintained." PCSAT synthesizes the interpretation of PickK along with the invariant — it figures out the optimal refocusing strategy automatically.

### Why prophecy (d0)?
Without d0, you'd need to track exactly which positions are equal — impossible without array theory. Prophecy sidesteps this: "I don't know WHICH positions are equal, but there are at least d0 of them." The bound `n - d0` degrades gracefully from `n` (d0=0, no information) to `0` (d0=n, identical arrays).

### Why Wit (witness predicate) in sync model?
When PickK refocuses from cell k to cell kp, we need fresh values `(ak1p, ak2p, bkp)` for the new cell. In async mode, the scheduler predicates (SchTT etc.) provide these existentially. In sync mode, we use a minimal `Wit` predicate for the same purpose. Wit has the same signature as Inv minus the mutable state — PCSAT synthesizes its interpretation.

---

## 5. Decision Reasoning

### "Why not just add the PickK fallback rule?"

We tried adding a third PickK rule for the case `d < d0 ∧ i1 ≠ i2` (keep cell k when loops are misaligned). This **made things slower**, not faster.

The lesson (echoing the Dijkstra Approach A failure): PCSAT must find an invariant that is closed under ALL Horn clauses simultaneously. More clauses = more constraints on the invariant = harder problem. An extra clause that's "sound but unnecessary" gives the solver more work for no benefit.

**Rule of thumb:** Only add a Horn clause if it carries information the solver needs. If a case is already handled by the solver's freedom to choose any value, don't constrain it.

### "Why synchronized over asynchronous?"

For deterministic-order loops (`for i = 0 to n-1`), both runs visit indices in the same order. The async model (i1, i2 with scheduler) allows interleavings that can't actually happen — and the solver must prove the property for ALL interleavings, which is strictly harder.

The sync model (single counter i) is both:
- **Sound**: both runs really do step together
- **More precise**: no spurious interleavings
- **Dramatically faster**: 6 fewer Horn clauses

**When async IS needed**: Kruskal MST (add/skip decisions differ between runs), or any algorithm where data-dependent control flow causes the runs to diverge.

### "Why is arraysum more interesting than countpositive?"

For countpositive, the cost contribution at each step is ±1 regardless of values. Pure counting can express "equal → 0, unequal → ±1" without knowing what the values actually are.

For arraysum, the cost contribution is `a1[i] - a2[i]` — it depends on the actual VALUES. Cell morphing at HIT positions gives `|ak1 - ak2| ≤ eps`, bounding the per-step contribution. Counting has no access to values, so it can't express this. PickK + cell morphing is genuinely necessary.

---

## 6. Lessons Learned

### Bug: Extra clauses hurt PCSAT (confirmed again!)
We already knew this from Dijkstra Approach A (15+ hours with extra TT clause). The `countpositive_opt.clp` experiment confirms it: adding one PickK rule made things slower. This is now a **replicated finding** across two completely different encoding families.

### Insight: PickK is essentially free
Version A (9 vars, PickK) was FASTER than Version B (5 vars, no PickK): 2.5s vs 5s. The functional predicate adds no meaningful overhead to invariant synthesis. The solver handles existential morphing naturally.

This was surprising — we expected PickK to add a quantifier alternation penalty. In practice, PCSAT's treatment of functional predicates is efficient enough that it doesn't show up.

### Insight: The async scheduler is the ENTIRE bottleneck for cost
Going from async to sync: 3 hours → 2.5 seconds. That's a ~4000x speedup. The scheduler adds SchTF, SchFT, SchTT (3 unknown predicates) + 2 fairness clauses + 1 disjunction clause = 6 extra Horn constraints. For cost encodings with PickK, this is too much.

### Insight: Performance scales with CLAUSES, not VARIABLES
| Encoding | Variables | Clauses | Time |
|----------|-----------|---------|------|
| Counting (B) | 5 | 3 | 5s |
| Sync+PickK (A) | 9 | 5 | 2.5s |
| Async+PickK (original) | 11 | ~12 | 3hr |

Going from 5 to 9 variables barely matters. Going from 5 to 12 clauses is catastrophic. **Clause count matters more than variable count** for PCSAT performance in this domain.

### Pattern: The "PickK search → settle" two-phase strategy
The PickK rules encode a proof strategy:
1. **Phase 1 (d < d0)**: Keep refocusing to current index. Each TT step tests equality. If equal, bank it (d++). 
2. **Phase 2 (d ≥ d0)**: Stop refocusing. Prophecy fulfilled. Remaining steps are worst-case.

This is a general pattern that could apply to any property that benefits from counting "good" positions. Future examples might use different criteria for "good" (not just equality).

### Anti-pattern: Don't use async for deterministic-order loops
If both runs iterate `0, 1, 2, ..., n-1` in order, use a single counter. The async model's freedom to interleave is wasted (all interleavings reach the same final state) but costs the solver enormously.

---

## 7. What's Next

### Immediate (for the paper)
1. ✅ countpositive: sync+PickK (2.5s), fixed-k comparison (4.5s), counting baseline (5s)
2. ✅ arraysum_mixed: sync+PickK+eps (25s) — the killer example
3. Try more algorithms: count_in_range, weighted_sum, conditional_accumulate
4. Write up the comparison table for the paper

### Future directions
- **Async cost**: Find an algorithm where async + PickK is necessary (cost depends on data-dependent control flow). This would show the framework's generality even if solver time is longer.
- **Tighter bounds**: For arraysum, the HIT-unequal case could be split further (both positive contribution → tighter bound). Need to see if PCSAT can handle the extra cases.
- **Multiple distinguished cells**: Instead of one PickK, could we have PickK1, PickK2? Track two cells simultaneously? Would add variables but might give tighter bounds for algorithms with two interacting cost-relevant positions.

---

## 8. Async Exploration: Stride-1 vs Stride-2

### The Setup

Two DIFFERENT programs on two RELATED arrays:

```
P1(A1, n):                    P2(A2, n):
  for i1 = 0 to n-1:            for i2 = 0 to n-1 step 2:
    if A1[i1] > 0: cost1++        if A2[i2] > 0: cost2++
```

P1 visits every position (stride 1, n iterations). P2 visits even positions only (stride 2, n/2 iterations). The counters diverge: after one step each, i1=1 but i2=2.

**Property:** cost1 − cost2 ≤ n − d0, where d0 counts equal values at even positions (the intersection of both programs' index sets).

### Why This Genuinely Needs Async

The scheduler must interleave P1 and P2's steps. A natural pattern emerges:
- **TT** (both step): i1→i1+1, i2→i2+2. If aligned (i1=i2=2j), they see the same even position. PickK can discover equality here (d++). But now i1=2j+1, i2=2j+2 — misaligned.
- **TF** (P1 catches up): i1→i1+1. Now i1=2j+2, i2=2j+2 — realigned!
- Repeat: TT, TF, TT, TF, ... gives epochs where PickK can focus on each even position.

The scheduler ARRANGES the alignment. PickK exploits it. This is the interplay we want to demonstrate.

### Two Encodings

| File | Model | Scheduler? | Clauses | Variables |
|------|-------|------------|---------|-----------|
| `stride12_cost_sync.clp` | Epoch sync | No | ~5 | 9 |
| `stride12_cost_async.clp` | Full async | Yes (SchTF/FT/TT) | 11 | 10 |

The sync epoch model absorbs the stride difference into per-epoch semantics (each epoch = P1 does 2 steps, P2 does 1). It's a shortcut that avoids the scheduler entirely. **Already verified UNSAT.**

The async model is the real test: can PCSAT handle full scheduler + PickK + prophecy on a problem that genuinely has different strides? Based on async countpositive (~3hr), it might be slow. But this is a more meaningful example because the scheduler isn't just adding spurious interleavings — it's actually needed to arrange the alignment pattern.

### The Invariant PCSAT Needs to Find

For the async model, the invariant is more complex. At any point:
- P1 has processed i1 positions, P2 has processed i2/2 positions (since i2 is always even)
- cost1 ≤ i1 (at most one count per P1 step)
- cost2 ≤ i2/2 (at most one count per P2 step)
- d counts discovered equal positions at even indices where both were aligned

The expected invariant shape: c ≤ i1 − d (P1's maximum minus the savings from equal positions). At termination (i1=n, i2=n, d≥d0): c ≤ n − d0. ✓

### Lessons (pending verification)

- If async UNSAT in reasonable time: proves the framework handles genuinely different programs with different strides. Major result for the paper.
- If async times out: confirms the scheduler bottleneck scales to new examples. The epoch sync model (already verified) is the practical encoding, while the async formulation shows what the IDEAL encoding would look like.
- Either way, having both encodings demonstrates the design space clearly.
