/* Core API acceptance for ooRexx Semantic Source Control v0.1 */
repoRoot = "/tmp/osc-core-test"
address system "rm -rf '" || repoRoot || "'"
repo = .SemanticRepository~new(repoRoot)
analyzer = .OoRexxSourceAnalyzer~new(repo)

v1 = analyzer~analyzeTree("tests/fixtures/provider_v1", "DataStore", "MAIN", 1, "v1")
call assertEq 2, v1~methods~items, "v1 method count"
call assertEq 1, v1~candidates~items, "SQL proposal discovered"
call assertEq 0, v1~externalOperations~items, "proposal not silently tracked"

candidate = v1~candidates[1]
call assertEq "SQL", candidate~kind, "proposal kind"
call assertEq "SELECT", candidate~operation, "proposal operation"
call assertContains candidate~semanticContract, "projection=ACCOUNT_ID, NAME, BALANCE", "SELECT projection contract"
call assertTrue candidate~beforeHashes~items >= 1, "context above retained"
call assertTrue candidate~afterHashes~items >= 1, "context below retained"
repo~saveSnapshot(v1)
externalId = repo~recordDecision(candidate~proposalId, "ACCEPTED", "test acceptance", "TEST")
call assertTrue externalId~left(3) = "EO-", "accepted external ID"

v1tracked = repo~loadLatest("DataStore")
call assertEq 1, v1tracked~externalOperations~items, "accepted decision materializes tracked entity without rewriting source level"
call assertContains repo~methodSource("DataStore", 1, "DataStore.AccountStore.loadAccounts"), "SELECT account_id, name, balance", "historical method source reconstructible"

call assertEq externalId, v1tracked~externalOperations[1]~externalId, "external identity"

v2 = analyzer~analyzeTree("tests/fixtures/provider_v2", "DataStore", "MAIN", 2, "v2")
repo~reconcileIdentities(v2)
call assertEq 1, v2~externalOperations~items, "tracked SQL survives statement edit"
call assertEq externalId, v2~externalOperations[1]~externalId, "tracked SQL identity survives edit"
deltas = .ContractComparator~new~compare(v1tracked, v2)
call assertDelta deltas, "METHOD_CONTRACT_CHANGED"
call assertDelta deltas, "METHOD_REMOVED"
call assertDelta deltas, "SQL_PROJECTION_OR_ORDER_CHANGED"

work = analyzer~analyzeTree("tests/fixtures/work", "WORK", "WORK", "WORKING")
call assertEq 2, work~requirements~items, "AT_LEAST requirements"
call assertEq 3, work~dataDependencies~items, "data/result dependencies"
findings = .ImpactEngine~new~assess(v1tracked, v2, work, deltas)
call assertFinding findings, "KNOWN_UNSATISFIED_SURFACE", "legacyDelete"
call assertFinding findings, "MAY_BREAK_HIGH", "positional SQL result consumer"

v3 = analyzer~analyzeTree("tests/fixtures/provider_v3", "DataStore", "MAIN", 3, "v3")
repo~reconcileIdentities(v3)
d3 = .ContractComparator~new~compare(v1tracked, v3)
call assertDelta d3, "SQL_OPERATION_CHANGED"
f3 = .ImpactEngine~new~assess(v1tracked, v3, work, d3)
call assertFinding f3, "MAY_BREAK_HIGH", "data source ACCOUNT"

/* Rejection is durable for the exact candidate but does not suppress a
   materially changed statement at the same contextual site. */
