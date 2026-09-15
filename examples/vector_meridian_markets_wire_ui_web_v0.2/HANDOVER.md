# Handover — Vector Meridian Markets Wire UI Web v0.2

## Baseline relationship

This is a separate UI candidate. It does not supersede or modify `vector_meridian_markets_v0.11.zip` as VMM business/runtime authority.

## What is real now

`wire_ui/VMMWireUIDesignFixture.cls` is a Builder v0.11 semantic source for the VMM operator workspace. It compiles to the shipped exact release:

`compiled/vector_meridian_markets_operations_v0.2.json`

Release identity:

`VECTOR_MERIDIAN_MARKETS_OPERATIONS@2`

The release describes four human operator workspaces and 23 exact projections.

The first operator intents are:

- order selection / cancel request / reconciliation request;
- inventory selection;
- algo kill / resume request;
- synthetic selection;
- funding/collateral selection;
- exception selection / acknowledgement request;
- semantic workspace navigation.

These are Wire UI semantic intents, not direct calls to VMM classes.

## Boundary already proved

The live browser shell still contains no VMM domain action literals or business-object references.

Server v0.17 regression proves that rendering a bound action is insufficient. Exact server-side action availability at the rendered revision is required before dispatch. Ownership and site-release provenance are also enforced before dispatch.

## Next implementation step

Build a VMM-owned Wire UI application adapter which projects real v0.11 state into the semantic elements and translates admitted UI intents into existing VMM queue/application authorities.

Recommended first live adapters:

1. order/execution projection + cancel/reconcile intent adapter;
2. firm/algo risk projection + kill/resume intent adapter;
3. exception work queue projection;
4. synthetic and treasury read-only projections;
5. only after those are stable, explicit institutional/treasury action workflows.

Do not let the adapter acquire authority by reaching directly into FederationBank, All Japan Insurance or browser state. It should consume VMM-owned projections/services and emit VMM-owned queue commands/intents under existing application authority.
