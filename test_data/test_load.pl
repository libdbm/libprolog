% Test file for file loading
% Simple facts
parent(tom, bob).
parent(bob, ann).

% Multi-line rule
grandparent(X, Z) :-
    parent(X, Y),
    parent(Y, Z).

% List fact
likes(john, [pizza, pasta, icecream]).
