:- module(family_live_relations,
          [live_parent/3,live_female/2,live_male/2,live_mother/3,
           live_sibling/3,live_aunt/3,live_cousin/3]).

/* Book is a retained ooRexx FamilyBook.  parentsOf returns a productive Rexx
   solution source, so each Prolog redo advances live ooRexx state. */
live_parent(Book, Parent, Child) :-
    rexx_send(Book, parentsOf, [Child], Parent).

live_female(Book, Person) :-
    rexx_send(Book, isFemale, [Person], true).

live_male(Book, Person) :-
    rexx_send(Book, isMale, [Person], true).

live_mother(Book, Mother, Child) :-
    live_female(Book, Mother),
    live_parent(Book, Mother, Child).

live_sibling(Book, A, B) :-
    live_parent(Book, P, A),
    live_parent(Book, P, B),
    A \= B.

live_aunt(Book, Aunt, NieceOrNephew) :-
    live_female(Book, Aunt),
    live_sibling(Book, Aunt, Parent),
    live_parent(Book, Parent, NieceOrNephew).

live_cousin(Book, A, B) :-
    live_parent(Book, PA, A),
    live_parent(Book, PB, B),
    live_sibling(Book, PA, PB),
    A \= B.

/* Deliberately no wife -> mother rule.  live_mother/3 requires female/2 and
   actual parent/2 evidence from the current FamilyBook state. */
