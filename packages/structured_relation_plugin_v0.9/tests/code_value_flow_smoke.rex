newline = '0a'x

goodText = '#include <cstring>' || newline || -
'void guarded_alias(const unsigned char *src, size_t len) {' || newline || -
'    unsigned char buf[64];' || newline || -
'    size_t n = len;' || newline || -
'    if (n <= 64) {' || newline || -
'        memcpy(buf, src, n);' || newline || -
'    }' || newline || -
'}' || newline

goodRev = .RemoteSourceFileRevision~new('fixture/valueflow', 'good', 'good.cpp', 'blob-good', goodText)
goodSymbol = .CxxSemanticAnalyzer~analyze(goodRev)~symbol('guarded_alias')
call assertTrue goodSymbol \== .nil, 'good symbol parsed'
goodFlow = .CxxValueFlowAnalyzer~analyze(goodSymbol)
call assertTrue goodFlow~exactEquivalent('n', 'len'), 'exact alias lineage retained'
goodOp = goodSymbol~operations('BYTE_COPY')[1]
call assertEqual 'n', goodFlow~memoryLengthSubject(goodOp), 'write length subject'
goodConstraint = goodFlow~protectingConstraint(goodOp)
call assertTrue goodConstraint \== .nil, 'alias guard protects write length'
call assertEqual 64, goodConstraint~maximumValue, 'guard maximum normalized'
call assertTrue goodConstraint~sourceSpan~fileRevision~blobSha == 'blob-good', 'constraint source blob retained'

wrongText = '#include <cstring>' || newline || -
'void wrong_guard(const unsigned char *src, size_t len, size_t other) {' || newline || -
'    unsigned char buf[64];' || newline || -
'    if (other <= 64) {' || newline || -
'        memcpy(buf, src, len);' || newline || -
'    }' || newline || -
'}' || newline
wrongRev = .RemoteSourceFileRevision~new('fixture/valueflow', 'wrong', 'wrong.cpp', 'blob-wrong', wrongText)
wrongSymbol = .CxxSemanticAnalyzer~analyze(wrongRev)~symbol('wrong_guard')
wrongFlow = .CxxValueFlowAnalyzer~analyze(wrongSymbol)
wrongOp = wrongSymbol~operations('BYTE_COPY')[1]
call assertTrue wrongFlow~hasDominatingConstraint(wrongOp), 'nearby dominating guard observed'
call assertTrue wrongFlow~protectingConstraint(wrongOp) == .nil, 'wrong variable guard not credited'

derivedText = '#include <cstring>' || newline || -
'void derived_length(const unsigned char *src, size_t len) {' || newline || -
'    unsigned char buf[64];' || newline || -
'    size_t n = len + 1;' || newline || -
'    if (len <= 64) {' || newline || -
'        memcpy(buf, src, n);' || newline || -
'    }' || newline || -
'}' || newline
derivedRev = .RemoteSourceFileRevision~new('fixture/valueflow', 'derived', 'derived.cpp', 'blob-derived', derivedText)
derivedSymbol = .CxxSemanticAnalyzer~analyze(derivedRev)~symbol('derived_length')
derivedFlow = .CxxValueFlowAnalyzer~analyze(derivedSymbol)
call assertTrue derivedFlow~derivesFrom('n', 'len'), 'derived lineage retained'
call assertTrue \derivedFlow~exactEquivalent('n', 'len'), 'derived expression not treated as exact alias'
derivedOp = derivedSymbol~operations('BYTE_COPY')[1]
call assertTrue derivedFlow~protectingConstraint(derivedOp) == .nil, 'guard on len does not prove len+1 safe'

beforeChange = .CodeSemanticChange~new(goodSymbol, derivedSymbol, goodOp, derivedOp)
historyFinding = .MemoryValueFlowHistoryRule~assess(beforeChange, goodFlow, derivedFlow)
call assertEqual 'BOUNDS_VALUE_FLOW_PROTECTION_REMOVED', historyFinding~classification, 'value-flow history catches semantic weakening'
call assertTrue historyFinding~asBusinessFact~source == beforeChange, 'HardWorld fact retains value-flow semantic change'

say 'CODE VALUE FLOW SMOKE: OK'
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

::requires '../src/CodeValueFlowRules.cls'
