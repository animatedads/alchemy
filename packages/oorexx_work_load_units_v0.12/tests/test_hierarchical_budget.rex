parse source . . here
root = filespec('location', here)
src = root || '../src/'
call setlocal
call value 'REXX_PATH', src || ':' || value('CRYPTO_SRC',, 'ENVIRONMENT'), 'ENVIRONMENT'

keyRing = .WLUFastMacKeyRing~new
keyRing~addKey('hierarchy-k1', '000102030405060708090a0b0c0d0e0f')
h = .WLUHierarchyBudgetManager~new(keyRing)

enterprise = h~createRoot('ENTERPRISE', 'ENTERPRISE', .WLUUnits~parse('100'))
call assertTrue enterprise~ok, 'enterprise root opens'
flylo = h~delegate(enterprise~value, 'FLYLO', 'TENANT', .WLUUnits~parse('80'))
call assertTrue flylo~ok, 'FlyLo tenant delegates'
shannon = h~delegate(flylo~value, 'FLYLO.SHANNON', 'SERVICE', .WLUUnits~parse('60'))
call assertTrue shannon~ok, 'Shannon service delegates'
chat = h~delegate(shannon~value, 'FLYLO.SHANNON.CHAT-001', 'JOB', .WLUUnits~parse('20'))
call assertTrue chat~ok, 'chat budget delegates'

/* Sibling ceilings are constraints, not pre-spent allocations. */
other = h~delegate(flylo~value, 'FLYLO.OTHER', 'SERVICE', .WLUUnits~parse('60'))
call assertTrue other~ok, 'sibling ceiling may nominally overcommit parent'

holdResult = h~hold(chat~value, .WLUUnits~parse('10'), 'chat-001-stage-1')
call assertTrue holdResult~ok, '10 WLU hold admitted through all ancestors'
chatLease = holdResult~value[1]
hold = holdResult~value[2]
call assertEq .WLUUnits~parse('10'), chatLease~committedMicroWlu, 'leaf commitment'

pathResult = h~path(chatLease)
call assertTrue pathResult~ok, 'path available'
call assertEq 4, pathResult~value~items, 'four hierarchy levels'
do node over pathResult~value
  call assertEq .WLUUnits~parse('10'), node~committedMicroWlu, 'same commitment reflected at each level'
end

/* The same work settles at every constraint level, but is not multiplied. */
settled = h~settle(hold, .WLUUnits~parse('6'))
call assertTrue settled~ok, 'hold settles at actual 6 WLU'
chatLease = settled~value
pathResult = h~path(chatLease)
do node over pathResult~value
  call assertEq .WLUUnits~parse('6'), node~spentMicroWlu, 'same 6 WLU reflected at each level'
  call assertEq 0, node~committedMicroWlu, 'commitment cleared at each level'
end

/* A child can have headroom while an ancestor is the real limiter. */
flyloNow = h~current(flylo~value~nodeId)~value
flyloHold = h~hold(flyloNow, .WLUUnits~parse('70'), 'flylo-bulk')
call assertTrue flyloHold~ok, 'FlyLo bulk work uses parent headroom'
chatNow = h~current(chat~value~nodeId)~value
assessment = h~assess(chatNow, .WLUUnits~parse('5'))
call assertTrue assessment~ok, 'assessment returned'
call assertTrue \assessment~value~ready, 'chat locally has room but ancestor blocks'
call assertEq 'FLYLO', assessment~value~limitingNodeKey, 'FlyLo is limiting ancestor'
call assertEq .WLUUnits~parse('1'), assessment~value~shortfallMicroWlu, 'ancestor shortfall is 1 WLU'
blocked = h~hold(chatNow, .WLUUnits~parse('5'), 'chat-001-stage-2')
call assertTrue \blocked~ok, 'ancestor exhaustion refuses child hold'
call assertEq 'WLU_BUDGET_EXHAUSTED', blocked~code, 'ancestor refusal code'

/* Releasing unrelated committed work restores admission without changing spend. */
flyloReleased = h~release(flyloHold~value[2])
call assertTrue flyloReleased~ok, 'bulk hold released'
chatNow = h~current(chat~value~nodeId)~value
allowed = h~hold(chatNow, .WLUUnits~parse('5'), 'chat-001-stage-2')
call assertTrue allowed~ok, 'chat admitted after ancestor capacity restored'

/* Idempotency and tamper evidence. */
replay = h~hold(allowed~value[1], .WLUUnits~parse('5'), 'chat-001-stage-2')
call assertTrue replay~ok, 'same request id replays idempotently'
call assertEq allowed~value[2]~holdId, replay~value[2]~holdId, 'same hold id on replay'

fake = .WLUBudgetNodeLease~new(chatNow~nodeId, chatNow~nodeKey, chatNow~kind, chatNow~parentId, chatNow~budgetMicroWlu + 1, chatNow~spentMicroWlu, chatNow~committedMicroWlu, chatNow~revision, chatNow~proof)
tampered = h~assess(fake, .WLUUnits~parse('1'))
call assertTrue \tampered~ok, 'tampered budget lease rejected'
call assertEq 'WLU_BUDGET_LEASE_PROOF_INVALID', tampered~code, 'tamper rejection code'

say 'PASS test_hierarchical_budget'
exit 0

assertTrue: procedure
  use arg value, message
  if \value then do
    say 'FAIL:' message
    exit 1
  end
return

assertEq: procedure
  use arg expected, actual, message
  if expected \= actual then do
    say 'FAIL:' message 'expected='expected 'actual='actual
    exit 1
  end
return

::requires 'WLUHierarchy.cls'
