# alchemy_autobuild v0.4

v0.4 extends the accepted v0.3 runner with a declarative **per-test environment contract** for ooRexx-heavy integration.

It depends explicitly on `packages/alchemy_autobuild_v0.3`; the v0.3 Downloads/Git-inbox, publication, receipt and timing machinery remains the execution base.

## Why

Different acceptance scripts can legitimately need different Rexx search paths and dependency roots. A package-wide login-shell environment is therefore insufficient and can accidentally load stale `.cls` files.

Each test may now have its own `environment` overlay:

```json
{
  "name": "reputation-communication",
  "argv": ["rexx", "tests/test_shannon_reputation_communication.rex"],
  "environment": {
    "set": {
      "REPUTATION_EFFECT_ROOT": "${REPO_ROOT}/packages/reputation_effect_v0.2",
      "REPUTATION_FEED_ROOT": "${REPO_ROOT}/packages/reputation_feed_v0.1"
    },
    "rexx_path": {
      "mode": "replace",
      "entries": [
        "${PACKAGE_ROOT}",
        "${REPO_ROOT}/packages/reputation_effect_v0.2/src",
        "${REPO_ROOT}/packages/runtime_registry_v0.11/src"
      ],
      "require_entries": true
    },
    "require_dirs": ["REPUTATION_EFFECT_ROOT", "REPUTATION_FEED_ROOT"],
    "report": ["REPUTATION_EFFECT_ROOT", "REPUTATION_FEED_ROOT"]
  }
}
```

The package-level `environment` is constructed first. The test-level environment is overlaid immediately before that test is started.

### `rexx_path`

`mode` is one of:

- `replace` — deterministic complete REXX_PATH for this scope;
- `prepend` — declared entries before the inherited/package REXX_PATH;
- `append` — declared entries after it.

`require_entries: true` fails before executing the script if any declared entry is not a directory.

### Required exports

- `require`: variable must exist and be non-empty.
- `require_dirs`: variable must exist, be non-empty, and name an existing directory.
- `report`: add the effective value to the test result evidence.

Required variables are reported automatically. `PATH`, `REXX_PATH`, `ALCHEMY_PACKAGE_ROOT`, and `ALCHEMY_REPO_ROOT` are always reported for each test.

An environment-contract failure returns test code `125` without starting the declared script.

## Substitution

Environment values and PATH/REXX_PATH entries support `${PACKAGE_ROOT}`, `${AUTOBUILD_ROOT}`, `${REPO_ROOT}`, and already-defined environment variables. Unresolved `${NAME}` tokens are rejected.

## Protocol

New packages may use `alchemy.autobuild.integration/0.3`. v0.1 and v0.2 manifests remain supported. The v0.4 upgrade package itself uses 0.2 so a running v0.3 service can install it.
