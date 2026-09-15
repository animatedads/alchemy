parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'
booking = .ShannonBooking~new('FAMILY-1')
booking~addPassenger(.ShannonPassenger~new('P1', 'Parent', 'ADULT', 'BOOKING_SYSTEM', 'ELIGIBLE'))
booking~addPassenger(.ShannonPassenger~new('P2', 'Kid One', 'CHILD', 'BOOKING_SYSTEM', 'INELIGIBLE'))
booking~addPassenger(.ShannonPassenger~new('P3', 'Kid Two', 'CHILD', 'BOOKING_SYSTEM', 'INELIGIBLE'))
booking~seal
session = .ShannonChatSession~new('test-family-beer', policy, .nil, booking)
turn = session~respond('What can you sell us?')
call assertEqual 'NORMAL_COMMERCIAL', turn~mode, 'normal commercial mode'
call assertEqual 3, turn~commercialPlan~candidates~items, 'feral model proposes to every passenger'
call assertEqual 3000, turn~commercialPlan~modelGrossCents, 'feral gross is EUR30'
call assertEqual 1, turn~commercialPlan~permittedCount, 'only adult offer permitted'
call assertEqual 2, turn~commercialPlan~blockedCount, 'two child offers blocked'
call assertEqual 1000, turn~commercialPlan~governedGrossCents, 'governed gross is EUR10'
call assertContains turn~modelProposal~text, 'Parent', 'model targets parent'
call assertContains turn~modelProposal~text, 'Kid One', 'model also tries child one'
call assertContains turn~modelProposal~text, 'Kid Two', 'model also tries child two'
call assertContains turn~finalText, 'For Parent: Beer + Crisps is €10.', 'adult receives beer bundle offer'
call assertNotContains turn~finalText, 'Kid One', 'child one removed from emitted offer'
call assertNotContains turn~finalText, 'Kid Two', 'child two removed from emitted offer'

decisions = turn~commercialPlan~decisions
call assertTrue decisions[1]~permitted, 'adult decision permitted'
call assertEqual 'ADMISSIBLE', decisions[1]~legalAssessment~status, 'adult Legal Effect status'
call assertTrue decisions[1]~legalAssessment~promotionAuthority~pos('LEGAL_EFFECT/0.5/') = 1, 'adult v0.5 compatibility promotion identity'
call assertFalse decisions[2]~permitted, 'child one decision blocked'
call assertEqual 'BLOCKED', decisions[2]~legalAssessment~status, 'child one Legal Effect blocks'
call assertTrue decisions[2]~legalAssessment~promotionAuthority~pos('LEGAL_EFFECT/0.5/') = 1, 'child one v0.5 compatibility promotion identity'
call assertFalse decisions[2]~hardWorldRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)~finalSelected, 'HardWorld refuses child one sale'
call assertFalse decisions[3]~permitted, 'child two decision blocked'
call assertEqual 'BLOCKED', decisions[3]~legalAssessment~status, 'child two Legal Effect blocks'
say 'PASS test_shannon_family_beer_targeting'
exit 0

assertTrue: procedure
  use arg value, label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertFalse: procedure
  use arg value, label
  if value then do; say 'FAIL:' label; exit 1; end
  return
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

::requires 'ShannonChatbot.cls'
