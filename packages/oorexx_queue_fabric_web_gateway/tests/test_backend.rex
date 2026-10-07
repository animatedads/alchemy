manager=.ObjectQueueManager~new("GWTEST")
call must manager~createQueue("WIREUI.TEST.IN","TEMPORARY","WIREUI",0,"admin")
call must manager~createQueue("WIREUI.TEST.OUT","TEMPORARY","WIREUI",0,"admin")
call must manager~grant("WIREUI.TEST.IN","browser-gateway",.QueueAccess~PUT,"admin")
call must manager~grant("WIREUI.TEST.OUT","browser-gateway",.QueueAccess~GET,"admin")
call must manager~grant("WIREUI.TEST.OUT","browser-gateway",.QueueAccess~BROWSE,"admin")
backend=.QueueFabricWebGatewayBackend~new(manager,"WIREUI.TEST.IN","WIREUI.TEST.OUT","browser-gateway","secret")
ping=.directory~new; ping["bridgeToken"]="secret"; ping["op"]="PING"; r=backend~handle(ping)
if \r["ok"] | r["value"]<>"OK" then call fail "PING failed"
bad=.directory~new; bad["bridgeToken"]="wrong"; bad["op"]="PING"; r=backend~handle(bad)
if r["ok"] | r["code"]<>"BRIDGE_AUTH_FAILED" then call fail "bridge auth not enforced"
payload=.directory~new; payload["type"]="UI_ACTION"; payload["action"]="FLIGHT.SEARCH"
put=.directory~new; put["bridgeToken"]="secret"; put["op"]="PUT"; put["payload"]=payload; r=backend~handle(put)
if \r["ok"] then call fail "PUT failed"
claim=manager~claim("WIREUI.TEST.IN","admin"); call must claim
if claim~value~payload["action"]<>"FLIGHT.SEARCH" then call fail "PUT did not reach real manager"
ignore=manager~ack("WIREUI.TEST.IN",claim~value~packageId,claim~value~claimToken,"admin")
say "QUEUE FABRIC WEB GATEWAY BACKEND: OK"; exit 0
::routine must
 use arg r
 if \r~ok then call fail r~code r~detail
 return r
::routine fail
 use arg t; say "FAIL:" t; exit 1
::requires "QueueFabricWebGatewayBridge.cls"
