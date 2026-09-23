/* MCP semantic adapter for Cognitive Continuity.
 * Authentication owns actorId; tool arguments never carry identity/authority.
 */
::class CognitiveMcpAdapter public
::constant MCP_SPEC "2026-07-28"
::constant API "oorexx.cognitive.mcp/0.1"
::method init
  expose service
  use strict arg serviceArg
  if serviceArg == .nil then raise syntax 40.900 array('Cognitive service is required')
  service=serviceArg
::method tools
  out=.array~new
  out~append(self~tool('cognitive.context.project','Project cognitive context','Build a bounded disposable context projection with selection reasons.',self~schema(.array~of('scopeRef'),.array~of('scopeRef','task','limit'))))
  out~append(self~tool('cognitive.context.export','Export exact model input','Return the exact provider-neutral JSON payload selected for a model plus its projection trace.',self~schema(.array~of('scopeRef'),.array~of('scopeRef','task','limit'))))
  out~append(self~tool('cognitive.context.explain','Explain context projection','Explain why records were included or excluded.',self~schema(.array~of('scopeRef','projectionId'),.array~of('scopeRef','projectionId'))))
  out~append(self~tool('cognitive.records.query','Query cognitive records','Query admitted cognitive records in an authorised scope.',self~schema(.array~of('scopeRef'),.array~of('scopeRef','kind','memoryClass'))))
  out~append(self~tool('cognitive.continuity.query','Query continuity state','Query plans, decisions, assumptions, questions, commitments, blockers, risks and argument state.',self~schema(.array~of('scopeRef'),.array~of('scopeRef'))))
  out~append(self~tool('cognitive.classification.explain','Explain classification','Explain the deterministic baseline classification and projection reason for a record.',self~schema(.array~of('scopeRef','recordId'),.array~of('scopeRef','recordId'))))
  out~append(self~tool('cognitive.learning.delta','Build learning delta','Return admitted records since a corpus sequence for Queue Fabric nearline learning.',self~schema(.array~of('scopeRef'),.array~of('scopeRef','sinceSequence'))))
  out~append(self~tool('cognitive.learning.bundle','Build learning bundle','Return corpus delta plus projection receipts/outcomes for nearline learning.',self~schema(.array~of('scopeRef'),.array~of('scopeRef','sinceSequence','sinceMeasurementSequence'))))
  out~append(self~tool('cognitive.projection.receipts','List model-feed receipts','List persisted exact model-feed projection receipts outside cognitive authority.',self~schema(.array~of('scopeRef'),.array~of('scopeRef','sinceMeasurementSequence'))))
  out~append(self~tool('cognitive.projection.outcomes','List projection outcomes','List persisted model-feed outcome feedback outside cognitive authority.',self~schema(.array~of('scopeRef'),.array~of('scopeRef','sinceMeasurementSequence'))))
  outcomeProps=.directory~new
  do n over .array~of('scopeRef','projectionId','outcome','note'); p=.directory~new; p['type']='string'; outcomeProps[n]=p; end
  do n over .array~of('usefulRecordIds','irrelevantRecordIds','missingKinds'); p=.directory~new; p['type']='array'; q=.directory~new; q['type']='string'; p['items']=q; outcomeProps[n]=p; end
  outcomeSchema=.directory~new; outcomeSchema['type']='object'; outcomeSchema['properties']=outcomeProps; outcomeSchema['required']=.array~of('scopeRef','projectionId','outcome'); outcomeSchema['additionalProperties']=.json~false
  out~append(self~tool('cognitive.projection.outcome','Record projection outcome','Record usefulness/irrelevance/missing-context feedback for a prior projection; measurement only, not cognitive authority.',outcomeSchema))
  effectSchema=.directory~new; effectSchema['type']='object'; effectSchema['description']='Validated by cognitive.effect.proposal/0.2 and server admission policy'
  props=.directory~new
  p=.directory~new; p['type']='string'; props['scopeRef']=p
  p=.directory~new; p['type']='array'; p['items']=effectSchema; props['effects']=p
  p=.directory~new; p['type']='array'; s=.directory~new; s['type']='string'; p['items']=s; props['evidenceManifest']=p
  proposal=.directory~new; proposal['type']='object'; proposal['properties']=props; proposal['required']=.array~of('scopeRef','effects'); proposal['additionalProperties']=.json~false
  out~append(self~tool('cognitive.effects.propose','Propose cognitive effects','Propose typed cognitive effects. The client cannot self-admit, self-verify or set authority.',proposal))
  return out
::method call
  expose service
  use strict arg toolName, args, actorId
  actorId=actorId~string~strip
  if actorId='' then return .CognitiveResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED')
  operation=self~operationFor(toolName)
  if operation='' then return .CognitiveResult~failure('MCP_TOOL_UNKNOWN',toolName)
  if args<>.nil & args~isA(.Directory) then do
    do forbidden over .array~of('actorId','principalId','authority','assertionClass','origin','epistemicState','decisionAuthority','verificationState','toolVerified')
      if args~hasIndex(forbidden) then return .CognitiveResult~failure('MCP_IDENTITY_FIELD_FORBIDDEN',forbidden)
    end
  end
  return service~dispatch(operation,args,actorId)
::method operationFor private
  use strict arg toolName
  select
    when toolName='cognitive.context.project' then return 'COGNITIVE.CONTEXT.PROJECT'
    when toolName='cognitive.context.export' then return 'COGNITIVE.CONTEXT.EXPORT'
    when toolName='cognitive.context.explain' then return 'COGNITIVE.CONTEXT.EXPLAIN'
    when toolName='cognitive.records.query' then return 'COGNITIVE.RECORDS.QUERY'
    when toolName='cognitive.continuity.query' then return 'COGNITIVE.CONTINUITY.QUERY'
    when toolName='cognitive.classification.explain' then return 'COGNITIVE.CLASSIFICATION.EXPLAIN'
    when toolName='cognitive.learning.delta' then return 'COGNITIVE.LEARNING.DELTA'
    when toolName='cognitive.learning.bundle' then return 'COGNITIVE.LEARNING.BUNDLE'
    when toolName='cognitive.projection.receipts' then return 'COGNITIVE.PROJECTION.RECEIPTS'
    when toolName='cognitive.projection.outcomes' then return 'COGNITIVE.PROJECTION.OUTCOMES'
    when toolName='cognitive.projection.outcome' then return 'COGNITIVE.PROJECTION.OUTCOME'
    when toolName='cognitive.effects.propose' then return 'COGNITIVE.EFFECTS.PROPOSE'
    otherwise return ''
  end
::method tool private
  use strict arg name,title,description,inputSchema
  d=.directory~new; d['name']=name; d['title']=title; d['description']=description; d['inputSchema']=inputSchema; return d
::method schema private
  use strict arg requiredNames, propertyNames
  schema=.directory~new; schema['type']='object'; props=.directory~new
  do name over propertyNames
    p=.directory~new
    if name='limit' | name='sinceSequence' | name='sinceMeasurementSequence' then p['type']='integer'; else p['type']='string'
    props[name]=p
  end
  schema['properties']=props; schema['required']=requiredNames; schema['additionalProperties']=.json~false
  return schema
::requires 'CognitiveContinuity.cls'
::requires 'json.cls'
