/* Contract qualification for Cluster object execution of one acoustic candidate. */

registryA = .ClusterObjectAdapterRegistry~new
registryB = .ClusterObjectAdapterRegistry~new
ignore = .F11AcousticClusterWorkflow~registerAdapter(registryA)
ignore = .F11AcousticClusterWorkflow~registerAdapter(registryB)

resourcesA = .ClusterLocalResourceRegistry~new
resourcesB = .ClusterLocalResourceRegistry~new
hostA = .ClusterObjectHost~new("NODE-A", registryA, resourcesA)
hostB = .ClusterObjectHost~new("NODE-B", registryB, resourcesB)

contextB = .TestAcousticLocalContext~new
ignore = .F11AcousticClusterWorkflow~publishLocalContext(resourcesB, contextB)

task = .F11AcousticCandidateTrajectoryTask~new("F11-5.0-4.5-RTL", 5.0, 4.5, "RTL", 20, 4360)
ignore = assertTrue(.F11AcousticClusterWorkflow~attachTask(hostA, "candidate-1", task), "attach source task")

network = .ClusterObjectLoopbackNetwork~new
serviceA = .ClusterObjectPeerService~new("NODE-A", hostA)
serviceB = .ClusterObjectPeerService~new("NODE-B", hostB)
ignore = network~publish("NODE-A", serviceA)
ignore = network~publish("NODE-B", serviceB)

clientA = .ClusterObjectPeerClient~new("NODE-A", network~transportFor("NODE-A"))
mover = .ClusterObjectMoveCoordinator~new(hostA, clientA)
move = mover~move("candidate-1", "NODE-B")
ignore = assertTrue(move~ok, "candidate moves to destination")
ignore = assertEqual(2, move~generation, "generation advances")
ignore = assertTrue(hostA~resident("candidate-1") == .nil, "source releases after accepted move")
ignore = assertTrue(hostB~resident("candidate-1") \== .nil, "destination owns candidate")

answer = .F11AcousticClusterWorkflow~invokeRemote(clientA, "NODE-B", "candidate-1")
ignore = assertTrue(answer \== .nil, "remote call response")
ignore = assertEqual("OK", answer["status"], "remote call succeeds")
summary = answer["payload"]["value"]
ignore = assertEqual("physics.f11.candidate-summary/1", summary["schema"], "summary schema")
ignore = assertEqual("F11-5.0-4.5-RTL", summary["candidate_id"], "candidate identity survives move")
ignore = assertEqual(218, summary["sample_count"], "whole trajectory is one unit of work")
ignore = assertEqual("local://NODE-B/fc-pitch", summary["fc_pitch_curve_ref"], "compact result returns reference")
ignore = assertEqual(1, contextB~calls, "destination-local context invoked exactly once")

/* Missing local context must fail closed rather than moving bulk audio. */
resourcesC = .ClusterLocalResourceRegistry~new
registryC = .ClusterObjectAdapterRegistry~new
ignore = .F11AcousticClusterWorkflow~registerAdapter(registryC)
hostC = .ClusterObjectHost~new("NODE-C", registryC, resourcesC)
ignore = assertTrue(.F11AcousticClusterWorkflow~attachTask(hostC, "candidate-2", task), "attach no-context task")
serviceC = .ClusterObjectPeerService~new("NODE-C", hostC)
ignore = network~publish("NODE-C", serviceC)
noContext = .F11AcousticClusterWorkflow~invokeRemote(clientA, "NODE-C", "candidate-2")
ignore = assertEqual("ERROR", noContext["status"], "missing local context fails")
ignore = assertEqual("ARGUMENT_RESOLUTION_FAILED", noContext["code"], "missing local ref code")

say "PASS F11 acoustic cluster workflow"
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

::class TestAcousticLocalContext
::method init
    expose calls
    calls = 0
::attribute calls get
::method evaluateCandidateTrajectory
    expose calls
    use strict arg task
    calls += 1
    return .F11AcousticCandidateSummary~new(task, 218, -
        "local://NODE-B/fc-pitch", "local://NODE-B/fd-pitch", -
        "local://NODE-B/fc-power", "local://NODE-B/fd-power", -
        "local://NODE-B/overlap")

::requires '../cluster/F11AcousticClusterWorkflow.cls'
