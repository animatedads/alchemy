/* Falsifying regression (Claude, Opus 4.8): open-world soundness of survivors().
 * A world SILENT about an observed field must not be eliminated; a world that
 * CONTRADICTS a modelled field must still be eliminated. */
signal on syntax name onSyntax
checks = 0
m = .WorldEnsemble~new
call populate m
m~admit('E_BANK_NEGATIVE','BANK_A_DAY','NO_MATCH','bank-export-v1','ADMITTED')
m~admit('E_HE_SAID','HE_SAID_CARD','YES','witness-utterance-v1','ADMITTED')
m~admit('E_SLIP_PICTURE','SLIP_SHOWN','YES','photo-of-slip-v1','ADMITTED')
call check m~survivors~items = 6, 'Baseline: all six worlds fit the shared observations'
call check m~assess('ACQUIRER_BATCH_ID','YES')['status'] = 'UNKNOWN_IN_MODEL', -
  'Unmodelled field QUERIED is unknown'

/* Core falsifier: an authentic on-point observation about a field none of the
 * worlds model must leave the ensemble intact (silence does not discriminate). */
m~admit('E_NEW_BATCH','ACQUIRER_BATCH_ID','YES','acquirer-batch-v3','ADMITTED')
call check m~survivors~items = 6, 'Unmodelled field OBSERVED must not delete silent worlds'
call check m~assess('ACQUIRER_BATCH_ID','YES')['status'] = 'UNKNOWN_IN_MODEL', -
  'Observed-but-unmodelled field stays unknown, never negated'
call check m~assess('SETTLED','YES')['status'] = 'UNDERDETERMINED', -
  'Silent-field evidence does not fabricate a payment conflict'

/* Guard: the repair must stay surgical -- a real contradiction still eliminates. */
c = .WorldEnsemble~new
call populate c
c~admit('E_REAL_CONTRA','BANK_A_DAY','MATCH','teller-note','ADMITTED')
call check c~survivors~items = 0, 'A contradicting observation on a modelled field still eliminates'
call check c~assess('SETTLED','YES')['status'] = 'MODEL_OR_EVIDENCE_CONFLICT', -
  'Genuine contradiction still yields conflict (not reached via silence)'

say ''
say 'OPEN-WORLD SOUNDNESS:' checks 'PASS, 0 FAIL'
exit 0

populate: procedure
  use strict arg a
  a~addWorld('W1_OTHER_CARD_PAID', world('NO_MATCH','YES','YES','YES','YES','NO','NO','HONEST'))
  a~addWorld('W2_POSTING_DELAY_PAID', world('NO_MATCH','YES','YES','YES','YES','YES','NO','HONEST'))
  a~addWorld('W3_AUTH_VOID_NO_PAYMENT', world('NO_MATCH','YES','YES','YES','NO','NO','YES','HONEST'))
  a~addWorld('W4_FORGED_SLIP_EVASION', world('NO_MATCH','YES','YES','NO','NO','NO','NO','DECEIVE'))
  a~addWorld('W5_GIFT_CARD_PAID', world('NO_MATCH','YES','YES','YES','YES','NO','NO','HONEST'))
  a~addWorld('W6_AUTH_NO_CAPTURE_DECEIVE', world('NO_MATCH','YES','YES','YES','NO','NO','YES','DECEIVE'))
  return
world: procedure
  use strict arg bank, said, slip, auth, settled, bankLater, voided, intent
  d = .directory~new
  d['BANK_A_DAY']=bank; d['HE_SAID_CARD']=said; d['SLIP_SHOWN']=slip
  d['CARD_AUTH']=auth; d['SETTLED']=settled; d['BANK_A_LATER']=bankLater
  d['VOIDED']=voided; d['INTENT']=intent
  return d
check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok == .true | ok == 1 then do; say 'PASS:' label; return; end
  say 'FAIL:' label
  exit 1
onSyntax:
  say 'SYNTAX line' sigl':' condition('D'); exit 2
::requires 'WorldEnsemble.cls'
