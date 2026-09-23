/* MLSearch.cls - first-class bounded, comparable search experiments. */

::class MLObjective public
::attribute id
::attribute direction
::attribute formula
::attribute description
::method init
  use strict arg id,direction='MINIMIZE',formula='',description=''
  d=direction~translate
  if d<>'MINIMIZE' & d<>'MAXIMIZE' then raise syntax 88.900 array('ML objective direction must be MINIMIZE or MAXIMIZE')
  self~id=id; self~direction=d; self~formula=formula; self~description=description
::method fitnessFor
  use strict arg score
  if self~direction='MINIMIZE' then return -score
  return score
::method better
  use strict arg left,right
  if self~direction='MINIMIZE' then return left<right
  return left>right
::method canonicalText
  return 'OBJECTIVE='||self~id||'|direction='||self~direction||'|formula='||self~formula||'|description='||self~description

::class MLObjectiveFitnessAdapter public
::method init
  expose objective scoreEvaluator
  use strict arg objective,scoreEvaluator
  if \objective~isA(.MLObjective) then raise syntax 88.900 array('fitness adapter requires MLObjective')
::method objective; expose objective; return objective
::method fitness
  expose objective scoreEvaluator
  use strict arg subject
  return objective~fitnessFor(scoreEvaluator~score(subject))

::class MLWorkspaceBudget public
::attribute maximumBytes
::attribute reserveBytes
::attribute minimumFreeAtStart
::attribute retainedOutputLimit
::attribute spillPolicy
::attribute failurePolicy
::method init
  use strict arg maximumBytes,reserveBytes=0,minimumFreeAtStart=.nil,retainedOutputLimit=0,spillPolicy='NONE',failurePolicy='FAIL_CLOSED'
  if maximumBytes<0 | reserveBytes<0 then raise syntax 88.900 array('workspace byte budgets must be non-negative')
  if minimumFreeAtStart==.nil then minimumFreeAtStart=maximumBytes+reserveBytes
  if minimumFreeAtStart<maximumBytes then raise syntax 88.900 array('minimum free space must be at least workspace maximum')
  if retainedOutputLimit<0 then raise syntax 88.900 array('retained output limit must be non-negative')
  self~maximumBytes=maximumBytes; self~reserveBytes=reserveBytes; self~minimumFreeAtStart=minimumFreeAtStart
  self~retainedOutputLimit=retainedOutputLimit; self~spillPolicy=spillPolicy~translate; self~failurePolicy=failurePolicy~translate
::method gib class
  use strict arg maximumGiB,reserveGiB=0,minimumFreeGiB=.nil,retainedOutputLimit=0,spillPolicy='NONE',failurePolicy='FAIL_CLOSED'
  numeric digits 30
  unit=1073741824
  if minimumFreeGiB==.nil then minimumFreeGiB=maximumGiB+reserveGiB
  return self~new(maximumGiB*unit,reserveGiB*unit,minimumFreeGiB*unit,retainedOutputLimit,spillPolicy,failurePolicy)
::method preflight
  use strict arg freeBytes
  out=.directory~new
  out['freeBytes']=freeBytes; out['requiredFreeBytes']=self~minimumFreeAtStart
  out['maximumBytes']=self~maximumBytes; out['reserveBytes']=self~reserveBytes
  out['allowed']=(freeBytes>=self~minimumFreeAtStart)
  if out['allowed'] then out['reason']='OK'
  else out['reason']='INSUFFICIENT_FREE_SPACE'
  return out
::method retainedBytesAllowed
  use strict arg retainedBytes
  return retainedBytes<=self~maximumBytes
::method canonicalText
  return 'WORKSPACE=max='||self~maximumBytes||'|reserve='||self~reserveBytes||'|minFree='||self~minimumFreeAtStart||'|retain='||self~retainedOutputLimit||'|spill='||self~spillPolicy||'|failure='||self~failurePolicy

