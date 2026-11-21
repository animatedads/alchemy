# Native qualification — Moonsault recovery integrity

Interpreter: ooRexx 5.3.0 r13196, 64-bit internal test.

Baseline `test_sydney_camera_coarse_fix.rex`: PASS (nine stars, 3 landmarks).
New `test_recovery_envelope.rex`: PASS (finite-grid acceptance, impossible strict-bound rejection, 54 input perturbations, known-position synthetic recovery with withheld fourth landmark).

Measured: 0.56850 px star-plate RMS; coarse 208.01903° true; model coordinate -33.848212 / +151.215134. The 2° angular tolerance grid samples 7,845 candidates and retains one 50m cell (70.71m padded reported estimate). Sampled robustness displacement 68.27m; worst perturbed residual 6.46°, outside model allowance. These are MODEL-ONLY diagnostics, never a 1NM or 5m real-world accuracy certificate.

Open: surveyed camera reference, validated independent 3D landmarks, physical lens calibration, provenance of landmark geodesy and comparison to a ground-truth receiver; Gopher runtime registration still unconfirmed.