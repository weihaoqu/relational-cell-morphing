(*
CountInRange(A: array, n: size, lo: int, hi: int)
    cost := 0
    for i = 0 to n-1:
        if lo <= A[i] and A[i] <= hi:
            cost++
    return cost
*)

(*
PROPERTY: Relative execution cost under replace metric.
  If A1 and A2 share at least d0 equal positions,
  then cost(A1) - cost(A2) <= n - d0.

  cost = number of elements falling in range [lo, hi].

WHY THIS EXAMPLE:
  - Same structure as countpositive, different branch condition
  - Shows PickK + prophecy is not specific to "> 0" condition
  - The branch condition is abstracted away: at HIT we know if values
    are equal (same branch), at MISS we dont (worst case +-1)

ENCODING INSIGHT:
  The branch condition (lo <= x <= hi vs x > 0) is irrelevant to the
  encoding. What matters is: equal values => same branch => cost neutral.
  Unequal values => branches may differ => cost +-1.
  PickK discovers equal positions dynamically.

State: i, n, k, ak1, ak2, bk, d, d0, c  (9 Inv variables)
Expected: UNSAT in seconds
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
(* HIT equal (bkp=1): a1[i]=a2[i], same range check, cost neutral           *)
(* HIT unequal (bkp=0): values differ, range check may differ, cost +-1     *)
(* MISS: unknown, worst case cost +1                                         *)
(******************************************************************************)

Inv(i', n, kp, ak1', ak2', bk', d', d0, c') :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  i < n,
  PickK(i, n, k, ak1, ak2, bk, d, d0, c, kp),
  Wit(i, n, kp, ak1p, ak2p, bkp, d, d0, c),
  (
    (* HIT equal: same value => same range check => cost neutral *)
    (i = kp and bkp = 1
     and c' = c
     and d' = d + 1)
    or
    (* HIT unequal: range check may differ, worst case +1 *)
    (i = kp and bkp = 0
     and c' = c + 1
     and d' = d)
    or
    (* MISS: unknown, worst case +1 *)
    (i <> kp
     and c' = c + 1
     and d' = d)
  ),
  i' = i + 1,
  ak1' = ak1p,
  ak2' = ak2p,
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
(******************************************************************************)

c > n - d0 :-
  Inv(i, n, k, ak1, ak2, bk, d, d0, c),
  n <= i,
  d >= d0.
(*
unsat,13
docker run -it -v  coar:latest bash -c   0.01s user 0.01s system 0% cpu 4.982 total
*)