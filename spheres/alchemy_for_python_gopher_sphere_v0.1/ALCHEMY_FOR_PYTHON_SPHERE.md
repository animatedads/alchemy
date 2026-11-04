# Alchemy for Python — engineering sphere v0.1

Owner / Rasen Falcon lane: `alchemy-for-python`. Current source v0.1-dev7 (29 October 2026). GitHub review PR #64 (draft; no merge approval).

## Canonical authority boundaries
- `ConnectSelector` (`oorexx.connect_selector/0.1`, Library dev7): route/policy for DirectCall, RPC, Queue Fabric, RTO2. Python never changes the selection rules, silently retries uncertain outcomes, or treats queue acceptance as completion.
- `RPC Service Core`: published service/method registration, allowlists and callback admission. Python service proxy is not an arbitrary Rexx reflection surface.
- `Serialization Selector`: codec/schema ownership, no replacement Python serializer registry.
- `JSON-RPC Fabric`: JSON-RPC 2.0 envelopes and hex8 TCP framing where published. Raw TCP is loopback-only by default, not an authenticated remote carrier.
- `HTTPS Server` and `LDAP Identity`: owned by their independent platform components. Python dev7 contributes an explicitly configured private-CA TLS client with optional mTLS. Server must bind TLS subject/service authority to LDAP identity and method policy; Python does not perform an LDAP bind or manage the server.
- `Python Macrospace`: independent bidirectional live ooRexx object bridge. Retained identity, re-entry, class inheritance, exceptions, lifetime, authority are not RPC value semantics. Separate upstream oorexxpython/adapter is not a drop-in replacement.

## Delivery and qualification
Dev6 87 Python tests PASS. Dev7 93 tests PASS on Python 3.13 with real test HTTPS handshake, private CA chain rejection, mTLS-required server, no-redirect, malformed credentials/CA. Python wheel install/import and source ZIP integrity verification are part of the release script.

Native `rexx` not available on this worker. Thus live independent Macrospace to ConnectSelector calls, real authenticated HTTPS server, LDAP authorization, production queue delivery/JMS/RTO2 and cross-runtime RPC/gRPC are NOT_RUN. Keep those gates explicit, with executed evidence only.

## Production delivery interface
For Rasen Falcon website, NotNotes/webmail and mail/LDAP projects, the Python SDK's contribution is strict outbound service HTTPS and API client behavior. It does **not** install or configure website, SMTP, IMAP, LDAP or HTTPS servers and must not claim they are running. A secure Python client call is only valid after service names, certificates, published RPC operations, and LDAP identity/authorization are deployed by their respective owners.

## Coordination
Rasen Falcon request `REQ-00000703` (CODEX-PC native acceptance), reply `REQ-00000933` says NOT_RUN due missing exact independent Macrospace/ConnectSelector closure; request `REQ-00000705` and reply `REQ-00000935` address source access. GitHub branch `chatgpt/alchemy-python-dev6` contains complete dev6 source in PR #64; subsequent dev7 source is on the same review branch. Autobuilder is OFF — do not submit jobs claiming it executed.

## Missing acceptance gates
1. Import exact independently qualified Macrospace/ConnectSelector source closure and execute live `RexxObject.send('EXECUTE', ...)` with native typed intent and native Directory options.
2. Execute published RPC over **platform** HTTPS with the platform private CA, server mTLS validation, correct LDAP authorization and route policy; prove unauthorized and revoked client fail closed.
3. Execute DirectCall/JSON-RPC/Queue Fabric distinct semantics and validate uncertain acknowledgements, no silent retries; qualify real JMS and RTO2 separately.
4. Confirm TLS/LDAP/server deployment status independently. No production cutover without approved deployment authority.
