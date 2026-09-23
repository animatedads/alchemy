# dev8 — Tcl completion/error evidence

dev8 stops treating a Tcl failure as only a prefixed string. `AlchemyTclEvalDetailed()` returns a length-framed completion record containing the Tcl completion code, interpreter result, `errorCode`, and `errorInfo`.

The error variables are captured immediately after `Tcl_Eval`, before another Tcl operation can overwrite them. Length framing permits embedded newlines and punctuation without lossy escaping.

This is an intentionally small native contract pending projection into the shared Alchemy structured exception/evidence model. It preserves Tcl authority rather than translating Tcl errors prematurely.

dev8 does not yet expose every non-error Tcl completion code as higher-level Rexx conditions; the raw completion code is retained so that later policy can do so honestly.
