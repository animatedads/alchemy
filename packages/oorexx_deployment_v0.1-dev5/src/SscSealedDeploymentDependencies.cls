/* Adapter from current Semantic Source Store sealed deployment authority into
 * the general Deployment dependency-lock contract.
 *
 * The adapter intentionally receives module/package service objects rather than
 * opening SSC persistence itself.  SSC owns resolution and semantic bytes;
 * Deployment consumes the immutable receipt/package.
 */
::options numeric inherit

::class DeploymentSscSealedDependency public
::method init
  expose requiringDeploymentId targetModuleId resolvedDeploymentId deploymentSequence manifestSha256 requirementSummary
  use strict arg requiringDeploymentId,targetModuleId,resolvedDeploymentId,deploymentSequence,manifestSha256,requirementSummary=''
::method requiringDeploymentId; expose requiringDeploymentId; return requiringDeploymentId
::method targetModuleId; expose targetModuleId; return targetModuleId
::method resolvedDeploymentId; expose resolvedDeploymentId; return resolvedDeploymentId
::method deploymentSequence; expose deploymentSequence; return deploymentSequence
::method manifestSha256; expose manifestSha256; return manifestSha256
::method requirementSummary; expose requirementSummary; return requirementSummary

::class DeploymentSscSealedIssue public
::method init
  expose kind detail
  use strict arg kind,detail
::method kind; expose kind; return kind
::method detail; expose detail; return detail

::class DeploymentSscSealedResolution public
::method init
  expose rootDeploymentId rootModuleId rootSequence rootManifestSha256 dependencies issues package sourceAuthority
  use strict arg rootDeploymentId,rootModuleId='',rootSequence=0,rootManifestSha256=''
  dependencies=.array~new
  issues=.array~new
  package=.nil
  sourceAuthority='SSC_SEALED_DEPLOYMENT/1'
::method rootDeploymentId; expose rootDeploymentId; return rootDeploymentId
::method rootModuleId; expose rootModuleId; return rootModuleId
::method rootSequence; expose rootSequence; return rootSequence
::method rootManifestSha256; expose rootManifestSha256; return rootManifestSha256
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method addDependency; expose dependencies; use strict arg d; dependencies~append(d); return self
::method dependencies; expose dependencies; return dependencies~copy
::method addIssue; expose issues; use strict arg i; issues~append(i); return self
::method issues; expose issues; return issues~copy
::method setPackage; expose package; use strict arg p; package=p; return self
::method package; expose package; return package
::method satisfied
  expose issues package rootDeploymentId rootManifestSha256
  if rootDeploymentId='' | rootManifestSha256='' then return .false
  if issues~items>0 then return .false
  if package==.nil then return .false
  return package~resolutionPolicy='sealed-deployment-exact-closure'
::method failureReason
  expose issues package rootDeploymentId rootManifestSha256
  if rootDeploymentId='' then return 'SSC root deployment id absent'
  if rootManifestSha256='' then return 'SSC root deployment manifest authority absent'
  if issues~items>0 then return issues[1]~kind||': '||issues[1]~detail
  if package==.nil then return 'SSC sealed deployment package absent'
  if package~resolutionPolicy<>'sealed-deployment-exact-closure' then return 'SSC package is not sealed exact closure: '||package~resolutionPolicy
  return ''
::method asTsv
  expose sourceAuthority rootDeploymentId rootModuleId rootSequence rootManifestSha256 dependencies package issues
  out=.array~new
  out~append('authority'||'09'x||sourceAuthority)
  out~append('deployment'||'09'x||rootModuleId||'09'x||rootDeploymentId||'09'x||rootSequence||'09'x||rootManifestSha256||'09'x||'ROOT')
  do d over dependencies
    out~append('deployment-dependency'||'09'x||d~requiringDeploymentId||'09'x||d~targetModuleId||'09'x||d~resolvedDeploymentId||'09'x||d~deploymentSequence||'09'x||d~manifestSha256||'09'x||d~requirementSummary)
  end
  if package<>.nil then do item over package~manifest
    out~append('sealed-object'||'09'x||item['module_id']||'09'x||item['deployment_id']||'09'x||item['object_id']||'09'x||item['revision_id']||'09'x||item['source_sha256']||'09'x||item['relative_path'])
  end
  do i over issues
    out~append('issue'||'09'x||i~kind||'09'x||'1'||'09'x||i~detail)
  end
  return out

