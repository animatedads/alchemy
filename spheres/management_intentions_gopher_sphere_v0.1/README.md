# Management Intentions LLM Gopher sphere v0.1

Authoritative continuity/documentation sphere for the Management Intention Discovery workstream. It is separate from executable Management, Network Transport, Instrumentation, MVS, Compute and cloud/provider packages.

The core doctrine is: do not teach the top-level management system every domain. Discover the authoritative objects in scope, ask those objects/services which specialist intention surfaces currently exist, preserve native object identity and provenance, and compose multiple specialists when the request crosses boundaries.

The sphere records the executable path through Management Intention Discovery v0.1-dev8 and Instrumentation Intentions v0.1-dev1, while also recording later Library supersessions such as Network Transport Intentions dev3, Instrumentation Mesh dev8, Socket Provider dev16 and XTP dev19 as newer dependent context rather than rewriting the original qualification baseline.

Start with:

    gopher --profile management-intentions context management-intentions --full
    gopher --profile management-intentions open arch.management-intentions.discovery
    gopher --profile management-intentions open arch.management-intentions.authority
    gopher --profile management-intentions open arch.management-intentions.cloud-control
    gopher --profile management-intentions open arch.management-intentions.instrumentation
    gopher --profile management-intentions open ops.management-intentions.continue

Executable grounding added by this workstream:

    oorexx_management_intention_discovery_v0.1-dev9
    oorexx_instrumentation_intentions_v0.1-dev2

Important non-architectural tools remain exactly that: historical provider-native `cloudctl.sh` and `sshnode.sh` shortcuts are constrained operator/developer transports and must not become capability truth, routing authority or Management semantics. The first-class authority is the Alchemy Cloud Control contract described below.

## Cloud control continuity — dev4

`alchemy.cloud-control/0.1` / `ALCHEMY_CLOUD_CONTROL` remains the cloud RESOURCE/NODE authority. `oorexx_cloud_console_v0.1-dev4` is the consistent human, ooRexx-code and Codex facade above it. Management discovers that specialist dynamically; it does not learn Azure, GCP, AWS, OCI or Vultr command syntax and it does not own cloud credentials.

Cloud Control v0.1-dev4 adds generic firewall source-set reconciliation: for one scoped ingress protocol/port rule, replace the source CIDR set with the exact caller-supplied set while preserving unrelated rules. Empty desired sets fail closed. XTP/network authorities continue to decide which peers belong in the set; Cloud Control only performs the bounded infrastructure mutation.

Cloud Console v0.1-dev4 delegates mutation through Cloud Control when configured, retains PLAN/APPLY plus exact destroy confirmation, and keeps provider-native reads separately attributable as observations. A real cross-package regression now exercises Console -> Cloud Control -> provider fixture. The same run found and repaired JSON quote/backslash/newline escaping in the ooRexx encoder/parser.

Both dev4 packages are qualified locally from fresh extraction. Cloud Console was compiled and run under exact ooRexx 5.3.0 r13196 (DEB SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`). Cloud Control's five-provider fixture suite and the Console integration suite pass. No live cloud mutation was performed, so this does not claim installed website/mail/LDAP/HTTPS services or production cutover.

This infrastructure primitive is intended for the existing deployment, mail, LDAP, HTTPS and internode-network owners to consume during commissioning; those service implementations and their production activation remain in their owning lanes.

## MVS specialist continuity

The MVS specialist is now grounded by `mvs_intention_runner_v0.1-dev9` (SHA-256 `03a2cc798db5cff171cd7ca37eb5ca686d9f7bfce17cd381c85c77a703fbec52`). dev9 consumes Terminal Machine as terminal/session authority, keeps s3270/c3270 as independent reference evidence, and preserves MVS Alchemy/JES as owner of guest/job/dataset semantics. It was locally qualified under ooRexx 5.3.0 r13196 and against Terminal Machine v0.22-candidate8's focused 3270 suites. Terminal Machine v0.22-candidate12 is now current GitHub context, so candidate12 requalification remains a gate.

ED209Z and ED209ZZ are distinct scopes: ED209Z is hosted by ED209C and ED209ZZ by ED209I. MVS batch outcomes are asynchronous semantic objects: JES acceptance, step return codes and spool/printer artifacts are evidence; submission or a host-side process return alone is not success.


## 2026-10-27 Mesh dev8 read-side completion

Instrumentation Intentions dev2 now consumes Mesh dev8 events, explicit correlation/causation/context, observed relationships and publication freshness. Management dev9 discovers those facts transiently and remains domain-blind and non-mutating.
