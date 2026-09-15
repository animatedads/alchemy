newline = '0a'x
text = '#include <stdlib.h>' || newline || -
'void alias_free(size_t n) {' || newline || -
'    void *p = malloc(n);' || newline || -
'    void *q = p;' || newline || -
'    free(q);' || newline || -
'}' || newline || -
'void *alias_return(size_t n) {' || newline || -
'    void *p = malloc(n);' || newline || -
'    void *q = p;' || newline || -
'    return q;' || newline || -
'}' || newline || -
'void handoff(void *p);' || newline || -
'void escape_to_call(size_t n) {' || newline || -
'    void *p = malloc(n);' || newline || -
'    handoff(p);' || newline || -
'}' || newline || -
'void unresolved(size_t n) {' || newline || -
'    void *p = malloc(n);' || newline || -
'    if (n == 0) return;' || newline || -
'}' || newline
rev = .RemoteSourceFileRevision~new('fixture/ownership', 'r1', 'ownership.c', 'blob-owner', text)
doc = .CxxSemanticAnalyzer~analyze(rev)

aliasFree = doc~symbol('alias_free')
flow = .CxxValueFlowAnalyzer~analyze(aliasFree)
call assertTrue flow~exactEquivalent('p', 'q'), 'pointer alias retained'
f = .MemoryOwnershipFlowRule~assess(aliasFree, flow)
call assertEqual 'ALLOCATION_RELEASE_VIA_ALIAS_OBSERVED', f~classification, 'free via alias recognized'
call assertTrue f~evidence[1]~sourceSpan~fileRevision~blobSha == 'blob-owner', 'allocation provenance retained'

aliasReturn = doc~symbol('alias_return')
f2 = .MemoryOwnershipFlowRule~assess(aliasReturn)
call assertEqual 'OWNERSHIP_TRANSFER_VIA_ALIAS_OBSERVED', f2~classification, 'return via alias recognized'

escape = doc~symbol('escape_to_call')
f3 = .MemoryOwnershipFlowRule~assess(escape)
call assertEqual 'OWNERSHIP_ESCAPES_TO_CALL_UNRESOLVED', f3~classification, 'unknown call escape blocks false leak verdict'
call assertTrue f3~counterEvidence~items >= 1, 'escape call retained as counterevidence'

unresolved = doc~symbol('unresolved')
f4 = .MemoryOwnershipFlowRule~assess(unresolved)
call assertEqual 'POSSIBLE_UNRELEASED_LOCAL_ALLOCATION', f4~classification, 'unresolved local remains review finding'

say 'CODE OWNERSHIP FLOW SMOKE: OK'
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
