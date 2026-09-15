/* Binding to ooRexx HTTPS Server v0.4.4.
 * Authentication is deliberately external: a trusted HTTPS interceptor/gateway
 * must set request.context['mcp.principal']; clientInfo is never authority.
 */

::class McpContextPrincipalResolver public
::method resolve
  use strict arg request
  if request~context==.nil then return ''
  return request~context~get('mcp.principal','')~string

::class McpFixedPrincipalResolver public
::method init
  expose principal
  use strict arg principal
::method resolve
  expose principal
  use strict arg request
  return principal

::class McpHttpsRoute public
::method init
  expose protocol principalResolver
  use strict arg protocol, principalResolver=.nil
  if principalResolver==.nil then principalResolver=.McpContextPrincipalResolver~new

::method bind
  use strict arg server, path='/mcp'
  server~route('POST',path,self,'post')
  return self

::method post
  expose protocol principalResolver
  use strict arg request
  headers=.directory~new
  headers['mcp-protocol-version']=request~header('MCP-Protocol-Version','')
  headers['mcp-method']=request~header('Mcp-Method','')
  headers['mcp-name']=request~header('Mcp-Name','')
  actorId=principalResolver~resolve(request)
  result=protocol~handle(headers,request~body,actorId)
  response=.HttpResponse~json(result~jsonText,result~status)
  response~header('MCP-Protocol-Version',.McpProtocolAdapter~PROTOCOL_VERSION)
  response~header('Cache-Control','no-store')
  return response

::requires 'McpProtocolAdapter.cls'
