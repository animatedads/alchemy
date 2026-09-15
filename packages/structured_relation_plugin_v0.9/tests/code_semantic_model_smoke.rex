fixtureRoot = value('GIT_FIXTURE_ROOT',, 'ENVIRONMENT')
if fixtureRoot = '' then fixtureRoot = '/tmp/oorexx_git_fixture'
repo = .GitRepositoryContext~new(fixtureRoot, 'fixture/example', 'https://example.invalid/fixture.git')
head = repo~commit('HEAD')
parent = repo~commit(head~parents[1])
beforeFile = repo~fileRevision(parent~sha, 'crypto.cpp')
afterFile = repo~fileRevision(head~sha, 'crypto.cpp')

beforeDoc = .CxxSemanticAnalyzer~analyze(beforeFile)
afterDoc = .CxxSemanticAnalyzer~analyze(afterFile)
call assertEqual 1, beforeDoc~symbols~items, 'before function count'
call assertEqual 1, afterDoc~symbols~items, 'after function count'
beforeSymbol = beforeDoc~symbols[1]
afterSymbol = afterDoc~symbols[1]
call assertEqual 'copy_key', beforeSymbol~qualifiedName, 'symbol name'
call assertTrue beforeSymbol~sourceSpan~fileRevision~blobSha == beforeFile~blobSha, 'symbol tied to predecessor blob'
call assertTrue afterSymbol~sourceSpan~fileRevision~blobSha == afterFile~blobSha, 'symbol tied to successor blob'
call assertEqual 3, beforeSymbol~parameters~items, 'parameter origins retained'
call assertEqual 1, beforeSymbol~guards~items, 'before guard retained'
call assertEqual 'len <= 64', beforeSymbol~guards[1]~condition, 'guard condition'

beforeOps = beforeSymbol~operations
call assertEqual 1, beforeOps~items, 'before operation count'
call assertEqual 'BYTE_COPY', beforeOps[1]~operationKind, 'memcpy semantic kind'
call assertEqual 'len', beforeOps[1]~lengthExpression, 'length expression'
call assertTrue beforeOps[1]~parentGuard \== .nil, 'memcpy retains dominating guard'
call assertTrue beforeOps[1]~valueOrigins~items >= 2, 'parameter origin links'

afterOps = afterSymbol~operations
call assertEqual 1, afterOps~items, 'after operation count'
call assertEqual 'RANGE_COPY', afterOps[1]~operationKind, 'std::copy semantic kind'
call assertTrue afterOps[1]~parentGuard \== .nil, 'std::copy retains dominating guard'
change = .CxxSemanticAnalyzer~compareMemoryOperation(beforeSymbol, afterSymbol)
call assertTrue change~guardPreserved, 'semantic guard preservation'
call assertTrue \change~guardRemoved, 'guard not removed'
call assertTrue beforeSymbol~cfg~edges~items >= 1, 'control-flow edges retained'
call assertEqual 'CODE_SEMANTIC_CHANGE', change~provenance['kind'], 'semantic change provenance'
say 'CODE SEMANTIC MODEL SMOKE: OK'
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

::requires '../src/CodeSemanticSource.cls'
