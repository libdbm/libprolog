% family.pl - Example Prolog program demonstrating family relationships
% This file can be loaded with: consult('example/family_examples.pl').

% Facts: parent(Parent, Child)
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).
parent(pat, jim).

% Rule: grandparent relationship
grandparent(X, Z) :-
    parent(X, Y),
    parent(Y, Z).

% Rule: ancestor relationship (recursive)
ancestor(X, Y) :- parent(X, Y).
ancestor(X, Z) :-
    parent(X, Y),
    ancestor(Y, Z).

% Rule: sibling relationship
sibling(X, Y) :-
    parent(P, X),
    parent(P, Y),
    X \= Y.

% Example queries to try:
% ?- parent(tom, X).          % Who are tom's children?
% ?- grandparent(tom, X).     % Who are tom's grandchildren?
% ?- ancestor(tom, X).        % Who are tom's descendants?
% ?- sibling(bob, X).         % Who are bob's siblings?
