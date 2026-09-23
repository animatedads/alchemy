/* ooRexx Cognitive Continuity v0.1-dev2-exp1
 * Experimental dog-food cut of the Cognitive Continuity / Memory Fabric architecture.
 *
 * IMPORTANT: CognitiveResult is an internal compatibility outcome for this cut.
 * External/common response ownership remains with the platform Structured Response API.
 * See integration/CognitiveStructuredResponseBridge.cls and docs/STRUCTURED_RESPONSE_COMPAT.md.
 */

::class CognitiveBuild public
::constant VERSION "0.1-dev2-exp1"
::constant API "oorexx.cognitive.continuity/0.1"
::constant EVENT_SCHEMA "oorexx.cognitive.event/2"
::constant EFFECT_SCHEMA "cognitive.effect.proposal/0.2"
::constant MODEL_CONTEXT_SCHEMA "cognitive.model-context/0.1"
::constant LEARNING_API "cognitive.learning/0.1"
::constant LEARNING_REQUEST_SCHEMA "cognitive.learning.request/1"
::constant LEARNING_RESULT_SCHEMA "cognitive.learning.result/1"

/* Internal operation outcome. Not the platform Structured Response contract. */
::class CognitiveResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use strict arg okArg, codeArg, detailArg='', valueArg=.nil
  ok=okArg; code=codeArg; detail=detailArg; value=valueArg
::method success class
  use strict arg valueArg=.nil, codeArg='OK', detailArg=''
  return self~new(.true,codeArg,detailArg,valueArg)
::method failure class
  use strict arg codeArg, detailArg='', valueArg=.nil
  return self~new(.false,codeArg,detailArg,valueArg)

::class CognitiveUtil public
::method string class
  use strict arg value, defaultValue=''
  if value == .nil then return defaultValue
  return value~string
::method required class
  use strict arg args, name
  if args == .nil | \args~hasIndex(name) then return ''
  return self~string(args[name])~strip
::method optional class
  use strict arg args, name, defaultValue=''
  if args == .nil | \args~hasIndex(name) then return defaultValue
  return self~string(args[name],defaultValue)
::method now class
  return date('S') || 'T' || time('L')
::method copyDirectory class
  use strict arg source
  out=.directory~new
  if source == .nil then return out
  do key over source
    out[key]=source[key]
  end
  return out
::method arrayCopy class
  use strict arg source
  out=.array~new
  if source == .nil then return out
  do item over source; out~append(item); end
  return out
::method makeId class
  use strict arg prefix
  return prefix || '-' || date('S') || '-' || time('L')~changestr(':','')~changestr('.','') || '-' || random(100000,999999)
::method arrayHas class
  use strict arg source, value
  if source == .nil then return .false
  do item over source
    if item~string == value~string then return .true
  end
  return .false
::method int class
  use strict arg value, defaultValue=0
  text=self~string(value,defaultValue~string)~strip
  if \datatype(text,'W') then return defaultValue
  return text+0

/* Capability+scope policy. Identity is supplied out-of-band. */
::class CognitiveAccessPolicy public
::method init
  expose capabilities scopes
  capabilities=.directory~new
  scopes=.directory~new
::method grant
  expose capabilities scopes
  use strict arg actorId, capability, scope='*'
  actorId=actorId~string~strip
  capability=capability~string~strip
  scope=scope~string~strip
  if actorId='' | capability='' then return .false
  key=actorId || '09'x || capability
  capabilities[key]=1
  scopes[key || '09'x || scope]=1
  return .true
::method allows
  expose capabilities scopes
  use strict arg actorId, capability, scope=''
  actorId=actorId~string~strip; capability=capability~string~strip; scope=scope~string~strip
  key=actorId || '09'x || capability
  if \capabilities~hasIndex(key) then return .false
  if scope='' then return .true
  if scopes~hasIndex(key || '09'x || '*') then return .true
  return scopes~hasIndex(key || '09'x || scope)
