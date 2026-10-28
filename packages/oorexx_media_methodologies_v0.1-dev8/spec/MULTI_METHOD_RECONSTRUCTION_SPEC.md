# Multi-method Reconstruction

Reconstruction is strongest when methods are allowed to disagree.

For a blurred moving subject, one experiment may legitimately run, for example:

1. `VIDEO.RECON.LEADING_EDGE_BACKPROJECTION`
2. `VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL`
3. `VIDEO.RECON.LATENT_MULTI_FRAME`
4. `VIDEO.RECON.FLOW_WARP_ACCUMULATE`
5. `VIDEO.RECON.MOVING_STRIP_MOSAIC`

Each method receives the same authoritative source references but retains its own
work shape, halos, state and reconstruction support map. Distribution across
RexxOS nodes does not change methodological identity.

After execution, pairwise or higher-level comparator providers may record which
regions/features agree, disagree or cannot be compared. Agreement between
independent lineages is useful corroborative evidence, but it is not proof that
the reconstructed value is an observed source value. Disagreement is itself an
important result and must remain queryable.

A later presentation layer may render:

- source observation;
- candidate A;
- candidate B;
- common supported region;
- method-specific region;
- disagreement mask;
- unsupported/unknown region.

It must not silently render a synthetic consensus image and present it as a
captured frame.
