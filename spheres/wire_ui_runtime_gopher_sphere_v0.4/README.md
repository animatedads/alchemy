# Wire UI Runtime Gopher Sphere v0.4

Authoritative continuity sphere for Wire UI runtime/access-point architecture, logical Comms, Queue Fabric gateway semantics, exact ResourceRef consumption and cross-renderer agreement across Web, Swing, GTK/Direct Linux and Android.

v0.4 preserves the measured renderer state from v0.3 and incorporates two delivered programme changes:

- the complete 134-file Direct Linux dev41 archive is now on Git `main` at `b6c08fffd2ed55be434c6524b50e579f63f9c7eb`, removing the source-lineage blocker for its next semantic increment;
- Rasen Falcon v0.4.5 is on `main` at `ff9643b8418b971452c457e23c468d0c55e82939` with a verified 16-file public-role source slice.

Rasen Falcon readiness is now split correctly. Public `rasenfalcon.com` does **not** depend on LDAP or private mTLS, but still lacks accepted production content plus owned HTTPS service/runtime/live TLS and install/run evidence. Private NOC/Office does require dedicated owned HTTPS, device mTLS and LDAP/Access Permissions; LDAP dev23 is currently open PR #71 and not merged, installed or live-qualified.

Renderer state remains fail-closed: Swing dev12 is 8/10 shared gates, Direct Linux dev41 is 3/10, Web and Android still need real canonical adapters.
