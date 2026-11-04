passes=0
graph=.LibrarianProvenanceGraph~new
call ok graph~relationship('A','B')=='INDEPENDENCE_NOT_ESTABLISHED','unknown does not establish independence'
graph~add(.LibrarianProvenanceEdge~new('a','A','WIRE','SYNDICATED','evidence-a'))
graph~add(.LibrarianProvenanceEdge~new('b','B','WIRE','SYNDICATED','evidence-b'))
call ok graph~relationship('A','B')=='DECLARED_SHARED_UPSTREAM','shared wire provenance'
call ok graph~relationship('A','WIRE')=='DECLARED_DEPENDENCY','direct dependency'
call ok graph~relationship('A','A')=='SAME_SOURCE','same source'
call ok graph~ancestors('A')~hasIndex('WIRE'),'ancestor index'
graph~add(.LibrarianProvenanceEdge~new('c','COMBINED','A','AGGREGATED','evidence-c'))
graph~add(.LibrarianProvenanceEdge~new('d','COMBINED','INDEPENDENT-BLOG','QUOTED','evidence-d'))
call ok graph~ancestors('COMBINED')~hasIndex('WIRE'),'transitive ancestor'
call ok graph~ancestors('COMBINED')~hasIndex('INDEPENDENT-BLOG'),'second parent'
call ok graph~relationship('COMBINED','INDEPENDENT-BLOG')=='DECLARED_DEPENDENCY','multiple parents'
call ok graph~relationship('UNSEEN','B')=='INDEPENDENCE_NOT_ESTABLISHED','unknown ancestry'
call ok graph~independenceVerdict=='NOT_ESTABLISHED','no authority'
say 'PASS' passes 'dev8 graph assertions'
exit 0
ok: procedure expose passes
  use arg truth,label
  if \truth then do
    say 'FAIL' label
    exit 1
  end
  passes=passes+1
  return
::requires 'LibrarianProvenanceGraph.cls'
