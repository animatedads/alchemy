# ooRexx Audio Spectral v0.4

Additive development of v0.3 spectral reference models, retaining noise-only EWMA, Wiener power-ratio and oversubtracted spectral subtraction. Adds a **decision-directed a priori SNR estimator with Wiener amplitude gain** (`AudioDecisionDirected`) following the Ephraim–Malah decision-directed SNR recurrence (not an MMSE-STSA or Log-MMSE estimator).

`gamma = observedPower / max(noisePower, floor)`; `xi = alpha * previousGain² * previousGamma + (1-alpha)*max(gamma-1,0)`; `gain = xi/(1+xi)`. First frame initializes `xi` from the instantaneous posterior estimate. Continuation is block-independent and snapshot/restore is supported. Caller must supply power spectra of identical bins, with consistent scaling. The returned array contains **amplitude gains**, not power estimates.

No FFT, synthesis, phase, speech inference or full audio enhancement pipeline is included. No Maths acceleration yet; existing Maths v0.17 is the intended numerical dependency for the next integration. Results are experimental reference calculations, not validated forensic speech restoration.

Tests: `REXX_PATH=src rexx tests/smoke.rex` and `REXX_PATH=src rexx tests/decision_directed.rex`.
