#!/usr/bin/env rexx
/* Administrative planner for named, multi-source Storage Fabric acquisition.
 * No IP address is accepted: offers identify logical storage peers only. */
parse source . . here
root=filespec('location',here)'..'
::requires (root'/src/StorageParallelFetch.cls')
::requires 'ServiceDescriptors.cls'
::requires 'OperationalPlanner.cls'

parse arg command rest
if command='' | command='help' | command='--help' then do; call usage; exit 0; end
serviceRegistry=value('OOREXX_SERVICE_REGISTRY',,'ENVIRONMENT')
if serviceRegistry='' then serviceRegistry='services.tsv'
plannerCmd=value('OOREXX_OPERATIONAL_PLANNER',,'ENVIRONMENT')
if plannerCmd='' then plannerCmd='opctl'
control=.StorageOperationalFetchControl~new(.ServiceRegistry~new(serviceRegistry),.OperationalPlanner~new(plannerCmd))

select
  when command='policy' then do
    parse var rest service state .
    if service='' | state='' then call fail 'policy requires SERVICE STATE'
    p=control~policyForService(service,state)
    call emitPolicy p
  end
  when command='plan' then do
    parse var rest service object startOffset endOffset state rest
    if service='' | object='' | datatype(startOffset,'W')=0 | datatype(endOffset,'W')=0 | state='' then call fail 'plan requires SERVICE OBJECT START END STATE'
    offers=.array~new
    do while rest<>''
      parse var rest opt rest
      if opt<>'--offer' then call fail 'unknown option:' opt
      parse var rest spec rest
      parse var spec peer ':' a ':' b
      if peer='' | datatype(a,'W')=0 | datatype(b,'W')=0 then call fail 'offer syntax PEER:START:END'
      offers~append(.StorageRangeOffer~new(peer,object,a,b,.true,'operator'))
    end
    plan=control~plan(service,object,startOffset,endOffset,state,offers)
    call emitPolicy plan~policy
    say 'PLAN object='object 'start='startOffset 'end='endOffset 'sources='plan~requestedSources 'effective_inbound_percent='plan~effectiveInboundPercent
    do s over plan~slices
      say 'SLICE peer='s~peerId 'start='s~startOffset 'end='s~endOffset 'bytes='s~length 'class='s~operationalClass 'cap_percent='s~perContextCapPercent
    end
  end
  otherwise call fail 'unknown command:' command
end
exit 0

emitPolicy:
  use arg p
  say 'POLICY class='p~className 'state='p~state 'action='p~disposition 'per_context_cap_percent='p~effectivePerContextPercent 'max_parallel_contexts='p~maxParallelContexts 'aggregate_cap_percent='p~aggregateCapPercent 'maximum_aggregate_percent='p~maximumAggregatePercent
  return
fail:
  parse arg msg
  say 'ERROR' msg
  call usage
  exit 64
usage:
  say 'storagefetchctl.rex policy SERVICE normal|degraded|constrained|emergency'
  say 'storagefetchctl.rex plan SERVICE OBJECT START END STATE --offer PEER:START:END [--offer ...]'
  say 'All PEER values are logical service/fabric peers. IP addresses are rejected.'
  return
