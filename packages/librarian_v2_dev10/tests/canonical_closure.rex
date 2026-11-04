/* Regression for dev9's incomplete canonical evidence identity.
   Different claims/scope/cutoffs must have different complete serialization. */
passes=0
one=.LibrarianTimePoint~new(1000,'Etc/UTC','2025b')
two=.LibrarianTimePoint~new(2000,'Etc/UTC','2025b')
three=.LibrarianTimePoint~new(3000,'Etc/UTC','2025b')
four=.LibrarianTimePoint~new(4000,'Etc/UTC','2025b')
h=.LibrarianProvenanceHistory~new
h~append(make('a','LineA','','ASSERT','event','prop','A','occ','P1','SYNDICATED','proofA',one,two))
h~append(make('b','LineB','','ASSERT','event','prop','B','occ','P1','SYNDICATED','proofB',one,two))
s=h~snapshot('event','prop',two,two)
call ok s~activeCount==2,'two active claims'
call ok s~relationship('A','occ','B','occ')=='DECLARED_SHARED_UPSTREAM','shared upstream preserved'
call ok s~canonical\=='','nonempty canonical'
/* Same eligible evidence but later knowledge cutoff is a different snapshot identity. */
call ok s~canonical\==h~snapshot('event','prop',three,three)~canonical,'publication and observation cutoff in key'
call ok s~canonical\==h~snapshot('event','other-prop',two,two)~canonical,'proposition in key'
call ok s~canonical\==h~snapshot('other-event','prop',two,two)~canonical,'event in key'
/* Different timezone evidence must be distinguished even with the same instant. */
zone=.LibrarianTimePoint~new(2000,'Europe/London','2025b')
call ok s~canonical\==h~snapshot('event','prop',two,zone)~canonical,'cutoff timezone in key'
changedZone=.LibrarianTimePoint~new(2000,'Etc/UTC','2026a')
call ok s~canonical\==h~snapshot('event','prop',two,changedZone)~canonical,'tzdb edition in key'
/* Superseded evidence is still part of what was historically known. */
h~append(make('fix','LineA','a','CORRECT','event','prop','A','occ','P2','DERIVED','correction',three,four))
current=h~snapshot('event','prop',four,four)
hother=.LibrarianProvenanceHistory~new
hother~append(make('a','LineA','','ASSERT','event','prop','A','occ','P3','SYNDICATED','proofA',one,two))
hother~append(make('b','LineB','','ASSERT','event','prop','B','occ','P1','SYNDICATED','proofB',one,two))
hother~append(make('fix','LineA','a','CORRECT','event','prop','A','occ','P2','DERIVED','correction',three,four))
call ok current~activeCount==hother~snapshot('event','prop',four,four)~activeCount,'same projected count'
call ok current~canonical\==hother~snapshot('event','prop',four,four)~canonical,'different superseded parent remains visible'
/* Retraction records with identical IDs but different details are distinct. */
r1=.LibrarianProvenanceHistory~new
r2=.LibrarianProvenanceHistory~new
r1~append(make('root','R','','ASSERT','event','prop','A','occ','P1','DERIVED','root-proof',one,two))
r2~append(make('root','R','','ASSERT','event','prop','A','occ','P2','DERIVED','root-proof',one,two))
r1~append(make('ret','R','root','RETRACT','event','prop','A','occ','P1','DERIVED','ret-proof',three,four))
r2~append(make('ret','R','root','RETRACT','event','prop','A','occ','P2','DERIVED','ret-proof',three,four))
call ok r1~snapshot('event','prop',four,four)~canonical\==r2~snapshot('event','prop',four,four)~canonical,'retraction history identity'
/* Two unresolved branches with same IDs but different parent edges must differ. */
f1=.LibrarianProvenanceHistory~new
f2=.LibrarianProvenanceHistory~new
f1~append(make('origin','F','','ASSERT','event','prop','A','occ','P1','DERIVED','origin-evidence',one,two))
f2~append(make('origin','F','','ASSERT','event','prop','A','occ','P1','DERIVED','origin-evidence',one,two))
f1~append(make('branch1','F','origin','CORRECT','event','prop','A','occ','P2','DERIVED','same-1',three,four))
f2~append(make('branch1','F','origin','CORRECT','event','prop','A','occ','P3','DERIVED','same-1',three,four))
f1~append(make('branch2','F','origin','CORRECT','event','prop','A','occ','P4','DERIVED','same-2',three,four))
f2~append(make('branch2','F','origin','CORRECT','event','prop','A','occ','P4','DERIVED','same-2',three,four))
call ok f1~snapshot('event','prop',four,four)~conflicted==1,'conflicting tips retained'
call ok f1~snapshot('event','prop',four,four)~canonical\==f2~snapshot('event','prop',four,four)~canonical,'conflicting parent identity'
/* The ordering of independent reports must not change canonical materialisation. */
permuted=.LibrarianProvenanceHistory~new
permuted~append(make('b','LineB','','ASSERT','event','prop','B','occ','P1','SYNDICATED','proofB',one,two))
permuted~append(make('a','LineA','','ASSERT','event','prop','A','occ','P1','SYNDICATED','proofA',one,two))
call ok s~canonical==permuted~snapshot('event','prop',two,two)~canonical,'insertion order independent'
say 'PASS' passes 'dev10 canonical closure assertions'
exit 0
make: procedure
  use strict arg id,lineage,prior,action,event,prop,child,childOcc,parent,relation,evidence,pub,obs
  return .LibrarianProvenanceClaim~new(id,lineage,prior,action,event,prop,child,childOcc,'child-span',parent,'parent-occ','parent-span',relation,evidence,pub,obs)
ok: procedure expose passes
  use arg truth,title
  if \truth then do
    say 'FAIL' title
    exit 1
  end
  passes=passes+1
  return
::requires 'LibrarianProvenanceHistory.cls'
