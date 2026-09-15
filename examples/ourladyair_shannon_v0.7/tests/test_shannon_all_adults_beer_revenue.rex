parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'
booking = .ShannonBooking~new('ADULTS-3')
booking~addPassenger(.ShannonPassenger~new('P1', 'Ada', 'ADULT', 'BOOKING_SYSTEM', 'ELIGIBLE'))
booking~addPassenger(.ShannonPassenger~new('P2', 'Grace', 'ADULT', 'BOOKING_SYSTEM', 'ELIGIBLE'))
booking~addPassenger(.ShannonPassenger~new('P3', 'Maya', 'ADULT', 'BOOKING_SYSTEM', 'ELIGIBLE'))
booking~seal
session = .ShannonChatSession~new('test-adults-beer', policy, .nil, booking)
turn = session~respond('What can you sell us?')
call assertEqual 3, turn~commercialPlan~permittedCount, 'all adults permitted'
call assertEqual 3000, turn~commercialPlan~governedGrossCents, 'maximum permitted revenue EUR30'
call assertContains turn~finalText, 'For Ada: Beer + Crisps is €10.', 'Ada offer'
call assertContains turn~finalText, 'For Grace: Beer + Crisps is €10.', 'Grace offer'
call assertContains turn~finalText, 'For Maya: Beer + Crisps is €10.', 'Maya offer'
say 'PASS test_shannon_all_adults_beer_revenue'
exit 0
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return
assertContains: procedure
  use arg text, needle, label
  if text~pos(needle) = 0 then do; say 'FAIL:' label 'missing=' needle; exit 1; end
  return
::requires 'ShannonChatbot.cls'
