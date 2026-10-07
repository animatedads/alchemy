# ooRexx Generalized Compute Intentions v0.1-dev2

A separate convenience package that puts an object-aware Intention Service surface
in front of generalized compute routing.  It plans a **planned admittance route**
using generalized compute, allocation, WLU and router advisory authorities without
becoming any of those authorities itself.

## dev2: real Intention Service shape

The package now follows the same object-preserving pattern used by the LLM Coding
Workbench. `GeneralizedComputeStructuredIntentionProvider~stage()` retains the real
workload/context objects and returns only an opaque token such as:

```text
COMPUTE_INTENTION GCI1
```

Its `propose(service, text)` method implements the current Intention Service provider
contract (`name`, `propose`). The default proposal path constructs the external
`IntentionProposal`; qualification can inject a proposal factory so this convenience
package does not vendor or fork Intention Service classes. It resolves the staged request to an ordinary
`IntentionProposal` and places the original `GeneralizedComputeIntentionRequest`,
workload and context objects into proposal slots. No workload is serialized into a
command string and reconstructed later.

The supported semantic operations are:

- `COMPUTE_PLAN_ADMITTANCE`
- `COMPUTE_EXPLAIN_ADMITTANCE`
- `COMPUTE_PREFERRED_ROUTE`
- `COMPUTE_PREPARE_ADMISSION`

`GeneralizedComputeIntentionEvent` implements the normal `event~invoke(decision)`
shape used by Intention Service dispatch.

## Planned admission handoff

`PREPARE_ADMISSION` does **not** admit anything. It returns a
`PlannedAdmittanceHandoff` containing the exact planned route, selected candidate,
workload and resource objects. That handoff is intended for the existing authoritative
router/WLU/allocation path, which must revalidate and perform the actual admission.

This preserves the authority split:

```text
application / workbench / customer-service caller
                 |
          Intention Service
                 |
 Generalized Compute Intentions
                 |
        planned admittance route
                 |
      authoritative router
          /       |       \
     compute   allocator   WLU
```

The router remains non-entitling until its existing admission path succeeds. This
package never reserves WLU, creates an allocation, acquires a lease, dispatches a
job, invokes an LLM, or claims provider quota.

## Dynamic discovery

Every plan performs fresh compute candidate discovery and fresh assessments from
compute, allocation, WLU and router adapters. A route is therefore a planning result,
not a permanent routing catalogue.

CPU, GPU, ZeroGPU, local-model and hosted-model resources can all travel through the
same surface as their existing objects. Provider-specific selection remains below the
semantic intention boundary.

## Qualification

Use the supplied ooRexx r13196 package directly:

```sh
OOREXX_DEB=/path/to/oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb \
  ./tools/run_environment_test.sh
```

Qualification compiles the source/tests and proves:

- object identity survives planning, proposal and handoff;
- WLU/router/allocator advisory evidence stays separately attributable;
- planning and `PREPARE_ADMISSION` perform no mutation;
- candidate discovery is fresh on each plan;
- the structured provider uses the current Intention Service `name/propose` shape;
- Intention Service dispatch can invoke the planning event without flattening objects.
