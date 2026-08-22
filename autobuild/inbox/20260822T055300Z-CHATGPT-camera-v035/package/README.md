# Camera Behaviour ooRexx v0.35

v0.35 adds compact immutable evidence to generation-pinned clip assessment.

Every `CameraGenerationClipComparator` result now carries a `CameraAssessmentEvidence` object identifying the exact learned generation, publication time, clip/time/day/environment context, compact learned-world counts, and frozen event-grammar settings. Each assessed metric has `CameraAssessmentMetricEvidence` retaining observed/expected/z/support/state, the selected baseline family (`ALL`, `DAY`, or `ENV`), and — for temporal/calendar baselines — the exact overlapping frozen windows that contributed, including their applicability weight and local distribution support/mean/deviation.

This is evidence, not policy. Camera still makes no operational disposition. The object is designed so HardWorld, Structured Relation, NoSQLServer, Queue Fabric or another consumer can inspect or project why Camera reached an assessment without rerunning the mutable learner.
