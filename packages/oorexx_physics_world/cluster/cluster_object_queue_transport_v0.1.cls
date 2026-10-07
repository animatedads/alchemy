/* cluster_object_queue_transport_v0.1.cls
 * Cluster object transport over the existing QueueRexx / Queue Fabric peer mesh.
 *
 * API: cluster.object.peer/0.1
 *
 * Design rule:
 *   - application objects know nothing about clustering;
 *   - adapters capture/restore reconstructable object state;
 *   - large/local data is named by LOCAL_REF and resolved only at destination;
 *   - Queue Fabric carries envelopes, references and compact results, not bulk data;
 *   - the optional QueueRexx binding reuses bindServiceRoute()/queue.transport/2.
 */

::class ClusterObjectTransportBuild public
::constant VERSION "0.1"
::constant API "cluster.object.peer/0.1"

::class ClusterObjectContract public
::constant API "cluster.object.peer/0.1"
::constant REQUEST_SCHEMA "cluster.object.peer.request/1"
::constant RESPONSE_SCHEMA "cluster.object.peer.response/1"
::constant ENVELOPE_SCHEMA "cluster.object.envelope/1"
::constant ARG_SCHEMA "cluster.object.arg/1"
::constant SECURITY_DOMAIN "OBJECT"

::class ClusterObjectOperation public
::constant HELLO "HELLO"
::constant MOVE "MOVE"
::constant CALL "CALL"
::constant SNAPSHOT "SNAPSHOT"

::class ClusterObjectArgKind public
::constant VALUE "VALUE"
::constant LOCAL_REF "LOCAL_REF"

/* ====================================================================== */
::class ClusterObjectCodec public

::method value class
    use strict arg directory, key, defaultValue = ""
    if directory == .nil then return defaultValue
    v = directory[key]
    if v == .nil then return defaultValue
    return v

::method whole class
    use strict arg directory, key, defaultValue = 0
    v = self~value(directory, key, defaultValue)
    if \datatype(v, "W") then return defaultValue
    return v + 0

::method newRequest class
    use strict arg requestId, fromNode, toNode, operation
    d = .directory~new
    d["schema"] = .ClusterObjectContract~REQUEST_SCHEMA
    d["api"] = .ClusterObjectContract~API
    d["request_id"] = requestId~string
    d["from_node"] = fromNode~string
    d["to_node"] = toNode~string
    d["operation"] = operation~string~upper
    return d

::method response class
    use strict arg request, sourceNode, status, code = "", payload = .nil
    d = .directory~new
    d["schema"] = .ClusterObjectContract~RESPONSE_SCHEMA
    d["api"] = .ClusterObjectContract~API
    d["request_id"] = self~value(request, "request_id", "")
    d["from_node"] = self~value(request, "from_node", "")
    d["to_node"] = self~value(request, "to_node", "")
    d["source_node"] = sourceNode~string
    d["operation"] = self~value(request, "operation", "")
    d["status"] = status~string~upper
    d["code"] = code~string
    if payload \== .nil then d["payload"] = payload
    return d

::method envelope class
    use strict arg objectId, adapterId, generation, state
    d = .directory~new
    d["schema"] = .ClusterObjectContract~ENVELOPE_SCHEMA
    d["object_id"] = objectId~string
    d["adapter_id"] = adapterId~string
    d["generation"] = generation + 0
    d["state"] = state
    return d

::method valueArg class
    use strict arg value
    d = .directory~new
    d["schema"] = .ClusterObjectContract~ARG_SCHEMA
    d["kind"] = .ClusterObjectArgKind~VALUE
    d["value"] = value
    return d

::method localRefArg class
    use strict arg refId
    d = .directory~new
    d["schema"] = .ClusterObjectContract~ARG_SCHEMA
    d["kind"] = .ClusterObjectArgKind~LOCAL_REF
    d["ref_id"] = refId~string
    return d

/* A deliberately small replay signature.  It is not a cryptographic digest;
 * Queue Fabric owns transport integrity.  This only detects changed-content
 * reuse of one request id inside this service's replay ledger. */
