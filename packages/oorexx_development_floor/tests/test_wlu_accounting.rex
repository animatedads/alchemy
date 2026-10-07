/* Executable integration of Development Floor with exact work.load.units/0.12. */
failures = 0
parse arg ledgerRoot
if ledgerRoot = "" then ledgerRoot = "/tmp/df-wlu-accounting-test"
address command "rm -rf" ledgerRoot
address command "mkdir -p" ledgerRoot

keyRing = .WLUFastMacKeyRing~new
ignore = keyRing~addKey("df-test", "00112233445566778899aabbccddeeff")
wluLedger = .WLUAuthenticatedFileLedger~new(ledgerRoot || "/wlu.auth.ledger", keyRing)
clock = .WLUTestTimeSource~new(1000000)
authority = .WLUAuthority~new(keyRing, wluLedger, clock)
account = .WLUAccount~new("development-floor", 100000000)
ignore = authority~addAccount(account)
ignore = authority~bindAccount("*", "*", account~accountId)

accounting = .DFAccountingLedger~new(ledgerRoot || "/development-floor.accounting")
control = .DFWLUControl~new(authority, accounting)
manager = .DFDevelopmentManager~new
ignore = manager~loadRegistrations("config/default_registrations.json")
ignore = manager~bindWorkControl(control)

assignment = .DFAssignment~new("A-WLU-1", "DEVFLOOR", "PKG", "ooRexx", "exercise WLU control")
ignore = assignment~assignTo("specialist-wlu")
ignore = manager~addAssignment(assignment)
ignore = manager~bindAssignmentExecution(assignment~id, "coding-specialist", "local-qwen-llamacpp")

reserved = manager~reserveAssignmentWork(assignment~id, 10000000, 20000000, 60, 300, "req-A-WLU-1")
call check reserved~ok, "WLU reservation accepted"
call check assignment~wluState = "RESERVED", "assignment records reserved state"
call check assignment~wluReservationId <> "", "assignment records reservation id"

admitted = manager~admitAssignmentWork(assignment~id)
call check admitted~ok, "WLU reservation admitted before work"
call check assignment~wluState = "ADMITTED", "assignment records admitted state"
call check assignment~status = "ACTIVE", "assignment becomes active only after admission"

consumed = manager~consumeAssignmentWork(assignment~id, 3000000, "implementation-bite-1")
call check consumed~ok, "WLU consumption recorded"
ignore = manager~recordAssignmentResourceUse(assignment~id, "LLM_INPUT", 1250, "INPUT_TOKEN", "call-1", "local worker prompt")
ignore = manager~recordAssignmentResourceUse(assignment~id, "LLM_OUTPUT", 375, "OUTPUT_TOKEN", "call-1", "local worker response")
ignore = manager~recordAssignmentResourceUse(assignment~id, "WALL", 842, "WALL_MILLISECOND", "call-1", "elapsed")
call check accounting~totalFor(assignment~id, "LLM_INPUT", "INPUT_TOKEN") = 1250, "native input-token accounting preserved"
call check accounting~totalFor(assignment~id, "WALL", "WALL_MILLISECOND") = 842, "wall-time accounting preserved"

settled = manager~settleAssignmentWork(assignment~id, 4000000)
call check settled~ok, "WLU settlement succeeds"
call check assignment~wluState = "SETTLED", "assignment records settled WLU state"
call check assignment~status = "COMPLETE", "settled assignment completes"
call check account~spentMicroWlu = 4000000, "WLU authority remains source of spent work"
call check account~reservedMicroWlu = 0, "unused WLU reservation released by authority"

authRead = wluLedger~readVerified
call check authRead~ok, "authenticated WLU ledger verifies"
if authRead~ok then do
  authEvents = authRead~value[1]
  call check authEvents~items >= 3, "authenticated WLU ledger retains authority events"
end

dfRead = accounting~readAll
call check dfRead[1], "Development Floor accounting ledger replays"
if dfRead[1] then call check dfRead[3]~items >= 6, "cross-resource ledger retains correlated events"

/* Reporting totals are a derived restart-safe index, not a full-scan hot path. */
recoveredAccounting = .DFAccountingLedger~new(ledgerRoot || "/development-floor.accounting")
call check recoveredAccounting~totalFor(assignment~id, "LLM_INPUT", "INPUT_TOKEN") = 1250, "resource totals rebuild from durable ledger"
call check recoveredAccounting~totalFor(assignment~id, "WALL", "WALL_MILLISECOND") = 842, "wall totals rebuild from durable ledger"

/* Malformed hex is rejected by validation, without exception-driven decode flow. */
badLedgerPath = ledgerRoot || "/bad.accounting"
call lineout badLedgerPath, "DF_ACCOUNTING/0.1|1|100|zz||||0|||"
call lineout badLedgerPath
signal on syntax name malformedLedger
ignore = .DFAccountingLedger~new(badLedgerPath)
signal off syntax
call check .false, "malformed accounting ledger should fail recovery"
signal malformedDone
malformedLedger:
  say "expected malformed accounting refusal rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" condition("D")
  caughtMalformed = condition("C")
  signal off syntax
  call check caughtMalformed = "SYNTAX", "malformed accounting ledger fails closed"
malformedDone:

/* WLU ceiling remains authority: insufficient entitlement must fail closed. */
assignment2 = .DFAssignment~new("A-WLU-2", "DEVFLOOR", "PKG", "ooRexx", "oversized reservation")
ignore = assignment2~assignTo("specialist-wlu")
ignore = manager~addAssignment(assignment2)
ignore = manager~bindAssignmentExecution(assignment2~id, "coding-specialist", "local-qwen-llamacpp")
denied = manager~reserveAssignmentWork(assignment2~id, 97000000, 97000000, 0, 300, "req-A-WLU-2")
call check \denied~ok, "WLU entitlement exhaustion denies new work"
call check denied~code = "WLU_ENTITLEMENT_EXHAUSTED", "denial comes from WLU authority"

/* Binding an execution provider is not itself permission to execute. */
assignment3 = .DFAssignment~new("A-WLU-3", "DEVFLOOR", "PKG", "ooRexx", "missing reservation")
ignore = assignment3~assignTo("specialist-wlu")
ignore = manager~addAssignment(assignment3)
ignore = manager~bindAssignmentExecution(assignment3~id, "coding-specialist", "local-qwen-llamacpp")
signal on syntax name missingWlu
ignore = manager~requireAssignmentWorkAdmission(assignment3~id)
signal off syntax
call check .false, "missing WLU reservation should refuse work"
signal doneMissing
missingWlu:
  say "expected WLU refusal rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" condition("D")
  caughtCondition = condition("C")
  signal off syntax
  call check caughtCondition = "SYNTAX", "missing WLU reservation fails closed"
doneMissing:

if failures = 0 then do
  say "PASS test_wlu_accounting"
  exit 0
end
say "FAIL test_wlu_accounting failures=" failures
exit 1

check: procedure expose failures
  use arg conditionValue, label
  if conditionValue then return
  say "FAIL" label
  failures += 1
  return

::requires "DevelopmentFloor.cls"
::requires "WLULedger.cls"
