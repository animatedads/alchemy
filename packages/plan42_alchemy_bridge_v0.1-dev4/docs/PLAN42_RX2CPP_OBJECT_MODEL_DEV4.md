# Plan42 / RX2CPP code-unit integration (dev4, 2026-10-19)

## Source authority and purpose

Based on `alchemy_framework_65_plan42_rx2cpp_integrated_dev3.zip`, this is an **additive, read-only** integration candidate. The RX2CPP compiler is still authored in ooRexx and is the source-language authority. Plan42 must not invent a second ooRexx syntax parser. The interpreter-owned inspector (`oorexx2cpp/inspector/RxSourceInspector.cls`, object map `RX2CPP_OBJECT_MODEL/0.1`) contributes class/routine/method descriptors; `RxWhenDealingWith` owns compiler scope; the RX2CPP backend owns C++ lowering.

Checked repository `animatedads/oorexx` on 2026-10-19: GitHub main commit `f63993cda664465523d4cd7650106bbcd0ccfb4d`, dated 2026-10-17. RX2CPP's VERSION remains `0.30.18`. **The previously pinned `9047f0e13c8cd67acf4258bd69cf78ea946944ac` is NOT silently promoted.**

## Code-unit boundary added

- Intention `plan42.native.inventory`, API `plan42.rx2cpp.inventory/0.1`.
- `tools/plan42_rx2cpp_inventory.py`: imports the exact hex-encoded, tab-delimited stream and retains byte-exact source bodies (`source_hex` / SHA-256), defining owner, selector, visibility, flags, kind and package numeric/prologue options.
- `tools/plan42_bridge.py native-inventory` and `AlchemyPlan42Service~nativeInventory(...)` expose it via the existing Alchemy service transport without mandatory Queue Fabric or RPC.
- `plan42_rx2cpp_plan.py --model PATH` optionally binds its non-executing native build proposal to **scope descriptors** extracted from this validated stream; invalid or stale-path evidence is refused.
- Imported code-unit descriptor scopes: class declaration -> CLASS (metadata), methods including class-side methods -> METHOD (activation), routines -> ROUTINE, prologue -> PROLOGUE. This is a *proposal* for the existing `RxWhenDealingWith` scope gateway, **not a live compiler-emitter input**.

The importer rejects unknown kinds, malformed hex, unsupported visibility/flags, duplicate names, methods without their defining class, out-of-workspace/symlink map files, non-generated source files, and a source path inconsistent with the model's PACKAGE line. It does **not** reinterpret METHOD source text.

## Reproduce with actual ooRexx (separately, when available)

For a **trusted** class/routine source that does not require dependency imports:

```sh
# From the verified/pinned animatedads/oorexx checkout:
cd oorexx2cpp
export REXX_PATH="$PWD${REXX_PATH:+:$REXX_PATH}"
rexx inspector/inspect.rex /absolute/alchemy/generated/plan42/worker.cls \
  /tmp/unique-not-existing-inspection.cls > /absolute/alchemy/reports/worker.object-map.tsv
# The inspector removes its inspection-only temporary source.

# From the Alchemy workspace:
python3 tools/plan42_bridge.py native-inventory \
  --source generated/plan42/worker.cls \
  --model reports/worker.object-map.tsv --mode native-package
python3 tools/plan42_bridge.py native-plan \
  --source generated/plan42/worker.cls --mode native-package \
  --model reports/worker.object-map.tsv
```

**Warning:** RX2CPP explicitly does not describe this process as a safe general sandbox. Use only approved source, and never turn a model import into an automatically trusted deployment.

## Known mismatch: generated Plan42 class_greeter.rex

`generated/plan42/class_greeter.rex` currently includes `::requires "rxregexp.cls"`. RX2CPP's normal `inspect.rex` rejects `::REQUIRES` before the interpreter constructs the inspection package. The newer `--tree` inspector supports neutralized dependency traversal, but its output includes graph records (`requires`, `edge`, `missing`) beyond the **single-source** model accepted here. Do not forge a single-source export or assert the generated greeter was inspected. A later, separately qualified graph importer should take `--tree` with dependency and cycle evidence; native `::REQUIRES LIBRARY` is still a refusal.

## Qualification and constraints

Validation here tests **synthetic object-model streams only**, not interpreter-produced model capture. The importer cannot prove an externally provided model is authentic: status `IMPORTED_UNATTESTED`, `export_authenticity_verified=false`, `source_to_model_semantic_equivalence=UNVERIFIED`. Source/map hashes protect later transport/change checks, **not provenance of the model from that source**.

- RX2CPP native C++: NOT EXECUTED.
- RX2CPP object inspector: NOT EXECUTED here (no `rexx` binary).
- Exact current compiler revision: observed, not checked out or qualified.
- RX2CPP code-unit emitter integration: NOT IMPLEMENTED.
- Existing Alchemy runtime registry publication: NOT PERFORMED.
- Codelet publication, hot replacement, agent state migration: NOT PERFORMED.

Next implementation authority: inside RX2CPP, have `RxSourceInspector` supply structured unit source directly to the `RxWhenDealingWith~setScope` and common rule-selection pipeline. Qualify actual object-valued argument retention and method scopes with ooRexx 5.3 reference output, GCC and Clang before marking a native method eligible.
