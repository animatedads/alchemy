# ooRexx Qualification Execution Broker v0.1-dev1

Authority component for long-running, human-authorised qualification outside an LLM chat execution window.

The broker is deliberately **not a remote shell**. An LLM can select only operator-catalogued artifact, authorised-data, runtime, sandbox, test-plan and target identities. Preflight proves the proposed run is runnable before any authorization challenge exists. The exact resolved run is then frozen and hashed. A human signs the domain-separated intent hash with an Ed25519 private key that remains entirely on the local workstation. Execution nodes receive only the public key and detached signature.

## Lifecycle

`PLAN -> PREFLIGHT_VALIDATED -> INTENT_FROZEN -> AWAITING_AUTHORIZATION -> AUTHORIZED -> worker revalidation -> RUNNING -> SEALED`

Material drift after authorization produces `INTENT_STALE`. There is no LLM/MCP execute operation; worker methods are separate authority.

## Server operations

- `QUALIFICATION.PLAN`
- `QUALIFICATION.REQUEST`
- `QUALIFICATION.AUTHORIZATION.CHALLENGE`
- `QUALIFICATION.AUTHORIZATION.SUBMIT`
- `QUALIFICATION.STATUS`
- `QUALIFICATION.RESULTS`
- `QUALIFICATION.CANCEL`

## Local key ceremony

`tools/qual_authorize.rex` independently recomputes the frozen intent hash, renders the exact package/data/runtime/sandbox/target/commands/limits, asks for literal `YES`, and only then opens the private seed file. It emits a detached grant suitable for `QUALIFICATION.AUTHORIZATION.SUBMIT`. The private seed is never part of a server or MCP payload.

## Current scope

v0.1-dev1 implements the durable authority core and catalogue-backed preflight contract. Actual ed209XX sandbox construction/execution is intentionally delegated to a worker adapter calling `workerStart` / `workerSeal`; those methods are not exposed as LLM operations. Integration with Job-to-Node Allocation, WLU, Storage Fabric, Access/Permissions and managed sandbox deployment remains via explicit adapter seams rather than being simulated in this package.
