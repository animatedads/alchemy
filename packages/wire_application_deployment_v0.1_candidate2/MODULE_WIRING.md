# Existing module splice points (Library baseline, not implicit GitHub changes)

**HTTPS Server v0.5** (`e00f2d497404ed8c3ae842128bf152a0a5551fc36b54e3cb7d85e06fd75e6b02`): Require `HttpsHostedRoutes.cls`. Initialise one `hostedRoutes` with `HttpsServer`. Expose `publishHostedRoute(method,path,owner,generation,target,selector,expected)`, `retireHostedRoute` and `hostedRouteGeneration`. Refuse collisions with existing static routes. In `dispatchRoute`, consult hosted snapshot after static route lookup and include hosted methods in 405 Allow. Only the deployment authority invokes publication.

**Wire UI Server v0.17.1** (`5a20d6da1866cecad9c452915616cb6926d3291c74a82c0dc69252963a96fb33`): Preserve `registerApplication` for non-deployment owners. Add `hostedGeneration(appId)`, `hostedApplication(appId)`, `publishHostedApplication(app,generation,expected)`, `retireHostedApplication(appId,expected)` and `retiredHostedApplication(appId,generation)`. Reject takeover of manually registered apps and changes of accessPointId without drain.

**Web Gateway v0.2** (`83118442d7c734e4a194598b0709311de7a055ae33fb4e094cccf3686b7ffcf8`): Add `WireDeploymentGatewaySlots.cls` around existing `WireUIWebAccessPointBinding`; retain the authoritative ObjectQueueManager; keep bridge token and principal private. The browser sees only the existing safe `browserBootstrap`.

**General Deployment v0.1-dev3** (`796b4375b7abac6e13e5f23f632c8aa75f86fe777f3d7c130ea8e440ff5dbd79`): Add `WireHostedDeploymentCoordinator.cls` and `WireDeploymentQueueIngress.cls`. Compose with existing `HostedModuleDeployment` after independent signed artifact verification and readiness admission. Gateway -> semantic application -> HTTPS publication. Queue command body holds an artifact reference, not unverified source.

This file intentionally does not pretend that future upstream code versions share the same splice offsets. Use the candidate ZIP full replacements for inspected baselines, inspect diffs and rerun acceptance before merge.
