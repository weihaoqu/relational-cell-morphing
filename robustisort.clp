
(*
Insertion-Sort(A : arr)
   i = 1  // outer starts at 1 (0 sorted)
while i < n:
    key = A[i]
    j = i - 1
    while j >= 0 and A[j] > key:  // inner shift
        A[j+1] = A[j]
        j -= 1
    A[j+1] = key
    i += 1
*)

(*

i1,i2 : outer loop indices in runs 1 and 2.

k : distinguished index.

ak1,ak2 : values of A1[k], A2[k].

bk : Boolean sign bit as above.

b = false: at outer head, run 1 either starts a new inner loop or finishes the outer loop.
b = true : inside inner loop, run 1 either does a body step (write+j--) or exits the inner loop.

eps : non‑negative real bound.

N : array length (can be added later; not strictly needed in init).
*)



Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps) :-
  i1 = 0, i2 = 0,
  j1 = -1, j2 = -1,  (* Start with j invalid (not in inner loop) *)
  n1 > 0, n1 = n2,
  0 <= k, k < n1,
  !b1, !b2,
  0 <= eps,
  (bk and 0 <= ak2 - ak1 and ak2 - ak1 <= eps) or
  (!bk and 0 <= ak1 - ak2 and ak1 - ak2 <= eps).


Inv(i1', i2, j1', j2, key1', key2, n1, n2, k, ak1', ak2, bk:bool, b1':bool, b2:bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchTF(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (
    (* Outer loop: read key *)
    !b1 and i1 < n1 and i1' = i1 and j1' = i1 - 1 and b1' and
    (i1 = k and key1' = ak1 or i1 <> k ) and  (* Miss: key1' is fresh/unknown *)
    ak1' = ak1  (* Distinguished cell never changes *)
  ) or (
    (* Inner loop body: shift *)
    b1 and j1 >= 0 and i1' = i1 and j1' = j1 - 1 and b1' and
    (* Read A[j1] *)
    (j1 = k and 
      (* Hit case: we know A[j1] = ak1 *)
      ak1 > key1 and
      (j1 + 1 = k and ak1' = ak1 or j1 + 1 <> k and ak1' = ak1)  (* Write: ak1' = ak1 always *)
     or j1 <> k and
      (* Miss case: A[j1] is unknown, comparison is non-deterministic *)
      (* Comparison can go either way *)
      ak1' = ak1  (* Distinguished cell doesn't change *)
    ) and
    key1' = key1
  ) or (
    (* Inner loop exit: write key *)
    b1 and i1' = i1 and !b1' and j1' = j1 and
    (j1 < 0 or 
     j1 = k and ak1 <= key1 or 
     j1 <> k ) and  (* Miss: comparison unknown *)
    (j1 + 1 = k and ak1' = key1 or j1 + 1 <> k and ak1' = ak1) and
    key1' = key1
  ) or (
    (* Outer loop increment *)
    !b1 and i1 < n1 and i1' = i1 + 1 and !b1' and j1' = -1 and
    ak1' = ak1 and key1' = key1
  ) or (
    (* Finished *)
    !b1 and i1 >= n1 and i1' = i1 and !b1' and j1' = j1 and
    ak1' = ak1 and key1' = key1
  ),
  (* Maintain epsilon bound *)
  (bk and 0 <= ak2 - ak1' and ak2 - ak1' <= eps) or
  (!bk and 0 <= ak1' - ak2 and ak1' - ak2 <= eps).

