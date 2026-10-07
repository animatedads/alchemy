:- module(family_qualification,
          [mother/2,sibling/2,brother/2,sister/2,aunt/2,cousin/2,nephew/2]).

mother(M,C) :- female(M), parent(M,C).
sibling(A,B) :- parent(P,A), parent(P,B), A \= B.
brother(B,P) :- male(B), sibling(B,P).
sister(S,P) :- female(S), sibling(S,P).
aunt(A,N) :- female(A), sibling(A,P), parent(P,N).
cousin(A,B) :- parent(PA,A), parent(PB,B), sibling(PA,PB), A \= B.
nephew(N,P) :- male(N), parent(Parent,N), sibling(Parent,P).

/* Deliberately absent: wife(W,F), parent(F,C) does NOT entail mother(W,C).
   Motherhood requires an explicit/provable parent(W,C) plus female(W). */
