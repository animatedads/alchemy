now = .DateTime~new
comm = .ReputationCommunicationSurface~new('COMM-SEALED')
comm~addAct('ACKNOWLEDGEMENT', 'FACTS', 'ACCEPTED')
comm~seal
call assertFalse comm~addAct('SALES_PROMPT', 'DEAL', 'SEATS'), 'sealed communication rejects late acts'
action = .ReputationActionSurface~new('ACTION-COMM-SEALED', 'ACTOR', 'CUSTOMER_COMMUNICATION', now)
action~addGeography('GB')
action~setCommunicationSurface(comm)
action~seal
call assertTrue action~canonicalText~pos('COMM-SEALED') > 0, 'communication surface is part of action canonical identity'
say 'PASS test_reputation_communication_sealing'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'ReputationEffect.cls'
