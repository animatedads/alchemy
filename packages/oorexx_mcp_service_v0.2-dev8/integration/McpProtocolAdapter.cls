/* MCP protocol adapter for ooRexx MCP Project Service.
 *
 * Primary protocol: MCP 2026-07-28 (stateless modern era).
 * Compatibility: initialize-era MCP through 2025-11-25, served statelessly.
 *
 * The compatibility path is intentionally limited to the tool surface. It exists
 * so deployed hosts such as ChatGPT can scan/call tools while client rollout of
 * the 2026-07-28 revision is still heterogeneous. MCP identity is never authority.
 */

::class McpProtocolHttpResult public
::attribute status get
::attribute jsonText get
::method init
  expose status jsonText
  use strict arg status, jsonText

::class McpProtocolAdapter public
::constant PROTOCOL_VERSION "2026-07-28"
::constant LEGACY_VERSION "2025-11-25"
::constant SERVER_NAME "oorexx-mcp-project-service"
::constant SERVER_VERSION "0.2-dev8"

::method init
  expose projectService tools toolNameMode qualificationService
  use strict arg projectService, toolNameMode='canonical', qualificationService=.nil
  toolNameMode=toolNameMode~lower
  if toolNameMode<>'canonical' & toolNameMode<>'compat' then raise syntax 40.900 array('MCP tool name mode must be canonical or compat')
  tools=self~buildTools(toolNameMode,qualificationService<>.nil)

::method handle
  expose projectService tools
  use strict arg headers, bodyText, actorId=''
  signal on syntax name parseError
  request=.json~fromJSON(bodyText)
  signal off syntax
  if request==.nil then return self~rpcError(.nil,-32600,'Invalid Request',400)
  if \request~isA(.Directory) then return self~rpcError(.nil,-32600,'Invalid Request: JSON-RPC request must be an object',400)
  id=.nil
  if request~hasIndex('id') then id=request['id']
  if .McpProjectUtil~optional(request,'jsonrpc','')<>'2.0' then return self~rpcError(id,-32600,'Invalid Request',400)
  method=.McpProjectUtil~required(request,'method')
  if method='' then return self~rpcError(id,-32600,'Invalid Request: method is required',400)

  /* A modern request is self-identifying by the transport version header.
   * The initialize-era compatibility path deliberately has no such header.
   */
  protocolHeader=.McpProjectUtil~optional(headers,'mcp-protocol-version','')
  /* Streamable-HTTP initialize-era clients send MCP-Protocol-Version on
   * requests after initialization. A version header therefore does not mean
   * the request belongs to the 2026 stateless protocol. Route by the version
   * value itself, not merely by header presence.
   */
  if protocolHeader='' then return self~handleLegacy(request,id,method,actorId,'')
  if protocolHeader=self~PROTOCOL_VERSION then return self~handleModern(headers,request,id,method,actorId)
  if self~selectLegacyVersion(protocolHeader)<>'' then return self~handleLegacy(request,id,method,actorId,protocolHeader)
  return self~rpcError(id,-32020,'Unsupported MCP protocol version: '||protocolHeader,400)

parseError:
  return self~rpcError(.nil,-32700,'Parse error',400)

::method handleModern private
  use strict arg headers, request, id, method, actorId
  headerError=self~validateModernEnvelope(headers,request,method)
  if headerError<>'' then return self~rpcError(id,-32020,headerError,400)

  select
    when method='server/discover' then return self~rpcSuccess(id,self~discoverResult)
    when method='tools/list' then return self~rpcSuccess(id,self~listToolsResult)
    when method='tools/call' then return self~callTool(id,request,actorId,.true)
    when method='ping' then return self~rpcSuccess(id,self~stampServerInfo(.directory~new))
    otherwise return self~rpcError(id,-32601,'Method not found: '||method,404)
  end

::method handleLegacy private
  use strict arg request, id, method, actorId, protocolHeader=''
  select
    when method='initialize' then return self~legacyInitialize(id,request,protocolHeader)
    when method='notifications/initialized' then return .McpProtocolHttpResult~new(202,'')
    when method='tools/list' then return self~rpcSuccess(id,self~listToolsResultLegacy)
    when method='tools/call' then return self~callTool(id,request,actorId,.false)
    when method='ping' then return self~rpcSuccess(id,.directory~new)
    otherwise return self~rpcError(id,-32601,'Method not found: '||method,200)
  end

