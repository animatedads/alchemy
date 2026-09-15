parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'
booking = .ShannonBooking~new('UNKNOWN-AGE-ELIGIBILITY')
booking~addPassenger(.ShannonPassenger~new('P1', 'Mystery Adult', 'ADULT', 'BOOKING_SYSTEM', 'UNKNOWN'))
booking~seal
session = .ShannonChatSession~new('test-unknown-age-eligibility', policy, .nil, booking)
turn = session~respond('Sell me everything.')
call assertEqual 1, turn~commercialPlan~blockedCount, 'adult booking role alone is insufficient for age-restricted product'
call assertEqual 0, turn~commercialPlan~governedGrossCents, 'no age-restricted revenue without eligibility'
call assertEqual 'BLOCKED', turn~commercialPlan~decisions[1]~legalAssessment~status, 'Legal Effect blocks unknown age eligibility'
call assertNotContains turn~finalText, 'Beer + Crisps is €10', 'no beer offer emitted'
say 'PASS test_shannon_unknown_age_eligibility_beer_block'
exit 0
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return
assertNotContains: procedure
  use arg text, needle, label
  if text~pos(needle) > 0 then do; say 'FAIL:' label 'unexpected=' needle; exit 1; end
  return
::requires 'ShannonChatbot.cls'
