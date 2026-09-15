/* Composition sketch. The host application must already have authenticated the
 * peer and place a verified project principal into HttpExchangeContext under
 * 'mcp.principal'. Do not derive authority from MCP clientInfo. */
parse arg catalogPath journalPath gopherPath apiRollup sphereOverride
if catalogPath='' | journalPath='' then do
  say 'usage: rexx embed_mcp.rex CATALOG.json JOURNAL.jsonl [GOPHER API_ROLLUP SPHERE_OVERRIDE_DIR]'
  exit 2
end

catalog=.McpProjectComponentCatalog~fromJsonFile(catalogPath)
journal=.McpProjectJsonlJournal~new(journalPath)
checker=.McpProjectNullSphereChecker~new
if gopherPath<>'' then checker=.McpGopherSphereChecker~new(gopherPath,apiRollup,sphereOverride)
wireService=.McpProjectWireService~new(catalog,journal,checker)
protocol=.McpProtocolAdapter~new(wireService)
route=.McpHttpsRoute~new(protocol)
/* Optional client-compatibility presentation. It advertises underscore aliases
 * only, while sharing exactly the same authoritative Wire service. */
compatProtocol=.McpProtocolAdapter~new(wireService,'compat')
compatRoute=.McpHttpsRoute~new(compatProtocol)

/* In the real HTTPS application:
 *   route~bind(server,'/mcp')
 *   compatRoute~bind(server,'/mcp-compat')  -- optional Grok/name-compat A/B path
 *   server~serve
 * A trusted interceptor before this route must set context['mcp.principal'].
 */
say 'MCP project service composed; bind canonical /mcp and optional /mcp-compat routes to the existing HttpsServer.'

::requires 'McpProjectService.cls'
::requires 'McpGopherSphereChecker.cls'
::requires 'McpProtocolAdapter.cls'
::requires 'McpHttpsRoute.cls'
