/* Tests time-scoped exact-occurrence source provenance with no bias authority. */
passes=0
first=.LibrarianTimePoint~new(1000,'Etc/UTC','2025b')
second=.LibrarianTimePoint~new(2000,'Etc/UTC','2025b')
third=.LibrarianTimePoint~new(3000,'Etc/UTC','2025b')
fourth=.LibrarianTimePoint~new(4000,'Etc/UTC','2025b')
fifth=.LibrarianTimePoint~new(5000,'Etc/UTC','2025b')
h=.LibrarianProvenanceHistory~new
h~append(claim('a1','A','','ASSERT','A-ed1','a-s1','agency-v1','wire-para','SYNDICATED','src-a1',first,second))
h~append(claim('b1','B','','ASSERT','B-ed1','b-s1','agency-v1','wire-para','SYNDICATED','src-b1',first,second))
old=h~snapshot('event','prop',first,first)
call ok old~activeCount==0,'observation cutoff not publication cutoff'
current=h~snapshot('event','prop',second,second)
call ok current~activeCount==2,'two active source dependencies'
call ok current~relationship('A-ed1','a-s1','B-ed1','b-s1')=='DECLARED_SHARED_UPSTREAM','shared wire occurrence'
call ok current~independenceVerdict=='NOT_ESTABLISHED','never infer independence'
call ok current~recordsSeen==2,'historical knowledge count'
call ok current~hasCycle==.false,'acyclic initial graph'
/* Corroboration claim is not dependency evidence. */
h~append(claim('c1','C','','ASSERT','C-ed1','c-s1','agency-v1','wire-para','CORROBORATION_CLAIM','src-c1',first,second))
three=h~snapshot('event','prop',second,second)
call ok three~activeCount==3,'corroboration evidence retained'
call ok three~relationship('C-ed1','c-s1','B-ed1','b-s1')=='INDEPENDENCE_NOT_ESTABLISHED','corroboration does not establish shared origin'
/* Multiple upstreams are legal in distinct provenance lineages. */
h~append(claim('a2','A2','','ASSERT','A-ed1','a-s1','blog-v4','quoted-line','QUOTED','src-a2',second,third))
more=h~snapshot('event','prop',third,third)
call ok more~relationship('A-ed1','a-s1','blog-v4','quoted-line')=='DECLARED_DEPENDENCY','multiple parents retained'
/* A known correction at later observation time must not rewrite earlier view. */
h~append(claim('a3','A','a1','CORRECT','A-ed1','a-s1','otherwire-v2','w2-line','DERIVED','src-a3',third,fourth))
cut=h~snapshot('event','prop',third,third)
call ok cut~relationship('A-ed1','a-s1','B-ed1','b-s1')=='DECLARED_SHARED_UPSTREAM','correction not observed yet'
corrected=h~snapshot('event','prop',fourth,fourth)
call ok corrected~relationship('A-ed1','a-s1','B-ed1','b-s1')=='INDEPENDENCE_NOT_ESTABLISHED','new source is not proven independent'
call ok corrected~activeCount==4,'correction replaces one lineage tip'
/* Retraction removes dependency but preserves historical original. */
h~append(claim('a4','A','a3','RETRACT','A-ed1','a-s1','otherwire-v2','w2-line','DERIVED','src-a4',fourth,fifth))
pre=h~snapshot('event','prop',fourth,fourth)
call ok pre~activeCount==4,'pre-retraction historical view'
post=h~snapshot('event','prop',fifth,fifth)
call ok post~retracted==1,'retraction explicitly counted'
call ok post~activeCount==3,'withdrawn edge removed'
call ok post~relationship('A-ed1','a-s1','blog-v4','quoted-line')=='DECLARED_DEPENDENCY','other lineage retained'
/* Explicit fork from prior correction creates unresolved evidence, not arbitrary winner. */
h~append(claim('a5','A','a3','CORRECT','A-ed1','a-s1','other-agency','agency-line','DERIVED','src-a5',fourth,fifth))
fork=h~snapshot('event','prop',fifth,fifth)
call ok fork~conflicted==1,'fork is unresolved conflict'
call ok fork~relationship('A-ed1','a-s1','blog-v4','quoted-line')=='INDETERMINATE_CONFLICT','conservative conflict projection'
/* Reordered independent entries must have identical canonical serialized evidence. */
h2=.LibrarianProvenanceHistory~new
h2~append(claim('b1','B','','ASSERT','B-ed1','b-s1','agency-v1','wire-para','SYNDICATED','src-b1',first,second))
h2~append(claim('c1','C','','ASSERT','C-ed1','c-s1','agency-v1','wire-para','CORROBORATION_CLAIM','src-c1',first,second))
h2~append(claim('a1','A','','ASSERT','A-ed1','a-s1','agency-v1','wire-para','SYNDICATED','src-a1',first,second))
call ok h2~snapshot('event','prop',second,second)~canonical==three~canonical,'deterministic serialization of permutations'
/* A separate event/proposition must never appear in this snapshot. */
h~append(.LibrarianProvenanceClaim~new('foreign','Foreign','','ASSERT','other','other-prop','X-ed','occ','span','Y-ed','occ','span','QUOTED','foreign-evidence',first,second))
call ok h~snapshot('event','prop',second,second)~recordsSeen==3,'event and proposition isolation'
/* Separate claim revisions may create a provenance cycle: fail closed. */
cyc=.LibrarianProvenanceHistory~new
cyc~append(claim('cycle1','CY1','','ASSERT','X-ed','x-s1','Y-ed','y-s1','DERIVED','e-c1',first,second))
cyc~append(claim('cycle2','CY2','','ASSERT','Y-ed','y-s1','X-ed','x-s1','DERIVED','e-c2',first,second))
cycView=cyc~snapshot('event','prop',second,second)
call ok cycView~hasCycle==.true,'cycle detected in historical snapshot'
call ok cycView~relationship('X-ed','x-s1','Y-ed','y-s1')=='UNRESOLVED_CYCLE','cycle rejects ancestry verdict'
say 'PASS' passes 'provenance-history assertions'
exit 0
claim: procedure
  use strict arg id,lineage,prior,action,childEdition,childOccurrence,parentEdition,parentOccurrence,relation,evidenceId,pub,obs
  return .LibrarianProvenanceClaim~new(id,lineage,prior,action,'event','prop',childEdition,childOccurrence,'child-span:'||id,parentEdition,parentOccurrence,'parent-span:'||id,relation,evidenceId,pub,obs)
ok: procedure expose passes
  use arg truth,title
  if \truth then do
    say 'FAIL' title
    exit 1
  end
  passes=passes+1
  return
::requires 'LibrarianProvenanceHistory.cls'
