# Current production binding targets — 2026-10-29

PRE25 reviews current platform contracts without claiming live ED209Z production bindings.

- ConnectSelector dev8: `oorexx_connect_selector_v0.1-dev8.zip`, SHA-256 `1cc89a61f2b8f4f4e4ee0b32480ce1b149658bb89a67522d466db8dfb4a296fc`.
- RPC Portfolio dev1: SHA-256 `c07d87ebfdaf988ad9a4c2a4e52a8927da29b4e40365fbc7bd0fd544fa7a66fc`.
- SerializationSelector v0.5: SHA-256 `410c152e2771d55ce567cb79d76ca48e49190c39fa580767252d5d9d5a5ada37`.
- LDAP Identity dev22: `oorexx_ldap_identity_v0.1-dev22.zip`, SHA-256 `697c301c37ad1d77252a34db9028420c4c9a3e3dbe5c60de9be6fc91940341fc`.
- HTTPS Server v0.4.8: `oorexx_https_server_v0.4.8.zip`, SHA-256 `d38ddd049e5d8f5683e4ebf09e09a870c9c562bd3663db32950df711f7040fbe`.
- Instrumentation Mesh dev8 remains the telemetry baseline; Logging v0.7 remains qualification/audit evidence.
- NoSQLServer v0.91 remains a development candidate; IMAP last reviewed line remains dev12; SMTP Secure Stack reviewed target remains dev11.

ConnectSelector dev8 remote RPC/QUEUE/RTO2 admission requires independent platform route authority. PRE25 implements a fail-closed composition: authenticated LDAP dev22 session + endpoint-security attestation + exact IdentityDirectory ACL. Guest fields, source addresses and intention metadata never grant identity/authority.

HTTPS v0.4.8 TLS projections are transport evidence only. PRE25 requires trusted platform composition to assert `mas.private_ca_verified`; it does not infer private-CA authentication from protocol/cipher presence.

PRE24 independently passed static and package-owned host gateway tests under r13196. PRE25 route-authority runtime and ED209Z live execution remain NOT_RUN until rerun.