::method replaySignature class
    use strict arg request
    op = self~value(request, "operation", "")
    objectId = self~value(request, "object_id", "")
    if objectId = "" then do
        env = request["envelope"]
        if env \== .nil then objectId = self~value(env, "object_id", "")
    end
    generation = ""
    env = request["envelope"]
    if env \== .nil then generation = self~value(env, "generation", "")
    methodName = self~value(request, "method", "")
    return op || "1F"x || objectId || "1F"x || generation || "1F"x || methodName


/* ====================================================================== */
::class ClusterObjectAdapterRegistry public

::method init
    expose adapters
    adapters = .directory~new

::method register
    expose adapters
    use strict arg adapter
    id = adapter~adapterId~string
    if id = "" then raise syntax 88.900 array("cluster object adapter id is required")
    adapters[id] = adapter
    return adapter

::method resolve
    expose adapters
    use strict arg adapterId
    return adapters[adapterId~string]


/* ====================================================================== */
::class ClusterLocalResourceRegistry public

::method init
    expose resources
    resources = .directory~new

::method publish
    expose resources
    use strict arg refId, object
    resources[refId~string] = object
    return object

::method resolve
    expose resources
    use strict arg refId
    return resources[refId~string]

::method withdraw
    expose resources
    use strict arg refId
    return resources~remove(refId~string)


/* ====================================================================== */
::class ClusterResidentObject public

::method init
    expose objectId object adapterId generation
    use strict arg objectId, object, adapterId, generation

::attribute objectId get
::attribute object get
::attribute adapterId get
::attribute generation get


/* ====================================================================== */
::class ClusterObjectHost public

::method init
    expose nodeId adapters resources residents highGeneration
    use strict arg nodeIdArg, adapterRegistryArg, resourceRegistryArg = .nil

    nodeId = nodeIdArg~string~strip
    if nodeId = "" then raise syntax 88.900 array("cluster object host node id is required")
    adapters = adapterRegistryArg
    if adapters == .nil then raise syntax 88.900 array("cluster object adapter registry is required")
    if resourceRegistryArg == .nil then resources = .ClusterLocalResourceRegistry~new
    else resources = resourceRegistryArg
    residents = .directory~new
    highGeneration = .directory~new

::attribute nodeId get
::attribute resources get

::method attach
    expose residents highGeneration adapters
    use strict arg objectId, object, adapterId, generation = 1

    adapter = adapters~resolve(adapterId)
    if adapter == .nil then return .false
    if generation < 1 then return .false
    residents[objectId] = .ClusterResidentObject~new(objectId, object, adapterId, generation)
    previous = highGeneration[objectId]
    if previous == .nil | generation > previous then highGeneration[objectId] = generation
    return .true

::method resident
    expose residents
    use strict arg objectId
    return residents[objectId]

::method residentCount
    expose residents
    return residents~items

::method snapshot
    expose residents adapters
    use strict arg objectId, generationOverride = .nil

    record = residents[objectId]
    if record == .nil then return .nil
    adapter = adapters~resolve(record~adapterId)
    if adapter == .nil then return .nil
    state = adapter~capture(record~object)
    if state == .nil then return .nil
    generation = record~generation
    if generationOverride \== .nil then generation = generationOverride + 0
    return .ClusterObjectCodec~envelope(objectId, record~adapterId, generation, state)

::method acceptEnvelope
    expose residents highGeneration adapters
    use strict arg envelope

    if envelope == .nil | \envelope~isA(.Directory) then return "ENVELOPE_INVALID"
    if .ClusterObjectCodec~value(envelope, "schema", "") <> .ClusterObjectContract~ENVELOPE_SCHEMA then return "ENVELOPE_SCHEMA_INVALID"

    objectId = .ClusterObjectCodec~value(envelope, "object_id", "")~string~strip
    adapterId = .ClusterObjectCodec~value(envelope, "adapter_id", "")~string~strip
    generation = .ClusterObjectCodec~whole(envelope, "generation", 0)
    state = envelope["state"]
    if objectId = "" | adapterId = "" | generation < 1 | state == .nil then return "ENVELOPE_FIELDS_INVALID"

    previous = highGeneration[objectId]
    if previous \== .nil then do
        if generation <= previous then return "STALE_GENERATION"
    end

    adapter = adapters~resolve(adapterId)
    if adapter == .nil then return "ADAPTER_NOT_FOUND"
    object = adapter~restore(state)
    if object == .nil then return "RESTORE_FAILED"

    residents[objectId] = .ClusterResidentObject~new(objectId, object, adapterId, generation)
    highGeneration[objectId] = generation
    return "ACCEPTED"

