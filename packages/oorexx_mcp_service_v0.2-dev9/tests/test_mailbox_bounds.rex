/* test_mailbox_bounds.rex -- MCP Project Service v0.2-dev9
 * Regression for the 26 Nov 2026 blockage: one oversized unread reply at the
 * head of a lane made project.requests.list too large for the client to read,
 * hiding every newer message, and no call could read one request by ID.
 * Architecture: Tom Dyer.  Coded by: Claude (Opus 5.5).
 */
parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)

/* 1. Reproduce the lane: a 40000-byte report first, then 16 small messages. */
big=''
do i=1 to 400
  big=big||('line' i~right(4,'0') 'of the oversized report' copies('x',60))~left(99)||'0a'x
end
big=big~left(40000)
call assert big~length=40000,'oversized body is 40000 bytes'
bigId=create('llm:codex','llm:claude',big,'Oversized report')
ids=.array~of(bigId)
do i=1 to 16
  ids~append(create('llm:codex','llm:claude','Small result' i,'Result' i))
end

/* 2. Default list is bounded and reports what it cut. */
la=.directory~new; la['unreadOnly']=.true
r=service~dispatch('PROJECT.REQUESTS.LIST',la,'llm:claude')
call assert r~ok,'default list ok'
v=r~value
call assert v['count']=10,'default limit is 10'
call assert v['total']=17,'total counts every match'
call assert v['hasMore']=1,'hasMore set'
call assert v['nextAfterId']~string=ids[10],'nextAfterId is the last returned request'
first=v['requests'][1]
call assert first['requestId']~string=bigId,'oldest first by default'
call assert first['body']~length<=1500,'list body cut to 1500 bytes'
call assert first['bodyBytes']=40000,'list reports full body size'
call assert first['bodyTruncated']=1,'list reports truncation'
call assert v['requests'][2]['bodyTruncated']=0,'small body not truncated'
json=.json~toJSON(v)
call assert json~length<30000,'default listing JSON under 30000 chars (was ~41000+ unbounded): '||json~length

/* 3. Ten oversized requests still give a listing under the client ceiling. */
s2=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)
do i=1 to 12
  a=.directory~new; a['componentId']='wire_ui_server'; a['recipientId']='llm:claude'; a['body']=big; a['subject']=copies('S',1000)
  call assert s2~dispatch('PROJECT.REQUEST.CREATE',a,'llm:codex')~ok,'create big' i
end
r=s2~dispatch('PROJECT.REQUESTS.LIST',.directory~new,'llm:claude')
json=.json~toJSON(r~value)
call assert json~length<30000,'worst-case default listing under 30000 chars: '||json~length
call assert r~value['requests'][1]['subject']~length<=303,'subject capped'

/* 4. afterId paging reaches every request exactly once. */
seen=.array~new; after=''
do pages=1 to 10
  a=.directory~new; a['unreadOnly']=.true; a['limit']=4
  if after<>'' then a['afterId']=after
  r=service~dispatch('PROJECT.REQUESTS.LIST',a,'llm:claude')
  call assert r~ok,'page' pages
  do q over r~value['requests']; seen~append(q['requestId']~string); end
  if r~value['hasMore']=0 then leave
  after=r~value['nextAfterId']~string
end
call assert seen~items=17,'paging returns all 17'
do i=1 to 17; call assert seen[i]=ids[i],'paging order' i; end

/* 5. newestFirst puts the newest request first. */
a=.directory~new; a['newestFirst']=.true; a['limit']=1
r=service~dispatch('PROJECT.REQUESTS.LIST',a,'llm:claude')
call assert r~value['requests'][1]['requestId']~string=ids[17],'newestFirst'
call assert r~value['order']~string='newest-first','order reported'

/* 6. maxBodyBytes 0 omits bodies; bad arguments are rejected, not clamped. */
a=.directory~new; a['maxBodyBytes']=0
r=service~dispatch('PROJECT.REQUESTS.LIST',a,'llm:claude')
call assert r~value['requests'][1]['body']=='','maxBodyBytes 0 omits body'
do bad over .array~of('0','101','2.5','ten')
  a=.directory~new; a['limit']=bad
  r=service~dispatch('PROJECT.REQUESTS.LIST',a,'llm:claude')
  call assert \r~ok & r~code='INVALID_ARGUMENT','limit rejected:' bad
end
a=.directory~new; a['afterId']='REQ-99999999'
call assert service~dispatch('PROJECT.REQUESTS.LIST',a,'llm:claude')~code='REQUEST_NOT_FOUND','unknown afterId'

/* 7. GET reads one request; pages rebuild the body byte for byte. */
g=.directory~new; g['requestId']=bigId
r=service~dispatch('PROJECT.REQUEST.GET',g,'llm:claude')
call assert r~ok & r~code='REQUEST_FETCHED','get ok'
call assert r~value['body']~length=8000 & r~value['bodyHasMore']=1,'default page 8000'
rebuilt=''; off=1
do n=1 to 20
  g=.directory~new; g['requestId']=bigId; g['offset']=off; g['length']=7000
  r=service~dispatch('PROJECT.REQUEST.GET',g,'llm:claude')
  call assert r~ok,'get page' n
  rebuilt=rebuilt||r~value['body']
  if r~value['bodyHasMore']=0 then leave
  off=r~value['nextOffset']
end
call assert rebuilt==big,'pages rebuild the body exactly'

