/* Work Load Units v0.2 gates terminal mutation before executeAID. */
MICRO = 1000000
clock = .WLUTestTimeSource~new(5000000)
keys = .WLUFastMacKeyRing~new
ignore = keys~addKey('shannon-terminal-test', '000102030405060708090a0b0c0d0e0f')
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)

account = .WLUAccount~new('ourladyair-shannon-terminal', 20 * MICRO)
auth~addAccount(account)
bucket = .WLUCapacityBucket~new('terminal-control-global', 1 * MICRO, 0, clock~nowTick)
auth~addBucket(bucket)
auth~bindAccount('SHANNON_*', 'TERMINAL:*', account~accountId)
auth~bindBucket('*', 'TERMINAL:*', bucket~bucketId)

card = .WLURateCard~new('ourladyair.terminal.control', '2026-08')
card~addRule(.WLURateRule~new('FIELD_WRITE', 100000))
card~addRule(.WLURateRule~new('AID', 250000))
card~addRule(.WLURateRule~new('SCREEN_UPDATE', 50000))
card~addRule(.WLURateRule~new('HOST_ROUND_TRIP', 200000))
card~addRule(.WLURateRule~new('CONTROL_LEASE_TIME', 10, 1000))
card~addRule(.WLURateRule~new('BYTES_RX', 1000, 1024))
card~addRule(.WLURateRule~new('BYTES_TX', 1000, 1024))
card~addRule(.WLURateRule~new('KNOWN_STATE_EVALUATION', 75000))
card~seal
auth~addRateCard(card)
auth~bindRateCard('*', 'TERMINAL:*', card~rateCardId, card~version)

gate = .ShannonWorkLoadGate~new(auth, 'SHANNON_AGENT')
controller = .ShannonTerminalWorkController~new(gate)
terminal = .FakeTerminal~new

call assertEqual .WLUDBuild~API_VERSION, gate~workLoadApiVersion, 'loaded WLU API identity retained'

/* Planned action is 0.6 WLU. Hold 0.5 WLU first so the shared 1.0 WLU
   capacity bucket refuses Shannon BEFORE terminal mutation. */
blocker = auth~reserve('SHANNON_AGENT', 'TERMINAL:QPADEV0037', 500000, 30, 'blocker', 'internal.fixture', '1')
call assertTrue blocker~ok, 'fixture capacity blocker admitted'
denied = controller~executeAID(terminal, 'QPADEV0037', 'ENTER', 1, 1, 1)
call assertTrue \denied~ok, 'terminal action denied under WLU capacity exhaustion'
call assertEqual 'WLU_CAPACITY_EXHAUSTED', denied~code, 'WLU denial code retained'
call assertEqual 0, terminal~actionCount, 'denial leaves terminal untouched'
call assertEqual 0, account~spentMicroWlu, 'denied action spends no WLU'
ignore = auth~release(blocker~value)

executed = controller~executeAID(terminal, 'QPADEV0037', 'ENTER', 1, 1, 1)
call assertTrue executed~ok, 'terminal action admitted after capacity release'
call assertEqual 1, terminal~actionCount, 'terminal action executes exactly once'
call assertEqual 600000, account~spentMicroWlu, 'actual terminal work settles at 0.6 WLU'
call assertEqual 'ourladyair.terminal.control', executed~value['rateCardId'], 'rate-card identity retained'
call assertEqual '2026-08', executed~value['rateCardVersion'], 'rate-card generation retained'
call assertEqual 'RESOURCE_ADMISSION_ONLY', executed~value['workAuthority'], 'WLU does not claim legal authority'

say 'PASS test_shannon_wlu_terminal_gate'
exit 0

assertTrue: procedure
  use arg value, label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return

::class FakeTerminal
::attribute actionCount get
::method init
  expose actionCount
  actionCount = 0
::method executeAID
  expose actionCount
  use strict arg aid
  actionCount += 1
  return aid

::requires 'ShannonWorkLoadGate.cls'
