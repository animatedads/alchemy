/* F11AcousticClusterWorkflow.cls
 * Cluster adapter/workflow for F11 acoustic reverse-engineering candidates.
 *
 * Application Physics objects remain cluster-unaware.  Small reconstructable
 * candidate state moves; destination-local acoustic contexts, PCM windows and
 * heavy spectral state remain resident behind LOCAL_REF.
 */

::class F11AcousticCandidateTrajectoryTask public

::method init
    expose candidateId sourceX sourceY direction sampleStepMs durationMs signalId
    use strict arg candidateIdArg, sourceXArg, sourceYArg, directionArg, -
                   sampleStepMsArg = 20, durationMsArg = 0, signalIdArg = "warbler.default/1"
    candidateId = candidateIdArg~string
    sourceX = sourceXArg
    sourceY = sourceYArg
    direction = directionArg~string~upper
    sampleStepMs = sampleStepMsArg
    durationMs = durationMsArg
    signalId = signalIdArg~string

::attribute candidateId get
::attribute sourceX get
::attribute sourceY get
::attribute direction get
::attribute sampleStepMs get
::attribute durationMs get
::attribute signalId get

::method evaluate
    use strict arg context
    return context~evaluateCandidateTrajectory(self)


::class F11AcousticCandidateTrajectoryAdapter public
::constant ADAPTER_ID "physics.f11.candidate-trajectory/1"

::attribute adapterId get
::method init
    expose adapterId
    adapterId = self~ADAPTER_ID

::method capture
    use strict arg task
    if task == .nil then return .nil
    d = .directory~new
    d["schema"] = "physics.f11.candidate-trajectory.state/1"
    d["candidate_id"] = task~candidateId
    d["source_x"] = task~sourceX
    d["source_y"] = task~sourceY
    d["direction"] = task~direction
    d["sample_step_ms"] = task~sampleStepMs
    d["duration_ms"] = task~durationMs
    d["signal_id"] = task~signalId
    return d

::method restore
    use strict arg state
    if state == .nil then return .nil
    if \state~isA(.Directory) then return .nil
    if state["schema"] <> "physics.f11.candidate-trajectory.state/1" then return .nil
    if state["candidate_id"] == .nil then return .nil
    if state["source_x"] == .nil then return .nil
    if state["source_y"] == .nil then return .nil
    if state["direction"] == .nil then return .nil
    return .F11AcousticCandidateTrajectoryTask~new( -
        state["candidate_id"], state["source_x"], state["source_y"], -
        state["direction"], state["sample_step_ms"], state["duration_ms"], -
        state["signal_id"])


::class F11AcousticClusterWorkflow public
::constant LOCAL_CONTEXT_REF "f11-acoustic-context"

::method registerAdapter class
    use strict arg adapterRegistry
    return adapterRegistry~register(.F11AcousticCandidateTrajectoryAdapter~new)

::method publishLocalContext class
    use strict arg resourceRegistry, context
    return resourceRegistry~publish(self~LOCAL_CONTEXT_REF, context)

::method attachTask class
    use strict arg host, objectId, task, generation = 1
    return host~attach(objectId, task, .F11AcousticCandidateTrajectoryAdapter~ADAPTER_ID, generation)

::method invocationArgs class
    args = .array~new
    args~append(.ClusterObjectCodec~localRefArg(self~LOCAL_CONTEXT_REF))
    return args

::method invokeRemote class
    use strict arg client, nodeId, objectId
    return client~invoke(nodeId, objectId, "evaluate", self~invocationArgs)


/* Candidate result schemas carry compact values and references only.  The v1
 * constructor is retained for existing consumers; v2 adds the complete set of
 * moving-probe curves needed by the reverse-engineering workflow. */
::class F11AcousticCandidateSummary public

