parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'
session = .ShannonChatSession~new('test-queue', policy)
service = .ShannonQueueService~new(session)
putOperation = service~submit('My EpiPen is in a 10 kg cabin bag that might be gate-checked and put in the hold.')
call assertTrue putOperation~ok, 'queue submit succeeds'
call assertEqual 0, putOperation~triggerFailures~items, 'trigger has no failures'
call assertEqual 1, service~auditDepth, 'one rich audit record queued'
replyOperation = service~receive
call assertTrue replyOperation~ok, 'response queued'
reply = replyOperation~value~payload
call assertEqual 'SHANNON_REPLY', reply['kind'], 'reply payload kind'
call assertEqual 'SAFETY_REMEDIATION', reply['mode'], 'queue path preserves governance mode'
call assertContains reply['text'], 'personal custody', 'queue path returns safety text'
auditOperation = service~getAudit
call assertTrue auditOperation~ok, 'audit record available'
audit = auditOperation~value~payload
call assertEqual 'ourladyair.shannon.turn.v3', audit['schema'], 'audit schema'
call assertEqual 'BLOCKED', audit['governance']['legalStatus']['SELL_PRODUCT'], 'audit carries Legal Effect result'
call assertEqual .LegalEffectBuild~API_VERSION, audit['governance']['legalApiVersion'], 'audit carries loaded Legal Effect API'
call assertEqual '0.6', audit['governance']['legalBuildVersion'], 'audit exposes supplied build metadata'
call assertContains audit['governance']['legalPromotionAuthority']['SELL_PRODUCT'], 'LEGAL_EFFECT/0.5/', 'audit carries explicit v0.5 compatibility promotion authority'
call assertFalse audit['governance']['salesAllowed'], 'audit records sales block'
call assertEqual 1000, audit['commercial']['modelGrossCents'], 'audit preserves proposed commercial value'
call assertEqual 0, audit['commercial']['governedGrossCents'], 'safety block removes governed commercial value'
call assertEqual 1, audit['commercial']['blockedCount'], 'audit preserves target-level block'
say 'PASS test_shannon_queue_service'
exit 0

assertTrue: procedure
  use arg conditionValue, label
  if \conditionValue then do; say 'FAIL:' label; exit 1; end
  return
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

::requires 'ShannonQueueService.cls'
