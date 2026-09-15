# Wire UI Swing v0.2-dev3

Defensive Java Swing renderer and desktop shell for `WIRE-UI/0.1`. The Builder remains renderer-neutral: Swing consumes the same exact semantic definitions, composition hints, snapshots and patches as the browser path.

## Core invariants

- Java 21+.
- Swing creation, mutation and top-level window lifecycle are marshalled through the EDT.
- Swing listeners never call ooRexx, Queue Fabric, JMS or application logic synchronously; they enqueue `UI_ACTION`.
- Actions carry the authoritative `elementInstance`, `viewRef` and event-time `renderedRevision`.
- Exact `definitionId@version` identity and manifest content addresses are enforced.
- Cold-cache snapshots/patches wait for exact definitions and sequential patches replay in order.
- Patch preflight completes before visual mutation.
- A view has exactly one declared root; extra top-level instances are rejected before Swing mutation.
- Unsupported primitives and slot failures are contained locally rather than escaping through the EDT.
- Existing `JComponent` identity survives structural re-layout, preserving unsent local editor state.
- Builder `compositionHints` are renderer hints only; journey/business/release/experiment authority remains outside Swing.

## Builder composition

Builder v0.8.3 emits semantic GRID12 placement (`order`, `span`, `rowSpan`, `align`, `region`). v0.2-dev3 translates those hints to `GridBagConstraints`. The actual Builder publish/compiler path is acceptance-tested through ooRexx/BSF with the screenshot-like allocation `12 / 3 / 5 / 4 / 12`.

The stable desktop host uses `BorderLayout.CENTER` so the authoritative view root fills the viewport. GRID12 containers add a renderer-private vertical absorber after the last semantic row so ordinary Swing `GridBagLayout` behaviour cannot vertically centre the whole journey. The absorber is presentation-only and is never a Wire instance.

## Semantic adapter parity

The current primitive vocabulary is: `PANEL`, `CONTAINER`, `TEXT`, `STATUS`, `ACTION_BUTTON`, `BUTTON`, `MODE_SWITCH_OFFER`, `INPUT`, `FORM`, `TOKEN_FORM`, `CHOICE_LIST`, `LIST`, `OFFER_LIST`, `OFFER_SELECTOR`, `DOCUMENT`, `SEMANTIC_RECORD`, `SEMANTIC_COLLECTION`.

Important browser-parity rules are locked: Builder top-level `bindings` are retained; CHOICE_LIST server identity such as `saleId` stays string-valued; actionable collections return only index plus recognised server identity; actionable SEMANTIC_RECORD `message` is editable and only action fields are returned.

`styleRole` is accepted at either definition top level or metadata, as in the browser adapter. Rich FORM/TOKEN_FORM/CHOICE_LIST composition keeps the browser's `Continue` submission semantics. Text editors submit the same semantic action on Enter. Collection cells may render a human label/title/name while action detail remains narrow and authority-safe.

## Executable JAR

The distribution JAR is directly launchable. With no arguments it opens a small Builder-shaped semantic demonstration with SEARCH -> SUMMARY -> TRANSACTION switching. A separate in-process demo authority consumes `UI_ACTION` and sends the next authoritative snapshot; `WireSwingRuntime` itself never chooses the transition.

```sh
java -jar dist/wire-ui-swing-v0.2-dev3.jar
```

Non-GUI verification is available with `--version`; `--smoke-window` opens and automatically closes a real JFrame for packaging/CI acceptance. The launcher is a demonstration host only and does not move journey or business authority into Swing.

## Desktop shell

`WireSwingDesktopWindow` is deliberately thin. It attaches `WireSwingRuntime.hostComponent()` once, owns only JFrame show/hide/dispose/title/size/capture lifecycle, and uses `DISPOSE_ON_CLOSE` rather than terminating the JVM. It does not interpret journeys or actions.

The ooRexx bridge exposes `openDesktopWindow` / `closeDesktopWindow` while keeping the JFrame object private to the bridge. The real path `ooRexx -> BSF4ooRexx -> WireSwingDesktopWindow -> JFrame` is tested under Xvfb.

## Validation

```sh
scripts/run_tests.sh
scripts/run_xvfb_tests.sh
```

The strict headless renderer suite passes **32/32** with `javac --release 21 -Xlint:all -Werror`. A separate real-window suite creates, shows, captures, repeatedly resizes and disposes a JFrame under a virtual X display.

The supplied ooRexx 5.3.0 r13196 and BSF4ooRexx v850 refresh are also exercised end-to-end, including actual Wire UI Server v0.11 objects and actual Wire UI Builder v0.8.3 compiler output. See `VALIDATION.txt` and `integration/BSF4OOREXX_NOTES.md`.

## Runtime shape

```text
Wire UI Server / Queue Fabric
           |
           | WIRE-UI/0.1
           v
   WireSwingRuntime
      |         |
      |         +--> queued UI_ACTION --> transport thread
      v
 defensive EDT renderer
      |
 stable host JPanel
      |
 WireSwingDesktopWindow (optional)
      |
    JFrame
```
