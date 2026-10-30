# Ruby Alchemy sphere — resident Ruby / ooRexx bridge

## Scope
Ruby owns Ruby dispatch, method_missing, keywords, blocks and runtime exceptions. ooRexx owns UNKNOWN, methods and conditions. Alchemy Objects / Foreign Object owns the common object, authority and interposition semantics. This sphere owns only the resident MRI Ruby adapter and runtime boundary.

## Baseline
The latest local source checkpoint is v0.1-dev19 (derived from dev18). The native callback queue uses shared ownership of AsyncRexxCall request storage. Implemented state path: QUEUED -> DISPATCHING -> COMPLETED. The CANCELLED enum value is reserved only; no cancellation behavior is implemented or qualified.

## Correctness blockers
- A Ruby worker waiting through rb_thread_call_without_gvl with RUBY_UBF_IO may be interrupted before completion. Shared request storage alone does not prove safe Ruby VALUE rooting, worker unwind or exactly-once pin release.
- Cancellation must atomically claim queued work, release the invocation pin on the owner activity, and publish a terminal result/wakeup without holding queue or registry locks during foreign calls.
- Shutdown must reject new admission, distinguish queued from dispatching work and handle nested callbacks.
- Bounded admission and multi-worker fairness need independent qualification.
- Re-run native qualification against ooRexx 5.3.0 r13196 and exact dependency closure; the dev19 checkpoint is NOT QUALIFIED.

## Dependencies
Alchemy Foreign Object v0.2; Alchemy Objects v0.8.1; Crypto v0.8.3; Foreign Runtime v0.22.6; Runtime Reference v0.4; MRI Ruby; ooRexx 5.3.0 r13196. Discover include/library paths via RbConfig and configurable ooRexx roots; Android/Termux first class. Do not vendor RxMath.

## Review provenance
The 2026-09-27 portfolio checkpoint inventoried Ruby but left targeted manual review pending. No clean-review or production acceptance is inferred.

## Source provenance
Source delivery: oorexx_ruby_alchemy_v0.1-dev19-source.zip, SHA-256 9049fc611f8fa1be34aa9c7ff8ee880258493281e6783f302a11ac1cfebeaad5.

## 2026-10-29 dev21 interruption correction
The native worker wait changed from `RUBY_UBF_IO` to a NULL UBF in `rb_thread_call_without_gvl`, avoiding premature return/unwind of a waiter while the owner still has queued work and Ruby VALUE arguments. This deliberately sacrifices interruptibility: the worker can block until the owning ooRexx activity pumps. Cancellation, shutdown, GC rooting and exactly-once pin release remain UNQUALIFIED. Local Ruby projection PASS, Ruby syntax PASS; native r13196 NOT RUN (runtime unavailable). The latest Rasen Falcon testing reply REQ-00000869 was against stale Git dev12 and stopped on missing ruby.h; it is NOT evidence for dev20/dev21.
