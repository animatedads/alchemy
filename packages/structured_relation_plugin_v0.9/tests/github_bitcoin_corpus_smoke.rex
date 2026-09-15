repo = .BitcoinCorePublicCorpus~build
call assertEqual 'bitcoin/bitcoin', repo~slug, 'repo slug'
pr = repo~pullRequest(35688)
call assertEqual 'l0rinc', pr~author, 'PR author'
call assertEqual 'OPEN', pr~state, 'PR state'
call assertEqual .false, pr~draft, 'PR not draft'
call assertEqual 1, pr~codeChanges~items, 'code change evidence'
change = pr~codeChanges[1]
call assertEqual 'memcpy', change~beforeOperation~api, 'before operation'
call assertEqual 'std::copy', change~afterOperation~api, 'after operation'
call assertEqual 'CRYPTOGRAPHIC_KEY_MATERIAL', change~beforeOperation~property('sensitiveDomain'), 'crypto domain'
call assertEqual 'EMPTY_RANGE_DEFINED', change~afterOperation~property('rangeSemantics'), 'defined empty-range semantics'
call assertTrue change~reviews~items >= 2, 'review disagreement/quality evidence retained'
perf = repo~pullRequest(31868)
call assertEqual .true, perf~draft, 'performance PR draft state'
call assertTrue perf~claimsByCategory('UNCERTAINTY')~items >= 1, 'performance caveat retained'
vec = repo~pullRequest(34083)
call assertEqual 'theuni', vec~author, 'vectorization author'
call assertTrue vec~claimsByCategory('GENERATED_CODE_EVIDENCE')~items = 1, 'asm/IR evidence claim retained'
call assertTrue vec~checks~items = 1, 'CI state retained separately'
say 'GITHUB BITCOIN CORPUS SMOKE: OK'
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
