.QebTestFixture~installCrypto
seed='9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'
c=.QebTestFixture~catalog; j=.QebMemoryJournal~new; b=.QualificationExecutionBroker~new(c,j,.QebTestFixture~approvers)
a=.QebTestFixture~args
r=b~plan(a,'llm:test'); if \r~ok | r~code<>'PREFLIGHT_VALIDATED' then call fail 'plan failed'
if j~events~items<>0 then call fail 'plan unexpectedly created authorization state'
/* Fail preflight before any key/challenge state exists. */
bad=c~get('artifact','demo-artifact'); bad['signed']=.false
r=b~request(a,'llm:test'); if r~ok | r~code<>'ARTIFACT_NOT_RUNNABLE' then call fail 'bad artifact accepted'
if j~events~items<>0 then call fail 'failed preflight wrote run events'
bad['signed']=.true
r=b~request(a,'llm:test'); if \r~ok | r~code<>'QUALIFICATION_AWAITING_AUTHORIZATION' then call fail 'request failed'
runId=r~value['runId']
ca=.directory~new; ca['runId']=runId
ch=b~authorizationChallenge(ca,'llm:test'); if \ch~ok then call fail 'challenge failed'
msg=ch~value['messageToSign']; sig=.Ed25519~sign(msg,seed)
sub=.directory~new; sub['runId']=runId; sub['approverKeyId']='architect-ed25519'; sub['signature']=sig
r=b~authorizationSubmit(sub,'llm:test'); if \r~ok | r~value['state']<>'AUTHORIZED' then call fail 'authorization failed'
/* Mutating authorised data after signing must invalidate the frozen intent. */
data=c~get('data','demo-data'); data['manifestSha256']='abababababababababababababababababababababababababababababababab'
r=b~workerStart(runId,'worker:test'); if r~ok | r~code<>'INTENT_STALE' then call fail 'drift not detected'
st=b~status(ca,'llm:test'); if st~value['state']<>'INTENT_STALE' then call fail 'stale state absent'
/* Restore, make a second run and complete it. */
data['manifestSha256']='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
r=b~request(a,'llm:test'); run2=r~value['runId']; ca2=.directory~new; ca2['runId']=run2
ch=b~authorizationChallenge(ca2,'llm:test'); sig=.Ed25519~sign(ch~value['messageToSign'],seed)
sub['runId']=run2; sub['signature']=sig; r=b~authorizationSubmit(sub,'llm:test'); if \r~ok then call fail 'second authorization failed'
r=b~workerStart(run2,'worker:test'); if \r~ok | r~value['state']<>'RUNNING' then call fail 'worker start failed'
r=b~workerSeal(run2,'worker:test','QUALIFIED','1212121212121212121212121212121212121212121212121212121212121212','all assertions passed'); if \r~ok then call fail 'seal failed'
rr=b~results(ca2,'llm:test'); if \rr~ok | rr~value['outcome']<>'QUALIFIED' then call fail 'results failed'
/* No worker method is present in dispatch. */
r=b~dispatch('QUALIFICATION.EXECUTE',ca2,'llm:test'); if r~ok | r~code<>'UNKNOWN_OPERATION' then call fail 'LLM execute surface exists'
say 'PASS test_broker_core'
exit 0
fail: procedure
  parse arg m; say 'FAIL test_broker_core:' m; exit 1
::requires 'TestFixture.cls'
::requires 'QualificationExecutionBroker.cls'
::requires 'crypto.cls'