::method legacyInitialize private
  use strict arg id, request, protocolHeader=''
  if \request~hasIndex('params') then return self~rpcError(id,-32602,'initialize params are required',200)
  params=request['params']
  if params==.nil then return self~rpcError(id,-32602,'initialize params must be an object',200)
  if \params~isA(.Directory) then return self~rpcError(id,-32602,'initialize params must be an object',200)
  requested=.McpProjectUtil~optional(params,'protocolVersion','')
  selected=self~selectLegacyVersion(requested)
  if selected='' then return self~rpcError(id,-32602,'Unsupported protocol version: '||requested,200)
  if protocolHeader<>'' & protocolHeader<>selected then return self~rpcError(id,-32602,'MCP-Protocol-Version header does not match initialize protocolVersion',200)

  out=.directory~new
  out['protocolVersion']=selected
  capabilities=.directory~new
  capabilities['tools']=.directory~new
  out['capabilities']=capabilities
  info=.directory~new
  info['name']=self~SERVER_NAME
  info['version']=.JsonString~new(self~SERVER_VERSION)
  out['serverInfo']=info
  out['instructions']='Project coordination MCP: inspect spheres/components, coordinate ownership/requests, and when configured request durable preflight-first human-authorised qualification. Authenticated HTTPS identity is authoritative.'
  return self~rpcSuccess(id,out)

::method selectLegacyVersion private
  use strict arg requested
  /* Tool calling used by this service is compatible across these initialize-era
   * revisions. Keep the list explicit rather than accepting arbitrary versions.
   */
  select
    when requested='2025-11-25' then return requested
    when requested='2025-06-18' then return requested
    when requested='2025-03-26' then return requested
    otherwise return ''
  end

::method validateModernEnvelope private
  use strict arg headers, request, method
  protocol=.McpProjectUtil~optional(headers,'mcp-protocol-version','')
  if protocol='' then return 'MCP-Protocol-Version header is required'
  if protocol<>self~PROTOCOL_VERSION then return 'Unsupported MCP protocol version: '||protocol
  headerMethod=.McpProjectUtil~optional(headers,'mcp-method','')
  if headerMethod='' then return 'Mcp-Method header is required'
  if headerMethod<>method then return 'Mcp-Method header does not match JSON-RPC method'

  if \request~hasIndex('params') then return 'params with _meta are required by MCP 2026-07-28'
  params=request['params']
  if params==.nil then return 'params._meta is required by MCP 2026-07-28'
  if \params~isA(.Directory) then return 'params must be a JSON object'
  if \params~hasIndex('_meta') then return 'params._meta is required by MCP 2026-07-28'
  meta=params['_meta']
  if meta==.nil then return 'params._meta must be a JSON object'
  if \meta~isA(.Directory) then return 'params._meta must be a JSON object'
  protocolMeta=.McpProjectUtil~optional(meta,'io.modelcontextprotocol/protocolVersion','')
  if protocolMeta='' then return 'protocolVersion is required in request _meta'
  if protocolMeta<>self~PROTOCOL_VERSION then return 'request _meta protocolVersion does not match supported version'

  headerName=.McpProjectUtil~optional(headers,'mcp-name','')
  if method='tools/call' then do
    name=.McpProjectUtil~optional(params,'name','')
    if name='' then return 'tools/call params.name is required'
    if headerName='' then return 'Mcp-Name header is required for tools/call'
    if headerName<>name then return 'Mcp-Name header does not match tools/call params.name'
  end
  else if headerName<>'' then return 'Mcp-Name must be absent for this MCP method'
  return ''

::method discoverResult private
  out=.directory~new
  out['resultType']='complete'
  out['supportedVersions']=.array~of(self~PROTOCOL_VERSION)
  capabilities=.directory~new
  capabilities['tools']=.directory~new
  out['capabilities']=capabilities
  out['instructions']='Project coordination MCP: inspect spheres/components, coordinate ownership/requests, and when configured request durable preflight-first human-authorised qualification. Authenticated HTTPS identity is authoritative.'
  return self~stampServerInfo(out)

::method listToolsResult private
  expose tools
  out=.directory~new
  out['resultType']='complete'
  out['tools']=tools
  out['ttlMs']=30000
  out['cacheScope']='private'
  return self~stampServerInfo(out)

