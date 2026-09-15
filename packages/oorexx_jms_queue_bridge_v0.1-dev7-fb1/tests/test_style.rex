parse source . . here
root = filespec("L", here)
call directory root
bad = 0
files = .array~of("../src/JMSQueueBridge.cls", "../src/JMSQueueBridgeBSF.cls", "../src/JMSQueueBridgeSecrets.cls")
do file over files
  text = charin(file, 1, chars(file))
  if text~caselessPos("CALL object~") > 0 then call fail file, "CALL object~message"
  if text~caselessPos("self~attribute =") > 0 then call fail file, "pseudo-field self assignment"
  if text~caselessPos("SockConnect(") > 0 then call fail file, "raw socket API"
  if text~caselessPos("SockSend(") > 0 then call fail file, "raw socket API"
  if text~caselessPos("SockRecv(") > 0 then call fail file, "raw socket API"
end
if bad > 0 then exit 1
say "JMS BRIDGE OOREXX STYLE PASS 3"
exit 0

fail: procedure expose bad
  use arg file, what
  bad += 1
  say "FAIL" file what
return