::method canPropose
  use strict arg actorId, scope=''
  if self~allows(actorId,'cognitive.effects.propose.operator',scope) then return .true
  if self~allows(actorId,'cognitive.effects.propose.model',scope) then return .true
  if self~allows(actorId,'cognitive.effects.propose.analysis',scope) then return .true
  /* dev1 compatibility capability names */
  if self~allows(actorId,'cognitive.effects.submit.operator',scope) then return .true
  if self~allows(actorId,'cognitive.effects.submit.model',scope) then return .true
  return .false
::method originFor
  use strict arg actorId, scope=''
  if self~allows(actorId,'cognitive.effects.propose.operator',scope) | self~allows(actorId,'cognitive.effects.submit.operator',scope) then return 'HUMAN'
  if self~allows(actorId,'cognitive.effects.propose.analysis',scope) then return 'DERIVED_ANALYSIS'
  if self~allows(actorId,'cognitive.effects.propose.model',scope) | self~allows(actorId,'cognitive.effects.submit.model',scope) then return 'MODEL'
  return 'UNKNOWN'
::method decisionAuthorityFor
  use strict arg actorId, scope=''
  if self~allows(actorId,'cognitive.authority.project_owner',scope) then return 'PROJECT_OWNER'
  if self~allows(actorId,'cognitive.authority.subject_owner',scope) then return 'SUBJECT_OWNER'
  if self~allows(actorId,'cognitive.authority.operator',scope) then return 'OPERATOR'
  if self~allows(actorId,'cognitive.authority.domain',scope) then return 'DOMAIN_AUTHORITY'
  return 'NONE'
::method assertionClass
  use strict arg actorId, scope=''
  origin=self~originFor(actorId,scope)
  if origin='HUMAN' then return 'OPERATOR_ASSERTED'
  if origin='MODEL' then return 'MODEL_ASSERTED'
  if origin='DERIVED_ANALYSIS' then return 'ANALYSIS_PROPOSED'
  return ''

::class CognitiveMemoryJournal public
::method init
  expose journalEvents
  journalEvents=.array~new
::method append
  expose journalEvents
  use strict arg event
  journalEvents~append(event)
  return event
::method events
  expose journalEvents
  return .CognitiveUtil~arrayCopy(journalEvents)

::class CognitiveJsonlJournal public
::attribute path get
::method init
  expose path
  use strict arg path
  path=path~string~strip
  if path='' then raise syntax 40.900 array('Cognitive journal path is required')
::method append
  expose path
  use strict arg event
  result=stream(path,'c','open write append')
  if result~left(5) <> 'READY' & result~left(6) <> 'NORMAL' then -
    raise syntax 40.900 array('Unable to open cognitive journal',path,result)
  call lineout path,.json~toJSON(event)
  call stream path,'c','close'
  return event
::method events
  expose path
  out=.array~new
  if stream(path,'c','query exists')='' then return out
  result=stream(path,'c','open read')
  if result~left(5) <> 'READY' & result~left(6) <> 'NORMAL' then -
    raise syntax 40.900 array('Unable to read cognitive journal',path,result)
  lineNo=0
  do while lines(path)>0
    line=linein(path); lineNo+=1
    if line~strip='' then iterate
    event=.json~fromJSON(line)
    if event == .nil | \event~hasIndex('schema') | \event~hasIndex('eventType') then -
      raise syntax 40.900 array('Invalid cognitive journal event',path,lineNo)
    if event['schema'] <> .CognitiveBuild~EVENT_SCHEMA then -
      raise syntax 40.900 array('Unsupported cognitive journal schema',path,lineNo,event['schema'])
    out~append(event)
  end
  call stream path,'c','close'
  return out

