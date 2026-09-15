fixtureRoot = value('GIT_FIXTURE_ROOT',, 'ENVIRONMENT')
if fixtureRoot = '' then fixtureRoot = '/tmp/oorexx_git_fixture'
repo = .GitRepositoryContext~new(fixtureRoot, 'fixture/example', 'https://example.invalid/fixture.git')
head = repo~commit('HEAD')
parent = repo~commit(head~parents[1])
beforeDoc = .CxxSemanticAnalyzer~analyze(repo~fileRevision(parent~sha, 'crypto.cpp'))
afterDoc = .CxxSemanticAnalyzer~analyze(repo~fileRevision(head~sha, 'crypto.cpp'))
semanticChange = .CxxSemanticAnalyzer~compareMemoryOperation(beforeDoc~symbols[1], afterDoc~symbols[1])
finding = .SemanticMemoryHistoryRule~assess(semanticChange)
call assertEqual 'BOUNDS_INVARIANT_PRESERVED', finding~classification, 'guard-preserved classification'
call assertTrue finding~evidence~items >= 4, 'guard source evidence retained'
call assertTrue finding~asBusinessFact~source == semanticChange, 'HardWorld fact retains semantic change'

lifeDoc = .CxxSemanticAnalyzer~analyze(repo~fileRevision(parent~sha, 'leak.c'))
bad = lifeDoc~symbol('bad_alloc')
transfer = lifeDoc~symbol('transfer_alloc')
good = lifeDoc~symbol('good_alloc')
call assertTrue bad \== .nil, 'bad_alloc symbol'
call assertTrue transfer \== .nil, 'transfer_alloc symbol'
call assertTrue good \== .nil, 'good_alloc symbol'
leakFinding = .MemoryLifetimeRule~assess(bad)
call assertEqual 'POSSIBLE_UNRELEASED_LOCAL_ALLOCATION', leakFinding~classification, 'bounded leak review finding'
call assertTrue leakFinding~evidence[1]~sourceSpan~fileRevision~blobSha == lifeDoc~fileRevision~blobSha, 'allocation revision identity'
transferFinding = .MemoryLifetimeRule~assess(transfer)
call assertEqual 'OWNERSHIP_TRANSFER_OBSERVED', transferFinding~classification, 'return distinguishes ownership transfer'
goodFinding = .MemoryLifetimeRule~assess(good)
call assertEqual 'ALLOCATION_RELEASE_OBSERVED', goodFinding~classification, 'release recognized'

unsafeBeforeText = 'void copy_bad(unsigned char *dst, const unsigned char *src, size_t len) {' || '0a'x || -
    '    if (len <= 64) memcpy(dst, src, len);' || '0a'x || '}' || '0a'x
unsafeAfterText = 'void copy_bad(unsigned char *dst, const unsigned char *src, size_t len) {' || '0a'x || -
    '    memcpy(dst, src, len);' || '0a'x || '}' || '0a'x
unsafeBefore = .RemoteSourceFileRevision~new('fixture/example', 'before', 'unsafe.cpp', 'blob-before', unsafeBeforeText)
unsafeAfter = .RemoteSourceFileRevision~new('fixture/example', 'after', 'unsafe.cpp', 'blob-after', unsafeAfterText)
ub = .CxxSemanticAnalyzer~analyze(unsafeBefore)~symbols[1]
ua = .CxxSemanticAnalyzer~analyze(unsafeAfter)~symbols[1]
unsafeSemantic = .CxxSemanticAnalyzer~compareMemoryOperation(ub, ua)
call assertTrue unsafeSemantic~guardRemoved, 'removed guard derived from syntax graph'
unsafeFinding = .SemanticMemoryHistoryRule~assess(unsafeSemantic)
call assertEqual 'BOUNDS_INVARIANT_REMOVED', unsafeFinding~classification, 'semantic removed-guard classification'
call assertTrue unsafeFinding~evidence[2]~sourceSpan~fileRevision~blobSha == 'blob-before', 'removed guard retains predecessor blob'
say 'CODE SEMANTIC RULES SMOKE: OK'
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

::requires '../src/CodeEvidenceRules.cls'
