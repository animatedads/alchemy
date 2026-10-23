/* Opt-in registration. Never register SOAP envelope codec as generic XML. */
::routine registerSoapSerialization public
  if \.SerializationSelector~registered('soap-xml-request') then
    .SerializationSelector~register('soap-xml-request',.SoapEnvelopeCodec~new('request'))
  if \.SerializationSelector~registered('soap-xml-response') then
    .SerializationSelector~register('soap-xml-response',.SoapEnvelopeCodec~new('response'))
  return .true

::requires 'SoapEnvelopeCodec.cls'
::requires 'SerializationSelector.cls'
