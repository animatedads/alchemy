/* General deployment dependency model.
 *
 * Dependency authority is deliberately separate from transport and target
 * mutation.  Resolvers establish an immutable component/package closure;
 * Deployment consumes the resulting resolution before planning any mutation.
 */
::options numeric inherit

::class DeploymentComponentRequirement public
::method init
  expose target minimumSourceLevel lineage required consumer evidence metadata
  use strict arg target, minimumSourceLevel=0, lineage='MAIN', required=.true, consumer='', evidence='DECLARED', metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method target; expose target; return target
::method minimumSourceLevel; expose minimumSourceLevel; return minimumSourceLevel
::method lineage; expose lineage; return lineage
::method required; expose required; return required
::method consumer; expose consumer; return consumer
::method evidence; expose evidence; return evidence
::method metadata; expose metadata; return metadata
::method component
  expose target
  p=pos('.',target)
  if p=0 then return target
  return target~left(p-1)
::method explain
  expose target minimumSourceLevel lineage required consumer evidence
  return 'component='||target||' lineage='||lineage||' AT_LEAST='||minimumSourceLevel||' required='||required||' consumer='||consumer||' evidence='||evidence

::class DeploymentComponentArtifact public
::method init
  expose component lineage sourceLevel root artifactId artifactHash metadata
  use strict arg component,lineage='MAIN',sourceLevel='UNKNOWN',root='',artifactId='',artifactHash='',metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method component; expose component; return component
::method lineage; expose lineage; return lineage
::method sourceLevel; expose sourceLevel; return sourceLevel
::method root; expose root; return root
::method artifactId; expose artifactId; return artifactId
::method artifactHash; expose artifactHash; return artifactHash
::method metadata; expose metadata; return metadata
::method satisfies
  expose component lineage sourceLevel
  use strict arg requirement
  if component~upper<>requirement~component~upper then return .false
  if lineage~upper<>requirement~lineage~upper then return .false
  if requirement~minimumSourceLevel=0 then return .true
  if \datatype(sourceLevel,'W') then return .false
  if \datatype(requirement~minimumSourceLevel,'W') then return .false
  return sourceLevel>=requirement~minimumSourceLevel
::method identity
  expose component lineage sourceLevel artifactHash
  return component||'/'||lineage||'/'||sourceLevel||'/'||artifactHash

::class DeploymentDependencyBinding public
::method init
  expose requirement artifact satisfied reason
  use strict arg requirement,artifact=.nil,satisfied=.false,reason=''
::method requirement; expose requirement; return requirement
::method artifact; expose artifact; return artifact
::method satisfied; expose satisfied; return satisfied
::method reason; expose reason; return reason

::class DeploymentPackageRequirement public
::method init
  expose consumerComponent consumerPackage requiredName required metadata
  use strict arg consumerComponent,consumerPackage,requiredName,required=.true,metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method consumerComponent; expose consumerComponent; return consumerComponent
::method consumerPackage; expose consumerPackage; return consumerPackage
::method requiredName; expose requiredName; return requiredName
::method required; expose required; return required
::method metadata; expose metadata; return metadata
::method id
  expose consumerComponent consumerPackage requiredName
  return consumerComponent||':'||consumerPackage||' -> '||requiredName

::class DeploymentPackageBinding public
::method init
  expose requirement providerComponent providerPath satisfied reason
  use strict arg requirement,providerComponent='',providerPath='',satisfied=.false,reason=''
::method requirement; expose requirement; return requirement
::method providerComponent; expose providerComponent; return providerComponent
::method providerPath; expose providerPath; return providerPath
::method satisfied; expose satisfied; return satisfied
::method reason; expose reason; return reason

::class DeploymentDependencyIssue public
::method init
  expose kind detail required metadata
  use strict arg kind,detail,required=.true,metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method kind; expose kind; return kind
::method detail; expose detail; return detail
::method required; expose required; return required
::method metadata; expose metadata; return metadata

::class DeploymentDependencyResolution public
::method init
  expose componentRequirements componentArtifacts bindings packageRequirements packageBindings issues sourceAuthority
  use strict arg sourceAuthority='DECLARED'
  componentRequirements=.array~new
  componentArtifacts=.array~new
  bindings=.array~new
  packageRequirements=.array~new
  packageBindings=.array~new
  issues=.array~new
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method addComponentRequirement; expose componentRequirements; use strict arg v; componentRequirements~append(v); return self
::method addComponentArtifact; expose componentArtifacts; use strict arg v; componentArtifacts~append(v); return self
::method addBinding; expose bindings; use strict arg v; bindings~append(v); return self
::method addPackageRequirement; expose packageRequirements; use strict arg v; packageRequirements~append(v); return self
::method addPackageBinding; expose packageBindings; use strict arg v; packageBindings~append(v); return self
::method addIssue; expose issues; use strict arg v; issues~append(v); return self
::method componentRequirements; expose componentRequirements; return componentRequirements~copy
::method componentArtifacts; expose componentArtifacts; return componentArtifacts~copy
::method bindings; expose bindings; return bindings~copy
::method packageRequirements; expose packageRequirements; return packageRequirements~copy
::method packageBindings; expose packageBindings; return packageBindings~copy
::method issues; expose issues; return issues~copy
::method satisfied
  expose bindings packageBindings issues
  do i over issues
    if i~required then return .false
  end
  do b over bindings
    if b~requirement~required & \b~satisfied then return .false
  end
  do b over packageBindings
    if b~requirement~required & \b~satisfied then return .false
  end
  return .true
::method failureReason
  expose bindings packageBindings issues
  do i over issues
    if i~required then return i~kind||': '||i~detail
  end
  do b over bindings
    if b~requirement~required & \b~satisfied then return 'component dependency: '||b~reason
  end
  do b over packageBindings
    if b~requirement~required & \b~satisfied then return 'package dependency: '||b~reason
  end
  return ''
::method asTsv
  expose sourceAuthority componentArtifacts bindings packageBindings issues
  out=.array~new
  out~append('authority'||'09'x||sourceAuthority)
  /* Artifact rows make a dependency lock independently materialisable.  They
     identify the exact supplied component authority without embedding a
     controller-local root path in the portable lock. */
  do a over componentArtifacts
    out~append('artifact'||'09'x||a~component||'09'x||a~lineage||'09'x||a~sourceLevel||'09'x||a~artifactId||'09'x||a~artifactHash)
  end
  do b over bindings
    a=b~artifact
    aid=''; comp=''; lin=''; level=''; hash=''
    if a<>.nil then do
      aid=a~artifactId; comp=a~component; lin=a~lineage; level=a~sourceLevel; hash=a~artifactHash
    end
    out~append('component'||'09'x||b~requirement~target||'09'x||b~requirement~minimumSourceLevel||'09'x||comp||'09'x||lin||'09'x||level||'09'x||aid||'09'x||hash||'09'x||b~satisfied||'09'x||b~reason)
  end
  do b over packageBindings
    out~append('package'||'09'x||b~requirement~consumerComponent||'09'x||b~requirement~consumerPackage||'09'x||b~requirement~requiredName||'09'x||b~providerComponent||'09'x||b~providerPath||'09'x||b~satisfied||'09'x||b~reason)
  end
  do i over issues
    out~append('issue'||'09'x||i~kind||'09'x||i~required||'09'x||i~detail)
  end
  return out
