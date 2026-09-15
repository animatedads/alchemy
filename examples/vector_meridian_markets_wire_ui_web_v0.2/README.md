# Vector Meridian Markets Wire UI Web v0.2

Early operator browser for **Vector Meridian Markets Ltd** (`VECTOR_MERIDIAN_MARKETS_LTD`), targeting the VMM v0.11 semantic/runtime baseline.

This package remains deliberately separate from the VMM trading/runtime package. It owns browser presentation, the exact Builder interaction release, operator-workspace semantics and non-authoritative preview fixtures. It does **not** own pricing, route selection, execution, inventory, risk, synthetic-product, funding, collateral, accounting or close-out truth.

## What v0.2 adds

v0.1 established the thin browser shell. v0.2 adds a real compiled Wire UI Builder release:

`VECTOR_MERIDIAN_MARKETS_OPERATIONS@2`

The release contains 23 exact `HUMAN_VISUAL` projections and four operator journey states:

- **DEALING** — firm risk, order worklist/detail, cancel/reconcile intent, inventory, position detail and algo controls;
- **INSTITUTIONAL** — institutional synthetic worklist and contract detail;
- **TREASURY** — funding and collateral/custody worklists/details;
- **EXCEPTIONS** — evidence-first operator exception worklist/detail and acknowledgement intent.

The compiled package is shipped as:

`compiled/vector_meridian_markets_operations_v0.2.json`

It is generated from `wire_ui/VMMWireUIDesignFixture.cls` with Wire UI Builder v0.11 rather than being hand-authored browser JSON.

## Operator action model

The release can project semantic intents such as:

- `VMM.ORDER.CANCEL.REQUEST`
- `VMM.ORDER.RECONCILE.REQUEST`
- `VMM.ALGO.KILL.REQUEST`
- `VMM.ALGO.RESUME.REQUEST`
- `VMM.EXCEPTION.ACKNOWLEDGE.REQUEST`

These are **not trading commands embedded in JavaScript**. The live shell still contains none of those literals. They arrive inside the exact server-authoritative compiled release/definition and an action remains unusable unless Wire UI Server records that action as available at the exact rendered revision.

The included Server v0.17 authority regression proves that:

1. a rendered/bound control is rejected before server-side action availability is set;
2. a server-available semantic intent reaches the server dispatcher;
3. an invented execution action is rejected as not bound to the element;
4. a Federation Merchant access point is rejected by access-point ownership;
5. a mismatched site-release content address is rejected.

No VMM business implementation is present in that fixture; the dispatcher records delivery of an operator intent only.

## Start

```bash
./start.sh
```

With no configuration the package opens the **non-authoritative preview fixture**.

For a real server-authoritative Wire UI session:

```bash
./start.sh --live \
  --bootstrap-url http://127.0.0.1:8090/wire-ui/bootstrap \
  --wire-ui-js-root /path/to/alchemy_wire_ui_js_v0.4-dev4
```

Browser bootstrap data must contain only browser-safe Wire UI binding information. Queue claim tokens, VMM service credentials, signing keys and venue credentials must not be stored in browser configuration.

## Preview

`web/preview.html` remains sample data only. v0.2 makes the intended operator-control rail visible, including cancel, reconciliation and algo-kill intent, while clearly marking that availability as server projected in a live session.

The preview also keeps the company boundary visible:

- All Japan institutional contracts are VMM contract objects;
- execution surfaces receive VMM contract references, not raw institutional portfolios;
- FederationBank is shown only as an arm's-length lender/counterparty where VMM itself projects that fact;
- Federation principals have no VMM workspace authority.

## Boundary

> The browser renders VMM truth and expresses user intent. It never becomes VMM truth.

The browser must not calculate or infer executable price, route selection, order state, fill state, inventory, P&L, margin, close-out, journal entries, legal netting, collateral ownership or action authorisation.

See `docs/FRONTEND_BOUNDARY.md` and `docs/SEMANTIC_RELEASE.md`.

## Browser-only validation

```bash
./run_tests.sh
```

This checks the shell boundary, preview boundary, compiled release structure and canonical starter.

## Full Builder/Server qualification

With the qualified ooRexx / Wire UI dependency roots available:

```bash
OOREXX_HOME=/path/to/oorexx-prefix \
WIRE_UI_BUILDER_ROOT=/path/to/wire_ui_builder_v0.11 \
WIRE_UI_SERVER_ROOT=/path/to/wire_ui_server_v0.17 \
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8 \
OOREXX_CRYPTO_ROOT=/path/to/oorexx_crypto_v0.5 \
./run_qualification.sh
```

The qualification rebuilds the compiled package byte-for-byte and exercises the Server v0.17 action-authority boundary.
