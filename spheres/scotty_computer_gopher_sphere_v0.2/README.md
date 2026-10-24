# Scotty Computer — Gopher sphere v0.2

**Current source candidate:** `scotty_computer_v0.1-dev9.zip`, SHA-256 `caddc451eb17c1efaa12f9708e5ce772d132b7cd3fab5deae11b984d6f9b13b1` (24 October 2026). Design: Tom Dyer. Implementation: ChatGPT with Claude contributions. This sphere supersedes `scotty_computer_gopher_sphere_v0.1` for *development continuity*; the executable package remains separate.

**GitHub package submission:** [`autobuild-submit/20261024T174800Z-CHATGPT-scotty-computer-dev9-caddc451`](https://github.com/animatedads/alchemy/tree/autobuild-submit/20261024T174800Z-CHATGPT-scotty-computer-dev9-caddc451), ready commit `2d489cd52e02b97e0c250e2565198b683d9042ad`. The submission is **not proof of Autobuild acceptance** or publication under `packages/`.

**Qualification:** 86 Python tests passed; native ooRexx script-binding, original integration, GitHub/search/learn and job/document suites each passed independently. The full native wrapper did not finish within the runtime limit; dev6/dev7 native suites were not fully requalified for this candidate. Record remains DEVELOPMENT / NOT FULLY QUALIFIED.

## New in dev9
- A local Python, shell or ooRexx interpreter executing an explicit script file now hashes that file in addition to the interpreter.
- Optional repeatable `--pin-file ABSOLUTE_FILE` before the `--` separator binds explicit local sidecar inputs; symlinks and remote-side file-pin claims are rejected.
- Registration review, run preview and execution re-evaluate pinned file hashes. A changed input invalidates the pending operation.
- This is **not** transitive dependency closure: imported modules, nested scripts, shell `-c`, environment dependencies and remote executable bytes are not fully attested.
- The native qualification wrapper is serial by default for deterministic attribution, but aggregate completion was not verified in this environment.

## Enduring boundaries
Intention Service dev11 owns semantic READY/dispatch. Git and OpenSSH own identity; `sshnode.sh` owns ED209 mapping. Named search scopes are machine-local, unknown scopes fail closed. Exception observation is run-scoped, not a monitoring service; 10 meg = 10,000,000 bytes and size breaches must be observed by sampling. Confirmation bearer tokens do not prove independent human identity. No live ED209/cloud/XTP success is claimed.

See `qualification/STATUS.md` and `cmp.*` articles. Gopher runtime ingestion/validation still requires the receiver; publishing Git objects alone does not register the sphere in a running Gopher instance.
