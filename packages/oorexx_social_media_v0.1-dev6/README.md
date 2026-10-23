# ooRexx Social Media Library — v0.1-dev6

CMS Brand Builder / Dynamic Story provider-neutral semantics for social platforms,
marketplace reviews, Steam, Discord, YouTube creators, email/community groups,
private messaging and advertising *proposals*. **No paid placement execution**.

## New in dev6

`src/SocialAdapterContract.cls` implements a provider-neutral integration surface:

* `SocialAdapter`, with separate outbound, capability, inbound verification, and
  reconciliation operations;
* `SocialAdapterRegistry` and `SocialAdapterScopedResolver` for exact provider
  lookup and account/surface-scoped capability observations;
* `SocialAdapterProvider`, a shim into the existing SocialLibrary controlled
  publication route (not an authority to publish);
* `SocialAdapterInboundVerifier` and `SocialAdapterDeliveryVerifier`, which
  delegate distinct evidence checks to provider-owned verification code;
* `SocialTestAdapter`, a deliberately inert test implementation which dispatches
  only simulated receipts and denies inbound and remote proof.

This is an **additive** increment. All dev5 `.cls` source is byte-identical and
all dev5 regression tests are retained. The adapter is not an actual live vendor
implementation and must not be mistaken for one.

See `docs/DEV6_ADAPTER_CONTRACT.md` and earlier dev3–dev5 contracts.

## Smoke/qualification

```sh
bash tests/run_all.sh /path/to/rexx
# with rexxc installed: rexxc src/*.cls (one by one)
```

`tests/adapter_contract.rex` adds an executable (when a local ooRexx is
available) simulated provider end-to-end test. The full suite is declared in
`integration.json` for Alchemy Autobuild and will be run by its qualified
interpreter when available. No hardcoded credentials, keys, or remote API calls.

## Integration and repository

`integration.json` declares `alchemy.autobuild.integration/0.2` and publication
to `packages/oorexx_social_media_v0.1-dev6`. A Git submission should use
`tools/alchemy_submit.py` (or its documented provider-API fallback) on
`animatedads/alchemy`, not commit directly to main. An accepted autobuild result
is required before the package can be considered integrated.

## Boundaries still open

No ooRexx runtime executable is present in this packaging container, and the
conversation's uploaded r13196 `.deb` has no downloadable backing here. This
candidate is statically qualified only until its tests run on Autobuild.
Development outbox recovery still does not provide power-loss durability,
interprocess locking or remote exactly-once. Do not use dev6 to publish live.
