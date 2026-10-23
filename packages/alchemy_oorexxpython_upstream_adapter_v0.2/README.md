# Alchemy / upstream ooRexxPython adapter v0.2

Adapter-only integration with https://github.com/JosepMariaBlasco/oorexxpython (Apache-2.0). Native bridge belongs upstream, not in Alchemy. Reviewed against the user-provided 2026-10-16 source archive.

Rexx `.py~import`, `.py~eval`, `.py~exec`, `.py~kw`, `.py~box`, `.py~type` are used through the upstream `python.cls` public surface. Python `oorexx.Interpreter` is used as a context manager with `eval` and `routine`.

Run `python3 tests/contract_static.py` for the static gate and `tests/run.sh` on a host with the upstream bridge installed. No native runtime PASS is claimed here. Upstream requires ooRexx 5.3.0 r13265+ for cross-thread execution.

No native fork, shared Alchemy Objects identity adapter, ConnectSelector, RPC, or Queue Fabric implementation is included. See UPSTREAM_ADOPTION.md.
