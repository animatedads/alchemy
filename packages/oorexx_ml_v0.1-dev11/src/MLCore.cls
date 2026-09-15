/* MLCore.cls
 *
 * ooRexx ML v0.1-dev2: driveable, branchable learning objects.
 *
 * State history uses JournalPointedState.  Journal values held here are
 * immutable-by-contract snapshot objects or scalar values; live arrays and
 * directories are copied at the semantic boundary.
 */

::class MLFrozenVector public
::method init
  expose values
  use strict arg source
  if \source~isA(.Array) then raise syntax 88.900 array("MLFrozenVector requires Array")
  values=.array~new
  do item over source; values~append(item); end
::method items; expose values; return values~items
::method size; expose values; return values~items
::method at; expose values; use strict arg i; return values[i]
::method '[]'; expose values; use strict arg i; return values[i]
::method toArray
  expose values
  out=.array~new; do item over values; out~append(item); end; return out
::method canonicalText
  expose values
  text='['; first=.true
  do item over values
    if \first then text=text||','
    first=.false
    if item==.nil then text=text||'<NULL>'; else text=text||item
  end
  return text||']'
::method string; return self~canonicalText

::class MLFrozenMap public
::method init
  expose keys values
  use strict arg source
  if \source~isA(.Directory) then raise syntax 88.900 array("MLFrozenMap requires Directory")
  keys=source~allIndexes; keys~sort
  values=.directory~new
  do key over keys; values[key]=source[key]; end
::method hasIndex; expose values; use strict arg key; return values~hasIndex(key)
::method at; expose values; use strict arg key; return values[key]
::method '[]'; expose values; use strict arg key; return values[key]
::method allIndexes
  expose keys
  out=.array~new; do key over keys; out~append(key); end; return out
::method items; expose keys; return keys~items
::method toDirectory
  expose keys values
  out=.directory~new; do key over keys; out[key]=values[key]; end; return out
::method canonicalText
  expose keys values
  lines=.array~new
  do key over keys
    value=values[key]
    if value==.nil then valueText='<NULL>'
    else if value~hasMethod('CANONICALTEXT') then valueText=value~canonicalText
    else valueText=value
    lines~append(key||'='||valueText)
  end
  return lines~makeString('L')
::method string; return self~canonicalText

::class MLBranch public
::attribute name
::attribute parent
::attribute forkPoint
::attribute headPoint
::attribute createdTag
::method init
  use strict arg name,parent,forkPoint,headPoint,createdTag=''
  self~name=name; self~parent=parent; self~forkPoint=forkPoint; self~headPoint=headPoint; self~createdTag=createdTag
::method canonicalText
  return 'BRANCH='||self~name||'|parent='||self~parent||'|fork='||self~forkPoint~string||'|head='||self~headPoint~string||'|tag='||self~createdTag

::class MLDriveableObject public
::method init
  expose stableId kind state branches currentBranch controller componentId autoFutureNumber
  use strict arg stableId,kind='ML_OBJECT',initial=.nil
  if initial==.nil then initial=.directory~new
  if \initial~isA(.Directory) then raise syntax 88.900 array("MLDriveableObject initial state must be Directory")
  state=.JournalPointedState~new(initial,'ML:'||stableId)
  branches=.directory~new
  currentBranch='main'
  branches['main']=.MLBranch~new('main','',state~rootPoint,state~journalPoint,'ROOT')
  controller=.nil; componentId=''; autoFutureNumber=1
::method stableId; expose stableId; return stableId
::method kind; expose kind; return kind
::method journalPoint; expose state; return state~journalPoint
::method currentPoint; return self~journalPoint
::method rootPoint; expose state; return state~rootPoint
::method journalCanMoveTo
  expose state
  use strict arg point
  return state~journalCanMoveTo(point)
::method journalAttachController
  expose controller componentId
  use strict arg newController,newComponentId
  controller=newController; componentId=newComponentId; return self
::method journalDetachController
  expose controller componentId
  controller=.nil; componentId=''; return self
::method journalMoveTo
  expose state controller componentId
  use strict arg point,notify=.true
  p=state~journalMoveTo(point,.false)
  if notify & controller\==.nil then controller~participantChanged(componentId,p,'MOVE','MOVE',.nil)
  return p
::method snapshot; expose state; return state~snapshot
::method stateAt; expose state; use strict arg point; return state~reconstruct(point)
::method at; expose state; use strict arg key; return state~at(key)
::method hasState; expose state; use strict arg key; return state~hasIndex(key)
::method retainedNodeCount; expose state; return state~retainedNodeCount
::method diff; expose state; use strict arg fromPoint,toPoint; return state~diff(fromPoint,toPoint)
::method currentBranch; expose currentBranch; return currentBranch
::method branchNames
  expose branches
  names=branches~allIndexes; names~sort; return names
