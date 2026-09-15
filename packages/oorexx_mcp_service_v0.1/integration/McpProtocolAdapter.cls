/* MCP 2026-07-28 protocol adapter for ooRexx MCP Project Service v0.1.
 * Pure JSON/headers adapter: HTTPS transport binding is in McpHttpsRoute.cls.
 */

::class McpProtocolHttpResult public
::attribute status get
::attribute jsonText get
::method init
  expose status jsonText
  use strict arg status, jsonText

::class McpProtocolAdapter public
::constant PROTOCOL_VERSION "2026-07-28"
::constant SERVER_NAME "oorexx-mcp-project-service"
::constant SERVER_VERSION "0.1"

::method init
  expose projectService tools
  use strict arg projectService
  tools=self~buildTools

::method handle
  expose projectService tools
  use strict arg headers, bodyText, actorId=''
  signal on syntax name parseError
  request=.json~fromJSON(bodyText)
  signal off syntax
  if request==.nil then return self~rpcError(.nil,-32600,'Invalid Request',400)
  id=.nil
  if request~hasIndex('id') then id=request['id']
  if .McpProjectUtil~optional(request,'jsonrpc','')<>'2.0' then return self~rpcError(id,-32600,'Invalid Request',400)
  method=.McpProjectUtil~required(request,'method')
  if method='' then return self~rpcError(id,-32600,'Invalid Request: method is required',400)

  headerError=self~validateModernEnvelope(headers,request,method)
  if headerError<>'' then return self~rpcError(id,-32020,headerError,400)

  select
    when method='server/discover' then return self~rpcSuccess(id,self~discoverResult)
    when method='tools/list' then return self~rpcSuccess(id,self~listToolsResult)
    when method='tools/call' then return self~callTool(id,request,actorId)
    otherwise return self~rpcError(id,-32601,'Method not found: '||method,404)
  end

parseError:
  return self~rpcError(.nil,-32700,'Parse error',400)

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
  if params==.nil | \params~hasIndex('_meta') then return 'params._meta is required by MCP 2026-07-28'
  meta=params['_meta']
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
  out['instructions']='Project coordination MCP: inspect spheres/components, create/read/reply to project requests, and claim component ownership. Authenticated HTTPS identity is authoritative.'
  return self~stampServerInfo(out)

::method listToolsResult private
  expose tools
  out=.directory~new
  out['resultType']='complete'
  out['tools']=tools
  out['ttlMs']=30000
  out['cacheScope']='private'
  return self~stampServerInfo(out)

::method callTool private
  expose projectService
  use strict arg id, request, actorId
  params=request['params']
  name=.McpProjectUtil~optional(params,'name','')
  args=.directory~new
  if params~hasIndex('arguments') & params['arguments']<>.nil then args=params['arguments']
  operation=self~operationForTool(name)
  if operation='' then return self~rpcError(id,-32602,'Unknown tool: '||name,400)
  serviceResult=projectService~dispatch(operation,args,actorId)
  toolResult=.directory~new
  toolResult['resultType']='complete'
  toolResult['isError']=\serviceResult~ok
  structured=.directory~new
  structured['ok']=serviceResult~ok
  structured['code']=serviceResult~code
  structured['detail']=serviceResult~detail
  structured['value']=serviceResult~value
  toolResult['structuredContent']=structured
  contentItem=.directory~new
  contentItem['type']='text'
  if serviceResult~ok then contentItem['text']='OK '||serviceResult~code||': '||self~brief(serviceResult~value)
  else contentItem['text']='ERROR '||serviceResult~code||': '||serviceResult~detail
  toolResult['content']=.array~of(contentItem)
  return self~rpcSuccess(id,self~stampServerInfo(toolResult))

::method operationForTool private
  use strict arg name
  select
    when name='sphere.check' then return 'SPHERE.CHECK'
    when name='project.components.list' then return 'PROJECT.COMPONENTS.LIST'
    when name='project.request.create' then return 'PROJECT.REQUEST.CREATE'
    when name='project.ownership.claim' then return 'PROJECT.OWNERSHIP.CLAIM'
    when name='project.requests.list' then return 'PROJECT.REQUESTS.LIST'
    when name='project.request.mark_read' then return 'PROJECT.REQUEST.MARK_READ'
    when name='project.request.reply' then return 'PROJECT.REQUEST.REPLY'
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
  out=.array~new
  out~append(self~tool('sphere.check','Check a Gopher sphere','Resolve a sphere through LLM Gopher and report selected provenance.',self~objectSchema(.array~of('sphereId'),.array~of('sphereId','componentId'))))
  out~append(self~tool('project.components.list','List project components','List current ooRexxAPI project components with ownership/request summary.',self~objectSchema(.array~new,.array~of('componentId'))))
  out~append(self~tool('project.request.create','Create project request','Create an immutable request addressed to another project principal.',self~objectSchema(.array~of('componentId','body'),.array~of('componentId','recipientId','subject','body','requestType'))))
  out~append(self~tool('project.ownership.claim','Claim project component','Claim active ownership of a project component for the authenticated LLM principal.',self~objectSchema(.array~of('componentId'),.array~of('componentId','claimRequestId'))))
  out~append(self~tool('project.requests.list','List visible requests','List requests visible to the authenticated principal.',self~objectSchema(.array~new,.array~of('componentId','unreadOnly'))))
  out~append(self~tool('project.request.mark_read','Mark request read','Create a per-principal read receipt without modifying the request.',self~objectSchema(.array~of('requestId'),.array~of('requestId'))))
  out~append(self~tool('project.request.reply','Reply to request','Create a new request chained to an existing request.',self~objectSchema(.array~of('requestId','body'),.array~of('requestId','recipientId','subject','body','requestType'))))
  return out

::method tool private
  use strict arg name,title,description,inputSchema
  t=.directory~new
  t['name']=name; t['title']=title; t['description']=description; t['inputSchema']=inputSchema
  return t

::method objectSchema private
  use strict arg requiredNames, propertyNames
  schema=.directory~new
  schema['$schema']='https://json-schema.org/draft/2020-12/schema'
  schema['type']='object'
  properties=.directory~new
  do name over propertyNames
    p=.directory~new
    if name='unreadOnly' then p['type']='boolean'
    else p['type']='string'
    properties[name]=p
  end
  schema['properties']=properties
  schema['required']=requiredNames
  schema['additionalProperties']=.false
  return schema

::requires 'McpProjectService.cls'
::requires 'json.cls'
