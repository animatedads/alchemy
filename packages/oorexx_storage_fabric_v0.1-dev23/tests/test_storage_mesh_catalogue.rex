/* Discovery shares the existing StoragePeer request/response transport.
 * No new socket/RPC protocol; tests run with authenticated peer wrappers. */
root=SysTempFileName('/tmp/storage-discovery-??????')
call SysFileDelete root
call SysMkDir root
service=.StorageCommandService~new(root,'ed209c','SAFE','AZURE','ED209C')
s1=root||'/first.mp4'; s2=root||'/second.webm'
call charout s1,'First video payload'; call stream s1,'c','close'
call charout s2,'Second video payload'; call stream s2,'c','close'
r=service~addFile(s1,'first.mp4','/videos/client-a/one.mp4','media','Research clip','research'||'1E'x||'one','customer'||'1F'x||'Alpha','video/mp4')
call ok r['ok'],'first registered'
r=service~addFile(s2,'second.webm','/videos/client-b/two.webm','media','Second clip','review','','video/webm')
call ok r['ok'],'second registered'

remote=.StoragePeerService~new('ed209c')
/* Discovery is opt-in: unconfigured service refuses. */
transport=.StoragePeerInProcessTransport~new~bind('ed209c',remote)
client=.StoragePeerClient~new('ed209b',transport)
resp=client~catalogueList('ed209c')
call eq 'DISCOVERY_NOT_CONFIGURED',resp['code'],'disabled by default'
remote~configureCatalogue(service,.array~of('ed209b'))
/* A request-supplied from_node is NOT an authenticated source identity.
 * The public handle() must fail closed for catalogue discovery. */
spoof=.StoragePeerCodec~newRequest('forged','ed209b','ed209c',.StoragePeerOperation~CATALOGUE_LIST)
spoof['query']=''; spoof['offset']=0; spoof['limit']=1
rejected=remote~handle(spoof)
call eq 'AUTHENTICATED_PEER_REQUIRED',rejected['code'],'unauthenticated direct handler rejected'
resp=client~catalogueList('ed209c','',0,1)
call eq 'OK',resp['status'],'page accepted'
p=resp['payload']
call eq 1,p['items']~items,'one page item'
call ok p['more'],'pagination reports more'
call eq 2,service~objects~items,'source catalogue unchanged'
first=p['items'][1]
call ok first['paths']~items>0,'projected namespace metadata'
call ok first['locations']~items>0,'projected location info'
call ok \first['locations'][1]~hasIndex('locator'),'do not leak physical path'
rev=p['revision']
resp2=client~catalogueList('ed209c','',1,1,rev)
call eq 'OK',resp2['status'],'pinned page revision valid'
call eq 1,resp2['payload']['items']~items,'second page item'
call ok \resp2['payload']['more'],'pagination reached end'
respBad=client~catalogueList('ed209c','',1,1,rev+1)
call eq 'REVISION_CHANGED',respBad['code'],'revision changed fails closed'
resp=client~catalogueLocate('ed209c','/videos/client-a/one.mp4')
call eq 'OK',resp['status'],'locate by virtual path'
call eq 'first.mp4',resp['payload']['items'][1]['name'],'locate identifies file'
resp=client~catalogueList('ed209c','Research',0,50)
call eq 1,resp['payload']['items']~items,'search extended attribute'
resp=client~catalogueList('ed209c','client-b',0,50)
call eq 1,resp['payload']['items']~items,'search virtual path'
resp=client~catalogueLocate('ed209c','/no/such/file')
call eq 'NOT_FOUND',resp['code'],'not found explicit'
other=.StoragePeerClient~new('ed209f',transport)
resp=other~catalogueList('ed209c')
call eq 'DISCOVERY_NOT_AUTHORISED',resp['code'],'unapproved peer rejected'
req=.StoragePeerCodec~newRequest('injected','ed209b','ed209c',.StoragePeerOperation~CATALOGUE_LIST)
req['query']='';req['offset']=0;req['limit']=1
resp=remote~handleFrom('ed209f',req)
call eq 'PEER_IDENTITY_MISMATCH',resp['code'],'mismatched authenticated peer rejected'

say 'PASS Storage mesh catalogue auth/pagination/find/locate/metadata/redaction'
exit 0
::routine eq
  use arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    raise syntax 88.900 array('assertion failed')
  end
::routine ok
  use arg truth,label
  if \truth then do
    say 'FAIL' label
    raise syntax 88.900 array('assertion failed')
  end
::requires 'StorageCommand.cls'
