# Sending a Managed ZIP to Alchemy Autobuild

This document is the producer contract for any AI or human preparing a ZIP for
`alchemy_autobuild`.

The autobuilder is deliberately dumb. It does not infer how a package should be
run. The ZIP must describe itself with a root-level `integration.json` file.

## Human delivery sequence

1. Make sure the autobuilder service is running.
2. Only after the service has started, download the managed ZIP into `~/Downloads`.
3. Download one candidate at a time. The runner considers only the newest
   post-start top-level `*.zip` and does not walk backwards through older ZIPs.
4. Do not move an old ZIP into place and expect it to be accepted as a previous
   job. Each service start establishes a fresh intake watermark.

Typical service check:

```sh
systemctl --user status alchemy-autobuild.service
```

The default watched path is:

```text
~/Downloads/*.zip
```

The scan is not recursive.

## What the sender must produce

A managed ZIP must contain `integration.json` at the archive root.

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

The second form is not managed because `integration.json` is not at ZIP root.

## Minimum manifest

```json
{
  "schema": "alchemy.autobuild.integration/0.1",
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
  ]
}
```

Required rules:

- `schema` must be exactly `alchemy.autobuild.integration/0.1`.
- `package.name` and `package.version` must be non-empty strings.
- `tests` must contain at least one test.
- Every test uses an `argv` array. Do not use shell-command strings.
- Every timeout must be positive.
- `working_directory`, test `cwd`, PATH entries, and publication sources are
  package-relative unless otherwise documented.

## ooRexx package example

A package which needs its own classes available through `PATH` can declare that
without teaching the runner anything about the component:

```json
{
  "schema": "alchemy.autobuild.integration/0.1",
  "package": {
    "name": "queue_fabric",
    "version": "0.8.2",
    "kind": "oorexx"
  },
  "working_directory": ".",
  "environment": {
    "set": {
      "QUEUE_FABRIC_HOME": "${PACKAGE_ROOT}"
    },
    "prepend_path": [
      ".",
      "lib"
    ]
  },
  "tests": [
    {
      "name": "acceptance",
      "argv": ["sh", "run_tests.sh"],
      "timeout_seconds": 300
    },
    {
      "name": "direct-smoke",
      "argv": ["rexx", "tests/test_smoke.rex"],
      "timeout_seconds": 60
    }
  ]
}
```

Available substitutions in `environment.set` are:

```text
${PACKAGE_ROOT}
${AUTOBUILD_ROOT}
${REPO_ROOT}
```

The runner also exports:

```text
ALCHEMY_PACKAGE_ROOT
ALCHEMY_AUTOBUILD_ROOT
ALCHEMY_REPO_ROOT
```

If a package needs several environment variables or paths before its tests run,
put them in the manifest. Do not rely on the user's interactive shell profile.

## Test contract

Tests run in manifest order. Each test records:

- start and end timestamps;
- elapsed milliseconds;
- return code;
- timeout state;
- stdout;
- stderr.

A zero return code is PASS. A non-zero return code or timeout is FAIL.

A package should normally include its own `run_tests.sh` so that the same test
entrypoint works both under autobuild and when a developer runs the package by
hand.

## Publishing a prepared IPC or result file

A package may contain a file which should be copied into the Alchemy repository
after testing. Declare it explicitly:

```json
{
  "publish": {
    "files": [
      {
        "source": "ipc/reply.msg",
        "path": "mesh/ctl/PACKAGE-CHATGPT/20260822T060000Z-reply.msg"
      }
    ]
  }
}
```

`source` is inside the ZIP. `path` is relative to the Alchemy repository root.
Existing `mesh/ctl/...` files are append-only and will not be overwritten.

The package itself does not need to create the standard autobuild result
message. The runner automatically publishes an `AUTOBUILD_RESULT` packet under:

```text
mesh/ctl/AUTOBUILD-CHATGPT/
```

## What the runner publishes automatically

After running a managed ZIP, the runner commits and pushes:

```text
autobuild/artifacts/<package>/<version>/<sha256>.zip
autobuild/results/<run-id>/result.json
autobuild/results/<run-id>/logs/...
mesh/ctl/AUTOBUILD-CHATGPT/<timestamp>-<sha>.msg
```

The original ZIP is therefore preserved by content hash. Failed runs still
produce evidence and logs.

## Instructions for an AI sending a package

When asked to provide a package for this system:

1. Finish the component and its tests.
2. Put a valid `integration.json` at ZIP root.
3. Ensure every required test/environment setup is declared in that manifest.
4. Include `run_tests.sh` when the component has a normal package test suite.
5. ZIP the package with `integration.json` at archive root, not inside a wrapper
   directory.
6. Give the user the actual downloadable `.zip` file/link.
7. Tell the user to click/download it only after `alchemy-autobuild.service` is
   running.
8. Do not ask the user to unpack, copy, rename, or manually run the package.
9. Do not upload a second candidate until the first has been observed unless the
   intention is to supersede it; only the newest post-start ZIP is considered.
10. Subsequent diagnosis should read the GitHub `autobuild/results/...` and
    `mesh/ctl/AUTOBUILD-CHATGPT/...` output instead of asking the user to paste
    terminal output when Git evidence is available.

## Sender checklist

Before presenting the download link, verify:

```text
[ ] archive extension is .zip
[ ] integration.json is at ZIP root
[ ] schema is alchemy.autobuild.integration/0.1
[ ] package name/version are present
[ ] at least one argv-based test is declared
[ ] required PATH/environment setup is declared
[ ] run_tests.sh and referenced test files are present
[ ] publication sources, if any, exist inside the ZIP
[ ] archive does not contain path traversal entries
[ ] user is told to download after service startup
```

The authoritative runner implementation is in:

```text
packages/alchemy_autobuild_v0.1/
```
