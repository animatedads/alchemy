# RexxOS Managed Compute MU v0.1-dev2

First executable ooRexx MU extension for supervised Colab / Hugging Face ZeroGPU / Windows test execution. The MU does **not** mint placement leases, impersonate an MI, or implement its own migration engine.

## Local qualification

Unpack the separately supplied `job_node_allocator_v0.6-network6.zip` and make its `src` and the existing `crypto.cls` available on `REXX_PATH`. With ooRexx 5.3.0 r13196:

```sh
MU_UPSTREAM_ROOT=/path/to/job_node_allocator_v0.6-network6 ./run_tests.sh
```

Run tests only with fake provider ports; no cloud credits, ZeroGPU seconds or Windows container launches occur. The Windows script requires an actual Windows host and a local signed/controlled invocation channel. See `docs/ARCHITECTURE.md`.

**Maturity:** integration candidate, fail-closed development controls. Local journal does not satisfy production crash consistency, and no live provider deployment was performed. `integration.json` intentionally runs static, dependency-free checks in Autobuild; allocator-dependent tests are separately qualified here.
