/* WLU admission, provider/model rate accounting and hourly allowance. */

clock = .TestBudgetClock~new(1000000000000)
policy = .LlmPaExternalBudgetPolicy~new(3, 10000)
authority = .LlmPaExternalBudgetAuthority~new(policy, clock)

registered = authority~registerRate("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 10000, "hf-2026-09")
if \registered~ok then exit 1
registered = authority~registerRate("deepseek", "deepseek-reasoner", 20000, "ds-2026-09")
if \registered~ok then exit 2

first = authority~reserve("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 1500000, "request-one")
if \first~ok then exit 3
if first~value["estimated_microdollars"] \= 15000 then exit 4

second = authority~reserve("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 1000000, "request-two")
if \second~ok then exit 5

/* The third reservation would exceed the separate $0.03 allowance. */
denied = authority~reserve("deepseek", "deepseek-reasoner", 500000, "request-three")
if denied~ok then exit 6
if denied~code \= "PA_MONEY_HOURLY_CEILING" then exit 7

/* Settlement uses the reservation's immutable rate-book snapshot. */
ignore = authority~registerRate("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 99999, "hf-newer")
settled = authority~settle(first~value["reservation_id"], 1000000)
if \settled~ok then exit 8
if settled~value["actual_microdollars"] \= 10000 then exit 9

released = authority~release(second~value["reservation_id"])
if \released~ok then exit 10

state = authority~snapshot~value
if state["reserved_micro_wlu"] \= 0 then exit 11
if state["settled_micro_wlu"] \= 1000000 then exit 12
if state["settled_microdollars"] \= 10000 then exit 13
if authority~ledger~items \= 4 then exit 14

/* The allowance is windowed; a new hour starts with no reservations. */
clock~setValue(clock~value + 3600000000)
next = authority~reserve("deepseek", "deepseek-reasoner", 1000000, "request-four")
if \next~ok then exit 15
if next~value["estimated_microdollars"] \= 20000 then exit 16

/* Restart recovery: settled allowance remains spent in the same hour. */
path = "/tmp/pa-budget-authority-test-" || random(100000, 999999) || ".jsonl"
persistent = .LlmPaExternalBudgetAuthority~new(policy, clock, path)
ignore = persistent~registerRate("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 10000, "hf-2026-09")
spent = persistent~reserve("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 3000000, "restart-check")
if \spent~ok then exit 17
ignore = persistent~settle(spent~value["reservation_id"], 3000000)
restarted = .LlmPaExternalBudgetAuthority~new(policy, clock, path)
ignore = restarted~registerRate("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 10000, "hf-2026-09")
blocked = restarted~reserve("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 1, "after-restart")
if blocked~ok then exit 18
if blocked~code \= "PA_WLU_HOURLY_CEILING" then exit 19
if restarted~ledger~items < 2 then exit 20

clock~setValue(clock~value + 3600000000)
fresh = restarted~reserve("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 1, "new-hour")
if \fresh~ok then exit 21
if fresh~value["reservation_id"] \= "pa-budget-2" then exit 22

overrunAuthority = .LlmPaExternalBudgetAuthority~new(policy, clock)
ignore = overrunAuthority~registerRate("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 10000, "hf-2026-09")
bounded = overrunAuthority~reserve("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 1000000, "overrun")
if \bounded~ok then exit 23
overrun = overrunAuthority~settle(bounded~value["reservation_id"], 4000000)
if overrun~ok then exit 24
if overrun~code \= "PA_WLU_OVERRUN_WINDOW_FROZEN" then exit 25
again = overrunAuthority~reserve("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 1, "frozen")
if again~ok then exit 26
if again~code \= "PA_WINDOW_FROZEN" then exit 27
say "PASS test_budget_authority"
exit 0

::class TestBudgetClock public
::attribute value get
::method init
  expose value
  use arg valueArg
  value = valueArg
::method microseconds
  expose value
  return value
::method setValue
  expose value
  use arg valueArg
  value = valueArg

::requires "LlmPaBudgetAuthority.cls"
