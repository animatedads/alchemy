# ConnectSelector dev8 — authenticated remote route admission

Date: 2026-10-29
Source checkpoint: `oorexx_connect_selector_v0.1-dev8.zip`
ZIP SHA-256: `1cc89a61f2b8f4f4e4ee0b32480ce1b149658bb89a67522d466db8dfb4a296fc` (26 members including a 25-line MANIFEST.sha256).

The new class `src/ConnectAuthenticatedRoutePolicy.cls` and its executable negative test are committed in this directory. The **complete replacement ZIP** includes all dev7 files, this class, the added test and updated package metadata; this GitHub directory is **not yet the complete upstream source import**.

## Invocation contract

ConnectSelector still owns route selection and calls. This new compositional policy checks the exact base `ConnectRoutePolicy` ACL first, then asks an **injected platform authority** `authorizeRoute(intent,provider)` for its own evidence. RPC, QUEUE and RTO2 require affirmative authorization by default, even without an explicit destination mark; local DIRECT can additionally be marked with `requireAuthenticated`. Caller-provided `intent.options` identity booleans are ignored, and authority faults fail closed.

```rexx
route = .ConnectRoutePolicy~new
route~allow('telemetry.internode','REQUEST','RPC','MI.MN1')
secure = .ConnectAuthenticatedRoutePolicy~new(route, trustedAuthority)
selector = .ConnectSelector~new(secure)
```

A real production authority must verify the user's LDAP identity via our own ooRexx LDAP component, the peer's private-CA certificate/HTTPS channel or authenticated XTP named-service identity, and the destination's required role/scope. **This test only uses an injected fake authority, not live LDAP or TLS.** Attestation must be bound to the actual connection and peer, not simply a claim stored in a request. RTO2 runtime still owns epoch/fencing/promotion, QueueFabric owns durability, and SOAP/JSON-RPC/gRPC own their protocol envelopes.

## Qualification

- ooRexx 5.3.0 r13196: all seven production classes compile; full dependency-backed regression passed.
- Real QueueFabric dev6 persistent journal recovery, RPC Service Core dev1, SOAP dev2, JSON-RPC dev3, Instrumentation Mesh dev7; actual RTO2 Grid dev15 membership objects with **simulated invocation port**.
- New test rejects missing/forged authority, enforces base ACL precedence, and fails closed on authority exception; QUEUE and RTO2 also require attestation.
- Strict coding standards 19 scanned / 0 errors / 0 warnings. ZIP integrity and 25 manifest hashes PASS.
- RFE #882 `ADDRESS` remains blocked on r13196 (requires r13289+); no autobuilder used.

## Outstanding deliverables

1. Import all 26 dev8 source/package files to GitHub (dev7→dev8 incremental code and test are now committed).
2. Supply and test a live ooRexx LDAP v22 + private-CA HTTPS/XTP channel identity attestor, with binding to the actual MU/MI peer and named-service route.
3. Run real JMS broker acknowledgements, transaction/recovery and dead-letter qualification.
4. Run authenticated RTO2 runtime invocation, epoch fencing, socket failover/replay campaign.
5. Qualify new `ADDRESS` package-prolog support only on an r13289+ interpreter.

No cutover or installed/running platform service is claimed.
