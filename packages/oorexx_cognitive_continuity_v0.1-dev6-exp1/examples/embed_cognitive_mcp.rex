/* Composition sketch for ChatGPT/Codex MCP dog-food access.
 * Host HTTPS authentication must set request.context['mcp.principal'].
 */
parse arg journalPath scopeRef
if journalPath='' | scopeRef='' then do
  say 'usage: rexx embed_cognitive_mcp.rex JOURNAL.jsonl SCOPE'
  exit 2
end
policy=.CognitiveAccessPolicy~new
ignore=policy~grant('chatgpt:mcp','cognitive.effects.propose.model',scopeRef)
ignore=policy~grant('chatgpt:mcp','cognitive.records.query',scopeRef)
ignore=policy~grant('chatgpt:mcp','cognitive.context.project',scopeRef)
ignore=policy~grant('chatgpt:mcp','cognitive.context.explain',scopeRef)
ignore=policy~grant('codex:mcp','cognitive.effects.propose.model',scopeRef)
ignore=policy~grant('codex:mcp','cognitive.records.query',scopeRef)
ignore=policy~grant('codex:mcp','cognitive.context.project',scopeRef)
ignore=policy~grant('codex:mcp','cognitive.context.explain',scopeRef)
service=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(journalPath),policy)
semantic=.CognitiveMcpAdapter~new(service)
protocol=.CognitiveMcpProtocolAdapter~new(semantic)
route=.CognitiveMcpHttpsRoute~new(protocol)
say 'Cognitive MCP composed. Bind route~bind(server,"/cognitive-mcp") to existing HttpsServer.'
say 'Use cognitive.context.export to inspect the exact model-facing context payload.'
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveMcpAdapter.cls'
::requires 'CognitiveMcpProtocolAdapter.cls'
::requires 'CognitiveMcpHttpsRoute.cls'
