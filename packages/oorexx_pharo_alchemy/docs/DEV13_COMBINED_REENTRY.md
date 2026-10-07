# dev13 — single-activation Pharo / ooRexx re-entry

This cut joins the two independently-qualified halves from dev11 and dev12.
The executed qualification is one synchronous native-thread activation:

Pharo 12 -> native `pa_dev13_run` -> embedded ooRexx 5.3.0 r13196 ->
Foreign Runtime v0.22.6 -> `pa_dev13_cross` -> resident Pharo `FFICallback` ->
`pa_dev13_invoke_rexx` -> Foreign Runtime call-thread closure -> retained ooRexx
`Dev13Target~sum(20,22)` -> 42 -> Pharo -> ooRexx -> native -> Pharo.

The Foreign Runtime callback remains `threadPolicy=call-thread` and
`lifetime=call`. No worker-thread relaxation or asynchronous callback claim is
made. The nested ooRexx callback occurs while the original Foreign Runtime
native call is active, on the same thread, which is precisely the safety model
already owned by Foreign Runtime.

The Pharo callback deliberately uses the one-argument callback shape already
qualified in dev11. The native activation retains the original two Rexx
arguments while Pharo re-enters `pa_dev13_invoke_rexx`; this avoids pretending
that Pharo's callback ABI is the public message model. Generic object/selector
marshalling remains separate work.

Executed result: 42.