::class MLRetentionPolicy public
::attribute retainCount
::attribute uniqueBy
::attribute materializeMode
::method init
  use strict arg retainCount=0,uniqueBy='CANDIDATE',materializeMode='PROMOTED_ONLY'
  if retainCount<0 then raise syntax 88.900 array('retention count must be non-negative')
  self~retainCount=retainCount; self~uniqueBy=uniqueBy~translate; self~materializeMode=materializeMode~translate
::method shouldRetainRank
  use strict arg rank
  if self~retainCount=0 then return .false
  return rank<=self~retainCount
::method canonicalText
  return 'RETENTION=count='||self~retainCount||'|uniqueBy='||self~uniqueBy||'|materialize='||self~materializeMode

::class MLParameterDomain public
::attribute name
::attribute description
::method init
  expose values
  use strict arg name,sourceValues,description=''
  if \sourceValues~isA(.Array) | sourceValues~items=0 then raise syntax 88.900 array('parameter domain requires nonempty Array',name)
  self~name=name; self~description=description; values=.MLFrozenVector~new(sourceValues)
::method values; expose values; return values
::method contains
  expose values
  use strict arg candidate
  do i=1 to values~items
    if values[i]==candidate then return .true
  end
  return .false
::method isSubsetOf
  use strict arg other
  do i=1 to self~values~items
    if \other~contains(self~values[i]) then return .false
  end
  return .true
::method canonicalText
  expose values
  return 'DOMAIN='||self~name||'|values='||values~canonicalText||'|description='||self~description

::class MLSearchSpace public
::attribute id
::attribute description
::method init
  expose domains
  use strict arg id,sourceDomains,description=''
  if \sourceDomains~isA(.Array) | sourceDomains~items=0 then raise syntax 88.900 array('search space requires nonempty Array')
  self~id=id; self~description=description; domains=.directory~new
  do d over sourceDomains
    if \d~isA(.MLParameterDomain) then raise syntax 88.900 array('search space domains must be MLParameterDomain')
    if domains~hasIndex(d~name) then raise syntax 88.900 array('duplicate parameter domain',d~name)
    domains[d~name]=d
  end
::method parameterNames
  expose domains
  names=domains~allIndexes; names~sort; return names
::method domain
  expose domains
  use strict arg name
  if domains~hasIndex(name) then return domains[name]
  return .nil
::method containsConfiguration
  expose domains
  use strict arg configuration
  if \configuration~isA(.Directory) then raise syntax 88.900 array('search configuration must be Directory')
  do name over domains~allIndexes
    if \configuration~hasIndex(name) then return .false
    if \domains[name]~contains(configuration[name]) then return .false
  end
  return .true
::method canonicalText
  expose domains
  names=domains~allIndexes; names~sort; lines=.array~new; lines~append('SEARCH_SPACE='||self~id||'|description='||self~description)
  do name over names; lines~append(domains[name]~canonicalText); end
  return lines~makeString('L')

::class MLSearchSpaceComparison public
::attribute leftId
::attribute rightId
::attribute relation
::method init
  expose differences
  use strict arg leftId,rightId,relation,sourceDifferences
  self~leftId=leftId; self~rightId=rightId; self~relation=relation; differences=.array~new; do d over sourceDifferences; differences~append(d); end
::method differences
  expose differences
  out=.array~new; do d over differences; out~append(d); end; return out
::method equivalent; return self~relation='EQUIVALENT'
::method canonicalText
  expose differences
  lines=.array~new; lines~append('SEARCH_SPACE_COMPARISON='||self~leftId||':'||self~rightId||'|relation='||self~relation)
  do d over differences; lines~append(d); end; return lines~makeString('L')
