parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
journal=.McpProjectMemoryJournal~new
service=.McpProjectWireService~new(catalog,journal)

call assert catalog~has('wire_ui_server'), 'wire component exists'

args=.directory~new
args['componentId']='wire_ui_server'; args['recipientId']='llm:bob'; args['subject']='Check renderer seam'; args['body']='Please review the renderer boundary.'
r=service~dispatch('PROJECT.REQUEST.CREATE',args,'architect')
call assert r~ok, 'request create'
req=r~value; rid=req['requestId']~string
call assert req['rootRequestId']~string=rid, 'root request self'

listArgs=.directory~new; listArgs['unreadOnly']=.true
r=service~dispatch('PROJECT.REQUESTS.LIST',listArgs,'llm:bob')
call assert r~ok & r~value['count']=1, 'recipient sees unread request'

readArgs=.directory~new; readArgs['requestId']=rid
r=service~dispatch('PROJECT.REQUEST.MARK_READ',readArgs,'llm:bob')
call assert r~ok, 'mark read'
r=service~dispatch('PROJECT.REQUESTS.LIST',listArgs,'llm:bob')
call assert r~ok & r~value['count']=0, 'unread cleared without mutating request'

replyArgs=.directory~new; replyArgs['requestId']=rid; replyArgs['body']='Reviewed; I will own the component.'
r=service~dispatch('PROJECT.REQUEST.REPLY',replyArgs,'llm:bob')
call assert r~ok, 'reply create'
reply=r~value
call assert reply['parentRequestId']~string=rid, 'reply parent'
call assert reply['rootRequestId']~string=rid, 'reply root'
call assert reply['recipientId']~string='architect', 'reply reverses recipient by default'

claim=.directory~new; claim['componentId']='wire_ui_server'; claim['claimRequestId']=reply['requestId']
r=service~dispatch('PROJECT.OWNERSHIP.CLAIM',claim,'llm:bob')
call assert r~ok & r~code='OWNERSHIP_CLAIMED', 'claim ownership'
r=service~dispatch('PROJECT.OWNERSHIP.CLAIM',claim,'llm:bob')
call assert r~ok & r~code='ALREADY_OWNED_BY_CALLER', 'idempotent reclaim'
r=service~dispatch('PROJECT.OWNERSHIP.CLAIM',claim,'llm:alice')
call assert \r~ok & r~code='OWNERSHIP_CONFLICT', 'ownership conflict'

missing=.directory~new; missing['componentId']='not_real'; missing['recipientId']='llm:bob'; missing['body']='x'
r=service~dispatch('PROJECT.REQUEST.CREATE',missing,'architect')
call assert \r~ok & r~code='COMPONENT_NOT_FOUND', 'unknown component rejected'

r=service~dispatch('PROJECT.REQUESTS.LIST',.directory~new,'')
call assert \r~ok & r~code='AUTHENTICATED_PRINCIPAL_REQUIRED', 'anonymous request read rejected'

/* Replay proves append-only journal reconstructs the same coordination state. */
service2=.McpProjectWireService~new(catalog,journal)
r=service2~dispatch('PROJECT.REQUESTS.LIST',.directory~new,'architect')
call assert r~ok & r~value['count']=2, 'journal replay preserves request chain'
r=service2~dispatch('PROJECT.OWNERSHIP.CLAIM',claim,'llm:alice')
call assert \r~ok & r~code='OWNERSHIP_CONFLICT', 'journal replay preserves ownership'

/* Unowned components have durable component mailboxes; the eventual owner inherits visibility. */
mail=.directory~new; mail['componentId']='oorexx_https_server'; mail['body']='Please inspect HTTPS MCP admission.'
r=service~dispatch('PROJECT.REQUEST.CREATE',mail,'architect')
call assert r~ok & r~value['recipientId']~string='component:oorexx_https_server','unowned component mailbox request'
mailId=r~value['requestId']~string
claim2=.directory~new; claim2['componentId']='oorexx_https_server'
r=service~dispatch('PROJECT.OWNERSHIP.CLAIM',claim2,'llm:https')
call assert r~ok,'claim previously unowned component'
r=service~dispatch('PROJECT.REQUESTS.LIST',.directory~new,'llm:https')
call assert r~ok & r~value['count']=1,'new owner sees component mailbox request'

say 'PASS test_project_service'
exit 0

assert: procedure
  use arg condition,label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
  return

::requires 'McpProjectService.cls'