::method listToolsResultLegacy private
  expose tools
  out=.directory~new
  out['tools']=tools
  return out

::method callTool private
  expose projectService qualificationService
  use strict arg id, request, actorId, modern=.true
  if \request~hasIndex('params') then return self~rpcError(id,-32602,'tools/call params are required',400)
  params=request['params']
  if params==.nil then return self~rpcError(id,-32602,'tools/call params must be an object',400)
  if \params~isA(.Directory) then return self~rpcError(id,-32602,'tools/call params must be an object',400)
  name=.McpProjectUtil~optional(params,'name','')
  args=.directory~new
  if params~hasIndex('arguments') & params['arguments']<>.nil then args=params['arguments']
  operation=self~operationForTool(name)
  if operation='' then return self~rpcError(id,-32602,'Unknown tool: '||name,400)
  if operation~left(14)='QUALIFICATION.' then do
    if qualificationService==.nil then return self~rpcError(id,-32602,'Qualification service is not configured',400)
    serviceResult=qualificationService~dispatch(operation,args,actorId)
  end
  else serviceResult=projectService~dispatch(operation,args,actorId)
  toolResult=.directory~new
  if modern then toolResult['resultType']='complete'
  if serviceResult~ok then toolResult['isError']=.json~false
  else toolResult['isError']=.json~true
  structured=.directory~new
  if serviceResult~ok then structured['ok']=.json~true
  else structured['ok']=.json~false
  structured['code']=serviceResult~code
  structured['detail']=serviceResult~detail
  structured['value']=serviceResult~value
  toolResult['structuredContent']=structured
  contentItem=.directory~new
  contentItem['type']='text'
  if serviceResult~ok then contentItem['text']='OK '||serviceResult~code||': '||self~brief(serviceResult~value)
  else contentItem['text']='ERROR '||serviceResult~code||': '||serviceResult~detail
  toolResult['content']=.array~of(contentItem)
  if modern then toolResult=self~stampServerInfo(toolResult)
  return self~rpcSuccess(id,toolResult)

::method operationForTool private
  use strict arg name
  select
    when name='sphere.check' | name='sphere_check' then return 'SPHERE.CHECK'
    when name='project.components.list' | name='project_components_list' then return 'PROJECT.COMPONENTS.LIST'
    when name='project.request.create' | name='project_request_create' then return 'PROJECT.REQUEST.CREATE'
    when name='project.ownership.claim' | name='project_ownership_claim' then return 'PROJECT.OWNERSHIP.CLAIM'
    when name='project.ownership.release' | name='project_ownership_release' then return 'PROJECT.OWNERSHIP.RELEASE'
    when name='project.requests.list' | name='project_requests_list' then return 'PROJECT.REQUESTS.LIST'
    when name='project.request.mark_read' | name='project_request_mark_read' then return 'PROJECT.REQUEST.MARK_READ'
    when name='project.request.reply' | name='project_request_reply' then return 'PROJECT.REQUEST.REPLY'
    when name='qualification.plan' | name='qualification_plan' then return 'QUALIFICATION.PLAN'
    when name='qualification.request' | name='qualification_request' then return 'QUALIFICATION.REQUEST'
    when name='qualification.authorization.challenge' | name='qualification_authorization_challenge' then return 'QUALIFICATION.AUTHORIZATION.CHALLENGE'
    when name='qualification.authorization.submit' | name='qualification_authorization_submit' then return 'QUALIFICATION.AUTHORIZATION.SUBMIT'
    when name='qualification.status' | name='qualification_status' then return 'QUALIFICATION.STATUS'
    when name='qualification.results' | name='qualification_results' then return 'QUALIFICATION.RESULTS'
    when name='qualification.cancel' | name='qualification_cancel' then return 'QUALIFICATION.CANCEL'
    otherwise return ''
  end

::method brief private
  use strict arg value
  if value==.nil then return ''
  text=.json~toJSON(value)
  if text~length>500 then return text~left(497)||'...'
  return text

::method rpcSuccess private
  use strict arg id, payload
  response=.directory~new
  response['jsonrpc']=.JsonString~new('2.0')
  response['id']=id
  response['result']=payload
  return .McpProtocolHttpResult~new(200,.json~toJSON(response))