::method branch
  expose branches
  use strict arg name
  if branches~hasIndex(name) then return branches[name]
  return .nil
::method branchHead
  expose branches
  use strict arg name
  if \branches~hasIndex(name) then raise syntax 88.900 array('unknown ML branch',name)
  return branches[name]~headPoint
::method fork
  expose branches currentBranch state
  use strict arg name,fromPoint=.nil,tag='FORK'
  if branches~hasIndex(name) then raise syntax 88.900 array('ML branch already exists',name)
  if fromPoint==.nil then fromPoint=state~journalPoint
  if \state~journalCanMoveTo(fromPoint) then raise syntax 88.900 array('ML fork point is not retained',name)
  parent=currentBranch
  branches[name]=.MLBranch~new(name,parent,fromPoint,fromPoint,tag)
  state~journalMoveTo(fromPoint,.false)
  currentBranch=name
  return branches[name]
::method checkout
  expose branches currentBranch state controller componentId
  use strict arg name
  if \branches~hasIndex(name) then raise syntax 88.900 array('unknown ML branch',name)
  state~journalMoveTo(branches[name]~headPoint,.false)
  currentBranch=name
  if controller\==.nil then controller~participantChanged(componentId,state~journalPoint,'MOVE','CHECKOUT',.nil)
  return state~journalPoint
::method rollback
  expose branches currentBranch state autoFutureNumber controller componentId
  use strict arg point,preserveAs=''
  if \state~journalCanMoveTo(point) then raise syntax 88.900 array('ML rollback point is not retained')
  oldHead=branches[currentBranch]~headPoint
  if oldHead~nodeId<>point~nodeId then do
    if preserveAs='' then do
      preserveAs=currentBranch||'~future-'||autoFutureNumber
      autoFutureNumber=autoFutureNumber+1
    end
    if branches~hasIndex(preserveAs) then raise syntax 88.900 array('ML preserved-future branch already exists',preserveAs)
    branches[preserveAs]=.MLBranch~new(preserveAs,currentBranch,point,oldHead,'ROLLBACK_PRESERVED_FUTURE')
  end
  state~journalMoveTo(point,.false)
  branches[currentBranch]~headPoint=point
  if controller\==.nil then controller~participantChanged(componentId,point,'MOVE','ROLLBACK',.nil)
  return point
::method rollForward
  use strict arg branchName
  return self~checkout(branchName)
::method mutate
  expose state branches currentBranch controller componentId
  use strict arg changes,tag='MUTATE',metadata=.nil
  if \changes~isA(.Directory) then raise syntax 88.900 array('ML mutation requires Directory')
  before=state~journalPoint~nodeId
  edit=state~beginEdit(tag,metadata)
  do key over changes~allIndexes; edit~put(key,changes[key]); end
  p=edit~commit
  branches[currentBranch]~headPoint=p
  if p~nodeId\=before & controller\==.nil then controller~participantChanged(componentId,p,'CHANGE',tag,metadata)
  return p
::method removeState
  expose state branches currentBranch controller componentId
  use strict arg key,tag='REMOVE',metadata=.nil
  before=state~journalPoint~nodeId
  edit=state~beginEdit(tag,metadata); edit~remove(key); p=edit~commit
  branches[currentBranch]~headPoint=p
  if p~nodeId\=before & controller\==.nil then controller~participantChanged(componentId,p,'CHANGE',tag,metadata)
  return p
::method canonicalState
  snap=self~snapshot
  keys=snap~allIndexes; keys~sort; lines=.array~new
  do key over keys
    value=snap[key]
    if value==.nil then valueText='<NULL>'
    else if value~hasMethod('CANONICALTEXT') then valueText=value~canonicalText
    else valueText=value
    lines~append(key||'='||valueText)
  end
  return lines~makeString('L')

::class MLExperimentBranch public
::attribute name
::attribute parent
::attribute forkCheckpoint
::attribute headCheckpoint
::method init
  use strict arg name,parent,forkCheckpoint,headCheckpoint
  self~name=name; self~parent=parent; self~forkCheckpoint=forkCheckpoint; self~headCheckpoint=headCheckpoint

