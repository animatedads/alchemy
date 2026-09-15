parse arg root
feed = .ShannonPnrGovParser~parseFile(root || '/examples/ourladyair_shannon_ticket_groups_v1.edi')

/* G02 is spectacularly scattered, but every passenger already has SSR+SEAT.
 * The €20 rule is "seat not purchased", not "Shannon dislikes your seat".
 */
booking = feed~booking('G02')
session = .ShannonChatSession~new('ticket-g02', root || '/policy/ourladyair_safety_policy.txt', .nil, booking)
turn = session~respond('Can you make us sit together?')
call assertEqual 5, turn~commercialPlan~candidates~items, 'only five feral bar candidates; no seat double-sell candidates'
call assertEqual 0, turn~commercialPlan~governedGrossFor('SEAT_RESERVATION'), 'reserved seats are not charged again'
call assertNotContains turn~finalText, '€20 per passenger', 'no seat-reservation resell emitted'
say 'PASS test_shannon_ticket_reserved_seat_no_double_sell'
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return
assertNotContains: procedure
  use arg text, needle, label
  if text~pos(needle) > 0 then do; say 'FAIL:' label 'unexpected=' needle; exit 1; end
  return

::requires 'ShannonPnrGovParser.cls'
::requires 'ShannonChatbot.cls'