::method new class
    use strict arg task, sampleCount, fcPitchCurveRef, fdPitchCurveRef, -
                   fcPowerCurveRef, fdPowerCurveRef, overlapCurveRef
    d = .directory~new
    d["schema"] = "physics.f11.candidate-summary/1"
    self~putIdentity(d, task, sampleCount)
    d["fc_pitch_curve_ref"] = fcPitchCurveRef~string
    d["fd_pitch_curve_ref"] = fdPitchCurveRef~string
    d["fc_power_curve_ref"] = fcPowerCurveRef~string
    d["fd_power_curve_ref"] = fdPowerCurveRef~string
    d["overlap_curve_ref"] = overlapCurveRef~string
    return d

::method newV2 class
    use strict arg task, sampleCount, staticTdoaMs, staticOverlapLag, -
                   fcPitchCurveRef, fdPitchCurveRef, -
                   fcCadenceCurveRef, fdCadenceCurveRef, -
                   fcPowerCurveRef, fdPowerCurveRef, -
                   fcReflectionDelayCurveRef, fdReflectionDelayCurveRef, -
                   overlapCurveRef, fcVehicleResidualRef, fdVehicleResidualRef
    d = .directory~new
    d["schema"] = "physics.f11.candidate-summary/2"
    self~putIdentity(d, task, sampleCount)
    d["static_fd_minus_fc_ms"] = staticTdoaMs
    d["static_overlap_lag"] = staticOverlapLag
    d["fc_pitch_curve_ref"] = fcPitchCurveRef~string
    d["fd_pitch_curve_ref"] = fdPitchCurveRef~string
    d["fc_cadence_curve_ref"] = fcCadenceCurveRef~string
    d["fd_cadence_curve_ref"] = fdCadenceCurveRef~string
    d["fc_power_curve_ref"] = fcPowerCurveRef~string
    d["fd_power_curve_ref"] = fdPowerCurveRef~string
    d["fc_reflection_delay_curve_ref"] = fcReflectionDelayCurveRef~string
    d["fd_reflection_delay_curve_ref"] = fdReflectionDelayCurveRef~string
    d["overlap_curve_ref"] = overlapCurveRef~string
    d["fc_vehicle_residual_ref"] = fcVehicleResidualRef~string
    d["fd_vehicle_residual_ref"] = fdVehicleResidualRef~string
    return d

::method newV3 class
    use strict arg task, sampleCount, features, refs
    if features == .nil then return .nil
    if refs == .nil then return .nil
    d = .directory~new
    d["schema"] = "physics.f11.candidate-summary/3"
    self~putIdentity(d, task, sampleCount)
    fields = .F11AcousticEvidenceMatcher~supportedFields
    do field over fields
        d[field] = features~fieldValue(field)
    end
    d["fc_pitch_curve_ref"] = refs["fc_pitch_curve_ref"]
    d["fd_pitch_curve_ref"] = refs["fd_pitch_curve_ref"]
    d["fc_cadence_curve_ref"] = refs["fc_cadence_curve_ref"]
    d["fd_cadence_curve_ref"] = refs["fd_cadence_curve_ref"]
    d["fc_power_curve_ref"] = refs["fc_power_curve_ref"]
    d["fd_power_curve_ref"] = refs["fd_power_curve_ref"]
    d["fc_reflection_delay_curve_ref"] = refs["fc_reflection_delay_curve_ref"]
    d["fd_reflection_delay_curve_ref"] = refs["fd_reflection_delay_curve_ref"]
    d["overlap_curve_ref"] = refs["overlap_curve_ref"]
    d["fc_vehicle_residual_ref"] = refs["fc_vehicle_residual_ref"]
    d["fd_vehicle_residual_ref"] = refs["fd_vehicle_residual_ref"]
    return d

::method putIdentity class
    use strict arg d, task, sampleCount
    d["candidate_id"] = task~candidateId
    d["source_x"] = task~sourceX
    d["source_y"] = task~sourceY
    d["direction"] = task~direction
    d["sample_count"] = sampleCount
    return d


/* A deterministic work plan.  It contains only reconstructable candidate
 * descriptors; no cluster host or transport object is retained. */
::class F11AcousticCandidateBatchPlan public

::method init
    expose tasks
    tasks = .array~new

::attribute tasks get

