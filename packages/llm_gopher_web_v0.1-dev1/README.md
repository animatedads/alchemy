# LLM Gopher Web Explorer v0.1-dev1

A local, human-facing, read-only web front for exploring an expanding directory of LLM Gopher sphere ZIPs.

The important design choice is that the web front does **not** become a second semantic engine. It reads only enough of each ZIP to discover the embedded `profiles/*.json` sphere identity. Once a sphere is selected it uses Gopher itself and renders Gopher's JSON envelopes:

- `gopher sphere load <sphere> --override <exact-zip>`
- `gopher --profile <sphere> context <sphere> --full`
- `gopher --profile <sphere> open <article>`
- `gopher --profile <sphere> search <text> --sphere <sphere>`
- `gopher --profile <sphere> lookup field=value ... --sphere <sphere>`

Capabilities are shown as documentation only. The web API exposes no arbitrary `exec`, editing, packaging or authoring route.

## Start

The intended collection is `/Downloads/current/sphere` (with `$HOME/Downloads/current/sphere` recognised as a convenience fallback when the absolute path does not exist).

```sh
./gopher-web --gopher /path/to/llm_gopher_v0.19-dev1/gopher
```

Then open the URL printed by the launcher. On a desktop the launcher also asks the default browser to open it automatically. Use `--no-browser` to suppress that.

If `gopher` is already on `PATH`, or `LLM_GOPHER=/path/to/gopher` is set, `--gopher` is unnecessary.

Useful overrides:

```sh
./gopher-web \
  --sphere-dir /Downloads/current/sphere \
  --gopher /Downloads/current/llm_gopher_v0.19-dev1/gopher \
  --port 8765
```

An exact ooRexx Debian package can be supplied when Gopher setup needs one:

```sh
./gopher-web --gopher /path/to/gopher --oorexx-deb /path/to/oorexx-5.3.0-13196.deb
```

## Behaviour

- Binds to `127.0.0.1` by default.
- Uses a private Gopher environment at `~/.local/state/llm-gopher-web/gopher-env` by default.
- Never modifies sphere ZIPs.
- Rescans the sphere directory while running; new ZIPs appear without restart.
- Uses the exact selected ZIP as an explicit Gopher override, so duplicate sphere IDs remain distinguishable rather than making the explorer guess which is newer.
- Shows malformed or non-profile archives in the collection list as unavailable instead of silently ignoring them.
- Uses Gopher's current access-control role `llm` by default because that is the published read role in the supplied packs; use `--role` if the Gopher policy model later publishes another appropriate read role.

## Self-test

```sh
./gopher-web \
  --sphere-dir /path/to/current/sphere \
  --gopher /path/to/gopher \
  --self-test
```

The self-test performs live sphere discovery, activation, full context retrieval, article opening (when an article exists), and corpus search, and prints JSON.

## Security boundary

This is intentionally an explorer, not a Gopher execution console. HTTP requests are converted into fixed argument vectors and passed to Gopher without a shell. The browser can activate a sphere in the private Gopher environment and invoke only read-oriented Gopher operations exposed by this package.

If you deliberately bind to a non-loopback address with `--host`, treat the service as local-trust software; v0.1-dev1 does not provide network authentication or TLS.
