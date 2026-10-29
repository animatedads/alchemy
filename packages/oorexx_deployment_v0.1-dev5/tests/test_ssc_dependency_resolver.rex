parse arg consumerRoot providerRoot
if consumerRoot='' | providerRoot='' then do; say 'FAIL roots required'; exit 2; end
entries=.array~of('src/SscDeploymentDependencies.cls')
providers=.array~of(providerRoot)
r=.SscDeploymentDependencyResolver~new~resolve(consumerRoot,entries,providers)
call must r~satisfied,'SSC-backed closure resolves'
call must r~componentRequirements~items>=1,'active @source-requires discovered'
found=.false
do b over r~bindings
  if b~requirement~component~upper='SEMANTICSOURCECONTROL' then do
    found=.true
    call must b~satisfied,'SemanticSourceControl requirement satisfied'
    call must b~artifact~sourceLevel>=5,'SemanticSourceControl source level authority retained'
  end
end
call must found,'SemanticSourceControl component binding present'
foundPkg=.false
do b over r~packageBindings
  if b~providerComponent~upper='SEMANTICSOURCECONTROL' then foundPkg=.true
end
call must foundPkg,'cross-component ::requires resolved to SSC provider'

missing=.SscDeploymentDependencyResolver~new~resolve(consumerRoot,entries,.array~new)
call must \missing~satisfied,'missing SSC provider fails closed'

say 'PASS SSC dependency resolver'
exit 0
must: procedure
 use strict arg c,m
 if \c then do
   say 'FAIL' m
   exit 1
 end
return
::requires 'SscDeploymentDependencies.cls'
