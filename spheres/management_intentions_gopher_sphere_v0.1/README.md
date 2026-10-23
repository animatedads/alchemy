# Management Intentions LLM Gopher sphere v0.1

Authoritative continuity/documentation sphere for the Management Intention Discovery workstream. It is separate from executable Management, Network Transport, Instrumentation, MVS, Compute and cloud/provider packages.

The core doctrine is: do not teach the top-level management system every domain. Discover the authoritative objects in scope, ask those objects/services which specialist intention surfaces currently exist, preserve native object identity and provenance, and compose multiple specialists when the request crosses boundaries.

The sphere records the executable path through Management Intention Discovery v0.1-dev8 and Instrumentation Intentions v0.1-dev1, while also recording later Library supersessions such as Network Transport Intentions dev3, Instrumentation Mesh dev8, Socket Provider dev16 and XTP dev19 as newer dependent context rather than rewriting the original qualification baseline.

Start with:

    gopher --profile management-intentions context management-intentions --full
    gopher --profile management-intentions open arch.management-intentions.discovery
    gopher --profile management-intentions open arch.management-intentions.authority
    gopher --profile management-intentions open arch.management-intentions.instrumentation
    gopher --profile management-intentions open ops.management-intentions.continue

Executable grounding added by this workstream:

    oorexx_management_intention_discovery_v0.1-dev8
    oorexx_instrumentation_intentions_v0.1-dev1

Important non-architectural tools remain exactly that: `cloudctl.sh` and `sshnode.sh` are constrained operator/developer shortcuts and must not become capability truth, routing authority or semantic APIs.
