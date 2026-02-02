% Facts: Define relationships
male(john).
male(david).
male(michael).
female(mary).
female(susan).
female(lisa).

parent(john, david).  % John is a parent of David
parent(john, susan).  % John is a parent of Susan
parent(mary, david).
parent(mary, susan).
parent(david, lisa).
parent(susan, michael).

% Rules: Define derived relationships
father(Father, Child) :-
    male(Father),
    parent(Father, Child).

mother(Mother, Child) :-
    female(Mother),
    parent(Mother, Child).

child(Child, Parent) :-
    parent(Parent, Child).

grandparent(Grandparent, Grandchild) :-
    parent(Grandparent, Parent),
    parent(Parent, Grandchild).

sibling(Person1, Person2) :-
    parent(P, Person1),
    parent(P, Person2),
    Person1 \= Person2. % Ensure they are not the same person