/* Deterministic baseline classifier. Nearline ML may propose richer dimensions later. */
::class CognitiveBaselineClassifier public
::method classifyKind class
  use strict arg kind
  kind=kind~string~upper
  out=.directory~new
  select
    when kind='CLAIM' then family='CLAIM'
    when kind='DECISION' | kind='ASSUMPTION' | kind='PLAN_CREATE' | kind='PLAN_ITEM_ADD' | kind='PLAN_ITEM_STATE_PROPOSAL' | kind='PLAN_CHANGE' | kind='DEPENDENCY' | kind='COMMITMENT' | kind='OPEN_QUESTION' | kind='QUESTION_RESOLVED' | kind='BLOCKER' | kind='RISK' then family='CONTINUITY'
    when kind='ARGUMENT_EDGE' | kind='ARGUMENT_CLAIM' | kind='ARGUMENT_SUPPORT' | kind='ARGUMENT_OBJECTION' | kind='ARGUMENT_REBUTTAL' then family='ARGUMENT'
    when kind='SKILL_EPISODE_HINT' then family='PROCEDURAL_EPISODE_HINT'
    when kind='LESSON' | kind='PROCEDURE' | kind='TOOL_CANDIDATE' | kind='CONCEPT' | kind='CONCEPT_RELATION' then family='INTEGRATED_KNOWLEDGE'
    when kind='CLASSIFICATION_HINT' then family='CLASSIFICATION_EVIDENCE'
    otherwise family='OTHER'
  end
  out['memoryClass']=family
  if family='PROCEDURAL_EPISODE_HINT' | family='INTEGRATED_KNOWLEDGE' then out['learningEligible']=.true; else out['learningEligible']=.false
  out['classificationSource']='DETERMINISTIC_BASELINE'
  out['classificationVersion']='baseline/0.1'
  return out
::method selectionReason class
  use strict arg kind
  kind=kind~string~upper
  select
    when kind='DECISION' then return 'CURRENT_DECISION'
    when kind='OPEN_QUESTION' then return 'OPEN_QUESTION_DEPENDENCY'
    when kind='PLAN_CREATE' | kind='PLAN_ITEM_ADD' | kind='PLAN_ITEM_STATE_PROPOSAL' | kind='PLAN_CHANGE' | kind='DEPENDENCY' then return 'ACTIVE_PLAN_DEPENDENCY'
    when kind='ASSUMPTION' then return 'ACTIVE_ASSUMPTION'
    when kind='COMMITMENT' then return 'ACTIVE_COMMITMENT'
    when kind='BLOCKER' then return 'ACTIVE_BLOCKER'
    when kind='RISK' then return 'ACTIVE_RISK'
    when kind='LESSON' then return 'RELEVANT_LESSON'
    when kind='PROCEDURE' then return 'RELEVANT_PROCEDURE'
    when kind='CONCEPT' | kind='CONCEPT_RELATION' then return 'INTEGRATED_KNOWLEDGE'
    when kind='CLAIM' then return 'ACTIVE_CLAIM'
    when kind='SKILL_EPISODE_HINT' then return 'HISTORICAL_EPISODE_HINT'
    when kind='TOOL_CANDIDATE' then return 'TOOL_CANDIDATE'
    otherwise return 'VISIBLE_SCOPE_RECORD'
  end

::class CognitiveContinuityService public
::attribute journal get
::attribute policy get

::method init
  expose journal policy records sequence projections
  use strict arg journalArg, policyArg
  if journalArg == .nil then raise syntax 40.900 array('Cognitive journal is required')
  if policyArg == .nil then raise syntax 40.900 array('Cognitive access policy is required')
  journal=journalArg; policy=policyArg
  records=.array~new; sequence=0; projections=.directory~new
  self~replay

::method dispatch
  use strict arg operation, args=.nil, actorId=''
  operation=operation~string~upper
  select
    when operation='COGNITIVE.EFFECTS.PROPOSE' then return self~effectsPropose(args,actorId)
    when operation='COGNITIVE.EFFECTS.SUBMIT' then return self~effectsPropose(args,actorId)
    when operation='COGNITIVE.RECORDS.QUERY' then return self~recordsQuery(args,actorId)
    when operation='COGNITIVE.CONTINUITY.QUERY' then return self~continuityQuery(args,actorId)
    when operation='COGNITIVE.CONTEXT.PROJECT' then return self~contextProject(args,actorId)
    when operation='COGNITIVE.CONTEXT.EXPORT' then return self~contextExport(args,actorId)
    when operation='COGNITIVE.CONTEXT.EXPLAIN' then return self~contextExplain(args,actorId)
    when operation='COGNITIVE.CLASSIFICATION.EXPLAIN' then return self~classificationExplain(args,actorId)
    when operation='COGNITIVE.LEARNING.DELTA' then return self~learningDelta(args,actorId)
    otherwise return .CognitiveResult~failure('UNKNOWN_OPERATION','Unknown cognitive operation: ' || operation)
  end

