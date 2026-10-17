#!/usr/bin/env rexx
parse source . . here
lib=filespec('location',here)'../rexx/ServiceDescriptors.cls'
::requires (lib)

parse arg command rest
if command='' | command='help' | command='--help' then do
  call usage
  exit 0
end

registryPath=value('OOREXX_SERVICE_REGISTRY',,'ENVIRONMENT')
if registryPath='' then registryPath='services.tsv'
r=.ServiceRegistry~new(registryPath)

select
  when command='add' then do
    parse var rest name rest
    opClass=''; peer=''; point=''; description=''
    do while rest<>''
      parse var rest opt rest
      select
        when opt='--class' then parse var rest opClass rest
        when opt='--peer' then parse var rest peer rest
        when opt='--point' then parse var rest point rest
        when opt='--description' then do; description=rest; rest=''; end
        otherwise call fail 'unknown option:' opt
      end
    end
    if name='' | opClass='' then call fail 'add requires NAME --class CLASS'
    d=.ServiceDescriptor~new(name,opClass,peer,point,.true,description)
    r~register(d)
    call emit d
  end
  when command='set-class' then do
    parse var rest name className .
    if name='' | className='' then call fail 'set-class requires NAME CLASS'
    if \r~setClass(name,className) then exit 2
    call emit r~resolve(name,.false)
  end
  when command='set-peer' then do
    parse var rest name peer .
    if name='' then call fail 'set-peer requires NAME LOGICAL_PEER'
    if \r~setPeer(name,peer) then exit 2
    call emit r~resolve(name,.false)
  end
  when command='set-point' then do
    parse var rest name point .
    if name='' | point='' then call fail 'set-point requires NAME SERVICE_POINT'
    if \r~setPoint(name,point) then exit 2
    call emit r~resolve(name,.false)
  end
  when command='remove' then do
    parse var rest name .
    if \r~remove(name) then exit 2
  end
  when command='enable' then do
    parse var rest name .
    if \r~enable(name) then exit 2
  end
  when command='disable' then do
    parse var rest name .
    if \r~disable(name) then exit 2
  end
  when command='show' | command='resolve' then do
    parse var rest name .
    d=r~resolve(name,command='resolve')
    if d=.nil then exit 2
    call emit d
  end
  when command='list' then do
    do d over r~list; call emit d; end
  end
  when command='decision' | command='capacity' | command='policy' then do
    parse var rest name state rest
    d=r~resolve(name)
    if d=.nil then exit 2
    planner=value('OOREXX_OPERATIONAL_PLANNER',,'ENVIRONMENT')
    if planner='' then planner='opctl'
    out.=''; err.=''
    address command planner 'decide' d~operationalClass state with output stem out. error stem err.
    if rc<>0 then do
      do i=1 to err.0; say err.i; end
      exit rc
    end
    say 'SERVICE name='d~name 'class='d~operationalClass 'state='state
    do i=1 to out.0; say out.i; end
  end
  when command='peer-services' then do
    parse var rest peer .
    do d over r~servicesForPeer(peer); call emit d; end
  end
  otherwise call fail 'unknown command:' command
end
exit 0

emit:
  use arg d
  state='disabled'; if d~enabled then state='enabled'
  say 'SERVICE name='d~name 'class='d~operationalClass 'peer='d~routePeer 'point='d~servicePoint 'state='state
  return

fail:
  parse arg msg
  say 'ERROR' msg
  call usage
  exit 64

usage:
  say 'servicectl.rex add NAME --class CLASS [--peer LOGICAL_PEER] [--point SERVICE_POINT] [--description TEXT]'
  say 'servicectl.rex remove|enable|disable|show|resolve NAME'
  say 'servicectl.rex set-class NAME CLASS'
  say 'servicectl.rex set-peer NAME LOGICAL_PEER'
  say 'servicectl.rex set-point NAME SERVICE_POINT'
  say 'servicectl.rex list'
  say 'servicectl.rex decision|policy|capacity NAME normal|degraded|constrained|emergency'
  say 'servicectl.rex peer-services LOGICAL_PEER'
  say 'Environment: OOREXX_SERVICE_REGISTRY=/path/services.tsv'
  say 'IP addresses are deliberately rejected here; configure them only in the transport route table.'
  return
