/* Persistence and compact token-stream tests for CameraCore.cls */

say 'CAMERA PERSISTENCE SMOKE START'

camera = .CameraModel~new('CAMPERSIST', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 60 * 60))
road = .CameraBox~new('ROAD', 0, 80, 640, 220, camera~rootRegion)

/* Learn R1 and some zones/events. */
call feedPath camera, road, 900, 100, 150, 20, 0, 5
call expireTracks camera, 906
call feedPath camera, road, 1000, 102, 152, 20, 0, 5
call expireTracks camera, 1006

call assertEqual 'one learned route', 1, camera~routeModel~routeCount
call assertTrue 'zones learned', camera~spatialModel~zones~zoneCount >= 2
call assertTrue 'events learned', camera~eventGrammar~eventCount > 0

/* Encode derived behaviour into a compact binary stream. */
streamer = .CameraEventStream~new(camera~tokenDictionary)
streamer~appendEvents(camera~eventGrammar~events)
byteCount = streamer~byteCount
call assertTrue 'event stream has bytes', byteCount > 5
call assertTrue 'event stream far smaller than simple 64-byte/event records', byteCount < (camera~eventGrammar~eventCount * 64)

decoded = streamer~decode
call assertEqual 'roundtrip event count', camera~eventGrammar~eventCount, decoded~items
firstOriginal = camera~eventGrammar~events[1]
firstDecoded = decoded[1]
call assertEqual 'roundtrip first event type', firstOriginal~eventType, firstDecoded~eventType
call assertEqual 'roundtrip first timestamp', firstOriginal~timestamp, firstDecoded~timestamp
call assertEqual 'roundtrip first track id', firstOriginal~trackAId, firstDecoded~trackAId

/* Dictionary and learned camera state survive an actual filesystem round trip. */
snapshotPath = '/tmp/camera_v07.snapshot'
streamPath = '/tmp/camera_v07.events'
saved = .CameraModelPersistence~save(camera, snapshotPath)
writtenBytes = streamer~write(streamPath)
call assertEqual 'snapshot save succeeded', 1, saved
call assertEqual 'stream write reports byte count', byteCount, writtenBytes
call assertTrue 'snapshot written', stream(snapshotPath, 'c', 'query size') > 0
call assertEqual 'binary stream size matches byte count', byteCount, stream(streamPath, 'c', 'query size')

loadedCamera = .CameraModelPersistence~load(snapshotPath)
call assertTrue 'camera reload succeeded', loadedCamera \== .nil
call assertEqual 'camera id preserved', camera~id, loadedCamera~id
call assertEqual 'route count preserved', camera~routeModel~routeCount, loadedCamera~routeModel~routeCount
call assertEqual 'zone count preserved', camera~spatialModel~zones~zoneCount, loadedCamera~spatialModel~zones~zoneCount
call assertEqual 'window count preserved', camera~behaviour~windows~items, loadedCamera~behaviour~windows~items
call assertEqual 'token count preserved', camera~tokenDictionary~count, loadedCamera~tokenDictionary~count
originalRouteToken = camera~tokenDictionary~tokenFor('ROUTE:R1')
loadedRouteToken = loadedCamera~tokenDictionary~tokenFor('ROUTE:R1')
call assertEqual 'R1 token identity preserved', originalRouteToken, loadedRouteToken

streamSize = stream(streamPath, 'c', 'query size')
binaryBytes = charin(streamPath, 1, streamSize)
call stream streamPath, 'c', 'close'
loadedStreamer = .CameraEventStream~new(loadedCamera~tokenDictionary)
loadedDecoded = loadedStreamer~decode(binaryBytes)
call assertEqual 'reloaded dictionary decodes stream count', decoded~items, loadedDecoded~items
call assertEqual 'reloaded dictionary decodes R1', decoded[decoded~items]~routeId, loadedDecoded[loadedDecoded~items]~routeId

originalRoute = camera~routeModel~routes['R1']
loadedRoute = loadedCamera~routeModel~routes['R1']
call assertTrue 'R1 restored', loadedRoute \== .nil
call assertNear 'R1 entry x preserved', originalRoute~meanEntryX, loadedRoute~meanEntryX, 0.0001
call assertNear 'R1 exit x preserved', originalRoute~meanExitX, loadedRoute~meanExitX, 0.0001

/* A post-reload matching track must continue using R1 rather than creating a new route. */
loadedRoad = .CameraBox~new('ROAD', 0, 80, 640, 220, loadedCamera~rootRegion)
call feedPath loadedCamera, loadedRoad, 1100, 101, 151, 20, 0, 5
call expireTracks loadedCamera, 1106
reloadedTrack = loadedCamera~tracks['T1']
call assertEqual 'reloaded camera reuses persistent R1', 'R1', reloadedTrack~routeId
call assertEqual 'route dictionary remains one route', 1, loadedCamera~routeModel~routeCount

say '  derived events:' camera~eventGrammar~eventCount
say '  binary bytes:  ' byteCount
say '  bytes/event:   ' format(byteCount / camera~eventGrammar~eventCount,, 2)
say 'CAMERA PERSISTENCE SMOKE: OK'
exit 0

feedPath: procedure
  use arg cameraObject, parentRegion, startSecond, startX, startY, deltaX, deltaY, pointCount
  do step = 0 to pointCount - 1
    observations = .array~new
    movingBox = .CameraBox~new('P' || startSecond || '_' || step, startX + (deltaX * step), startY + (deltaY * step), 24, 40, parentRegion)
    observations~append(.CameraObservation~new(startSecond + step, movingBox, 0.04, 0.50))
    cameraObject~observeFrame(startSecond + step, observations)
  end
  return

expireTracks: procedure
  use arg cameraObject, firstEmptySecond
  emptyObservations = .array~new
  cameraObject~observeFrame(firstEmptySecond, emptyObservations)
  cameraObject~observeFrame(firstEmptySecond + 1, emptyObservations)
  cameraObject~observeFrame(firstEmptySecond + 2, emptyObservations)
  return

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertNear: procedure
  use arg label, expected, actual, tolerance
  if abs(expected - actual) <= tolerance then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label, actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  say '  actual:' actual
  exit 1

::requires 'CameraCore.cls'
