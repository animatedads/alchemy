parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'
session = .ShannonChatSession~new('test-normal', policy)
turn = session~respond('Can I buy a 10 kg cabin bag?')
call assertEqual 'NORMAL_COMMERCIAL', turn~mode, 'normal mode'
call assertTrue turn~salesAllowed, 'sales allowed in ordinary commercial turn'
call assertContains turn~finalText, 'Mega Priority Cabin Upgrade', 'commercial answer carries sales offer'
call assertEqual 'ADMISSIBLE', turn~legalAssessments['SELL_PRODUCT']~status, 'legal sell status'
say 'PASS test_shannon_normal_sales'
exit 0

assertTrue: procedure
  use arg conditionValue, label
  if \conditionValue then do
    say 'FAIL:' label
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say 'FAIL:' label 'expected=' expected 'actual=' actual
    exit 1
  end
  return

assertContains: procedure
  use arg text, needle, label
  if text~pos(needle) = 0 then do
    say 'FAIL:' label 'missing=' needle
    exit 1
  end
  return

::requires 'ShannonChatbot.cls'