(* FT transition - only run 2 steps *)
Inv(i1, i2', j1, j2', key1, key2', n1, n2, k, ak1, ak2', bk:bool, b1:bool, b2':bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchFT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (
    (* Outer loop: read key *)
    !b2 and i2 < n2 and i2' = i2 and j2' = i2 - 1 and b2' and
    (i2 = k and key2' = ak2 or i2 <> k ) and
    ak2' = ak2
  ) or (
    (* Inner loop body: shift *)
    b2 and j2 >= 0 and i2' = i2 and j2' = j2 - 1 and b2' and
    (j2 = k and 
      ak2 > key2 and
      (j2 + 1 = k and ak2' = ak2 or j2 + 1 <> k and ak2' = ak2)
     or j2 <> k and
      ak2' = ak2
    ) and
    key2' = key2
  ) or (
    (* Inner loop exit: write key *)
    b2 and i2' = i2 and !b2' and j2' = j2 and
    (j2 < 0 or 
     j2 = k and ak2 <= key2 or 
     j2 <> k) and
    (j2 + 1 = k and ak2' = key2 or j2 + 1 <> k and ak2' = ak2) and
    key2' = key2
  ) or (
    (* Outer loop increment *)
    !b2 and i2 < n2 and i2' = i2 + 1 and !b2' and j2' = -1 and
    ak2' = ak2 and key2' = key2
  ) or (
    (* Finished *)
    !b2 and i2 >= n2 and i2' = i2 and !b2' and j2' = j2 and
    ak2' = ak2 and key2' = key2
  ),
  (* Maintain epsilon bound *)
  (bk and 0 <= ak2' - ak1 and ak2' - ak1 <= eps) or
  (!bk and 0 <= ak1 - ak2' and ak1 - ak2' <= eps).

(* TT transition - both runs step *)
Inv(i1', i2', j1', j2', key1', key2', n1, n2, k, ak1', ak2', bk:bool, b1':bool, b2':bool, eps) :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  SchTT(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  (* Run 1 transition *)
  (
    !b1 and i1 < n1 and i1' = i1 and j1' = i1 - 1 and b1' and
    (i1 = k and key1' = ak1 or i1 <> k ) and
    ak1' = ak1
  ) or (
    b1 and j1 >= 0 and i1' = i1 and j1' = j1 - 1 and b1' and
    (j1 = k and ak1 > key1 and (j1 + 1 = k and ak1' = ak1 or j1 + 1 <> k and ak1' = ak1)
     or j1 <> k   and ak1' = ak1) and
    key1' = key1
  ) or (
    b1 and i1' = i1 and !b1' and j1' = j1 and
    (j1 < 0 or j1 = k and ak1 <= key1 or j1 <> k ) and
    (j1 + 1 = k and ak1' = key1 or j1 + 1 <> k and ak1' = ak1) and
    key1' = key1
  ) or (
    !b1 and i1 < n1 and i1' = i1 + 1 and !b1' and j1' = -1 and
    ak1' = ak1 and key1' = key1
  ) or (
    !b1 and i1 >= n1 and i1' = i1 and !b1' and j1' = j1 and
    ak1' = ak1 and key1' = key1
  ),
  (* Run 2 transition *)
  (
    !b2 and i2 < n2 and i2' = i2 and j2' = i2 - 1 and b2' and
    (i2 = k and key2' = ak2 or i2 <> k ) and
    ak2' = ak2
  ) or (
    b2 and j2 >= 0 and i2' = i2 and j2' = j2 - 1 and b2' and
    (j2 = k and ak2 > key2 and (j2 + 1 = k and ak2' = ak2 or j2 + 1 <> k and ak2' = ak2)
     or j2 <> k  and ak2' = ak2) and
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
  (* Maintain epsilon bound *)
  (bk and 0 <= ak2' - ak1' and ak2' - ak1' <= eps) or
  (!bk and 0 <= ak1' - ak2' and ak1' - ak2' <= eps).

(*
Inv(i1', i2, j1',j2, key1', key2,n1, n2, k, ak1', ak2, bk:bool, b1':bool,b2:bool, eps) :-
  Inv(i1,  i2, j1,j2, key1, key2,n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  SchTF(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  !b1 and i1 < n1 and i1' = i1  and j1' = i1 -1 and b1' and ak1' = ak1 and (i1 = k and key1' = ak1 or i1 <> k and key1' = key2) or
  b1 and  j1 >= 0 and i1' = i1 and j1' = j1 -1 and b1' 
  and (j1 = k and aj1 = ak1 or j1 <> k and aj1 = key2) and aj1 > key1 
  and  (j1 +1 = k and  ak1' = aj1 or j1 + 1 <> k and ak1' = ak1 ) and key1' = key1  or 
  b1 and  i1' = i1 and !b1' and ak1' = ak1 and j1' = j1 and key1' = key1 and (j1 = k and aj1 = ak1 or j1 <> k and aj1 = key2) and (j1 < 0 or aj1 <= key1) or 
  !b1 and i1 < n1 and i1' = i1 +1 and ak1' = ak1 and !b1' and j1' = 0 and key1' = key1 ,
  (bk and ak1'<=ak2 and ak2-ak1'<= eps) or (!bk and ak2<=ak1' and ak1'-ak2 <= eps).

Inv(i1, i2', j1,j2' ,key1, key2', n1, n2, k, ak1, ak2', bk:bool, b1:bool,b2':bool, eps) :-
  Inv(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  SchFT(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  !b2 and i2 < n2 and i2' = i2  and j2' = i2 -1 and b2' and ak2' = ak2 and (i2 = k and key2' = ak2 or i2 <> k and key2' = key1) or
  b2 and  j2 >= 0 and i2' = i2 and j2' = j2 -1 and b2' and (j2 = k and aj2 = ak2 or j2 <> k and aj2 = key1) and aj2 > key2 and  (j2 +1 = k and  ak2' = aj2 or j2 + 1 <> k and ak2' = ak2 ) and key2' = key2  or 
  b2 and  i2' = i2 and !b2' and ak2' = ak2 and j2' = j2 and key2' = key2 and (j2 = k and aj2 = ak2 or j2 <> k and aj2 = key1) and (j2 < 0 or aj2 <= key2) or 
  !b2 and i2 < n2 and i2' = i2 +1 and ak2' = ak2 and !b2' and j2' = 0 and key2' = key2 ,
  (bk and ak1<=ak2' and ak2'-ak1<= eps) or (!bk and ak2'<=ak1 and ak1-ak2' <= eps).

Inv(i1', i2', j1',j2',key1', key2', n1, n2, k, ak1', ak2', bk:bool, b1':bool,b2':bool, eps) :-
  Inv(i1,  i2, j1,j2,key1, key2,  n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  SchTT(i1, i2, j1,j2 ,key1, key2,  n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  !b1 and i1 < n1 and i1' = i1  and j1' = i1 -1 and b1' and ak1' = ak1 and (i1 = k and key1' = ak1 or i1 <> k and key1' = key2) or
  b1 and  j1 >= 0 and i1' = i1 and j1' = j1 -1 and b1' and (j1 = k and aj1 = ak1 or j1 <> k and aj1 = key2) and aj1 > key1 and  (j1 +1 = k and  ak1' = aj1 or j1 + 1 <> k and ak1' = ak1 ) and key1' = key1  or 
  b1 and  i1' = i1 and !b1' and ak1' = ak1 and j1' = j1 and key1' = key1 and (j1 = k and aj1 = ak1 or j1 <> k and aj1 = key2) and (j1 < 0 or aj1 <= key1) or 
  !b1 and i1 < n1 and i1' = i1 +1 and ak1' = ak1 and !b1' and j1' = 0 and key1' = key1 ,
   !b2 and i2 < n2 and i2' = i2  and j2' = i2 -1 and b2' and ak2' = ak2 and (i2 = k and key2' = ak2 or i2<> k and key2' = key1) or
  b2 and  j2 >= 0 and i2' = i2 and j2' = j2 -1 and b2' and (j2 = k and aj2 = ak2 or j2 <> k and aj2 = key1) and aj2 > key2 and  (j2 +1 = k and  ak2' = aj2 or j2 + 1 <> k and ak2' = ak2 ) and key2' = key2  or 
  b2 and  i2' = i2 and !b2' and ak2' = ak2 and j2' = j2 and key2' = key2 and (j2 = k and aj2 = ak2 or j2 <> k and aj2 = key1) and (j2 < 0 or aj2 <= key2) or 
  !b2 and i2 < n2 and i2' = i2 +1 and ak2' = ak2 and !b2' and j2' = 0 and key2' = key2 ,
  (bk and ak1'<=ak2' and ak2'-ak1'<= eps) or (!bk and ak2'<=ak1' and ak1'-ak2' <= eps).
*)

(*
i1 < n1 or b1 or j1 >= 0 :-
  Inv(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  SchTF(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  i2 < n2 or b2 or j2 >=0.
i2 < n2 or b2 or j2 >=0  :-
  Inv(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  SchFT(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  i1 < n1 or b1 or j1 >= 0 .

SchTF(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps), 
SchFT(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps ), 
SchTT(i1, i2, j1,j2 , key1, key2,n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps) :-
  Inv(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
   (i1 < n1 or b1 or j1 >= 0) or
   (i2 < n2 or b2 or j2 >= 0).
   *)

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




ak1 - ak2 <= eps and ak2 - ak1 <= eps    :-
  Inv(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  n1<=i1, n2<=i2, !b1, !b2.

(*

(* Test 1: Epsilon bound is maintained at termination *)
sat,51
docker run -it -v  coar:latest bash -c   0.02s user 0.02s system 0% cpu 14.477 total
ak1 - ak2 <= eps and ak2 - ak1 <= eps :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  n1 <= i1, n2 <= i2, !b1, !b2.
(* Test 2: Epsilon bound is broken at termination *)
unsat,150
docker run -it -v  coar:latest bash -c   0.07s user 0.07s system 0% cpu 17:24.09 total
ak1 - ak2 > eps and ak2 - ak1 > eps    :-
  Inv(i1, i2, j1,j2 ,key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool,b2:bool, eps),
  n1<=i1, n2<=i2, !b1, !b2.

(*Test 3*)
ak1 - ak2 > eps or ak2 - ak1 > eps   
unsat,12

(* Test 5: Exact equality - should NOT hold (only bounded by eps) *)

unsat,132
docker run -it -v  coar:latest bash -c   0.04s user 0.04s system 0% cpu 13:24.69 total
ak1 = ak2 :-
  Inv(i1, i2, j1, j2, key1, key2, n1, n2, k, ak1, ak2, bk:bool, b1:bool, b2:bool, eps),
  n1 <= i1, n2 <= i2, !b1, !b2.
*)