/* 8. GET does not mark read, respects visibility, validates arguments. */
la=.directory~new; la['unreadOnly']=.true
call assert service~dispatch('PROJECT.REQUESTS.LIST',la,'llm:claude')~value['total']=17,'get leaves request unread'
g=.directory~new; g['requestId']=bigId
call assert service~dispatch('PROJECT.REQUEST.GET',g,'llm:mallory')~code='REQUEST_NOT_VISIBLE','get hidden from others'
call assert service~dispatch('PROJECT.REQUEST.GET',g,'')~code='AUTHENTICATED_PRINCIPAL_REQUIRED','get needs principal'
g['requestId']='REQ-99999999'
call assert service~dispatch('PROJECT.REQUEST.GET',g,'llm:claude')~code='REQUEST_NOT_FOUND','get unknown id'
g['requestId']=bigId; g['length']=16001
call assert service~dispatch('PROJECT.REQUEST.GET',g,'llm:claude')~code='INVALID_ARGUMENT','get length over max'
g['length']=10; g['offset']=40001
call assert service~dispatch('PROJECT.REQUEST.GET',g,'llm:claude')~code='INVALID_ARGUMENT','get offset past end'

/* 9. UTF-8: cuts never split a character. e-acute is C3 A9; Euro sign is E2 82 AC. */
utf='a'||copies('C3A9'x,10)||copies('E282AC'x,10)
uid=create('llm:codex','llm:claude',utf,'utf8')
a=.directory~new; a['newestFirst']=.true; a['limit']=1; a['maxBodyBytes']=4
r=service~dispatch('PROJECT.REQUESTS.LIST',a,'llm:claude')
call assert r~value['requests'][1]['body']=='a'||'C3A9'x,'list cut backs off a split character'
seen=''; off=1
do n=1 to 40
  g=.directory~new; g['requestId']=uid; g['offset']=off; g['length']=2
  r=service~dispatch('PROJECT.REQUEST.GET',g,'llm:claude')
  call assert r~ok,'utf8 page' n
  call assert validUtf8(r~value['body']),'utf8 page' n 'is whole characters'
  seen=seen||r~value['body']
  if r~value['bodyHasMore']=0 then leave
  off=r~value['nextOffset']
end
call assert seen==utf,'utf8 pages rebuild exactly (3-byte chars with length 2 still advance)'
g=.directory~new; g['requestId']=uid; g['offset']=3; g['length']=2
r=service~dispatch('PROJECT.REQUEST.GET',g,'llm:claude')
call assert r~value['bodyOffset']=2,'offset on a continuation byte moves back to the lead byte'

/* 10. Adapter: tools/list advertises project.request.get and it works over MCP. */
protocol=.McpProtocolAdapter~new(service)
headers=.directory~new; headers['mcp-protocol-version']='2026-07-28'
params=.directory~new; meta=.directory~new; meta['io.modelcontextprotocol/protocolVersion']='2026-07-28'; params['_meta']=meta
req=.directory~new; req['jsonrpc']='2.0'; req['id']=1; req['method']='tools/list'; req['params']=params
headers['mcp-method']='tools/list'; headers['mcp-name']=''
d=.json~fromJSON(protocol~handle(headers,.json~toJSON(req),'llm:claude')~jsonText)
found=.false
do t over d['result']['tools']
  if t['name']='project.request.get' then do
    found=.true
    call assert t['inputSchema']['properties']['offset']['type']='integer','offset is integer'
  end
  if t['name']='project.requests.list' then call assert t['inputSchema']['properties']['limit']['type']='integer','limit is integer'
end
call assert found,'project.request.get advertised'
args=.directory~new; args['requestId']=bigId; args['length']=100
params['name']='project.request.get'; params['arguments']=args
req['id']=2; req['method']='tools/call'; headers['mcp-method']='tools/call'; headers['mcp-name']='project.request.get'
d=.json~fromJSON(protocol~handle(headers,.json~toJSON(req),'llm:claude')~jsonText)
call assert d['result']['isError']=.false,'get over MCP'
call assert d['result']['structuredContent']['value']['body']~length=100,'get over MCP returns page'
compat=.McpProtocolAdapter~new(service,'compat')
params['name']='project_request_get'; headers['mcp-name']='project_request_get'
d=.json~fromJSON(compat~handle(headers,.json~toJSON(req),'llm:claude')~jsonText)
call assert d['result']['isError']=.false,'compat alias project_request_get'

say 'PASS test_mailbox_bounds'
exit 0

create: procedure expose service
  use arg sender, recipient, body, subject
  a=.directory~new; a['componentId']='wire_ui_server'; a['recipientId']=recipient; a['body']=body; a['subject']=subject
  r=service~dispatch('PROJECT.REQUEST.CREATE',a,sender)
  call assert r~ok,'create' subject
  return r~value['requestId']~string

validUtf8: procedure
  use arg s
  i=1
  do while i<=s~length
    b=c2d(s~substr(i,1))
    select
      when b<128 then n=1
      when b>=194 & b<224 then n=2
      when b>=224 & b<240 then n=3
      when b>=240 & b<245 then n=4
      otherwise return 0
    end
    if i+n-1>s~length then return 0
    do k=1 to n-1
      c=c2d(s~substr(i+k,1)); if c<128 | c>=192 then return 0
    end
    i+=n
  end
  return 1

assert: procedure
  use arg condition,label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
  return

::requires 'McpProjectService.cls'
::requires 'McpProtocolAdapter.cls'
