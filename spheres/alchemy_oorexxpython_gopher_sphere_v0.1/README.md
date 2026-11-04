# Alchemy ooRexxPython integration sphere v0.1

Authority: upstream https://github.com/JosepMariaBlasco/oorexxpython, Alchemy PR #22 merged as 7c67dff918e58cb2f26924142952560647eb26f6. Source adapter: packages/alchemy_oorexxpython_upstream_adapter_v0.2.

## Ownership
- Upstream owns native ooRexx/Python interpreter lifecycle, GIL, handles, identity and callback/thread attachment.
- Alchemy owns adapter, virtual-class semantic projection, service integration and ConnectSelector selection.
- Historical Macrospace v0.31.x is qualification evidence, not active native production source.

## Current qualification
- Source adapter and smoke tests published and merged.
- Native runtime qualification **not established**; autobuilder OFF.
- Upstream thread-capable ooRexx 5.3.0 r13265+ required per reviewed upstream documentation.
- No claim of deployed website, mail, XTP, LDAP or HTTPS changes from this sphere.

## Admission gates
1. Inspect exact upstream revision and installed ooRexx version.
2. Run tests/contract_static.py then tests/run.sh in clean Rexx-first and Python-first processes.
3. Qualify binary extension imports without LD_PRELOAD, identity/lifetime and callbacks, including nested worker threads.
4. Qualify four resident speech providers across four ooRexx activities, preserving the scalar/file-artifact provider boundary.
5. Only after evidence, map Alchemy Objects virtual-class semantics; keep transport-neutral service boundary and optional ConnectSelector.

## Coordination
Rasen Falcon component: alchemy-oorexxpython. Request REQ-00002069 to CLAUDE on 2026-10-29. Autobuilder is not running. This sphere is an integration/status contract, not an executable native bridge.
