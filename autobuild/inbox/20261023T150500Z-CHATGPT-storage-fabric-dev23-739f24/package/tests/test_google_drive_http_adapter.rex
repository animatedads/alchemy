auth=.GoogleDriveTestAuthProvider~new('secret-bearer-fixture')
http=.FakeHttpExecutor~new
adapter=.GoogleDriveApiAdapter~new(http,auth,'google-drive:test','https://api.example/drive/v3','https://upload.example/drive/v3')

h=.directory~new; h['location']='https://upload.example/session-secret-123'
http~enqueue(.FakeHttpResponse~new(200,h,''))
s=adapter~startUpload('root','bodycam "one".mp4','video/mp4',300000)
call assertTrue s<>.nil,'session created'
call assertEq 0,s~nextOffset,'session starts zero'
call assertTrue http~authSeen,'bearer seen by executor'
call assertEq 1,auth~acquisitions,'one auth acquisition'
call assertEq 1,auth~retirements,'lease retired after initiation'
call assertTrue pos('session-secret',http~requestUrl(1))=0,'init URL is not session capability'
call assertTrue pos('bodycam \"one\".mp4',http~requestBody(1))>0,'metadata JSON escaped'
call assertTrue http~requestHeaders(1)~at('authorization')==.nil,'authorization removed from retained request headers'

h2=.directory~new; h2['range']='bytes=0-262143'
http~enqueue(.FakeHttpResponse~new(308,h2,''))
r1=adapter~uploadChunk(s,0,copies('A',262144))
call assertTrue r1~ok,'first chunk accepted'
call assertEq 262144,r1~nextOffset,'server Range controls offset'
call assertFalse r1~completed,'first chunk not complete'
call assertEq 'bytes 0-262143/300000',http~requestHeaders(2)~at('content-range'),'chunk Content-Range'

sha=copies('a',64)
body='{"id":"drive-file-123","sha256Checksum":"'||sha||'","md5Checksum":"'||copies('b',32)||'","modifiedTime":"2026-09-06T10:00:00Z"}'
http~enqueue(.FakeHttpResponse~new(200,.directory~new,body))
r2=adapter~uploadChunk(s,262144,copies('B',37856))
call assertTrue r2~ok,'final chunk accepted'
call assertTrue r2~completed,'final response complete'
call assertEq 300000,s~nextOffset,'complete offset'
call assertEq 'drive-file-123',s~remoteFileId,'remote id parsed'
call assertEq sha,s~remoteSha256,'sha256 parsed'

rangeData='00'x||copies('R',1022)||'ff'x||'0a'x
http~enqueue(.FakeHttpResponse~new(206,.directory~new,rangeData))
d=adapter~downloadRange('drive-file-123',1000,length(rangeData),5000)
call assertTrue d~ok,'range download accepted'
call assertEq rangeData,d~data,'binary range body preserved'
call assertEq 'bytes=1000-'||(1000+length(rangeData)-1),http~requestHeaders(4)~at('range'),'Range header'

call assertEq auth~acquisitions,auth~retirements,'all auth leases retired'
do i=1 to http~requestCount
  call assertTrue http~requestHeaders(i)~at('authorization')==.nil,'no retained bearer header request '||i
end
say 'PASS Google Drive HTTP/auth/resumable/range adapter'
exit 0

::class FakeHttpResponse public
::attribute status get
::attribute headers get
::attribute body get
::attribute errorCode get
::method init
  expose status headers body errorCode
  use arg statusArg=0,headersArg=.nil,bodyArg='',errorArg=''
  status=statusArg+0; if headersArg==.nil then headers=.directory~new; else headers=headersArg
  body=bodyArg; errorCode=errorArg~string

::class FakeHttpExecutor subclass StorageHttpExecutor public
::attribute requestCount get
::attribute authSeen get
::method init
  expose planned requests requestCount authSeen
  planned=.queue~new; requests=.array~new; requestCount=0; authSeen=.false
::method enqueue
  expose planned
  use arg response
  planned~queue(response); return self
::method execute
  expose planned requests requestCount authSeen
  use arg methodArg,urlArg,headersArg=.nil,bodyArg='',trafficArg=''
  requestCount+=1
  rec=.directory~new; rec['method']=methodArg; rec['url']=urlArg; rec['headers']=headersArg; rec['body']=bodyArg; rec['traffic']=trafficArg
  if headersArg~at('authorization')<>.nil then authSeen=.true
  requests~append(rec)
  if planned~items=0 then return .FakeHttpResponse~new(0,.nil,'','NO_PLANNED_RESPONSE')
  return planned~pull
::method requestUrl
  expose requests
  use arg i
  return requests[i]['url']
::method requestBody
  expose requests
  use arg i
  return requests[i]['body']
::method requestHeaders
  expose requests
  use arg i
  return requests[i]['headers']

::routine assertTrue
  use arg value,label
  if \value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertFalse
  use arg value,label
  if value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label 'expected='expected 'actual='actual; raise syntax 88.900 array('test assertion failed'); end
::requires "src/StorageGoogleDrive.cls"
