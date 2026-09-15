now = .DateTime~new
subject = 'CUSTOMER-1'
store = .SecurityEvidenceStore~new
london = .SecurityObservation~new('OBS-LON','AUTHENTICATED_LOCATION','ACCOUNT',subject,'WEB',now - .TimeSpan~new(0,0,30,0,0),100,'London known network')
london~putMetadata('COUNTRY','GB')
call assertTrue store~recordObservation(london~seal)~ok,'London observation stored'
kz = .SecurityObservation~new('OBS-KZ','AUTHENTICATED_LOCATION','ACCOUNT',subject,'WEB',now,100,'Kazakhstan unfamiliar network')
kz~putMetadata('COUNTRY','KZ')
call assertTrue store~recordObservation(kz~seal)~ok,'Kazakhstan observation stored'
call assertTrue store~recordFinding(.SecurityTestSupport~geoFinding(subject,now))~ok,'geo finding stored'
call assertTrue store~recordFinding(.SecurityTestSupport~finding('F-DEVICE','UNFAMILIAR_DEVICE',subject,now))~ok,'device finding stored'
call assertTrue store~recordFinding(.SecurityTestSupport~finding('F-VPN','VPN_USAGE_UNKNOWN',subject,now,'SECURITY_EFFECT','UNKNOWN'))~ok,'VPN unknown retained'
snap = store~snapshotFor(subject,now)
policy = .SecurityTestSupport~basePolicy(now)
engine = .SecurityEffectEngine~new

gold = .SecurityActionSurface~new('A-GOLD',subject,'PURCHASE',now,'HIGH','PAYMENT')
gold~putAttribute('PAYMENT_INSTRUMENT','STORED')
gold~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
gold~putAttribute('AMOUNT',20000)
gold~seal
ass = engine~evaluate(gold,snap,policy)~value
call assertEqual 'HOLD',ass~disposition,'gold transaction held'
call assertTrue ass~containsConstraint('OUT_OF_BAND_CONFIRMATION_REQUIRED'),'OOB confirmation required'
call assertTrue ass~containsConstraint('FREEZE_RECOVERY_CHANNEL_MUTATION'),'recovery mutation frozen'
call assertTrue .SecurityCanonical~containsString(ass~trace~traces[1]~findingIds,'F-GEO-1'),'decision trace names causal finding'
call assertTrue .SecurityCanonical~containsString(ass~unaffectedAbilities,'CUSTOMER_SERVICE_CONVERSATION'),'Shannon conversation expressly unaffected'

phone = .SecurityActionSurface~new('A-PHONE',subject,'CHANGE_VERIFIED_PHONE',now,'HIGH','RECOVERY_PHONE')~seal
p = engine~evaluate(phone,snap,policy)~value
call assertEqual 'HOLD',p~disposition,'phone mutation held'

booking = .SecurityActionSurface~new('A-BOOKING',subject,'READ_BOOKING_STATUS',now,'LOW','BOOKING_STATUS_READ')~seal
b = engine~evaluate(booking,snap,policy)~value
call assertEqual 'ALLOW',b~disposition,'ordinary booking read remains allowed'
say 'PASS test_kazakhstan_gold'
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