::method effectsPropose
  expose journal policy records sequence
  use strict arg args, actorId=''
  actorId=actorId~string~strip
  if actorId='' then return .CognitiveResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED')
  if args == .nil | \args~hasIndex('effects') then return .CognitiveResult~failure('EFFECTS_REQUIRED')
  scope=.CognitiveUtil~optional(args,'scopeRef','')~strip
  if scope='' then return .CognitiveResult~failure('SCOPE_REQUIRED')
  if \policy~canPropose(actorId,scope) then return .CognitiveResult~failure('COGNITIVE_WRITE_FORBIDDEN',actorId || ':' || scope)
  origin=policy~originFor(actorId,scope)
  decisionAuthority=policy~decisionAuthorityFor(actorId,scope)
  assertionClass=policy~assertionClass(actorId,scope)
  effects=args['effects']
  if effects == .nil | \effects~isA(.Array) then return .CognitiveResult~failure('EFFECTS_MUST_BE_ARRAY')
  evidenceManifest=.array~new
  if args~hasIndex('evidenceManifest') & args['evidenceManifest']<>.nil then do
    if \args['evidenceManifest']~isA(.Array) then return .CognitiveResult~failure('EVIDENCE_MANIFEST_MUST_BE_ARRAY')
    evidenceManifest=.CognitiveUtil~arrayCopy(args['evidenceManifest'])
  end
  proposalId=.CognitiveUtil~makeId('cep')
  dispositions=.array~new
  index=0
  do effect over effects
    index+=1
    checked=self~validateEffect(effect,evidenceManifest)
    if \checked~ok then do
      row=.directory~new; row['index']=index; row['disposition']='REJECTED'; row['code']=checked~code; row['detail']=checked~detail
      dispositions~append(row)
      iterate
    end
    kind=.CognitiveUtil~required(effect,'kind')~upper
    if kind='CONTEXT_RETRIEVAL_HINT' then do
      row=.directory~new; row['index']=index; row['disposition']='NOT_DURABLE_HINT'; row['recordRef']=''
      dispositions~append(row)
      iterate
    end
    sequence+=1
    event=.directory~new
    event['schema']=.CognitiveBuild~EVENT_SCHEMA
    event['eventType']='COGNITIVE_RECORD_ADMITTED'
    event['sequence']=sequence
    event['recordId']='cog-' || sequence~string~right(9,'0')
    event['proposalId']=proposalId
    event['effectId']=.CognitiveUtil~optional(effect,'effectId','e-'||index)
    event['kind']=kind
    event['scopeRef']=scope
    event['subjectRef']=.CognitiveUtil~optional(effect,'subjectRef','')
    event['objectRef']=.CognitiveUtil~optional(effect,'objectRef','')
    event['relation']=.CognitiveUtil~optional(effect,'relation','')
    event['statement']=.CognitiveUtil~optional(effect,'statement','')
    event['state']=.CognitiveUtil~optional(effect,'state','')
    event['aimScope']=.CognitiveUtil~optional(effect,'aimScope','TASK')~upper
    event['durabilityHint']=.CognitiveUtil~optional(effect,'durabilityHint','TASK')~upper
    event['verificationNeed']=.CognitiveUtil~optional(effect,'verificationNeed','NONE')~upper
    event['confidencePct']=.CognitiveUtil~int(.CognitiveUtil~optional(effect,'confidencePct','0'),0)
    event['actorId']=actorId
    event['origin']=origin
    event['assertionClass']=assertionClass
    event['decisionAuthority']=decisionAuthority
    if origin='MODEL' | origin='DERIVED_ANALYSIS' then event['epistemicState']='PROPOSED'; else event['epistemicState']='ASSERTED'
    event['timestamp']=.CognitiveUtil~now
    event['status']='ACTIVE'
    event['basisRefs']=.array~new
    if effect~hasIndex('basisRefs') & effect['basisRefs']<>.nil then event['basisRefs']=.CognitiveUtil~arrayCopy(effect['basisRefs'])
    event['evidenceBound']=.true
    classInfo=.CognitiveBaselineClassifier~classifyKind(kind)
    event['memoryClass']=classInfo['memoryClass']
    event['classificationSource']=classInfo['classificationSource']
    event['classificationVersion']=classInfo['classificationVersion']
    event['learningEligible']=classInfo['learningEligible']
    if kind='DECISION' then do
      if origin='HUMAN' & decisionAuthority<>'NONE' then event['decisionState']='ACCEPTED'; else event['decisionState']='PROPOSED'
    end
    if kind='SKILL_EPISODE_HINT' then event['verificationState']='PENDING_EVIDENCE'
    else if origin='MODEL' then event['verificationState']='UNVERIFIED_MODEL_PROPOSAL'
    else if origin='DERIVED_ANALYSIS' then event['verificationState']='UNVERIFIED_ANALYSIS_PROPOSAL'
    else event['verificationState']='ASSERTED_BY_OPERATOR'
    journal~append(event)
    records~append(event)
    row=.directory~new
    row['index']=index
    row['recordRef']=event['recordId']
    if kind='SKILL_EPISODE_HINT' then row['disposition']='PENDING_EVIDENCE'
    else if origin='MODEL' & kind='CLAIM' then row['disposition']='ADMITTED_MODEL_ASSERTION'
    else if origin='HUMAN' & kind='CLAIM' then row['disposition']='ADMITTED_OPERATOR_ASSERTION'
    else if kind='DECISION' & event['decisionState']='PROPOSED' then row['disposition']='ADMITTED_DECISION_PROPOSAL'
    else if kind='DECISION' & event['decisionState']='ACCEPTED' then row['disposition']='ADMITTED_ACCEPTED_DECISION'
    else row['disposition']='ADMITTED_COGNITIVE_RECORD'
    dispositions~append(row)
  end
  value=.directory~new
  value['schema']='oorexx.cognitive.effect.proposal-result/2'
  value['proposalId']=proposalId
  value['scopeRef']=scope
  value['results']=dispositions
  value['corpusPointId']='cp-'||sequence
  return .CognitiveResult~success(value,'COGNITIVE_EFFECTS_PROCESSED')

