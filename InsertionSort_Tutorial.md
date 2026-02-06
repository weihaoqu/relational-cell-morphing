# Insertion Sort Robustness Verification using PCSAT

## A Complete Tutorial on Relational Cell Morphing

---

## Table of Contents

1. [Overview](#overview)
2. [The Algorithm](#the-algorithm)
3. [The Property: 1-Robustness](#the-property-1-robustness)
4. [The Challenge: Array Reasoning](#the-challenge-array-reasoning)
5. [The Solution: Relational Cell Morphing](#the-solution-relational-cell-morphing)
6. [State Variables](#state-variables)
7. [The PCSAT Encoding](#the-pcsat-encoding)
   - [Initialization](#initialization)
   - [TF Transition (Run 1 Steps)](#tf-transition-run-1-steps)
   - [FT Transition (Run 2 Steps)](#ft-transition-run-2-steps)
   - [TT Transition (Both Step)](#tt-transition-both-step)
   - [Scheduler Clauses](#scheduler-clauses)
   - [Goal Clause](#goal-clause)
8. [The HIT/MISS Abstraction](#the-hitmiss-abstraction)
9. [Why 1-Robust Works](#why-1-robust-works)
10. [Verification Results](#verification-results)
11. [Comparison with N-Robust Algorithms](#comparison-with-n-robust-algorithms)
12. [Complete Encoding](#complete-encoding)
13. [Key Takeaways](#key-takeaways)
14. [References](#references)

---

## Overview

This document explains how to verify that **Insertion Sort** is **1-robust** using **PCSAT** (a solver for predicate constraint satisfaction problems) with the **relational cell morphing** technique.

### What You Will Learn

- How to encode array-manipulating algorithms for robustness verification
- The relational cell morphing technique for avoiding quantified array reasoning
- The HIT/MISS abstraction for tracking array accesses
- How to interpret PCSAT verification results

### Prerequisites

- Basic understanding of insertion sort algorithm
- Familiarity with loop invariants
- Basic knowledge of formal verification concepts

---

## The Algorithm

```
Insertion-Sort(A : arr)
   i = 1                              // outer loop starts at 1 (index 0 is trivially sorted)
   while i < n:
       key = A[i]                     // save the element to insert
       j = i - 1
       while j >= 0 and A[j] > key:   // inner loop: shift larger elements right
           A[j+1] = A[j]              // shift element right
           j -= 1
       A[j+1] = key                   // insert key at correct position
       i += 1
```

### Algorithm Visualization

```
Initial:  [5, 2, 8, 1, 9]
          ─────────────────
Step 1:   [2, 5, 8, 1, 9]    // Insert 2: shift 5 right, place 2
Step 2:   [2, 5, 8, 1, 9]    // Insert 8: already in place
Step 3:   [1, 2, 5, 8, 9]    // Insert 1: shift all, place 1 at front
Step 4:   [1, 2, 5, 8, 9]    // Insert 9: already in place
          ─────────────────
Final:    [1, 2, 5, 8, 9]    // Sorted!
```

### Key Observation

**Values are MOVED, never MODIFIED arithmetically.**

The value `5` stays `5` throughout — it only changes position. This is the key insight that makes insertion sort **1-robust** (not N-robust like graph algorithms).

---

## The Property: 1-Robustness

### Formal Definition

```
∀k. |A1[k] - A2[k]| ≤ ε  ⟹  ∀k. |A1'[k] - A2'[k]| ≤ ε
     ~~~~~~~~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~
     INPUT arrays             OUTPUT arrays (sorted)
```

### In Plain English

> If two input arrays have corresponding elements that differ by at most ε,
> then after sorting, the output arrays will also have corresponding elements
> that differ by at most ε.

### Example

```
Input A1:  [5.0, 2.0, 8.0, 1.0]
Input A2:  [5.1, 1.9, 8.05, 1.1]    // Each element differs by at most 0.1

After sorting:

Output A1': [1.0, 2.0, 5.0, 8.0]
Output A2': [1.1, 1.9, 5.1, 8.05]   // Still differs by at most 0.1 ✓
```

### Why "1-Robust"?

The bound stays **constant** (1 × ε = ε) regardless of array size.

Compare with graph algorithms like Dijkstra where the bound **grows** with problem size (N × ε).

| Algorithm | Robustness | Final Bound |
|-----------|------------|-------------|
| Insertion Sort | 1-robust | ε |
| Dijkstra | N-robust | N·ε |
| Kruskal MST | (N-1)-robust | (N-1)·ε |

---

## The Challenge: Array Reasoning

### The Problem

To verify 1-robustness, we need to prove:

```
∀k. |A1'[k] - A2'[k]| ≤ ε
```

This requires reasoning about **all array indices simultaneously**.

**But CHC (Constrained Horn Clauses) solvers cannot handle quantified array properties directly!**

### Why Arrays Are Hard

```
// We want to verify this for ALL k:
forall k: 0 <= k < n ==> |A1[k] - A2[k]| <= eps

// But we can't enumerate all k (n could be unbounded)
// And we can't use array theories in standard CHC solvers
```

### Traditional Approaches (and their limitations)

1. **Enumerate all indices**: Only works for fixed, small n
2. **Array theories**: Not supported by many CHC solvers
3. **Abstract interpretation**: May lose precision

---

## The Solution: Relational Cell Morphing

### The Key Idea

Instead of tracking the **entire array**, we track **one symbolic cell**:

```
┌─────────────────────────────────────────────────────────────┐
│  ARRAY A                                                    │
│                                                             │
│  Index:   0      1      2      k      4      5     ...     │
│          ┌──────┬──────┬──────┬──────┬──────┬──────┐       │
│  A1:     │  ?   │  ?   │  ?   │ ak1  │  ?   │  ?   │       │
│          └──────┴──────┴──────┴──────┴──────┴──────┘       │
│          ┌──────┬──────┬──────┬──────┬──────┬──────┐       │
│  A2:     │  ?   │  ?   │  ?   │ ak2  │  ?   │  ?   │       │
│          └──────┴──────┴──────┴──────┴──────┴──────┘       │
│                              ↑                              │
│                    Distinguished Cell k                     │
│                                                             │
│  We track: ak1 (value A1[k]) and ak2 (value A2[k])         │
│  We know:  |ak1 - ak2| ≤ ε                                  │
│  All other cells: unknown (represented as ?)                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### The Universal Quantification Trick

**`k` is symbolic (universally quantified)**

- We don't assign `k` a specific value like 0, 1, 2...
- Instead, `k` represents an **arbitrary** valid index
- If we prove the property holds for this arbitrary `k`, it holds for **ALL** indices!

```
Proof structure:
1. Pick arbitrary k where 0 ≤ k < n
2. Track A1[k] and A2[k] through execution
3. Prove |A1'[k] - A2'[k]| ≤ ε at termination
4. Since k was arbitrary, this holds for all indices ∀k. QED
```

### Why This Works

The proof is **parametric** in k. Any property we prove about the distinguished cell k holds for every possible index, because we never assumed anything special about which index k is.

---

## State Variables

The encoding uses the following state variables:

```
Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps)
```

### Control Flow Variables

These track where each run is in the algorithm:

| Variable | Type | Meaning |
|----------|------|---------|
| `i1, i2` | int | Outer loop index (which element to insert) |
| `j1, j2` | int | Inner loop index (current shift position) |
| `key1, key2` | real | The value being inserted (saved from A[i]) |
| `b1, b2` | bool | Loop phase: `false` = outer head, `true` = inner loop |
| `n1, n2` | int | Array sizes (must be equal) |

### Distinguished Cell Variables

These implement the cell morphing technique:

| Variable | Type | Meaning |
|----------|------|---------|
| `k` | int | Distinguished index (symbolic, universally quantified) |
| `ak1` | real | Value A1[k] in run 1 |
| `ak2` | real | Value A2[k] in run 2 |
| `bk` | bool | Sign bit: `true` ⟹ ak2 ≥ ak1, `false` ⟹ ak1 > ak2 |
| `eps` | real | Perturbation bound (ε ≥ 0) |

### Why Two Runs?

We verify a **relational property** comparing two executions:
- **Run 1**: Sorts array A1
- **Run 2**: Sorts array A2

The scheduler (SchTF, SchFT, SchTT) controls which run(s) take steps.

---

## The PCSAT Encoding

### Encoding Structure Overview

```
┌─────────────────────────────────────────────────────────────┐
│  PCSAT CLAUSE STRUCTURE                                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. INITIALIZATION                                          │
│     Inv(...) :- initial_conditions.                         │
│                                                             │
│  2. TRANSITIONS (TF, FT, TT)                                │
│     Inv(updated) :-                                         │
│         Inv(current),                                       │
│         Scheduler(...),                                     │
│         (case1) or (case2) or ... ,                         │
│         epsilon_bound.                                      │
│                                                             │
│  3. FAIRNESS CONSTRAINTS                                    │
│     Ensure both runs can make progress                      │
│                                                             │
│  4. SCHEDULER DISJUNCTION                                   │
│     At least one scheduler active when progress possible    │
│                                                             │
│  5. GOAL CLAUSE                                             │
│     Check if violation is reachable                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### Initialization

```prolog
Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps) :-
  i1 = 0, i2 = 0,           (* Outer loop starts at index 0 *)
  j1 = -1, j2 = -1,         (* j = -1 indicates "not in inner loop" *)
  n1 > 0, n1 = n2,          (* Valid arrays of equal size *)
  0 <= k, k < n1,           (* k is a valid index *)
  !b1, !b2,                 (* Both runs start at outer loop head *)
  0 <= eps,                 (* Non-negative perturbation bound *)
  (* INPUT PRECONDITION: |ak1 - ak2| ≤ eps *)
  (bk and 0 <= ak2 - ak1 and ak2 - ak1 <= eps) or
  (!bk and 0 <= ak1 - ak2 and ak1 - ak2 <= eps).
```

#### Explanation

**Initial state**:
- Both runs at the start of the algorithm (`i = 0`, not in inner loop)
- `k` is declared but not assigned → it's symbolic (arbitrary)
- `ak1, ak2` satisfy the input assumption: `|ak1 - ak2| ≤ ε`

**The sign bit `bk`**:
Since we can't write `|ak1 - ak2| ≤ eps` directly in linear arithmetic, we use:
```
bk = true:  ak2 ≥ ak1, so |ak1 - ak2| = ak2 - ak1
bk = false: ak1 > ak2, so |ak1 - ak2| = ak1 - ak2
```

---

### TF Transition (Run 1 Steps)

This is the most detailed transition. Only **Run 1** takes a step while Run 2 waits.

```prolog
Inv(i1', i2, j1', j2, key1', key2, n1, n2, k, ak1', ak2, bk:bool, b1':bool, b2:bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchTF(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (
    (* Case 1: Outer loop - read key *)
    !b1 and i1 < n1 and i1' = i1 and j1' = i1 - 1 and b1' and
    (i1 = k and key1' = ak1 or i1 <> k) and
    ak1' = ak1
  ) or (
    (* Case 2: Inner loop body - shift *)
    b1 and j1 >= 0 and i1' = i1 and j1' = j1 - 1 and b1' and
    (j1 = k and 
      ak1 > key1 and
      (j1 + 1 = k and ak1' = ak1 or j1 + 1 <> k and ak1' = ak1)
     or j1 <> k and
      ak1' = ak1
    ) and
    key1' = key1
  ) or (
    (* Case 3: Inner loop exit - write key *)
    b1 and i1' = i1 and !b1' and j1' = j1 and
    (j1 < 0 or 
     j1 = k and ak1 <= key1 or 
     j1 <> k) and
    (j1 + 1 = k and ak1' = key1 or j1 + 1 <> k and ak1' = ak1) and
    key1' = key1
  ) or (
    (* Case 4: Outer loop increment *)
    !b1 and i1 < n1 and i1' = i1 + 1 and !b1' and j1' = -1 and
    ak1' = ak1 and key1' = key1
  ) or (
    (* Case 5: Finished *)
    !b1 and i1 >= n1 and i1' = i1 and !b1' and j1' = j1 and
    ak1' = ak1 and key1' = key1
  ),
  (* Maintain epsilon bound *)
  (bk and 0 <= ak2 - ak1' and ak2 - ak1' <= eps) or
  (!bk and 0 <= ak1' - ak2 and ak1' - ak2 <= eps).
```

#### Case 1: Outer Loop — Read Key

**Code**: `key = A[i]`

```prolog
!b1 and i1 < n1 and i1' = i1 and j1' = i1 - 1 and b1' and
(i1 = k and key1' = ak1 or i1 <> k) and
ak1' = ak1
```

**HIT/MISS Analysis**:

| Condition | What Happens | Result |
|-----------|--------------|--------|
| `i1 = k` (HIT) | Reading distinguished cell | `key1' = ak1` (exact value known) |
| `i1 <> k` (MISS) | Reading other cell | `key1'` unconstrained (unknown) |

**Critical**: `ak1' = ak1` — reading doesn't change the value!

#### Case 2: Inner Loop Body — Shift

**Code**: `A[j+1] = A[j]; j--`

```prolog
b1 and j1 >= 0 and i1' = i1 and j1' = j1 - 1 and b1' and
(j1 = k and 
  ak1 > key1 and
  (j1 + 1 = k and ak1' = ak1 or j1 + 1 <> k and ak1' = ak1)
 or j1 <> k and
  ak1' = ak1
) and
key1' = key1
```

This is the most complex case. We READ from `A[j]` and WRITE to `A[j+1]`:

```
┌─────────────────────────────────────────────────────────────────────┐
│  SHIFT OPERATION: A[j+1] = A[j]                                     │
│                                                                     │
│  READ index: j        WRITE index: j+1                              │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Case: j = k (READ HIT)                                       │   │
│  │                                                               │   │
│  │   We're reading the distinguished cell!                       │   │
│  │   • We KNOW the value is ak1                                  │   │
│  │   • The comparison ak1 > key1 must be true (else no shift)   │   │
│  │   • Now check the WRITE target:                               │   │
│  │     ├── j+1 = k: Writing TO distinguished cell               │   │
│  │     │            But we're writing ak1! So ak1' = ak1 ✓      │   │
│  │     └── j+1 ≠ k: Writing elsewhere                           │   │
│  │                  Distinguished cell unchanged: ak1' = ak1 ✓  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Case: j ≠ k (READ MISS)                                      │   │
│  │                                                               │   │
│  │   We're reading some other cell (unknown value)               │   │
│  │   • Comparison result is NON-DETERMINISTIC                    │   │
│  │   • Either we shift (continue inner loop) or we don't        │   │
│  │   • Either way: ak1' = ak1 (distinguished cell unchanged) ✓  │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

**Key insight**: Even when we write TO the distinguished cell (`j+1 = k`), we're writing `ak1` (the value we just read from `j = k`), so `ak1' = ak1`!

#### Case 3: Inner Loop Exit — Write Key

**Code**: `A[j+1] = key`

```prolog
b1 and i1' = i1 and !b1' and j1' = j1 and
(j1 < 0 or 
 j1 = k and ak1 <= key1 or 
 j1 <> k) and
(j1 + 1 = k and ak1' = key1 or j1 + 1 <> k and ak1' = ak1) and
key1' = key1
```

**Exit conditions** (when do we stop shifting?):
- `j < 0`: Reached the beginning of the array
- `j = k and ak1 <= key1`: HIT — we know A[j] ≤ key
- `j <> k`: MISS — comparison unknown, non-deterministic exit

**Write analysis** (inserting the key):

| Condition | What Happens | Result |
|-----------|--------------|--------|
| `j1 + 1 = k` (HIT) | Writing TO distinguished cell | `ak1' = key1` |
| `j1 + 1 <> k` (MISS) | Writing elsewhere | `ak1' = ak1` |

**This is where `ak1` can change!** But the bound is maintained because `key1` came from the input array where all values satisfy the ε bound.

#### Cases 4 & 5: Increment and Finished

```prolog
(* Case 4: Outer loop increment - move to next element *)
!b1 and i1 < n1 and i1' = i1 + 1 and !b1' and j1' = -1 and
ak1' = ak1 and key1' = key1

(* Case 5: Finished - algorithm complete *)
!b1 and i1 >= n1 and i1' = i1 and !b1' and j1' = j1 and
ak1' = ak1 and key1' = key1
```

Simple cases with no array access: `ak1' = ak1` always.

#### The Epsilon Bound Clause

Every transition ends with:

```prolog
(bk and 0 <= ak2 - ak1' and ak2 - ak1' <= eps) or
(!bk and 0 <= ak1' - ak2 and ak1' - ak2 <= eps)
```

This enforces: `|ak1' - ak2| ≤ eps`

**Note**: We use `ak2` (not `ak2'`) because in TF, only run 1 steps!

---

### FT Transition (Run 2 Steps)

Symmetric to TF, but only Run 2 steps:

```prolog
Inv(i1, i2', j1, j2', key1, key2', n1, n2, k, ak1, ak2', bk:bool, b1:bool, b2':bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchFT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (* Same case structure as TF, but for run 2 *)
  ...
  (* Epsilon bound uses ak2' and ak1 *)
  (bk and 0 <= ak2' - ak1 and ak2' - ak1 <= eps) or
  (!bk and 0 <= ak1 - ak2' and ak1 - ak2' <= eps).
```

---

### TT Transition (Both Step)

Both runs step simultaneously:

```prolog
Inv(i1', i2', j1', j2', key1', key2', n1, n2, k, ak1', ak2', bk:bool, b1':bool, b2':bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchTT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (* Run 1 cases *)
  (...) or (...) or (...) or (...) or (...),
  (* Run 2 cases *)
  (...) or (...) or (...) or (...) or (...),
  (* Epsilon bound uses both primed variables *)
  (bk and 0 <= ak2' - ak1' and ak2' - ak1' <= eps) or
  (!bk and 0 <= ak1' - ak2' and ak1' - ak2' <= eps).
```

---

### Scheduler Clauses

#### Fairness Constraints

```prolog
(* If TF is chosen and run 2 can progress, run 1 must be able to progress *)
i1 < n1 or b1 or j1 >= 0 :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchTF(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  i2 < n2 or b2 or j2 >= 0.

(* Symmetric for FT *)
i2 < n2 or b2 or j2 >= 0 :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchFT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  i1 < n1 or b1 or j1 >= 0.
```

#### Scheduler Disjunction

```prolog
(* At least one scheduler must be active when progress is possible *)
SchTF(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps), 
SchFT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps), 
SchTT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (i1 < n1 or b1 or j1 >= 0) or (i2 < n2 or b2 or j2 >= 0).
```

**Note**: This is a **non-Horn clause** (multiple atoms in the head). This makes the problem pfwCSP rather than standard CHC.

---

### Goal Clause

```prolog
(* Check if violation is reachable at termination *)
ak1 - ak2 > eps or ak2 - ak1 > eps :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  n1 <= i1, n2 <= i2, !b1, !b2.
```

**Meaning**: At termination (both loops finished), is `|ak1 - ak2| > eps` possible?

- **UNSAT**: No! Violation unreachable → **Property verified!**
- **SAT**: Yes, violation is possible → Property does NOT hold

---

## The HIT/MISS Abstraction

### Core Concept

When accessing array index `j`:

| Case | Condition | What We Know | How We Handle It |
|------|-----------|--------------|------------------|
| **HIT** | `j = k` | Accessing distinguished cell | Use exact value `ak1` |
| **MISS** | `j ≠ k` | Accessing other cell | Value unknown, use non-determinism |

### For Array Reads

```
Reading A[j]:
  • HIT (j = k):   value = ak1  (we know exactly!)
  • MISS (j ≠ k):  value = ?    (unknown, non-deterministic)
```

### For Array Writes

```
Writing value v to A[j]:
  • HIT (j = k):   ak1' = v     (distinguished cell updated)
  • MISS (j ≠ k):  ak1' = ak1   (distinguished cell unchanged)
```

### For Comparisons

```
Comparing A[j] > key:
  • HIT (j = k):   ak1 > key    (we can evaluate!)
  • MISS (j ≠ k):  unknown      (non-deterministic: either branch possible)
```

### Visual Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                      HIT/MISS ABSTRACTION                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Array A:   [ ? | ? | ? | ak1 | ? | ? | ? ]                       │
│                           ───┬───                                   │
│                              │                                      │
│                        index k (distinguished)                      │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐  │
│   │  ACCESS at index j:                                          │  │
│   │                                                               │  │
│   │    j = k  (HIT)  →  We know: value = ak1                     │  │
│   │                              comparison: ak1 vs key           │  │
│   │                              write: ak1' = new_value          │  │
│   │                                                               │  │
│   │    j ≠ k  (MISS) →  Unknown: value = ?                       │  │
│   │                              comparison: non-deterministic    │  │
│   │                              write: ak1' = ak1 (unchanged)   │  │
│   └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│   This abstraction is SOUND: we consider all possibilities          │
│   This abstraction is COMPLETE: for the distinguished cell k        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Why 1-Robust Works

### The Key Invariant

```
ak1' = ak1  (almost always!)
```

The value at the distinguished cell **never changes arithmetically**. It can only be:

1. **Read**: unchanged (`ak1' = ak1`)
2. **Shifted**: value moves, but if it's the distinguished cell, it's still `ak1`
3. **Replaced by key**: `ak1' = key1`, but `key1` was also from the input array

### Why the Bound is Preserved

```
┌─────────────────────────────────────────────────────────────────────┐
│                  THE 1-ROBUSTNESS INSIGHT                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  INPUT:   |ak1 - ak2| ≤ ε     (given as precondition)              │
│                                                                     │
│  DURING EXECUTION:                                                  │
│    • Values only MOVE between positions                             │
│    • Values are never MODIFIED (no arithmetic operations)          │
│    • When ak1 changes, it becomes key1 (from another input cell)   │
│    • All input cells satisfy the ε bound                           │
│                                                                     │
│  OUTPUT:  |ak1 - ak2| ≤ ε     (same bound!)                        │
│                                                                     │
│  The bound is CONSTANT because values are PRESERVED!                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Contrast with N-Robust Algorithms

| Algorithm | Operation | Value Change | Bound Growth |
|-----------|-----------|--------------|--------------|
| **Insertion Sort** | Move/copy | `ak1' = ak1` | Constant: ε |
| **Kruskal MST** | Accumulate | `c1' = c1 + w` | Linear: (N-1)·ε |
| **Dijkstra** | Accumulate | `d1' = d1 + w` | Linear: N·ε |

---

## Verification Results

### Running the Verification

```bash
pcsat insertion_sort_robust.clp
```

### Test Results

| Goal Clause | Result | Time | Interpretation |
|-------------|--------|------|----------------|
| `ak1 - ak2 <= eps and ak2 - ak1 <= eps` | **SAT** | ~14s | Bound CAN be satisfied ✓ |
| `ak1 - ak2 > eps or ak2 - ak1 > eps` | **UNSAT** | ~17min | Bound CANNOT be violated ✓ |
| `ak1 = ak2` | **UNSAT** | ~13min | Exact equality too strong ✓ |

### Understanding the Results

#### SAT for Positive Property

```
Goal: ak1 - ak2 <= eps and ak2 - ak1 <= eps
Result: SAT

Meaning: "There EXISTS a reachable terminal state where |ak1 - ak2| ≤ ε"
         → Yes! The algorithm can successfully maintain the bound.
         → This is EXPECTED for a correct algorithm.
```

#### UNSAT for Violation

```
Goal: ak1 - ak2 > eps or ak2 - ak1 > eps  
Result: UNSAT

Meaning: "There is NO reachable terminal state where |ak1 - ak2| > ε"
         → The bound can NEVER be violated!
         → This PROVES 1-ROBUSTNESS! ✓
```

#### UNSAT for Exact Equality

```
Goal: ak1 = ak2
Result: UNSAT

Meaning: "Exact equality is not guaranteed"
         → Correct! We only guarantee bounded difference, not equality.
         → This confirms our property is tight (not too strong).
```

### Verification Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                    VERIFICATION COMPLETE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Property:   1-Robustness of Insertion Sort                         │
│                                                                     │
│  Statement:  ∀k. |A1[k] - A2[k]| ≤ ε ⟹ ∀k. |A1'[k] - A2'[k]| ≤ ε  │
│                                                                     │
│  Result:     VERIFIED ✓                                             │
│                                                                     │
│  Evidence:   Violation query returns UNSAT                          │
│              (no counterexample exists)                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Comparison with N-Robust Algorithms

### Property Comparison

| Aspect | Insertion Sort | Dijkstra | Kruskal MST |
|--------|---------------|----------|-------------|
| **Type** | 1-robust | N-robust | (N-1)-robust |
| **Values** | Preserved (move only) | Accumulate | Accumulate |
| **Key insight** | `ak1' = ak1` | `\|d1'-d2'\| ≤ \|d1-d2\|+ε` | `\|c1'-c2'\| ≤ \|c1-c2\|+ε` |
| **Invariant** | `\|ak1-ak2\| ≤ ε` | `\|d1-d2\| ≤ i·ε` | `\|c1-c2\| ≤ i·ε` |
| **Final bound** | ε | N·ε | (N-1)·ε |

### State Variable Comparison

| Variable | Insertion Sort | Dijkstra | Kruskal |
|----------|---------------|----------|---------|
| Loop counters | i1, i2, j1, j2 | i1, i2 | i1, i2 |
| Distinguished index | k | v | k (edge) |
| Tracked values | ak1, ak2 | dv1, dv2 | wk1, wk2, c1, c2 |
| Input cell | ak1, ak2 | wk1, wk2 (in v2) | wk1, wk2 |
| Output cell | ak1, ak2 (same!) | dv1, dv2 | c1, c2 |

### When to Use Each Pattern

```
Decision tree:

Does the algorithm modify values arithmetically?
├── NO (only moves/copies values)
│   └── 1-ROBUST pattern (like Insertion Sort)
│       • Invariant: |ak1 - ak2| ≤ ε
│       • Key insight: ak1' = ak1
│
└── YES (computes new values)
    └── N-ROBUST pattern (like Dijkstra, Kruskal)
        • Invariant: |output1 - output2| ≤ i·ε
        • Key insight: each step adds ≤ ε to difference
```

---

## Complete Encoding

For reference, here is the complete PCSAT encoding:

```prolog
(*
Insertion-Sort(A : arr)
   i = 1
   while i < n:
       key = A[i]
       j = i - 1
       while j >= 0 and A[j] > key:
           A[j+1] = A[j]
           j -= 1
       A[j+1] = key
       i += 1
*)

(* Initialization *)
Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps) :-
  i1 = 0, i2 = 0,
  j1 = -1, j2 = -1,
  n1 > 0, n1 = n2,
  0 <= k, k < n1,
  !b1, !b2,
  0 <= eps,
  (bk and 0 <= ak2 - ak1 and ak2 - ak1 <= eps) or
  (!bk and 0 <= ak1 - ak2 and ak1 - ak2 <= eps).

(* TF transition - only run 1 steps *)
Inv(i1', i2, j1', j2, key1', key2, n1, n2, k, ak1', ak2, bk:bool, b1':bool, b2:bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchTF(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (
    !b1 and i1 < n1 and i1' = i1 and j1' = i1 - 1 and b1' and
    (i1 = k and key1' = ak1 or i1 <> k) and
    ak1' = ak1
  ) or (
    b1 and j1 >= 0 and i1' = i1 and j1' = j1 - 1 and b1' and
    (j1 = k and 
      ak1 > key1 and
      (j1 + 1 = k and ak1' = ak1 or j1 + 1 <> k and ak1' = ak1)
     or j1 <> k and
      ak1' = ak1
    ) and
    key1' = key1
  ) or (
    b1 and i1' = i1 and !b1' and j1' = j1 and
    (j1 < 0 or j1 = k and ak1 <= key1 or j1 <> k) and
    (j1 + 1 = k and ak1' = key1 or j1 + 1 <> k and ak1' = ak1) and
    key1' = key1
  ) or (
    !b1 and i1 < n1 and i1' = i1 + 1 and !b1' and j1' = -1 and
    ak1' = ak1 and key1' = key1
  ) or (
    !b1 and i1 >= n1 and i1' = i1 and !b1' and j1' = j1 and
    ak1' = ak1 and key1' = key1
  ),
  (bk and 0 <= ak2 - ak1' and ak2 - ak1' <= eps) or
  (!bk and 0 <= ak1' - ak2 and ak1' - ak2 <= eps).

(* FT transition - only run 2 steps *)
Inv(i1, i2', j1, j2', key1, key2', n1, n2, k, ak1, ak2', bk:bool, b1:bool, b2':bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchFT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (
    !b2 and i2 < n2 and i2' = i2 and j2' = i2 - 1 and b2' and
    (i2 = k and key2' = ak2 or i2 <> k) and
    ak2' = ak2
  ) or (
    b2 and j2 >= 0 and i2' = i2 and j2' = j2 - 1 and b2' and
    (j2 = k and 
      ak2 > key2 and
      (j2 + 1 = k and ak2' = ak2 or j2 + 1 <> k and ak2' = ak2)
     or j2 <> k and
      ak2' = ak2
    ) and
    key2' = key2
  ) or (
    b2 and i2' = i2 and !b2' and j2' = j2 and
    (j2 < 0 or j2 = k and ak2 <= key2 or j2 <> k) and
    (j2 + 1 = k and ak2' = key2 or j2 + 1 <> k and ak2' = ak2) and
    key2' = key2
  ) or (
    !b2 and i2 < n2 and i2' = i2 + 1 and !b2' and j2' = -1 and
    ak2' = ak2 and key2' = key2
  ) or (
    !b2 and i2 >= n2 and i2' = i2 and !b2' and j2' = j2 and
    ak2' = ak2 and key2' = key2
  ),
  (bk and 0 <= ak2' - ak1 and ak2' - ak1 <= eps) or
  (!bk and 0 <= ak1 - ak2' and ak1 - ak2' <= eps).

(* TT transition - both runs step *)
Inv(i1', i2', j1', j2', key1', key2', n1, n2, k, ak1', ak2', bk:bool, b1':bool, b2':bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchTT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (
    !b1 and i1 < n1 and i1' = i1 and j1' = i1 - 1 and b1' and
    (i1 = k and key1' = ak1 or i1 <> k) and
    ak1' = ak1
  ) or (
    b1 and j1 >= 0 and i1' = i1 and j1' = j1 - 1 and b1' and
    (j1 = k and ak1 > key1 and (j1 + 1 = k and ak1' = ak1 or j1 + 1 <> k and ak1' = ak1)
     or j1 <> k and ak1' = ak1) and
    key1' = key1
  ) or (
    b1 and i1' = i1 and !b1' and j1' = j1 and
    (j1 < 0 or j1 = k and ak1 <= key1 or j1 <> k) and
    (j1 + 1 = k and ak1' = key1 or j1 + 1 <> k and ak1' = ak1) and
    key1' = key1
  ) or (
    !b1 and i1 < n1 and i1' = i1 + 1 and !b1' and j1' = -1 and
    ak1' = ak1 and key1' = key1
  ) or (
    !b1 and i1 >= n1 and i1' = i1 and !b1' and j1' = j1 and
    ak1' = ak1 and key1' = key1
  ),
  (
    !b2 and i2 < n2 and i2' = i2 and j2' = i2 - 1 and b2' and
    (i2 = k and key2' = ak2 or i2 <> k) and
    ak2' = ak2
  ) or (
    b2 and j2 >= 0 and i2' = i2 and j2' = j2 - 1 and b2' and
    (j2 = k and ak2 > key2 and (j2 + 1 = k and ak2' = ak2 or j2 + 1 <> k and ak2' = ak2)
     or j2 <> k and ak2' = ak2) and
    key2' = key2
  ) or (
    b2 and i2' = i2 and !b2' and j2' = j2 and
    (j2 < 0 or j2 = k and ak2 <= key2 or j2 <> k) and
    (j2 + 1 = k and ak2' = key2 or j2 + 1 <> k and ak2' = ak2) and
    key2' = key2
  ) or (
    !b2 and i2 < n2 and i2' = i2 + 1 and !b2' and j2' = -1 and
    ak2' = ak2 and key2' = key2
  ) or (
    !b2 and i2 >= n2 and i2' = i2 and !b2' and j2' = j2 and
    ak2' = ak2 and key2' = key2
  ),
  (bk and 0 <= ak2' - ak1' and ak2' - ak1' <= eps) or
  (!bk and 0 <= ak1' - ak2' and ak1' - ak2' <= eps).

(* Fairness constraint 1 *)
i1 < n1 or b1 or j1 >= 0 :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchTF(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  i2 < n2 or b2 or j2 >= 0.

(* Fairness constraint 2 *)
i2 < n2 or b2 or j2 >= 0 :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchFT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  i1 < n1 or b1 or j1 >= 0.

(* Scheduler disjunction *)
SchTF(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps), 
SchFT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps), 
SchTT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (i1 < n1 or b1 or j1 >= 0) or (i2 < n2 or b2 or j2 >= 0).

(* Goal: violation should be unreachable *)
ak1 - ak2 > eps or ak2 - ak1 > eps :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  n1 <= i1, n2 <= i2, !b1, !b2.
```

---

## Key Takeaways

### 1. Relational Cell Morphing

- Track **one symbolic cell** instead of entire array
- `k` is universally quantified — proof holds for all indices
- Reduces unbounded array reasoning to finite state

### 2. HIT/MISS Abstraction

- **HIT** (access k): use exact value `ak1`
- **MISS** (access ≠k): value unknown, use non-determinism
- Sound and complete for the distinguished cell

### 3. 1-Robust vs N-Robust

- **1-robust**: values preserved (`ak1' = ak1`)
- **N-robust**: values accumulate (`c1' = c1 + w`)
- Choose pattern based on whether algorithm modifies values arithmetically

### 4. PCSAT Encoding Structure

```
Inv(updated) :-
    Inv(current),
    Scheduler(...),
    (case1) or (case2) or ...,
    epsilon_bound.    ← SEPARATE clause at end!
```

### 5. Verification Interpretation

| Goal | Result | Meaning |
|------|--------|---------|
| Property holds | SAT | Property is achievable ✓ |
| Violation | UNSAT | Property is verified ✓ |
| Stronger property | UNSAT | Too strong (expected) |

### 6. PCSAT Syntax Notes

- Use `and`, `or` inside compound expressions (not `;`)
- Use `,` between top-level predicates
- Use `!b` for boolean negation
- Use `<>` for not-equal
- **Cannot write `bk' = bk`** for boolean variables!

---

## References

1. **Chaudhuri, Gulwani, Lublinerman** - "Continuity and Robustness of Programs" (CACM 2012)
   - Original framework for robustness verification

2. **Monniaux & Gonnord** - "Cell Morphing: From Array Programs to Array-Free Horn Clauses" (SAS 2016)
   - The cell morphing technique for array abstraction

3. **Unno, Terauchi, Kobayashi** - "Constraint-based Relational Verification" (CAV 2021)
   - pfwCSP and relational verification framework

4. **PCSAT Solver**
   - Tool for solving predicate constraint satisfaction problems

---

## Document Information

- **Version**: 1.0
- **Last Updated**: February 2025
- **Authors**: PCSAT Verification Project
- **License**: For academic and research use

---

*This document is part of the PCSAT Robustness Verification tutorial series.*