::class SscSealedDeploymentDependencyResolver public
::method init
  expose moduleService packageService
  use strict arg moduleService,packageService

::method resolve
  expose moduleService packageService
  use strict arg deploymentId,projectId='default'
  root=moduleService~deployment(deploymentId)
  result=.DeploymentSscSealedResolution~new(deploymentId,root['module_id'],root['deployment_sequence'],root['manifest_sha256'])
  if root['status']<>'QUALIFIED' then do
    result~addIssue(.DeploymentSscSealedIssue~new('SSC_DEPLOYMENT_NOT_QUALIFIED','root deployment is not QUALIFIED: '||deploymentId))
    return result
  end
  if root['manifest_sha256']==.nil | root['manifest_sha256']='' then do
    result~addIssue(.DeploymentSscSealedIssue~new('SSC_DEPLOYMENT_UNSEALED','root deployment has no manifest SHA-256: '||deploymentId))
    return result
  end

  queue=.queue~new
  seen=.directory~new
  queue~queue(deploymentId)
  do while queue~items>0
    current=queue~pull
    if seen~hasIndex(current) then iterate
    dep=moduleService~deployment(current)
    if dep['status']<>'QUALIFIED' then do
      result~addIssue(.DeploymentSscSealedIssue~new('SSC_DEPENDENCY_NOT_QUALIFIED','deployment in sealed closure is not QUALIFIED: '||current))
      iterate
    end
    if dep['manifest_sha256']==.nil | dep['manifest_sha256']='' then do
      result~addIssue(.DeploymentSscSealedIssue~new('SSC_DEPENDENCY_UNSEALED','deployment in sealed closure has no manifest SHA-256: '||current))
      iterate
    end
    seen[current]=dep
    rows=moduleService~sealedDependencies(current)
    do row over rows~rows
      childId=row['resolved_deployment_id']
      child=moduleService~deployment(childId)
      if child['module_id']<>row['target_module_id'] then do
        result~addIssue(.DeploymentSscSealedIssue~new('SSC_DEPENDENCY_MODULE_MISMATCH','resolved deployment '||childId||' belongs to '||child['module_id']||', expected '||row['target_module_id']))
        iterate
      end
      if child['status']<>'QUALIFIED' then do
        result~addIssue(.DeploymentSscSealedIssue~new('SSC_DEPENDENCY_NOT_QUALIFIED','resolved deployment is not QUALIFIED: '||childId))
        iterate
      end
      if child['manifest_sha256']==.nil | child['manifest_sha256']='' then do
        result~addIssue(.DeploymentSscSealedIssue~new('SSC_DEPENDENCY_UNSEALED','resolved deployment has no manifest SHA-256: '||childId))
        iterate
      end
      result~addDependency(.DeploymentSscSealedDependency~new(current,row['target_module_id'],childId,child['deployment_sequence'],child['manifest_sha256'],row['requirement_summary']))
      queue~queue(childId)
    end
  end

  if result~issues~items>0 then return result
  package=packageService~getDeploymentPackage(deploymentId,projectId)
  result~setPackage(package)
  if package~resolutionPolicy<>'sealed-deployment-exact-closure' then do
    result~addIssue(.DeploymentSscSealedIssue~new('SSC_PACKAGE_FLOATING','package service returned non-sealed resolution policy: '||package~resolutionPolicy))
    return result
  end

  /* Every semantic object in the returned package must belong to a deployment
     proven reachable through the exact sealed dependency graph above. */
  do item over package~manifest
    itemDeployment=item['deployment_id']
    if \seen~hasIndex(itemDeployment) then result~addIssue(.DeploymentSscSealedIssue~new('SSC_PACKAGE_OUTSIDE_SEALED_CLOSURE','package contains deployment not in sealed closure: '||itemDeployment))
    if item['resolution']<>'sealed' then result~addIssue(.DeploymentSscSealedIssue~new('SSC_PACKAGE_FLOATING','package object is not marked sealed: '||item['object_id']))
  end
  return result

::requires 'DeploymentDependencies.cls'