::method addCandidate
    expose tasks
    use strict arg sourceX, sourceY, direction, sampleStepMs = 20, durationMs = 0, signalId = "warbler.default/1"
    id = self~candidateId(sourceX, sourceY, direction)
    task = .F11AcousticCandidateTrajectoryTask~new(id, sourceX, sourceY, direction, sampleStepMs, durationMs, signalId)
    tasks~append(task)
    return task

::method addGrid
    use strict arg xMin, xMax, xStep, yMin, yMax, yStep, directions, -
                   sampleStepMs = 20, durationMs = 0, signalId = "warbler.default/1"
    if xStep <= 0 then raise syntax 88.900 array("F11 batch xStep must be positive")
    if yStep <= 0 then raise syntax 88.900 array("F11 batch yStep must be positive")
    if directions == .nil then raise syntax 88.900 array("F11 batch directions are required")
    added = 0
    y = yMin
    do while y <= yMax
        x = xMin
        do while x <= xMax
            do direction over directions
                ignore = self~addCandidate(x, y, direction, sampleStepMs, durationMs, signalId)
                added += 1
            end
            x += xStep
        end
        y += yStep
    end
    return added

::method candidateId
    use strict arg sourceX, sourceY, direction
    return "F11-" || sourceX~string || "-" || sourceY~string || "-" || direction~string~upper


/* Assignment is explicit evidence.  The planner uses deterministic round-robin
 * placement only; it does not claim performance-optimal scheduling. */
::class F11AcousticBatchAssignment public
::method init
    expose task nodeId ordinal
    use strict arg taskArg, nodeIdArg, ordinalArg
    task = taskArg
    nodeId = nodeIdArg~string
    ordinal = ordinalArg
::attribute task get
::attribute nodeId get
::attribute ordinal get

