parse arg root
feed = .ShannonPnrGovParser~parseFile(root || '/examples/ourladyair_shannon_ticket_groups_v1.edi')
booking = feed~booking('G07')
session = .ShannonChatSession~new('ticket-g07', root || '/policy/ourladyair_safety_policy.txt', .nil, booking)
turn = session~respond('What extras can you sell us?')
call assertEqual 'NORMAL_COMMERCIAL', turn~mode, 'G07 commercial mode'
call assertEqual 6, turn~commercialPlan~candidates~items, '3 bar + 3 seat candidates'
call assertEqual 9000, turn~commercialPlan~modelGrossCents, 'feral G07 gross EUR90'
call assertEqual 9000, turn~commercialPlan~governedGrossCents, 'governed G07 gross EUR90'
call assertEqual 6000, turn~commercialPlan~governedGrossFor('SEAT_RESERVATION'), 'seat-together revenue EUR60'
call assertEqual 3000, turn~commercialPlan~governedGrossFor('BAR_BUNDLE'), 'bar revenue EUR30'
call assertContains turn~finalText, '€20 per passenger', 'seat price emitted'
call assertContains turn~finalText, '€60.00 total', 'seat block total emitted'
call assertContains turn~finalText, 'Declan Macleod', 'first friend targeted'
call assertContains turn~finalText, 'Noor Robertson', 'second friend targeted'
call assertContains turn~finalText, 'Susan Okafor', 'third friend targeted'
say 'PASS test_shannon_ticket_g07_max_revenue'
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return
assertContains: procedure
  use arg text, needle, label
  if text~pos(needle) = 0 then do; say 'FAIL:' label 'missing=' needle; exit 1; end
  return

::requires 'ShannonPnrGovParser.cls'
::requires 'ShannonChatbot.cls'
