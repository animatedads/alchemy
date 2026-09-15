# Alchemy: a large open ooRexx toolkit estate

**Alchemy is a public collection of reusable Open Object Rexx (ooRexx) libraries, runtimes, services, infrastructure components, experiments and complete worked applications.**

This repository is deliberately broader than a single framework. It is the home for a substantial body of ooRexx work covering the kinds of problems that normally force developers to leave Rexx, glue together unrelated tools, or start again in another language.

The aim is practical: make modern systems work available as inspectable, composable ooRexx components, while keeping authority, provenance, dependencies and runtime boundaries explicit.

## What is in here?

The estate spans a wide range of problem domains, including:

- **queues, scheduling and distributed work** — Queue Fabric, QueueRexx, job-to-node placement, workload units, managed-node profiles and migration-oriented components;
- **storage and movement of data** — Storage Fabric, resumable/range transfer, storage evacuation, durable checkpoint movement and provider adapters;
- **AI and LLM integration** — provider adapters, model routing, tool brokers/orchestration, managed endpoints, API access, LLM Gopher and safety/authority boundaries;
- **web, UI and interaction** — Wire UI server/builder/Swing/JavaScript components, virtual browser tooling, structured interaction and observation layers;
- **security, identity and governance** — cryptography, access permissions, secret brokering, institutional policy, legal/security effects, qualification and authority services;
- **databases and data systems** — database skeletons, native backends, NoSQL, SQL shims, journalling and semantic source-control components;
- **maths, ML, signal and media analysis** — maths libraries, ML/graph tooling, camera behaviour, layered audio, motion analysis and visualisation demonstrations;
- **enterprise and domain modelling** — accounting, relationship/case/CRM, brand interaction/journey/intervention, reputation and evidence-oriented components;
- **systems and emulation** — foreign-runtime integration, runtime registry/reference, Unix sockets, HTTPS/MCP, terminal machinery and mainframe/minicomputer emulation work;
- **complete applications and integration examples** — banking, markets, insurance, airline, UI, queue and recovery examples which exercise the component estate together;
- **LLM Gopher knowledge spheres** — curated implementation/standards/continuity knowledge kept separately from executable source.

This is not intended to be a giant flattened source dump. Each component remains a first-class project tree with its own source, tests, documentation, examples, schemas and provenance.

## Repository structure

| Path | Purpose |
| --- | --- |
| `packages/` | Reusable libraries, runtimes, services and tools |
| `examples/` | Complete applications, demonstrations and integration examples |
| `spheres/` | LLM Gopher knowledge/documentation spheres |
| `docs/` | Repository-level architecture, publication and historical material |
| `autobuild/` | Alchemy managed build/test evidence, artifacts and receipts |
| `tools/` | Repository publication/build tooling |
| `mesh/` | Alchemy control/coordination material |
| `CATALOG.md` | Human-readable index of the current published estate |

Alchemy's existing managed-autobuild machinery remains in place. `GIT_SUBMISSION.md` and `MANAGED_ZIP.md` document the managed integration protocol for components that use it.

## Dependency rule: do not smuggle another project into a source tree

A distribution ZIP may contain a `deps/`, `vendor/`, `third_party/`, `third-party/` or `externals/` directory so that a particular delivery can run in isolation. **That does not make those dependency sources part of the component.**

For the GitHub source publication:

1. project-owned source, tests, docs, schemas, fixtures and examples are published normally;
2. embedded dependency payloads are omitted from that project's source tree;
3. the dependency directory is replaced with a small provenance note describing what was omitted;
4. the dependency should be consumed from its own first-class Alchemy tree or its upstream project.

This avoids stale duplicate source, accidental forks, ambiguous licensing, and the misleading impression that one component owns another component's code. See `docs/publication/DEPENDENCY_POLICY.md`.

## Source versus runtime state

The same rule applies to generated/runtime state. Queue roots, caches, logs, build debris, machine-local state and secrets are not source merely because they were present in a delivery archive. Publication keeps the material required to understand, build, test and use the project; transient machine state stays out of the source tree.

## Where should I start?

If you are looking for a particular capability, start with `CATALOG.md` and then the component's own README/tests.

A few useful families to explore are:

- QueueRexx / Queue Fabric / Job-to-Node for distributed work and placement;
- Storage Fabric for durable data movement and resumable storage operations;
- API Client / Virtual Browser / HTTPS / MCP for external systems and service integration;
- Wire UI for user-facing applications;
- Crypto / Access Permissions / Secret Broker / Institutional Policy for authority and security boundaries;
- ooRexx ML / Maths / Graph for analytical work;
- the mainframe, terminal and runtime components for systems work;
- the worked applications under `examples/` to see larger compositions rather than isolated classes.

For shell-oriented queue orchestration, see the companion **[BashQueues](https://github.com/animatedads/bashqueues)** project. BashQueues has first-class ooRexx frontage but remains its own repository because it is a substantial Bash-based platform in its own right.

## Publication provenance

The September 2026 estate publication is built from the supplied current API/component bundle, Gopher sphere bundle, and separately supplied current component deliveries. The publication manifest records source archive names and SHA-256 values so that a Git tree can be traced back to the exact delivery it came from.

Historical root documentation has been retained under `docs/history/` rather than discarded during the repository clean-up.

## Project status

Alchemy contains components at different maturity levels: experiments, development candidates, qualified components and larger worked systems. A directory being public does not by itself mean that every component is production-certified. Read the component's own qualification, compatibility, safety and dependency documentation.

## Why ooRexx?

ooRexx remains unusually good at readable automation, object-oriented scripting, systems integration and long-lived operational code. Alchemy is an attempt to give it a much larger modern component estate: not a toy showcase, but enough real machinery that substantial applications can stay in Rexx when Rexx is the right tool.