::method remove
    expose residents
    use strict arg objectId, expectedGeneration = .nil

    record = residents[objectId]
    if record == .nil then return .nil
    if expectedGeneration \== .nil then do
        if record~generation <> expectedGeneration then return .nil
    end
    return residents~remove(objectId)

::method resolveArguments
    expose resources
    use strict arg argSpecs

    args = .array~new
    if argSpecs == .nil then return args

    do spec over argSpecs
        if spec == .nil | \spec~isA(.Directory) then return .nil
        if .ClusterObjectCodec~value(spec, "schema", "") <> .ClusterObjectContract~ARG_SCHEMA then return .nil
        kind = .ClusterObjectCodec~value(spec, "kind", "")~upper
        if kind = .ClusterObjectArgKind~VALUE then args~append(spec["value"])
        else if kind = .ClusterObjectArgKind~LOCAL_REF then do
            refId = .ClusterObjectCodec~value(spec, "ref_id", "")
            localObject = resources~resolve(refId)
            if localObject == .nil then return .nil
            args~append(localObject)
        end
        else return .nil
    end
    return args

::method invoke
    expose residents
    use strict arg objectId, methodName, argSpecs = .nil

    record = residents[objectId]
    if record == .nil then return .ClusterInvocationResult~failure("OBJECT_NOT_RESIDENT")
    args = self~resolveArguments(argSpecs)
    if args == .nil then return .ClusterInvocationResult~failure("ARGUMENT_RESOLUTION_FAILED")

    signal on syntax name invokeFailed
    message = .message~new(record~object, methodName, "a", args)
    value = message~send
    signal off syntax
    return .ClusterInvocationResult~success(value, record~generation)

invokeFailed:
    signal off syntax
    conditionObject = condition("O")
    detail = ""
    if conditionObject \== .nil then detail = conditionObject~string
    return .ClusterInvocationResult~failure("OBJECT_METHOD_FAILED", detail)


/* ====================================================================== */
::class ClusterInvocationResult public

::method init
    expose ok code detail value generation
    use strict arg okArg, codeArg, detailArg = "", valueArg = .nil, generationArg = 0
    ok = (okArg == .true)
    code = codeArg~string
    detail = detailArg~string
    value = valueArg
    generation = generationArg + 0

::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::attribute generation get

::method success class
    use strict arg valueArg, generationArg
    return self~new(.true, "OK", "", valueArg, generationArg)

::method failure class
    use strict arg codeArg, detailArg = ""
    return self~new(.false, codeArg, detailArg)


/* ====================================================================== */
::class ClusterObjectPeerService public

::method init
    expose nodeId host replayResponses replaySignatures
    use strict arg nodeIdArg, hostArg
    nodeId = nodeIdArg~string~strip
    host = hostArg
    replayResponses = .directory~new
    replaySignatures = .directory~new

