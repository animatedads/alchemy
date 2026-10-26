/* Synthetic red-team benchmark. Pure ooRexx 5.3. Zero personal-case data.
 * All worlds are hypothetical and do not jointly exhaust possible reality.
 * Architecture: hypothesis/observation split; implementation: ChatGPT GPT-6.
 */
signal on syntax name onSyntax
checks = 0
m = .WorldEnsemble~new

/* Six mutually distinguishable possibilities with identical first observations.
 * BANK_A_DAY: no matching posted payment on date of meal, as observed by investigator.
 * HE_SAID_CARD: the witness said 'I paid by card'; doesn't certify actual payment.
 * SLIP_SHOWN: a displayed slip, not necessarily authenticated.
 * CARD_AUTH: actual card authorization, not necessarily a captured settlement.
 * SETTLED: merchant eventually receives payment for the dinner.
 * INTENT: HONEST or DECEIVE as a hypothetical truth, not an inferred mental state. */
m~addWorld('W1_OTHER_CARD_PAID', world('NO_MATCH','YES','YES','YES','YES','NO','NO','HONEST'))
m~addWorld('W2_POSTING_DELAY_PAID', world('NO_MATCH','YES','YES','YES','YES','YES','NO','HONEST'))
m~addWorld('W3_AUTH_VOID_NO_PAYMENT', world('NO_MATCH','YES','YES','YES','NO','NO','YES','HONEST'))
m~addWorld('W4_FORGED_SLIP_EVASION', world('NO_MATCH','YES','YES','NO','NO','NO','NO','DECEIVE'))
m~addWorld('W5_GIFT_CARD_PAID', world('NO_MATCH','YES','YES','YES','YES','NO','NO','HONEST'))
m~addWorld('W6_AUTH_NO_CAPTURE_DECEIVE', world('NO_MATCH','YES','YES','YES','NO','NO','YES','DECEIVE'))

say 'THE VANISHING DINNER / OPEN-WORLD COUNTERMODEL BENCHMARK'
/* At this point we know only what has been searched and what was said/shown. */
m~admit('E_BANK_NEGATIVE', 'BANK_A_DAY', 'NO_MATCH', 'bank-export-v1', 'ADMITTED')
m~admit('E_HE_SAID', 'HE_SAID_CARD', 'YES', 'witness-utterance-v1', 'ADMITTED')
m~admit('E_SLIP_PICTURE', 'SLIP_SHOWN', 'YES', 'photo-of-slip-v1', 'ADMITTED')
call check m~survivors~items = 6, 'Every world fits the accurate initial observations'
call check m~assess('SETTLED','YES')['status'] = 'UNDERDETERMINED', 'No observed bank charge does not establish nonpayment'
call check m~assess('INTENT','DECEIVE')['status'] = 'UNDERDETERMINED', 'No observed bank charge does not establish fraudulent intent'
call check m~assess('BANK_A_DAY','NO_MATCH')['status'] = 'HOLDS_IN_LISTED_WORLDS_ONLY', 'Exact observed no-match remains true in all worlds'
call check m~assess('HE_SAID_CARD','YES')['status'] = 'HOLDS_IN_LISTED_WORLDS_ONLY', 'Statement occurrence is not its factual truth'
call check m~assess('SETTLED','YES')['actualTruthProven'] = .false, 'Enumerated worlds never certify external event truth'
pair = m~indistinguishablePair('SETTLED')
call check pair~items = 2, 'Constructed indistinguishable worlds with opposite payment states'
say 'COUNTERMODEL PAYMENT: ' pair[1] ' vs ' pair[2]
pair = m~indistinguishablePair('INTENT')
call check pair~items = 2, 'Constructed indistinguishable worlds with opposite intent states'
say 'COUNTERMODEL INTENT: ' pair[1] ' vs ' pair[2]

/* Intentionally suspicious duplications: copies are not independent sources. */
m~admit('E_BANK_MIRROR', 'BANK_A_DAY', 'NO_MATCH', 'bank-export-v1', 'ADMITTED')
m~admit('E_BANK_PDF', 'BANK_A_DAY', 'NO_MATCH', 'bank-export-v1', 'ADMITTED')
call check m~distinctRoots('BANK_A_DAY') = 1, 'Three restatements of one bank export count as one provenance root'
call check m~survivors~items = 6, 'Repeated reporting does not strengthen the logical constraint'

/* A witness's extra claim is not a verified measurement. */
m~admit('E_WITNESS_I_USED_A', 'USED_BANK_A_CARD', 'YES', 'witness-utterance-v1', 'REPORTED')
call check m~survivors~items = 6, 'Unadmitted allegation cannot eliminate worlds'

