# ooRexx Ruby Alchemy v0.1-dev17

Resident, bidirectional MRI Ruby ↔ ooRexx bridge using the Alchemy Foreign Object / Alchemy Objects architecture.

## dev16

dev15 carries the structured ooRexx condition contract through the cooperative Ruby-worker scheduler introduced in dev14. An asynchronous Ruby Thread callback that raises in ooRexx now receives the same `OoRexxAlchemyCondition` shape as the synchronous path, including condition, description, RC and code metadata; the scheduler no longer flattens that failure to a generic string.

The existing generation/retain/revocation/invocation-pin contract is preserved. Callback queue and projection locks remain outside actual ooRexx dispatch. The dev14 release-vs-pinned-call regression remains qualified.

A multi-worker fairness experiment was intentionally not promoted into the qualified contract: arbitrary worker admission requires an explicit owner-pump scheduling/fairness policy rather than an accidental MRI scheduling assumption. dev15 therefore improves exception fidelity without overclaiming multi-worker semantics.

## 2026-09-27 portfolio-review checkpoint

dev16 consumes today's portfolio review as a review standard, not as evidence of
a Ruby defect: the checkpoint explicitly leaves `oorexx_ruby_alchemy` manual
review pending.  A new boundary regression covers empty queue behavior,
malformed handles, repeated release, passive state and revocation.  Scheduler
request ownership and the unqualified cancellation/shutdown boundary are now
documented in source.  See `docs/PORTFOLIO_REVIEW_2026-09-27.md`.

## dev17 — owned asynchronous request lifetime

dev17 replaces the callback queue's borrowed pointer to a worker-stack request with `std::shared_ptr` ownership shared by waiter and owner pump.  Dequeue transfers the queue owner into the pump, so request storage remains valid independently of the waiter's stack lifetime.  Invocation pins still complete exactly once in the pump and no queue/projection lock is held across ooRexx dispatch.

This is deliberately a lifetime repair, not a cancellation policy.  Cancellation/shutdown and arbitrary multi-worker fairness remain unqualified until an explicit queued/cancelled/dispatching/completed state contract is implemented and raced.
