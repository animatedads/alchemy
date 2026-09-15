parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'
session = .ShannonChatSession~new('test-resolution', policy)
first = session~respond('Can I put my EpiPen in the 10 kg cabin bag?')
call assertEqual 'NEEDS_INFORMATION', first~mode, 'unknown custody blocks sales'
second = session~respond('It will stay under seat and is guaranteed to stay in the cabin with me.')
call assertEqual 'NORMAL_COMMERCIAL', second~mode, 'safe custody resolves governance block'
call assertTrue second~salesAllowed, 'sales may resume only after safe custody becomes known'
call assertEqual 'ADMISSIBLE', second~legalAssessments['SELL_PRODUCT']~status, 'sell becomes admissible'
say 'PASS test_shannon_custody_resolution'
exit 0

assertTrue: procedure
  use arg conditionValue, label
  if \conditionValue then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return

::requires 'ShannonChatbot.cls'
