# ooRexx AI Model Router v0.1

Provider-neutral, non-entitling cross-provider route selection built on the authenticated route analytics/advisory and institutional-policy decision surfaces in Work Load Units v0.12.

The router deliberately does **not** select provider-specific models from raw provider catalogs. Grok/Anthropic/OpenAI-family packages may perform their own provider-local capability selection first. Deployment code registers the resulting executable routes with stable route IDs, model/provider metadata, Runtime Registry coordinates and WLU expected/ceiling values. Cross-provider selection then operates on those declarations.

## Authority boundary

`AIModelRouter` accepts no provider transport, credential, Secret Broker, Runtime Registry session/registry/router, WLU Authority, job manager, hierarchy manager or reservation object.

WLU receives only `WLUJobStage` values containing stable route IDs, WLU scopes and expected/ceiling work. It does not receive provider model IDs, Runtime Registry environment/client/ability coordinates, credentials or request contents.

A successful `AIModelRoutePlan` is **not admission and not execution authority**. It retains the deployment coordinates required by a trusted consumer to attempt a later Runtime Registry acquisition, together with authenticated WLU advisory evidence and the operative institutional-policy decision evidence. Ordinary Runtime Registry and WLU admission still occur later.

## Selection sequence

1. Filter the deployment catalog by explicit provider-neutral constraints such as required tags, sovereignty zone, batch allowance and optional provider allowlist.
2. Project eligible routes to `WLUJobStage` values.
3. Ask `WLUJobRouteAdvisor` to evaluate those candidates against a verified route-evidence source and explicit statistical policy.
4. Refuse to invent a default if no route clears the evidence threshold.
5. Submit the authenticated recommendation to `WLUJobRouteDecisionGate` under the operative institutional route policy.
6. Return a detached route plan only when that fixed policy permits the route.

The WLU advisory is evidence, not authority. The institutional decision is permission for the external scheduler to *attempt* the selected route, not workload admission.

## Dependencies

- Alchemy Objects v0.8
- Work Load Units v0.12
- Institutional Policy v0.6 (compatible shared `InstitutionalPolicy.cls` lifecycle used by WLU v0.12)
- ooRexx Crypto v0.1 (through WLU proof verification)

No AI provider package is required.

## Qualification

The acceptance suite creates authenticated historical route evidence for multiple candidate backends and proves:

- stronger conservative success evidence can beat a cheaper route;
- the WLU advisory sees no Runtime Registry deployment coordinates;
- an automated `RECOMMENDED_ONLY` institutional policy permits only the authenticated recommendation;
- a `DENY` policy prevents automatic routing despite eligible evidence;
- insufficient statistical evidence produces no route instead of a silent default;
- provider/tag constraints are applied before advisory;
- the returned plan has no Runtime acquisition, WLU reservation, Secret Broker or provider execution method;
- Alchemy Objects v0.8 STANDARD adoption is warning-free.
