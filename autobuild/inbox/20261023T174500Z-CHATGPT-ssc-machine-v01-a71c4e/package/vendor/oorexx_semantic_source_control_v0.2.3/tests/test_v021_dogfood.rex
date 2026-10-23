/* v0.2.1 proposal/reconciliation regressions from FederationBank dogfooding. */

/* Rexx CALL must not become SQL CALL merely because the line mentions SQL/PROC. */
repoRoot = "/tmp/osc-v021-noise"
address system "rm -rf '" || repoRoot || "'"
repo = .SemanticRepository~new(repoRoot)
an = .OoRexxSourceAnalyzer~new(repo)
noise = an~analyzeTree("tests/fixtures_v021/sql_call_noise", "Noise", "MAIN", 1)
call assertEq 1, noise~candidates~items, "ordinary CALL ASSERT lines are not SQL candidates"
call assertEq "SQL", noise~candidates[1]~kind, "stored SQL call kind"
call assertEq "CALL", noise~candidates[1]~operation, "stored procedure SQL CALL retained"
call assertContains noise~candidates[1]~statement~upper, "CALL POST_LEDGER", "stored SQL CALL statement extracted"

/* Accepted operation identity survives method extraction when semantic owner,
   operation and data source identify one unambiguous tracked operation. */
relocRoot = "/tmp/osc-v021-reloc"
address system "rm -rf '" || relocRoot || "'"
repo = .SemanticRepository~new(relocRoot)
an = .OoRexxSourceAnalyzer~new(repo)
v1 = an~analyzeTree("tests/fixtures_v021/relocate_v1", "Bank", "MAIN", 1)
call assertEq 2, v1~candidates~items, "v1 SQL candidates"
ids = .directory~new
 do c over v1~candidates
   eid = repo~recordDecision(c~proposalId, "ACCEPTED", "test accepted durability boundary", "TEST")
   source = .SQLSemantic~field(c~semanticContract, "sources")
   ids[source] = eid
 end
v2 = an~analyzeTree("tests/fixtures_v021/relocate_v2", "Bank", "MAIN", 2)
call assertEq 2, v2~candidates~items, "v2 SQL candidates"
call assertEq 2, v2~externalOperations~items, "moved operations resolved to accepted entities"
 do e over v2~externalOperations
   source = .SQLSemantic~field(e~semanticContract, "sources")
   call assertEq ids[source], e~externalId, "external identity survives method extraction for " || source
   call assertContains e~methodKey, "commitTransferPostings", "current location reflects extracted method"
 end
call assertEq 2, .SSCUtil~readLines(relocRoot || "/proposals.osc")~items, "method extraction does not create duplicate proposals"

say "PASS test_v021_dogfood"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
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

::requires "src/SemanticSourceControl.cls"
