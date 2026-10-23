# .NET Alchemy — LLM Gopher sphere v0.1

Status: architecture and upstream-adoption decision recorded; migration not yet runtime-qualified.

## Purpose
Preserve the authority boundaries and migration evidence for ooRexx ↔ .NET Alchemy.

## Authoritative upstream
Josep Maria Blasco's ooRexx/.NET: https://github.com/JosepMariaBlasco/oorexxnet
Pinned observation of upstream main: `1a5db49af0232749c40bbba19839048a5284730c` (2026-10-23).
Upstream calls itself a prototype, despite reporting broad automated test coverage. Do not claim Alchemy production qualification.

## Architecture
Rexx.Net and net.cls are the CLR bridge; Alchemy adapts them. Upstream owns CLR identity, type/reflection, invocation, callbacks, events and lifetime. Alchemy owns its object integration, cooperative interposition, Inspector, Logging, qualification and governance. No stale CLR target or physical wrapper replacement.

## Evidence and next implementation
- Current experimental baseline: `packages/oorexx_dotnet_alchemy_v0.2.15`, branch `tmp-dotnet-alchemy-v0.2.15`.
- Migration decision and acceptance gates: `packages/oorexx_dotnet_alchemy_v0.2.15/docs/UPSTREAM_REXXNET_ADOPTION.md`.
- Preserve accepted v0.2.14 on main until a real upstream-backed Alchemy adapter passes regression.
- Run upstream suites and port Alchemy probes before claiming production readiness.
- Record upstream SHA, licenses, CI results and local runtime results separately.

## Non-goals
No new parallel CLR reflection engine, no independent fork of upstream bridge, no rewriting shared AlchemyObject or Inspector authority.
