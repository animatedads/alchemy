/* ooRexx native host: file-watcher, durable journal, HTTP transport.
   Needs Alchemy oorexx_https_server/rexx/https_server.cls in REXX_PATH. */
parse arg root port
if root='' then root=directory()
if port='' then port=8765

eventSource=.EventSource~new('event-continuation')
coordinator=.ContinuationCoordinator~new(root||'/state/events.journal',eventSource)
config=.HttpsServerConfig~new
config~transportMode='HTTP'
config~bindAddress='127.0.0.1'
config~port=port
config~connectionWorkers=6
config~maxPendingConnections=16
config~readTimeout=30
config~maxBodyBytes=4096
config~accessLog=.false

routes=.ContinuationRoutes~new(root,port,coordinator)
server=.HttpsServer~new(config)
server~route('GET','/',routes,'index')
server~route('GET','/browser.rex',routes,'browser')
server~route('GET','/ooRexx.js',routes,'wasmFile')
server~route('GET','/ooRexx-worker.js',routes,'wasmFile')
server~route('GET','/rexx.js',routes,'wasmFile')
server~route('GET','/rexx.wasm',routes,'wasmFile')
server~route('GET','/rexx.data',routes,'wasmFile')
server~route('GET','/js-realm.js',routes,'wasmFile')
server~route('GET','/polygon-clipping.umd.min.js',routes,'wasmFile')
server~route('GET','/api/next',routes,'next')
server~route('GET','/api/health',routes,'health')
server~route('POST','/api/register',routes,'register')
server~route('POST','/api/claim',routes,'claim')
server~route('POST','/api/received',routes,'received')
server~route('POST','/api/complete',routes,'complete')
server~route('POST','/api/demo/create',routes,'createFlag')
server~route('POST','/api/demo/remove',routes,'removeFlag')

/* The on-machine ticker is separate from the HTTP worker pool. */
monitor=coordinator~start('run')
say 'EVENT_CONTINUATION_READY http://127.0.0.1:'||port||'/'
server~serve
exit 0

::class ContinuationRoutes
::method init
  expose root port coordinator
  use strict arg root,port,coordinator

::method secure
  use strict arg response
  response~header('Cache-Control','no-store')
  response~header('X-Content-Type-Options','nosniff')
  response~header('Cross-Origin-Opener-Policy','same-origin')
  response~header('Cross-Origin-Embedder-Policy','require-corp')
  response~header('Cross-Origin-Resource-Policy','same-origin')
  return response

::method sameOrigin
  expose port
  use strict arg request
  origin=request~header('origin','')
  return origin=='http://127.0.0.1:'||port

::method file
  expose root
  use strict arg relative,contentType
  path=root||'/'||relative
  if stream(path,'C','QUERY EXISTS')='' then return self~secure(.HttpResponse~text('missing asset',404))
  call stream path,'C','OPEN READ'
  count=chars(path)
  if count<0 then do
    call stream path,'C','CLOSE'
    return self~secure(.HttpResponse~text('unreadable asset',500))
  end
  content=charin(path,1,count)
  call stream path,'C','CLOSE'
  return self~secure(.HttpResponse~new(200,content,contentType))

::method index
  use strict arg request
  return self~file('web/index.html','text/html; charset=utf-8')

::method browser
  use strict arg request
  return self~file('web/browser.rex','text/plain; charset=utf-8')

::method wasmFile
  use strict arg request
  path=request~path~substr(2)
  select
    when path='rexx.wasm' then mime='application/wasm'
    when path='rexx.data' then mime='application/octet-stream'
    otherwise mime='text/javascript; charset=utf-8'
  end
  return self~file('assets/'||path,mime)

::method health
  use strict arg request
  return self~secure(.HttpResponse~text('event.continuation/0.1 OK'))

/* Bounded long poll. ooRexx keeps watching; browser gets the next event
   promptly without polling the file or holding an LLM request open. */
::method next unguarded
  expose coordinator
  use strict arg request
  do i=1 to 80
    ev=coordinator~next
    if ev<>.nil then return self~secure(.HttpResponse~text(ev~wire))
    call SysSleep .25
  end
  return self~secure(.HttpResponse~empty(204))

::method register
  expose coordinator root
  use strict arg request
  if \self~sameOrigin(request) then return self~secure(.HttpResponse~text('forbidden',403))
  if request~body~strip<>'WATCH-READY' then return self~secure(.HttpResponse~text('unrecognised demo watch',400))
  watch=.ContinuationWatch~new('WATCH-READY','FILE_EXISTS',root||'/input/ready.flag', -
    'rasen-falcon','Hey, to remind you. You just had your file created.')
  coordinator~addWatch(watch)
  return self~secure(.HttpResponse~text('REGISTERED'))

::method claim
  expose coordinator
  use strict arg request
  if \self~sameOrigin(request) then return self~secure(.HttpResponse~text('forbidden',403))
  body=request~body
  parse var body id '09'x owner
  if \coordinator~claim(id,owner) then return self~secure(.HttpResponse~text('lease conflict',409))
  return self~secure(.HttpResponse~text('CLAIMED'))

::method received
  expose coordinator
  use strict arg request
  if \self~sameOrigin(request) then return self~secure(.HttpResponse~text('forbidden',403))
  body=request~body
  parse var body id '09'x owner
  if \coordinator~receive(id,owner) then return self~secure(.HttpResponse~text('no active lease',409))
  return self~secure(.HttpResponse~text('RECEIVED'))

::method complete
  expose coordinator
  use strict arg request
  if \self~sameOrigin(request) then return self~secure(.HttpResponse~text('forbidden',403))
  body=request~body
  parse var body id '09'x owner
  if \coordinator~complete(id,owner) then return self~secure(.HttpResponse~text('not received or lease expired',409))
  return self~secure(.HttpResponse~text('COMPLETED'))

::method createFlag
  expose root
  use strict arg request
  if \self~sameOrigin(request) then return self~secure(.HttpResponse~text('forbidden',403))
  path=root||'/input/ready.flag'
  call lineout path,'A local file appeared.'
  call stream path,'C','CLOSE'
  return self~secure(.HttpResponse~text('CREATED'))

::method removeFlag
  expose root
  use strict arg request
  if \self~sameOrigin(request) then return self~secure(.HttpResponse~text('forbidden',403))
  path=root||'/input/ready.flag'
  if stream(path,'C','QUERY EXISTS')<>'' then call SysFileDelete path
  return self~secure(.HttpResponse~text('REMOVED'))

::requires 'ContinuationCore.cls'
::requires 'EventRuntime.cls'
::requires 'https_server.cls'
