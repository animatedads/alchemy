# Alchemy ooRexx Estate Catalogue

The September 2026 publication inventory contains **195 first-class component trees** prepared from the supplied current deliveries:

- **93 reusable packages, runtimes, services and tools**;
- **46 complete applications and integration examples**;
- **56 LLM Gopher knowledge/documentation spheres**.

Twelve supplied component archives contain embedded dependency payloads. In the clean publication tree those dependency payloads are not vendored; they are replaced by provenance notes as described in `docs/publication/DEPENDENCY_POLICY.md`.

## Major package families

### Runtime, queues, placement and distributed work

QueueRexx, Queue Fabric, Queue Fabric Web Gateway, Job-to-Node Allocator (including the network authority extension), Work Load Units, Runtime Reference, Runtime Registry, Managed Node Host Profile, Deployment, Colab/HuggingFace job components, Qualification Execution Broker and journalling/live-patch components.

### Storage, data movement and durable state

Storage Fabric, Storage Evacuation, lazy read-only file access, semantic source control, journal pointed state and the storage/migration seams used by long-running jobs.

### AI, LLM and external-system access

API Client, AI Access, model router, tool broker/orchestrator, provider adapters (OpenAI-compatible, Anthropic and Grok among the current bundle), managed HuggingFace endpoints, LLM Gopher, LLM Gopher Web, HTTPS Server, MCP service, Virtual Browser and Secret Broker.

### UI and application interaction

Wire UI Server, Wire UI Builder, Wire UI Swing, Alchemy Wire UI JavaScript, Observation and the structured interaction/event components used by larger applications.

### Security, authority, legal and governance

Crypto, Access Permissions, Institutional Policy, Security Effect, Legal Effect, Secret Broker, qualification components and related authority/evidence contracts.

### Database and data systems

Database Skeleton, Native Database Backends, NoSQLServer, MSQL shim, Foreign Database Native Certification, Accounting Core and related persistent-state components.

### Maths, ML, audio, video and signal work

ooRexx Maths, ooRexx ML, ML Graph, the cryptography-failure visualisation demo, Camera Behaviour, Layered Audio, FD Door Micro Motion, FC Camera Events and Audio V9 locator components.

### Systems, terminals and emulation

Foreign Runtime, Unix Socket, Terminal Machine, KL10 emulator/IPL work, IBM 4361 work, portability tooling and runtime integration components.

### Enterprise/domain component stacks

Relationship Case/CRM, reputation, accounting, brand interaction/journey/intervention and reusable service/effect components used by the larger worked systems.

## Worked applications and integration examples

The current example estate includes FederationBank services and applications, Vector Meridian Markets, All Japan Insurance, Flylo, Our Lady Air Shannon, Psychic Poker, regulated intermediary distribution, Wire UI examples, journalling/live-patch demonstrations and other multi-component compositions.

These are intentionally kept under `examples/` rather than being mistaken for reusable libraries.

## Knowledge spheres

The 56 `spheres/` trees cover implementation and continuity knowledge for major Alchemy components as well as standards/manual navigation and language best-practice material. Current subjects include Queue Fabric/transport, Job-to-Node, Storage Fabric, Work Load Units, runtime registry, MCP/HTTPS, Wire UI, access permissions, accounting, security effects, semantic source control, Unix sockets, terminal/TN5250 standards, S/370 MVS, KL10, maths/ML/graph, layered audio, browser/API access, database backends, manual navigation, ooRexx/Python/Java/Bash material and sphere authoring itself.

## Current separately supplied components included in the publication plan

- `queuerexx_v0.1-dev12` — sealed QueueRexx head supplied for this publication;
- `job_node_allocator_v0.6-network1` — Job-to-Node network authority extension;
- `oorexx_storage_evacuation_v0.1-dev2` — storage evacuation coordinator (Storage Fabric vendor copy omitted from its source tree);
- `fd_door_micro_motion_v0.2-dev5` — door/camera micro-motion analysis package;
- `oorexx_llm_pa_v0.1-dev9-candidate1` — LLM Personal Assistant candidate (large `deps/` payload omitted from its source tree and represented by provenance instead).

## Source provenance

The publication was prepared from these supplied archive snapshots:

| Source | SHA-256 |
| --- | --- |
| `oorexxapis(20260915-080909).zip` | `8fd06ee75eeb8726327c19157e5f929cd08f64aa512e20c4449ffe7fb928c404` |
| `sphere(20260915-080907).zip` | `a586d09799437a35432861e5b0548de1ec6e273abc689ac013b50fd8f7165245` |
| `queuerexx_v0.1-dev12(2)(5).zip` | `e18888a29175d77663c14f37b578d647306b52d0a28d205ee069bd100bb41032` |
| `job_node_allocator_v0.6-network1(4).zip` | `e6ea65304f51e16ee336a27783d185b09cdfff7117b4abe8ed8afabe2cb03b1f` |
| `oorexx_storage_evacuation_v0.1-dev2(1).zip` | `85893b96976202b31cefd7f3c355a1f9b8fead93f64b2e2058b6655651cbfd53` |
| `fd_door_micro_motion_v0.2-dev5(1).zip` | `07eae9e67cc7aa104961f8774ebd925d235d58aaba095610ca6f3a3b4a764740` |
| `oorexx_llm_pa_v0.1-dev9-candidate1(1).zip` | `30297f69ec0df690621e72f91da82a22f85cf05624544a432e2f974f6d7cb555` |

The companion BashQueues source is published in its own repository: <https://github.com/animatedads/bashqueues>.
