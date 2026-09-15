parse arg root
feed = .ShannonPnrGovParser~parseFile(root || '/examples/ourladyair_shannon_ticket_groups_v1.edi')
booking = feed~booking('G03')
session = .ShannonChatSession~new('ticket-g03', root || '/policy/ourladyair_safety_policy.txt', .nil, booking)
turn = session~respond('Drinks?')
call assertEqual 3000, turn~commercialPlan~modelGrossCents, 'model tries EUR30'
call assertEqual 2000, turn~commercialPlan~governedGrossCents, 'two adult bundles only'
call assertContains turn~finalText, 'Amaka Okafor', 'adult one offered'
call assertContains turn~finalText, 'Chidi Okafor', 'adult two offered'
call assertNotContains turn~finalText, 'Ife Okafor', 'teen removed from passenger-visible bar offers'
say 'PASS test_shannon_ticket_g03_teen_bar_block'
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return
assertContains: procedure
  use arg text, needle, label
  if text~pos(needle) = 0 then do; say 'FAIL:' label 'missing=' needle; exit 1; end
  return
assertNotContains: procedure
  use arg text, needle, label
  if text~pos(needle) > 0 then do; say 'FAIL:' label 'unexpected=' needle; exit 1; end
  return

::requires 'ShannonPnrGovParser.cls'
::requires 'ShannonChatbot.cls'
