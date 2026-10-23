#!/usr/bin/env rexx
/* ooRexx administrative surface over the transport-neutral planner. */
parse source . . here
parse arg command rest
backend=value('OOREXX_OPERATIONAL_PLANNER',,'ENVIRONMENT')
if backend='' then backend=filespec('location',here)'opctl'
registry=.OperationalClassRegistry~new(backend)
capacity=.OperationalCapacityRegistry~new(backend)
select
  when command='set' then do
    parse var rest name rest
    normal=''; degraded=''; constrained=''; emergency=''; sort=''; deadline=''
    do while rest<>''
      parse var rest opt value rest
      select
        when opt='--normal' then normal=value
        when opt='--degraded' then degraded=value
        when opt='--constrained' then constrained=value
        when opt='--emergency' then emergency=value
        when opt='--sort' then sort=value
        when opt='--deadline-us' then deadline=value
        otherwise call fail 'unknown option:' opt
      end
    end
    if name='' | normal='' | degraded='' | constrained='' | emergency='' then call fail 'set requires NAME and all four operating-state policies'
    registry~register(name,normal,degraded,constrained,emergency,sort,deadline)
    say 'CLASS_SET name='name
  end
  when command='capacity-set' then do
    parse var rest domain nominal current .
    if domain='' | nominal='' then call fail 'capacity-set requires DOMAIN NOMINAL_BPS [CURRENT_BPS]'
    capacity~set(domain,nominal,current)
    say 'CAPACITY_SET domain='domain 'nominal_bps='nominal 'current_bps='current
  end
  when command='capacity-show' then do
    parse var rest domain .
    if domain='' then call fail 'capacity-show requires DOMAIN'
    d=capacity~show(domain)
    if d==.nil then exit 3
    say 'CAPACITY domain='d['DOMAIN'] 'nominal_bps='d['NOMINAL_BPS'] 'current_bps='d['CURRENT_BPS']
  end
  when command='capacity-list' then do
    address command backend 'capacity list'
    exit rc
  end
  when command='decision' then do
    parse var rest name state .
    if name='' | state='' then call fail 'decision requires CLASS STATE'
    d=.OperationalPlanner~new(backend)~decide(name,state)
    line='DECISION'
    do k over d; line=line k'='d[k]; end
    say line
  end
  when command='list' | command='show' then do
    address command backend 'class' command rest
    exit rc
  end
  otherwise call fail 'unknown command:' command
end
exit 0
fail:
  parse arg msg
  say 'ERROR' msg
  say 'operationalctl.rex set CLASS --normal POLICY --degraded POLICY --constrained POLICY --emergency POLICY [--sort N] [--deadline-us N]'
  say 'POLICY = disposition:rate:fallback:protected:per-context-cap:max-parallel:aggregate-cap'
  say 'operationalctl.rex decision CLASS STATE'
  say 'operationalctl.rex list | show CLASS'
  say 'operationalctl.rex capacity-set DOMAIN NOMINAL_BPS [CURRENT_BPS]'
  say 'operationalctl.rex capacity-show DOMAIN | capacity-list'
  exit 64
::requires "../rexx/OperationalPlanner.cls"
