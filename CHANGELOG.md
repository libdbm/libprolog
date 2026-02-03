## 0.1.2
- Update the CHANGELOG

## 0.1.1
- Update the README.md

## 0.1.0

- Initial release of libprolog
- ISO Prolog core predicates implementation
- Definite Clause Grammar (DCG) support
- Pure Dart implementation with no external dependencies
- Terms: Atom, Variable, Compound, Integer, Float
- Unification with occur check
- SLD resolution with backtracking
- Database with first-argument indexing
- Built-in predicates:
  - Type testing (var/1, atom/1, number/1, etc.)
  - Arithmetic (is/2, comparison operators)
  - Term manipulation (functor/3, arg/3, =../2)
  - Control flow (!/0, ->/2, ;/2, \+/1)
  - All-solutions (findall/3, bagof/3, setof/3)
  - I/O operations (read/1, write/1, get_char/1, put_char/1)
  - Database operations (assert/1, retract/1, abolish/1)
  - List operations (append/3, member/2, length/2)
- Parser with operator support
- Stream-based query interface
- Clean Dart API for embedding
