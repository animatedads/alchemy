graph=.LibrarianProvenanceGraph~new
graph~add(.LibrarianProvenanceEdge~new('e1','A','B','DERIVED','proof-1'))
graph~add(.LibrarianProvenanceEdge~new('e2','B','A','DERIVED','proof-2'))
say 'FAIL accepted a cycle'
exit 0
::requires 'LibrarianProvenanceGraph.cls'