/* An authentic card authorization exists: still not proof of settlement. */
m~admit('E_POS_AUTH', 'CARD_AUTH', 'YES', 'acquirer-auth-log-v2', 'ADMITTED')
call check m~survivors~items = 5, 'Authenticated authorization eliminates forged-slip world only'
call check m~assess('SETTLED','YES')['status'] = 'UNDERDETERMINED', 'Authorization does not entail merchant settlement'
call check m~assess('INTENT','DECEIVE')['status'] = 'UNDERDETERMINED', 'Authorization does not establish payer intent'

/* A merchant settlement record, if on-point and authenticated, discriminates the key proposition. */
paid = .WorldEnsemble~new
call populate(paid)
call sharedEvidence(paid)
paid~admit('E_ACQUIRER_CAPTURE', 'SETTLED', 'YES', 'acquirer-settlement-ledger', 'ADMITTED')
call check paid~survivors~items = 3, 'Settlement evidence excludes unpaid modeled worlds'
call check paid~assess('SETTLED','YES')['status'] = 'HOLDS_IN_LISTED_WORLDS_ONLY', 'Merchant settlement is determined within listed world models'
call check paid~assess('SETTLED','YES')['actualTruthProven'] = .false, 'Model entailment remains narrower than authenticated real-world fact'
call check paid~assess('INTENT','DECEIVE')['status'] = 'REFUTED_IN_LISTED_WORLDS_ONLY', 'Synthetic scenario explicitly ties paid worlds to honest intent'

/* A void log narrows the same evidence in the other direction, still leaves intent unresolved. */
unpaid = .WorldEnsemble~new
call populate(unpaid)
call sharedEvidence(unpaid)
unpaid~admit('E_VOID', 'CARD_AUTH', 'YES', 'acquirer-auth-log-v2', 'ADMITTED')
unpaid~admit('E_NO_SETTLEMENT', 'SETTLED', 'NO', 'merchant-reconciliation-v2', 'ADMITTED')
call check unpaid~survivors~items = 2, 'Verified authorization with no settlement retains honest/error and deliberate worlds'
call check unpaid~assess('INTENT','DECEIVE')['status'] = 'UNDERDETERMINED', 'Demonstrated nonpayment still does not establish dishonesty'
call check unpaid~partition('INTENT')~items = 2, 'Intent cannot be inferred without discriminating evidence'

/* No surviving model means possible bad evidence, bad schema or incomplete hypotheses,
 * never explosion into arbitrary truth. */
unpaid~admit('E_CONTRADICTION', 'SETTLED', 'YES', 'new-conflicting-ledger', 'ADMITTED')
call check unpaid~survivors~items = 0, 'Contradictory admitted observations do not silently select a winner'
call check unpaid~assess('INTENT','DECEIVE')['status'] = 'MODEL_OR_EVIDENCE_CONFLICT', 'Zero models must not imply anything whatever'
call check unpaid~assess('INTENT','DECEIVE')['actualTruthProven'] = .false, 'Contradiction does not create truth authority'

/* Chronology/replay: adding observations does not rewrite the original negative search. */
call check paid~assess('BANK_A_DAY','NO_MATCH')['status'] = 'HOLDS_IN_LISTED_WORLDS_ONLY', 'Later settlement evidence does not rewrite earlier bank search'
call check paid~distinctRoots('BANK_A_DAY') = 1, 'Provenance remains consistent through belief revision'
call check paid~distinctRoots('SETTLED') = 1, 'One acquirer feed is one root, not magically a quorum'

/* A deliberately unmodelled property is not automatically false. */
call check paid~assess('SECRET_THIRD_PARTY', 'YES')['status'] = 'UNKNOWN_IN_MODEL', 'Unmodelled fact remains unknown, never negated'
call check paid~assess('SECRET_THIRD_PARTY', 'YES')['actualTruthProven'] = .false, 'Open world remains open'

/* Search-scope adversary: the same accurate no-match can support one narrow
 * absence claim but cannot be used for a wider claim about payment or intent. */
search = .NegativeSearch~new('S1', 'BANK_A', 'POSTED', 'POSTING_DATE', -
  'DAY_D', 'COMPLETE', 'VERIFIED')
call check search~result = 'NO_MATCH', 'The exact observed no-match is preserved'
call check search~evaluate('BANK_A','POSTED','POSTING_DATE','DAY_D')['assessment'] = -
 'SCOPED_NEGATIVE_SUPPORT_ONLY', 'Verified complete exact search supports a narrow negative claim'
