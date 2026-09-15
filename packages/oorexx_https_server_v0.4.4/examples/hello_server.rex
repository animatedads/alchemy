/* Minimal embedding example. Invoke from this directory after setting
 * REXX_PATH to include ../rexx, ../vendor/foreign_runtime_v0.17.1/rexx and
 * the ooRexx bin directory, plus LD_LIBRARY_PATH for the native libraries. */
parse arg certificate privateKey port
if certificate='' | privateKey='' then do
  say 'usage: rexx hello_server.rex CERT.pem KEY.pem [PORT]'
  exit 2
end
if port='' then port=8443

config=.HttpsServerConfig~new
config~certificateFile=certificate
config~privateKeyFile=privateKey
config~port=port
config~bridgeDirectory='../bridge'

app=.HelloApplication~new
server=.HttpsServer~new(config)
server~route('GET','/',app,'index')
server~serve

::class HelloApplication
::method index
  use strict arg request
  return .HttpResponse~text('Hello from native ooRexx HTTPS!'||'0A'x)

::requires 'https_server.cls'
