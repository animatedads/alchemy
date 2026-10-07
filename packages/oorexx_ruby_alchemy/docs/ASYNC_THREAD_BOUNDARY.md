# Asynchronous Ruby-thread boundary — dev15

Ruby-created worker threads may invoke retained ooRexx projections through the cooperative owner-activity scheduler. A worker pins the projection, queues the call, releases the MRI GVL while waiting, and resumes after `RubyAlchemyPumpCallbacks` services the request on the owning Rexx activity. Registry and queue locks are not held across Rexx dispatch.

## Condition fidelity

A protected `RubyAlchemyCallbackGuard` returns either a value envelope or the full Rexx condition Directory. dev15 recognizes that envelope in the asynchronous pump and transports condition, description, RC and code back to the waiting worker as `OoRexxAlchemyCondition`. This matches the synchronous callback boundary instead of degrading asynchronous failures to generic runtime strings.

## Qualified scope

One Ruby worker callback, release racing an already-pinned queued callback, deterministic revocation of future calls, deferred final destruction, and structured asynchronous Rexx-condition propagation are qualified. Multi-worker ordering/fairness and bridge shutdown with outstanding workers remain future explicit contracts; they are not inferred from MRI scheduler behavior.
