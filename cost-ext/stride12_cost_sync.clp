(*
STRIDE-1 vs STRIDE-2 COUNTING COST
Two different programs, two related arrays.

P1(A1, n):                    P2(A2, n):
  cost1 := 0                    cost2 := 0
  for i1 = 0 to n-1:            for i2 = 0 to n-1 step 2:
    if A1[i1] > 0: cost1++        if A2[i2] > 0: cost2++

Precondition:
  d0 even-indexed positions have A1[2j] = A2[2j].
  (Odd positions: A1 and A2 may differ arbitrarily.)

Property: cost1 - cost2 <= n - d0  (where n = 2*m)

EPOCH MODEL:
  One epoch j covers positions 2j and 2j+1.
  P1 processes both (2j and 2j+1), P2 processes only 2j.
  Epoch counter j = 0 to m-1 where m = n/2.

  This absorbs the stride asymmetry into the epoch semantics,
  giving a SYNC model with no scheduler.

HIT-EQUAL (bkp = 1, A1[2j] = A2[2j]):
  Even position 2j: same branch for both -> even contribution cancels.
  Odd position 2j+1: only P1 sees it -> c may increase by 0 or 1.
  Net: c' in {c, c+1}, d' = d+1.

HIT-UNEQUAL (bkp = 0) / MISS (j <> kp):
  Even position: branches may differ -> +-1 for each run.
  Odd position: P1 may or may not count -> +0 or +1.
  Net: c' in {c-1, c, c+1, c+2}, d' = d.

INVARIANT (expected): c <= 2*j - d
  d epochs contributed at most +1 each (only odd position).
  (j - d) epochs contributed at most +2 each.
  c <= d*1 + (j-d)*2 = 2j - d.

GOAL: c > 2*m - d0 at termination with d >= d0.
  Since 2*m = n, this is c > n - d0.

State: j, m, k, ak1, ak2, bk, d, d0, c  (9 variables)
*)


(******************************************************************************)
(* INITIALIZATION                                                             *)
(******************************************************************************)

Inv(j, m, k, ak1, ak2, bk, d, d0, c) :-
  j = 0, m > 0,
  0 <= k, k < m,
  (ak1 = ak2 and bk = 1) or (ak1 <> ak2 and bk = 0),
  d = 0,
  d0 >= 0,
  c = 0.


(******************************************************************************)
(* TRANSITION -- one epoch                                                    *)
(*                                                                            *)
(* Epoch j:                                                                   *)
(*   P1 processes A1[2j] and A1[2j+1]  (stride 1, two positions)            *)
(*   P2 processes A2[2j]               (stride 2, one position)              *)
(*                                                                            *)
(* The epoch counter j corresponds to the EVEN position index 2j.            *)
(* PickK tracks one even position (in terms of epochs: one epoch index).     *)
(* k here is an epoch index (0..m-1), corresponding to even position 2k.    *)
(******************************************************************************)

Inv(j', m, kp, ak1', ak2', bk', d', d0, c') :-
  Inv(j, m, k, ak1, ak2, bk, d, d0, c),
  j < m,
  PickK(j, m, k, ak1, ak2, bk, d, d0, c, kp),
  Wit(j, m, kp, ak1p, ak2p, bkp, d, d0, c),
  (
    (* HIT equal: A1[2j] = A2[2j], same branch at even position *)
    (* Odd position 2j+1: P1 may count +1, P2 doesn't see it *)
    (* Net change: c' = c (odd not positive) or c' = c+1 (odd positive) *)
    (j = kp and bkp = 1
     and (c' = c or c' = c + 1)
     and d' = d + 1)
    or
    (* HIT unequal: A1[2j] <> A2[2j], branches may differ *)
    (* Even: P1 may count +1 or 0, P2 may count +1 or 0, independently *)
    (* Odd: P1 may count +1 or 0 *)
    (* Worst case: P1 counts at both even and odd (+2), P2 counts 0 *)
    (* Best case: P1 counts 0 at both, P2 counts at even (-1) *)
    (j = kp and bkp = 0
     and (c' = c - 1 or c' = c or c' = c + 1 or c' = c + 2)
     and d' = d)
    or
    (* MISS: not tracking this epoch *)
    (* Same range as HIT-unequal since we don't know the values *)
    (j <> kp
     and (c' = c - 1 or c' = c or c' = c + 1 or c' = c + 2)
     and d' = d)
  ),
  j' = j + 1,
  ak1' = ak1p,
  ak2' = ak2p,
  (ak1' = ak2' and bk' = 1 or ak1' <> ak2' and bk' = 0).


(******************************************************************************)
(* WITNESS                                                                    *)
(******************************************************************************)

Wit(j, m, k, ak1, ak2, bk, d, d0, c) :-
  Inv(j, m, k, ak1, ak2, bk, d, d0, c),
  j < m.


(******************************************************************************)
(* PICKK                                                                      *)
(******************************************************************************)

PickK(j, m, k, ak1, ak2, bk, d, d0, c, j) :-
  Inv(j, m, k, ak1, ak2, bk, d, d0, c),
  j < m, d < d0.

PickK(j, m, k, ak1, ak2, bk, d, d0, c, k) :-
  Inv(j, m, k, ak1, ak2, bk, d, d0, c),
  d >= d0.


(******************************************************************************)
(* GOAL: c > 2*m - d0 at termination -- UNSAT = verified                     *)
(*                                                                            *)
(* Since 2*m = n, this is c > n - d0.                                        *)
(******************************************************************************)

c > 2 * m - d0 :-
  Inv(j, m, k, ak1, ak2, bk, d, d0, c),
  m <= j,
  d >= d0.
(*
unsat,10
docker run -it -v  coar:latest bash -c   0.02s user 0.02s system 1% cpu 3.366 total
*)