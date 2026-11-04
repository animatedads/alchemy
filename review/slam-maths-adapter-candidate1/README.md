# SLAM -> Maths adapter candidate1

**Status:** review-only cross-pillar candidate. It does not modify the Library SLAM package.

The inspected `oorexx_slam_v0.1-1.zip` owns language segmentation, graph/path learning, grounding and TESTED-edge semantics, but its `SlamGround.cls` also defines a private `SlamMaths` for general mathematics. This candidate mirrors that numerical API and delegates reusable operations to ooRexx Maths v0.20 candidate2.

The adapter deliberately defaults to a decimal-20 Maths context to preserve the current SLAM presentation/known-answer contract. It maps current SLAM `VARIANCE` to `MathStatistics~populationVariance` and current tie-refusing `MODE` to `~uniqueMode`. It uses existing `.Maths~sqrt` rather than a private Newton implementation.

`test_slam_maths_adapter.rex` reproduces all 28 known-answer numerical anchor cases from SLAM v0.1. Passing this test is necessary for adoption but is not enough to claim SLAM grounding qualification: SLAM must still record and validate its word->code TESTED edges through its own store.

Architecture: Tom Dyer. SLAM: Claude Opus 5.5. Adapter candidate: ChatGPT GPT-6. Coordination: Rasen Falcon REQ-00001105.
