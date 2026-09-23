/* MCP 2026-07-28 stateless JSON-RPC protocol binding for Cognitive Continuity.
 * HTTPS/authentication supplies actorId. This class owns protocol translation only.
 */

::class CognitiveMcpHttpResult public
::attribute status get
::attribute jsonText get
::method init
  expose status jsonText
  use strict arg status, jsonText

::class CognitiveMcpProtocolAdapter public
::constant PROTOCOL_VERSION "2026-07-28"
::constant SERVER_NAME "oorexx-cognitive-continuity"
::constant SERVER_VERSION "0.1-dev2-exp1"

::method init
  expose semantic tools
  use strict arg semanticAdapter
  if semanticAdapter == .nil then raise syntax 40.900 array('Cognitive MCP semantic adapter is required')
  semantic=semanticAdapter
  tools=semantic~tools

::method handle
  use strict arg headers, bodyText, actorId=''
  signal on syntax name parseError
  request=.json~fromJSON(bodyText)
  signal off syntax
  if request==.nil | \request~isA(.Directory) then return self~rpcError(.nil,-32600,'Invalid Request',400)
  id=.nil; if request~hasIndex('id') then id=request['id']
  if .CognitiveUtil~optional(request,'jsonrpc','')<>'2.0' then return self~rpcError(id,-32600,'Invalid Request',400)
  method=.CognitiveUtil~required(request,'method')
  if method='' then return self~rpcError(id,-32600,'Invalid Request: method is required',400)
  envelopeError=self~validateEnvelope(headers,request,method)
  if envelopeError<>'' then return self~rpcError(id,-32020,envelopeError,400)
  select
    when method='server/discover' then return self~rpcSuccess(id,self~discover)
    when method='tools/list' then return self~rpcSuccess(id,self~toolList)
    when method='tools/call' then return self~callTool(id,request,actorId)
    when method='ping' then return self~rpcSuccess(id,self~stamp(.directory~new))
    otherwise return self~rpcError(id,-32601,'Method not found: '||method,404)
  end
parseError:
  return self~rpcError(.nil,-32700,'Parse error',400)

::method validateEnvelope private
  use strict arg headers, request, method
  protocol=.CognitiveUtil~optional(headers,'mcp-protocol-version','')
  if protocol='' then return 'MCP-Protocol-Version header is required'
  if protocol<>self~PROTOCOL_VERSION then return 'Unsupported MCP protocol version: '||protocol
  headerMethod=.CognitiveUtil~optional(headers,'mcp-method','')
  if headerMethod='' then return 'Mcp-Method header is required'
  if headerMethod<>method then return 'Mcp-Method header does not match JSON-RPC method'
  if \request~hasIndex('params') then return 'params with _meta are required by MCP 2026-07-28'
  params=request['params']
  if params==.nil | \params~isA(.Directory) then return 'params must be a JSON object'
  if \params~hasIndex('_meta') then return 'params._meta is required by MCP 2026-07-28'
  meta=params['_meta']
  if meta==.nil | \meta~isA(.Directory) then return 'params._meta must be a JSON object'
  protocolMeta=.CognitiveUtil~optional(meta,'io.modelcontextprotocol/protocolVersion','')
  if protocolMeta<>self~PROTOCOL_VERSION then return 'request _meta protocolVersion does not match supported version'
  headerName=.CognitiveUtil~optional(headers,'mcp-name','')
  if method='tools/call' then do
    name=.CognitiveUtil~optional(params,'name','')
    if name='' then return 'tools/call params.name is required'
    if headerName='' then return 'Mcp-Name header is required for tools/call'
    if headerName<>name then return 'Mcp-Name header does not match tools/call params.name'
  end
  else if headerName<>'' then return 'Mcp-Name must be absent for this MCP method'
  return ''

::method discover private
  out=.directory~new
  out['resultType']='complete'
  out['supportedVersions']=.array~of(self~PROTOCOL_VERSION)
  caps=.directory~new; caps['tools']=.directory~new; out['capabilities']=caps
  out['instructions']='Cognitive Continuity MCP. Context projections are disposable; cognitive effects are admission proposals. Authenticated transport identity is authoritative.'
  return self~stamp(out)

::method toolList private
  expose tools
  out=.directory~new; out['resultType']='complete'; out['tools']=tools; out['ttlMs']=30000; out['cacheScope']='private'
  return self~stamp(out)

::method callTool private
  expose semantic
  use strict arg id, request, actorId
  params=request['params']
  name=.CognitiveUtil~optional(params,'name','')
  args=.directory~new
  if params~hasIndex('arguments') & params['arguments']<>.nil then args=params['arguments']
  serviceResult=semantic~call(name,args,actorId)
  toolResult=.directory~new; toolResult['resultType']='complete'
  if serviceResult~ok then toolResult['isError']=.json~false; else toolResult['isError']=.json~true
  structured=.CognitiveStructuredResponseBridge~wrap(serviceResult,'MCP:'||name,actorId)
  toolResult['structuredContent']=structured
  content=.directory~new; content['type']='text'
  if serviceResult~ok then content['text']='OK '||serviceResult~code||': '||self~brief(serviceResult~value)
  else content['text']='ERROR '||serviceResult~code||': '||serviceResult~detail
  toolResult['content']=.array~of(content)
  return self~rpcSuccess(id,self~stamp(toolResult))

::method brief private
  use strict arg value
  if value==.nil then return ''
  text=.json~toJSON(value)
  if text~length>500 then return text~left(497)||'...'
  return text

::method stamp private
  use strict arg out
  meta=.directory~new; info=.directory~new
  info['name']=self~SERVER_NAME; info['version']=.JsonString~new(self~SERVER_VERSION)
  meta['io.modelcontextprotocol/serverInfo']=info; out['_meta']=meta
  return out

::method rpcSuccess private
  use strict arg id, payload
  response=.directory~new; response['jsonrpc']=.JsonString~new('2.0'); response['id']=id; response['result']=payload
  return .CognitiveMcpHttpResult~new(200,.json~toJSON(response))

::method rpcError private
  use strict arg id, code, message, status=400
  response=.directory~new; response['jsonrpc']=.JsonString~new('2.0'); response['id']=id
  error=.directory~new; error['code']=code; error['message']=message; response['error']=error
  return .CognitiveMcpHttpResult~new(status,.json~toJSON(response))

::requires 'CognitiveMcpAdapter.cls'
::requires 'CognitiveStructuredResponseBridge.cls'
::requires 'CognitiveContinuity.cls'
::requires 'json.cls'
