parse arg mode req resp key variant
if mode="request" then do
  nonce="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  node="MN1-ED209F"; count=1000
  if variant="wrong-target" then node="MN2-ED209F"
  if variant="out-of-bounds" then count=1001
  command=.QueueRecordCodec~encode("RTO2_WORK",.array~of("queue.transport/2","FIELD-TEST",node,count,1))
  data=.QueueXTPWire~request(key,"TEST-CORR","GRID.MU.MU-ED209F","GRID.MN.MN1-ED209F","RTO2.MN1-ED209F","grid-controller","k1",nonce,command)
  s=.stream~new(req);s~open("write replace");s~charout(data);s~close
  say "PASS request";exit 0
end
if mode="reject" then do
  s=.stream~new(resp);s~open("read");data=s~charin(,s~chars);s~close
  d=.QueueXTPWire~open(key,data,"RESP")
  if \d~ok then do; say "FAIL unauthenticated rejection"; exit 12;end
  row=.QueueRecordCodec~decode(d~value["plaintext"])
  if row==.nil | row[1]<>"RESULT" | row[4]<>variant then do; say "FAIL rejected code";exit 13;end
  say "PASS authenticated rejection" variant;exit 0
end
if mode="response" then do
  s=.stream~new(resp);s~open("read");data=s~charin(,s~chars);s~close
  d=.QueueXTPWire~open(key,data,"RESP")
  if \d~ok then do; say "FAIL RESPONSE AUTH" d~code;exit 1;end
  row=.QueueRecordCodec~decode(d~value["plaintext"])
  if row==.nil then do; say "FAIL UNDECODABLE";exit 2;end
  if row[1]<>"RTO2_WORK_RESULT" then do; say "FAIL" row[1] row[4];exit 3;end
  r=.json~fromJson(row[3])
  if r["committed_value"]<>500500 | r["node_id"]<>"MN1-ED209F" | r["rto2_api"]<>"alchemy.rto/0.1" then do; say "FAIL RESULT";exit 4;end
  say "PASS authenticated RTO2 execution" r["value"] r["rto2_api"]
  exit 0
end
exit 64
::requires "ObjectQueueXTPTransport.cls"
::requires "json.cls"
