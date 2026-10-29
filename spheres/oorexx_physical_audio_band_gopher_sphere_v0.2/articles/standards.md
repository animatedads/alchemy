# ooRexx standards learned from the audio/physics work

The 2026-09-27 review used Claude's heuristic standards enforcer and Grok's `family.rex` positive-control example.

The standard is semantic, not cosmetic:

- `value + 0` is an error. It sends `+` to `value`; it does not “coerce” a value. Validate with the correct numeric contract first.
- `&`, `|`, and `&&` are only appropriate when every operand is valid and intended to be evaluated. If the legality of a later expression depends on an earlier test, use explicit nested control flow. This review found and fixed the concrete `q==.nil | q~items=0` case in the MIDI reader.
- Mutation semantics matter: `Array~remove` leaves a hole; `delete` shifts; `Queue~pull` is the correct FIFO primitive.
- Concurrency is native ooRexx object behaviour. Asynchronous calls must respect method visibility and object ownership.
- Positive idiom matters as much as lint: mainline before directives, `expose` first, `use arg`, access inherited state through messages, and let objects own their behaviour.