::method rpcError private
  use strict arg id, code, message, status=400, data=.nil
  response=.directory~new
  response['jsonrpc']=.JsonString~new('2.0')
  response['id']=id
  error=.directory~new
  error['code']=code
  error['message']=message
  if data<>.nil then error['data']=data
  response['error']=error
  return .McpProtocolHttpResult~new(status,.json~toJSON(response))

::method stampServerInfo private
  use strict arg out
  meta=.directory~new
  info=.directory~new
  info['name']=self~SERVER_NAME
  info['version']=.JsonString~new(self~SERVER_VERSION)
  meta['io.modelcontextprotocol/serverInfo']=info
  out['_meta']=meta
  return out

::method buildTools private
  use strict arg toolNameMode='canonical', includeQualification=.false
  out=.array~new
  if toolNameMode='compat' then do
    out~append(self~tool('sphere_check','Check a Gopher sphere','Compatibility alias for sphere.check. Resolve a sphere through LLM Gopher and report selected provenance.',self~objectSchema(.array~of('sphereId'),.array~of('sphereId','componentId'))))
    out~append(self~tool('project_components_list','List project components','Compatibility alias for project.components.list. List project components, including first-class sphere components, with ownership/request summary.',self~objectSchema(.array~new,.array~of('componentId','componentKind'))))
    out~append(self~tool('project_request_create','Create project request','Compatibility alias for project.request.create. Create an immutable request addressed to another project principal.',self~objectSchema(.array~of('componentId','body'),.array~of('componentId','recipientId','subject','body','requestType'))))
    out~append(self~tool('project_ownership_claim','Claim project component','Compatibility alias for project.ownership.claim. Claim active ownership of a project component for the authenticated LLM principal.',self~objectSchema(.array~of('componentId'),.array~of('componentId','claimRequestId'))))
    out~append(self~tool('project_ownership_release','Release project component','Compatibility alias for project.ownership.release. Release active ownership of a project component. Only the authenticated active owner may release it.',self~objectSchema(.array~of('componentId'),.array~of('componentId','releaseRequestId','reason'))))
    out~append(self~tool('project_requests_list','List visible requests','Compatibility alias for project.requests.list. List requests visible to the authenticated principal.',self~objectSchema(.array~new,.array~of('componentId','unreadOnly'))))
    out~append(self~tool('project_request_mark_read','Mark request read','Compatibility alias for project.request.mark_read. Create a per-principal read receipt without modifying the request.',self~objectSchema(.array~of('requestId'),.array~of('requestId'))))
    out~append(self~tool('project_request_reply','Reply to request','Compatibility alias for project.request.reply. Create a new request chained to an existing request.',self~objectSchema(.array~of('requestId','body'),.array~of('requestId','recipientId','subject','body','requestType'))))
    if includeQualification then do
      out~append(self~tool('qualification_plan','Preflight qualification','Compatibility alias for qualification.plan. Validate runnability without creating any authorization challenge.',self~qualificationPlanSchema))
      out~append(self~tool('qualification_request','Request qualification','Compatibility alias for qualification.request. Preflight and freeze an exact run intent before human authorization.',self~qualificationRequestSchema))
      out~append(self~tool('qualification_authorization_challenge','Get authorization challenge','Compatibility alias for qualification.authorization.challenge. Return the frozen intent/hash for local human signing.',self~objectSchema(.array~of('runId'),.array~of('runId'))))
      out~append(self~tool('qualification_authorization_submit','Submit detached approval','Compatibility alias for qualification.authorization.submit. Submit only runId, public key identity and detached signature; never private-key material.',self~objectSchema(.array~of('runId','approverKeyId','signature'),.array~of('runId','approverKeyId','signature'))))
      out~append(self~tool('qualification_status','Qualification status','Compatibility alias for qualification.status.',self~objectSchema(.array~of('runId'),.array~of('runId'))))
      out~append(self~tool('qualification_results','Qualification results','Compatibility alias for qualification.results.',self~objectSchema(.array~of('runId'),.array~of('runId'))))
      out~append(self~tool('qualification_cancel','Cancel qualification','Compatibility alias for qualification.cancel. Does not expose worker execution control.',self~objectSchema(.array~of('runId'),.array~of('runId'))))
    end
    return out
  end

  out~append(self~tool('sphere.check','Check a Gopher sphere','Resolve a sphere through LLM Gopher and report selected provenance.',self~objectSchema(.array~of('sphereId'),.array~of('sphereId','componentId'))))
  out~append(self~tool('project.components.list','List project components','List project components, including first-class sphere components, with ownership/request summary.',self~objectSchema(.array~new,.array~of('componentId','componentKind'))))
  out~append(self~tool('project.request.create','Create project request','Create an immutable request addressed to another project principal.',self~objectSchema(.array~of('componentId','body'),.array~of('componentId','recipientId','subject','body','requestType'))))
  out~append(self~tool('project.ownership.claim','Claim project component','Claim active ownership of a project component for the authenticated LLM principal.',self~objectSchema(.array~of('componentId'),.array~of('componentId','claimRequestId'))))
  out~append(self~tool('project.ownership.release','Release project component','Release active ownership of a project component. Only the authenticated active owner may release it.',self~objectSchema(.array~of('componentId'),.array~of('componentId','releaseRequestId','reason'))))
  out~append(self~tool('project.requests.list','List visible requests','List requests visible to the authenticated principal.',self~objectSchema(.array~new,.array~of('componentId','unreadOnly'))))
  out~append(self~tool('project.request.mark_read','Mark request read','Create a per-principal read receipt without modifying the request.',self~objectSchema(.array~of('requestId'),.array~of('requestId'))))
  out~append(self~tool('project.request.reply','Reply to request','Create a new request chained to an existing request.',self~objectSchema(.array~of('requestId','body'),.array~of('requestId','recipientId','subject','body','requestType'))))
  if includeQualification then do
    out~append(self~tool('qualification.plan','Preflight qualification','Validate artifact/data/runtime/sandbox/test-plan/target runnability. This operation never creates an authorization challenge.',self~qualificationPlanSchema))
    out~append(self~tool('qualification.request','Request qualification','Preflight and freeze an exact qualification intent. Human authorization is requested only after this succeeds.',self~qualificationRequestSchema))
    out~append(self~tool('qualification.authorization.challenge','Get authorization challenge','Return the frozen intent/hash and public verification-key identities for a local-only signing ceremony.',self~objectSchema(.array~of('runId'),.array~of('runId'))))
    out~append(self~tool('qualification.authorization.submit','Submit detached approval','Submit a detached Ed25519 approval for the frozen run. Private key material is never accepted.',self~objectSchema(.array~of('runId','approverKeyId','signature'),.array~of('runId','approverKeyId','signature'))))
    out~append(self~tool('qualification.status','Qualification status','Read durable qualification state without holding a chat execution session open.',self~objectSchema(.array~of('runId'),.array~of('runId'))))
    out~append(self~tool('qualification.results','Qualification results','Return sealed qualification evidence/result metadata when available.',self~objectSchema(.array~of('runId'),.array~of('runId'))))
    out~append(self~tool('qualification.cancel','Cancel qualification','Cancel a not-yet-running qualification request. Worker execution is not exposed through MCP.',self~objectSchema(.array~of('runId'),.array~of('runId'))))
  end
  return out

