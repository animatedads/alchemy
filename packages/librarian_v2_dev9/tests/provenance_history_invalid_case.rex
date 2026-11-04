/* Executed separately by tests/run_librarian_tests.sh to verify fail-closed paths.
   Expected failure is a nonzero interpreter return code. */
parse arg which
one=.LibrarianTimePoint~new(1000,'Etc/UTC','2025b')
two=.LibrarianTimePoint~new(2000,'Etc/UTC','2025b')
three=.LibrarianTimePoint~new(3000,'Etc/UTC','2025b')
h=.LibrarianProvenanceHistory~new
h~append(make('orig','root','','ASSERT','source','occ','upstream','occ2','SYNDICATED','proof',one,two))
select
  when which=='DUPLICATE' then h~append(make('orig','root','','ASSERT','source','occ','upstream','occ2','SYNDICATED','proof',one,two))
  when which=='UNKNOWN_PARENT' then h~append(make('new','root','missing','CORRECT','source','occ','upstream','occ2','SYNDICATED','proof',two,three))
  when which=='FOREIGN_LINEAGE' then h~append(make('new','wrong','orig','CORRECT','source','occ','upstream','occ2','SYNDICATED','proof',two,three))
  when which=='CHILD_MUTATION' then h~append(make('new','root','orig','CORRECT','source','different','upstream','occ2','SYNDICATED','proof',two,three))
  when which=='RETROGRADE' then h~append(make('new','root','orig','CORRECT','source','occ','upstream','occ2','SYNDICATED','proof',one,one))
  when which=='EVIDENCE_EMPTY' then c=make('new','another','','ASSERT','source','occ','upstream','occ2','SYNDICATED','',one,two)
  when which=='SELF_EDGE' then c=make('new','another','','ASSERT','source','occ','source','occ','SYNDICATED','proof',one,two)
  when which=='BAD_RELATION' then c=make('new','another','','ASSERT','source','occ','upstream','occ2','BOGUS','proof',one,two)
  when which=='RETRACTION_NO_PREDECESSOR' then c=make('new','another','','RETRACT','source','occ','upstream','occ2','SYNDICATED','proof',one,two)
  when which=='ROOT_DUPLICATE' then h~append(make('new','root','','ASSERT','source','occ','upstream','occ2','SYNDICATED','proof',one,two))
  when which=='OBSERVATION_BEFORE_PUBLICATION' then c=make('new','another','','ASSERT','source','occ','upstream','occ2','SYNDICATED','proof',two,one)
  when which=='INVALID_CUTOFF' then v=h~snapshot('event','prop','2000',two)
  otherwise do
    say 'unknown fixture' which
    exit 2
  end
end
say 'ERROR expected rejection but accepted' which
exit 0
make: procedure
  use strict arg id,lineage,prior,action,child,childOcc,parent,parentOcc,relation,evidence,pub,obs
  return .LibrarianProvenanceClaim~new(id,lineage,prior,action,'event','prop',child,childOcc,'child-span',parent,parentOcc,'parent-span',relation,evidence,pub,obs)
::requires 'LibrarianProvenanceHistory.cls'
