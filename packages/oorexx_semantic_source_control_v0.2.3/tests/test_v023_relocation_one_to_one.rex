/* v0.2.3 FederationBank level-7 one-to-many relocation regression. */
repoRoot = "/tmp/osc-v023-reloc"
address system "rm -rf '" || repoRoot || "'"
repo = .SemanticRepository~new(repoRoot)
an = .OoRexxSourceAnalyzer~new(repo)

v1 = an~analyzeTree("tests/fixtures_v023/relocate_v1", "Bank", "MAIN", 1)
call assertEq 2, v1~candidates~items, "v1 candidates"
do c over v1~candidates
  eid = repo~recordDecision(c~proposalId, "ACCEPTED", "fixture tracked operation", "TEST")
end
/* Decisions invalidate the derived view; re-resolve before accepting level 1. */
repo~reconcileTrackingSet(v1, .nil, .false)
call assertEq 2, v1~externalOperations~items, "v1 tracked"
repo~saveSnapshot(v1)

v2 = an~analyzeTree("tests/fixtures_v023/relocate_v2", "Bank", "MAIN", 2)
call assertEq 2, v2~candidates~items, "v2 candidates"
call assertEq 2, v2~externalOperations~items, "v2 legitimate method extraction retains identities"
call assertEq 0, pendingCount(repo, v2), "v2 pending"
repo~reconcileIdentities(v2)
repo~saveSnapshot(v2)

v3 = an~analyzeTree("tests/fixtures_v023/relocate_v3", "Bank", "MAIN", 3)
call assertEq 7, v3~candidates~items, "v3 candidates"
call assertEq 2, v3~externalOperations~items, "only continuing transfer operations retain old identities"
call assertEq 5, pendingCount(repo, v3), "new same-table operations remain independent proposals"
call assertEq 7, .SSCUtil~readLines(repoRoot || "/proposals.osc")~items, "proposal ledger contains original 2 plus 5 genuinely new sites"

say "PASS test_v023_relocation_one_to_one"
exit 0

pendingCount: procedure
  use arg repo, snap
  n = 0
  do c over snap~candidates
    if repo~candidateStatus(c, snap) = "PENDING" then n += 1
  end
  return n

assertEq: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "src/SemanticSourceControl.cls"
