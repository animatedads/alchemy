/* Dev8 provisional regression suite. Run with ooRexx, not Python.
   No dev8 runtime qualification has yet been claimed. */
testsPassed=0
graph=.LibrarianProvenanceGraph~new
call check graph~relationship('paperA','paperB')=='INDEPENDENCE_NOT_ESTABLISHED','unknown not independent'
graph~add(.LibrarianProvenanceEdge~new('e1','paperA','wire','SYNDICATED','src-claim-1'))
graph~add(.LibrarianProvenanceEdge~new('e2','paperB','wire','SYNDICATED','src-claim-2'))
call check graph~relationship('paperA','paperB')=='DECLARED_SHARED_UPSTREAM','shared wire declaration'
call check graph~relationship('paperA','wire')=='DECLARED_DEPENDENCY','direct dependency'
call check graph~relationship('paperA','paperA')=='SAME_SOURCE','same source'
call check graph~ancestors('paperA')~hasIndex('wire'),'ancestor index'
call check graph~independenceVerdict=='NOT_ESTABLISHED','no independence authority'
graph~add(.LibrarianProvenanceEdge~new('e3','aggregator','paperA','AGGREGATED','src-claim-3'))
graph~add(.LibrarianProvenanceEdge~new('e4','aggregator','independentBlog','QUOTED','src-claim-4'))
call check graph~ancestors('aggregator')~hasIndex('wire'),'transitive ancestry'
call check graph~ancestors('aggregator')~hasIndex('independentBlog'),'second parent retained'
call check graph~relationship('aggregator','paperB')=='DECLARED_SHARED_UPSTREAM','multi-parent upstream relationship'
call check graph~relationship('paperB','unseen')=='INDEPENDENCE_NOT_ESTABLISHED','absence of linkage not independence'
call check graph~relationship('aggregator','independentBlog')=='DECLARED_DEPENDENCY','second parent dependency'
call check graph~reaches('wire','paperA')==.false,'parent does not reach child'
say 'PASS' testsPassed 'positive provenance assertions'
/* This deliberate invalid edge would make a cycle paperA -> wire -> paperA. */
signal on syntax name expectedCycle
graph~add(.LibrarianProvenanceEdge~new('bad-cycle','wire','paperA','DERIVED','src-claim-cycle'))
say 'FAIL cycle was admitted'
exit 1
expectedCycle:
signal off syntax
call check graph~relationship('paperA','wire')=='DECLARED_DEPENDENCY','graph unchanged after rejected cycle'
say 'PASS' testsPassed 'provenance assertions including rejected cycle'
exit 0
check: procedure expose testsPassed
  use arg truth,label
  if \truth then do
    say 'FAIL' label
    exit 1
  end
  testsPassed=testsPassed+1
  return
::requires 'LibrarianProvenanceGraph.cls'