::method recordsQuery
  expose policy records
  use strict arg args, actorId=''
  actorId=actorId~string~strip
  scope=.CognitiveUtil~optional(args,'scopeRef','')~strip
  if actorId='' then return .CognitiveResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED')
  if scope='' then return .CognitiveResult~failure('SCOPE_REQUIRED')
  if \policy~allows(actorId,'cognitive.records.query',scope) then return .CognitiveResult~failure('COGNITIVE_READ_FORBIDDEN',actorId || ':' || scope)
  kindFilter=.CognitiveUtil~optional(args,'kind','')~upper~strip
  familyFilter=.CognitiveUtil~optional(args,'memoryClass','')~upper~strip
  out=.array~new
  do rec over records
    if rec['scopeRef']<>scope then iterate
    if kindFilter<>'' & rec['kind']<>kindFilter then iterate
    if familyFilter<>'' & rec['memoryClass']<>familyFilter then iterate
    out~append(.CognitiveUtil~copyDirectory(rec))
  end
  value=.directory~new; value['schema']='oorexx.cognitive.records/2'; value['scopeRef']=scope; value['records']=out; value['count']=out~items
  return .CognitiveResult~success(value,'COGNITIVE_RECORDS_LISTED')

::method continuityQuery
  use strict arg args, actorId=''
  query=self~recordsQuery(args,actorId)
  if \query~ok then return query
  out=.array~new
  do rec over query~value['records']
    if rec['memoryClass']='CONTINUITY' | rec['memoryClass']='ARGUMENT' then out~append(rec)
  end
  value=.directory~new; value['schema']='oorexx.cognitive.continuity/2'; value['scopeRef']=query~value['scopeRef']; value['records']=out; value['count']=out~items
  return .CognitiveResult~success(value,'COGNITIVE_CONTINUITY_LISTED')

