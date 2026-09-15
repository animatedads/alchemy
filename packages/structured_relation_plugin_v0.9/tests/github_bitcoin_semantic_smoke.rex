change = .BitcoinCorePublicCorpus~semantic35688
call assertTrue change~beforeSymbol \== .nil, 'Bitcoin base symbol modeled'
call assertTrue change~afterSymbol \== .nil, 'Bitcoin head symbol modeled'
call assertEqual '0796bbeb3271a210ed7ed5d85a82fc76939db61a', change~beforeSymbol~sourceSpan~fileRevision~blobSha, 'public base blob identity'
call assertEqual 'd9e16f361107c6d66f32ad8050c658d3b01f9241', change~afterSymbol~sourceSpan~fileRevision~blobSha, 'public head blob identity'
call assertEqual 'BYTE_COPY', change~beforeOperation~operationKind, 'public predecessor operation'
call assertEqual 64, change~beforeOperation~destinationExtent, 'public destination extent retained'
call assertEqual 'keylen', change~beforeOperation~lengthExpression, 'public length expression retained'
call assertTrue change~beforeOperation~valueOrigins~items >= 2, 'public parameter origins retained'
call assertEqual 'RANGE_COPY', change~afterOperation~operationKind, 'public successor operation'
call assertTrue change~guardPreserved, 'public guard relation retained'
finding = .SemanticMemoryHistoryRule~assess(change)
call assertEqual 'BOUNDS_INVARIANT_PRESERVED', finding~classification, 'public semantic classification'
call assertTrue finding~evidence~items >= 5, 'public PR/change evidence linked'
fact = finding~asBusinessFact
call assertTrue fact~isEvidenceBearing, 'public finding is evidence bearing'
call assertTrue fact~source == change, 'public HardWorld source is semantic change'
say 'GITHUB BITCOIN SEMANTIC SMOKE: OK'
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
