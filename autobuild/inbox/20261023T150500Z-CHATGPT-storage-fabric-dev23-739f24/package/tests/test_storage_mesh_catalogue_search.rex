/* Authenticated multi-peer discovery: no global transaction and no fake OK. */
root=SysTempFileName('/tmp/storage-fanout-??????')
call SysFileDelete root
call SysMkDir root
s1=.StorageCommandService~new(root,'ed209c','SAFE','AZURE','ED209C')
f=root||'/clip.webm'
call charout f,'Initech testing bytes'
call stream f,'c','close'
r=s1~addFile(f,'clip.webm','/customers/initech/tps/clip.webm','media','Initech video','', '', 'video/webm')
call require r['ok'],'add fixture'
s2=.StorageCommandService~new(root||'/second','ed209d','SAFE','AWS','ED209D')
/* No writes to s2: exercise empty authoritative page. */
t=.StoragePeerInProcessTransport~new
sc=.StoragePeerService~new('ed209c')
sd=.StoragePeerService~new('ed209d')
sc~configureCatalogue(s1,.array~of('ed209b'))
sd~configureCatalogue(s2,.array~of('ed209b'))
t~bind('ed209c',sc)
t~bind('ed209d',sd)
client=.StoragePeerClient~new('ed209b',t)
searcher=.StorageMeshCatalogueSearch~new(client,.array~of('ed209c','ed209d'))
found=searcher~search('Initech',1,3)
call require found['complete'],'two peers report complete'
call require found['record_count']=1,'only one real match'
call require found['records'][1]['node_id']='ed209c','origin retained'
call require found['coverage']['ed209d']['accepted']=0,'empty peer reported'
/* Refusal and missing peer must never be reported as a complete view. */
blocked=.StoragePeerClient~new('ed209f',t)
partial=.StorageMeshCatalogueSearch~new(blocked,.array~of('ed209c','ed209x'))~search('',1,2)
call require \partial['complete'],'failed peers mark partial'
call require partial['coverage']['ed209c']['code']='DISCOVERY_NOT_AUTHORISED','ACL denials retained'
call require partial['coverage']['ed209x']['code']='UNREACHABLE','missing MU retained'
/* First peer has one record: page size 1 completes. A zero-page cap is invalid. */
call require found['coverage']['ed209c']['revision']<>.nil,'revision retained'
/* Four records creates a bounded-truncation refusal with pageSize=1. */
do k=1 to 2
  f2=root||'/clip-'||k||'.webm'
  call charout f2,'Initech testing bytes '||k
  call stream f2,'c','close'
  r=s1~addFile(f2,'clip-'||k||'.webm','/customers/initech/tps/clip-'||k||'.webm','media','Initech', '', '', 'video/webm')
  call require r['ok'],'extra binding registered'
end
truncated=searcher~search('',1,1)
call require \truncated['complete'],'bounded search marks incomplete'
call require truncated['coverage']['ed209c']['code']='TRUNCATED','bounded page is not a full search'
call require truncated['record_count']=0,'partial node discarded not returned'
/* Mutated second-page revision refuses stale aggregation. */
unstable=.StoragePeerClient~new('ed209b',.RevisionTamperTransport~new(t))
inconsistent=.StorageMeshCatalogueSearch~new(unstable,.array~of('ed209c'))~search('',1,8)
call require \inconsistent['complete'],'revision shift marks incomplete'
call require inconsistent['coverage']['ed209c']['code']='REVISION_CHANGED','mid-query revision rejected'
call require inconsistent['record_count']=0,'no partial records after revision shift'
/* Lying about the origin must never poison the merged catalogue. */
lying=.StoragePeerClient~new('ed209b',.OriginTamperTransport~new(t))
invalid=.StorageMeshCatalogueSearch~new(lying,.array~of('ed209c'))~search('',1,8)
call require \invalid['complete'],'bad origin marks incomplete'
call require invalid['coverage']['ed209c']['code']='INVALID_RESPONSE','peer origin checked'
say 'PASS Storage mesh catalogue fanout / origin / ACL denial / unreachable / truncation'
exit 0
require: procedure
  use strict arg truth,msg
  if truth then return
  say 'FAIL' msg
  exit 1
::requires 'StorageCommand.cls'
::requires 'StorageMeshCatalogueSearch.cls'

::class RevisionTamperTransport
::method init
  expose inner
  use strict arg inner
::method request
  expose inner
  use strict arg peer,req
  r=inner~request(peer,req)
  if req['offset']>0 then r['payload']['revision']+=1
  return r
::class OriginTamperTransport
::method init
  expose inner
  use strict arg inner
::method request
  expose inner
  use strict arg peer,req
  r=inner~request(peer,req)
  r['payload']['node_id']='wrong-node'
  return r
