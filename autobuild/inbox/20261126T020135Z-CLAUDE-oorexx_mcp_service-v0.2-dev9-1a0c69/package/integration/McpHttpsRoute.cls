/* Binding to ooRexx HTTPS Server v0.4.4.
 * Authentication is deliberately external: a trusted HTTPS interceptor/gateway
 * must set request.context['mcp.principal']; clientInfo is never authority.
 *
 * Transport errors are converted to a bounded JSON-RPC internal-error response
 * so a connector scan cannot collapse into the HTTPS server's generic 500 path.
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
  /* Explicit probe routes make browser/operator probes deterministic. */
  server~route('GET',path,self,'probe')
  server~route('HEAD',path,self,'probe')
  return self

::method probe
  use strict arg request
  response=.HttpResponse~json('{"status":"mcp","transport":"streamable-http","post":"required"}',405)
  response~header('Allow','POST')
  response~header('Cache-Control','no-store')
  return response

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

  if result~jsonText='' then response=.HttpResponse~empty(result~status)
  else response=.HttpResponse~json(result~jsonText,result~status)
  if headers['mcp-protocol-version']<>'' then response~header('MCP-Protocol-Version',.McpProtocolAdapter~PROTOCOL_VERSION)
  response~header('Cache-Control','no-store')
  if request~context<>.nil then response~header('X-Request-Id',request~context~requestId)
  return response

routeError:
  /* Deliberately do not leak ooRexx condition text to a remote caller. The
   * X-Request-Id lets operators correlate the server-side diagnostic/log. */
  body='{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal error"}}'
  response=.HttpResponse~json(body,500)
  response~header('Cache-Control','no-store')
  if request~context<>.nil then response~header('X-Request-Id',request~context~requestId)
  return response

/* HttpResponse is a public class of the HTTPS package, but ooRexx public
 * classes are imported through package dependency relationships, not magically
 * shared between sibling ::requires packages.  Import the transport package
 * here so .HttpResponse resolves to the real HTTPS class in this package. */
::requires 'https_server.cls'
::requires 'McpProtocolAdapter.cls'
