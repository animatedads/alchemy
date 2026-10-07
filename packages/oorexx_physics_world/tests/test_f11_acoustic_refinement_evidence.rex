/* dev50: Room-F refinement plan and compact reverse-evidence matching. */
plan = .F11AcousticRefinementPlans~roomF
ignore = assertEqual(42, plan~tasks~items, "Room-F 0.25m x two directions produces 42 tasks")

nodes = .array~of("NODE-B", "NODE-C", "NODE-D")
assignments = .F11AcousticBatchPlanner~assignRoundRobin(plan, nodes)
ignore = assertEqual(42, assignments~items, "all refinement tasks assigned")

counts = .directory~new
counts["NODE-B"] = 0
counts["NODE-C"] = 0
counts["NODE-D"] = 0
do assignment over assignments
    nodeId = assignment~nodeId
    counts[nodeId] = counts[nodeId] + 1
end
ignore = assertEqual(14, counts["NODE-B"], "balanced NODE-B")
ignore = assertEqual(14, counts["NODE-C"], "balanced NODE-C")
ignore = assertEqual(14, counts["NODE-D"], "balanced NODE-D")

/* Build one compact v3 candidate summary.  The actual local context computes
 * these descriptors from its resident curves; the matcher sees no PCM. */
task = .F11AcousticCandidateTrajectoryTask~new("F11-5.0-4.5-RTL", 5.0, 4.5, "RTL", 20, 4360)
features = .F11AcousticTrajectoryFeatures~new( -24.10, -22, -
    0.9945, 1.0016, 0.9946, 1.0015, -
    18.0, 0.2, 13.4, 7.1, -12, -38.0)
refs = makeRefs("local://NODE-B/F11-5.0-4.5-RTL/")
summary = .F11AcousticCandidateSummary~newV3(task, 218, features, refs)
ignore = assertEqual("physics.f11.candidate-summary/3", summary["schema"], "v3 summary")

observed = .F11AcousticObservedEvidence~new
ignore = observed~put("static_fd_minus_fc_ms", -24.0, 0.25)
ignore = observed~put("static_overlap_lag", -22, 1)
ignore = observed~put("fc_pitch_ratio", 0.9946, 0.001)
ignore = observed~put("fd_pitch_ratio", 1.0015, 0.001)
ignore = observed~put("overlap_lag_during_vehicle", -12, 1)
ignore = observed~put("rear_path_power_db", -38.2, 1.0)
match = .F11AcousticEvidenceMatcher~score(summary, observed)
ignore = assertTrue(match \== .nil, "match produced")
ignore = assertTrue(match~compatible, "candidate inside every supplied tolerance")
ignore = assertEqual(6, match~componentCount, "six evidence dimensions")
ignore = assertTrue(match~score < 1, "normalised residual below tolerance")

badObserved = .F11AcousticObservedEvidence~new
ignore = badObserved~put("static_fd_minus_fc_ms", -10.0, 0.25)
bad = .F11AcousticEvidenceMatcher~score(summary, badObserved)
ignore = assertTrue(\bad~compatible, "incompatible evidence rejects candidate")
ignore = assertTrue(bad~maxResidual > 1, "rejection has explicit residual evidence")

say "PASS F11 acoustic refinement evidence"
exit 0

::routine makeRefs
    use strict arg prefix
    d = .directory~new
    d["fc_pitch_curve_ref"] = prefix || "fc-pitch"
    d["fd_pitch_curve_ref"] = prefix || "fd-pitch"
    d["fc_cadence_curve_ref"] = prefix || "fc-cadence"
    d["fd_cadence_curve_ref"] = prefix || "fd-cadence"
    d["fc_power_curve_ref"] = prefix || "fc-power"
    d["fd_power_curve_ref"] = prefix || "fd-power"
    d["fc_reflection_delay_curve_ref"] = prefix || "fc-delay"
    d["fd_reflection_delay_curve_ref"] = prefix || "fd-delay"
    d["overlap_curve_ref"] = prefix || "overlap"
    d["fc_vehicle_residual_ref"] = prefix || "fc-residual"
    d["fd_vehicle_residual_ref"] = prefix || "fd-residual"
    return d

::routine assertTrue
    use strict arg condition, label
    if condition then return .true
    say "FAIL:" label
    exit 1

::routine assertEqual
    use strict arg expected, actual, label
    if expected == actual then return .true
    say "FAIL:" label "expected="expected "actual="actual
    exit 1

::requires '../cluster/F11AcousticClusterWorkflow.cls'
