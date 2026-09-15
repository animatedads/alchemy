now = .DateTime~new
subject = 'SESSION-PROBE'
store = .SecurityEvidenceStore~new
kinds = .array~of('ROUTE_ENUMERATION','SQL_INJECTION_CANDIDATE','ABILITY_DISCOVERY_PROBE')
i = 0
do kind over kinds
  i += 1
  o = .SecurityObservation~new('OBS-PROBE-' || i,kind,'SESSION',subject,'ABILITY_HTTP',now,90,'synthetic probe evidence')~seal
  call assertTrue store~recordObservation(o)~ok,'probe observation stored'
end
snap1 = store~snapshotFor(subject,now)
probePolicy = .SecurityProbePolicy~new('SECURITY-PROBE-POLICY','1.0',3)~seal
analysis = .SecurityProbeAnalyzer~new~analyze(snap1,probePolicy)
call assertTrue analysis~ok,'probe analysis succeeds'
call assertEqual 'ACTIVE_EXPLOIT_PROBE',analysis~value~findingKind,'three fixed-policy signals correlate active probe'
call assertTrue store~recordFinding(analysis~value)~ok,'derived finding retained'

snap2 = store~snapshotFor(subject,now)
policy = .SecurityTestSupport~basePolicy(now)
engine = .SecurityEffectEngine~new
mut = .SecurityActionSurface~new('A-PRIV-PROBE',subject,'PRIVILEGED_API_MUTATION',now,'HIGH','ADMIN_MUTATE')~seal
ass = engine~evaluate(mut,snap2,policy)~value
call assertEqual 'HOLD',ass~disposition,'derived probe finding affects privileged mutation'
say 'PASS test_probe_analyzer'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'TestSupport.cls'
