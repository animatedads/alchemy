numeric digits 50
failures=0

A=.Maths~set(.array~of(1,2,2,3))
call check A~cardinality=3,'set removes duplicates'
call check A~contains(2),'set membership'
B=.Maths~set(.array~of(3,4))
call check A~union(B)~cardinality=4,'set union'
call check A~intersection(B)~equals(.Maths~set(.array~of(3))),'set intersection'
call check A~difference(B)~equals(.Maths~set(.array~of(1,2))),'set difference'

D=.Maths~set(.array~of(1,2,3))
C=.Maths~set(.array~of('a','b','c'))
f=.Maths~map(D,C,.array~of(.array~of(1,'a'),.array~of(2,'b'),.array~of(3,'c')))
call check f~apply(2)='b','map application'
call check f~bijective,'map bijection'

g=.Maths~map(C,D,.array~of(.array~of('a',3),.array~of('b',2),.array~of('c',1)))
h=f~compose(g)
call check h~apply(1)=3 & h~apply(3)=1,'map composition'

R=.Maths~relation(D,D,.array~of(.array~of(1,1),.array~of(2,2),.array~of(3,3)))
call check R~equivalence,'identity relation is equivalence'

Z2=.Maths~set(.array~of(0,1))
table=.array~of(.array~of(0,0,0),.array~of(0,1,1),.array~of(1,0,1),.array~of(1,1,0))
group=.Maths~finiteGroup(Z2,table,0)
call check group~valid,'Z2 operation satisfies group axioms'
call check group~abelian,'Z2 group is abelian'
call check group~order=2,'group order'
monoid=.Maths~finiteMonoid(Z2,table,0)
call check monoid~valid,'Z2 addition table is also a monoid'

mult=.array~of(.array~of(0,0,0),.array~of(0,1,0),.array~of(1,0,0),.array~of(1,1,1))
ring=.Maths~finiteRing(Z2,table,mult,0,1)
call check ring~valid,'Z2 satisfies ring axioms'
call check ring~commutative & ring~unital,'Z2 ring is commutative and unital'
field=.Maths~finiteField(Z2,table,mult,0,1)
call check field~valid & field~order=2,'Z2 satisfies finite field axioms'

idMap=.Maths~map(Z2,Z2,.array~of(.array~of(0,0),.array~of(1,1)))
hom=.Maths~groupHomomorphism(group,group,idMap)
call check hom~valid,'identity map preserves group operation'
call check hom~isomorphism,'identity homomorphism is an isomorphism'
call check hom~kernel~equals(.Maths~set(.array~of(0))),'identity homomorphism kernel is identity only'

th=.Maths~theorem('demo.parity','The sum of two even integers is even')
lemma=.MathLemma~new('demo.even.definition','An even integer is divisible by two')
th~addDependency(lemma)
proof=.Maths~proofArtifact(th~id,th~revision,'DERIVATION','ooRexx Maths','0.19','VERIFIED','tests/test_theory_foundations.rex')
th~attachProof(proof)
call check th~state='PROVED','verified derivation promotes theorem state'
call check th~dependencies~items=1,'theorem dependency retained'

formal=.Maths~proofArtifact(th~id,th~revision,'FORMAL','Lean','4.x','FORMALLY_VERIFIED','example')
th~attachProof(formal)
call check th~state='FORMALIZED','formal proof promotes theorem state'

th~withdraw
call check th~state='WITHDRAWN','withdrawal is explicit theorem state'

stale=.Maths~proofArtifact(th~id,2,'DERIVATION','demo','1','VERIFIED','stale')
staleRejected=.false
signal on syntax name staleProof
th~attachProof(stale)
signal off syntax
signal staleDone
staleProof:
  say 'expected stale-proof rejection rc='rc 'sigl='sigl 'condition='condition('C') 'description='condition('D')
  staleRejected=.true
  signal off syntax
staleDone:
call check staleRejected,'proof artifact for another revision is rejected'

c=.Maths~conjecture('demo.open','An intentionally open statement')
call check c~kind='CONJECTURE' & c~state='PROPOSED','conjecture remains proposed without proof'
counter=.Maths~proofArtifact(c~id,c~revision,'COUNTEREXAMPLE','ooRexx Maths','0.19','VERIFIED','constructed witness')
c~attachProof(counter)
call check c~state='DISPROVED','verified counterexample disproves statement'

cat=.Maths~theoryCatalogue
r1=.Maths~theorem('demo.revision','First statement',.nil,1)
r2=.Maths~theorem('demo.revision','Corrected statement',.nil,2)
cat~add(r1); cat~add(r2)
call check cat~revisionCount('demo.revision')=2,'catalogue retains statement revision history'
call check cat~latest('demo.revision')~revision=2,'catalogue selects latest numerical revision'
call check cat~revision('demo.revision',1)~text='First statement','catalogue retrieves exact historical revision'

if failures=0 then do; say 'PASS oorexx_maths theory foundations 29 assertions'; exit 0; end
say 'FAIL oorexx_maths theory foundations failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathsBootstrap.cls'
