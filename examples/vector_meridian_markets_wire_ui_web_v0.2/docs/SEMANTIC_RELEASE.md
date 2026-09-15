# VMM Operator Semantic Release v0.2

## Identity

- Release: `VECTOR_MERIDIAN_MARKETS_OPERATIONS@2`
- Legal entity: `VECTOR_MERIDIAN_MARKETS_LTD`
- Profile: `HUMAN_VISUAL`
- Builder: Wire UI Builder v0.11
- Runtime contract: Wire UI `WIRE-UI/0.1`

## Rule

The release defines **what may be projected and what user intent may be expressed**. It does not grant VMM domain authority.

Every actionable projection still depends on Wire UI Server's exact instance binding, exact release provenance, exact rendered revision and action-availability record. Downstream VMM application policy remains responsible for deciding whether an admitted operator intent can alter VMM domain state.

## Workspaces

### DEALING

Firm risk, orders, selected order evidence, cancellation/reconciliation intent, inventory, selected position, algorithm state and algorithm kill/resume intent.

### INSTITUTIONAL

Synthetic-contract worklist and selected contract projection. Execution-sensitive screens receive VMM contract references rather than the institutional client's underlying reference portfolio.

### TREASURY

Arm's-length funding and collateral/custody projection. A FederationBank lender identity is counterparty evidence only.

### EXCEPTIONS

Evidence-bearing operational exceptions and acknowledgement intent. Acknowledgement is not resolution and cannot rewrite order, venue, collateral or accounting state.

## Deliberate absences

The release contains no `BUY`, `SELL`, route, fill, price, journal-posting, collateral-settlement or close-out implementation. Those remain VMM/server authorities.

The live browser shell contains no VMM domain action strings at all. Those strings are installed only from the exact compiled release.
