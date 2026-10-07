# Code Examiner deployment slice

This directory is the deployment-facing handoff for the human Semantic Source Code Examiner.
It does not contain a second application server and must not be used to bypass Wire UI, Queue Fabric,
Security Effect/Bouncer, Access Permissions, or the authenticated HTTPS principal boundary.

## Required topology

```text
browser /code-examiner
  -> same-origin static Examiner shell
  -> Alchemy Wire UI JS
  -> authenticated WSS Queue Fabric gateway
  -> existing authoritative ObjectQueueManager
  -> Wire UI Server v0.17
  -> secure Semantic Source Examiner adapter
  -> Semantic Source Control
```

The HTTPS/WSS front door must authenticate the human principal. The browser may not supply a `userId`
or select an arbitrary Queue Fabric queue. The server resolves the verified principal into the SSC opaque
bearer session and re-authorises every semantic action. Accept/refuse and branch classification/protection/
conflict resolution require a fresh action-bound step-up challenge.

## Stage static assets

```bash
./deploy/stage_code_examiner.sh \
  /path/to/oorexx_semantic_source_store \
  /path/to/alchemy_wire_ui_js_v0.4-dev4 \
  /srv/www/code-examiner
```

Generate the service descriptor only after the Wire host/gateway has supplied the exact authorised IN queue:

```bash
export SSC_EXAMINER_WEBSOCKET_URL='wss://HOST/wire-ui'
export SSC_EXAMINER_OUTBOUND_QUEUE='EXACT-SERVER-AUTHORISED-IN-QUEUE'
./deploy/generate_service_descriptor.sh /srv/www/code-examiner/service-descriptor
```

Do not hand-edit `bootstrap.mjs` for host-specific values.

## Deployed-route smoke

```bash
./deploy/smoke_code_examiner.sh https://HOST/code-examiner
```

That test intentionally distinguishes static deployment from end-to-end semantic qualification. It passes only
when the full Examiner shell, Wire runtime module and secure descriptor are served. A separate live test must
then prove authenticated `UI_HELLO`, `CODE.CATALOG`, default `CODE.CLASS.INSPECT`, ordinary authorised action,
denied unauthorised action, and privileged step-up through the real Wire/Queue Fabric path.
