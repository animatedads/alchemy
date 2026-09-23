# ooRexx Ruby Alchemy v0.1-dev12

First executable/scaffolding package for a live, bidirectional Ruby ↔ ooRexx Alchemy bridge.

## Architectural contract

* Ruby and ooRexx objects remain owned by their originating runtimes.
* `.AlchemyRubyObject` subclasses the authoritative external `.AlchemyForeignObject`; no new Alchemy root is invented.
* Ruby `method_missing` / `respond_to_missing?` and ooRexx `UNKNOWN` are the natural unresolved-message seams.
* Invocation is authoritative: a negative `respond_to?` result must never be used to reject a call that Ruby may handle through `method_missing`.
* A foreign method that exists and raises is an exception, not a missing method, and must not fall through to the other runtime's missing-method handler.
* Projections are identity-preserving handles, not serialized copies.
* Method interposition is live. Removing a Rexx-side override reveals the Ruby method currently underneath it, not a cached historical Method.
* Ruby blocks/Proc objects and retained ooRexx callbacks are live callable objects.
* The intended production runtime is resident/in-process. Subprocess/JSON transport is explicitly non-conforming.

dev1 makes the Ruby-side dynamic dispatch seam executable, defines the ooRexx projection/UNKNOWN contract, and provides a resident Ruby C-API probe that compiles and runs against an installed Ruby development runtime. Full ooRexx native handle exchange is the next implementation boundary; dev1 does not falsely claim it.

## Layout

* `src/ruby/alchemy_rexx.rb` — Ruby projection with `method_missing`, `respond_to_missing?`, identity registry, blocks and keyword preservation.
* `src/rexx/AlchemyRubyObject.cls` — `.AlchemyForeignObject` subclass and composed `UNKNOWN` bridge.
* `native/ruby_resident_probe.c` — in-process Ruby C API qualification probe.
* `tests/` — Ruby behavioral and ooRexx contract tests.
* `scripts/qualify.sh` — portable qualification; discovers Ruby via `RbConfig`, not fixed Linux paths.

## Dependencies

External/unmodified: Alchemy Foreign Object v0.2, authoritative Alchemy Objects, Crypto, Foreign Runtime, Runtime Reference/OpenSSL chain, and RxMath from the selected ooRexx distribution.

No dependency is vendored in this package.


## dev2

dev2 crosses the first real native boundary. `native/ruby_alchemy.cpp` is an
ooRexx native package linked to the resident Ruby C API. It retains Ruby
`VALUE`s behind protected opaque handles, invokes actual Ruby dispatch under
`rb_protect`, and releases GC roots explicitly.

The native acceptance test proves from a real ooRexx interpreter that:

* an ooRexx call reaches a Ruby object whose behavior exists only in
  `method_missing`;
* no `respond_to?` preflight suppresses that dispatch;
* a retained handle preserves Ruby object identity;
* reopening/mutating that exact Ruby singleton is visible through the old
  handle (no stale Method snapshot);
* retained Ruby GC roots can be explicitly released.

Argument marshalling, Ruby blocks, reverse retained Rexx objects and complete
foreign-condition objects remain later boundaries; dev2 does not claim them.

## dev3

Adds real scalar marshalling: Ruby nil/boolean/Integer/Float/String return as native ooRexx values; Rexx scalar arguments cross into Ruby for one-argument sends. Non-scalars remain retained live Ruby identities. Qualification retains method_missing and live-mutation proofs. Arbitrary vectors, keywords, blocks/Proc and reverse retained Rexx projections remain subsequent boundaries.

## dev4

Adds arbitrary positional argument vectors and an object-aware Ruby projection token. Tokens are typed (`@RUBY:<handle>`) rather than bare integers, so ordinary Rexx numerics cannot accidentally alias Ruby identities. Passing a token back into Ruby unwraps the exact resident VALUE. Non-scalar results from the generic dispatcher remain live tokens. Qualification proves exact object round-trip identity, arbitrary positional dispatch, method_missing and live mutation. Keyword and block/Proc semantics are the next boundary.

## dev5

Adds Ruby 3 keyword-aware native dispatch using `rb_funcallv_kw(..., RB_PASS_KEYWORDS)` and retained Ruby `Proc` invocation. A Proc returned to ooRexx remains a live resident Ruby identity and can be invoked later, preserving closure state. This establishes the Ruby-callable half of the callback model without pretending that a Rexx object is yet projected as a Ruby callable. The next boundary is that reverse retained Rexx projection and true Ruby -> Rexx -> Ruby re-entry.

