# Wire UI Renderer Conformance v0.4

Executable semantic-conformance kit for Web, Swing, GTK/Direct Linux and Android.

v0.4 keeps the v0.3 real renderer measurements and corrects the Rasen Falcon runtime model after the 29 October delivery moved again.

## Renderer evidence

- Swing `wire_ui_swing_v0.2-dev12.zip`: 61/61 renderer tests PASS; 8/10 shared semantic gates.
- GTK/Direct Linux `wire_direct_linux_v0.1-dev41.zip`: native/static evidence PASS where dependencies exist; 3/10 shared gates. The exact 134-file dev41 archive is now synchronized to Git `main` at `b6c08fffd2ed55be434c6524b50e579f63f9c7eb`, with no semantic edits.
- Web and Android still need real canonical adapters.

## Rasen Falcon surface readiness

The readiness evidence now separates the **public apex** from **private NOC/Office**.

Public `rasenfalcon.com` uses Rasen Falcon delivery v0.4.5 on Git main (`ff9643b8418b971452c457e23c468d0c55e82939`). Its deterministic 16-file public-role source slice and manifest are real, but it remains NOT_READY because approved production content, owned HTTPS service/unit closure, exact HTTPS v0.4.8 runtime/live TLS, host installation and running state are not proved. LDAP is deliberately **not** a public-apex prerequisite.

Private NOC/Office remains NOT_READY and does require dedicated owned HTTPS, private CA/device mTLS plus LDAP identity/Access Permissions. LDAP dev23 is an **open** PR #71 (`725502de...`), not merged, installed or live-qualified. Private admission requires an active attributed LDAP principal plus explicit `HTTPS_LOGIN`, with no fallback identity store.

Wire Application Deployment candidate3 retains durable Queue Fabric ingress evidence but does not prove a live browser HTTPS/WSS semantic roundtrip.

Run:

```sh
python3 -m unittest discover -s tests -v
```
