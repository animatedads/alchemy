catalogue = .MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(catalogue)

plan = .MediaMethodologyPlan~new("partial reconstruction of a moving subject blurred in every frame")
plan~add(.MediaMethodologyStep~new("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION"))
plan~add(.MediaMethodologyStep~new("VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL"))
plan~add(.MediaMethodologyStep~new("VIDEO.RECON.LATENT_MULTI_FRAME"))
plan~add(.MediaMethodologyStep~new("VIDEO.RECON.FLOW_WARP_ACCUMULATE"))
plan~add(.MediaMethodologyStep~new("QUAL.FORWARD_MODEL.REPROJECTION"))
plan~add(.MediaMethodologyStep~new("QUAL.TIME_REVERSE"))
plan~add(.MediaMethodologyStep~new("QUAL.CROSS_METHOD.DISAGREEMENT"))

say plan~goal
steps = plan~steps
do i = 1 to steps~items
  spec = catalogue~methodology(steps~at(i)~methodologyId)
  say i || "." spec~id "[" || spec~maturity || "]" spec~name
end

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
