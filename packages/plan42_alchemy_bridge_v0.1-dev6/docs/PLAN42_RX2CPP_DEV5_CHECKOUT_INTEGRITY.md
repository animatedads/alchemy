# Plan42 / RX2CPP dev5: pinned working-tree integrity

**Scope:** Alchemy Plan42 bridge; does not modify RX2CPP compiler, coding intentions, Semantic Source Store, or Runtime Registry.

## Bug closed

Earlier `native-plan` accepted an exact Git HEAD and a plausible `VERSION`/entry script as `checkout_pin_verified`, without proving the scripts and other required compiler interface files were unchanged on disk. An operator could have an uncommitted modified `RxRexxRuleSelection.cls`, keep the pinned HEAD, and receive `READY_FOR_DIFFERENTIAL_QUALIFICATION` when the Plan42 receipt was compatible.

Dev5 binds the pin and exact interface list to `plan42/rx2cpp.upstream.pin.json` and requires seven *working-tree* Git object hashes to match `git ls-tree HEAD` and `git hash-object` for each declared interface. Missing, untracked, symlink or modified paths now produce `REVIEW_REQUIRED`, and build argv is withheld. Source has no execution or publication route. It does not verify every transitive compiler file; this is an **interface integrity** guard, not full source qualification.

## Upstream movement reviewed

On 27 October 2026, connector-fetched `animatedads/oorexx` main remains `e3d8d0024943565eb3d247b2c02a8a955f6a7f01`, VERSION 0.30.18. Git tree object IDs of seven pinned interfaces were compared against `9047f0e13c8cd67acf4258bd69cf78ea946944ac`. Exactly three interface files changed: `native/build.sh`, `rx2cpp_native_library.rex` and `core/RxRexxRuleSelection.cls`. Four remained byte-identical. `reports/rx2cpp_upstream_observed_20261027.json` records the observed Git blobs; a snapshot file alone is **not authenticated**, as indicated in the audit response. Current pin remains 9047f0e; no automatic re-pin.

The standalone `tools/plan42_rx2cpp_upstream_audit.py` rejects incomplete or mismatching interface inventories and emits a *non-authorising*, read-only review receipt. It does not query GitHub directly or claim live compiler qualification.

## Regression

Run `python3 -m unittest discover -s tests -p 'test_plan42*.py' -v`. The dev5 added cases create a real local Git repository, change or symlink the seven compiler entry files while holding HEAD fixed, and verify rejection. Additional tests validate the upstream snapshot and preserve `NO_AUTO_REPIN`. The package's existing test suite still runs.

## Remaining work

- Obtain a full pinned RX2CPP checkout in a qualified ooRexx 5.3.0 r13196 environment, and run its real GCC/Clang, interpreter differential, object identity, numeric context, class-private, prologue and rollback tests.
- Verify full dependency closure and local working-tree cleanliness, not just these seven interfaces, before treating native compilation as qualification.
- Keep genuine Plan42 object-model inventory untrusted until a controlled interpreter capture and source identity linkage is established.
- Route successful evidence to Alchemy approval surfaces; do not change Runtime Registry or `CODELET:DEFINE` automatically.

Rasen Falcon ownership lane: `plan42-alchemy`; RX2CPP internal compiler work remains with `rx2cpp`.