::method compare class
  use strict arg left,right
  leftNames=left~parameterNames; rightNames=right~parameterNames; differences=.array~new
  sameNames=(leftNames~items=rightNames~items)
  if sameNames then do i=1 to leftNames~items; if leftNames[i]\==rightNames[i] then do; sameNames=.false; leave; end; end
  if \sameNames then do
    differences~append('PARAMETER_SET_DIFFERS')
    return self~new(left~id,right~id,'DIFFERENT',differences)
  end
  leftSubset=.true; rightSubset=.true
  do name over leftNames
    ld=left~domain(name); rd=right~domain(name)
    lsub=ld~isSubsetOf(rd); rsub=rd~isSubsetOf(ld)
    if \lsub then leftSubset=.false
    if \rsub then rightSubset=.false
    if \lsub | \rsub then differences~append(name||':left='||ld~values~canonicalText||'|right='||rd~values~canonicalText)
  end
  if leftSubset & rightSubset then relation='EQUIVALENT'
  else if leftSubset then relation='LEFT_SUBSET'
  else if rightSubset then relation='RIGHT_SUBSET'
  else relation='DIFFERENT'
  return self~new(left~id,right~id,relation,differences)

::class MLSearchStrategySpec public
::attribute id
::attribute kind
::attribute configuration
::method init
  use strict arg id,kind,configuration=.nil
  if configuration==.nil then configuration=.directory~new
  self~id=id; self~kind=kind~translate; self~configuration=.MLFrozenMap~new(configuration)
::method canonicalText
  return 'SEARCH_STRATEGY='||self~id||'|kind='||self~kind||'|'||self~configuration~canonicalText

::class MLSearchCandidate public
::attribute id
::attribute laneId
::attribute configuration
::attribute score
::attribute objective
::attribute evidence
::attribute materialRefs
::method init
  use strict arg id,laneId,configuration,score,objective,evidence=.nil,materialRefs=.nil
  if \configuration~isA(.Directory) then raise syntax 88.900 array('candidate configuration must be Directory')
  if \objective~isA(.MLObjective) then raise syntax 88.900 array('candidate requires MLObjective')
  if materialRefs==.nil then materialRefs=.array~new
  self~id=id; self~laneId=laneId; self~configuration=.MLFrozenMap~new(configuration); self~score=score; self~objective=objective; self~evidence=evidence; self~materialRefs=.MLFrozenVector~new(materialRefs)
::method fitness; return self~objective~fitnessFor(self~score)
::method canonicalText
  return 'CANDIDATE='||self~id||'|lane='||self~laneId||'|score='||self~score||'|fitness='||self~fitness||'|'||self~configuration~canonicalText

::class MLSearchCandidateComparator public
::method compare
  use strict arg a,b
  if a~objective~id\==b~objective~id then raise syntax 88.900 array('cannot rank candidates from different objectives',a~objective~id,b~objective~id)
  if a~score==b~score then return 0
  if a~objective~better(a~score,b~score) then return -1
  return 1

::class MLSearchLane subclass MLDriveableObject public
::method init
  expose objective workspace retention searchSpace strategy
  use strict arg laneId,strategy,searchSpace,objective,workspace,retention
  if \strategy~isA(.MLSearchStrategySpec) then raise syntax 88.900 array('search lane requires MLSearchStrategySpec')
  if \searchSpace~isA(.MLSearchSpace) then raise syntax 88.900 array('search lane requires MLSearchSpace')
  if \objective~isA(.MLObjective) then raise syntax 88.900 array('search lane requires MLObjective')
  if \workspace~isA(.MLWorkspaceBudget) then raise syntax 88.900 array('search lane requires MLWorkspaceBudget')
  if \retention~isA(.MLRetentionPolicy) then raise syntax 88.900 array('search lane requires MLRetentionPolicy')
  initial=.directory~new
  initial['status']='READY'; initial['cursor']=0; initial['evaluations']=0; initial['uniqueEvaluations']=0; initial['promoted']=0
  initial['strategyId']=strategy~id; initial['searchSpaceId']=searchSpace~id; initial['objectiveId']=objective~id
  self~init:super(laneId,'SEARCH_LANE',initial)
