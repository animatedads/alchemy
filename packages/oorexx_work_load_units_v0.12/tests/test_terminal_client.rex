MICRO = 1000000
clock = .WLUTestTimeSource~new(5000000)
keys = .WLUFastMacKeyRing~new
ignore = keys~addKey("hot-terminal", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)

account = .WLUAccount~new("acct-ai-gpt", 20 * MICRO)
auth~addAccount(account)
bucket = .WLUCapacityBucket~new("terminal-control-global", 1 * MICRO, 0, clock~nowTick)
auth~addBucket(bucket)
auth~bindAccount("AI_GPT", "TERMINAL:*", account~accountId)
auth~bindBucket("*", "TERMINAL:*", bucket~bucketId)

/* The terminal declares facts.  Policy, not the terminal, owns their WLU value. */
card = .WLURateCard~new("terminal.control", "2026-08")
card~addRule(.WLURateRule~new("FIELD_WRITE", 100000))
card~addRule(.WLURateRule~new("AID", 250000))
card~addRule(.WLURateRule~new("SCREEN_UPDATE", 50000))
card~addRule(.WLURateRule~new("HOST_ROUND_TRIP", 200000))
card~addRule(.WLURateRule~new("CONTROL_LEASE_TIME", 10, 1000))
card~addRule(.WLURateRule~new("BYTES_RX", 1000, 1024))
card~addRule(.WLURateRule~new("BYTES_TX", 1000, 1024))
card~addRule(.WLURateRule~new("KNOWN_STATE_EVALUATION", 75000))
card~seal
auth~addRateCard(card)
auth~bindRateCard("*", "TERMINAL:*", card~rateCardId, card~version)

terminal = .FakeTerminal~new
scope = "TERMINAL:QPADEV0037"
planned = .array~of(.WLUFact~new("FIELD_WRITE", 1, "TN5250"), .WLUFact~new("AID", 1, "TN5250"), .WLUFact~new("HOST_ROUND_TRIP", 1, "TN5250"), .WLUFact~new("SCREEN_UPDATE", 1, "TN5250"))
quote = auth~quoteFacts("AI_GPT", scope, planned)
call assertTrue quote~ok, "authority quotes terminal facts"
call assertEq 600000, quote~value~microWlu, "terminal operation quote"
call assertEq "terminal.control", quote~value~rateCardId, "policy rate card id"
call assertEq "2026-08", quote~value~rateCardVersion, "policy rate card version"

/* Another controller has consumed enough shared capacity to force denial. */
blocker = auth~reserve("AI_GPT", scope, 500000, 30, "blocker", "internal.fixture", "1")
call assertTrue blocker~ok, "capacity blocker reserve"
denied = auth~reserveFacts("AI_GPT", scope, planned, 10, "terminal-denied")
call assertTrue \denied~ok, "terminal request denied before action"
call assertEq "WLU_CAPACITY_EXHAUSTED", denied~code, "429-like capacity refusal"
call assertEq 0, terminal~actionCount, "denial leaves terminal untouched"

/* Once capacity is returned, policy-valued reservation admits the action. */
ignore = auth~release(blocker~value)
granted = auth~reserveFacts("AI_GPT", scope, planned, 10, "terminal-granted")
call assertTrue granted~ok, "fact reservation granted"
call assertEq "terminal.control", granted~value~rateCardId, "reservation binds tariff id"
call assertEq "2026-08", granted~value~rateCardVersion, "reservation binds tariff version"
call assertTrue auth~admit(granted~value)~ok, "control gate admission"

/* Only after admission is the terminal permitted to mutate. */
terminal~executeAID("ENTER")
call assertEq 1, terminal~actionCount, "terminal operation executed once"

/* A live tariff rollover changes NEW work, never an already admitted lease. */
card2 = .WLURateCard~new("terminal.control", "2026-09")
card2~addRule(.WLURateRule~new("FIELD_WRITE", 200000))
card2~addRule(.WLURateRule~new("AID", 300000))
card2~addRule(.WLURateRule~new("SCREEN_UPDATE", 100000))
card2~addRule(.WLURateRule~new("HOST_ROUND_TRIP", 300000))
card2~addRule(.WLURateRule~new("CONTROL_LEASE_TIME", 10, 1000))
card2~addRule(.WLURateRule~new("BYTES_RX", 1000, 1024))
card2~addRule(.WLURateRule~new("BYTES_TX", 1000, 1024))
card2~addRule(.WLURateRule~new("KNOWN_STATE_EVALUATION", 75000))
card2~seal
auth~addRateCard(card2)
auth~bindRateCard("*", "TERMINAL:*", card2~rateCardId, card2~version)
newQuote = auth~quoteFacts("AI_GPT", scope, planned)
call assertEq "2026-09", newQuote~value~rateCardVersion, "new requests see new tariff"
call assertEq 900000, newQuote~value~microWlu, "new tariff price"

actual = .array~of(.WLUFact~new("FIELD_WRITE", 1, "TN5250"), .WLUFact~new("AID", 1, "TN5250"), .WLUFact~new("HOST_ROUND_TRIP", 1, "TN5250"), .WLUFact~new("SCREEN_UPDATE", 1, "TN5250"))
settled = auth~settleFacts(granted~value, actual)
call assertTrue settled~ok, "terminal operation settles from facts"
call assertEq 600000, account~spentMicroWlu, "actual work charged"
call assertEq 0, account~reservedMicroWlu, "reservation fully settled"

say "PASS test_terminal_client"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
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

::requires "WorkLoadUnits.cls"
