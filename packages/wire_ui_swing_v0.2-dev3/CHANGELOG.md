# Changelog

## v0.2-dev3 — 2026-08-26

- Adds conservative semantic presentation on top of the active native Swing look-and-feel; no application colour/theme authority moves into the renderer.
- Reads `styleRole` from either the definition top level or metadata, matching the browser semantic adapter.
- Makes rich FORM/TOKEN_FORM/CHOICE_LIST submit text `Continue`, matching browser composition instead of misusing `definition.label` as an action caption.
- Adds accessible `JLabel.setLabelFor(...)` relationships and Enter-to-submit for text fields without changing semantic action payloads.
- Adds human-facing collection cell rendering while keeping actionable collection payloads narrowed to `index` plus recognised server identity.
- Adds `WireSwingStandaloneDemo`, a tiny authority outside `WireSwingRuntime`; the renderer emits `UI_ACTION` and only the demo authority chooses SEARCH/SUMMARY/TRANSACTION snapshots.
- Adds live standalone journey switching through the executable JAR without granting Swing journey authority.
- Adds desktop resize API and Xvfb resize-stress acceptance.
- Strict headless renderer suite: 32/32.
- Revalidates ooRexx 5.3.0 r13196 + BSF4ooRexx v850, Wire UI Server v0.11 objects, Builder v0.8.3 GRID12 compiler output, and real JFrame lifecycle.

## v0.2-dev2 — 2026-08-26

- Repairs the distribution JAR as a real executable JAR with `Main-Class: org.alchemy.wireui.swing.WireSwingMain`.
- No-argument `java -jar` opens a Builder-shaped standalone Swing renderer demonstration.
- Adds `--version`, `--help`, and `--smoke-window` launch modes.
- Adds packaging acceptance that executes the built JAR itself, including a real JFrame under Xvfb.
- Keeps the launcher as a presentation/demo host only; journey/business authority remains outside Swing.

## v0.2-dev1 — 2026-08-26

- Adds the first real `WireSwingDesktopWindow` JFrame shell while keeping journey/business authority outside Swing.
- Attaches the stable renderer host once; snapshot replacement cannot stale the desktop shell.
- Uses BorderLayout for the desktop root and a renderer-private GridBag vertical absorber so semantic content remains top-aligned rather than being vertically centred by Swing.
- Adds strict single-root view validation for snapshots and patches.
- Adds real Xvfb window lifecycle/capture testing.
- Adds ooRexx bridge desktop open/close methods without exposing arbitrary Swing widgets.
- Validates real `ooRexx -> BSF4ooRexx -> JFrame` show/dispose under Xvfb.

## v0.1 — 2026-08-26

Initial defensive Swing renderer/runtime cut for WIRE-UI/0.1.

- Keeps Wire UI journey, business state, release selection and action authority outside Swing.
- Adds renderer-capability `UI_HELLO` without choosing an interaction profile.
- Adds exact immutable definition cache and manifest guard.
- Adds parent-before-child snapshot validation and headless component-tree construction.
- Adds revision/view guards, transactional patch preflight and exact-definition hold/replay.
- Adds EDT-confined component creation/mutation and local rendering failure containment.
- Adds semantic primitive factory for current browser-runtime primitive vocabulary.
- Matches browser semantic-adapter action detail for CHOICE_LIST server identities, SEMANTIC_RECORD message actions, and actionable collection identity projection.
- Normalises actual Builder v0.8.3 top-level `bindings` into the renderer definition model.
- Adds GRID12 composition allocation over `GridBagLayout`.
- Preserves existing component identities across structural re-layout, retaining local unsent editor state.
- Queues actions without synchronous ooRexx/transport callbacks and stamps view revision at event time.
- Adds narrow ooRexx `.Table/.Directory/.Array` -> Java `Map/List` bridge.
- Adds BSF-compatible static `WireSwingRuntime.create()` factory.
- Validated with 25 strict Java 21 headless tests, real ooRexx 5.3.0 r13196 + BSF4ooRexx v850, actual Wire UI Server v0.11 objects, and an actual Wire UI Builder v0.8.3 compiled GRID12 package.
