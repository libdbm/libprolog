% Test file for REPL file loading
% This tests multi-line clauses, comments, and complex syntax

% Simple facts
parent(tom, bob).
parent(bob, ann).
parent(bob, pat).

% Rule with multiple lines
grandparent(X, Z) :-
    parent(X, Y),
    parent(Y, Z).

% Complex term with nested structures
complex(
    foo(
        bar(1, 2),
        baz([a, b, c])
    )
).

% List operations
member(X, [X|_]).
member(X, [_|T]) :- member(X, T).

% Arithmetic
factorial(0, 1).
factorial(N, F) :-
    N > 0,
    N1 is N - 1,
    factorial(N1, F1),
    F is N * F1.
