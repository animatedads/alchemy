now=.DateTime~new
source=.ReputationSourceIdentity~new('SRC','OFFICIAL','Source','','','GB','OFFICIAL_NOTICE','src-endpoint')
source~seal
env=.ReputationRawEnvelope~new('ENV',source,now,now,'TEXT/PLAIN','https://source.example/','EN','2222222222222222222222222222222222222222222222222222222222222222')
env~addSegment('BODY','x'); env~seal
binding=.ReputationSourceKeyBinding~new('BIND','SRC','ED25519','KEY','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','src-endpoint','https://source.example/')
binding~seal
auth=.ReputationSourceAuthenticator~new
ledger=.ReputationSourceHistoryLedger~new
objects=.array~of(source,env,binding,auth,ledger)
do object over objects
  adoption=.AlchemyAdoptionVerifier~verify(object,'STANDARD')
  if \adoption~ok then do
    say 'FAIL: STANDARD adoption' object~class~id
    do failure over adoption~failures; say failure['code'] failure['message']; end
    exit 1
  end
  if adoption~evidence['base_version'] \= '0.8' then do; say 'FAIL: base version' object~class~id adoption~evidence['base_version']; exit 1; end
end
say 'PASS test_alchemy_v08_adoption objects=' || objects~items
exit 0

::requires 'ReputationSourceAuthentication.cls'
::requires 'ReputationAcquisition.cls'
::requires 'AlchemyAdoption.cls'
