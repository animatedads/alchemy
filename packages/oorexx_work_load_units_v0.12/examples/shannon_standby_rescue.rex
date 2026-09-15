/* Shannon/FlyLo: turn an at-risk forecast into a non-entitling rescue standby,
 * then promote it only when the application actually decides to switch. */
MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
keys~addKey('demo-standby', '000102030405060708090a0b0c0d0e0f')
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new('flylo-demo', 100 * MICRO)
auth~addAccount(account)
auth~bindAccount('FLYLO_*', 'SHANNON:*', account~accountId)
pool = .WLUThroughputPool~new('grok-demo', 10 * MICRO)
auth~addThroughputPool(pool)
auth~bindThroughputPool('FLYLO_*', 'SHANNON:GROK', pool~poolId)

hier = .WLUHierarchyBudgetManager~new(keys)
enterprise = hier~createRoot('ENTERPRISE', 'ENTERPRISE', 50 * MICRO)~value
flylo = hier~delegate(enterprise, 'FLYLO', 'TENANT', 30 * MICRO)~value
chat = hier~delegate(flylo, 'FLYLO.SHANNON.CHAT-DEMO', 'JOB', 20 * MICRO)~value

plan = .WLUJobPlan~new('shannon.demo', '1')
plan~addStage(.WLUJobStage~new('GROK', 'SHANNON:GROK', 6 * MICRO, 9 * MICRO, 1 * MICRO, 1 * MICRO, 2), .true)
plan~seal
request = .WLUJobRequest~new('flylo-demo-chat', 'CHAT-DEMO', 'FLYLO_SHANNON', 'SHANNON:CHAT', plan, 7 * MICRO, 20 * MICRO)
manager = .WLUHierarchicalJobManager~new(auth, hier)
lease = manager~openJob(request, chat)~value

forecasted = manager~reviseForecast(lease, 12 * MICRO, 22 * MICRO, 8000, 'SHANNON', 'remote rescue becoming plausible')
lease = forecasted~value[1]
forecast = forecasted~value[2]
standby = manager~standbyStage(lease, 'GROK', 30, 900, 'grok-rescue')~value
assessment = manager~assessStandby(lease, standby)~value

say 'forecast status:' forecast~status
say 'standby state:' assessment~jobAssessment~effectiveState
say 'standby ceiling:' .WLUUnits~format(standby~ceilingMicroWlu) 'WLU'
say 'standby rate:' .WLUUnits~format(standby~requestedRateMicroWluPerSecond) 'WLU/s'
say 'promotable now:' assessment~ready
say 'hard job committed before promotion:' .WLUUnits~format(lease~committedMicroWlu) 'WLU'
say 'hierarchy committed before promotion:' .WLUUnits~format(hier~current(chat~nodeId)~value~committedMicroWlu) 'WLU'

promoted = manager~promoteStandby(lease, standby, 60, 'grok-rescue')
if \promoted~ok then do
  say 'promotion failed:' promoted~code promoted~detail
  exit 1
end
lease = promoted~value[1]
reservation = promoted~value[2]
say 'hard job committed after promotion:' .WLUUnits~format(lease~committedMicroWlu) 'WLU'
say 'provider rate reserved after promotion:' .WLUUnits~format(pool~reservedRateMicroWluPerSecond) 'WLU/s'

settled = manager~settleStage(lease, reservation, 7 * MICRO)
if \settled~ok then do
  say 'settlement failed:' settled~code settled~detail
  exit 1
end
say 'actual settled work:' .WLUUnits~format(settled~value[1]~spentMicroWlu) 'WLU'
exit 0

::requires 'WLUHierarchicalJob.cls'
