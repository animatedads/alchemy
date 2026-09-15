parse source . . sourceFile
scriptDir=filespec('D',sourceFile)||filespec('P',sourceFile)
root=scriptDir'..'

config=.HttpsServerConfig~new
config~bridgeDirectory=root'/bridge'

command=arg(1)
if command='' then command=''
cert=''
key=''
clientCA=''
requireClient=.false
bind='127.0.0.1'
port=8443
quiet=.false
nativeConcurrency=1
workers=16
pending=64

rest=command
/* Command-line parser intentionally accepts simple non-space paths. */
do while rest~strip<>''
  rest=rest~strip
  token=rest~word(1)
  rest=rest~subword(2)
  select
    when token='--cert' then do; cert=rest~word(1); rest=rest~subword(2); end
    when token='--key' then do; key=rest~word(1); rest=rest~subword(2); end
    when token='--bind' then do; bind=rest~word(1); rest=rest~subword(2); end
    when token='--port' then do; port=rest~word(1); rest=rest~subword(2); end
    when token='--client-ca' then do; clientCA=rest~word(1); rest=rest~subword(2); end
    when token='--require-client-cert' then requireClient=.true
    when token='--quiet' then quiet=.true
    when token='--native-concurrency' then do; nativeConcurrency=rest~word(1); rest=rest~subword(2); end
    when token='--workers' then do; workers=rest~word(1); rest=rest~subword(2); end
    when token='--pending' then do; pending=rest~word(1); rest=rest~subword(2); end
    when token='--help' | token='-h' then do; call usage; exit 0; end
    otherwise do
      say 'Unknown option:' token
      call usage
      exit 2
    end
  end
end

if cert='' | key='' then do
  call usage
  exit 2
end

config~certificateFile=cert
config~privateKeyFile=key
config~bindAddress=bind
config~port=port
config~clientCAFile=clientCA
config~requireClientCertificate=requireClient
config~accessLog=\quiet
config~nativeTlsConcurrency=nativeConcurrency
config~connectionWorkers=workers
config~maxPendingConnections=pending

app=.DemoApp~new
server=.HttpsServer~new(config)
server~route('GET','/',app,'home')
server~route('GET','/healthz',app,'health')
server~route('POST','/echo',app,'echo')
server~route('HEAD','/',app,'home')
server~serve
exit 0

usage:
  say 'usage: rexx https_server.rex --cert CERT.pem --key KEY.pem [--bind ADDRESS] [--port PORT] [--client-ca CA.pem] [--require-client-cert] [--native-concurrency 1] [--workers 16] [--pending 64] [--quiet]'
  return

::class DemoApp
::method home
  use strict arg request
  body='ooRexx HTTPS server' || '0A'x
  return .HttpResponse~text(body)

::method health
  use strict arg request
  return .HttpResponse~json('{"status":"ok","server":"oorexx-https/0.4.4"}')

::method echo
  use strict arg request
  contentType=request~header('content-type','application/octet-stream')
  return .HttpResponse~new(200,request~body,contentType)

::requires 'https_server.cls'
