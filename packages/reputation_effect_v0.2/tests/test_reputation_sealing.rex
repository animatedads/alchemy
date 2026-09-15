now = .DateTime~new
event = .ReputationTestSupport~boeingIncident('SEALED-EVENT', now, 'NONE')
call assertFalse event~addConcept('LATE_MUTATION'), 'sealed event rejects mutation'
snapshot = .ReputationTestSupport~snapshot('SEALED-SNAPSHOT', now, now, .array~of('GB'), .array~of(event))~seal
call assertFalse snapshot~addCoverageGeography('GR'), 'sealed snapshot rejects mutation'
snapshotText = snapshot~canonicalText
call assertTrue snapshotText~pos('SEALED-SNAPSHOT') > 0, 'sealed snapshot canonicalises'
action = .ReputationActionSurface~new('SEALED-ACTION', 'OURLADYAIR', 'ADVERTISING', now)
action~addGeography('GB')
action~seal
call assertFalse action~addConcept('LATE_MUTATION'), 'sealed action rejects mutation'
text = event~canonicalText
call assertTrue text~pos('SEALED-EVENT') > 0, 'sealed event canonicalises'
say 'PASS test_reputation_sealing'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'ReputationTestSupport.cls'
