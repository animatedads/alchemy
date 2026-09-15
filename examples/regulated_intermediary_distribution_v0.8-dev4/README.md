# Federation Regulated Intermediary Distribution — v0.8-dev4 UI candidate

This package is a UI-development continuation over the sealed v0.7 regulated intermediary authority baseline.

The browser surface is now organised as an operator desktop: compact scorecards and filters, table-like active case worklist, and a selected-case dossier containing exact provider state, intermediary responsibility, case facts, product-specific journey, sealed signing material, authoritative timeline, and the next permitted intermediary action.

The visual journey is presentation only. Mortgage, investment and insurance progression continues to derive from server-projected case/work/provider fields. The browser does not become a second workflow engine and does not infer provider approval, binding or completion.

## Start

```bash
./start.sh
```

serves the static preview with Node. For the live development path:

```bash
./start.sh --live
```

See `STARTING.md` for environment details. The package has no Python serving fallback.

Sealed v0.7 remains the accepted authority/release baseline until the UI line receives full release qualification.
