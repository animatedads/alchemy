parse source . . here
pkg=filespec('location',here)
path='/tmp/oorexx_mcp_test_journal.jsonl'
call SysFileDelete path
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectJsonlJournal~new(path))
a=.directory~new; a['componentId']='wire_ui_server'; a['recipientId']='llm:bob'; a['body']='first'
r=service~dispatch('PROJECT.REQUEST.CREATE',a,'architect')
call assert r~ok,'first durable request'
id1=r~value['requestId']~string
claim=.directory~new; claim['componentId']='wire_ui_server'
r=service~dispatch('PROJECT.OWNERSHIP.CLAIM',claim,'llm:bob')
call assert r~ok & r~code='OWNERSHIP_CLAIMED','durable ownership claim'
release=.directory~new; release['componentId']='wire_ui_server'; release['reason']='restart qualification'
r=service~dispatch('PROJECT.OWNERSHIP.RELEASE',release,'llm:bob')
call assert r~ok & r~code='OWNERSHIP_RELEASED','durable ownership release'
service2=.McpProjectWireService~new(catalog,.McpProjectJsonlJournal~new(path))
r=service2~dispatch('PROJECT.OWNERSHIP.CLAIM',claim,'llm:alice')
call assert r~ok & r~code='OWNERSHIP_CLAIMED','released component is claimable after restart'
a['body']='second'
r=service2~dispatch('PROJECT.REQUEST.CREATE',a,'architect')
call assert r~ok,'second request after restart'
id2=r~value['requestId']~string
call assert id1<>id2,'ids do not collide after journal replay'
service3=.McpProjectWireService~new(catalog,.McpProjectJsonlJournal~new(path))
r=service3~dispatch('PROJECT.REQUESTS.LIST',.directory~new,'architect')
call assert r~ok & r~value['count']=2,'both requests survive second restart'
r=service3~dispatch('PROJECT.OWNERSHIP.CLAIM',claim,'llm:bob')
call assert \r~ok & r~code='OWNERSHIP_CONFLICT','post-release replacement owner survives restart'
r=service3~dispatch('PROJECT.OWNERSHIP.RELEASE',release,'llm:alice')
call assert r~ok & r~code='OWNERSHIP_RELEASED','replacement owner can release after restart'
call SysFileDelete path
say 'PASS test_jsonl_restart'
exit 0
assert: procedure
 use arg c,l
 if \c then do; say 'FAIL:' l; exit 1; end
 return
::requires 'McpProjectService.cls'
