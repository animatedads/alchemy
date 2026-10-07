# Inspector Clouseau — general-purpose ooRexx package

This package lifts **Inspector Clouseau** out of the Storage/FUSE integration and
ships it as an ordinary ooRexx inspection package.  It has no Storage Fabric or
FUSE dependency.

The Inspector can attach to arbitrary live ooRexx objects, walk reachable object
and class/package structure, record method and inheritance evidence, optionally
install temporary inspection probes, and return a structured immutable snapshot.

## Files

- `lib/InspectorClouseau.cls` — qualified general-purpose Inspector.
- `lib/InspectorClouseau.authority.cls` — recovered v1.4.2 authority source,
  retained unchanged for provenance.
- `lib/json.cls` — ooRexx `json.cls` dependency, bundled unchanged for a
  self-contained copy.
- `examples/basic_inspection.rex` — minimal arbitrary-object example.
- `tests/philfork_clouseau_wasm.rex` — dining-philosophers concurrency/WASM
  qualification.
- `docs/InspectorClouseau-r13196-observation.patch` — the narrow compatibility
  patch previously qualified against ooRexx 5.3.x.

## Minimal use

Place `InspectorClouseau.cls` and `json.cls` on the ooRexx package search path:

```rexx
thing = .MyObject~new

inspect = .InspectorClouseau~new
inspect~dontFollowPackage('REXX')
inspect~reportInheritanceMap(.true)
inspect~addPackage(.context~package)
inspect~addRoot('thing', thing)

snapshot = inspect~snapshot
say snapshot~asText

::requires 'InspectorClouseau.cls'
```

`addRoot()` is useful for focused/general-purpose use because it does not add
Inspector's optional `.environment`, `.local`, and `.context` automatic roots.
`attach()` remains available when those automatic roots are desired.

## Principal API

The class is `.InspectorClouseau`.

Common entry points include:

- `addRoot(name, object)` — add a focused live inspection root.
- `attach([name,] object)` — attach and seed the normal automatic roots.
- `addPackage(package)` — include package/class/method metadata.
- `snapshot()` — return an `.InspectorSnapshot`.
- `refreshObservation()` — re-walk registered roots for a fresh observation.
- `enableProbes(.true/.false)` — permit/deny temporary runtime probe insertion.
- `dontFollowPackage(pattern)` — keep inspection closure bounded.
- `reportVariable(pattern)` — request variable/slot evidence.
- `reportCollectionSizes()` / `reportCollectionItems()` — collection evidence.
- `reportInheritanceMap()` — inheritance and method-origin evidence.
- `suppressInternalClassMethods()` — reduce core-runtime method noise.

An `.InspectorSnapshot` provides `asDirectory()` for programmatic consumption and
`asText()` for a human-readable report.

The snapshot schema identifier remains
`alchemy.oorexx.inspector-clouseau.snapshot.v1` for compatibility with existing
consumers; this standalone package does **not** require Alchemy Objects.

## WASM qualification

Qualified against the ooRexx 5.3.0 r13195 Emscripten 6.0.9 port.

The dining-philosophers test creates five `PHIL` objects and five `FORK` objects,
starts all five philosopher methods using ooRexx `START`, leaves the sample's
`GUARD ON WHEN used = 0` synchronization in place, and takes a focused Clouseau
snapshot while those methods are live.

One full Inspector + philosophers run on the original dev1 WASM runtime completed
and observed all ten application objects:

```text
CLOUSEAU schema=alchemy.oorexx.inspector-clouseau.snapshot.v1
CLOUSEAU objects=10 phil=5 fork=5 probed=0
...
PASS Inspector Clouseau dining philosophers WASM qualification
```

However, repeated qualification exposed a **dev1 pthread-runtime instability that
is independent of Inspector Clouseau**: the unmodified baseline `philfork.rex`
failed repeatedly in that old local dev1 runtime with Emscripten worker traps.
The current upstream/public ooRexx WASM runtime has subsequently demonstrated the
Dining Philosophers sample in the browser.  Therefore this package includes the
Inspector philosophers test as the qualification specimen for that current
runtime, but does not mislabel the old dev1 stress result as stable.

General Inspector execution is independently qualified under WASM: focused
snapshot creation passes, and the cooperative probe test passes repeatedly.

Injected probes require application cooperation on stock ooRexx because
`Object~setMethod` / `~unsetMethod` are restricted messages.  An application that
wants slot probes can provide `__INSPECTOR_CLOUSEAU_INSTALL` and
`__INSPECTOR_CLOUSEAU_UNINSTALL` hooks (see `tests/probe_smoke_wasm.rex`).
Observation through `addRoot()` / `snapshot()` does not require those hooks.

## Provenance

Authority recovered from:

`alchemy_objects_v0.8.2-semantic-target.zip` →
`alchemy_objects_v0.8.2/inspector/InspectorClouseau.cls`

The recovered authority identifies itself as Inspector Clouseau v1.4.2.  The
qualified copy applies the previously recorded ooRexx 5.3.x observation patch:

- direct Array input to `.Method~new` when probe source is an Array;
- `Class~methods` supplier based method lookup;
- getter fallback for inferred slots that cannot be exposed directly;
- scalar printable values retained in object records;
- public `refreshObservation()` support;
- stock ooRexx cooperative probe installation passes source to the object's
  install hook (rather than requiring an externally-built Method object), with
  the original Method-object route retained as a fallback.

The untouched authority copy and exact patch are included so the qualified file
can be reproduced and reviewed.
