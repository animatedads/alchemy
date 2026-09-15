/* Queue Fabric integration smoke: UI_ACTION arrives on direct queue and response can leave on direct queue. */
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
topics = .QueueTopicFabric~new(manager)
server = .WireUIServer~new(manager, topics, "admin")
call must server~provisionAccessPoint("AP-Q", "browser"), "provision"

view = .WireUIView~new("QueueView", "root")
slots = .table~new; slots["action"] = "PING"; slots["value"] = "idle"
call must view~createInstance("root", "PING_ACTION", slots), "instance"
view~setActionAvailable("root", "PING", .true)
projection = .WireUIProjection~new
projection~bind("state", "root", "value")
app = .QueueDemoApp~new("APP-Q", "SESSION-Q", "AP-Q", view, projection)
server~registerApplication(app)

m = .table~new
m["type"] = .WireUIProtocol~UI_ACTION
m["messageId"] = "queue-msg-1"
m["applicationId"] = "APP-Q"
m["sessionId"] = "SESSION-Q"
m["accessPointId"] = "AP-Q"
m["viewRef"] = "QueueView"
m["elementInstance"] = "root"
m["action"] = "PING"
m["renderedRevision"] = 0
call must manager~put("WIREUI.IN.AP-Q", m, .table~new, "browser"), "browser put"
r = server~receiveFromAccessPoint("AP-Q", "browser")
call must r, "server receive"
patches = app~drainOutbound
call expect patches~items = 1, "patch generated"
call must server~enqueueToAccessPoint("AP-Q", patches[1], "queue-msg-1"), "server outbound"
package = manager~browse("WIREUI.OUT.AP-Q", "browser")~value
call expect package~payload["type"] = .WireUIProtocol~UI_VIEW_PATCH, "direct queue carries patch"
say "PASS queue integration"
exit 0

must: procedure
  use arg r, label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
  return
expect: procedure
  use arg c, label
  if \c then do; say "FAIL" label; exit 1; end
  say "ok" label
  return

::class QueueDemoApp subclass WireUIApplication
::method dispatchSemanticAction
  use arg action, message
  if action = "PING" then do
    ignore = self~mutateState("state", "pong")
    return .WireUIResult~success("pong")
  end
  return .WireUIResult~failure("UNKNOWN_ACTION", action)

::requires "WireUIAll.cls"
::requires "WireUIServer.cls"
