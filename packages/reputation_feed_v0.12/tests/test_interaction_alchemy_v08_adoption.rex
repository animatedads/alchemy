now=.DateTime~new
packet=.ReputationInteractionEvidencePacket~new('P','TEST','SOURCE','OBJECT','POINT','CHAT','','OUTBOUND',now,now,'GB')
packet~addContentItem(.ReputationInteractionEvidenceItem~new('I','TEST','x','ORGANISATION','RAW','SYSTEM',100,'POINT')); packet~seal
spec=.ReputationInteractionClaimSpec~new('C','F','COMMUNICATION_ACTION','ROOT'); spec~seal
objects=.array~of(packet,.ReputationFeedInteractionClaimBridge~new,.ReputationFeedInteractionEventBridge~new,.ReputationFeedStructuredUtteranceBridge~new)
do object over objects
  adoption=.AlchemyAdoptionVerifier~verify(object,'STANDARD')
  if \adoption~ok then do
    say 'FAIL: STANDARD adoption' object~class~id
    do failure over adoption~failures; say failure['code'] failure['message']; end
    exit 1
  end
  if adoption~evidence['base_version'] \= '0.8' then do; say 'FAIL: base version' object~class~id adoption~evidence['base_version']; exit 1; end
  if adoption~warnings~items \= 0 then do; say 'FAIL: adoption warnings' object~class~id adoption~warnings~items; exit 1; end
end
say 'PASS test_interaction_alchemy_v08_adoption objects='objects~items
exit 0
::requires 'ReputationFeedInteractionEventBridge.cls'
::requires 'ReputationFeedStructuredUtteranceBridge.cls'
::requires 'AlchemyAdoption.cls'
