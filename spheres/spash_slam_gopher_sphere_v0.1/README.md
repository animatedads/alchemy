# SPASH SLAM sphere v0.1

Architecture: Tom Dyer. Initial independent implementation and documentation: ChatGPT GPT-6, 2026-10-30.

Canonical package: packages/oorexx_spash_slam_v0.1-dev1.

OBS != LIKE != PATH != PHYSICAL SOURCE.

An acoustic node carries exact source/sample/time geometry, band, processing-method identity, frequency, optional pitch, spectral pattern, energy and optional location hypothesis. SPASH derives a likeness-family identity from compatible patterns, proposes temporal continuation, allows independent overlapping paths, and produces source-referenced replay plans. None of those operations requires naming the sound.

The graph refuses unaligned cross-feed and cross-method continuation; pattern resemblance across sources does not imply one physical emitter. Spectral-bin incompatibility is INCOMPARABLE rather than dissimilar. Virtual microphone results are MODEL_ONLY predictions, not independent captured measurements. An unadmitted replay path is rejected instead of silently spliced. Method-foundation IDs retain dependency information.

Experiment order: admit measured blocks and source/method provenance; compute likeness; propose competing graph continuations; select and retain alternative paths; emit exact sample/band replay plans; test spatial hypotheses against held-out real measurements if they exist; preserve negative results and model uncertainty.

Qualification: 40 positive and nine negative admission tests PASS using ooRexx 5.3.0 r13196 on 2026-10-30. These are synthetic fixtures, not field audio or independent acoustic triangulation.

Next: source-hashed Audio V9 input adapter, drift-resistant family identity, calibrated branch scoring, chunk-halo continuation, SQL graph indexing, independent spatial model comparison and an actual governed waveform renderer. No changes to SLAM, Body SLAM or JCL ownership.
