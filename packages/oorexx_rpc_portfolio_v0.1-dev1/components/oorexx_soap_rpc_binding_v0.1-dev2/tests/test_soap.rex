/* SOAP protocol conformance and neutral dispatcher integration smoke tests. */
checks=0
registry=.RpcServiceRegistry~new
registry~register('catalog','echo',.Echo~new)
registry~register('catalog','refuse',.Refuse~new)
registry~register('catalog','panic',.Panic~new)
server=.SoapRpcServer~new(.RpcServiceDispatcher~new(registry),'catalog','urn:alchemy:catalog:v1')
transport=.SoapLoopbackTransport~new(server)
client=.SoapRpcClient~new(transport,'catalog','urn:alchemy:catalog:v1','1.2')
a=.directory~new
a['message']='a & <b> " c'
reply=client~request('catalog.echo',a)
call check reply~ok, 'SOAP 1.2 successful exchange'
call check reply~value == a['message'], 'escaped text round trip'
a['message']='0007'
reply=client~request('catalog.echo',a)
call check reply~ok & reply~value~string == '0007', 'numeric-looking strings preserved'
a['message']=.nil
reply=client~request('catalog.echo',a)
call check reply~ok & reply~value == .nil, 'nil round trip'
a['message']=.true
reply=client~request('catalog.echo',a)
call check reply~ok & reply~value == .true, 'XSD boolean round trip'
a['message']=.false
reply=client~request('catalog.echo',a)
call check reply~ok & reply~value == .false, 'false boolean round trip'
a['message']='Bonjour — Ελληνικά'
reply=client~request('catalog.echo',a)
call check reply~ok & reply~value == a['message'], 'UTF-8 round trip'
old=.SoapRpcClient~new(transport,'catalog','urn:alchemy:catalog:v1','1.1')
reply=old~request('catalog.echo',a)
call check reply~ok, 'SOAP 1.1 request/response'
reply=client~request('catalog.missing',a)
call check \reply~ok & reply~fault~message == 'Operation not found', 'allowlisted service operation'
reply=old~request('catalog.missing',a)
call check \reply~ok & reply~fault~message == 'Operation not found', 'SOAP 1.1 Fault mapping'
reply=client~request('catalog.refuse',a)
call check \reply~ok & reply~fault~message == 'Service execution failure', 'business fault masked when not parameter failure'
reply=client~request('catalog.panic',a)
call check \reply~ok & reply~fault~message == 'Service execution failure', 'exception detail masked'
reply=client~request('catalog.echo',.array~of('bad'))
call check \reply~ok & reply~fault~code == 'INVALID_ARGUMENT', 'complex payload rejected'
reply=client~request('other.echo',a)
call check \reply~ok, 'service binding prevents cross service call'
call check \client~notify('catalog.echo',a), 'SOAP cannot promise RPC notifications'
xml=SoapXmlBuildRequest('1.2','urn:alchemy:catalog:v1','echo',a)
call check xml~pos('http://www.w3.org/2003/05/soap-envelope')>0, 'SOAP12 namespace emitted'
call check xml~pos('encodingStyle') == 0, 'no encoded SOAP style'
call check xml~pos('SOAPAction') == 0, 'SOAPAction never used for service selection'
env=SoapXmlParse(xml,'request')
call check env['ok'] & env['operation']=='echo', 'namespace-aware parse'
call check env['arguments']['message']=='Bonjour — Ελληνικά', 'argument dictionary decoding'
soapFault=SoapXmlBuildFault('1.2','Sender','<secret> & denied')
faultEnv=SoapXmlParse(soapFault,'response')
call check faultEnv['ok'] & faultEnv['isFault'], 'SOAP12 fault parsed'
call check faultEnv['message']=='<secret> & denied', 'SOAP fault XML escaping'
soapFault=SoapXmlBuildFault('1.1','Sender','not allowed')
faultEnv=SoapXmlParse(soapFault,'response')
call check faultEnv['ok'] & faultEnv['isFault'] & faultEnv['faultCode']~pos('Client')>0, 'SOAP11 fault parsed'
xxe=xml~changestr('?>','?>' || '<!DOCTYPE soap:Envelope [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>')
replyXml=server~handleText(xxe)
call check replyXml~pos('DTD')>0, 'DOCTYPE/XXE rejected'
wrongXml=xml~changestr('http://www.w3.org/2003/05/soap-envelope','urn:not:soap')
replyXml=server~handleText(wrongXml)
call check replyXml~pos('VersionMismatch')>0, 'SOAP namespace version strict'
wrongXml=xml~changestr('urn:alchemy:catalog:v1','urn:untrusted:service')
replyXml=server~handleText(wrongXml)
call check replyXml~pos('Service namespace not allowed')>0, 'service namespace allowlist'
xmlMu=xml~changestr('<soap:Body xmlns:soap=', '<soap:Header><h:Auth xmlns:h="urn:headers" soap:mustUnderstand="1">X</h:Auth></soap:Header><soap:Body xmlns:soap=')
replyXml=server~handleText(xmlMu)
call check replyXml~pos('MustUnderstand')>0, 'SOAP mustUnderstand enforced'
xmlExtra=xml~changestr('</soap:Body>', '<bogus/></soap:Body>')
replyXml=server~handleText(xmlExtra)
call check replyXml~pos('exactly one')>0, 'multiple body items rejected'
xmlDup=xml~changestr('</m:echo>','<message>overridden</message></m:echo>')
replyXml=server~handleText(xmlDup)
call check replyXml~pos('Duplicate SOAP argument')>0, 'duplicate arguments rejected'
xmlNested=xml~changestr('</m:echo>','<nested><a>1</a></nested></m:echo>')
replyXml=server~handleText(xmlNested)
call check replyXml~pos('Complex argument unsupported')>0, 'no silently flattened XML graphs'
xmlEnc=xml~changestr('<m:echo','<m:echo soap:encodingStyle="urn:soap:encode"')
replyXml=server~handleText(xmlEnc)
call check replyXml~pos('encodingStyle')>0, 'SOAP encodingStyle rejected'
xmlBig='x'~copies(1048577)
replyXml=server~handleText(xmlBig)
call check replyXml~pos('frame too large')>0, '1MB size cap'

