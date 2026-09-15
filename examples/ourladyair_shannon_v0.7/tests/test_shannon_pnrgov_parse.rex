parse arg root
feed = .ShannonPnrGovParser~parseFile(root || '/examples/ourladyair_shannon_ticket_groups_v1.edi')
call assertEqual 7, feed~groupIds~items, 'seven demo groups parsed'
call assertEqual 'OOREXX_NATIVE_EDIFACT_V0.4', feed~document~parserName, 'Structured Relation native EDIFACT parser used'
call assertEqual 17, feed~document~annotations~items, 'source annotations preserved, not stripped'
call assertEqual 'INVALID', feed~envelopeReport~status, 'deliberate demo envelope defects surfaced'
call assertEqual 17, feed~envelopeReport~findings~items, 'all deliberate envelope defects retained'

provider = feed~relationProvider
call assertEqual 25, provider~table('pnr_passengers')~readRows~items, '25 TIF rows projected as rich relation rows'
call assertEqual 28, provider~table('pnr_ssr')~readRows~items, '28 SSR rows projected as rich relation rows'

g01 = feed~booking('G01')
call assertEqual 5, g01~passengerCount, 'G01 passenger count'
call assertEqual 'PNRGOV', g01~sourceFormat, 'booking source format'
call assertEqual 'structured_relation_plugin/0.9', g01~sourceAdapter, 'source adapter identity'
call assertEqual 'INVALID', g01~sourceEnvelopeStatus, 'envelope report retained on booking'
call assertEqual 'ADULT', g01~passengers[1]~role, 'Aoife adult'
call assertEqual 'UNKNOWN', g01~passengers[2]~role, 'Sean raw PTC/DOB contradiction fails closed'
call assertEqual 'UNKNOWN', g01~passengers[2]~ageRestrictedEligibility, 'Sean alcohol eligibility unresolved'
call assertEqual 'CHILD', g01~passengers[3]~role, 'Noah child'
call assertEqual 'NOT_APPLICABLE', g01~passengers[5]~seatReservationStatus, 'infant has no own seat'
call assertTrue g01~passengers[1]~sourceEvidence~items >= 3, 'Aoife carries rich projected source evidence'
call assertTrue g01~passengers[1]~sourcePaths~items >= 3, 'Aoife source paths retained'

g04 = feed~booking('G04')
call assertTrue g04~passengers[2]~essentialMedication, 'Lily MEDA/EpiPen retained'
call assertTrue g04~passengers[2]~custodyUnknown, 'Lily custody unresolved retained'
call assertTrue g04~passengers[2]~sourceEvidence~items >= 5, 'Lily rich TIF/SSR/TKT/IFT evidence retained'

g07 = feed~booking('G07')
call assertEqual 3, g07~noSeatPurchaseCount, 'G07 no-seat-purchase facts'
call assertEqual 'NOT_PURCHASED', g07~passengers[1]~seatReservationStatus, 'G07 NSST parsed'
call assertEqual 'OLAD5K1', g07~passengers[1]~pnr, 'PNR retained'
call assertEqual '6071234567950', g07~passengers[1]~ticketNumber, 'ticket retained'

say 'PASS test_shannon_pnrgov_parse'
exit 0

assertTrue: procedure
  use arg value, label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return

::requires 'ShannonPnrGovParser.cls'
