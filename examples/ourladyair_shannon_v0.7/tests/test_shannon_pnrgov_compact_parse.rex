parse arg root
feed = .ShannonPnrGovParser~parseFile(root || '/examples/ourladyair_shannon_ticket_groups_v1_compact.edi')
call assertEqual 7, feed~groupIds~items, 'seven compact demo groups parsed'
call assertEqual 'OOREXX_NATIVE_EDIFACT_V0.4', feed~document~parserName, 'Structured Relation native parser used'
call assertTrue feed~document~annotations~items >= 1, 'compact source annotation retained'
g07 = feed~booking('G07')
call assertEqual 3, g07~noSeatPurchaseCount, 'compact G07 retains three NSST facts'
call assertEqual 'OLAD5K1', g07~passengers[1]~pnr, 'compact PNR retained'
say 'PASS test_shannon_pnrgov_compact_parse annotations=' || feed~document~annotations~items || ' envelope=' || feed~envelopeReport~status
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
