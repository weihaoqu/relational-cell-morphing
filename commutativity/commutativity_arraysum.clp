(*
ArraySum(A: array, n: size)
    s := 0
    for i = 0 to n-1:
        s := s + A[i]
    return s
*)

(*
PROPERTY: Commutativity (Swap Invariance)
  Swapping two elements does not change the sum.

  Formally: Let A' be A with positions j and k swapped:
    A'[j] = A[k], A'[k] = A[j], A'[i] = A[i] for i != j,k
  Then: ArraySum(A) = ArraySum(A')

================================================================================
WHY THIS IS A NEW ENCODING PATTERN
================================================================================

Previous encodings: two runs on DIFFERENT inputs, same processing order.
  Robustness:   A1[i] ~= A2[i] (perturbed values)
  Sensitivity:  A1 differs from A2 at one position
  Monotonicity: A1[i] <= A2[i] (ordered values)

This encoding: two runs on inputs differing by a SWAP.
  Run 1: ..., A[j]=vj, ..., A[k]=vk, ...
  Run 2: ..., A[j]=vk, ..., A[k]=vj, ...  (swapped!)
  Other positions: identical in both runs.

NEW FEATURES:
  1. TWO distinguished cells (j and k) instead of one
  2. HIT fires TWICE per run (once at j, once at k)
  3. MISS preserves the difference (same value added to both runs)
  4. Postcondition is EQUALITY (s1 = s2), not inequality

================================================================================
ENCODING: SYNCHRONIZED MODEL
================================================================================

State: i, j, k, vj, vk, s1, s2, n  (8 variables, no booleans, no epsilon)

TWO DISTINGUISHED CELLS:
  - Position j with value vj (in run 1) / vk (in run 2)
  - Position k with value vk (in run 1) / vj (in run 2)

HIT-j (i = j):  Run 1 adds vj,  Run 2 adds vk
HIT-k (i = k):  Run 1 adds vk,  Run 2 adds vj
MISS  (i != j, i != k): Both runs add the SAME unknown value

After both HITs: run 1 added (vj + vk), run 2 added (vk + vj) = same total.
MISS steps: identical contributions. Therefore s1 = s2 at termination.
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, j, k, vj, vk, s1, s2, n) :-
    i = 0,
    n > 0,
    (* Two distinct valid positions *)
    0 <= j, j < n,
    0 <= k, k < n,
    j <> k,
    (* Non-negative values *)
    0 <= vj,
    0 <= vk,
    (* Both sums start at zero *)
    s1 = 0, s2 = 0.


(******************************************************************************)
(* TRANSITION (synchronized)                                                  *)
(*                                                                            *)
(* Three cases based on which distinguished cell we're at:                    *)
(*                                                                            *)
(* HIT-j (i = j):                                                             *)
(*   Run 1: s1' = s1 + vj    (original value at j)                           *)
(*   Run 2: s2' = s2 + vk    (swapped: k's value is now at j)                *)
(*   Difference change: (s2'-s1') - (s2-s1) = vk - vj                       *)
(*                                                                            *)
(* HIT-k (i = k):                                                             *)
(*   Run 1: s1' = s1 + vk    (original value at k)                           *)
(*   Run 2: s2' = s2 + vj    (swapped: j's value is now at k)                *)
(*   Difference change: (s2'-s1') - (s2-s1) = vj - vk                       *)
(*                                                                            *)
(* After both HITs: net difference change = (vk-vj) + (vj-vk) = 0            *)
(*                                                                            *)
(* MISS (i != j, i != k):                                                     *)
(*   Both runs add the SAME value (unswapped positions are identical)         *)
(*   s1' - s1 = s2' - s2    (same increment)                                 *)
(*   Difference preserved: (s2'-s1') = (s2-s1)                               *)
(******************************************************************************)

Inv(i', j, k, vj, vk, s1', s2', n) :-
    Inv(i, j, k, vj, vk, s1, s2, n),
    (
        (* HIT-j: process position j *)
        (* Run 1 sees vj (original), Run 2 sees vk (swapped in) *)
        i < n and i = j and i' = i + 1 and
        s1' = s1 + vj and s2' = s2 + vk
    ) or (
        (* HIT-k: process position k *)
        (* Run 1 sees vk (original), Run 2 sees vj (swapped in) *)
        i < n and i = k and i' = i + 1 and
        s1' = s1 + vk and s2' = s2 + vj
    ) or (
        (* MISS: process other position — SAME value in both runs *)
        (* The key constraint: same increment for both runs *)
        i < n and i <> j and i <> k and i' = i + 1 and
        s1' >= s1 and
        s1' - s1 = s2' - s2
    ) or (
        (* Finished: stutter *)
        i >= n and i' = i and s1' = s1 and s2' = s2
    ).


(******************************************************************************)
(* GOAL: Commutativity violation                                              *)
(*                                                                            *)
(* UNSAT = ArraySum is invariant under swap VERIFIED                          *)
(*                                                                            *)
(* We test s1 != s2 at termination, encoded as disjunction:                   *)
(*   s1 > s2 or s2 > s1                                                      *)
(******************************************************************************)

s1 > s2 or s2 > s1 :-
    Inv(i, j, k, vj, vk, s1, s2, n),
    n <= i.


(******************************************************************************)
(* TEST QUERIES                                                               *)
(******************************************************************************)

(*
(* Test 1: Inequality violation — expected UNSAT *)
s1 > s2 or s2 > s1 :-
    Inv(i, j, k, vj, vk, s1, s2, n),
    n <= i.

(* Test 2: One direction — expected UNSAT *)
s1 > s2 :-
    Inv(i, j, k, vj, vk, s1, s2, n),
    n <= i.

(* Test 3: Equality — expected SAT (forall: all terminated states have s1=s2) *)
s1 = s2 :-
    Inv(i, j, k, vj, vk, s1, s2, n),
    n <= i.

(* Test 4: Non-vacuity — expected SAT *)
s1 >= 0 :-
    Inv(i, j, k, vj, vk, s1, s2, n),
    n <= i.

(* Test 5: Mid-execution difference — expected SAT *)
(* After HIT-j but before HIT-k, s1 != s2 if vj != vk *)
s1 > s2 :-
    Inv(i, j, k, vj, vk, s1, s2, n),
    i > j, i <= k, vj > vk.

(* Test 6: Sanity — remove swap, should FAIL *)
(* If we make HIT-j also add vj to run 2 (no swap), then s1=s2 always *)
(* and the property becomes trivially true *)
*)
