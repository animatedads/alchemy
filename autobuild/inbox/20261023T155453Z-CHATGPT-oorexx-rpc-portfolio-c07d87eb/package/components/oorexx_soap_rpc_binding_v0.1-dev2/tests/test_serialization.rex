checks=0
call registerSoapSerialization
call check .SerializationSelector~registered('soap-xml-request'), 'request SOAP codec registered'
call check .SerializationSelector~registered('soap-xml-response'), 'response SOAP codec registered'
registry=.RpcServiceRegistry~new
registry~register('catalog','echo',.Echo~new)
dispatcher=.RpcServiceDispatcher~new(registry)
requestCodec=.SerializationSelector~new('soap-xml-request')
responseCodec=.SerializationSelector~new('soap-xml-response')
server=.SoapRpcServer~new(dispatcher,'catalog','urn:alchemy:catalog:v1',requestCodec)
client=.SoapRpcClient~new(.SoapLoopbackTransport~new(server),'catalog','urn:alchemy:catalog:v1','1.2',responseCodec)
a=.directory~new
a['message']='Selector XML ✓'
reply=client~request('catalog.echo',a)
call check reply~ok & reply~value==a['message'], 'explicit SerializationSelector codec exchange'
req=.directory~new
req['kind']='request'
req['version']='1.2'
req['namespace']='urn:alchemy:catalog:v1'
req['operation']='echo'
req['arguments']=a
bytes=responseCodec~encode(req)
doc=requestCodec~decode(bytes)
call check doc['ok'] & doc['arguments']['message']==a['message'], 'selector encode/decode semantics'
call registerSoapSerialization
call check .SerializationSelector~registered('soap-xml-response'), 'idempotent opt-in register'
call check \.SerializationSelector~registered('xml'), 'does not hijack generic XML provider'
say 'PASS' checks 'SerializationSelector SOAP registration checks'
exit 0
check:
 use strict arg condition,name
 if \condition then do
  say 'FAIL' name
  exit 1
 end
 checks += 1
return
::class Echo
::method invoke
  use strict arg op,args,context
  return args['message']
::requires 'SoapRpcBinding.cls'
::requires 'SoapSerializationRegistration.cls'