::method objective; expose objective; return objective
::method workspaceBudget; expose workspace; return workspace
::method retentionPolicy; expose retention; return retention
::method searchSpace; expose searchSpace; return searchSpace
::method strategy; expose strategy; return strategy
::method status; return self~at('status')
::method begin
  changes=.directory~new; changes['status']='RUNNING'; return self~mutate(changes,'SEARCH_BEGIN')
::method recordEvaluation
  use strict arg unique=.true
  changes=.directory~new; changes['cursor']=self~at('cursor')+1; changes['evaluations']=self~at('evaluations')+1
  if unique then changes['uniqueEvaluations']=self~at('uniqueEvaluations')+1
  return self~mutate(changes,'SEARCH_EVALUATION')
::method recordPromotion
  changes=.directory~new; changes['promoted']=self~at('promoted')+1; return self~mutate(changes,'SEARCH_PROMOTION')
::method complete
  changes=.directory~new; changes['status']='COMPLETE'; return self~mutate(changes,'SEARCH_COMPLETE')

::class MLSearchExperiment subclass MLExperiment public
::method init
  expose lanes
  use strict arg id='ML-SEARCH'
  self~init:super(id); lanes=.directory~new
::method addLane
  expose lanes
  use strict arg lane
  if \lane~isA(.MLSearchLane) then raise syntax 88.900 array('search experiment requires MLSearchLane')
  if lanes~hasIndex(lane~stableId) then raise syntax 88.900 array('duplicate search lane',lane~stableId)
  lanes[lane~stableId]=lane; self~register('lane:'||lane~stableId,lane); return lane
::method lane
  expose lanes
  use strict arg id
  if lanes~hasIndex(id) then return lanes[id]
  return .nil
::method laneIds
  expose lanes
  ids=lanes~allIndexes; ids~sort; return ids

::class MLQualificationCheck public
::attribute category
::attribute name
::attribute passed
::attribute detail
::method init
  use strict arg category,name,passed,detail=''
  self~category=category~translate; self~name=name; self~passed=passed; self~detail=detail
::method canonicalText
  return 'QUALIFICATION='||self~category||'|'||self~name||'|passed='||self~passed||'|detail='||self~detail

::class MLQualificationReport public
::attribute id
::method init
  expose checks
  use strict arg id,sourceChecks
  self~id=id; checks=.array~new; do c over sourceChecks; checks~append(c); end
::method checks
  expose checks
  out=.array~new; do c over checks; out~append(c); end; return out
::method passed
  expose checks
  do c over checks; if \c~passed then return .false; end
  return .true
::method canonicalText
  expose checks
  lines=.array~new; lines~append('QUALIFICATION_REPORT='||self~id||'|passed='||self~passed)
  do c over checks; lines~append(c~canonicalText); end; return lines~makeString('L')

::class MLSearchQualification public
::method preflight class
  use strict arg lane,freeBytes
  checks=.array~new
  p=lane~workspaceBudget~preflight(freeBytes)
  checks~append(.MLQualificationCheck~new('RESOURCE','workspace-free-space',p['allowed'],'free='||freeBytes||' required='||p['requiredFreeBytes']))
  checks~append(.MLQualificationCheck~new('DEFINITION','search-space-explicit',lane~searchSpace~parameterNames~items>0,'space='||lane~searchSpace~id))
  d=lane~objective~direction; checks~append(.MLQualificationCheck~new('DEFINITION','objective-direction',d='MINIMIZE' | d='MAXIMIZE','direction='||d))
  checks~append(.MLQualificationCheck~new('RETENTION','retention-bounded',lane~retentionPolicy~retainCount>=0,'retain='||lane~retentionPolicy~retainCount))
  return .MLQualificationReport~new('PREFLIGHT:'||lane~stableId,checks)

::requires "MLCore.cls"
