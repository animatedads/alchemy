# ooRexx Audio Models v0.2

Additive pure ooRexx reference techniques: normalized LMS adaptive filtering, positive spectral flux, and zero-crossing counts. Includes a registry, smoke tests and a snapshot/restore contract for LMS and spectral flux. These are mathematical reference implementations, not a complete enhancement pipeline.

The `AudioLMS` method `advance(reference, desired)` returns [error, estimate]. The adaptive filter uses normalized LMS with a fixed small denominator regularizer. It is not an acoustic echo canceller or independently qualified forensic restoration. `AudioSpectralFlux` consumes magnitude bins, not power bins, and returns unnormalized squared positive differences. `AudioZeroCrossing` counts sign transitions.

Run `REXX_PATH=src rexx tests/smoke.rex` under ooRexx 5.3.0 r13196. This Autobuild edition fixes the original smoke test's relative ::requires path and declares REXX_PATH explicitly. No Maths acceleration or machine-learning inference is included.
