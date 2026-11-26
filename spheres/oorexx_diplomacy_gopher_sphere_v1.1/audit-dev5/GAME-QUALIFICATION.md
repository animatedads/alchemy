# Dev5 — step-5 game controller qualification
Architecture: Tom Dyer. Implementation/qualification: ChatGPT GPT-6.2.
Existing referee independently reviewed by Claude Opus 5.5 on dev4r4;
dev4r5 and dev5 retain identical four referee class files and rules.conf.
No claim of independent review of the new controller.

Exact interpreter: ooRexx 5.3.0 r13196. Estate pinned pitfall lint: zero findings.
Logging framework v0.7, pinned LoggingCore and MethodInterposition hashes.

Core referee regression: 3311 checks / 232 positions, zero failures.
New native game checks: 63, zero failures. Total direct assertions 3374.
- HOLD seed 7: 125 phases, 350 calls, zero invalid orders.
- RANDOM seed 20261126: 125 phases, 376 calls, 163 invalid orders.
- Both finish Winter 1925 and replay byte-identically from recorded order calls.
- Directed scenario dislodges/retreats, captures Belgium only after Fall
  retreats, then builds twice in winter, with identical replay.
- Separate test starts with 17 centres and asserts solo at 18 after Fall
  retreats, no winter call.
- Malformed/timeout/exception responses fall back to no orders atomically;
  raw bytes (case, trailing spaces, separators) and status survive replay.
- Public-state snapshots are detached; a callback mutating its snapshot does
  not affect subsequent calls. No legal-order interface is supplied.
- Injected referee failure stops after one phase, logs error and publishes no
  phase result. Incomplete/failed journals reject replay. A changed RESULT
  record fails full-byte comparison.

Replay SHA-256:
HOLD   6ada6be204824b8eb4f39c377b083639ca6e57c450614d25d8799c89543bf2d7
RANDOM ba68d770498185e97363fea503c87b72a6f770751cbd3e65fe8dcde40049d29c

Reproduce: sh tests/run.sh with ALCHEMY_REPO_ROOT and native rexx. It
verifies source identity, reviewer files and pinned Logging v0.7; prints
the digest of each original and replay journal in a temporary directory.
No live model, press, prompt evolution or tournament results.
