# Plan42 Rust Backend Scaffold

This drop starts the Python-side Rust lane in `tools/plan42c.py`.

Status: **scaffold/static**.

What is now present:

- `RustBackend` is a real backend class, not only an unsupported registration.
- `--target rust` emits Rust source for a conservative typed subset.
- `--list-targets` reports Rust as `scaffold`.
- Rust compatibility reports can return `native` for the scaffold subset.
- Generated Rust includes the canonical embedded Plan42 marker.
- `tests/rust_backend_scaffold_static_guard.py` verifies generation, compatibility,
  diagnostics, target listing, and exact embedded-marker recovery.

Supported scaffold subset:

- Top-level scalar `const`.
- `routine` with typed parameters and optional `return_type`.
- `declare`, `assign`, `return`, `output`, `if`, `while`, `for_range`, `for_each`,
  `break`, `continue`, `assert`, and `raise`.
- Expressions: `literal`, `var`, `cast`, arithmetic/comparison/logical binary ops,
  `not`, `concat`, `format`, `call`, `len`, `in`, `index`, `ternary`, and simple
  list/tuple/set literals.

Not yet claimed:

- No live Rust acceptance was recorded in this environment because `rustc` was not
  available.
- Object/class/method lowering is not native in the Rust scaffold.
- Preferred runtime helpers are not yet mapped to Rust.
- The existing ooRexx-side `spec/RustNodes.cls` remains useful design input, but
  this file is the Python-side `plan42c.py` backend scaffold.
