# Reference Video Reconstruction Providers

This package includes one deliberately non-preferred reference provider family for five reconstruction methodologies.  Its purpose is to make the methodology contract executable and comparable; it does **not** turn any reconstruction into source observation.

The provider writes three material products per candidate: an RGBA candidate image, a support map, and an uncertainty map. Pixels without source-derived support remain transparent/zero. Every result is status `CANDIDATE` and authority effect `RECONSTRUCT_CANDIDATE`.

## Implemented methodologies

- `VIDEO.RECON.LEADING_EDGE_BACKPROJECTION` — aligns moving foreground by the observed leading support boundary and robustly backprojects source-supported pixels behind that boundary.
- `VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL` — normalises both leading and trailing support boundaries before robust accumulation.
- `VIDEO.RECON.FLOW_WARP_ACCUMULATE` — dense optical-flow warp to a reference frame followed by robust source-supported accumulation.
- `VIDEO.RECON.MOVING_STRIP_MOSAIC` — builds an object-coordinate mosaic from sequential source-supported strips.
- `VIDEO.RECON.LATENT_MULTI_FRAME` — flow-aligned robust latent estimate with conservative supported-pixel edge restoration. It performs no generative fill.

These are implementation variants, not definitions of the methodology itself. Other providers may use different tracking, PSF estimation, deconvolution, Bayesian inference, learned priors, GPU kernels or sensor models and remain independent implementations.

## Leading edge wording

The leading edge is treated as a higher-confidence **support/registration constraint**, not as an axiom that a motion-blurred edge is literally a sharp instantaneous sample. Real exposure integrates light through the shutter interval. This provider therefore records support and uncertainty and never labels its product a recovered original frame.

## Applicability

The current provider requires at least five usable moving-foreground frames and measurable horizontal translation inside the caller-supplied crop. It returns `NOT_APPLICABLE` when those conditions are not met. It does not silently fall back to a different methodology.

## ooRexx resident execution (EyePoke integration)

The former ooRexx adapter used `ADDRESS SYSTEM` to launch `python3` with a
provider script. **That route is now forbidden.** The implementation profiles
declare `OOREXX_FOREIGN_PYTHON` and require `OOREXX.FOREIGN.PYTHON`.

`tools/run_reference_video_provider.rex` calls
`MediaForeignVideoInvoker~run(methodologyId, jobPath, resultPath)`.
This class imports the installed `python_foreign.cls` from Foreign Runtime
v0.22.6, resolves the exact trusted `reference_video_reconstruction.py`,
loads it in the **resident** interpreter using `importlib.util`, and calls
`run_job_file` as a foreign-object method. ooRexx retains orchestration,
methodology identity, status checking and downstream admission authority.
OpenCV and NumPy remain implementation libraries, not controllers.

Deployment must expose the Media `src/`, Foreign Runtime `rexx/`, and
existing `json.cls` on the ooRexx class path. Foreign Runtime native Python
provider must be built/installed for the host ABI. The provider's local
Python environment must contain NumPy and OpenCV. No `subprocess`,
`os.system`, shell-wrapper invocation or new JSON-RPC side channel is needed.

**Fail-closed private material rule:** `ALCHEMY_PRIVATE_MEDIA_ROOT` must be
set to an existing absolute private directory other than `/`. For actual
video jobs, the video source, private job JSON, candidate output directory and result JSON path
must resolve within that root. Any path inside a Git worktree is rejected,
including through symlinks. Invalid privacy preflight does not write a
failure-result artifact. The caller is responsible for access control, lawful
purpose and original preservation in its own private Storage Fabric context.

The standalone Python command-line `main()` remains solely for diagnostic
compatibility; it observes the same private-material policy and is **never**
invoked by the ooRexx provider runner. The wholly synthetic fixture under
`tests/fixtures/foreign_runtime_video/` exercises the embedded call without
loading, decoding or saving real images.

`test_video_no_subprocess.rex` is a source boundary regression;
`test_foreign_video_invoker.rex` requires the actual Foreign Runtime library
and executes the synthetic provider. No successful end-to-end OpenCV/native
Foreign Runtime result is claimed until that integration test is run on the
target runtime. The other audio reference adapters remain separate work and
are not silently represented as migrated.
