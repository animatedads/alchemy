/* Bounded-connect qualification for queue.transport/2. */
start=time("E")
r=.QueueSocketConnector~connect("203.0.113.1",9,250)
elapsed=time("E")-start
if r~ok then do
  say "FAIL unexpected connection to TEST-NET-3"
  exit 1
end
if elapsed>2 then do
  say "FAIL connect was not bounded elapsed="elapsed "code="r~code "detail="r~detail
  exit 2
end
if r~code<>"CONNECT_TIMEOUT" & r~code<>"CONNECT_FAILED" & r~code<>"CONNECT_SELECT_FAILED" then do
  say "FAIL unexpected bounded-connect code" r~code r~detail
  exit 3
end
say "OBJECT QUEUE FABRIC V0.9-dev6 BOUNDED CONNECT: OK elapsed="elapsed "code="r~code
exit 0
::requires "ObjectQueueSocketTransport.cls"
