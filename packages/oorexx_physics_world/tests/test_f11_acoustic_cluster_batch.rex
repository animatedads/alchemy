/* Batch qualification: deterministic fan-out of whole F11 candidate trajectories. */
registryA = .ClusterObjectAdapterRegistry~new
ignore = .F11AcousticClusterWorkflow~registerAdapter(registryA)
resourcesA = .ClusterLocalResourceRegistry~new
hostA = .ClusterObjectHost~new("NODE-A", registryA, resourcesA)

network = .ClusterObjectLoopbackNetwork~new
serviceA = .ClusterObjectPeerService~new("NODE-A", hostA)
ignore = network~publish("NODE-A", serviceA)

nodeIds = .array~of("NODE-B", "NODE-C", "NODE-D")
contexts = .directory~new
hosts = .directory~new

do nodeId over nodeIds
    registry = .ClusterObjectAdapterRegistry~new
    ignore = .F11AcousticClusterWorkflow~registerAdapter(registry)
    resources = .ClusterLocalResourceRegistry~new
    context = .BatchTestContext~new(nodeId)
    ignore = .F11AcousticClusterWorkflow~publishLocalContext(resources, context)
    host = .ClusterObjectHost~new(nodeId, registry, resources)
    service = .ClusterObjectPeerService~new(nodeId, host)
    ignore = network~publish(nodeId, service)
    contexts[nodeId] = context
    hosts[nodeId] = host
end

clientA = .ClusterObjectPeerClient~new("NODE-A", network~transportFor("NODE-A"))
plan = .F11AcousticCandidateBatchPlan~new
directions = .array~of("RTL", "LTR")
added = plan~addGrid(4.5, 5.0, 0.5, 4.5, 4.5, 1.0, directions, 20, 4360)
ignore = assertEqual(4, added, "four whole-trajectory tasks")

assignments = .F11AcousticBatchPlanner~assignRoundRobin(plan, nodeIds)
ignore = assertEqual(4, assignments~items, "assignment count")
ignore = assertEqual("NODE-B", assignments[1]~nodeId, "round robin 1")
ignore = assertEqual("NODE-C", assignments[2]~nodeId, "round robin 2")
ignore = assertEqual("NODE-D", assignments[3]~nodeId, "round robin 3")
ignore = assertEqual("NODE-B", assignments[4]~nodeId, "round robin wraps")

runner = .F11AcousticClusterBatchRunner~new(hostA, clientA)
results = runner~run(assignments)
ignore = assertEqual(4, results~items, "result count")

do result over results
    ignore = assertTrue(result~ok, "batch candidate succeeds")
    summary = result~summary
    ignore = assertEqual("physics.f11.candidate-summary/2", summary["schema"], "v2 summary schema")
    ignore = assertEqual(218, summary["sample_count"], "whole trajectory remains unit of work")
    ignore = assertTrue(summary["fc_cadence_curve_ref"] <> "", "FC cadence evidence ref")
    ignore = assertTrue(summary["fd_reflection_delay_curve_ref"] <> "", "FD delay evidence ref")
    ignore = assertTrue(summary["fc_vehicle_residual_ref"] <> "", "vehicle subtraction residual ref")
end

ignore = assertEqual(2, contexts["NODE-B"]~calls, "NODE-B gets two assignments")
ignore = assertEqual(1, contexts["NODE-C"]~calls, "NODE-C gets one assignment")
ignore = assertEqual(1, contexts["NODE-D"]~calls, "NODE-D gets one assignment")
ignore = assertEqual(0, hostA~residentCount, "staging host releases all accepted moves")

say "PASS F11 acoustic cluster batch"
exit 0

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

::class BatchTestContext
::method init
    expose nodeId calls
    use strict arg nodeIdArg
    nodeId = nodeIdArg~string
    calls = 0
::attribute calls get
::method evaluateCandidateTrajectory
    expose nodeId calls
    use strict arg task
    calls += 1
    prefix = "local://" || nodeId || "/" || task~candidateId || "/"
    return .F11AcousticCandidateSummary~newV2(task, 218, -24.0, -22, -
        prefix || "fc-pitch", prefix || "fd-pitch", -
        prefix || "fc-cadence", prefix || "fd-cadence", -
        prefix || "fc-power", prefix || "fd-power", -
        prefix || "fc-delay", prefix || "fd-delay", -
        prefix || "overlap", prefix || "fc-residual", prefix || "fd-residual")

::requires '../cluster/F11AcousticClusterWorkflow.cls'
