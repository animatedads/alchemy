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

Important non-architectural tools remain exactly that: `cloudctl.sh` and `sshnode.sh` are constrained operator/developer shortcuts and must not become capability truth, routing authority or semantic APIs.

## MVS specialist continuity

The MVS specialist is now grounded by `mvs_intention_runner_v0.1-dev9` (SHA-256 `03a2cc798db5cff171cd7ca37eb5ca686d9f7bfce17cd381c85c77a703fbec52`). dev9 consumes Terminal Machine as terminal/session authority, keeps s3270/c3270 as independent reference evidence, and preserves MVS Alchemy/JES as owner of guest/job/dataset semantics. It was locally qualified under ooRexx 5.3.0 r13196 and against Terminal Machine v0.22-candidate8's focused 3270 suites. Terminal Machine v0.22-candidate12 is now current GitHub context, so candidate12 requalification remains a gate.

ED209Z and ED209ZZ are distinct scopes: ED209Z is hosted by ED209C and ED209ZZ by ED209I. MVS batch outcomes are asynchronous semantic objects: JES acceptance, step return codes and spool/printer artifacts are evidence; submission or a host-side process return alone is not success.


## 2026-10-27 Mesh dev8 read-side completion

Instrumentation Intentions dev2 now consumes Mesh dev8 events, explicit correlation/causation/context, observed relationships and publication freshness. Management dev9 discovers those facts transiently and remains domain-blind and non-mutating.

## 2026-10-29 Cloud Control source landing

`alchemy_cloud_control` dev3 candidate and `oorexx_cloud_console` dev3 candidate are now present on current `main`. Cloud Control owns normalized cloud RESOURCE/NODE operations; Cloud Console owns PLAN/APPLY interaction and exact destructive confirmation. Their current status is source/offline-qualified candidate, not live-cloud acceptance. `cloudctl.sh` remains an adapter/shortcut behind the authority boundary, not Management semantics.
