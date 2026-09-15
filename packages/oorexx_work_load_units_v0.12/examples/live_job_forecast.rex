/*
 * Live logical-job forecast example.
 *
 * Forecasts are authenticated estimator evidence.  They do not reserve,
 * spend, top up, or otherwise enlarge the job's hard WLU budget.
 */
MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
keys~addKey('demo', '000102030405060708090a0b0c0d0e0f')
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new('flylo', 100 * MICRO)
auth~addAccount(account)
auth~bindAccount('FLYLO_*', 'SHANNON:*', account~accountId)

plan = .WLUJobPlan~new('shannon.chat', '1')
plan~addStage(.WLUJobStage~new('SCRIPT', 'SHANNON:SCRIPT', 1 * MICRO, 2 * MICRO), .true)
plan~seal

manager = .WLUJobBudgetManager~new(auth)
request = .WLUJobRequest~new('chat-42', 'CHAT-42', 'FLYLO_SHANNON', 'SHANNON:CHAT', plan, 8 * MICRO, 20 * MICRO)
lease = manager~openJob(request)~value

say 'hard budget:' .WLUUnits~format(lease~budgetMicroWlu) 'WLU'
say 'initial projected expected:' .WLUUnits~format(lease~forecastProjectedExpectedMicroWlu) 'WLU'

/* Later Shannon observes that remote rescue may be required. */
revised = manager~reviseForecast(lease, 10 * MICRO, 22 * MICRO, 8000, 'SHANNON', 'remote rescue and history replay are plausible')
lease = revised~value[1]
forecast = revised~value[2]

say 'forecast status:' forecast~status
say 'projected expected:' .WLUUnits~format(forecast~projectedExpectedMicroWlu) 'WLU'
say 'projected upper:' .WLUUnits~format(forecast~projectedUpperMicroWlu) 'WLU'
say 'upper shortfall:' .WLUUnits~format(forecast~upperShortfallMicroWlu) 'WLU'
say 'declared confidence:' forecast~confidenceBasisPoints 'basis points'
say 'hard budget is still:' .WLUUnits~format(lease~budgetMicroWlu) 'WLU'
say 'spent remains:' .WLUUnits~format(lease~spentMicroWlu) 'WLU'

::requires 'WLUJobBudget.cls'
