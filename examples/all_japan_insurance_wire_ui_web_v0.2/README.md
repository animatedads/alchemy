# All Japan Insurance Wire UI Web v0.2

Early AJI operator UI and a runnable authoritative Wire UI development access
point. This package is separate from `all_japan_insurance_v0.10.zip`: the AJI
business model remains the authority for rating, underwriting, policy, billing,
claims and accounting semantics.

## The v0.1 connection failure is fixed

v0.1 shipped the browser projection shell but deliberately did not manufacture
an authoritative Wire UI session. If nothing was listening on 127.0.0.1:8090,
its local `/wire-ui/bootstrap` proxy correctly returned
`502 BOOTSTRAP_UNAVAILABLE` and the page displayed `Unable to connect`.

v0.2 supplies that missing development service. `./start.sh --live` now starts:

```
browser :8082
    |
    | GET /wire-ui/bootstrap
    v
ooRexx AJI WireUIApplication
    -> Wire UI Server v0.17
    -> Queue Fabric v0.9-dev4
    -> private Queue Fabric bridge
    -> Web Gateway v0.2 :8090
    -> WebSocket
    -> Alchemy Wire UI JS v0.4-dev4
```

The browser still cannot create a session, policy, price, reserve, billing
position or journal. It receives all of those as server projections.

## Start it

If `rexx` is installed in PATH:

```bash
./start.sh --live
```

The defaults are:

- browser shell: `http://127.0.0.1:8082/`
- authoritative bootstrap/WebSocket gateway: `127.0.0.1:8090`

With the supplied unpacked ooRexx test runtime, for example:

```bash
./start.sh --live \
  --rexx /path/to/oorexx/usr/local/bin/rexx \
  --rexx-lib /path/to/oorexx/usr/local/lib
```

The launcher prints the browser URL, the authoritative bootstrap URL, the exact
site release and the projection mode.

To start only the authoritative endpoint:

```bash
./start-authoritative.sh --port 8090
```

An external production bootstrap is still supported:

```bash
./start.sh --live \
  --bootstrap-url https://aji.example/wire-ui/bootstrap \
  --wire-ui-js-root /path/to/alchemy_wire_ui_js_v0.4-dev4
```

`./start.sh` with no options remains the clearly labelled non-authoritative
visual preview.

## Current live semantic release

`ALL_JAPAN_INSURANCE_OPERATIONS@2` contains six browser-supported human
projections:

- portfolio summary
- server-issued policy collection
- selected policy provenance
- billing position
- claim position
- AJI-STAT accounting projection

The first policy selection is a semantic `AJI.POLICY.OPEN` action. Only a
server-issued policy identity is returned by the browser. The ooRexx
application advances the journey and creates the selected policy/billing/claim/
accounting projection. Later selections are updated as one grouped view
revision.

The development service currently projects a small explicit
`AUTHORITATIVE_DEVELOPMENT_FIXTURE`. This is real server authority for the Wire
UI session and is sufficient to validate transport, definition material,
selection and provenance; it is **not** a claim that AJI v0.10 has acquired a
persistent production policy repository/service API. The next adapter should
replace the fixture source with AJI application/service queries without changing
the browser trust boundary.

## Important v0.2 renderer correction

The v0.1 Builder vocabulary compiled `SUMMARY` and `TIMELINE` primitives. The
current Alchemy JS v0.4-dev4 server semantic adapter does not implement those
server primitives. v0.2 corrects the release to `SEMANTIC_RECORD` and
`OFFER_LIST`, adds explicit field bindings, and qualifies the exact compiled
release through the real JavaScript renderer. This means fixing port 8090 alone
would not have been sufficient for a reliable live v0.1 session.

## Security boundary

The Web Gateway bootstrap contains only browser-safe ownership and binding
information. Queue Fabric bridge credentials/claim tokens do not enter the
browser. The path token used by this development launcher is a narrow local
access-point mechanism, not production authentication/TLS/access control.

Staff mutation actions remain deliberately absent. Before enabling them, pair
AJI with the current Access Control, method/object Permissions and Security
Effect authorities.

## Validation

`run_tests.sh` covers:

- browser bootstrap configuration
- browser business-authority boundary
- preview boundary
- starter behaviour
- Builder v0.11 -> Server v0.17 exact release binding
- generated compiled-release/source lock
- real ooRexx -> Wire UI Server -> Queue Fabric -> Web Gateway -> Alchemy JS
  connection
- live portfolio rendering and server-authoritative policy drill-down

See `VALIDATION.txt` and `VALIDATION_TRANSCRIPT.txt` in the sealed package.
