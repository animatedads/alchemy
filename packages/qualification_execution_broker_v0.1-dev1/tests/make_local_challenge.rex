.QebTestFixture~installCrypto
parse arg out
c=.QebTestFixture~catalog; b=.QualificationExecutionBroker~new(c,.QebMemoryJournal~new,.QebTestFixture~approvers)
r=b~request(.QebTestFixture~args,'llm:local'); q=.directory~new; q['runId']=r~value['runId']; ch=b~authorizationChallenge(q,'llm:local')
call charout out,.json~toJSON(ch~value); call stream out,'c','close'
::requires 'TestFixture.cls'
::requires 'QualificationExecutionBroker.cls'
::requires 'json.cls'