repo2Root = "/tmp/osc-reject-test"
address system "rm -rf '" || repo2Root || "'"
repo2 = .SemanticRepository~new(repo2Root)
a2 = .OoRexxSourceAnalyzer~new(repo2)
r1 = a2~analyzeTree("tests/fixtures/provider_v1", "DataStore", "MAIN", 1)
c1 = r1~candidates[1]
repo2~recordDecision(c1~proposalId, "REJECTED", "not independently significant", "TEST")
r1again = a2~analyzeTree("tests/fixtures/provider_v1", "DataStore", "MAIN", 1)
call assertTrue repo2~decisionForProposal(c1~proposalId) <> .nil, "rejection retained"
r2 = a2~analyzeTree("tests/fixtures/provider_v2", "DataStore", "MAIN", 2)
c2 = r2~candidates[1]
call assertTrue c2~proposalId <> c1~proposalId, "material SQL edit gets a new proposal identity"
call assertTrue repo2~proposal(c2~proposalId) <> .nil, "material edit re-proposed"


/* AT_LEAST comparisons are lineage-scoped; a replacement lineage is explicit risk. */
otherLineage = analyzer~analyzeTree("tests/fixtures/provider_v1", "DataStore", "NEXT", 1, "replacement lineage")
lineageDeltas = .ContractComparator~new~compare(v1tracked, otherLineage)
call assertDelta lineageDeltas, "SOURCE_LINEAGE_CHANGED"

/* Class-level OO surface changes are first-class. */
classV2 = analyzer~analyzeTree("tests/fixtures/provider_class_v2", "DataStore", "MAIN", 2, "class v2")
repo~reconcileIdentities(classV2)
classDeltas = .ContractComparator~new~compare(v1tracked, classV2)
call assertDelta classDeltas, "CLASS_CONTRACT_CHANGED"

/* Obvious external command lines use the same proposal/accept/tracked-revision model. */
repo3Root = "/tmp/osc-command-test"
address system "rm -rf '" || repo3Root || "'"
repo3 = .SemanticRepository~new(repo3Root)
a3 = .OoRexxSourceAnalyzer~new(repo3)
cmd1 = a3~analyzeTree("tests/fixtures/command_v1", "Tooling", "MAIN", 1)
call assertEq 1, cmd1~candidates~items, "CLI command proposal discovered"
call assertEq "CLI_COMMAND", cmd1~candidates[1]~kind, "CLI proposal kind"
repo3~saveSnapshot(cmd1)
cmdExternalId = repo3~recordDecision(cmd1~candidates[1]~proposalId, "ACCEPTED", "external process", "TEST")
cmdBase = repo3~loadLatest("Tooling")
call assertEq 1, cmdBase~externalOperations~items, "accepted CLI tracked"
cmd2 = a3~analyzeTree("tests/fixtures/command_v2", "Tooling", "MAIN", 2)
cmdDeltas = .ContractComparator~new~compare(cmdBase, cmd2)
call assertDelta cmdDeltas, "EXTERNAL_OPERATION_CHANGED"

/* Decisions are append-only and can be superseded without erasing the rejection. */
repo2~recordDecision(c1~proposalId, "ACCEPTED", "reviewed again", "TEST2")
latestDecision = repo2~decisionForProposal(c1~proposalId)
call assertEq "ACCEPTED", latestDecision~decision, "later decision supersedes rejection"
call assertContains latestDecision~reason, "supersedes REJECTED", "decision supersession provenance"

say "PASS test_semantic_source_control"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
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

assertContains: procedure
  use arg text, needle, label
  if pos(needle, text) = 0 then do
    say "FAIL" label "missing=" needle "in=" text
    exit 1
  end
  return

assertDelta: procedure
  use arg deltas, wanted
  do d over deltas
    if d~kind = wanted then return
  end
  say "FAIL missing delta" wanted
  exit 1

assertFinding: procedure
  use arg findings, status, needle
  do f over findings
    if f~status = status & (pos(needle~upper, f~reason~upper) > 0 | pos(needle~upper, f~provider~upper) > 0 | pos(needle~upper, f~consumer~upper) > 0) then return
  end
  say "FAIL missing finding" status needle
  do f over findings
    say "  got" f~status f~provider f~consumer f~reason
  end
  exit 1

::requires "src/SemanticSourceControl.cls"