::method contextProject
  expose policy records sequence projections
  use strict arg args, actorId=''
  actorId=actorId~string~strip
  scope=.CognitiveUtil~optional(args,'scopeRef','')~strip
  if actorId='' then return .CognitiveResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED')
  if scope='' then return .CognitiveResult~failure('SCOPE_REQUIRED')
  if \policy~allows(actorId,'cognitive.context.project',scope) then return .CognitiveResult~failure('COGNITIVE_CONTEXT_FORBIDDEN',actorId || ':' || scope)
  limit=.CognitiveUtil~int(.CognitiveUtil~optional(args,'limit','32'),32)
  if limit<1 then limit=1; if limit>128 then limit=128
  task=.CognitiveUtil~optional(args,'task','')
  source=.array~new
  do rec over records
    if rec['scopeRef']=scope then source~append(rec)
  end
  selected=.array~new; trace=.array~new; seen=.directory~new
  priority=.array~of('DECISION','OPEN_QUESTION','BLOCKER','PLAN_ITEM_STATE_PROPOSAL','PLAN_CHANGE','PLAN_ITEM_ADD','PLAN_CREATE','DEPENDENCY','ASSUMPTION','COMMITMENT','RISK','LESSON','PROCEDURE','CONCEPT','CONCEPT_RELATION','CLAIM','SKILL_EPISODE_HINT','TOOL_CANDIDATE')
  do wanted over priority while selected~items<limit
    do i=source~items to 1 by -1 while selected~items<limit
      rec=source[i]
      if rec['kind']<>wanted then iterate
      if seen~hasIndex(rec['recordId']) then iterate
      item=.CognitiveUtil~copyDirectory(rec)
      reason=.CognitiveBaselineClassifier~selectionReason(rec['kind'])
      item['selectionReason']=reason
      selected~append(item); seen[rec['recordId']]=1
      tr=.directory~new; tr['recordId']=rec['recordId']; tr['kind']=rec['kind']; tr['included']=.true; tr['reason']=reason
      trace~append(tr)
    end
  end
  /* Any remaining visible records fill spare capacity, newest first. */
  do i=source~items to 1 by -1 while selected~items<limit
    rec=source[i]
    if seen~hasIndex(rec['recordId']) then iterate
    item=.CognitiveUtil~copyDirectory(rec); reason=.CognitiveBaselineClassifier~selectionReason(rec['kind']); item['selectionReason']=reason
    selected~append(item); seen[rec['recordId']]=1
    tr=.directory~new; tr['recordId']=rec['recordId']; tr['kind']=rec['kind']; tr['included']=.true; tr['reason']=reason
    trace~append(tr)
  end
  do rec over source
    if seen~hasIndex(rec['recordId']) then iterate
    tr=.directory~new; tr['recordId']=rec['recordId']; tr['kind']=rec['kind']; tr['included']=.false; tr['reason']='BUDGET_LIMIT'
    trace~append(tr)
  end
  projectionId=.CognitiveUtil~makeId('proj')
  value=.directory~new
  value['schema']='oorexx.cognitive.context-projection/2'
  value['projectionId']=projectionId
  value['scopeRef']=scope
  value['task']=task
  value['records']=selected
  value['selectionTrace']=trace
  value['count']=selected~items
  value['visibleCount']=source~items
  value['authoritative']=.false
  value['disposition']='DERIVED_DISPOSABLE_PROJECTION'
  value['generatedAt']=.CognitiveUtil~now
  value['corpusPointId']='cp-'||sequence
  projections[projectionId]=value
  return .CognitiveResult~success(value,'COGNITIVE_CONTEXT_PROJECTED')

