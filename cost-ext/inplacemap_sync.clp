(*
InplaceMap(A: array, n: size)
    for i = 0 to n-1:
        x = A[i]
        A[i] = f(x)         (* f(x) = x > 0 ? x + 1 : 1 *)
    return
*)

(*
==========================================================================
InplaceMap: Sync + PickK + Prophecy — MUTABLE ARRAY Cell Morphing
==========================================================================

PROPERTY: Relative execution cost under replace metric.
  If A1 and A2 share at least d0 equal positions (before the map),
  then |cost1 - cost2| <= n - d0.

  where cost = number of iterations where the two runs DISAGREE
  on which branch of f they take (one has x>0, other has x<=0).

  When a1[i] = a2[i], f(a1[i]) = f(a2[i]) — same branch, cost neutral.
  When a1[i] <> a2[i], branches may differ — cost +-1.

WHY THIS EXAMPLE MATTERS:
  Unlike countpositive (read-only), InplaceMap WRITES to the array.
  Cell morphing tracks values that CHANGE during execution:
    - HIT at step i: ak1' = f(ak1p), ak2' = f(ak2p)  (cell mutates!)
    - MISS: cell values unchanged

  This shows PickK + prophecy works with mutable arrays, not just scans.

  f preserves equality: ak1p = ak2p => f(ak1p) = f(ak2p).
  So the equal-discovery mechanism still works:
    HIT equal => both runs apply same f => still equal after mutation.

COMPARISON WITH ORIGINAL (relational-map-cm-beta-singlek2.clp):
  Original: async + fixed k + no prophecy => bound n-1, requires bk=1 in goal
  This:     sync + PickK + prophecy       => bound n-d0, no bk constraint

State: i, n, k, ak1, ak2, bk, d, d0, c  (9 Inv variables)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i, n, k, ak1, ak2, bk, d, d0, c) :-
  i = 0, n > 0,
  0 <= k, k < n,
  (ak1 = ak2 and bk = 1) or (ak1 <> ak2 and bk = 0),
  d = 0,
  d0 >= 0,
  c = 0.


(******************************************************************************)
(* TRANSITION                                                                 *)
(*                                                                            *)
(* At each step i, both runs read A[i], apply f, write back.                  *)
(*                                                                            *)
(* HIT equal (i=kp, bkp=1): ak1p = ak2p                                     *)
(*   f(ak1p) = f(ak2p) — same branch of f, same result                      *)
(*   Cell mutates: ak1' = f(ak1p), ak2' = ak1' (still equal)               *)
(*   Cost neutral: c' = c                                                     *)
(*   Discovery: d' = d + 1                                                    *)
(*                                                                            *)
(* HIT unequal (i=kp, bkp=0): ak1p <> ak2p                                  *)
(*   f(ak1p) and f(ak2p) may take different branches                         *)
(*   Cell mutates: ak1' = f(ak1p), ak2' = f(ak2p)                           *)
(*   Worst case: c' = c + 1                                                   *)
(*                                                                            *)
(* MISS (i<>kp): unknown values, worst case c' = c + 1                       *)
(*   Cell unchanged: ak1' = ak1p, ak2' = ak2p                               *)
(******************************************************************************)

Inv(i', n, kp, ak1', ak2', bk', d', d0, c') :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  i < n,
  PickK(i, n, k, ak1, ak2, bk, d, d0, c, kp),
  Wit(i, n, kp, ak1p, ak2p, bkp, d, d0, c),
  (
    (* HIT equal: f preserves equality, cost neutral *)
    (* ak1p = ak2p, so both take same branch of f *)
    (i = kp and bkp = 1
     and (
       (ak1p > 0 and ak1' = ak1p + 1) or
       (ak1p <= 0 and ak1' = 1)
     )
     and ak2' = ak1'
     and c' = c
     and d' = d + 1)
    or
    (* HIT unequal: apply f independently, may disagree *)
    (i = kp and bkp = 0
     and (
       (ak1p > 0 and ak1' = ak1p + 1) or
       (ak1p <= 0 and ak1' = 1)
     )
     and (
       (ak2p > 0 and ak2' = ak2p + 1) or
       (ak2p <= 0 and ak2' = 1)
     )
     and c' = c + 1
     and d' = d)
    or
    (* MISS: untracked position, cell unchanged, worst case cost *)
    (i <> kp
     and ak1' = ak1p
     and ak2' = ak2p
     and c' = c + 1
     and d' = d)
  ),
  i' = i + 1,
  (ak1' = ak2' and bk' = 1 or ak1' <> ak2' and bk' = 0).


(******************************************************************************)
(* WITNESS                                                                    *)
(******************************************************************************)

Wit(i, n, k, ak1, ak2, bk, d, d0, c) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  i < n.


(******************************************************************************)
(* PICKK                                                                      *)
(******************************************************************************)

PickK(i, n, k, ak1, ak2, bk, d, d0, c, i) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  i < n, d < d0.

PickK(i, n, k, ak1, ak2, bk, d, d0, c, k) :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  d >= d0.


(******************************************************************************)
(* GOAL: c > n - d0 — UNSAT = verified                                        *)
(*                                                                            *)
(* No bk=1 constraint needed (unlike original fixed-k encoding).             *)
(* PickK discovers equal positions dynamically.                               *)
(******************************************************************************)

c > n - d0 :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  n <= i,
  d >= d0.
(*

unsat,34
docker run -it -v  coar:latest bash -c   0.02s user 0.02s system 0% cpu 30.636 total
*)