# XTP / Queue Fabric current-head reconciliation

**Date:** 2026-10-16. **Status:** source inspection and local regression evidence; no Queue Fabric integration or ED209 fabric deployment claimed.

## Source identity

| Exact Library archive | SHA-256 |
|---|---|
| `oorexx_xtp_v0.1-dev24.zip` | `9599ee6fc2d8a0fb2df5285ca28c199af7782e07eb44c422690325ee7315d331` |
| `oorexx_xtp_v0.1-dev23.zip` | `defd8f9aa4088079bb40bec4d87dfa41464913923175ce3f4946ce6f2a5c77c2` |
| `oorexx_operational_degradation_planner_v0.1-dev3.zip` | `5249c30611edf1e3606a54f74d6ce703ad8e77abc6f25b586a877ec8d67fc35d` |
| `oorexx_service_descriptors_v0.1-dev2.zip` | `ed4900b1fbe06bd73616530deea4553e056d6aa509be933e8d88bcfda8e30490` |
| `oorexx_memory_fabric_xtp_candidate1.zip` | `236f813439da72265fd1183204425ed738a9a350caa67a33d69efbfe6edf3ce3` |

## Version delta observed

- XTP dev23 introduces per-context capacity-cap mapping from Operational Degradation Planner dev2; `MAX_PARALLEL_CONTEXTS` and `AGGREGATE_CAP_PERCENT` are explicitly left to coordinating fabrics and admission authorities rather than being falsely represented as XTP-global accounting. **Review finding:** the native `operational_delay_for_bytes()` helper exists and is unit-tested, but no invocation of it was found on a real XTP send path; the named-service `XtpOperationalSocket~send` checks disposition/fallback/SORT but does not enforce the new per-context cap. Treat runtime cap enforcement as NOT YET PROVEN.
- XTP dev24 repairs native ooRexx service routine registration, misleading-indentation under `-Werror`, named-service listener access to planner and operating state, and test script permission handling. Its Makefile now points to Planner dev3.
- Service Descriptors dev2 binds canonical name -> registered operational class -> service point/logical peer, with IP/network addresses confined to XTP ROUTE administration.
- Operational Degradation Planner dev3 uses `disposition:rate:fallback:protected:per_context_cap:max_parallel_contexts:aggregate_cap` and remains independent of XTP.
- Memory Fabric XTP candidate1 presents an admission-aware, epoch-fenced, multi-source transfer *plan*, not a production remote memory transfer. It targets XTP dev23 and Planner dev2 and must be reconciled with dev24/dev3 before promotion.
- SSH-over-XTP candidates in the Library embed or target older dev22 baseline; requalification against dev24/dev3 must be separately performed.

## Local test evidence generated in this review

All tests executed against extracted Library source; ooRexx binary and SDK were taken from the previously supplied **r13196** Debian package extracted into a temporary working directory; no host package installation. Tests are local; neither raw36/L2 cloud path nor Queue Fabric channel behavior is tested.

| Test | Result | Evidence |
|---|---|---|
| Planner dev3 clean `make test` (`-Werror`) | PASS | `logs/planner_dev3.log` |
| Planner dev3 capacity scopes (separate `test_capacity.cpp`) | PASS | `logs/planner_capacity.log` |
| Service Descriptors dev2 static contract | PASS | `logs/descriptors_dev2.log` |
| XTP dev24 clean `make test-service`, compiling native `.so` under `-Werror` | PASS | `logs/xtp_dev24.log` |
| XTP dev24 operational mapping | PASS | `logs/xtp_operational.log` |
| XTP dev24 MULTI UDP-loopback quorum/replay/reassembly/NOERR | PASS | `logs/xtp_multicast.log` |
| XTP dev24 native two-process ooRexx FIRST named-service send/receive | PASS | On-demand local run, external routine integration |

**Coverage warning:** `make test-service` includes a static ooRexx registration check but does not itself run the independent native two-process ooRexx test; the latter was run separately using the prior regression fixture with dev24. Planner dev3 `make test` does not invoke the separate capacity test by default.

## Queue Fabric integration decision

1. **Preserve existing Queue Fabric ownership:** authenticated manager/channel permissions, queue/topic identity, durable journal and transfer receipts, retry, UOW atomicity, recovery and receiver idempotency remain above XTP. Do not imply distributed XA or exactly-once network delivery.
2. **Keep regular socket providers:** TCP/TLS and other approved transports remain first-class. ConnectSelector chooses invocation/transport route where applicable and SocketSelector provides the socket family; only libxtp chooses among XTP L2, raw36 and UDP physical carriers.
3. **Discover by service, not IP:** register named Queue Fabric channel and topic services via Service Descriptors; bind service identity to a logical route peer and a locally authoritative operational class. The FIRST service-name segment is an admission/discovery address, not a credential. Receiver still authenticates peer and channel.
4. **Make multicast capability-driven:** do not equate multicast packet ACK/quorum with a durable Queue Fabric publication commit. Maintain stable publication/transfer identities and per-recipient durable application receipts, repair missing destinations, preserve subscriber UOW/retained-state atomics. No unqualified multicast fallback for reliable topics.
5. **Do not invent name-to-multicast semantics:** the present `XtpNamedServiceAddress~multicast` returns `.false`; explicit XTP multicast remains a distinct route/membership capability, requiring a real binding to Queue Fabric interest groups.
6. **Honor admission budgets:** XTP has a per-context pacing calculation helper, but actual pacing is not yet proven in the named-service send path; Queue Fabric/WLU must coordinate maximum parallel channels and aggregate class budget. Do not map Queue Fabric message priority to registered operational class by caller assertion.
7. **Safe fallback:** transport degradation cannot silently weaken confidentiality, peer authentication, protected-route requirements or durable semantics. Network carrier failover within XTP and choice of ordinary TCP provider are distinct decisions.

## Remaining acceptance gates

- Wire and test per-context pacing on the actual XTP sender, including THROTTLE rate 0 (a rate-zero policy cannot be interpreted as unrestricted transmission), before claiming enforced bandwidth caps.
- Qualify the exact Queue Fabric transport-adapter boundary against current Queue Fabric source, without replacing the encrypted TCP transport.
- Demonstrate named-service sender/listener registration, ingress admission, peer authentication and durable envelope transfer over XTP in two actual processes.
- Validate service multicast interest registration/membership, explicit receiver population, duplicate suppression, application durable receipts and late-join replay.
- Exercise emergency/degraded policy and budget contention across multiple queue channels and remote peers.
- Reconcile Memory Fabric XTP candidate1 and SSH-over-XTP candidate3 against dev24/dev3; do not treat their earlier package-local results as current-head deployment acceptance.
- Test L2/raw36/UDP on actual ED209 routes with measured failure/return and explicit policy-approved carriers.