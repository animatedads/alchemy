# ooRexx Audio Models v0.2 — additive experimental models

Three independent pure ooRexx model classes: normalized LMS adaptive reference cancellation (AudioLMS), positive spectral flux (AudioSpectralFlux), and zero crossing count (AudioZeroCrossing). AudioModelRegistry provides discovery and instantiation. LMS and flux offer explicit checkpoint/restore. These are reference implementations, not yet connected to the Alchemy Maths provider selector. LMS is a reference-driven adaptive canceller, not blind source separation, and its normalization uses a small denominator stabilizer. Spectral flux accepts nonnegative magnitude arrays from a separately computed spectrum. No automatic claim of speech enhancement or forensic identification is made.

Tested with extracted ooRexx 5.3.0 r13196 debug runtime: `rexx tests/smoke.rex` PASS. No source recordings were used.

This is an additive package alongside the v0.1 foundational technique submission. It does not replace existing Audio V9 or Maths code. Integrate state-space and provider-backed methods after checking the actual Maths v0.17 API.
