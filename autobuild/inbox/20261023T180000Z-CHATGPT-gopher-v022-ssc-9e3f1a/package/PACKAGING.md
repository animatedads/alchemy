# Packaging

Authoritative operational article: `ops.package.stage`.

Default rules:
- stage before packaging;
- exclude `.git`, other VCS metadata, `__pycache__`, Python bytecode, editor/cache debris and prior root delivery ZIPs;
- dependencies are external unless an explicit package policy requests embedding;
- require a changelog entry for the candidate version;
- require at least one discoverable test;
- publish test environment references before qualification;
- do not seal while blocker breaches remain.

Use `./gopher --profile oorexx package check --in <stage> --version <version>`.
