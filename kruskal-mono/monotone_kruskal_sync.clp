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
SYNCHRONIZED MODEL
================================================================================

Why synchronized: Both runs process edges in the SAME order and make the
SAME add/skip decisions. The union-find structure depends only on which
edges were added, not their weights. So at each step, both runs either
both add or both skip the current edge.

In the asynchronous model, runs could make DIFFERENT add/skip decisions.
Proving monotonicity then requires MST optimality (matroid argument),
which cell morphing cannot capture. See session notes section 6.2.

ENCODING STRUCTURE (mirrors robustness kruskal_v2_fixed.clp):
    - Single counter i instead of i1, i2 (synchronized)
    - Same HIT/MISS/SKIP/FINISHED cases as robustness
    - Monotone bound c1' <= c2' replaces epsilon bound
    - No sign bits (bk, bc), no eps parameter needed
    - Counter i counts edges ADDED to MST (skip does NOT increment)
    - Loop bound n-1 (MST has n-1 edges for n vertices)

STATE VARIABLES (7 total):
    i    : edges added to MST (both runs, synchronized)
    k    : distinguished edge index (INPUT — never changes)
    wk1  : weight of edge k in run 1 (INPUT — never changes)
    wk2  : weight of edge k in run 2 (INPUT — never changes)
    c1   : MST cost for run 1 (OUTPUT — accumulates)
    c2   : MST cost for run 2 (OUTPUT — accumulates)
    n    : number of vertices

SOUNDNESS of monotone bound at each step:
    HIT ADD:  c1' = c1+wk1, c2' = c2+wk2. Since c1<=c2 and wk1<=wk2 => c1'<=c2'
    MISS ADD: c1' = c1+w1[e], c2' = c2+w2[e]. Since c1<=c2 and w1[e]<=w2[e] => c1'<=c2'
    SKIP:     c1' = c1, c2' = c2. Trivially c1'<=c2'.
    FINISHED: c1' = c1, c2' = c2. Trivially c1'<=c2'.

EXPECTED: UNSAT (fast — 7 variables, trivial invariant c1 <= c2)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, k, wk1, wk2, c1, c2, n) :-
    i = 0,
    n > 0,
    0 <= k,
    (* Distinguished edge weight precondition: wk1 <= wk2 *)
    wk1 <= wk2,
    (* Initial costs are equal *)
    c1 = 0, c2 = 0.


(******************************************************************************)
(* TRANSITION (synchronized — single counter, no scheduler)                   *)
(*                                                                            *)
(* Both runs consider the SAME edge simultaneously.                           *)
(* Both make the SAME decision (add or skip).                                 *)
(* Counter i counts edges ADDED to MST, terminates at n-1.                    *)
(*                                                                            *)
(* Cases:                                                                     *)
(*   1. HIT ADD: Both add distinguished edge k — c1'=c1+wk1, c2'=c2+wk2     *)
(*   2. MISS ADD: Both add other edge — weights unknown but w1[e]<=w2[e]     *)
(*   3. SKIP: Both skip edge — costs unchanged, counter unchanged            *)
(*   4. FINISHED: i >= n-1, stutter                                           *)
(******************************************************************************)

Inv(i', k, wk1, wk2, c1', c2', n) :-
    Inv(i, k, wk1, wk2, c1, c2, n),
    (
        (* Case 1: HIT ADD — both add distinguished edge k *)
        i < n - 1 and i' = i + 1 and
        c1' = c1 + wk1 and c2' = c2 + wk2
    ) or (
        (* Case 2: MISS ADD — both add other edge *)
        (* Weights unknown; c1' and c2' constrained by monotone bound below *)
        i < n - 1 and i' = i + 1
    ) or (
        (* Case 3: SKIP — both skip current edge, not added to MST *)
        i < n - 1 and i' = i and c1' = c1 and c2' = c2
    ) or (
        (* Case 4: FINISHED — stutter *)
        i >= n - 1 and i' = i and c1' = c1 and c2' = c2
    ),
    (* Monotone bound — replaces epsilon bound from robustness *)
    c1' <= c2'.


(******************************************************************************)
(* GOAL: Monotonicity violation at termination                                *)
(*                                                                            *)
(* UNSAT = cost(MST_1) <= cost(MST_2) verified                               *)
(******************************************************************************)

c1 <= c2 :-
    Inv(i, k, wk1, wk2, c1, c2, n),
    n - 1 <= i.


(******************************************************************************)
(* TEST QUERIES                                                               *)
(******************************************************************************)

(*
(* Test 1: Violation c1 > c2 — expected UNSAT *)
c1 > c2 :-
    Inv(i, k, wk1, wk2, c1, c2, n),
    n - 1 <= i.
unsat,0
1.014 total
(* Test 2: Bound holds c1 <= c2 — expected SAT *)
c1 <= c2 :-
    Inv(i, k, wk1, wk2, c1, c2, n),
    n - 1 <= i.
 sat,27
3.777 total   
*)
