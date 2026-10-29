# Management Intentions LLM Gopher sphere v0.1

Authoritative continuity/documentation sphere for the Management Intention Discovery workstream. It is separate from executable Management, Network Transport, Instrumentation, MVS, Compute and cloud/provider packages.

The core doctrine is: do not teach the top-level management system every domain. Discover the authoritative objects in scope, ask those objects/services which specialist intention surfaces currently exist, preserve native object identity and provenance, and compose multiple specialists when the request crosses boundaries.

The sphere records the executable path through Management Intention Discovery v0.1-dev8 and Instrumentation Intentions v0.1-dev1, while also recording later Library supersessions such as Network Transport Intentions dev3, Instrumentation Mesh dev8, Socket Provider dev16 and XTP dev19 as newer dependent context rather than rewriting the original qualification baseline.

Start with:

    gopher --profile management-intentions context management-intentions --full
    gopher --profile management-intentions open arch.management-intentions.discovery
    gopher --profile management-intentions open arch.management-intentions.authority
    gopher --profile management-intentions open arch.management-intentions.instrumentation
    gopher --profile management-intentions open arch.management-intentions.cloud-control
    gopher --profile management-intentions open ops.management-intentions.continue

Executable grounding added by this workstream:

    oorexx_management_intention_discovery_v0.1-dev9
    oorexx_instrumentation_intentions_v0.1-dev2

Important non-architectural tools remain exactly that: historical provider-native `cloudctl.sh` and `sshnode.sh` transports are constrained implementation adapters and must not become capability truth, routing authority or Management semantics. The first-class authority is `alchemy.cloud-control/0.1`.

## MVS specialist continuity

The MVS specialist is now grounded by `mvs_intention_runner_v0.1-dev9` (SHA-256 `03a2cc798db5cff171cd7ca37eb5ca686d9f7bfce17cd381c85c77a703fbec52`). dev9 consumes Terminal Machine as terminal/session authority, keeps s3270/c3270 as independent reference evidence, and preserves MVS Alchemy/JES as owner of guest/job/dataset semantics. It was locally qualified under ooRexx 5.3.0 r13196 and against Terminal Machine v0.22-candidate8's focused 3270 suites. Terminal Machine v0.22-candidate12 is now current GitHub context, so candidate12 requalification remains a gate.

ED209Z and ED209ZZ are distinct scopes: ED209Z is hosted by ED209C and ED209ZZ by ED209I. MVS batch outcomes are asynchronous semantic objects: JES acceptance, step return codes and spool/printer artifacts are evidence; submission or a host-side process return alone is not success.


## 2026-10-27 Mesh dev8 read-side completion

Instrumentation Intentions dev2 now consumes Mesh dev8 events, explicit correlation/causation/context, observed relationships and publication freshness. Management dev9 discovers those facts transiently and remains domain-blind and non-mutating.

## 2026-10-29 Cloud Control dev4 qualification

`alchemy_cloud_control_v0.1-dev4` and `oorexx_cloud_console_v0.1-dev4` supersede the dev3 source candidates in this workstream. Cloud Control remains the normalized cloud RESOURCE/NODE authority; Cloud Console remains the consistent human, ooRexx-code and Codex facade with PLAN/APPLY and exact destructive confirmation.

Cloud Control dev4 adds generic firewall source-set reconciliation. For one scoped ingress protocol/port rule it reconciles the source CIDR set to the exact caller-supplied set while preserving unrelated rules. An empty desired set fails closed. XTP/network/service authorities choose the desired set; Cloud Control does not infer topology.

Cloud Console dev4 delegates mutation through Cloud Control when configured while retaining provider-native reads as separately attributable observations. A real cross-package regression exercises Console -> Cloud Control -> provider fixture. That integration test exposed and drove repair of quote/backslash/newline handling in the ooRexx JSON encoder/parser.

Both release ZIPs passed fresh-extraction qualification. Cloud Console compiled and ran under exact ooRexx 5.3.0 r13196 using DEB SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`. No live cloud mutation, DNS/certificate change, host reconfiguration, or website/mail/LDAP/HTTPS installation was performed.

This dev4 primitive is available for the existing deployment, internode-network, mail, LDAP and HTTPS owners to consume when their accepted dependency graph permits it; this lane does not take over those service implementations.
