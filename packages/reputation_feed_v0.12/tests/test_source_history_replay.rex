t0 = .DateTime~new
t1 = t0 + .TimeSpan~new(0,0,10,0,0)
t2 = t0 + .TimeSpan~new(0,0,20,0,0)
t3 = t0 + .TimeSpan~new(0,0,30,0,0)
t4 = t0 + .TimeSpan~new(0,0,40,0,0)
t5 = t0 + .TimeSpan~new(0,0,50,0,0)
t6 = t0 + .TimeSpan~new(0,1,0,0,0)
t7 = t0 + .TimeSpan~new(0,1,10,0,0)

ledger = .ReputationSourceHistoryLedger~new
verified = .ReputationSourceAuthenticationResult~new('AUTH-1','SOURCE-A','BIND-1','PROOF-1','ED25519','KEY-1',t1,.true,'VERIFIED','ORIGIN_VERIFIED','origin verified')
call assertTrue ledger~recordAuthentication(verified), 'verified authentication recorded'

rotation = .ReputationSourceHistoryEvent~new('H-ROTATE','SOURCE-A','KEY_ROTATED',t2,'','BIND-2','KEY-2','','','key rotation declared')
rotation~seal; call assertTrue ledger~addEvent(rotation),'key rotation added'
correction = .ReputationSourceHistoryEvent~new('H-CORRECT','SOURCE-A','CORRECTION',t2,'','','','','ARTICLE-1','source issued correction')
correction~seal; call assertTrue ledger~addEvent(correction),'correction added'
compromise = .ReputationSourceHistoryEvent~new('H-COMP','SOURCE-A','COMPROMISE_DECLARED',t3,'','','','','INCIDENT-1','source key/channel compromise declared')
compromise~seal; call assertTrue ledger~addEvent(compromise),'compromise added'
restored = .ReputationSourceHistoryEvent~new('H-RESTORE','SOURCE-A','SOURCE_RESTORED',t5,'','BIND-3','KEY-3','','INCIDENT-1','source restored under replacement binding')
restored~seal; call assertTrue ledger~addEvent(restored),'restoration added'
retraction = .ReputationSourceHistoryEvent~new('H-RETRACT','SOURCE-A','RETRACTION',t5,'','','','','ARTICLE-2','source retracted earlier assertion')
retraction~seal; call assertTrue ledger~addEvent(retraction),'retraction added'
failed = .ReputationSourceAuthenticationResult~new('AUTH-2','SOURCE-A','BIND-3','PROOF-2','ED25519','KEY-3',t6,.false,'FAILED','PROOF_INVALID','later proof failed')
call assertTrue ledger~recordAuthentication(failed), 'failed authentication retained historically'

beforeCompromise = ledger~snapshotAt('SOURCE-A',t2)
call assertEqual 'VERIFIED',beforeCompromise~authenticationState,'pre-compromise replay retains verified origin state'
call assertFalse beforeCompromise~compromised,'pre-compromise replay clear'
call assertEqual 'KEY-2',beforeCompromise~currentKeyId,'key rotation visible by t2'
call assertEqual 1,beforeCompromise~correctionCount,'correction count by t2'

whileCompromised = ledger~snapshotAt('SOURCE-A',t4)
call assertTrue whileCompromised~compromised,'compromise state visible during incident'
call assertEqual 'VERIFIED',whileCompromised~authenticationState,'compromise does not rewrite earlier authentication event'

afterRestore = ledger~snapshotAt('SOURCE-A',t5)
call assertFalse afterRestore~compromised,'restoration clears explicit compromise state'
call assertEqual 1,afterRestore~retractionCount,'retraction retained'

afterFailure = ledger~snapshotAt('SOURCE-A',t7)
call assertEqual 'FAILED',afterFailure~authenticationState,'latest authentication state replayed'
call assertEqual 1,afterFailure~verifiedAuthenticationCount,'verified event count retained'
call assertEqual 1,afterFailure~failedAuthenticationCount,'failed event count retained'
call assertFalse afterFailure~hasMethod('RELIABILITYSCORE'),'history view intentionally exposes no universal reliability score'

say 'PASS test_source_history_replay events=' || afterFailure~eventCount
exit 0

assertTrue: procedure
  use arg value,label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertFalse: procedure
  use arg value,label
  if value then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'ReputationSourceAuthentication.cls'
