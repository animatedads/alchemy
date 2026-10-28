# RasenFalcon Gopher engineering sphere v0.4

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

## 27 October 2026 — offline Publisher candidate import

New Rasen Falcon site candidate `v0.4.2` extends the original website compiler to consume Website Publisher v0.3 candidate export and native record read-back. All nine pages are schema/site checked, normalized to candidate, and staged with SHA-256 lineage for separate review; preview builds are isolated and noindex. Local suite: 18/18 PASS, including v0.3 reference export/preview exercise. Production gate remains DENIED. See `rasenfalcon.website-publication`. New authenticated Rasen Falcon mailbox lane: `rasenfalcon-website`; independent test request REQ-00000481. Source submitted, not accepted or deployed.

## 28 October 2026 — current website source lock

The independent read-only qualification reply REQ-00001007 found 18 website tests passed but one of 13 handoff tests failed on an obsolete `github_source.lock.json` hash. The v0.4.3 candidate reconciles 28 current website sources separately from the original Builder ZIP identity. Local checks now pass 18/18 website and 21/21 handoff, including eight new drift-detection tests. Independent requalification and Autobuild acceptance remain pending; live CMS/Brand/Wire and HTTPS/mTLS deployment remain unqualified. See `rasenfalcon.source-lock`.