::method contextExport
  use strict arg args, actorId=''
  projected=self~contextProject(args,actorId)
  if \projected~ok then return projected
  p=projected~value
  items=.array~new
  do rec over p['records']
    item=.directory~new
    do name over .array~of('recordId','kind','memoryClass','subjectRef','objectRef','relation','statement','state','origin','epistemicState','decisionState','verificationState','selectionReason')
      if rec~hasIndex(name) then item[name]=rec[name]
    end
    item['basisRefs']=.CognitiveUtil~arrayCopy(rec['basisRefs'])
    items~append(item)
  end
  model=.directory~new
  model['schema']=.CognitiveBuild~MODEL_CONTEXT_SCHEMA
  model['projectionId']=p['projectionId']
  model['scopeRef']=p['scopeRef']
  model['task']=p['task']
  model['corpusPointId']=p['corpusPointId']
  model['items']=items
  model['generatedAt']=p['generatedAt']
  out=.directory~new
  out['schema']='oorexx.cognitive.model-feed/1'
  out['projectionId']=p['projectionId']
  out['modelInput']=model
  out['modelInputJson']=.json~toJSON(model)
  out['projectionTrace']=p['selectionTrace']
  out['disposition']='EXACT_MODEL_INPUT_EXPORT'
  return .CognitiveResult~success(out,'COGNITIVE_CONTEXT_EXPORTED')

::method contextExplain
  expose policy projections
  use strict arg args, actorId=''
  actorId=actorId~string~strip
  scope=.CognitiveUtil~optional(args,'scopeRef','')~strip
  projectionId=.CognitiveUtil~optional(args,'projectionId','')~strip
  if actorId='' then return .CognitiveResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED')
  if scope='' then return .CognitiveResult~failure('SCOPE_REQUIRED')
  if \policy~allows(actorId,'cognitive.context.explain',scope) & \policy~allows(actorId,'cognitive.context.project',scope) then return .CognitiveResult~failure('COGNITIVE_CONTEXT_FORBIDDEN')
  if projectionId='' | \projections~hasIndex(projectionId) then return .CognitiveResult~failure('PROJECTION_NOT_FOUND',projectionId)
  p=projections[projectionId]
  if p['scopeRef']<>scope then return .CognitiveResult~failure('PROJECTION_SCOPE_MISMATCH')
  out=.directory~new; out['schema']='oorexx.cognitive.projection-explanation/1'; out['projectionId']=projectionId; out['scopeRef']=scope; out['selectionTrace']=p['selectionTrace']; out['task']=p['task']; out['corpusPointId']=p['corpusPointId']
  return .CognitiveResult~success(out,'COGNITIVE_PROJECTION_EXPLAINED')

::method classificationExplain
  expose policy records
  use strict arg args, actorId=''
  actorId=actorId~string~strip; scope=.CognitiveUtil~optional(args,'scopeRef','')~strip; recordId=.CognitiveUtil~optional(args,'recordId','')~strip
  if actorId='' then return .CognitiveResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED')
  if scope='' | recordId='' then return .CognitiveResult~failure('SCOPE_AND_RECORD_REQUIRED')
  if \policy~allows(actorId,'cognitive.records.query',scope) then return .CognitiveResult~failure('COGNITIVE_READ_FORBIDDEN')
  do rec over records
    if rec['scopeRef']=scope & rec['recordId']=recordId then do
      out=.directory~new; out['schema']='oorexx.cognitive.classification-explanation/1'; out['recordId']=recordId; out['kind']=rec['kind']; out['memoryClass']=rec['memoryClass']; out['classificationSource']=rec['classificationSource']; out['classificationVersion']=rec['classificationVersion']; out['learningEligible']=rec['learningEligible']; out['selectionReason']=.CognitiveBaselineClassifier~selectionReason(rec['kind'])
      return .CognitiveResult~success(out,'COGNITIVE_CLASSIFICATION_EXPLAINED')
    end
  end
  return .CognitiveResult~failure('RECORD_NOT_FOUND',recordId)

::method learningDelta
  expose policy records sequence
  use strict arg args, actorId=''
  actorId=actorId~string~strip; scope=.CognitiveUtil~optional(args,'scopeRef','')~strip
  if actorId='' then return .CognitiveResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED')
  if scope='' then return .CognitiveResult~failure('SCOPE_REQUIRED')
  if \policy~allows(actorId,'cognitive.learning.delta',scope) then return .CognitiveResult~failure('COGNITIVE_LEARNING_FORBIDDEN')
  since=.CognitiveUtil~int(.CognitiveUtil~optional(args,'sinceSequence','0'),0)
  outRecords=.array~new
  do rec over records
    if rec['scopeRef']<>scope then iterate
    if rec['sequence']<=since then iterate
    outRecords~append(.CognitiveUtil~copyDirectory(rec))
  end
  out=.directory~new
  out['schema']='oorexx.cognitive.learning-delta/1'
  out['scopeRef']=scope
  out['fromCorpusPointId']='cp-'||since
  out['toCorpusPointId']='cp-'||sequence
  out['fromSequence']=since
  out['toSequence']=sequence
  out['records']=outRecords
  out['count']=outRecords~items
  out['generatedAt']=.CognitiveUtil~now
  return .CognitiveResult~success(out,'COGNITIVE_LEARNING_DELTA')

