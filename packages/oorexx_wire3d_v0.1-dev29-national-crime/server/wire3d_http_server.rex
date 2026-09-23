/* Wire3D development/projector server. Uses ooRexx HTTPS Server in HTTP mode. */
parse arg root port
if root='' then root=directory()
if port='' then port=8080

config=.HttpsServerConfig~new
config~transportMode='HTTP'
config~bindAddress='127.0.0.1'
config~port=port
config~connectionWorkers=4
config~maxPendingConnections=16
config~accessLog=.true

static=.Wire3DStaticRoutes~new(root)
server=.HttpsServer~new(config)
server~route('GET','/',static,'index')
server~route('GET','/index.html',static,'index')
server~route('GET','/wire3d.js',static,'renderer')
server~route('GET','/wire3d-live.js',static,'liveRenderer')
server~route('GET','/scene.json',static,'scene')
server~route('GET','/health',static,'health')
server~route('GET','/national-crime.html',static,'nationalCrimeHtml')
server~route('GET','/national-crime.js',static,'nationalCrimeJs')
server~route('GET','/national-crime.geojson',static,'nationalCrimeGeojson')
server~route('GET','/national-crime-summary.json',static,'nationalCrimeSummary')
server~route('GET','/stop-search.json',static,'stopSearch')
server~route('GET','/bua-2024.geojson',static,'buaGeojson')
server~route('GET','/wards-historic.geojson',static,'wardGeojson')
server~route('GET','/assets/demo-interview.wav',static,'asset')
do i=1 to 7
  server~route('GET','/assets/people/subject-'right(i,2,'0')'.png',static,'asset')
  server~route('GET','/resource/person/CE-'right(i,3,'0')'/headshot',static,'asset')
end
say 'WIRE3D_HTTP_START root='root' requestedPort='port
server~serve
exit 0

::class Wire3DStaticRoutes
::method init
  expose root
  use strict arg root
::method file private
  expose root
  use strict arg relative, contentType
  path=root||'/'||relative
  state=stream(path,'S')
  if state=='' then return .HttpResponse~text('not found',404)
  call stream path,'C','OPEN READ'
  size=chars(path)
  if size<0 then do; call stream path,'C','CLOSE'; return .HttpResponse~text('not found',404); end
  body=charin(path,1,size)
  call stream path,'C','CLOSE'
  return .HttpResponse~new(200,body,contentType)~header('Cache-Control','no-store')
::method index
  use strict arg request
  return self~file('index.html','text/html; charset=utf-8')
::method renderer
  use strict arg request
  return self~file('wire3d.js','text/javascript; charset=utf-8')
::method liveRenderer
  use strict arg request
  return self~file('wire3d-live.js','text/javascript; charset=utf-8')
::method scene
  use strict arg request
  return self~file('scene.json','application/json; charset=utf-8')
::method asset
  use strict arg request
  path=request~path
  if path=='/assets/demo-interview.wav' then return self~file('assets/demo-interview.wav','audio/wav')
  if path~left(23)=='/assets/people/subject-' & path~right(4)=='.png' then return self~file(path~substr(2),'image/png')
  if path~left(20)=='/resource/person/CE-' & path~right(9)=='/headshot' then do
    ref=path~substr(21,3); n=ref+0
    if n>=1 & n<=7 then return self~file('assets/people/subject-'right(n,2,'0')'.png','image/png')
  end
  return .HttpResponse~text('not found',404)

::method nationalCrimeHtml
  use strict arg request
  return self~file('national-crime.html','text/html; charset=utf-8')
::method nationalCrimeJs
  use strict arg request
  return self~file('national-crime.js','text/javascript; charset=utf-8')
::method nationalCrimeGeojson
  use strict arg request
  return self~file('national-crime.geojson','application/geo+json; charset=utf-8')
::method nationalCrimeSummary
  use strict arg request
  return self~file('national-crime-summary.json','application/json; charset=utf-8')
::method stopSearch
  use strict arg request
  return self~file('stop-search.json','application/json; charset=utf-8')
::method buaGeojson
  use strict arg request
  return self~file('bua-2024.geojson','application/geo+json; charset=utf-8')
::method wardGeojson
  use strict arg request
  return self~file('wards-historic.geojson','application/geo+json; charset=utf-8')

::method health
  use strict arg request
  return .HttpResponse~text('WIRE3D HTTP OK')

::requires 'https_server.cls'
