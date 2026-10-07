failures = 0
parse arg ledgerRoot
if ledgerRoot = "" then ledgerRoot = "/tmp/df-autonomous-hello-test"
address command "rm -rf" ledgerRoot
address command "mkdir -p" ledgerRoot

keyRing = .WLUFastMacKeyRing~new
ignore = keyRing~addKey("df-test", "00112233445566778899aabbccddeeff")
wluLedger = .WLUAuthenticatedFileLedger~new(ledgerRoot || "/wlu.auth.ledger", keyRing)
clock = .WLUTestTimeSource~new(1000000)
authority = .WLUAuthority~new(keyRing, wluLedger, clock)
account = .WLUAccount~new("development-floor", 20000000)
ignore = authority~addAccount(account)
ignore = authority~bindAccount("*", "*", account~accountId)

accounting = .DFAccountingLedger~new(ledgerRoot || "/development-floor.accounting")
control = .DFWLUControl~new(authority, accounting)
manager = .DFDevelopmentManager~new
ignore = manager~loadRegistrations("config/default_registrations.json")
ignore = manager~bindWorkControl(control)

assignment = .DFAssignment~new("HELLO-1", "DEVFLOOR", "HELLO", "ooRexx", "write a HelloWorld application")
ignore = assignment~assignTo("hello-specialist")
ignore = manager~addAssignment(assignment)
ignore = manager~bindAssignmentExecution(assignment~id, "coding-specialist", "local-qwen-llamacpp")
reserved = manager~reserveAssignmentWork(assignment~id, 2200000, 3000000, 60, 300, "hello-1")
call check reserved~ok, "Hello worker WLU reserved"
admitted = manager~admitAssignmentWork(assignment~id)
call check admitted~ok, "Hello worker WLU admitted"

provider = .DeterministicHelloProvider~new
worker = .DFAutonomousCodingWorker~new(manager, provider)
outcome = worker~runHelloWorld(assignment~id, "tests/fixtures/hello_worker/instructions.txt", ledgerRoot || "/workspace", "fixture-model", "HELLO WORLD", 512, 1000000, 100000, 1000000, 100000)

call check outcome~ok, "autonomous HelloWorld completes"
call check outcome~code = "OK", "autonomous outcome code"
call check outcome~secondBiteAction = "REPLACE", "second bite repairs observed output mismatch"
call check outcome~initialCompileRc = 0, "initial source compiles"
call check outcome~initialRunRc = 0, "initial source runs"
call check outcome~finalCompileRc = 0, "final source compiles"
call check outcome~finalRunRc = 0, "final source runs"
call check outcome~finalStdout = "HELLO WORLD", "final stdout accepted"
call check outcome~sourceSha256 <> "", "final source hash recorded"
call check provider~invocationCount = 2, "provider invoked for initial and second bite"
call check outcome~inputTokens = 50, "input token evidence accumulated"
call check outcome~outputTokens = 25, "output token evidence accumulated"
call check accounting~totalFor(assignment~id, "LLM_INPUT", "INPUT_TOKEN") = 50, "input token accounting journal"
call check accounting~totalFor(assignment~id, "LLM_OUTPUT", "OUTPUT_TOKEN") = 25, "output token accounting journal"
call check account~spentMicroWlu = 2200000, "WLU settlement reflects bounded worker loop"
call check assignment~wluState = "SETTLED", "worker settles WLU"
call check assignment~status = "COMPLETE", "worker terminal success completes assignment"

source = .Stream~new(outcome~filePath)
ignore = source~open("READ")
sourceText = source~charIn(1, source~chars)
ignore = source~close
call check sourceText~pos('say "HELLO WORLD"') > 0, "final file contains repaired HelloWorld"

if failures = 0 then do
  say "PASS autonomous Development Floor HelloWorld"
  say "  provider_calls=" || provider~invocationCount
  say "  final_sha256=" || outcome~sourceSha256
  say "  wlu_spent=" || account~spentMicroWlu
  exit 0
end
say "FAIL autonomous HelloWorld failures=" failures
exit 1

check: procedure expose failures
  use arg conditionValue, label
  if conditionValue then return
  say "FAIL" label
  failures += 1
  return

::class DeterministicHelloProvider subclass AIProviderAdapterBase public
::attribute invocationCount get
::method init
  expose invocationCount
  invocationCount = 0
  self~init:super
::method completeRequest protected
  expose invocationCount
  use arg request
  invocationCount += 1
  if invocationCount = 1 then do
    proposal = .directory~new
    proposal["source"] = 'say "HELLO WROLD"'
    return .AIProviderReply~success(.JSON~toJSON(proposal), request~model, "stop", .AIProviderUsage~new(20, 10))
  end
  proposal = .directory~new
  proposal["action"] = "REPLACE"
  proposal["source"] = 'say "HELLO WORLD"'
  return .AIProviderReply~success(.JSON~toJSON(proposal), request~model, "stop", .AIProviderUsage~new(30, 15))

::requires "AutonomousCodingWorker.cls"
::requires "WLULedger.cls"
