/* SOAP XML envelope codec. Native libxml2, not JSON mapped XML.
 * A codec is role-specific because the SOAP RPC binding knows whether
 * the inbound envelope is a request or a response.
 * SerializationSelector may register these separately by name.
 */
::class SoapEnvelopeCodec public
::method init
  expose direction
  use strict arg direction='request'
  direction=direction~lower
  if direction \== 'request' then if direction \== 'response' then
    raise syntax 93.900 additional('SOAP envelope codec direction must be request or response')
::method format
  expose direction
  return 'soap-xml-' || direction
::method decode
  expose direction
  use strict arg bytes
  return SoapXmlParse(bytes,direction)
::method encode
  use strict arg document
  if \document~isA(.Directory) then raise syntax 93.900 additional('SOAP envelope requires semantic Directory')
  if \document~hasIndex('kind') | \document~hasIndex('version') then
    raise syntax 93.900 additional('SOAP envelope kind/version required')
  kind=document['kind']
  version=document['version']
  select
    when kind == 'request' then do
      if \document~hasIndex('namespace') | \document~hasIndex('operation') | \document~hasIndex('arguments') then
        raise syntax 93.900 additional('SOAP request envelope fields missing')
      return SoapXmlBuildRequest(version,document['namespace'],document['operation'],document['arguments'])
    end
    when kind == 'response' then do
      if \document~hasIndex('namespace') | \document~hasIndex('operation') | \document~hasIndex('value') then
        raise syntax 93.900 additional('SOAP response envelope fields missing')
      return SoapXmlBuildResponse(version,document['namespace'],document['operation'],document['value'])
    end
    when kind == 'fault' then do
      if \document~hasIndex('code') | \document~hasIndex('message') then
        raise syntax 93.900 additional('SOAP fault fields missing')
      return SoapXmlBuildFault(version,document['code'],document['message'])
    end
    otherwise raise syntax 93.900 additional('Unsupported SOAP envelope kind')
  end

::requires 'soapxml' LIBRARY
