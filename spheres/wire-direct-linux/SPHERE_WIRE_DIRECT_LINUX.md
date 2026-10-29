# Wire Direct Linux — component sphere

**Component:** `wire_direct_linux`  
**Recorded candidate:** `wire_direct_linux_v0.1-dev39.zip` (2026-10-23)  
**Archive SHA-256:** `675183a3dec039b4dee59f14bdb327ce02f7a216cb2ee455e59019e30a111839`  
**Status:** Development candidate; not native-GTK or end-to-end editor qualified.

## Intent and ownership

Wire Direct Linux is the GTK4-native projection of a renderer-neutral Wire semantic application. It supports a VisPro/REXX-style application builder: select an element, choose an event, edit ordinary ooRexx behaviour, then explicitly bind it. The Builder owns symbolic design-time intent; the semantic application/controller owns runtime state and behaviour dispatch; the GTK renderer owns native widgets, layout, and event-loop mechanics. Neither the Builder nor the application behaviour owns GTK widgets.

## Current implementation boundary

- A declarative `.wire`/XML MailReader definition supplies the `VirtualList` source, start and bounded resident count (100 in the sample).
- GTK emits semantic `RangeRequested(start=N)` rather than directly fetching or deciding the requested range; the controller supplies the bounded window. Stable identities are separate from visible row ordinals.
- Selection is emitted as a semantic `SelectionChanged(identity=...)` event, and document updates travel through Wire's semantic projection.
- `WireBuilderSession~newBehaviourDraft` creates a detached ordinary-ooRexx method draft.
- `WireBuilderSession~acceptEditorSource` accepts edited source through `WireBehaviourDraft~replaceSource`, which validates the declared method and disallows additional package directives.
- `WireBuilderSession~commitBehaviourDraft` rejects stale selection and duplicate binding IDs, and stores edited source under `wire.behaviour.source` and method under `wire.behaviour.method`. It does not evaluate, compile, register, or dispatch that source.

## Dependency/authority constraints

- No GTK/GDK types in ordinary ooRexx behaviour or the editor contract.
- No IMAP or business-source policy inside the renderer.
- Language Alchemy engines remain behind ooRexx language-block integration, not imported into Wire's renderer.
- Source Editor integration is optional and not yet live-qualified. Queue Fabric is not mandatory for direct local UI.
- Other Wire UI Server/Builder/Swing components retain their own authorities; compatibility must be checked against their actual contracts before binding.

## Qualification evidence and gaps

Archive includes `MANIFEST.sha256`, `QUALIFICATION_DEV35.txt` through `QUALIFICATION_DEV39.txt`, `scripts/build.sh`, and test sources. The manifest was checked against the extracted dev39 package on 2026-10-23. A local build attempt was interrupted before completing the full suite; earlier dev39 reported an available regression pass. GTK4 headers/runtime and live Source Editor integration were not qualified in the assistant execution environment. Do not treat static GTK source checks as native compilation or a successful interactive application test.

## Next acceptance work

1. Resolve and inspect the latest Source Editor API; implement a real editor roundtrip without granting the editor application-dispatch authority.
2. Exercise committed ordinary ooRexx source in the Wire controller with explicit capability checks and failure reporting.
3. Run native GTK4 compile and interactive viewport/selection tests on Linux, especially virtual-scroll reentrancy and stable-selection restoration.
4. Reconcile this candidate with Semantic Source Control and record accepted revision provenance before declaring an estate baseline.

## Repository synchronization

This sphere is a documentation commit, not a claim that the complete dev39 source tree has been synchronized. The distributable archive remains the named candidate until a full source-tree import and qualification is committed.

## dev40 — Builder state-machine correction (2026-10-28)

Candidate archive: `wire_direct_linux_v0.1-dev40.zip`; SHA-256 `2675713bccbe035f1ee107f859726ab249ac0d20e4aff6b4de042acd7e156c50`. `WireBuilderSession~selectElement` now clears the selected trigger when the selected element changes. `bindBehaviour` and `commitBehaviourDraft` now call the same private `assertUnusedBindingId`, eliminating duplicate IDs across manual and editor paths. Added `tests/test_builder_selection_invalidation_static.py`; adjusted the roundtrip static test to assert the shared guard is invoked before metadata is committed. The new and downstream static checks passed; a full build rerun timed out and GTK/ooRexx runtime qualification is outstanding. Archive source is not yet committed to GitHub; this sphere records the candidate only.

## dev41 — Generated method identifier safety (2026-10-29)

Archive `wire_direct_linux_v0.1-dev41.zip` SHA-256 `2c93462bf5c2746eca4c3c235ae07e956680e8016a998cfe849dd3dd95461845`. `WireBehaviourDraft~init` now validates portable ASCII Rexx method identifiers before interpolating the name into the scaffold; prevents embedded newline/directive injection. Added `tests/test_behaviour_method_identifier_static.py` and wired it into `scripts/build.sh`. Local full available build PASS, manifest check PASS, ZIP integrity PASS; no native GTK4/ooRexx execution qualification. GitHub source subset committed under `packages/wire_direct_linux_v0.1-dev41/` (core draft and test), but full source tree is not yet synchronized. This component does not directly implement website, HTTPS, LDAP, SMTP/IMAP or XTP deployment, so no production activation is claimed.
