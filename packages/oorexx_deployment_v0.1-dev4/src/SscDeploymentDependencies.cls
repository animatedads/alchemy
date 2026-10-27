/* SSC-backed ooRexx deployment dependency resolver.
 *
 * SSC owns semantic source identity and ::requires evidence.  Deployment owns
 * selection/materialisation of the exact component closure.  This package is
 * optional so the minimal bootstrap and non-ooRexx deployment core do not
 * acquire a circular dependency on SSC.
 *
 * @source-requires SemanticSourceControl AT_LEAST 5
 */
::options numeric inherit

::class SscDeploymentDependencyResolver public
::method init
  expose requireSemanticVersionForCrossComponent
  use strict arg requireSemanticVersionForCrossComponent=.true

::method resolve
  expose requireSemanticVersionForCrossComponent
  use strict arg consumerRoot, entryPackages, providerRoots=.nil, explicitRequirements=.nil
  if providerRoots==.nil then providerRoots=.array~new
  if explicitRequirements==.nil then explicitRequirements=.array~new
  if entryPackages==.nil | entryPackages~items=0 then raise syntax 88.900 array('SSC deployment resolution requires at least one explicit ooRexx entry package')

  resolution=.DeploymentDependencyResolution~new('SSC_LOOSE_SOURCE/1 package-contract + AT_LEAST')
  entries=.directory~new
  intake=.RollupIntake~new

  consumer=self~loadComponent(consumerRoot,intake,resolution,'consumer')
  if consumer==.nil then return resolution
  entries[consumer['component']~upper]=consumer
  resolution~addComponentArtifact(consumer['artifact'])

  do root over providerRoots
    e=self~loadComponent(root,intake,resolution,'provider')
    if e==.nil then iterate
    key=e['component']~upper
    if entries~hasIndex(key) then do
      resolution~addIssue(.DeploymentDependencyIssue~new('DUPLICATE_COMPONENT','more than one supplied closure member identifies component '||e['component']))
      iterate
    end
    entries[key]=e
    resolution~addComponentArtifact(e['artifact'])
  end

  do r over explicitRequirements
    resolution~addComponentRequirement(r)
  end

  queue=.array~new
  do ep over entryPackages
    path=self~normalizePath(ep)
    if \self~snapshotHasFile(consumer['snapshot'],path) then do
      resolution~addIssue(.DeploymentDependencyIssue~new('ENTRY_PACKAGE_NOT_FOUND','consumer entry package not present in SSC snapshot: '||path))
      iterate
    end
    pair=.directory~new; pair['component']=consumer['component']; pair['path']=path
    queue~append(pair)
  end

  seen=.set~new
  cross=.set~new
  q=1
  do while q<=queue~items
    pair=queue[q]; q+=1
    component=pair['component']; path=pair['path']
    seenKey=component~upper||'|'||path~upper
    if seen~hasIndex(seenKey) then iterate
    seen~put(seenKey)
    e=entries[component~upper]
    snap=e['snapshot']

    /* Only declarations on files actually reachable from the deployment
       entry package participate in this closure.  Test/example-only source
       requirements therefore cannot accidentally become production deps. */
    do sr over snap~requirements
      if sr~path~upper=path~upper then do
        dr=.DeploymentComponentRequirement~new(sr~target,sr~minimumLevel,'MAIN',.true,sr~consumer,'SSC @source-requires')
        if \self~hasEquivalentRequirement(resolution~componentRequirements,dr) then resolution~addComponentRequirement(dr)
      end
    end

    pkg=self~packageByPath(snap,path)
    if pkg==.nil then iterate
    reqs=self~splitRequires(pkg~requiresContract)
    do reqName over reqs
      pr=.DeploymentPackageRequirement~new(component,path,reqName)
      resolution~addPackageRequirement(pr)
      matches=self~resolveRequiredFile(component,path,reqName,entries)
      if matches~items=0 then do
        resolution~addPackageBinding(.DeploymentPackageBinding~new(pr,'','',.false,'unresolved ::requires '||reqName))
        iterate
      end
      if matches~items>1 then do
        detail='ambiguous ::requires '||reqName||' candidates='
        first=.true
        do m over matches
          if \first then detail||=','
          detail||=m['component']||':'||m['path']; first=.false
        end
        resolution~addPackageBinding(.DeploymentPackageBinding~new(pr,'','',.false,detail))
        iterate
      end
      m=matches[1]
      local=(m['component']~upper=component~upper)
      reason='resolved exact package file'
      if \local then do
        reason='resolved cross-component package file'
        cross~put(m['component']~upper)
      end
      resolution~addPackageBinding(.DeploymentPackageBinding~new(pr,m['component'],m['path'],.true,reason))
      np=.directory~new; np['component']=m['component']; np['path']=m['path']; queue~append(np)
    end
  end

  /* Bind semantic component requirements to supplied immutable candidates. */
  do r over resolution~componentRequirements
    key=r~component~upper
    if \entries~hasIndex(key) then do
      resolution~addBinding(.DeploymentDependencyBinding~new(r,.nil,.false,'required component not supplied: '||r~component))
      iterate
    end
    a=entries[key]['artifact']
    if a~lineage~upper<>r~lineage~upper then do
      resolution~addBinding(.DeploymentDependencyBinding~new(r,a,.false,'source lineage mismatch: required '||r~lineage||', supplied '||a~lineage))
      iterate
    end
    if r~minimumSourceLevel<>0 then do
      if \datatype(a~sourceLevel,'W') then do
        resolution~addBinding(.DeploymentDependencyBinding~new(r,a,.false,'authoritative SSC sourceLevel absent for '||a~component))
        iterate
      end
      if a~sourceLevel<r~minimumSourceLevel then do
        resolution~addBinding(.DeploymentDependencyBinding~new(r,a,.false,'source level too low: requires AT_LEAST '||r~minimumSourceLevel||', supplied '||a~sourceLevel))
        iterate
      end
    end
    resolution~addBinding(.DeploymentDependencyBinding~new(r,a,.true,'SSC component/lineage/source minimum satisfied; compatibility still requires qualification'))
  end

  /* A bare cross-component ::requires tells us that code is needed, but not
     which semantic level is authoritative.  By default this is a deployment
     error unless the same active closure declares @source-requires (or the
     application supplied an explicit component requirement). */
  if requireSemanticVersionForCrossComponent then do c over cross
    declared=.false
    do r over resolution~componentRequirements
      if r~component~upper=c then do; declared=.true; leave; end
    end
    if \declared then resolution~addIssue(.DeploymentDependencyIssue~new('UNVERSIONED_CROSS_COMPONENT_REQUIRE','cross-component ::requires reaches '||entries[c]['component']||' but no active @source-requires/explicit component minimum declares its semantic authority'))
  end

  return resolution

