# alchemy_autobuild v0.2

Deterministic local integration relay for `animatedads/alchemy`.

There is no local LLM and no heuristic package selection. The runner observes a
single configured download folder, executes a versioned declarative manifest,
and uses Git as the durable publication/IPC plane.

## What changed in v0.2

v0.1 proved and archived managed ZIPs but did not automatically make an accepted
component's unpacked source visible in Git. That is inconvenient for other AI
sessions because Git code search and ordinary file access cannot work usefully
inside an opaque archive.

Protocol `alchemy.autobuild.integration/0.2` therefore makes publication intent
explicit. A v0.2 manifest must contain either:

- `publish.tree`: publish the accepted unpacked tree into a declared Git path; or
- `publish.artifact_only: true`: deliberately retain only the ZIP/result/logs.

A source tree is promoted only after all declared tests pass, and it is re-extracted
from the original ZIP so test-generated caches/logs cannot leak into accepted source.
If the destination
already exists with byte-identical content, publication is idempotent. If the
existing tree differs, the run becomes `ERROR`; it is never overwritten.

## Default configuration

- runner root: `~/alchemy-autobuild`
- download inbox: `~/Downloads`
- repository checkout: `~/alchemy-autobuild/repo`
- repository: `git@github-alchemy:animatedads/alchemy.git`
- branch: `main`
- manifest: root-level `integration.json`

The SSH URL deliberately uses the configured host alias `github-alchemy`; the
runner does not know the deploy-key filename.

## Selection rule

At process startup the runner records a nanosecond startup watermark. It then:

1. lists only immediate `~/Downloads` entries;
2. considers only files matching `*.zip`;
3. rejects ZIPs whose Linux `ctime_ns` is earlier than runner startup;
4. chooses only the newest remaining ZIP by `ctime_ns`;
5. observes the same size/mtime/ctime tuple twice before opening it;
6. opens only that selected ZIP;
7. accepts it only when `integration.json` exists at the ZIP root.

It does not recursively scan directories and does not inspect every ZIP looking
for a manifest. Restarting the runner therefore cannot ingest old downloads.

## Normal managed package manifest

```json
{
  "schema": "alchemy.autobuild.integration/0.2",
  "package": {
    "name": "example_component",
    "version": "0.4",
    "kind": "oorexx"
  },
  "working_directory": ".",
  "environment": {
    "set": {
      "EXAMPLE_HOME": "${PACKAGE_ROOT}"
    },
    "prepend_path": ["lib"]
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
      "path": "packages/example_component_v0.4"
    }
  }
}
```

The following substitutions are available in `environment.set`:
`${PACKAGE_ROOT}`, `${AUTOBUILD_ROOT}`, `${REPO_ROOT}`.

### Artifact-only packages

A deliberately non-source payload can say:

```json
"publish": {
  "artifact_only": true
}
```

That choice must be explicit in protocol 0.2.

### Additional files / IPC

A package can also publish specific files. `when` defaults to `pass`; use
`always` only for evidence or IPC that must survive a failed test.

```json
"publish": {
  "tree": {
    "source": ".",
    "path": "packages/example_component_v0.4"
  },
  "files": [
    {
      "source": "ipc/reply.msg",
      "path": "mesh/ctl/PACKAGE-CHATGPT/reply.msg",
      "when": "always"
    }
  ]
}
```

Existing `mesh/ctl` messages are append-only. Ordinary explicit file destinations
and source-tree destinations are also collision-protected: different existing
content is never silently replaced.

## Results

Every integration pushes the durable evidence to Git:

- original ZIP at `autobuild/artifacts/<package>/<version>/<sha256>.zip`;
- `autobuild/results/<run-id>/result.json`;
- per-test stdout/stderr logs;
- `mesh/ctl/AUTOBUILD-CHATGPT/<timestamp>-<sha>.msg` summary;
- accepted unpacked source tree, when `publish.tree` is declared;
- additional declared publication files.

A failed test still publishes the archive/results/logs and the AUTOBUILD result
message, but it does not publish the source tree as an accepted package.

## Backward compatibility

v0.2 still accepts `alchemy.autobuild.integration/0.1` manifests. The v0.2
upgrade ZIP itself uses a v0.1 manifest plus legacy enumerated publication files
so that a running v0.1 service can test and install the v0.2 package into Git.
Future managed packages should use schema 0.2.

## Bootstrap on the target machine

After v0.2 has appeared in Git:

```sh
cd ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.2
sh bootstrap.sh
systemctl --user daemon-reload
systemctl --user restart alchemy-autobuild.service
```

The restart establishes a new startup watermark. Download subsequent managed
ZIPs only after that restart.

Run the package tests with:

```sh
sh run_tests.sh
```