/* Additional hostile and malformed input regression cases. */
xmlBool=SoapXmlBuildRequest('1.2','urn:alchemy:catalog:v1','echo',.directory~new)
call check xmlBool~pos('http://www.w3.org/2003/05/soap-envelope')>0, 'empty operation parameter map'
valueMap=.directory~new
valueMap['message']=.true
xmlBool=SoapXmlBuildRequest('1.2','urn:alchemy:catalog:v1','echo',valueMap)
call check xmlBool~pos('xmlns:xs="http://www.w3.org/2001/XMLSchema"')>0, 'XSD QName namespace declared'
invalidTyped=xmlBool~changestr('xmlns:xs="http://www.w3.org/2001/XMLSchema"','xmlns:xs="urn:not:xml-schema"')
replyXml=server~handleText(invalidTyped)
call check replyXml~pos('Complex argument unsupported')>0, 'wrong xsi type QName binding rejected'
invalidNil=xml~changestr('<message>', '<message xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true">')
replyXml=server~handleText(invalidNil)
call check replyXml~pos('Complex argument unsupported')>0, 'nil with content rejected'
valueMap=.directory~new
valueMap['message']='abc' || d2c(0) || 'def'
reply=client~request('catalog.echo',valueMap)
call check \reply~ok, 'NUL in outbound scalar rejected'
rawNul=xml || d2c(0) || '<forged/>'
replyXml=server~handleText(rawNul)
call check replyXml~pos('NUL bytes rejected')>0, 'embedded NUL in incoming XML rejected'
valueMap=.directory~new
valueMap['message']=.array~of('unexpected')
reply=client~request('catalog.echo',valueMap)
call check \reply~ok, 'complex array param fails closed'
valueMap=.directory~new
valueMap['message']=d2c(1)
reply=client~request('catalog.echo',valueMap)
call check \reply~ok, 'invalid XML control character rejected'
say 'PASS' checks 'SOAP binding checks'
exit 0
check:
  use strict arg condition, name
  if \condition then do
   say 'FAIL' name
   exit 1
  end
  checks += 1
return
::class Echo
::method invoke
  use strict arg operation,args,context
  return args['message']
::class Refuse
::method invoke
  use strict arg operation,args,context
  return .RpcServiceFault~new('DENIED','Never send this detail')
::class Panic
::method invoke
  raise syntax 93.900 additional('Sensitive exception text')
::requires 'SoapRpcBinding.cls'
