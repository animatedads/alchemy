/* Optional binding to ooRexx HTTPS Server v0.4.4.
 * Authentication is external. Trusted HTTPS context supplies mcp.principal.
 */
::class CognitiveMcpContextPrincipalResolver public
::method resolve
  use strict arg request
  if request~context==.nil then return ''
  return request~context~get('mcp.principal','')~string

::class CognitiveMcpFixedPrincipalResolver public
::method init; expose principal; use strict arg principal
::method resolve; expose principal; use strict arg request; return principal

::class CognitiveMcpHttpsRoute public
::method init
  expose protocol principalResolver
  use strict arg protocolArg, principalResolverArg=.nil
  protocol=protocolArg; principalResolver=principalResolverArg
  if principalResolver==.nil then principalResolver=.CognitiveMcpContextPrincipalResolver~new
::method bind
  use strict arg server, path='/cognitive-mcp'
  server~route('POST',path,self,'post'); server~route('GET',path,self,'probe'); server~route('HEAD',path,self,'probe'); return self
::method probe
  use strict arg request
  response=.HttpResponse~json('{"status":"mcp","service":"cognitive-continuity","transport":"streamable-http","post":"required"}',405)
  response~header('Allow','POST'); response~header('Cache-Control','no-store'); return response
::method post
  expose protocol principalResolver
  use strict arg request
  signal on syntax name routeError
  headers=.directory~new
  headers['mcp-protocol-version']=request~header('MCP-Protocol-Version','')
  headers['mcp-method']=request~header('Mcp-Method','')
  headers['mcp-name']=request~header('Mcp-Name','')
  actorId=principalResolver~resolve(request)
  result=protocol~handle(headers,request~body,actorId)
  signal off syntax
  if result~jsonText='' then response=.HttpResponse~empty(result~status); else response=.HttpResponse~json(result~jsonText,result~status)
  if headers['mcp-protocol-version']<>'' then response~header('MCP-Protocol-Version',.CognitiveMcpProtocolAdapter~PROTOCOL_VERSION)
  response~header('Cache-Control','no-store')
  if request~context<>.nil then response~header('X-Request-Id',request~context~requestId)
  return response
routeError:
  body='{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal error"}}'
  response=.HttpResponse~json(body,500); response~header('Cache-Control','no-store'); return response
::requires 'https_server.cls'
::requires 'CognitiveMcpProtocolAdapter.cls'
