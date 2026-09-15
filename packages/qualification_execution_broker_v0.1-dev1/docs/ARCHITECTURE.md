# Architecture

The Qualification Execution Broker separates four principals: requester (LLM), human approver, verifier/execution node, and qualification worker. Authentication identifies the requester; catalogue/policy preflight decides runnability; the local human key authorizes one frozen transaction; the worker alone starts execution after revalidation.

The public-key registry is intentionally safe to distribute. A detached signature can also traverse MCP because it is evidence, not signing authority.

Preflight is machine effort without execution authority. The broker resolves catalog identities and validates signed/checked/deployed artifact status, authorised data availability, runtime availability, constructible sandbox policy, nonempty qualified test plan, eligible target and bounded runtime/WLU before `RUN_INTENT_FROZEN` is emitted.
