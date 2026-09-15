manager=.ObjectQueueManager~new("GWASYNC")
call must manager~createQueue("WIREUI.ASYNC.IN","TEMPORARY","WIREUI",0,"admin")
call must manager~createQueue("WIREUI.ASYNC.OUT","TEMPORARY","WIREUI",0,"admin")
call must manager~grant("WIREUI.ASYNC.IN","browser-gateway",.QueueAccess~PUT,"admin")
call must manager~grant("WIREUI.ASYNC.OUT","browser-gateway",.QueueAccess~GET,"admin")
call must manager~grant("WIREUI.ASYNC.OUT","browser-gateway",.QueueAccess~BROWSE,"admin")
backend=.QueueFabricWebGatewayBackend~new(manager,"WIREUI.ASYNC.IN","WIREUI.ASYNC.OUT","browser-gateway","bridge-secret")
listener=.QueueFabricWebGatewayBridgeListener~new(backend,"127.0.0.1",0)
if listener~serveAsync == .false then call fail "serveAsync did not start"
if \listener~running | listener~port<1 then call fail "listener not running"
client=.StreamSocket~new("127.0.0.1",listener~port); if client~open=-1 | client~state<>"READY" then call fail "connect failed"
request=.directory~new; request["bridgeToken"]="bridge-secret"; request["op"]="PING"; ignore=client~lineOut(.JSON~toJSON(request)); response=.JSON~fromJSON(client~lineIn); ignore=client~close
if \response["ok"] | response["value"]<>"OK" then call fail "PING failed"
payload=.directory~new; payload["type"]="ASYNC_TEST"; payload["value"]="same-manager"
client=.StreamSocket~new("127.0.0.1",listener~port); ignore=client~open; request=.directory~new; request["bridgeToken"]="bridge-secret"; request["op"]="PUT"; request["payload"]=payload; ignore=client~lineOut(.JSON~toJSON(request)); response=.JSON~fromJSON(client~lineIn); ignore=client~close
if \response["ok"] then call fail "PUT failed"
claim=manager~claim("WIREUI.ASYNC.IN","admin"); call must claim
if claim~value~payload["value"]<>"same-manager" then call fail "not same manager"
ignore=manager~ack("WIREUI.ASYNC.IN",claim~value~packageId,claim~value~claimToken,"admin")
ignore=listener~stop; call syssleep 0.20
if listener~running then call fail "listener did not stop"
say "QUEUE FABRIC WEB GATEWAY ASYNC SAME-MANAGER: OK"; exit 0
::routine must
 use arg r
 if \r~ok then call fail r~code r~detail
 return r
::routine fail
 use arg t; say "FAIL:" t; exit 1
::requires "QueueFabricWebGatewayBridge.cls"
