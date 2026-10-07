# dev11 native callback / Pharo re-entry

Executed against the user-supplied stableStackVM12 and latest-64 Pharo 12 image.
Pharo creates a resident receiver and an `FFICallback` closure capturing that
receiver. Pharo enters the dev11 native library; native C synchronously invokes
the callback; the callback re-enters Pharo and sends `alchemyAdd:` to the same
resident receiver; 42 returns through C to the original Pharo activation.

This proves native -> Pharo synchronous re-entry in the supplied runtime and
shows that the callback can act on resident object identity. It is not yet the
full ooRexx -> Pharo -> ooRexx path: the callback target in this qualification
is Pharo. The next gate is to substitute Foreign Runtime's call-thread ooRexx
callback for this Pharo callback without weakening its thread/lifetime policy.
