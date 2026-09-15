repo = .BitcoinCorePublicCorpus~build
pr = repo~pullRequest(35688)
change = pr~codeChanges[1]
finding = .ContextualMemoryRule~assess(change)
call assertEqual 'SEMANTIC_SAFETY_REFINEMENT', finding~classification, 'contextual memory classification'
call assertTrue finding~evidence~items >= 6, 'rich evidence retained'
fact = finding~asBusinessFact
call assertEqual 'CODE_FINDING', fact~semanticType, 'HardWorld fact semantic type'
call assertTrue fact~source == change, 'HardWorld fact keeps change object'
call assertTrue fact~diagnostics~items = 1, 'finding diagnostic preserved'

perf = .PerformanceEvidenceRule~assess(repo~pullRequest(31868))
call assertEqual 'PERFORMANCE_CHANGE_UNSETTLED', perf~classification, 'draft performance evidence state'
call assertTrue perf~counterEvidence~items >= 1, 'remeasurement caveat retained'
vec = .PerformanceEvidenceRule~assess(repo~pullRequest(34083))
call assertEqual 'PERFORMANCE_CHANGE_UNSETTLED', vec~classification, 'vectorization unsettled state'
call assertTrue vec~counterEvidence~items >= 2, 'uncertainty and CI state retained'

/* Synthetic counter-example: removing a known guard should classify differently. */
loc = .RemoteCodeLocation~new('fixture/example', 'a', 'crypto.cpp', 2, 2)
p1 = .table~new; p1['guard'] = 'len <= 64'; p1['destinationExtent'] = 64; p1['sensitiveDomain'] = 'CRYPTOGRAPHIC_KEY_MATERIAL'
p2 = .table~new; p2['guard'] = ''; p2['destinationExtent'] = 64; p2['sensitiveDomain'] = 'CRYPTOGRAPHIC_KEY_MATERIAL'
before = .CodeOperationEvidence~new('BYTE_COPY', 'memcpy', loc, .array~new, p1)
after = .CodeOperationEvidence~new('BYTE_COPY', 'memcpy', loc, .array~new, p2)
syntheticPr = .GitHubPullRequestEvidence~new('fixture/example', 1, 'perf change', 'OPEN', .false, 'tester', 'a', 'b', 'https://example.invalid/pr/1', '2026-08-20')
unsafeChange = .CodeChangeEvidence~new(before, after, syntheticPr)
hazard = .ContextualMemoryRule~assess(unsafeChange)
call assertEqual 'BOUNDS_INVARIANT_REMOVED', hazard~classification, 'removed invariant distinguished from API name'
say 'CODE EVIDENCE RULE SMOKE: OK'
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say 'ASSERT TRUE FAILED:' label
    exit 1
  end
return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say 'ASSERT EQUAL FAILED:' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
return

::requires '../src/BitcoinCorePublicCorpus.cls'
::requires '../src/CodeEvidenceRules.cls'