::method handle
    expose nodeId host replayResponses replaySignatures
    use strict arg request

    if request == .nil | \request~isA(.Directory) then return .ClusterObjectCodec~response(.directory~new, nodeId, "ERROR", "REQUEST_INVALID")
    if .ClusterObjectCodec~value(request, "schema", "") <> .ClusterObjectContract~REQUEST_SCHEMA | -
       .ClusterObjectCodec~value(request, "api", "") <> .ClusterObjectContract~API then -
        return .ClusterObjectCodec~response(request, nodeId, "ERROR", "CONTRACT_MISMATCH")
    if .ClusterObjectCodec~value(request, "to_node", "") <> nodeId then return .ClusterObjectCodec~response(request, nodeId, "ERROR", "DESTINATION_MISMATCH")

    requestId = .ClusterObjectCodec~value(request, "request_id", "")~string~strip
    fromNode = .ClusterObjectCodec~value(request, "from_node", "")~string~strip
    if requestId = "" | fromNode = "" then return .ClusterObjectCodec~response(request, nodeId, "ERROR", "IDENTITY_REQUIRED")

    signature = .ClusterObjectCodec~replaySignature(request)
    oldResponse = replayResponses[requestId]
    if oldResponse \== .nil then do
        if replaySignatures[requestId] <> signature then return .ClusterObjectCodec~response(request, nodeId, "ERROR", "REQUEST_ID_CONFLICT")
        return oldResponse
    end

    operation = .ClusterObjectCodec~value(request, "operation", "")~upper
    if operation = .ClusterObjectOperation~HELLO then do
        payload = .directory~new
        payload["node_id"] = nodeId
        payload["api"] = .ClusterObjectContract~API
        answer = .ClusterObjectCodec~response(request, nodeId, "OK", "HELLO", payload)
    end
    else if operation = .ClusterObjectOperation~MOVE then do
        code = host~acceptEnvelope(request["envelope"])
        if code = "ACCEPTED" then do
            env = request["envelope"]
            payload = .directory~new
            payload["object_id"] = .ClusterObjectCodec~value(env, "object_id", "")
            payload["generation"] = .ClusterObjectCodec~whole(env, "generation", 0)
            payload["owner_node"] = nodeId
            answer = .ClusterObjectCodec~response(request, nodeId, "OK", "MOVE_ACCEPTED", payload)
        end
        else answer = .ClusterObjectCodec~response(request, nodeId, "ERROR", code)
    end
    else if operation = .ClusterObjectOperation~CALL then do
        objectId = .ClusterObjectCodec~value(request, "object_id", "")
        methodName = .ClusterObjectCodec~value(request, "method", "")
        invocation = host~invoke(objectId, methodName, request["args"])
        if invocation~ok then do
            payload = .directory~new
            payload["object_id"] = objectId
            payload["generation"] = invocation~generation
            payload["value"] = invocation~value
            answer = .ClusterObjectCodec~response(request, nodeId, "OK", "CALL_COMPLETED", payload)
        end
        else answer = .ClusterObjectCodec~response(request, nodeId, "ERROR", invocation~code)
    end
    else if operation = .ClusterObjectOperation~SNAPSHOT then do
        objectId = .ClusterObjectCodec~value(request, "object_id", "")
        env = host~snapshot(objectId)
        if env == .nil then answer = .ClusterObjectCodec~response(request, nodeId, "ERROR", "OBJECT_NOT_RESIDENT")
        else answer = .ClusterObjectCodec~response(request, nodeId, "OK", "SNAPSHOT", env)
    end
    else answer = .ClusterObjectCodec~response(request, nodeId, "ERROR", "OPERATION_UNSUPPORTED")

    replaySignatures[requestId] = signature
    replayResponses[requestId] = answer
    return answer

::method handleFrom
    expose nodeId
    use strict arg authenticatedPeerNodeId, request
    peer = authenticatedPeerNodeId~string~strip
    if peer = "" then return .ClusterObjectCodec~response(request, nodeId, "ERROR", "AUTHENTICATED_PEER_REQUIRED")
    if .ClusterObjectCodec~value(request, "from_node", "") <> peer then return .ClusterObjectCodec~response(request, nodeId, "ERROR", "PEER_IDENTITY_MISMATCH")
    return self~handle(request)


/* ====================================================================== */
/* Transport contract: request(peerNodeId, requestDirectory) -> responseDirectory
 * or .nil on transport failure. */
::class ClusterObjectPeerClient public

::method init
    expose localNodeId transport counter
    use strict arg localNodeArg, transportArg
    localNodeId = localNodeArg~string~strip
    transport = transportArg
    counter = 0
    if localNodeId = "" | transport == .nil then raise syntax 88.900 array("cluster object client requires node id and transport")

::method nextRequestId private
    expose localNodeId counter
    counter += 1
    return "cluster-object-" || localNodeId || "-" || counter || "-" || time("F")

