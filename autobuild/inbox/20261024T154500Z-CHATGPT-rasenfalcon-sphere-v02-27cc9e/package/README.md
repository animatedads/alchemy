# RasenFalcon Gopher engineering sphere v0.2

This is an LLM Gopher **documentation and qualification sphere**, not an executable HTTPS, mail, CMS or RexxOS replacement.

The editable nine-page public website preview is built; its 69-file v0.4 source candidate was submitted to [GitHub Autobuild](https://github.com/animatedads/alchemy/tree/autobuild-submit/20261023T150929Z-CHATGPT-rasenfalcon-delivery-v04-538a2e). As of 23 October 2026 **no acceptance receipt or promoted main-branch source was observed**. Live NOC and Office private HTTPS/mTLS, public CMS/Wire publication, LDAP, mail, gateway and MCP qualification remain **NOT_RUN / NOT_QUALIFIED**.

## Binding engineering doctrine
- Public `rasenfalcon.com` is isolated from private NOC/Office.
- `noc.rasenfalcon.com` and `office.rasenfalcon.com` have **different native ooRexx HTTPS instances**, separate processes, credentials and **privately issued server leaf certificates**, with mandatory **per-device client mTLS**.
- Only explicitly trusted operator devices receive the private CA trust anchor and their own client identities. Nothing may fall back to HTTP, public-CA/ACME, anonymous TLS, password-only access, an inherited default vhost or a reverse proxy bypass.
- Gateway targets are `ed209zz`, `ed209z` (3270), `ed209cray` and `ed209tops` (web).
- BashQueues cron owns application scheduling; systemd may wake its minute ticker and supervise services.
- Removing a service withdraws routes, listeners and authority, not just files. RexxOS isolation must be enforced.

After installing/loading with LLM Gopher:
```
gopher --profile rasenfalcon context rasenfalcon --full
gopher --profile rasenfalcon search 'no fallback' --sphere rasenfalcon
```

Source: `fb4ce5bdecf0c9c312e21459f5ea74dc7d0eeb73fa37682cada06a5835028189` (combined v0.4); handoff: `60bf049a436c9f653b60cbf315331a85872ab4f6724f7ef685fec322de96bc5c`; Website Builder: `836c938533a3ac066b9fff3072b5f6183e773c7a1bbc7a548d35f927f601e886`; HTTPS 0.4.7 **candidate**: `ae1a4caa1f48d6348cdfa283323a25e300bda5c30b7ea5f8ef825c635502ac3c`.

See `packs/rasenfalcon/articles/`, profile and `tests/test_sphere.py` for machine-readable continuity. GitHub issues #6–#14 remain the live coding assignments.

## 24 October 2026 — public website and Website Publisher update

The v0.4 delivery source and independent Website Publisher v0.3 source are present on GitHub `main`, with the existing architecture still governing. The v0.4.1 fail-closed static website correction has been **submitted** to Autobuild and has not been asserted accepted. The newer publisher does not provide a production CMS service: its NoSQLServer v0.90 read/write path is a qualified *development/offline* handoff, not an authorised live publish channel. See `rasenfalcon.website-publication` for actual duties, required evidence and remaining tasks. Production still DENY, public/private authority still separate; prior delivery v0.4 and publisher v0.3 are not proof of deployment.