::class MLExperiment public
::method init
  expose id controller participants branches currentBranch autoFutureNumber
  use strict arg id='ML-EXPERIMENT'
  controller=.StateOfNationController~new
  participants=.directory~new
  branches=.directory~new
  currentBranch='main'; autoFutureNumber=1
  cp=controller~checkpoint('experiment-root','EXPERIMENT_ROOT')
  branches['main']=.MLExperimentBranch~new('main','',cp,cp)
::method id; expose id; return id
::method controller; expose controller; return controller
::method register
  expose controller participants
  use strict arg componentId,object
  controller~register(componentId,object); participants[componentId]=object; return object
::method participant
  expose participants
  use strict arg componentId
  if participants~hasIndex(componentId) then return participants[componentId]
  return .nil
::method participantIds; expose participants; return participants~allIndexes
::method checkpoint
  expose controller branches currentBranch
  use strict arg label='checkpoint',eventName='ML',metadata=.nil
  cp=controller~checkpoint(label,eventName,metadata)
  branches[currentBranch]~headCheckpoint=cp
  return cp
::method currentCheckpoint
  expose branches currentBranch
  return branches[currentBranch]~headCheckpoint
::method branchNames
  expose branches
  names=branches~allIndexes; names~sort; return names
::method branch
  expose branches currentBranch controller
  use strict arg name,fromCheckpoint=.nil
  if branches~hasIndex(name) then raise syntax 88.900 array('ML experiment branch already exists',name)
  if fromCheckpoint==.nil then fromCheckpoint=branches[currentBranch]~headCheckpoint
  parent=currentBranch
  controller~restore(fromCheckpoint)
  branches[name]=.MLExperimentBranch~new(name,parent,fromCheckpoint,fromCheckpoint)
  currentBranch=name
  return branches[name]
::method checkout
  expose branches currentBranch controller
  use strict arg name
  if \branches~hasIndex(name) then raise syntax 88.900 array('unknown ML experiment branch',name)
  controller~restore(branches[name]~headCheckpoint)
  currentBranch=name
  return branches[name]~headCheckpoint
::method rollback
  expose branches currentBranch controller autoFutureNumber
  use strict arg checkpoint,preserveAs=''
  oldHead=branches[currentBranch]~headCheckpoint
  if oldHead~checkpointId<>checkpoint~checkpointId then do
    if preserveAs='' then do; preserveAs=currentBranch||'~future-'||autoFutureNumber; autoFutureNumber=autoFutureNumber+1; end
    if branches~hasIndex(preserveAs) then raise syntax 88.900 array('ML experiment preserved future already exists',preserveAs)
    branches[preserveAs]=.MLExperimentBranch~new(preserveAs,currentBranch,checkpoint,oldHead)
  end
  controller~restore(checkpoint)
  branches[currentBranch]~headCheckpoint=checkpoint
  return checkpoint
::method rollForward
  use strict arg branchName
  return self~checkout(branchName)
::method barrier
  use strict arg barrier
  meta=.directory~new; meta['barrierId']=barrier~id; meta['reason']=barrier~reason; meta['barrier']=barrier
  return self~checkpoint('barrier:'||barrier~id,'LEARNING_BARRIER',meta)
::method currentBranch; expose currentBranch; return currentBranch

::class MLSourceIdentity public
::attribute component
::attribute lineage
::attribute sourceLevel
::attribute label
::attribute revision
::attribute digest
::method init
  use strict arg component='',lineage='',sourceLevel='',label='',revision='',digest=''
  self~component=component; self~lineage=lineage; self~sourceLevel=sourceLevel; self~label=label; self~revision=revision; self~digest=digest
::method fromSnapshot class
  use strict arg source,revision='',digest=''
  return self~new(source~component,source~lineage,source~sourceLevel,source~label,revision,digest)
::method canonicalText
  return 'SOURCE='||self~component||'|lineage='||self~lineage||'|level='||self~sourceLevel||'|label='||self~label||'|revision='||self~revision||'|digest='||self~digest

::class MLLearningBarrier public
::attribute id
::attribute reason
::attribute beforeSource
::attribute afterSource
::attribute metadata
::method init
  use strict arg id,reason,beforeSource=.nil,afterSource=.nil,metadata=.nil
  self~id=id; self~reason=reason; self~beforeSource=beforeSource; self~afterSource=afterSource; self~metadata=metadata
::method canonicalText
  beforeText='<NULL>'; afterText='<NULL>'
  if self~beforeSource\==.nil then beforeText=self~beforeSource~canonicalText
  if self~afterSource\==.nil then afterText=self~afterSource~canonicalText
  return 'BARRIER='||self~id||'|reason='||self~reason||'|before={'||beforeText||'}|after={'||afterText||'}'

