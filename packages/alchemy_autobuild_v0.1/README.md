# alchemy_autobuild v0.1

Deterministic local integration relay for `animatedads/alchemy`.

There is no local LLM and no heuristic package selection. The runner observes a
single configured download folder, executes a versioned declarative manifest,
and uses Git as the durable publication/IPC plane.

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
   `mtime_ns` is recorded for evidence but is not trusted as arrival time;
4. chooses only the newest remaining ZIP by `ctime_ns`;
5. observes the same size/mtime twice before opening it;
6. opens only that selected ZIP;
7. accepts it only when `integration.json` exists at the ZIP root.

It does not recursively scan directories and does not inspect every ZIP looking
for a manifest. Restarting the runner therefore cannot ingest old downloads.
The startup watermark is written to `~/alchemy-autobuild/runner-state.json` and
included in every integration result.

## Manifest

`integration.json` is declarative. Tests are argument arrays rather than shell
command strings. Environment variables and package-relative PATH additions are
supported.

```json
{
  "schema": "alchemy.autobuild.integration/0.1",
  "package": {"name": "example", "version": "0.1", "kind": "oorexx"},
  "working_directory": ".",
  "environment": {
    "set": {"EXAMPLE_HOME": "${PACKAGE_ROOT}"},
    "prepend_path": ["bin"]
  },
  "tests": [
    {"name": "acceptance", "argv": ["sh", "run_tests.sh"], "timeout_seconds": 120}
  ]
}
```

The following substitutions are available in `environment.set`:
`${PACKAGE_ROOT}`, `${AUTOBUILD_ROOT}`, `${REPO_ROOT}`.

A ZIP may also contain an already-prepared message/result file and declare an
explicit repository destination:

```json
"publish": {
  "files": [
    {"source": "ipc/reply.msg", "path": "mesh/ctl/PACKAGE-CHATGPT/reply.msg"}
  ]
}
```

Existing `mesh/ctl` files are append-only and will not be overwritten.

## Results

Each integration publishes to the Alchemy checkout and pushes to GitHub:

- original ZIP under `autobuild/artifacts/<package>/<version>/<sha256>.zip`;
- `autobuild/results/<run-id>/result.json`;
- per-test stdout/stderr logs;
- `mesh/ctl/AUTOBUILD-CHATGPT/<timestamp>-<sha>.msg` summary;
- any package-declared publication files.

Every test and the overall integration record elapsed milliseconds. The overall
run also records the runner startup watermark, archive SHA-256, and source stat
data.

## Bootstrap

From a checkout containing this package:

```sh
sh bootstrap.sh
systemctl --user daemon-reload
systemctl --user enable --now alchemy-autobuild.service
```

`bootstrap.sh` clones/pulls through `github-alchemy`, writes the default config
only when one does not already exist, and installs a user-level systemd unit.
Each service start establishes a fresh startup watermark, so ZIPs already
present before that start are outside the intake window.

Run tests with `sh run_tests.sh`.
