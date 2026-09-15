# Starting the Federation Intermediary UI

The package has an explicit root launcher. Do not substitute `python -m http.server`.

## Immediate visual preview

```bash
./start.sh
```

This is equivalent to `./start.sh --preview`. It uses Node's built-in `http` module through `tools/rid-ui-server.mjs` and serves the clearly-labelled sample-data UI at:

```text
http://127.0.0.1:8082/
```

Override the bind address/port with `--host`, `--port`, `RID_HTTP_HOST`, or `RID_HTTP_PORT`.

## Live authoritative development UI

```bash
./start.sh --live
```

Live mode starts, in one foreground launcher lifecycle:

1. the ooRexx RID development fixture / Queue Fabric bridge;
2. Queue Fabric Web Gateway v0.2 on `127.0.0.1:8090` by default;
3. the Node static UI server on `127.0.0.1:8082` by default.

It injects the WebSocket gateway URL into `web/index.html`; the browser still uses the real Alchemy -> WebSocket -> Queue Fabric -> Wire UI Server -> RID path.

Live mode requires the dependency environment already used by `run_browser_tests.sh`:

```text
ALCHEMY_SRC
CRYPTO_SRC
QUEUE_FABRIC_SRC
RUNTIME_REFERENCE_SRC
WIRE_UI_SERVER_SRC
WIRE_UI_BUILDER_SRC
WEB_GATEWAY_ROOT
ACCESS_PERMISSIONS_SRC
SECURITY_EFFECT_SRC
POLICY_SRC
```

`REXX_BIN` defaults to `rexx`. `RID_GATEWAY_HOST`, `RID_GATEWAY_PORT`, and `RID_GATEWAY_TOKEN` can override development gateway values.

If ooRexx or the dependency environment is absent, live mode fails explicitly. It does not fall back to Python or silently replace the authoritative backend with static data.

Ctrl+C / SIGTERM stops the UI server, Web Gateway and ooRexx fixture together.
