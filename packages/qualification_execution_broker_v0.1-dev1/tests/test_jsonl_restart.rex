.QebTestFixture~installCrypto
seed='9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'
path='qeb_restart_test.jsonl'; call sysfiledelete path
c=.QebTestFixture~catalog; apps=.QebTestFixture~approvers
b=.QualificationExecutionBroker~new(c,.QebJsonlJournal~new(path),apps)
a=.QebTestFixture~args; r=b~request(a,'llm:restart'); runId=r~value['runId']; q=.directory~new; q['runId']=runId
ch=b~authorizationChallenge(q,'llm:restart'); sub=.directory~new; sub['runId']=runId; sub['approverKeyId']='architect-ed25519'; sub['signature']=.Ed25519~sign(ch~value['messageToSign'],seed)
r=b~authorizationSubmit(sub,'llm:restart'); if \r~ok then call fail 'authorization failed'
/* Reconstruct from durable journal and execute using preserved grant. */
b2=.QualificationExecutionBroker~new(c,.QebJsonlJournal~new(path),apps)
st=b2~status(q,'llm:restart'); if \st~ok | st~value['state']<>'AUTHORIZED' then call fail 'authorized state not replayed'
r=b2~workerStart(runId,'worker:restart'); if \r~ok then call fail 'worker start after replay failed'
r=b2~workerSeal(runId,'worker:restart','INCONCLUSIVE','3434343434343434343434343434343434343434343434343434343434343434','manual evidence review required'); if \r~ok then call fail 'seal failed'
b3=.QualificationExecutionBroker~new(c,.QebJsonlJournal~new(path),apps)
rr=b3~results(q,'llm:restart'); if \rr~ok | rr~value['outcome']<>'INCONCLUSIVE' then call fail 'sealed result not replayed'
call sysfiledelete path
say 'PASS test_jsonl_restart'
exit 0
fail: procedure
 parse arg m; say 'FAIL test_jsonl_restart:' m; call sysfiledelete 'qeb_restart_test.jsonl'; exit 1
::requires 'TestFixture.cls'
::requires 'QualificationExecutionBroker.cls'
::requires 'crypto.cls'
