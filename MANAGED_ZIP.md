# Sending a Managed ZIP to Alchemy Autobuild

This is the producer contract for any AI or human preparing a ZIP for
`alchemy_autobuild`.

The autobuilder is deliberately dumb. It does not infer how a package should be
run or where accepted source belongs. The ZIP must describe that declaratively
with a root-level `integration.json`.

## Delivery sequence

1. Make sure `alchemy-autobuild.service` is running.
2. Only after the service has started, download the managed ZIP into `~/Downloads`.
3. Download one candidate at a time. The runner considers only the newest
   post-start top-level `*.zip`; it does not walk backwards through older ZIPs.
4. The scan is not recursive.

Typical check:

```sh
systemctl --user status alchemy-autobuild.service
```

The default watched path is `~/Downloads/*.zip`.

Each service start establishes a fresh intake watermark. A ZIP whose Linux
`ctime_ns` predates that startup is outside the run.

## ZIP layout

`integration.json` MUST be at archive root.

Correct:

```text
my_component_v0.4.zip
├── integration.json
├── run_tests.sh
├── src/
└── tests/
```

Wrong:

```text
my_component_v0.4.zip
└── my_component_v0.4/
    ├── integration.json
    └── run_tests.sh
```

## Current protocol: 0.2

Normal source packages should use `alchemy.autobuild.integration/0.2`.
Protocol 0.2 deliberately refuses to accept an omitted publication decision:
the manifest must either declare `publish.tree` or explicitly set
`publish.artifact_only` to true.

A normal ooRexx component looks like this:

```json
{
  "schema": "alchemy.autobuild.integration/0.2",
  "package": {
    "name": "my_component",
    "version": "0.4",
    "kind": "oorexx"
  },
  "working_directory": ".",
  "environment": {
    "set": {},
    "prepend_path": []
  },
  "tests": [
    {
      "name": "acceptance",
      "argv": ["sh", "run_tests.sh"],
      "timeout_seconds": 120
    }
  ],
  "publish": {
    "tree": {
      "source": ".",
      "path": "packages/my_component_v0.4"
    }
  }
}
```

### Why `publish.tree` matters

The original ZIP is always archived, but an opaque ZIP is not enough for other
AI sessions. They need accepted source visible as normal Git files for search,
inspection and dependency work.

After every declared test passes, v0.2 re-extracts a pristine copy of the
original ZIP and publishes the declared source tree into Git. Test-generated
cache files, logs or temporary build debris are therefore not promoted by
accident.

If the destination already exists with identical content, publication is a
harmless no-op. If it exists with different content, the integration result is
`ERROR`; existing package source is never silently overwritten.

A failed test still uploads the original ZIP, result, logs and autobuild IPC
message, but DOES NOT promote the source tree.

### Deliberately artifact-only payloads

If a ZIP really should remain only an archived test payload, say so explicitly:

```json
"publish": {
  "artifact_only": true
}
```

Do not omit the publication decision.

## Environment setup

The AI should declare everything required before the tests run instead of
assuming an interactive shell setup.

Available substitutions in `environment.set` are:

- `${PACKAGE_ROOT}` — temporary extracted package root;
- `${AUTOBUILD_ROOT}` — normally `~/alchemy-autobuild`;
- `${REPO_ROOT}` — local checkout of `animatedads/alchemy`.

Example:

```json
"environment": {
  "set": {
    "MY_COMPONENT_HOME": "${PACKAGE_ROOT}",
    "REXX_PATH": "${PACKAGE_ROOT}/lib"
  },
  "prepend_path": ["bin"]
}
```

Tests are argv arrays, not inferred shell prose:

```json
"tests": [
  {
    "name": "unit",
    "argv": ["rexx", "tests/test_unit.rex"],
    "timeout_seconds": 60
  },
  {
    "name": "acceptance",
    "argv": ["sh", "run_tests.sh"],
    "timeout_seconds": 180
  }
]
```

Each test receives separate stdout/stderr capture, return code, start/end time
and elapsed milliseconds.

## Additional files and IPC

`publish.tree` is for the accepted package source. Additional prepared files can
also be published:

```json
"publish": {
  "tree": {
    "source": ".",
    "path": "packages/my_component_v0.4"
  },
  "files": [
    {
      "source": "ipc/reply.msg",
      "path": "mesh/ctl/MY-COMPONENT-CHATGPT/reply.msg",
      "when": "always"
    }
  ]
}
```

`when` may be `pass` (the default) or `always`. Use `always` only for evidence or
IPC which must survive a failed test. `mesh/ctl` messages are append-only.
Ordinary explicit file publication is also collision-protected.

## What the runner publishes automatically

Every attempted managed integration publishes durable evidence to Git:

```text
autobuild/artifacts/<package>/<version>/<sha256>.zip
autobuild/results/<run-id>/result.json
autobuild/results/<run-id>/logs/...
mesh/ctl/AUTOBUILD-CHATGPT/<timestamp>-<sha>.msg
```

For a successful normal source package it additionally publishes the declared
`publish.tree` path, normally under `packages/`.

The result records the package/version, archive SHA-256, source stat data,
runner startup watermark, overall timing, individual test timing and the
published source path.

## Sender checklist

Before presenting the user with the ZIP download link, the producing AI must
verify all of the following:

- ZIP contains `integration.json` at root;
- schema is `alchemy.autobuild.integration/0.2` for normal new packages;
- package name and version are explicit;
- required environment/PATH setup is declared;
- tests use argv arrays and have sensible timeouts;
- normal source packages declare `publish.tree` to a versioned path under
  `packages/`;
- artifact-only intent is explicit if no source tree should be published;
- the ZIP has been locally tested where tooling permits;
- no unwanted caches, credentials or unrelated files are included;
- the user is reminded to download it only after the autobuilder service has
  started.

## v0.1 to v0.2 transition

A running v0.1 service cannot consume a normal schema-0.2 package. The
`alchemy_autobuild_v0.2.zip` upgrade is specially bootstrapped with a compatible
0.1 manifest and enumerated legacy publication files. v0.1 can therefore test
that one ZIP and place `packages/alchemy_autobuild_v0.2/` into Git. After that,
run its `bootstrap.sh`, reload systemd and restart the service. Subsequent
packages should use protocol 0.2.
