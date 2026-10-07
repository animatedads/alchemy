# dev12 Foreign Runtime callback qualification

This cut qualifies the ooRexx half of the re-entry path against the exact
Foreign Runtime v0.22.6 dependency.

Executed with ooRexx 5.3.0 r13196 and the supplied Foreign Runtime build:

1. ooRexx loads the Foreign Runtime definition.
2. `.ForeignCallback` is created for `binary_i32`.
3. Foreign Runtime creates its libffi closure for the calling thread.
4. native `callback_apply_i32` calls that closure synchronously.
5. the closure uses the live `RexxCallContext` to `SendMessage` to the retained
   ooRexx target.
6. `CallbackTarget~sum(20,22)` returns 42 through native code to ooRexx.

Observed policy is exactly `call-thread`, lifetime `call`.

This is the real Foreign Runtime callback mechanism that the Pharo bridge must
compose with. dev11 independently qualified native -> resident Pharo callback
re-entry. dev12 independently qualifies native -> resident ooRexx callback
re-entry.

NOT YET CLAIMED: one single invocation chaining ooRexx -> Pharo -> ooRexx.
The next cut must join these two already-executed halves without changing the
Foreign Runtime callback thread/lifetime safety contract.
