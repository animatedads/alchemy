# Portfolio synchronization — 27 September 2026

Source: `oorexx_portfolio_code_review_2026-09-27_checkpoint1.zip`.

The checkpoint identifies `oorexx_vision_v0.1-dev15-repaired1(1).zip`
(SHA-256 `b069cec52e53b9cd69a563849b60428b8f8e6eca3543ca8d256fb46ad21c88f4`)
as the retrieved Vision candidate.  It explicitly labels Vision
`RETRIEVED / INVENTORIED — MANUAL REVIEW PENDING`; therefore this package does
not reinterpret the checkpoint as release approval.

This dev16 line is rebased on that repaired1 source, not the earlier local
dev15-v5v-codec-highres derivative.

The portfolio also identifies the independent
`oorexx_vision_line_compat_v0.1-dev1.zip` adjunct.  Its `LineAssessment.cls`
is incorporated here as a separately named adjunct package source so both
Vision and downstream Vision 3D / Camera Behaviour adapters can consume the
same frame-local line evidence contract.  It remains structural evidence:
it is not scene classification, object identity, or motion authority.

Camera Behaviour remains an external specialist consumer.  The checkpoint
retrieved `camera_behaviour_oorexx_v0.57-candidate.zip`, but marks it manual
review pending.  It is therefore not vendored or silently promoted into Vision.

Phone/live acquisition remains rebuildable.  The checkpoint retrieved
`vision_phone_test_v0.1-dev10.zip`; it is a test harness, not Vision semantic
authority.