::method validateEffect private
  use strict arg effect, evidenceManifest
  if effect == .nil | \effect~isA(.Directory) then return .CognitiveResult~failure('EFFECT_MUST_BE_OBJECT')
  forbidden=.array~of('actorId','principalId','authority','assertionClass','origin','epistemicState','decisionAuthority','verificationState','toolVerified','operatorAsserted','serverTimestamp','recordId')
  do name over forbidden
    if effect~hasIndex(name) then return .CognitiveResult~failure('FORBIDDEN_AUTHORITY_FIELD',name)
  end
  allowedFields=.directory~new
  do name over .array~of('effectId','kind','subjectRef','objectRef','relation','statement','state','basisRefs','aimScope','durabilityHint','verificationNeed','confidencePct'); allowedFields[name]=1; end
  do name over effect
    if \allowedFields~hasIndex(name) then return .CognitiveResult~failure('COGNITIVE_EFFECT_FIELD_INVALID',name)
  end
  kind=.CognitiveUtil~required(effect,'kind')~upper
  allowed=.array~of('CLAIM','DECISION','ASSUMPTION','PLAN_CREATE','PLAN_ITEM_ADD','PLAN_ITEM_STATE_PROPOSAL','PLAN_CHANGE','DEPENDENCY','COMMITMENT','OPEN_QUESTION','QUESTION_RESOLVED','BLOCKER','RISK','ARGUMENT_EDGE','ARGUMENT_CLAIM','ARGUMENT_SUPPORT','ARGUMENT_OBJECTION','ARGUMENT_REBUTTAL','SKILL_EPISODE_HINT','CONTEXT_RETRIEVAL_HINT','LESSON','PROCEDURE','TOOL_CANDIDATE','CONCEPT','CONCEPT_RELATION','CLASSIFICATION_HINT','SUPERSESSION_PROPOSAL','CONTRADICTION_PROPOSAL')
  if allowed~hasItem(kind)=0 then return .CognitiveResult~failure('COGNITIVE_EFFECT_KIND_INVALID',kind)
  if .CognitiveUtil~required(effect,'statement')='' & kind<>'CONCEPT_RELATION' then return .CognitiveResult~failure('COGNITIVE_EFFECT_STATEMENT_REQUIRED',kind)
  if effect~hasIndex('basisRefs') & effect['basisRefs']<>.nil then do
    if \effect['basisRefs']~isA(.Array) then return .CognitiveResult~failure('BASIS_REFS_MUST_BE_ARRAY')
    do basis over effect['basisRefs']
      if \.CognitiveUtil~arrayHas(evidenceManifest,basis) then return .CognitiveResult~failure('BASIS_REF_NOT_IN_MANIFEST',basis)
    end
  end
  if effect~hasIndex('confidencePct') then do
    confidence=.CognitiveUtil~int(effect['confidencePct'],-1)
    if confidence<0 | confidence>100 then return .CognitiveResult~failure('CONFIDENCE_PCT_INVALID')
  end
  return .CognitiveResult~success(.true)

::method replay private
  expose journal records sequence
  sequence=0
  events=journal~events
  do event over events
    if event['schema']<>.CognitiveBuild~EVENT_SCHEMA then -
      raise syntax 40.900 array('Unsupported cognitive event schema',event['schema'])
    records~append(event)
    if event~hasIndex('sequence') then n=event['sequence']; else do; id=.CognitiveUtil~optional(event,'recordId',''); parse var id 'cog-' n; end
    if datatype(n,'W') & n>sequence then sequence=n
  end

::requires 'json.cls'
