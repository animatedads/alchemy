# Development Floor external infrastructure dependencies — dev11

## Alchemy Cloud Control

- API: `alchemy.cloud-control/0.1`
- Package: `alchemy_cloud_control_v0.1-dev2`
- Final supplied ZIP SHA-256: `0a29487b499b19c164ffc6af481b6e9feebade01ba152a96b3e7ae60e6e12bf2`
- `cloudctl.sh` SHA-256: `73eac5116d4e7f93f3450d71627070e67eb876e3993605b2c00188cd936d38be`
- `gcloud-account.sh` SHA-256: `27f408d4e1105c6b4b1bea8afe9afcf4a2812b19ed61fa933cc9de6b3dbac906`
- `sshnode.sh` SHA-256: `00aa70049b957f87a22235b27b50c59d063bfc07b180f8444bba4420da5bcc52`

The package is registered as an external control-plane authority. Development Floor
does not fork its account, entitlement, transport, normalized service, resource or
node semantics.

The dev2 dependency was qualified from a fresh extraction under exact ooRexx
5.3.0 r13196. Its seven ooRexx regressions, static contract, explicit GCP account
authority, sshnode passthrough, pinned transport identities, manifest and ZIP
integrity gates pass. No live cloud mutation is inferred from those local tests.

## Specialist bootstrap

The qualified one-time specialist bootstrap remains an external evidence input.
Development Floor imports it into an identity-preserving specialist revision
registry rather than rediscovering package knowledge for every assignment.

## RexxOS appliance/deployment qualification

- Appliance profiles: `rexxos_appliance_profiles_v0.1-dev2`
- ZIP SHA-256: `e7f1c1ddf1336110a83137595cf142f68ffbf8f715eb62754aa3e8eb8628879b`
- Application deployment: `rexxos_app_deploy_v0.1-dev3`
- ZIP SHA-256: `8482f760c0d779b0c71d13ddc99b567c9b63cf90b344f93287005a4fe1de5062`
- Crypto: `0.8.3`
- Runtime Reference: `0.4`, SHA-256 `c42a0c51cc5f5e26056d22db97d53eae2633141a7cebe3304b5f19b1847f957a`
- Foreign Runtime: `0.22.6`, SHA-256 `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`
- Native verifier observed: OpenSSL `/lib/x86_64-linux-gnu/libcrypto.so.3`

Supplied qualification under exact ooRexx 5.3.0 r13196 records `PASS FAST crypto provider sha512+ed25519` and `PASS FAST signed command deployment verified and staged with observed provider evidence`. Measured debug-runtime qualification was 14.79 s for MINIMAL versus 0.08 s for FAST; the signed FAST command path measured 0.21 s to sign/submit and 0.33 s for App Server verification/staging. These timings are evidence, not scheduling guarantees.

The Development Floor pins those packages and registers the observed provider stack. It does not claim the next Alchemy RTO lifecycle steps are implemented: authoritative deployment currently ends at `STAGED`.

## RexxOS QEMU HELLO field qualification harness

- `rexxos_qemu_hello_deploy_v0.1-dev1.zip`
- SHA-256 `d732e0ab0b2e9c54e1c0b443b94da0a35e66099ffc3f3a3ff7010724860c022e`
- Purpose: bounded one-shot QEMU field proof on ED209K/Kilo. This harness is qualification evidence, not a runtime dependency of Development Floor.

## Work Load Units authority and accounting — dev8

- API: `work.load.units/0.12`
- Package: `oorexx_work_load_units_v0.12`
- Exact ZIP SHA-256: `b5f6cd8230daa26c227b93032d42b4263c5fcb3b40838359aeab3421cf0ab75a`
- Crypto dependency: `oorexx_crypto_v0.8.3`, SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`
- Alchemy Objects dependency: `alchemy_objects_v0.8`, SHA-256 `7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073`

Development Floor composes the existing `.WLUAuthority`; it does not copy its entitlement,
reservation, authenticated proof, consumption, settlement or release semantics.  WLU's own
ledger remains authoritative WLU evidence.  `development.floor.accounting/0.1` is a separate,
non-entitling append-only journal for correlated native resource units such as model tokens,
micro-currency, GPU seconds, wall time and bytes.


## AI worker stack — dev11

- AI Access v0.6.1: `4cf0dc41330b5e42fa0d533c3601d441ba1f813cb2fbeb582629cad0937ed1f8`
- AI Model Router v0.1: `a0864533472126dda0f25b8b83a466609781e2c099bf0702d9a0be7ecd0f1ca6`
- AI Tool Broker v0.4: `0f29eaf67bf8b282be94b7ad5d590d3de9dd088e9232c39b1a0afd0769e37827`
- AI Tool Orchestrator v0.3: `d2499fa97a91b8eb3f27c36bfc816b0a8be728b90c9273da207d5008e5064ae8`
- OpenAI-compatible provider v0.6.2: `bca67fb506cf2a4c6379605b76d12068a966ab304a0163ab1b8606c604a99211`
- Semantic Source Control v0.2.3: `8b3aa4ddf05f9e4b4e4e6d593f7d36dea79a4b49493bb1442404376a6d16a97b`

The first HelloWorld worker directly uses AI Access plus the v0.6 provider contract and the existing Development Floor WLU/accounting authority. Router/Broker/Orchestrator are pinned portfolio components for broader multi-tool work; the first proof intentionally grants the model no tool execution authority. Semantic Source Control is pinned as the semantic revision/evidence component but is not falsely claimed as the mutation authority for this first single-file workspace proof.

`ai.provider.openai-compat/0.6.1` retains explicit `BEARER`, `API_KEY`, and `NONE` transport authentication without changing the provider-neutral request/reply boundary. Azure uses `API_KEY`; llama.cpp uses `NONE` and restricts its helper configuration to loopback HTTP.


## Packaged runnable dependency closure — dev11

The release ZIP now carries these roots under `deps/` and `run_tests.sh` / `run_worker.sh` resolve them relative to their own package directory by default:

- `oorexx_work_load_units_v0.12`
- `oorexx_crypto_v0.8.3`
- `alchemy_objects_v0.8`
- `oorexx_ai_access_v0.6.1`
- `oorexx_secret_broker_v0.2`
- `oorexx_ai_provider_openai_compat_v0.6.2`

This closure is for reproducible qualification and the bounded live worker. It does not replace the packages' own authority/version identities, and explicit `DF_*_ROOT` variables remain supported for controlled dependency substitution.

- ooRexx Logging v0.7: structured LogEvent model used by durable Development Floor run journal.

## dev16 reasoning-management dependency use

The local Qwen reasoning-alignment manager reuses the pinned OpenAI-compatible provider in no-auth loopback mode. It receives only explicit required reasoning obligations and the worker claimed summary. Azure Luna requests concise reasoning summaries; encrypted/private reasoning is neither requested as management evidence nor interpreted by Development Floor.