## dev6

dev6 crosses the reverse object boundary. A live ooRexx object can be retained as an interpreter global reference and projected into resident Ruby as `OoRexxAlchemyObject`. Ruby's `method_missing` forwards the exact selector and arguments back into the retained Rexx object on an attached interpreter thread. Qualification proves Ruby -> retained Rexx callback re-entry twice against the same Rexx object and state. This is the first executable both-way object bridge. Reverse projection release bookkeeping, full foreign exception preservation, arbitrary callback value/object projection, nested Ruby -> Rexx -> Ruby identity reversal, and GVL/re-entry hardening remain subsequent boundaries.

## dev7

dev7 proves nested Ruby -> ooRexx -> Ruby re-entry with identity reversal. When Ruby passes a non-scalar resident object into a retained Rexx callback, the bridge recognizes/retains that exact Ruby VALUE and supplies a typed Ruby identity token. Rexx can synchronously dispatch through that token back into the same Ruby object while the outer Ruby call remains active. The test repeats the path against the same objects and verifies Rexx callback state. dev7 also adds explicit reverse-projection release: the Rexx global reference and its Ruby proxy handle are released together. Structured cross-runtime exception objects, complete callback value projection, reverse projection interning, and GVL/thread hardening remain next.

## dev8

dev8 adds structured Ruby failure retention. A protected Ruby call now has an explicit result envelope: `value` or `raised`. Raised Ruby exceptions are retained as live Ruby exception VALUEs with stable failure IDs, class, message and queryable backtrace; they are explicitly released after consumption. A genuine unresolved send is observed as its actual `NoMethodError`, while a dynamic `method_missing` success remains an ordinary value. This removes the temptation to infer missing behavior from `respond_to?` and establishes the data needed for an Alchemy foreign-condition object. Full ooRexx condition-to-Ruby exception projection and exact NoMethodError provenance checks are next.

## dev9

Code-review and authoritative-Alchemy integration pass. The Rexx projection is now validated against Alchemy Foreign Object v0.2 and Alchemy Objects v0.8.1. Method-level comments document lifetime, identity, UNKNOWN composition and dispatch responsibilities. The native build enables `-Wall -Wextra`; review warnings were removed. Qualification consumes external dependency roots rather than fixed paths, preserving Termux/conventional Linux portability.

The qualifier exercised the supplied Crypto v0.8.3, Foreign Runtime v0.22.6 and Runtime Reference v0.4 chain. RxMath and json.cls come from the selected ooRexx distribution. Dependencies remain external and unmodified.


## dev11

Tightens Ruby missing-message provenance. A Ruby `NoMethodError` is now classified
as an Alchemy `missing` result only when its `receiver` is the exact projected
Ruby object and its `name` is the exact selector being dispatched. A resolved
Ruby method that raises `NoMethodError` internally remains a structured foreign
failure and can never fall through to the preserved ooRexx `UNKNOWN`.

The reverse ooRexx-condition-to-Ruby-exception path was also reproduced during
this development round. ooRexx native `SendMessage` does not expose a raised Rexx
condition through `CheckCondition()` after the callback send on the tested r13196
API path. dev11 therefore does not pretend to implement that transport by polling
the native condition flag; it remains an explicit next boundary requiring a Rexx
trampoline/condition envelope or another supported interpreter seam.

## dev11 protected Rexx callback conditions

dev11 adds a Rexx-side callback guard that traps conditions before the native SendMessage boundary and returns the original condition Directory in a private bridge envelope. The resident native adapter projects that envelope as `OoRexxAlchemyCondition < StandardError` with `condition`, `description`, `rc`, and `code` attributes while retaining Ruby exception semantics. This avoids pretending that post-SendMessage `CheckCondition()` is authoritative on r13196.

## dev12 lifecycle checkpoint

dev12 interns repeated Rexx-to-Ruby projections, adds generation-bearing proxy identity, explicit retain counts, invocation pins and revocation. A stale generation cannot resolve to another projection. Registry bookkeeping completes before foreign invocation; no registry lock is held across the Rexx call. Explicit revocation denies subsequent calls while release remains deterministic and repeat-safe.

This cut does not claim a fully qualified concurrent race implementation: Ruby-created-thread/GVL and true call-vs-release overlap remain the next qualification boundary. Shared live SETMETHOD/coordinator repair remains owned by the common Alchemy Objects/interposition layer, not this bridge.
