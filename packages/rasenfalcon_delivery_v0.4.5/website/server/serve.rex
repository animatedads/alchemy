/* Rasen Falcon public-preview adapter to the owned ooRexx HTTPS Server v0.4.7.
 * Bind to loopback only. Multi-host production requires RF-008/RF-010 SNI
 * and hostname authority qualification in the owning HTTPS server.
 * Required: REXX_PATH must contain oorexx_https_server_v0.4.7/rexx and
 * its pinned Foreign Runtime v0.17.1 dependency (see package README).
 */
parse arg certificate privateKey port
if certificate='' | privateKey='' then do
  say 'usage: rexx server/serve.rex CERT.pem KEY.pem [PORT]'
  exit 2
end
if port='' then port=8443
if \datatype(port,'W') then do
  say 'invalid port'
  exit 2
end
if port<1024 | port>65535 then do
  say 'port outside preview range'
  exit 2
end
parse source . . sourceFile
scriptDirectory=filespec('D',sourceFile)||filespec('P',sourceFile)
siteRoot=scriptDirectory||'../site/'
if stream(siteRoot||'build-manifest.json','C','QUERY EXISTS')='' then do
  say 'missing compiled site; run python3 tools/site.py build'
  exit 2
end
config=.HttpsServerConfig~new
config~certificateFile=certificate
config~privateKeyFile=privateKey
config~bindAddress='127.0.0.1'
config~port=port
bridgeDir=value('RF_HTTPS_BRIDGE_DIR',,'ENVIRONMENT')
if bridgeDir='' then do
  say 'RF_HTTPS_BRIDGE_DIR must identify the installed HTTPS/OpenSSL bridge definitions'
  exit 2
end
config~bridgeDirectory=bridgeDir
config~connectionWorkers=4
config~maxPendingConnections=16
app=.RasenSite~new(siteRoot)
server=.HttpsServer~new(config)
server~route('GET','/',app,'home')
server~route('GET','/index.html',app,'home')
server~route('HEAD','/',app,'home')
server~route('GET','/alchemy/',app,'alchemy')
server~route('GET','/alchemy/index.html',app,'alchemy')
server~route('GET','/visualisation/',app,'visualisation')
server~route('GET','/visualisation/index.html',app,'visualisation')
server~route('GET','/audio-analysis/',app,'audio')
server~route('GET','/audio-analysis/index.html',app,'audio')
server~route('GET','/video-analysis/',app,'video')
server~route('GET','/video-analysis/index.html',app,'video')
server~route('GET','/secure-protocols/',app,'protocols')
server~route('GET','/secure-protocols/index.html',app,'protocols')
server~route('GET','/intelligent-software/',app,'intelligence')
server~route('GET','/intelligent-software/index.html',app,'intelligence')
server~route('GET','/contact/',app,'contact')
server~route('GET','/contact/index.html',app,'contact')
server~route('GET','/privacy/',app,'privacy')
server~route('GET','/privacy/index.html',app,'privacy')
server~route('GET','/assets/site.css',app,'css')
server~route('GET','/assets/site.js',app,'js')
server~route('GET','/assets/favicon.svg',app,'favicon')
server~route('GET','/robots.txt',app,'robots')
server~route('GET','/sitemap.xml',app,'sitemap')
server~route('GET','/healthz',app,'health')
server~serve
exit 0

::class RasenSite
::method init
  expose root
  use strict arg root
::method send
  expose root
  use strict arg fixedPath,mime
  path=root||fixedPath
  if stream(path,'C','QUERY EXISTS')='' then return .HttpResponse~text('Not Found',404)
  call stream path,'C','OPEN READ'
  size=stream(path,'C','QUERY SIZE')
  if size<0 then return .HttpResponse~text('Unable to read',500)
  body=charin(path,1,size)
  call stream path,'C','CLOSE'
  response=.HttpResponse~new(200,body,mime)
  response~header('X-Content-Type-Options','nosniff')
  response~header('X-Frame-Options','DENY')
  response~header('Referrer-Policy','strict-origin-when-cross-origin')
  response~header('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'")
  return response
::method home
  use strict arg request
  return self~send('index.html','text/html; charset=utf-8')
::method alchemy
  use strict arg request
  return self~send('alchemy/index.html','text/html; charset=utf-8')
::method visualisation
  use strict arg request
  return self~send('visualisation/index.html','text/html; charset=utf-8')
::method audio
  use strict arg request
  return self~send('audio-analysis/index.html','text/html; charset=utf-8')
::method video
  use strict arg request
  return self~send('video-analysis/index.html','text/html; charset=utf-8')
::method protocols
  use strict arg request
  return self~send('secure-protocols/index.html','text/html; charset=utf-8')
::method intelligence
  use strict arg request
  return self~send('intelligent-software/index.html','text/html; charset=utf-8')
::method contact
  use strict arg request
  return self~send('contact/index.html','text/html; charset=utf-8')
::method privacy
  use strict arg request
  return self~send('privacy/index.html','text/html; charset=utf-8')
::method css
  use strict arg request
  return self~send('assets/site.css','text/css; charset=utf-8')
::method js
  use strict arg request
  return self~send('assets/site.js','text/javascript; charset=utf-8')
::method favicon
  use strict arg request
  return self~send('assets/favicon.svg','image/svg+xml')
::method robots
  use strict arg request
  return self~send('robots.txt','text/plain; charset=utf-8')
::method sitemap
  use strict arg request
  return self~send('sitemap.xml','application/xml; charset=utf-8')
::method health
  use strict arg request
  return .HttpResponse~json('{"status":"ok","service":"rasenfalcon-preview","runtime":"oorexx-https/0.4.7"}')
::requires 'https_server.cls'
