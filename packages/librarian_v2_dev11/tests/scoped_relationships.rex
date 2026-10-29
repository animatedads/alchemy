/* Dev11: disagreements and dependency cycles affect reachable subgraphs only. */
passes=0
t1=.LibrarianTimePoint~new(1000,'Etc/UTC','2025b')
t2=.LibrarianTimePoint~new(2000,'Etc/UTC','2025b')
t3=.LibrarianTimePoint~new(3000,'Etc/UTC','2025b')
t4=.LibrarianTimePoint~new(4000,'Etc/UTC','2025b')
h=.LibrarianProvenanceHistory~new
/* Known shared upstream, independent of the disputed article family. */
h~append(make('a','LA','','ASSERT','A','a','WIRE','wire','SYNDICATED','e-a',t1,t2))
h~append(make('b','LB','','ASSERT','B','b','WIRE','wire','SYNDICATED','e-b',t1,t2))
h~append(make('c','LC','','ASSERT','C','c','A','a','DERIVED','e-c',t1,t2))
base=h~snapshot('event','prop',t2,t2)
call ok base~relationship('A','a','B','b')=='DECLARED_SHARED_UPSTREAM','undisputed upstream'
call ok base~relationship('C','c','B','b')=='DECLARED_SHARED_UPSTREAM','transitive shared upstream'
call ok base~relationship('C','c','A','a')=='DECLARED_DEPENDENCY','direct dependency'
/* Two corrections from the same original report form unresolved fork. */
h~append(make('x','LX','','ASSERT','X','x','SRC1','s1','DERIVED','e-x',t1,t2))
h~append(make('x2','LX','x','CORRECT','X','x','SRC2','s2','DERIVED','e-x2',t2,t3))
h~append(make('x3','LX','x','CORRECT','X','x','SRC3','s3','DERIVED','e-x3',t2,t3))
h~append(make('y','LY','','ASSERT','Y','y','X','x','DERIVED','e-y',t2,t3))
fork=h~snapshot('event','prop',t3,t3)
call ok fork~conflicted==1,'one unresolved lineage'
call ok fork~relationship('X','x','SRC2','s2')=='INDETERMINATE_CONFLICT','disputed child fails closed'
call ok fork~relationship('Y','y','SRC2','s2')=='INDETERMINATE_CONFLICT','downstream of disputed node fails closed'
call ok fork~relationship('A','a','B','b')=='DECLARED_SHARED_UPSTREAM','disagreement not global'
call ok fork~relationship('C','c','A','a')=='DECLARED_DEPENDENCY','unrelated direct dependency still known'
call ok fork~relationship('C','c','B','b')=='DECLARED_SHARED_UPSTREAM','unrelated transitive relationship still known'
call ok fork~relationship('A','a','UNKNOWN','none')=='INDEPENDENCE_NOT_ESTABLISHED','unknown independence is still unknown'
/* Publication/observation cutoff predating both corrections is unaffected. */
earlier=h~snapshot('event','prop',t2,t2)
call ok earlier~conflicted==0,'early view does not know corrections'
call ok earlier~relationship('X','x','SRC1','s1')=='DECLARED_DEPENDENCY','historical original path'
/* Unrelated cycle is a global diagnostic but must not poison other pairs. */
h~append(make('u','LU','','ASSERT','U','u','V','v','DERIVED','e-u',t3,t4))
h~append(make('v','LV','','ASSERT','V','v','U','u','DERIVED','e-v',t3,t4))
h~append(make('q','LQ','','ASSERT','Q','q','U','u','DERIVED','e-q',t3,t4))
withCycle=h~snapshot('event','prop',t4,t4)
call ok withCycle~hasCycle==.true,'global cycle still detectable'
call ok withCycle~relationship('U','u','V','v')=='UNRESOLVED_CYCLE','cycle-local dependency fails closed'
call ok withCycle~relationship('Q','q','V','v')=='UNRESOLVED_CYCLE','downstream of cycle fails closed'
call ok withCycle~relationship('A','a','B','b')=='DECLARED_SHARED_UPSTREAM','cycle does not poison unrelated shared source'
call ok withCycle~relationship('C','c','A','a')=='DECLARED_DEPENDENCY','cycle does not poison unrelated direct source'
call ok withCycle~relationship('X','x','SRC2','s2')=='INDETERMINATE_CONFLICT','conflict continues to take precedence on affected path'
call ok withCycle~canonical\==fork~canonical,'knowledge additions change canonical identity'
/* An alleged corroboration edge must not falsely propagate uncertainty. */
h~append(make('k','LK','','ASSERT','K','k','X','x','CORROBORATION_CLAIM','e-k',t3,t4))
corro=h~snapshot('event','prop',t4,t4)
call ok corro~relationship('K','k','X','x')=='INDETERMINATE_CONFLICT','disputed node remains uncertain despite corroboration claim'
call ok corro~relationship('K','k','B','b')=='INDEPENDENCE_NOT_ESTABLISHED','corroboration does not import conflict'
say 'PASS' passes 'dev11 scoped relationship assertions'
exit 0
make: procedure
  use strict arg id,lineage,prior,action,child,childOcc,parent,parentOcc,relation,evidence,pub,obs
  return .LibrarianProvenanceClaim~new(id,lineage,prior,action,'event','prop',child,childOcc,'child-span:'||id,parent,parentOcc,'parent-span:'||id,relation,evidence,pub,obs)
ok: procedure expose passes
  use arg truth,label
  if \truth then do
    say 'FAIL' label
    exit 1
  end
  passes=passes+1
  return
::requires 'LibrarianProvenanceHistory.cls'