::method loadComponent private
  use strict arg root,intake,resolution,role
  meta=intake~metadata(root)
  component=meta['component']
  if component='' then do
    resolution~addIssue(.DeploymentDependencyIssue~new('SSC_COMPONENT_UNKNOWN',role||' root has no authoritative component identity: '||root))
    return .nil
  end
  lineage=meta['lineage']; if lineage='' then lineage='MAIN'
  level=meta['sourceLevel']; if level='' then level='UNKNOWN'
  snap=.OoRexxSourceAnalyzer~new(.nil)~analyzeTree(root,component,lineage,level,'deployment dependency scan')
  hash=''
  call SysFileTree root||'/MANIFEST.sha256','manifestFiles.','FOS'
  if manifestFiles.0>0 then hash=.SSCUtil~contentHash(.SSCUtil~readAll(manifestFiles.1))
  artifactId=component||'/'||lineage||'/'||level
  a=.DeploymentComponentArtifact~new(component,lineage,level,root,artifactId,hash)
  if hash<>'' then a~metadata['contentAuthority']='sha256(MANIFEST.sha256 bytes; manifest verified before resolution)'
  e=.directory~new; e['component']=component; e['root']=root; e['snapshot']=snap; e['artifact']=a
  return e

::method hasEquivalentRequirement private
  use strict arg requirements,wanted
  do r over requirements
    if r~target~upper=wanted~target~upper & r~lineage~upper=wanted~lineage~upper & r~minimumSourceLevel=wanted~minimumSourceLevel then return .true
  end
  return .false

::method packageByPath private
  use strict arg snap,path
  do p over snap~packages
    if p~path~upper=path~upper then return p
  end
  return .nil

::method snapshotHasFile private
  use strict arg snap,path
  do f over snap~files
    if f~path~upper=path~upper then return .true
  end
  return .false

::method splitRequires private
  use strict arg contract
  out=.array~new
  if contract='' then return out
  parts=.SSCUtil~split(contract,' || ')
  do raw over parts
    v=raw~strip
    if v~length>=2 then do
      first=v~left(1); last=v~right(1)
      if (first='"' & last='"') | (first="'" & last="'") then v=v~substr(2,v~length-2)
    end
    v=self~normalizePath(v)
    if v<>'' then out~append(v)
  end
  return out

::method resolveRequiredFile private
  use strict arg component,consumerPath,requiredName,entries
  out=.array~new
  current=entries[component~upper]
  same=self~matchesInComponent(current,consumerPath,requiredName)
  if same~items>0 then return same
  do key over entries
    if key=component~upper then iterate
    e=entries[key]
    ext=self~matchesInComponent(e,'',requiredName)
    do m over ext; out~append(m); end
  end
  return out

::method matchesInComponent private
  use strict arg entry,consumerPath,requiredName
  out=.array~new; snap=entry['snapshot']; component=entry['component']
  candidates=.array~new
  if consumerPath<>'' then do
    d=self~dirName(consumerPath)
    if d<>'' then candidates~append(self~normalizePath(d||'/'||requiredName))
  end
  candidates~append(self~normalizePath(requiredName))

  /* Exact relative paths are strongest and correspond to direct/relative
     package references before any REXX_PATH basename search. */
  do c over candidates
    do f over snap~files
      if f~path~upper=c~upper then do
        m=.directory~new; m['component']=component; m['path']=f~path; out~append(m)
      end
    end
    if out~items>0 then return out
  end

  /* Bare names are resolved only when unique inside a component.  Ambiguity
     is retained so Deployment cannot silently choose by incidental path order. */
  if pos('/',requiredName)=0 then do f over snap~files
    if self~baseName(f~path)~upper=requiredName~upper then do
      m=.directory~new; m['component']=component; m['path']=f~path; out~append(m)
    end
  end
  return out

::method normalizePath private
  use strict arg path
  p=path~strip~changestr('\\','/')
  do while p~left(2)='./'; p=p~substr(3); end
  do while pos('//',p)>0; p=p~changestr('//','/'); end
  return p

::method dirName private
  use strict arg path
  p=path~lastPos('/')
  if p=0 then return ''
  return path~left(p-1)

::method baseName private
  use strict arg path
  p=path~lastPos('/')
  if p=0 then return path
  return path~substr(p+1)

::requires 'DeploymentDependencies.cls'
::requires 'SemanticSourceControl.cls'
