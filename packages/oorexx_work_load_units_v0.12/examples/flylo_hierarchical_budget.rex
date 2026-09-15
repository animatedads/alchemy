/* FlyLo borrowing Shannon under a shared enterprise workload budget. */
keyRing = .WLUFastMacKeyRing~new
keyRing~addKey('demo', '000102030405060708090a0b0c0d0e0f')
h = .WLUHierarchyBudgetManager~new(keyRing)
enterprise = h~createRoot('ENTERPRISE', 'ENTERPRISE', .WLUUnits~parse('100'))~value
flylo = h~delegate(enterprise, 'FLYLO', 'TENANT', .WLUUnits~parse('80'))~value
shannon = h~delegate(flylo, 'FLYLO.SHANNON', 'SERVICE', .WLUUnits~parse('60'))~value
chat = h~delegate(shannon, 'FLYLO.SHANNON.CHAT-001', 'JOB', .WLUUnits~parse('20'))~value
reserved = h~hold(chat, .WLUUnits~parse('10'), 'gemma-stage')
say 'hold:' reserved~ok 'WLU=' .WLUUnits~format(reserved~value[2]~reservedMicroWlu)
settled = h~settle(reserved~value[2], .WLUUnits~parse('6'))
say 'actual chat work:' .WLUUnits~format(settled~value~spentMicroWlu) 'WLU'
say 'The same 6 WLU is reflected at each ancestor; it is not summed.'
::requires 'WLUHierarchy.cls'