::method call private
    expose localNodeId transport
    use strict arg peerNodeId, operation, requestMutator = .nil, fixedRequestId = ""

    requestId = fixedRequestId~string
    if requestId = "" then requestId = self~nextRequestId
    request = .ClusterObjectCodec~newRequest(requestId, localNodeId, peerNodeId, operation)
    if requestMutator \== .nil then requestMutator~apply(request)

    response = transport~request(peerNodeId, request)
    if response == .nil | \response~isA(.Directory) then return .nil
    if .ClusterObjectCodec~value(response, "schema", "") <> .ClusterObjectContract~RESPONSE_SCHEMA | -
       .ClusterObjectCodec~value(response, "api", "") <> .ClusterObjectContract~API then return .nil
    if .ClusterObjectCodec~value(response, "request_id", "") <> requestId then return .nil
    if .ClusterObjectCodec~value(response, "source_node", "") <> peerNodeId~string then return .nil
    if .ClusterObjectCodec~value(response, "from_node", "") <> localNodeId then return .nil
    return response

::method hello
    use strict arg peerNodeId
    return self~call(peerNodeId, .ClusterObjectOperation~HELLO)

::method move
    use strict arg peerNodeId, envelope, fixedRequestId = ""
    mutator = .ClusterMoveRequestMutator~new(envelope)
    return self~call(peerNodeId, .ClusterObjectOperation~MOVE, mutator, fixedRequestId)

::method invoke
    use strict arg peerNodeId, objectId, methodName, argSpecs = .nil
    mutator = .ClusterCallRequestMutator~new(objectId, methodName, argSpecs)
    return self~call(peerNodeId, .ClusterObjectOperation~CALL, mutator)

::method snapshot
    use strict arg peerNodeId, objectId
    mutator = .ClusterSnapshotRequestMutator~new(objectId)
    return self~call(peerNodeId, .ClusterObjectOperation~SNAPSHOT, mutator)


::class ClusterMoveRequestMutator public
::method init
    expose envelope
    use strict arg envelopeArg
    envelope = envelopeArg
::method apply
    expose envelope
    use strict arg request
    request["envelope"] = envelope

::class ClusterCallRequestMutator public
::method init
    expose objectId methodName argSpecs
    use strict arg objectIdArg, methodNameArg, argSpecsArg = .nil
    objectId = objectIdArg~string; methodName = methodNameArg~string; argSpecs = argSpecsArg
::method apply
    expose objectId methodName argSpecs
    use strict arg request
    request["object_id"] = objectId
    request["method"] = methodName
    if argSpecs \== .nil then request["args"] = argSpecs

::class ClusterSnapshotRequestMutator public
::method init
    expose objectId
    use strict arg objectIdArg
    objectId = objectIdArg~string
::method apply
    expose objectId
    use strict arg request
    request["object_id"] = objectId


/* ====================================================================== */
::class ClusterObjectMoveCoordinator public

::method init
    expose localHost client moveCounter
    use strict arg localHostArg, clientArg
    localHost = localHostArg
    client = clientArg
    moveCounter = 0

::method move
    expose localHost client moveCounter
    use strict arg objectId, destinationNode

    record = localHost~resident(objectId)
    if record == .nil then return .ClusterMoveResult~failure("OBJECT_NOT_RESIDENT")

    nextGeneration = record~generation + 1
    envelope = localHost~snapshot(objectId, nextGeneration)
    if envelope == .nil then return .ClusterMoveResult~failure("SNAPSHOT_FAILED")

    moveCounter += 1
    moveId = "move-" || localHost~nodeId || "-" || objectId || "-" || nextGeneration || "-" || moveCounter
    response = client~move(destinationNode, envelope, moveId)
    if response == .nil then return .ClusterMoveResult~failure("MOVE_UNCERTAIN")
    if .ClusterObjectCodec~value(response, "status", "") <> "OK" then return .ClusterMoveResult~failure(.ClusterObjectCodec~value(response, "code", "MOVE_FAILED"))

    payload = response["payload"]
    if payload == .nil then return .ClusterMoveResult~failure("MOVE_RESPONSE_INVALID")
    if .ClusterObjectCodec~value(payload, "object_id", "") <> objectId then return .ClusterMoveResult~failure("MOVE_RESPONSE_INVALID")
    if .ClusterObjectCodec~whole(payload, "generation", 0) <> nextGeneration then return .ClusterMoveResult~failure("MOVE_RESPONSE_INVALID")

    removed = localHost~remove(objectId, record~generation)
    if removed == .nil then return .ClusterMoveResult~failure("LOCAL_RELEASE_FAILED")
    return .ClusterMoveResult~success(objectId, destinationNode, nextGeneration)


