call load
root="/tmp/fbbranchday-queue-"||time("S")||"-"||random(100000,999999); codec=.FederationBankBranchDayServicePersistenceSupport~newCodec; manager=.ObjectQueueManager~new(root,codec,"queue-admin"); s=.FBBranchDayServiceTest~service; d=.FBBranchDayServiceTest~create(s,"DAY-Q")
worker=.FederationBankBranchDayQueueWorker~new(s,manager,"FB.BRANCH.DAY.CMD","FB.BRANCH.DAY.EVT","fb-branch-day-service","queue-admin","PERMANENT"); .FBBranchDayServiceTest~assertTrue(worker~install~ok); ignore=manager~grant("FB.BRANCH.DAY.CMD","client",.QueueAccess~PUT,"queue-admin")
es=.FBBranchDayServiceTest~endpoints; ps=.FBBranchDayServiceTest~positions; maker="MGR-A"; apr=.FederationBankBranchDayApproval~new("APR-Q",d~openActionIdentity(es,ps,maker),"MGR-B","AUTH:MGR-B"); p=.directory~new; p["dayId"]=d~dayId; p["endpoints"]=es; p["positions"]=ps; p["requestedBy"]=maker; p["approval"]=apr; env=.FederationBankBranchDayServiceEnvelope~new("CMD-Q","FBBRANCHDAY.DAY.OPEN",maker,p,"CORR-Q"); o=.table~new; o["persistent"]=.true; .FBBranchDayServiceTest~assertTrue(manager~put("FB.BRANCH.DAY.CMD",env,o,"client")~ok)
codec2=.FederationBankBranchDayServicePersistenceSupport~newCodec; manager2=.ObjectQueueManager~new(root,codec2,"queue-admin"); s2=.FBBranchDayServiceTest~service; d2=.FBBranchDayServiceTest~create(s2,"DAY-Q"); worker2=.FederationBankBranchDayQueueWorker~new(s2,manager2,"FB.BRANCH.DAY.CMD","FB.BRANCH.DAY.EVT","fb-branch-day-service","queue-admin","PERMANENT"); .FBBranchDayServiceTest~assertTrue(worker2~install~ok); r=worker2~processOne; .FBBranchDayServiceTest~assertTrue(r~ok); .FBBranchDayServiceTest~assertTrue(r~value~ok); .FBBranchDayServiceTest~assertEq(s2~day("DAY-Q")~state,"OPEN")
say "PASS: permanent Queue Fabric recovers typed Branch Day evidence graph before consumption"
exit 0
load: return
::requires "FederationBankBranchDayServiceQueue.cls"
::requires "TestSupport.cls"
