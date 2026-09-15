change = .BitcoinCorePublicCorpus~semantic35688
beforeFlow = .CxxValueFlowAnalyzer~analyze(change~beforeSymbol)
afterFlow = .CxxValueFlowAnalyzer~analyze(change~afterSymbol)

beforeOp = change~beforeOperation
afterOp = change~afterOperation
call assertEqual 'keylen', beforeFlow~memoryLengthSubject(beforeOp), 'Bitcoin memcpy length subject'
call assertEqual 'keylen', afterFlow~memoryLengthSubject(afterOp), 'Bitcoin std::copy range length subject'
call assertTrue beforeFlow~protectingConstraint(beforeOp) \== .nil, 'Bitcoin predecessor length guard linked'
call assertTrue afterFlow~protectingConstraint(afterOp) \== .nil, 'Bitcoin successor length guard linked'
call assertEqual 64, beforeOp~destinationExtent, 'Bitcoin destination extent derived'

finding = .MemoryValueFlowHistoryRule~assess(change, beforeFlow, afterFlow)
call assertEqual 'BOUNDS_VALUE_FLOW_PROTECTION_PRESERVED', finding~classification, 'Bitcoin value-flow finding'
call assertTrue finding~evidence[2]~sourceSpan~fileRevision~blobSha == '0796bbeb3271a210ed7ed5d85a82fc76939db61a', 'Bitcoin base constraint blob'
call assertTrue finding~evidence[4]~sourceSpan~fileRevision~blobSha == 'd9e16f361107c6d66f32ad8050c658d3b01f9241', 'Bitcoin head constraint blob'

say 'GITHUB BITCOIN VALUE FLOW SMOKE: OK'
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
::requires '../src/CodeValueFlowRules.cls'
