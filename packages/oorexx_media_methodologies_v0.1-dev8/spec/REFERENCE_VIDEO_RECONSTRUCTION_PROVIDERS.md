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
