# Remote Compute MU Gopher sphere v0.1-dev1

Operational knowledge for the RexxOS MU which coordinates external Colab, ZeroGPU and Windows targets without inheriting placement, policy, transport or migration authority from those backends.

This sphere records **implementation contracts and qualification state**, not permission to dispatch remote jobs. `packs/remote-compute-mu` holds the sphere descriptor, read-only access policy and typed corpus; `profiles/remote-compute-mu.json` is the Gopher profile. An LLM Gopher installation can load the sphere with its standard pack/profile rules.

**Source anchor:** `remote_compute_mu_v0.1-dev2`, code in `src/remote_mu.py` and `src/RemoteComputeMUFront.cls`; 2026-10-23. **Upstream anchors:** `packages/oorexx_colab_job_v0.3-dev1/README.md`, `packages/oorexx_managed_compute_increment_20260901_v6-dev2/README.md`, `packages/queuerexx_v0.1-dev12/README.md` in animatedads/alchemy. These are source claims, not an assertion of live provider capability.

To advance the sphere, amend its records only alongside verified upstream contracts and record exact new source hashes and test evidence. Preserve Colab-specific operational detail in the existing `google-colab` sphere rather than duplicating it here.

## 2026-10-29 native mesh ingress increment

The ooRexx `RemoteComputeMUMeshService.cls` accepts authenticated semantic MI→MU commands through an injected policy and `RemoteComputeMUFront`. Candidate named service `compute.remote/0.1`; operations DISPATCH/STATUS/CANCEL/RECOVER. All require an out-of-band trusted carrier identity with current external LDAP/mesh policy. Not deployed as an XTP listener. See `docs/MESH_INGRESS_DEV3.md` and native `tests/test_mesh.rex`.