::class MLAssessment public
::attribute kind
::attribute value
::attribute confidence
::attribute modelId
::attribute modelPoint
::attribute branch
::attribute evidence
::attribute limitations
::attribute claimType
::method init
  use strict arg kind,value,confidence=.nil,modelId='',modelPoint='',branch='',evidence=.nil,limitations='',claimType='ADVISORY'
  self~kind=kind; self~value=value; self~confidence=confidence; self~modelId=modelId; self~modelPoint=modelPoint; self~branch=branch; self~evidence=evidence; self~limitations=limitations; self~claimType=claimType
::method canonicalText
  return 'ASSESSMENT='||self~kind||'|value='||self~value||'|confidence='||self~confidence||'|model='||self~modelId||'|point='||self~modelPoint||'|branch='||self~branch||'|claim='||self~claimType||'|limitations='||self~limitations

::class MLLearnedGeneration public
::attribute id
::attribute objectId
::attribute objectKind
::attribute branch
::attribute point
::attribute label
::attribute state
::attribute sourceIdentity
::attribute metadata
::method init
  use strict arg id,object,label='',sourceIdentity=.nil,metadata=.nil
  self~id=id; self~objectId=object~stableId; self~objectKind=object~kind; self~branch=object~currentBranch; self~point=object~journalPoint; self~label=label
  self~state=.MLFrozenMap~new(object~snapshot); self~sourceIdentity=sourceIdentity; self~metadata=metadata
::method canonicalText
  sourceText='<NULL>'; if self~sourceIdentity\==.nil then sourceText=self~sourceIdentity~canonicalText
  return 'LEARNED_GENERATION='||self~id||'|object='||self~objectId||'|kind='||self~objectKind||'|branch='||self~branch||'|point='||self~point~string||'|label='||self~label||'|source={'||sourceText||'}'||'0a'x||self~state~canonicalText

::class MLLearnedGenerationRegistry public
::method init
  expose generations nextId
  generations=.directory~new; nextId=1
::method publish
  expose generations nextId
  use strict arg object,label='',sourceIdentity=.nil,metadata=.nil
  id='MG'||nextId; nextId=nextId+1
  generation=.MLLearnedGeneration~new(id,object,label,sourceIdentity,metadata)
  generations[id]=generation; return generation
::method generation
  expose generations
  use strict arg id
  if generations~hasIndex(id) then return generations[id]
  return .nil
::method generations
  expose generations
  ids=generations~allIndexes; ids~sort; out=.array~new
  do id over ids; out~append(generations[id]); end
  return out
::method count; expose generations; return generations~items

::class MLModelDefinition public
::attribute id
::attribute task
::attribute provider
::attribute family
::attribute source
::attribute revision
::attribute runtime
::attribute inputSchema
::attribute outputSchema
::attribute attributes
::method init
  use strict arg id,task='',provider='',family='',source='',revision='',runtime='',inputSchema=.nil,outputSchema=.nil,attributes=.nil
  self~id=id; self~task=task; self~provider=provider; self~family=family; self~source=source; self~revision=revision; self~runtime=runtime
  self~inputSchema=inputSchema; self~outputSchema=outputSchema; self~attributes=attributes
::method fromObject class
  use strict arg source
  return self~new(source~id,source~task,source~provider,source~family,source~source,source~revision,source~runtime,source~inputSchema,source~outputSchema,source~attributes)
::method canonicalText
  return 'MODEL='||self~id||'|task='||self~task||'|provider='||self~provider||'|family='||self~family||'|source='||self~source||'|revision='||self~revision||'|runtime='||self~runtime

::class MLTensorContract public
::attribute protocol
::attribute dtype
::attribute shape
::attribute strides
::attribute deviceType
::attribute deviceId
::attribute device
::attribute readonly
::attribute attributes
::method init
  use strict arg protocol,dtype,shape,strides=.nil,deviceType='',deviceId='',device='',readonly=.false,attributes=.nil
  self~protocol=protocol; self~dtype=dtype; self~shape=shape; self~strides=strides; self~deviceType=deviceType; self~deviceId=deviceId; self~device=device; self~readonly=readonly; self~attributes=attributes
::method fromObject class
  use strict arg source
  return self~new(source~protocol,source~dtype,source~shape,source~strides,source~deviceType,source~deviceId,source~device,source~readonly,source~attributes)
::method canonicalText
  return 'TENSOR='||self~protocol||'|dtype='||self~dtype||'|shape='||self~shape||'|device='||self~device||'|readonly='||self~readonly

::requires "JournalPointedState.cls"