::class ClusterMoveResult public
::method init
    expose ok code objectId ownerNode generation
    use strict arg okArg, codeArg, objectIdArg = "", ownerNodeArg = "", generationArg = 0
    ok = (okArg == .true); code = codeArg~string; objectId = objectIdArg~string; ownerNode = ownerNodeArg~string; generation = generationArg + 0
::attribute ok get
::attribute code get
::attribute objectId get
::attribute ownerNode get
::attribute generation get
::method success class
    use strict arg objectId, ownerNode, generation
    return self~new(.true, "OK", objectId, ownerNode, generation)
::method failure class
    use strict arg code
    return self~new(.false, code)


/* ====================================================================== */
/* In-process carrier for deterministic contract qualification.  It obeys the
 * same authenticated-peer service boundary as the Queue Fabric adapter. */
::class ClusterObjectLoopbackNetwork public

::method init
    expose services
    services = .directory~new

::method publish
    expose services
    use strict arg nodeId, service
    services[nodeId~string] = service
    return service

::method transportFor
    use strict arg localNodeId
    return .ClusterObjectLoopbackTransport~new(localNodeId, self)

::method deliver
    expose services
    use strict arg authenticatedFromNode, toNode, request
    service = services[toNode~string]
    if service == .nil then return .nil
    return service~handleFrom(authenticatedFromNode, request)

::class ClusterObjectLoopbackTransport public
::method init
    expose localNodeId network
    use strict arg localNodeArg, networkArg
    localNodeId = localNodeArg~string; network = networkArg
::method request
    expose localNodeId network
    use strict arg peerNodeId, request
    return network~deliver(localNodeId, peerNodeId, request)


/* ====================================================================== */
/* Optional QueueRexx / Queue Fabric binding.  This follows the same service-
 * neutral peer route shape used by StoragePeerQueueRexxBinding.  Loading this
 * package alone does not load QueueRexx or Queue Fabric. */
::class ClusterObjectQueueRexxBinding public

::method bindClient class
    use strict arg peerMesh, peerNodeId, clientId, principal = "object-client", -
                   remoteRequestQueue = "CLUSTER.OBJECT.REQUEST", timeoutMs = 10000

    localReply = "CLUSTER.OBJECT.REPLY." || clientId~string~translate
    route = peerMesh~bindServiceRoute(peerNodeId, "OBJECT.REQUEST." || clientId, -
             localReply, remoteRequestQueue, .ClusterObjectContract~SECURITY_DOMAIN, principal)
    if route == .nil | \route~ok then return route

    ignore = peerMesh~queueManager~grant(localReply, principal, "GET", peerMesh~adminPrincipal)
    d = route~value
    transport = .ClusterObjectQueueRexxClientTransport~new(peerMesh, d["remote_alias"], -
                d["sender_channel"], localReply, principal, timeoutMs)
    return .ClusterObjectBindingResult~success(transport, d)

::method bindServer class
    use strict arg peerMesh, peerNodeId, clientId, service, servicePrincipal = "object-service", -
                   remoteReplyQueue = "CLUSTER.OBJECT.REPLY."

    requestQueue = "CLUSTER.OBJECT.REQUEST"
    remoteReply = remoteReplyQueue || clientId~string~translate
    route = peerMesh~bindServiceRoute(peerNodeId, "OBJECT.REPLY." || clientId, -
             requestQueue, remoteReply, .ClusterObjectContract~SECURITY_DOMAIN, servicePrincipal)
    if route == .nil | \route~ok then return route

    ignore = peerMesh~queueManager~grant(requestQueue, servicePrincipal, "GET", peerMesh~adminPrincipal)
    d = route~value
    server = .ClusterObjectQueueRexxServer~new(peerMesh, peerNodeId, service, requestQueue, -
             d["remote_alias"], d["sender_channel"], servicePrincipal)
    return .ClusterObjectBindingResult~success(server, d)


