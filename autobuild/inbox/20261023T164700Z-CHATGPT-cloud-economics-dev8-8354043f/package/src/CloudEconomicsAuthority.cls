/* Cloud Economics: economic advisory route on the actual estate authority.
 * No allocator admission, lease, dispatch, reservation or cloud purchase.
 */
::class CloudEconomicAuthorityHandoff public
/* Retain exact intention route and candidate objects, without entitling them. */
::method init
  expose job decision route selectedCandidates status explanation
  use strict arg job, decision, route, selectedCandidates, status, explanation
::attribute job get
::attribute decision get
::attribute route get
::attribute selectedCandidates get
::attribute status get
::attribute explanation get
::method dispatchable
  return .false

::class CloudEconomicNodeEvidenceGate public
/* Verify an explicit quote-to-node binding against the real JNA eligibility
 * policy and job requirements. Existing-node evidence is not a VM purchase. */
::method assess
  use strict arg offer, job, binding, request, capability, capacity, nowMs, policy
  answer=.directory~new
  answer['allowed']=.false
  answer['reason']='MISSING_AUTHORITY_EVIDENCE'
  if binding==.nil | request==.nil | capability==.nil | capacity==.nil | policy==.nil then return answer
  if binding~hasIndex('offer_id')==.false | binding~hasIndex('node_id')==.false then return answer
  if binding['offer_id']<>offer['id'] | binding['node_id']<>capability~nodeId then do
    answer['reason']='OFFER_NODE_BINDING_MISMATCH'
    return answer
  end
  if request~hasMethod('requirement')==.false | request~hasMethod('jobId')==.false then return answer
  if request~jobId<>job['id'] then do
    answer['reason']='JOB_REQUEST_MISMATCH'
    return answer
  end
  req=request~requirement
  /* Reject underspecified job requirements: a 1 GiB JNA placement request
   * must not be reused to economically validate a 64 GiB job. */
  if req~minimumMemoryMiB < (job['mem']+0)*1024 | ,
     req~minimumFreeMemoryMiB < (job['mem']+0)*1024 | ,
     req~minimumCpuUnits < job['cpu']+0 | ,
     req~minimumAvailableCpuUnits < job['cpu']+0 | job['gpu']+0>0 then do
    answer['reason']='UNDERSTATED_NODE_REQUIREMENTS'
    return answer
  end
  if job['jurisdiction']<>'ANY' then do
    if req~jurisdictions~at(job['jurisdiction']~upper)==.nil then do
      answer['reason']='JURISDICTION_REQUIREMENT_MISSING'
      return answer
    end
  end
  if job['runtime']<>'ANY' then do
    if req~runtimes~at(job['runtime']~upper)==.nil then do
      answer['reason']='RUNTIME_REQUIREMENT_MISSING'
      return answer
    end
  end
  assessment=policy~assess(request,capability,capacity,nowMs)
  answer['assessment']=assessment
  answer['allowed']=assessment~eligible
  if assessment~eligible then answer['reason']='NODE_ELIGIBLE_AT_OBSERVATION'
  else answer['reason']=assessment~firstReason
  return answer

::class CloudEconomicAuthorityPlanner public
/* Route acceptance belongs to the provider's compute/allocation/WLU/router
 * assessments; market price never reverses a hard veto.
 * A real MemoryFabricCapacityPlan is mandatory before ranking split RAM. */
::method evaluate
  use strict arg job, offers, now, intentions, workload, context=.nil, history=.nil, fabricPlan=.nil, nodeEvidence=.nil, nodePolicy=.nil, fabricRegistry=.nil
  surface=intentions~discover(context)
  if surface['provider']<>'generalized.compute.intentions/0.1' then ,
    raise syntax 93.900 array('Generalized Compute Intention provider required')
  if surface['mutating'] then ,
    raise syntax 93.900 array('Mutating intention discovery prohibited')
  route=intentions~planAdmittance(workload,context)
  accepted=.directory~new
  if route~state='READY' then do
    do candidate over route~admissibleCandidates
      resource=candidate~resource
      key=''
      if resource~hasMethod('offerId') then key=resource~offerId
      else if resource~hasMethod('id') then key=resource~id
      if key<>'' then accepted[key]=candidate
    end
  end
  /* Certified fabric fragments are provider identities, not an abstract
   * two-node CPU aggregation. Only a complete same-site two-fragment plan. */
  fabricIds=.directory~new
  fabricAuthorized=.false
  if job['fabric_mode']='SEGMENTED' & fabricPlan<>.nil then do
    if fabricPlan~complete & fabricPlan~providerCount=2 then do
      numeric digits 20
      need=(job['mem']+0)*1024*1024*1024
      if fabricPlan~totalBytes>=need & fabricPlan~worstLocality<=40 then do
        fragments=fabricPlan~fragments
        if fragments[1]~providerId<>fragments[2]~providerId then do
          fabricAuthorized=.true
          do f over fragments
            fabricIds[f~providerId]=f~bytes
          end
        end
      end
    end
  end
  approved=.array~new
  candidateBindings=.directory~new
  seen=.directory~new
  do offer over offers
    id=offer['id']
    if id='' | id~pos('+')>0 | seen~hasIndex(id) then ,
      raise syntax 93.900 array('Ambiguous quote identity')
    seen[id]=.true
    if accepted~hasIndex(id)==.false then iterate
    if nodeEvidence<>.nil then do
      if nodeEvidence~hasIndex(id)==.false then iterate
      proof=nodeEvidence[id]
      if proof~hasIndex('binding')==.false | proof~hasIndex('request')==.false | ,
         proof~hasIndex('capability')==.false | proof~hasIndex('capacity')==.false then iterate
      gate=.CloudEconomicNodeEvidenceGate~new~assess(offer,job,proof['binding'], ,
        proof['request'],proof['capability'],proof['capacity'],now*1000,nodePolicy)
      if gate['allowed']==.false then iterate
    end
    /* Never mutate caller-owned quote evidence. */
    safe=.directory~new
    do field over offer~allIndexes
      safe[field]=offer[field]
    end
    safe['fabric_ok']='0'
    if fabricAuthorized & fabricRegistry<>.nil & fabricIds~hasIndex(id) & offer['fabric_ok']='1' then do
      provider=fabricRegistry~provider(id)
      if provider<>.nil then do
        if provider~siteId=offer['site'] & ,
          (offer['mem']+0)*1024*1024*1024 >= fabricIds[id] then ,
          safe['fabric_ok']='1'
      end
    end
    approved~append(safe)
    candidateBindings[id]=accepted[id]
  end
  decision=.CloudEconomicsPlanner~new~plan(job,approved,now,history)
  bindings=.array~new
  state='NOT_HANDOFF_READY'
  explanation=decision['reason']
  if decision['status']='PAPER_BUY' then do
    parts=decision['selected']~makeArray('+')
    possible=.true
    do id over parts
      if candidateBindings~hasIndex(id)==.false then possible=.false
      else bindings~append(candidateBindings[id])
      if parts~items>1 & fabricIds~hasIndex(id)==.false then possible=.false
    end
    if possible then do
      state='ADVISORY_HANDOFF_READY'
      explanation='Retained upstream candidates: fresh admission, lease and placement still required'
    end
  end
  return .CloudEconomicAuthorityHandoff~new(job,decision,route,bindings,state,explanation)

::requires 'CloudEconomics.cls'
