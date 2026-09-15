parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'
session = .ShannonChatSession~new('test-complaint', policy)
turn = session~respond('I want to complain about misleading advertising in your app.')
call assertEqual 'NONCOMMERCIAL_REVIEW', turn~mode, 'complaint mode'
call assertFalse turn~salesAllowed, 'complaint suppresses sales'
call assertEqual 'BLOCKED', turn~legalAssessments['SELL_PRODUCT']~status, 'Legal Effect blocks sell on complaint'
call assertContains turn~modelProposal~text, 'Mega Priority Cabin Upgrade', 'sales model still tries to sell'
call assertNotContains turn~finalText, 'Mega Priority Cabin Upgrade', 'final response does not upsell complaint'
say 'PASS test_shannon_complaint_sales_block'
exit 0

assertFalse: procedure
  use arg conditionValue, label
  if conditionValue then do; say 'FAIL:' label; exit 1; end
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