::method qualificationPlanSchema private
  return self~qualificationSchema(.false)

::method qualificationRequestSchema private
  return self~qualificationSchema(.true)

::method qualificationSchema private
  use strict arg includePurpose
  required=.array~of('artifactId','dataId','runtimeId','sandboxId','testPlanId','targetId')
  if includePurpose then props=.array~of('artifactId','dataId','runtimeId','sandboxId','testPlanId','targetId','purpose','maxRuntimeSeconds','maxWlu')
  else props=.array~of('artifactId','dataId','runtimeId','sandboxId','testPlanId','targetId','maxRuntimeSeconds','maxWlu')
  return self~objectSchema(required,props)

::method tool private
  use strict arg name,title,description,inputSchema
  t=.directory~new
  t['name']=name; t['title']=title; t['description']=description; t['inputSchema']=inputSchema
  return t

::method objectSchema private
  use strict arg requiredNames, propertyNames
  schema=.directory~new
  schema['type']='object'
  properties=.directory~new
  do name over propertyNames
    p=.directory~new
    if name='unreadOnly' then p['type']='boolean'
    else if name='maxRuntimeSeconds' | name='maxWlu' then p['type']='integer'
    else p['type']='string'
    properties[name]=p
  end
  schema['properties']=properties
  schema['required']=requiredNames
  schema['additionalProperties']=.json~false
  return schema

::requires 'McpProjectService.cls'
::requires 'json.cls'
