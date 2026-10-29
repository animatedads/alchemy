# Plan42 service integration into Alchemy — 0.1-dev1

**State:** additive integration candidate against the `alchemy_framework(65)` snapshot plus its FOP membrane document patch. This is *not* a claim that every current Alchemy runtime component is packaged here or that CODELET publication is qualified.

Plan42 is no longer only a standalone compiler command. `runner.rex` registers one `plan42` service in the container, with a native ooRexx façade (`plan42/AlchemyPlan42Service.cls`) and a testable, transport-neutral Python compiler adapter (`tools/plan42_bridge.py`). Existing `specGenerator`, `PreferredModule`, and `ProgramSpec` remain in place; no competing registry, transport selector, or queue dependency is created.

The service exports three semantic intentions:

- `plan42.discover`: *read-only*, recomputes available targets from the installed compiler. No permanent target cache.
- `plan42.inspect`: *read-only*, validates and inventories one source Plan42 JSON file, including preferred references and security annotations.
- `plan42.compile`: *effectful output staging*, validates source/target, checks compatibility, emits source to `generated/plan42/`, returns source and artifact SHA-256 plus generator attribution, and does **not** execute or publish emitted code.

The bridge uses `subprocess.run` with an argv array, never a shell. It rejects source-path escapes, output-path escapes and registered-but-unsupported targets; a failed compiler leaves existing destination artifacts untouched. The ooRexx façade additionally restricts parameters to a shell-safe token alphabet because the current framework `ExternalCall` transport assembles a shell command. The host must enforce output-write authorisation; the adapter is *not* a privilege boundary by itself.

## Backend decisions

`--engine auto` chooses native ooRexx generation for Python, Bash, Regina and ooRexx **only when `rexx` is installed**, otherwise the canonical Python compiler is used. An explicit `--engine native` without `rexx` refuses, never silently falls back. The Python compiler owns C and Rust. C++ and Java return explicit unsupported-target responses.

Native generation follows successful canonical preflight with a **fresh** output file. A successful preflight and generated ooRexx source do not prove semantic equivalence with the Python compiler. All target statuses are returned as evidence, not converted into promises of executable/runtime fidelity.

The current Python compiler preserves the Rust scaffold implementation and adds the already accepted `preferred.log`, `preferred.json`, minimal `preferred.api`, and typed CLI argument helper line (ported selectively from the accepted Python preferred/CLI fixes). `run_plan42.rex` delegates C/C11/Rust and registered C++/Java through the Python compiler, including unsupported diagnostics.

## Usage from the Alchemy root

```sh
python3 tools/plan42_bridge.py discover
python3 tools/plan42_bridge.py inspect --spec tools/full_nodes.plan42.json
python3 tools/plan42_bridge.py compile --spec tests/preferred_capabilities_smoke.plan42.json --target python3
python3 tools/plan42_bridge.py compile --spec tools/safe_subset.plan42.json --target c
python3 tools/plan42_bridge.py compile --spec tools/rust_scaffold.plan42.json --target rust
python3 -m unittest discover -s tests -p 'test_plan42_alchemy_integration.py' -v
```

In ooRexx:

```rexx
service = container~get('plan42')
meta    = service~discover
info    = service~inspect('tools/full_nodes.plan42.json')
build   = service~compile('tools/safe_subset.plan42.json', 'c')
```

The emitted response is a `.Directory` parsed from JSON. The bridge is deliberately independent of ConnectSelector; direct calls work now, and ConnectSelector can carry these same intentions over RPC or QueueFabric later, where governance/acknowledgement belongs.

## Runtime and governance boundary

`CODELET:DEFINE` must not be treated as permission to execute emitted code, swap live classes, or migrate resident state. Hot replacement requires independent approval, target method preflight, cooperative checkpoint/restore, invocation quiescence, and retained object identity rules. The class-upgrade proof is useful upstream evidence but it is not a blanket deployment authorisation. A future plugin router may expose these intentions only after provider interface qualification. No automated discovery registry update is claimed here beyond direct Alchemy container registration.

## Qualification

Local Python compiler path: generated/compiled/ran `full_nodes`, preferred smoke default and explicit args; C safe subset generated and C11 syntax checked; Rust scaffold generated with marker and typed functions. Static bridge security refusals, registration, and source/output provenance were tested. Native live ooRexx service and full Alchemy composition-root boot were **not tested** because this environment does not have `rexx` and the framework 65 zip is not an entire production runtime closure. Rust live compilation likewise awaits `rustc`.

Integration edits to existing source were applied with `fop applydiff`, with guard-first preflight and patch transcript. The original member bytes not listed in the delta are preserved in the full ZIP.