::class ClusterObjectBindingResult public
::method init
    expose ok code detail value route
    use strict arg okArg, codeArg, detailArg, valueArg = .nil, routeArg = .nil
    ok = (okArg == .true); code = codeArg~string; detail = detailArg~string; value = valueArg; route = routeArg
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::attribute route get
::method success class
    use strict arg valueArg, routeArg = .nil
    return self~new(.true, "OK", "", valueArg, routeArg)
::method failure class
    use strict arg codeArg, detailArg = ""
    return self~new(.false, codeArg, detailArg)


::class ClusterObjectQueueRexxClientTransport public
::method init
    expose peerMesh channels manager requestAlias requestChannel replyQueue listener admin localPrincipal timeoutMs
    use strict arg peerMeshArg, requestAliasArg, requestChannelArg, replyQueueArg, principalArg, timeoutArg = 10000
    peerMesh = peerMeshArg
    channels = peerMesh~channels
    manager = peerMesh~queueManager
    listener = peerMesh~listener
    admin = peerMesh~adminPrincipal
    requestAlias = requestAliasArg~string
    requestChannel = requestChannelArg~string
    replyQueue = replyQueueArg~string
    localPrincipal = principalArg~string
    timeoutMs = timeoutArg + 0

::method request
    expose channels manager requestAlias requestChannel replyQueue listener admin localPrincipal timeoutMs
    use strict arg peerNodeId, request

    if listener \== .nil then do
        if \listener~start then return .nil
        activity = .ClusterObjectServeOneActivity~new(listener)
        ignore = activity~run
    end

    options = .table~new
    options["persistent"] = .true
    options["securityDomain"] = .ClusterObjectContract~SECURITY_DOMAIN
    options["correlationId"] = .ClusterObjectCodec~value(request, "request_id", "")

    transportOutcome = channels~put(requestAlias, request, options, localPrincipal)
    if \transportOutcome~ok then return .nil
    transportOutcome = channels~pump(requestChannel, 0, admin)
    if \transportOutcome~ok then return .nil

    loops = timeoutMs % 25
    if loops < 1 then loops = 1
    do i = 1 to loops
        got = manager~get(replyQueue, localPrincipal)
        if got~ok then return got~value~payload
        if got~code <> "QUEUE_EMPTY" then return .nil
        call SysSleep 0.025
    end
    return .nil

::class ClusterObjectServeOneActivity public
::method init
    expose listener
    use strict arg listenerArg
    listener = listenerArg
::method run
    expose listener
    reply .true
    ignore = listener~serveOne
    return

::class ClusterObjectQueueRexxServer public
::method init
    expose peerMesh service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin
    use strict arg peerMeshArg, expectedPeerArg, serviceArg, requestQueueArg, replyAliasArg, replyChannelArg, principalArg
    peerMesh = peerMeshArg
    expectedPeerNodeId = expectedPeerArg~string~strip
    service = serviceArg
    requestQueue = requestQueueArg~string
    replyAlias = replyAliasArg~string
    replyChannel = replyChannelArg~string
    servicePrincipal = principalArg~string
    if expectedPeerNodeId = "" then raise syntax 88.900 array("cluster object QueueRexx server requires authenticated peer identity")
    manager = peerMesh~queueManager
    channels = peerMesh~channels
    admin = peerMesh~adminPrincipal

::method processOne
    expose service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin
    got = manager~get(requestQueue, servicePrincipal)
    if \got~ok then return .ClusterObjectBindingResult~failure(got~code, got~detail)

    response = service~handleFrom(expectedPeerNodeId, got~value~payload)
    options = .table~new
    options["persistent"] = .true
    options["securityDomain"] = .ClusterObjectContract~SECURITY_DOMAIN
    options["correlationId"] = .ClusterObjectCodec~value(response, "request_id", "")

    transportOutcome = channels~put(replyAlias, response, options, servicePrincipal)
    if \transportOutcome~ok then return .ClusterObjectBindingResult~failure(transportOutcome~code, transportOutcome~detail)
    transportOutcome = channels~pump(replyChannel, 0, admin)
    if \transportOutcome~ok then return .ClusterObjectBindingResult~failure(transportOutcome~code, transportOutcome~detail)
    return .ClusterObjectBindingResult~success(response)
