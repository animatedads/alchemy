# Semantic Source Code Examiner — human UI

This is the Wire UI access point intended for the human reviewer.

## What the human can do

- search semantic objects, work tickets and work entries;
- open an exact accepted/candidate source revision;
- read its attached design authority beside the source;
- mark a finding against the exact revision and optional line range;
- resolve a finding with a recorded resolution;
- request a dependency-complete `source.get_package` build;
- request qualification against that exact package request;
- accept or refuse a submitted work entry with recorded evidence.

## Browser boundary

The browser is not an IDE and does not own source truth. It renders Wire UI
projections and emits named semantic actions. Source mutation, dependency
resolution, test results and work disposition remain authoritative ooRexx/MCP
operations.

## Start the browser surface

1. Make the accepted Alchemy Wire UI JavaScript package available at:

   `web/vendor/alchemy-wire-ui/src/`

2. Copy `web/config.example.mjs` to `web/config.mjs` and set the exact gateway
   WebSocket URL and Wire UI IN queue produced by the application host.

3. Serve `web/` as static files, for example:

   `python3 -m http.server 8080 --bind 127.0.0.1 --directory web`

4. Open `http://127.0.0.1:8080/`.

The page deliberately shows a configuration/connection failure rather than a
fake local review application if the real Wire UI service is absent.

## Semantic navigation

The Examiner can now navigate source relationships rather than only display files. Server-authored actions support go-to-definition, find-uses, callers, callees and reference explanation. The UI should make resolvable constructs clickable (for example ooRexx `::requires`, `.Class`, and `instance~method`) while visibly distinguishing `RESOLVED`, `POSSIBLE`, `DYNAMIC` and `UNRESOLVED` references.

## Dynamic catalog and complete review context (dev13)

The browser must never be edited to add a module, source unit, test, class or file. Navigation is populated by `CODE.CATALOG`/the initial server catalog. Transport bootstrap comes from the same-origin `service-descriptor` endpoint.

Opening a semantic object is required to bring back its exact revision plus design, findings, revision history, requirements, notes/documentation, attached resources, module/deployment state, branch state, semantic references, runtime-effective surfaces, test evidence, related work entries, exports and dependencies. Empty collections are valid; omitted sections are a contract error.

The human surface includes all agreed actions: compare revisions; add method requirements and notes; upload/link resources; request development, deployment and branch packages; request tests; accept/refuse work; classify/protect/resolve branches; navigate definitions/uses/callers/callees; explain references; and inspect runtime class surfaces/overrides.


## dev14 visible workspace

The shipped `web/index.html` is now the Code Examiner workspace, not a source-file reader or a waiting card.  It contains no module/file inventory.  Navigation content and selected-object content are server-authoritative.  The visible controls correspond to the semantic actions declared in `wire/CODE_EXAMINER_UI_DESIGN.json`; the browser must not invent source identities, revisions, permissions, test outcomes or work dispositions.

## dev18 default class inspection

The central Examiner view now defaults to the condensed class semantic manifest: class/inheritance tree, inspection `since` evidence, and method rows containing `method`, `from`, `exposes`, and `returns` including returned class/type where known. Exact source and method bodies are an explicit drill-down to avoid spending tokens on source that the examiner has not requested.

## Dynamic intention entry

The navigation column now includes **Ask Examiner**.  It emits the semantic
`INTENTION.SUBMIT` action; the browser does not classify the user's text.
Intention Service performs fresh discovery and resolution on the server.  When
an intention can execute, dispatch re-enters the ordinary secure Examiner action
path rather than bypassing it.