::class F11AcousticBatchPlanner public
::method assignRoundRobin class
    use strict arg plan, nodeIds
    if nodeIds == .nil then raise syntax 88.900 array("F11 batch nodeIds are required")
    nodeCount = nodeIds~items
    if nodeCount < 1 then raise syntax 88.900 array("F11 batch requires at least one node")
    assignments = .array~new
    ordinal = 0
    do task over plan~tasks
        ordinal += 1
        slot = ((ordinal - 1) // nodeCount) + 1
        assignments~append(.F11AcousticBatchAssignment~new(task, nodeIds[slot], ordinal))
    end
    return assignments


::class F11AcousticBatchResult public
::method init
    expose candidateId nodeId ok code summary
    use strict arg candidateIdArg, nodeIdArg, okArg, codeArg, summaryArg = .nil
    candidateId = candidateIdArg~string
    nodeId = nodeIdArg~string
    ok = (okArg == .true)
    code = codeArg~string
    summary = summaryArg
::attribute candidateId get
::attribute nodeId get
::attribute ok get
::attribute code get
::attribute summary get


/* Runs an already-planned batch through the existing object move/invoke
 * contract.  The source host is only a staging owner.  Every candidate is
 * moved once, executed once at its assigned destination, and represented by a
 * compact result. */
::class F11AcousticClusterBatchRunner public

::method init
    expose sourceHost client mover nextObject
    use strict arg sourceHostArg, clientArg
    sourceHost = sourceHostArg
    client = clientArg
    mover = .ClusterObjectMoveCoordinator~new(sourceHost, client)
    nextObject = 0

::method run
    expose sourceHost client mover nextObject
    use strict arg assignments
    results = .array~new
    do assignment over assignments
        nextObject += 1
        objectId = "f11-candidate-" || nextObject
        task = assignment~task
        attached = .F11AcousticClusterWorkflow~attachTask(sourceHost, objectId, task)
        if \attached then do
            results~append(.F11AcousticBatchResult~new(task~candidateId, assignment~nodeId, .false, "ATTACH_FAILED"))
            iterate
        end
        move = mover~move(objectId, assignment~nodeId)
        if \move~ok then do
            results~append(.F11AcousticBatchResult~new(task~candidateId, assignment~nodeId, .false, move~code))
            iterate
        end
        answer = .F11AcousticClusterWorkflow~invokeRemote(client, assignment~nodeId, objectId)
        if answer == .nil then do
            results~append(.F11AcousticBatchResult~new(task~candidateId, assignment~nodeId, .false, "CALL_UNCERTAIN"))
            iterate
        end
        if answer["status"] <> "OK" then do
            results~append(.F11AcousticBatchResult~new(task~candidateId, assignment~nodeId, .false, answer["code"]))
            iterate
        end
        results~append(.F11AcousticBatchResult~new(task~candidateId, assignment~nodeId, .true, "OK", answer["payload"]["value"]))
    end
    return results


/* ====================================================================== */
/* dev50: compact trajectory features and reverse-evidence matching.
 *
 * Curve payloads remain destination-local.  These values are deliberately
 * compact descriptors extracted by the local acoustic context so a reverse
 * search can reject incompatible candidates without moving PCM/STFT data.
 */
::class F11AcousticTrajectoryFeatures public

::method init
    expose staticTdoaMs staticOverlapLag fcPitchRatio fdPitchRatio -
           fcCadenceRatio fdCadenceRatio fcPowerDeltaDb fdPowerDeltaDb -
           fcReflectionDelayMs fdReflectionDelayMs overlapLagDuringVehicle -
           rearPathPowerDb
    use strict arg staticTdoaMsArg, staticOverlapLagArg, -
                   fcPitchRatioArg, fdPitchRatioArg, -
                   fcCadenceRatioArg, fdCadenceRatioArg, -
                   fcPowerDeltaDbArg, fdPowerDeltaDbArg, -
                   fcReflectionDelayMsArg, fdReflectionDelayMsArg, -
                   overlapLagDuringVehicleArg, rearPathPowerDbArg = .nil
    staticTdoaMs = staticTdoaMsArg
    staticOverlapLag = staticOverlapLagArg
    fcPitchRatio = fcPitchRatioArg
    fdPitchRatio = fdPitchRatioArg
    fcCadenceRatio = fcCadenceRatioArg
    fdCadenceRatio = fdCadenceRatioArg
    fcPowerDeltaDb = fcPowerDeltaDbArg
    fdPowerDeltaDb = fdPowerDeltaDbArg
    fcReflectionDelayMs = fcReflectionDelayMsArg
    fdReflectionDelayMs = fdReflectionDelayMsArg
    overlapLagDuringVehicle = overlapLagDuringVehicleArg
    rearPathPowerDb = rearPathPowerDbArg

::attribute staticTdoaMs get
::attribute staticOverlapLag get
::attribute fcPitchRatio get
::attribute fdPitchRatio get
::attribute fcCadenceRatio get
::attribute fdCadenceRatio get
::attribute fcPowerDeltaDb get
::attribute fdPowerDeltaDb get
::attribute fcReflectionDelayMs get
::attribute fdReflectionDelayMs get
::attribute overlapLagDuringVehicle get
::attribute rearPathPowerDb get

::method fieldValue
    expose staticTdoaMs staticOverlapLag fcPitchRatio fdPitchRatio -
           fcCadenceRatio fdCadenceRatio fcPowerDeltaDb fdPowerDeltaDb -
           fcReflectionDelayMs fdReflectionDelayMs overlapLagDuringVehicle -
           rearPathPowerDb
    use strict arg name
    select
        when name = "static_fd_minus_fc_ms" then return staticTdoaMs
        when name = "static_overlap_lag" then return staticOverlapLag
        when name = "fc_pitch_ratio" then return fcPitchRatio
        when name = "fd_pitch_ratio" then return fdPitchRatio
        when name = "fc_cadence_ratio" then return fcCadenceRatio
        when name = "fd_cadence_ratio" then return fdCadenceRatio
        when name = "fc_power_delta_db" then return fcPowerDeltaDb
        when name = "fd_power_delta_db" then return fdPowerDeltaDb
        when name = "fc_reflection_delay_ms" then return fcReflectionDelayMs
        when name = "fd_reflection_delay_ms" then return fdReflectionDelayMs
        when name = "overlap_lag_during_vehicle" then return overlapLagDuringVehicle
        when name = "rear_path_power_db" then return rearPathPowerDb
        otherwise return .nil
    end


::class F11AcousticObservedEvidence public

::method init
    expose values tolerances
    values = .directory~new
    tolerances = .directory~new

::method put
    expose values tolerances
    use strict arg name, value, tolerance
    if tolerance <= 0 then raise syntax 88.900 array("F11 evidence tolerance must be positive")
    values[name~string] = value
    tolerances[name~string] = tolerance
    return self

::method value
    expose values
    use strict arg name
    return values[name~string]

::method tolerance
    expose tolerances
    use strict arg name
    return tolerances[name~string]

::method has
    expose values
    use strict arg name
    return values[name~string] \== .nil


::class F11AcousticEvidenceMatch public
::method init
    expose candidateId direction score maxResidual componentCount compatible
    use strict arg candidateIdArg, directionArg, scoreArg, maxResidualArg, componentCountArg, compatibleArg
    candidateId = candidateIdArg~string
    direction = directionArg~string
    score = scoreArg
    maxResidual = maxResidualArg
    componentCount = componentCountArg
    compatible = (compatibleArg == .true)
::attribute candidateId get
::attribute direction get
::attribute score get
::attribute maxResidual get
::attribute componentCount get
::attribute compatible get


::class F11AcousticEvidenceMatcher public

::method supportedFields class
    return .array~of( -
        "static_fd_minus_fc_ms", "static_overlap_lag", -
        "fc_pitch_ratio", "fd_pitch_ratio", -
        "fc_cadence_ratio", "fd_cadence_ratio", -
        "fc_power_delta_db", "fd_power_delta_db", -
        "fc_reflection_delay_ms", "fd_reflection_delay_ms", -
        "overlap_lag_during_vehicle", "rear_path_power_db")

/* score is the mean tolerance-normalised residual.  compatible means every
 * supplied evidence component is within its explicit tolerance.  No hidden
 * weighting or probabilistic claim is made. */
::method score class
    use strict arg candidateSummary, observed
    if candidateSummary == .nil then return .nil
    if observed == .nil then return .nil
    schema = candidateSummary["schema"]
    if schema <> "physics.f11.candidate-summary/3" then return .nil

    total = 0
    count = 0
    maxResidual = 0
    compatible = .true
    do field over self~supportedFields
        if observed~has(field) then do
            candidateValue = candidateSummary[field]
            if candidateValue == .nil then return .nil
            tolerance = observed~tolerance(field)
            residual = self~absolute(candidateValue - observed~value(field)) / tolerance
            total += residual
            count += 1
            if residual > maxResidual then maxResidual = residual
            if residual > 1 then compatible = .false
        end
    end
    if count = 0 then return .nil
    meanResidual = total / count
    return .F11AcousticEvidenceMatch~new( -
        candidateSummary["candidate_id"], candidateSummary["direction"], -
        meanResidual, maxResidual, count, compatible)

::method absolute class
    use strict arg value
    if value < 0 then return -value
    return value


/* Authoritative current Room-F refinement window.  This is intentionally a
 * named plan rather than scattered loop literals in experiments. */
::class F11AcousticRefinementPlans public
::constant ROOM_F_X_MIN 4.5
::constant ROOM_F_X_MAX 6.0
::constant ROOM_F_Y_MIN 4.25
::constant ROOM_F_Y_MAX 4.75
::constant ROOM_F_STEP 0.25

::method roomF class
    use strict arg directions = .nil, sampleStepMs = 20, durationMs = 4360, signalId = "warbler.default/1"
    if directions == .nil then directions = .array~of("RTL", "LTR")
    plan = .F11AcousticCandidateBatchPlan~new
    ignore = plan~addGrid(self~ROOM_F_X_MIN, self~ROOM_F_X_MAX, self~ROOM_F_STEP, -
                          self~ROOM_F_Y_MIN, self~ROOM_F_Y_MAX, self~ROOM_F_STEP, -
                          directions, sampleStepMs, durationMs, signalId)
    return plan

::requires 'cluster_object_queue_transport_v0.1.cls'
