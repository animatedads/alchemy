module=.FakeModuleService~new
module~addDeployment('dep-app','App',7,'QUALIFIED','aaaa')
module~addDeployment('dep-lib','Lib',12,'QUALIFIED','bbbb')
module~addDependency('dep-app','Lib','dep-lib','minimum qualified Lib')
package=.FakePackage~new('sealed-deployment-exact-closure')
package~addObject('App','dep-app','obj-app','rev-app','1111','src/App.cls','sealed')
package~addObject('Lib','dep-lib','obj-lib','rev-lib','2222','src/Lib.cls','sealed')
resolver=.SscSealedDeploymentDependencyResolver~new(module,.FakePackageService~new(package))
r=resolver~resolve('dep-app')
call must r~satisfied,'qualified sealed SSC deployment closure accepted'
call must r~dependencies~items=1,'exact dependency deployment retained'
call must r~sourceAuthority='SSC_SEALED_DEPLOYMENT/1','sealed SSC authority retained'

floating=.FakePackage~new('latest-accepted-unless-pinned')
r2=.SscSealedDeploymentDependencyResolver~new(module,.FakePackageService~new(floating))~resolve('dep-app')
call must \r2~satisfied,'floating development package rejected for sealed deployment'

bad=.FakeModuleService~new
bad~addDeployment('dep-app','App',7,'QUALIFIED','aaaa')
bad~addDeployment('dep-lib','WrongLib',12,'QUALIFIED','bbbb')
bad~addDependency('dep-app','Lib','dep-lib','bad target')
r3=.SscSealedDeploymentDependencyResolver~new(bad,.FakePackageService~new(package))~resolve('dep-app')
call must \r3~satisfied,'sealed dependency module mismatch rejected'

say 'PASS SSC sealed deployment dependency model'
exit 0

must: procedure
 use strict arg c,m
 if \c then do; say 'FAIL' m; exit 1; end
return

::class FakeRows public
::method init
 expose rows
 use strict arg rows
::method rows
 expose rows
 return rows

::class FakeModuleService public
::method init; expose deployments deps; deployments=.directory~new; deps=.directory~new
::method addDeployment
 expose deployments
 use strict arg id,moduleId,seq,status,hash
 d=.directory~new; d['deployment_id']=id; d['module_id']=moduleId; d['deployment_sequence']=seq; d['status']=status; d['manifest_sha256']=hash
 deployments[id]=d; return self
::method addDependency
 expose deps
 use strict arg parent,target,child,summary
 if \deps~hasIndex(parent) then deps[parent]=.array~new
 r=.directory~new; r['target_module_id']=target; r['resolved_deployment_id']=child; r['requirement_summary']=summary
 deps[parent]~append(r); return self
::method deployment
 expose deployments
 use strict arg id
 return deployments[id]
::method sealedDependencies
 expose deps
 use strict arg id
 if deps~hasIndex(id) then a=deps[id]; else a=.array~new
 return .FakeRows~new(a)

::class FakePackage public
::method init
 expose resolutionPolicy manifest resourceManifest
 use strict arg resolutionPolicy
 manifest=.array~new; resourceManifest=.array~new
::method resolutionPolicy; expose resolutionPolicy; return resolutionPolicy
::method manifest; expose manifest; return manifest
::method resourceManifest; expose resourceManifest; return resourceManifest
::method addObject
 expose manifest
 use strict arg moduleId,deploymentId,objectId,revisionId,sourceHash,path,resolution
 d=.directory~new; d['module_id']=moduleId; d['deployment_id']=deploymentId; d['object_id']=objectId; d['revision_id']=revisionId; d['source_sha256']=sourceHash; d['relative_path']=path; d['resolution']=resolution
 manifest~append(d); return self

::class FakePackageService public
::method init
 expose package
 use strict arg package
::method getDeploymentPackage
 expose package
 use strict arg deploymentId,projectId='default'
 return package

::requires 'SscSealedDeploymentDependencies.cls'