call check search~evaluate('ANY_CARD','POSTED','POSTING_DATE','DAY_D')['assessment'] = -
 'NO_VALID_ABSENCE_INFERENCE', 'Bank-A search cannot exclude other payment cards'
call check search~evaluate('BANK_A','AUTHORIZATION','POSTING_DATE','DAY_D')['assessment'] = -
 'NO_VALID_ABSENCE_INFERENCE', 'Posted transactions are not authorizations'
call check search~evaluate('BANK_A','POSTED','TRANSACTION_DATE','DAY_D')['assessment'] = -
 'NO_VALID_ABSENCE_INFERENCE', 'Posting-date search is not transaction-date search'
call check search~evaluate('BANK_A','POSTED','POSTING_DATE','D_THROUGH_D_PLUS_7')['assessment'] = -
 'NO_VALID_ABSENCE_INFERENCE', 'One-day search does not prove the longer settlement window'
call check search~evaluate('BANK_A','POSTED','POSTING_DATE','DAY_D')['truthProven'] = .false, -
 'Source scope validity is not an external truth certificate'
partial = .NegativeSearch~new('S2','BANK_A','POSTED','POSTING_DATE',- 
 'DAY_D','INCOMPLETE','VERIFIED')
call check partial~evaluate('BANK_A','POSTED','POSTING_DATE','DAY_D')['assessment'] = -
 'NO_VALID_ABSENCE_INFERENCE', 'Incomplete source blocks negative inference even for matching search'
unverified = .NegativeSearch~new('S3','BANK_A','POSTED','POSTING_DATE',- 
 'DAY_D','COMPLETE','UNVERIFIED')
call check unverified~evaluate('BANK_A','POSTED','POSTING_DATE','DAY_D')['assessment'] = -
 'NO_VALID_ABSENCE_INFERENCE', 'Unverified source cannot quietly supply certified absence'
call check partial~evaluate('BANK_A','POSTED','POSTING_DATE','DAY_D')['errors']~items = 1, -
 'Coverage gap is explained precisely without inventing other failures'

say ''
say 'QUALIFICATION:' checks 'PASS, 0 FAIL'
say 'This checks fixture semantics, not external forensic truth.'
exit 0

world: procedure
  use strict arg bank, said, slip, auth, settled, bankLater, voided, intent
  d = .directory~new
  d['BANK_A_DAY'] = bank; d['HE_SAID_CARD'] = said; d['SLIP_SHOWN'] = slip
  d['CARD_AUTH'] = auth; d['SETTLED'] = settled; d['BANK_A_LATER'] = bankLater
  d['VOIDED'] = voided; d['INTENT'] = intent
  return d

populate: procedure
  use strict arg a
  a~addWorld('W1_OTHER_CARD_PAID', world('NO_MATCH','YES','YES','YES','YES','NO','NO','HONEST'))
  a~addWorld('W2_POSTING_DELAY_PAID', world('NO_MATCH','YES','YES','YES','YES','YES','NO','HONEST'))
  a~addWorld('W3_AUTH_VOID_NO_PAYMENT', world('NO_MATCH','YES','YES','YES','NO','NO','YES','HONEST'))
  a~addWorld('W4_FORGED_SLIP_EVASION', world('NO_MATCH','YES','YES','NO','NO','NO','NO','DECEIVE'))
  a~addWorld('W5_GIFT_CARD_PAID', world('NO_MATCH','YES','YES','YES','YES','NO','NO','HONEST'))
  a~addWorld('W6_AUTH_NO_CAPTURE_DECEIVE', world('NO_MATCH','YES','YES','YES','NO','NO','YES','DECEIVE'))
  return

sharedEvidence: procedure
  use strict arg a
  a~admit('E_BANK_NEGATIVE', 'BANK_A_DAY', 'NO_MATCH', 'bank-export-v1', 'ADMITTED')
  a~admit('E_HE_SAID', 'HE_SAID_CARD', 'YES', 'witness-utterance-v1', 'ADMITTED')
  a~admit('E_SLIP_PICTURE', 'SLIP_SHOWN', 'YES', 'photo-of-slip-v1', 'ADMITTED')
  return

check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok == .true | ok == 1 then do
    say 'PASS:' label
    return
  end
  say 'FAIL:' label
  exit 1

onSyntax:
  say 'SYNTAX ERROR line' sigl ':' condition('D')
  exit 2

::requires 'WorldEnsemble.cls'
