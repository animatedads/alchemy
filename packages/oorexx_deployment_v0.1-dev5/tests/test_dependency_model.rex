root=.DeploymentComponentArtifact~new('App','MAIN',3,'/app','app.zip','abc')
need=.DeploymentComponentRequirement~new('Provider.Widget.run',5,'MAIN')
prov=.DeploymentComponentArtifact~new('Provider','MAIN',5,'/provider','provider.zip','def')
call must prov~satisfies(need),'AT_LEAST component requirement satisfied'
low=.DeploymentComponentArtifact~new('Provider','MAIN',4,'/provider','provider-low.zip','ghi')
call must \low~satisfies(need),'low source level rejected'
wrong=.DeploymentComponentArtifact~new('Provider','BRANCH',9,'/provider','provider-branch.zip','jkl')
call must \wrong~satisfies(need),'different lineage rejected'

r=.DeploymentDependencyResolution~new('test')
r~addComponentArtifact(root)~addComponentArtifact(prov)
r~addComponentRequirement(need)
r~addBinding(.DeploymentDependencyBinding~new(need,prov,.true,'qualified fixture'))
p=.DeploymentPackageRequirement~new('App','src/App.cls','Provider.cls')
r~addPackageRequirement(p)~addPackageBinding(.DeploymentPackageBinding~new(p,'Provider','src/Provider.cls',.true,'resolved'))
call must r~satisfied,'resolved component/package closure satisfied'

lockLines=r~asTsv
foundApp=.false; foundProvider=.false
do line over lockLines
  if pos('artifact'||'09'x||'App'||'09'x,line)=1 then foundApp=.true
  if pos('artifact'||'09'x||'Provider'||'09'x,line)=1 then foundProvider=.true
end
call must foundApp & foundProvider,'portable lock carries artifact authority rows for all closure components'

manifest=.DeploymentManifest~new('with-deps','1')
manifest~addDependency(need)
provider=.MemoryProvider~new
target=.DeploymentTarget~new('T')
d=.Deployment~new(provider)
plan=d~plan(target,manifest)
call must \plan~executable,'unresolved dependency closure blocks planning'
manifest~setDependencyLock(r)
plan2=d~plan(target,manifest)
call must plan2~executable,'resolved dependency closure permits planning'

say 'PASS dependency model'
exit 0
must: procedure
 use strict arg c,m
 if \c then do; say 'FAIL' m; exit 1; end
return

::class MemoryProvider subclass DeploymentProvider
::method discover
 use strict arg target,manifest
 return .DeploymentDiscovery~new(target)
::method assessRequirement
 use strict arg target,req,discovery,manifest
 return .DeploymentAssessmentItem~new(req,req~expected,.true,'')
::requires 'Deployment.cls'
::requires 'DeploymentDependencies.cls'
