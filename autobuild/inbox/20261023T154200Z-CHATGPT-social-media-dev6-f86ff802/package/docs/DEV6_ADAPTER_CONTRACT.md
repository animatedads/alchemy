# Social Media v0.1-dev6 — adapter contract

`social.media.adapter/0.1` is a semantic service-provider interface, not an HTTP API.

## Integration path

1. A platform adapter implements `SocialAdapter` with six provider operations:
   `id`, `capabilities`, `discoverScoped`, `dispatch`, `verifyInbound`, `verifyRemote`.
2. Register it in `SocialAdapterRegistry`. Register `SocialAdapterProvider(adapter)`
   with `SocialLibrary`, ensuring the provider adapter ID matches the surfaces.
3. Applications use `SocialScopedPublicationService` with an
   `SocialAdapterScopedResolver(registry)`; its `authority` remains an independent
   production CMS/identity/institutional-policy authority.
4. The adapter reports only provider-wide *possible* actions in `capabilities`.
   Every new publication must resolve current account/surface/action capabilities
   and pass existing local publisher approval and the library's policy.
5. `dispatch(action,context)` returns a dictionary with `status` reflecting
   *acknowledgement*, not a proven delivery. Status `accepted`/`queued` is a
   submitted outbox state; `simulated` only for synthetic providers.
6. Reconciliation supplies external evidence through
   `SocialAdapterDeliveryVerifier(registry)`, which delegates proof verification
   to the exact adapter. Never infer delivery from queue acknowledgement.
7. Inbound observations pass through `SocialInboundGate` configured with
   `SocialAdapterInboundVerifier(registry)`. Adapter verification must establish
   authenticity, account binding and replay protection. The test adapter denies
   all inbound and remote-status verification.

## Explicit boundaries

* No adapter obtains authorization by registration or provider discovery.
* A provider capability does not imply permission to publish from an account.
* Inbound verifier and delivery verifier are independent of outbound authority.
* Account and surface scope must be checked again after revocation for new jobs.
* An existing outbox result is immutable under request replay. Receipt status
  `unknown` is not permission to retry.
* Real providers must use existing API Client, Secret Broker, Institution Policy,
  Identity and storage interfaces — no new curl, key store, wallet or outbox authority.
* `SocialAdapterProvider~perform` is a transport adapter, not a public entrypoint;
  publication callers must be offered only the strict service facade.
* The current service and journal are single-process development implementations;
  these classes do not close concurrency and crash-consistency gaps in dev4.
* Existing `SocialInteraction` is mutable. Live inbound adapters must retain
  authenticated immutable envelope evidence and enforce evidence-to-interaction
  binding. No such platform verifier is included in dev6.
* The SPI is explicitly not yet a production provider implementation.

## Test inventory

`tests/adapter_contract.rex` covers duplicate registration, deny-by-default
scoped capability discovery, simulated dispatch through the existing service,
request replay, per-surface isolation, independent institutional permission,
inbound verification denial, and reconciliation proof denial.

The remaining dev1–dev5 tests are unmodified and run through `tests/run_all.sh`.

## Production adoption gates

A provider integration is qualified only after independent live evidence proves
credential handling, account binding, capability freshness, signature validation,
rate-limit/retry semantics, idempotent status reconciliation, expiry/revocation,
and removal/update of vendor content. There is no implicit advertising spend,
marketplace order execution or outbound direct-message permission.
