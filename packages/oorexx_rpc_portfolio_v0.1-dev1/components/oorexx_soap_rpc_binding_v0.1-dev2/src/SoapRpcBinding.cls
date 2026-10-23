/* SOAP 1.1/1.2 document/literal binding.
 * XML authority is native libxml2, NOT SerializationSelector XML-mapped JSON.
 * No hidden transport choice, no mutating-call retry, no WSDL/WS-Security claim.
 */

::class SoapRpcServer public
::method init
  expose dispatcher service serviceURI codec
  use strict arg dispatcher, service, serviceURI, codec = .nil
  if codec == .nil then codec = .SoapEnvelopeCodec~new('request')
  if \codec~hasMethod('format') | codec~format \== 'soap-xml-request' then raise syntax 93.900 additional('SOAP server codec must be SOAP XML request')
  if service == '' | serviceURI == '' then raise syntax 93.900 additional('SOAP service and namespace required')
::method handleText
  expose dispatcher service serviceURI codec
  use strict arg xml, context = .nil
  envelope = codec~decode(xml)
  version = envelope['version']
  if \envelope['ok'] then return self~fault(version,envelope['faultCode'],envelope['message'])
  if envelope['isFault'] then return self~fault(version,'Sender','Fault received where request was expected')
  if envelope['service'] \== serviceURI then return self~fault(version,'Sender','Service namespace not allowed')
  operation=envelope['operation']
  answer=dispatcher~invoke(service,operation,envelope['arguments'],context)
  if \answer~ok then do
    if answer~fault~code == 'NOT_FOUND' then return self~fault(version,'Sender','Operation not found')
    if answer~fault~code == 'INVALID_ARGUMENT' then return self~fault(version,'Sender',answer~fault~message)
    /* Explicit application errors retain a code only within the trusted local API. */
    return self~fault(version,'Receiver','Service execution failure')
  end
  replyDoc=.directory~new
  replyDoc['kind']='response'
  replyDoc['version']=version
  replyDoc['namespace']=serviceURI
  replyDoc['operation']=operation
  replyDoc['value']=answer~value
  response=codec~encode(replyDoc)
  if response == .nil then return self~fault(version,'Receiver','Response value unsupported')
  return response
::method fault private
  expose codec
  use strict arg version, code, message
  document=.directory~new
  document['kind']='fault'
  document['version']=version
  document['code']=code
  document['message']=message
  return codec~encode(document)

::class SoapRpcClient public
::method init
  expose transport serviceURI service version codec
  use strict arg transport, service, serviceURI, version='1.2', codec = .nil
  if codec == .nil then codec = .SoapEnvelopeCodec~new('response')
  if \codec~hasMethod('format') | codec~format \== 'soap-xml-response' then raise syntax 93.900 additional('SOAP client codec must be SOAP XML response')
  if version \== '1.1' then if version \== '1.2' then raise syntax 93.900 additional('SOAP 1.1 or 1.2 required')
::method request
  expose transport serviceURI service version codec
  use strict arg name, arguments = .nil
  prefix=service || '.'
  if name~left(prefix~length) \== prefix then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('INVALID_ARGUMENT','Wrong service binding'))
  operation=name~substr(prefix~length+1)
  if arguments == .nil then arguments=.directory~new
  signal on syntax name transportFailure
  request=.directory~new
  request['kind']='request'
  request['version']=version
  request['namespace']=serviceURI
  request['operation']=operation
  request['arguments']=arguments
  requestXml=codec~encode(request)
  if requestXml == .nil then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('INVALID_ARGUMENT','SOAP arguments unsupported'))
  responseText=transport~exchange(requestXml)
  if responseText == .nil then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('NO_RESPONSE','No SOAP response'))
  response=codec~decode(responseText)
  if \response['ok'] then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('BAD_RESPONSE','Malformed SOAP response'))
  if response['version'] \== version then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('VERSION_MISMATCH','SOAP version changed'))
  if response['isFault'] then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new(response['faultCode'],response['message']))
  if response['service'] \== serviceURI | response['operation'] \== operation || 'Response' then
    return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('BAD_RESPONSE','Unexpected SOAP response operation'))
  return .RpcServiceResult~new(.true,response['result'])
transportFailure:
  signal off syntax
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then
    say 'SOAP local transport diagnostic' rc sigl condition("C") condition("D")
  return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('TRANSPORT_FAILURE','Uncertain transport outcome; not retried'))
::method notify
  use strict arg name, arguments=.nil
  /* SOAP document/literal request/reply is NOT JSON-RPC notification. */
  return .false

::class SoapLoopbackTransport public
::method init
  expose server context
  use strict arg server, context = .nil
::method exchange
  expose server context
  use strict arg requestXml
  return server~handleText(requestXml,context)

::requires 'RpcServiceCore.cls'
::requires 'SoapEnvelopeCodec.cls'
