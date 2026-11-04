# Rasen Falcon — CMS, Brand and Wire publication seam

## Authority mapping

```
Rasen Falcon editorial source (content/pages/*.json)
    -> (candidate resource inputs) CMS Brand Builder / content authority
    -> approval/claim/brand decision gate
    -> Wire UI Resource Editor (exact immutable SHA-512 resource publication)
    -> published WireUIResourceRef with exact resourceId@version/contentAddress
    -> Wire UI Builder v0.12-dev1 (semantic elements, composition and actions)
    -> sealed WireUISiteRelease -> Wire UI Server v0.17.1
    -> Alchemy Wire UI JS v0.4-dev6 (for dynamic interactions)
    -> owned ooRexx HTTPS Server v0.4.7 with qualified vhost/SNI support
```

The **static public pages in this delivery do not claim to be a Wire compiled application**. They are the first publisher output and actual designed site, operated offline by a deterministic CLI. An unverified CMS Brand Builder service or absent resource publication must not be faked as a successful integration.

## What is verified from available packages

- Wire UI Builder v0.12-dev1: `WIRE-UI-DESIGN/0.7`, typed drafts/semantic composition, immutable `WireUISiteRelease` publication; Builder is not a content editor.
- Wire UI Server v0.17.1: `WIRE-UI/0.1` authority and projection.
- Alchemy Wire UI JS v0.4-dev6: semantic browser access point and exact-definition deauthorisation.
- Wire UI Resource Editor v0.3: separate immutable resource and byte ownership, SHA-512 publication.
- ooRexx HTTPS Server v0.4.7: exact GET routes; no multi-SNI/virtual-host qualification in available package. The existing Rasen Falcon task plan tracks this as RF-008/RF-010.
- CMS Brand Builder: named in the 15 October 2026 Alchemy Communications commercial proposal, but a stand-alone accepted executable package or runtime service interface was **not** verified in the material inspected. This is a required dependency discovery/implementation gate, not a licence to invent an API.

## Machine-operable development workflow

- `python3 tools/site.py status` — inspect page status and current SHA-256 draft digests.
- `python3 tools/site.py set audio-analysis intro "..."` — deterministic page edit, invalidates candidate's approval state.
- `python3 tools/site.py validate` — schema and internal link checks, non-zero exit on failure.
- `python3 tools/site.py build` — regenerate 9 local preview pages, content inventory and candidate CMS export.
- `python3 tools/site.py build --mode production` — **fails closed** without explicit per-page content-digest approval records (`content/approvals.json`).

CLI output is JSON for assistant/agent interoperability. The CLI does not call a private API, generate fictional approvals or attempt DNS changes.

The generated `site/cms-export.json` contains proposed content resource identities and candidate digests. They are **not** authoritative Wire resource refs; the Resource Editor's own exact SHA-512 publication receipts replace those provisional identities. `site/build-manifest.json` has `not_a_wire_release=true` deliberately.

## First Wire UI application target

The public marketing pages themselves can remain ordinary HTML while the authenticated site/editor is a genuine Wire application. Define semantic elements such as `RF_SITE_OVERVIEW`, `RF_PAGE_COLLECTION`, `RF_PAGE_DRAFT`, `RF_APPROVAL_DECISION`, with actions `CONTENT.OPEN`, `CONTENT.PROPOSE`, `CONTENT.REVIEW`, `CONTENT.PUBLISH`, and state owner in ooRexx/CMS. Renderers may display them; they never grant editing rights.

A correct Agent Authoring tool should invoke the same `CONTENT.PROPOSE` and review boundaries, include expected revision and principal and receive a conflict/denial when stale or unauthorised. Agent tooling cannot confer publication approval on itself.

## Deployment blockers (not silently bypassed)

- Accepted CMS Brand Builder code/service and its content/approval API, if available in the source estate.
- Resource Editor publication/import of these pages as exact SHA-512 content artifacts.
- Builder compiled release and authenticated editor execution qualification against the exact pinned dependency closure.
- HTTPS virtual hosts/TLS SNI, apex+www certificate validation, fail-closed Host mismatches and activation of the server by the deployment owner.
- Verified recipient routing before activating an enquiry submission form; no dummy contact mailbox.
- Production privacy, logging/retention, domain and accessibility acceptance.
