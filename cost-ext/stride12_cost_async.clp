(*
STRIDE-1 vs STRIDE-2 COUNTING COST -- ASYNC MODEL
Two different programs, two related arrays, full scheduler.

P1(A1, n):                    P2(A2, n):
  cost1 := 0                    cost2 := 0
  for i1 = 0 to n-1:            for i2 = 0 to n-1 step 2:
    if A1[i1] > 0: cost1++        if A2[i2] > 0: cost2++

Precondition:
  d0 positions in the intersection (even indices) have A1[i] = A2[i].

Property: cost1 - cost2 <= n - d0

ASYNC MODEL:
  i1 advances by 1 (P1), i2 advances by 2 (P2).
  Scheduler: TF (P1 only), FT (P2 only), TT (both).
  Fairness ensures both finish.

  PickK refocuses when i1 = i2 (aligned at even position).
  The scheduler can arrange alignment: e.g. after TT (i1=1,i2=2),
  one TF gives i1=2,i2=2 -> aligned at 2.

State: i1, i2, n, k, ak1, ak2, bk, d, d0, c  (10 variables)
Predicates: Inv(10), PickK(11), SchTF(10), SchFT(10), SchTT(10)
Clauses: 11 (init + 3 transitions + 3 fairness + 1 disjunction + 2 PickK + 1 goal)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c) :-
  i1 = 0, i2 = 0,
  n > 0,
  0 <= k, k < n,
  (ak1 = ak2 and bk = 1) or (ak1 <> ak2 and bk = 0),
  d = 0,
  d0 >= 0,
  c = 0.


(******************************************************************************)
(* TF TRANSITION -- P1 steps (stride 1), P2 waits                            *)
(*                                                                            *)
(* P1 processes A1[i1]. i1' = i1 + 1.                                       *)
(* cost1 may increase by 1 if A1[i1] > 0.                                   *)
(* c = cost1 - cost2, so c' = c + 1 or c' = c.                              *)
(******************************************************************************)

Inv(i1', i2, n, kp, ak1', ak2', bk', d', d0, c') :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  i1 < n,
  PickK(i1, i2, n, k, ak1, ak2, bk, d, d0, c, kp),
  SchTF(i1, i2, n, kp, ak1p, ak2p, bkp, d, d0, c),
  (
    (i1 = kp and ak1p > 0 and c' = c + 1)
    or
    (i1 = kp and ak1p <= 0 and c' = c)
    or
    (i1 <> kp and c' = c + 1)
    or
    (i1 <> kp and c' = c)
  ),
  d' = d,
  i1' = i1 + 1,
  ak1' = ak1p, ak2' = ak2p,
  (ak1' = ak2' and bk' = 1 or ak1' <> ak2' and bk' = 0).


(******************************************************************************)
(* FT TRANSITION -- P2 steps (stride 2), P1 waits                            *)
(*                                                                            *)
(* P2 processes A2[i2]. i2' = i2 + 2.                                       *)
(* cost2 may increase by 1 if A2[i2] > 0.                                   *)
(* c = cost1 - cost2, so c' = c - 1 or c' = c.                              *)
(******************************************************************************)

Inv(i1, i2', n, kp, ak1', ak2', bk', d', d0, c') :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  i2 < n,
  PickK(i1, i2, n, k, ak1, ak2, bk, d, d0, c, kp),
  SchFT(i1, i2, n, kp, ak1p, ak2p, bkp, d, d0, c),
  (
    (i2 = kp and ak2p > 0 and c' = c - 1)
    or
    (i2 = kp and ak2p <= 0 and c' = c)
    or
    (i2 <> kp and c' = c - 1)
    or
    (i2 <> kp and c' = c)
  ),
  d' = d,
  i2' = i2 + 2,
  ak1' = ak1p, ak2' = ak2p,
  (ak1' = ak2' and bk' = 1 or ak1' <> ak2' and bk' = 0).


(******************************************************************************)
(* TT TRANSITION -- Both step simultaneously                                  *)
(*                                                                            *)
(* P1 processes A1[i1], i1' = i1 + 1.                                       *)
(* P2 processes A2[i2], i2' = i2 + 2.                                       *)
(*                                                                            *)
(* HIT-HIT equal (i1=i2=kp, bkp=1): same branch, costs cancel, d+1.        *)
(* HIT-HIT unequal (i1=i2=kp, bkp=0): c' in {c-1, c, c+1}.               *)
(* MISS (at least one not at kp): c' in {c-1, c, c+1}.                     *)
(******************************************************************************)

Inv(i1', i2', n, kp, ak1', ak2', bk', d', d0, c') :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  i1 < n, i2 < n,
  PickK(i1, i2, n, k, ak1, ak2, bk, d, d0, c, kp),
  SchTT(i1, i2, n, kp, ak1p, ak2p, bkp, d, d0, c),
  (
    (i1 = kp and i2 = kp and bkp = 1
     and c' = c
     and d' = d + 1)
    or
    (i1 = kp and i2 = kp and bkp = 0
     and (c' = c - 1 or c' = c or c' = c + 1)
     and d' = d)
    or
    ((i1 <> kp or i2 <> kp)
     and (c' = c - 1 or c' = c or c' = c + 1)
     and d' = d)
  ),
  i1' = i1 + 1,
  i2' = i2 + 2,
  ak1' = ak1p,
  ak2' = ak2p,
  (ak1' = ak2' and bk' = 1 or ak1' <> ak2' and bk' = 0).


(******************************************************************************)
(* SCHEDULER FAIRNESS                                                         *)
(******************************************************************************)

i1 < n :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  SchTF(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  i2 < n.

i2 < n :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  SchFT(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  i1 < n.

i1 < n and i2 < n :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  SchTT(i1, i2, n, k, ak1, ak2, bk, d, d0, c).


(******************************************************************************)
(* SCHEDULER DISJUNCTION                                                      *)
(******************************************************************************)

SchTF(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
SchFT(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
SchTT(i1, i2, n, k, ak1, ak2, bk, d, d0, c) :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  i1 < n or i2 < n.


(******************************************************************************)
(* PICKK                                                                      *)
(*                                                                            *)
(* Searching: refocus when i1 = i2 (aligned at even position).               *)
(* The scheduler can arrange alignment via TT then TF.                       *)
(* Settled: keep current cell once d >= d0.                                  *)
(******************************************************************************)

PickK(i1, i2, n, k, ak1, ak2, bk, d, d0, c, i1) :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c)
  and i1 = i2 and i1 < n
  and d < d0.

PickK(i1, i2, n, k, ak1, ak2, bk, d, d0, c, k) :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  d >= d0.


(******************************************************************************)
(* GOAL: cost1 - cost2 > n - d0 at termination -- UNSAT = verified           *)
(******************************************************************************)

c > n - d0 :-
  Inv(i1, i2, n, k, ak1, ak2, bk, d, d0, c),
  n <= i1, n <= i2,
  d >= d0.
