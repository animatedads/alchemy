/*
 * Wire3DWireUIAdapter.cls
 *
 * Thin integration with the existing Wire UI / Queue Fabric access-point path.
 * Wire3D owns snapshot/delta semantics. WireUIServer owns access-point queues;
 * Queue Fabric and its Web Gateway own delivery, claims and WebSocket framing.
 */
::class Wire3DWireUIPublisher public
::attribute server get
::attribute accessPointId get

::method init
  expose server accessPointId
  use strict arg server, accessPointId
  if server == .nil then raise syntax 93.906 array ('WireUIServer')
  if server~hasMethod('ENQUEUETOACCESSPOINT') == .nil then raise syntax 93.900 array ('Wire3D requires WireUIServer enqueueToAccessPoint')

::method publishSnapshot
  expose server accessPointId
  use strict arg scene, correlationId=''
  message=.directory~new
  message['type']='WIRE3D_SNAPSHOT'
  message['protocolVersion']='WIRE-3D/0.1'
  message['sceneId']=scene~spatialId
  message['revision']=scene~revision
  message['snapshot']=scene~snapshot
  return server~enqueueToAccessPoint(accessPointId,message,correlationId)

::method publishDelta
  expose server accessPointId
  use strict arg delta, correlationId=''
  if delta == .nil then raise syntax 93.906 array ('Wire3D delta')
  if delta~isA(.Wire3DSceneDelta) then delta=delta~asDirectory
  if delta~isA(.Directory) == .false then raise syntax 93.900 array ('Wire3D delta must be Wire3DSceneDelta or Directory')
  message=.directory~new
  message['type']='WIRE3D_DELTA'
  message['protocolVersion']='WIRE-3D-DELTA/0.1'
  message['sceneId']=delta['sceneId']
  message['revision']=delta['revision']
  message['delta']=delta
  return server~enqueueToAccessPoint(accessPointId,message,correlationId)

::requires 'Wire3DCore.cls'
