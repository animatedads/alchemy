parse arg certificate privateKey port
config=.HttpsServerConfig~new
config~certificateFile=certificate
config~privateKeyFile=privateKey
config~port=port
config~bindAddress='127.0.0.1'
config~bridgeDirectory='../bridge'
config~accessLog=.false
app=.FaultApp~new
server=.HttpsServer~new(config)
server~route('GET','/boom',app,'boom')
server~route('GET','/ok',app,'ok')
server~serve

::class FaultApp
::method boom
  use strict arg request
  raise syntax 40.900 array('intentional handler failure')
::method ok
  use strict arg request
  return .HttpResponse~text('ok')
::requires 'https_server.cls'
