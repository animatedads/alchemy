/* XmppMessagingPresenceProvider.cls
 * Standards-backed provider for Messaging & Presence.
 */
::class XmppMessagingPresenceBuild public
::constant VERSION "0.1-dev4"
::constant PROVIDER_API "messaging.presence.xmpp.provider/0.1"
::constant XMPP_CORE "RFC 6120"
::constant XMPP_IM_PRESENCE "RFC 6121"
::constant XMPP_ADDRESS "RFC 7622 (updated by RFC 9844)"
::constant HISTORICAL_CORE "RFC 3920"
::constant HISTORICAL_IM_PRESENCE "RFC 3921"

::class XmppAddressCodec public
::method encode abstract
::method decode abstract

::class XmppAsciiAddressCodec public subclass XmppAddressCodec
::method encode
  use strict arg address
  if address=.nil then raise syntax 88.900 array("XMPP address requires MessagingAddress")
  local=address~localId; domain=address~authority; resource=address~endpoint
  if domain="" then raise syntax 88.900 array("XMPP projection requires address authority/domain")
  self~assertAsciiPart(local,"local"); self~assertAsciiPart(domain,"domain")
  if resource<>"" then self~assertAsciiPart(resource,"resource")
  jid=local||"@"||domain
  if resource<>"" then jid=jid||"/"||resource
  return jid
::method decode
  use strict arg jid
  text=strip(jid)
  if text="" then raise syntax 88.900 array("XMPP JID must not be empty")
  slash=pos("/",text)
  if slash>0 then do; resource=substr(text,slash+1); bare=substr(text,1,slash-1); end
  else do; resource=""; bare=text; end
  at=pos("@",bare)
  if at=0 then raise syntax 88.900 array("dev1 ASCII XMPP profile requires local@domain")
  local=substr(bare,1,at-1); domain=substr(bare,at+1)
  self~assertAsciiPart(local,"local"); self~assertAsciiPart(domain,"domain")
  if resource<>"" then self~assertAsciiPart(resource,"resource")
  return .MessagingAddress~new(local,domain,resource)
::method assertAsciiPart private
  use strict arg text, label
  if text="" then raise syntax 88.900 array("XMPP "||label||" part must not be empty")
  do i=1 to length(text)
    code=c2d(substr(text,i,1))
    if code<33 | code>126 then raise syntax 88.900 array("dev1 XMPP ASCII codec refuses non-ASCII/control "||label||" part")
  end
  if pos("<",text)>0 | pos(">",text)>0 | pos("'",text)>0 | pos('"',text)>0 then raise syntax 88.900 array("unsafe XMPP "||label||" part")
  if label<>"resource" then if pos("@",text)>0 | pos("/",text)>0 then raise syntax 88.900 array("XMPP "||label||" part contains address separator")
  return .true

::class XmppStanzaCodec public
::method init; expose addresses; use strict arg addresses; addresses=addresses
::method message
  expose addresses
  use strict arg message
  xml="<message to='"||self~escapeAttribute(addresses~encode(message~toAddress))||"' id='"||self~escapeAttribute(message~messageId)||"'>"
  if message~subject<>"" then xml=xml||"<subject>"||self~escapeText(message~subject)||"</subject>"
  xml=xml||"<body>"||self~escapeText(message~body)||"</body>"
  if message~threadId<>"" then xml=xml||"<thread>"||self~escapeText(message~threadId)||"</thread>"
  return xml||"</message>"
::method presence
  expose addresses
  use strict arg state
  a=state~availability
  if a=.PresenceAvailability~UNAVAILABLE then xml="<presence type='unavailable'>"; else xml="<presence>"
  if a=.PresenceAvailability~AWAY then xml=xml||"<show>away</show>"
  if a=.PresenceAvailability~BUSY then xml=xml||"<show>dnd</show>"
  if state~statusText<>"" then xml=xml||"<status>"||self~escapeText(state~statusText)||"</status>"
  return xml||"</presence>"
::method subscribe; expose addresses; use strict arg address; return "<presence to='"||self~escapeAttribute(addresses~encode(address))||"' type='subscribe'/>"
::method unsubscribe; expose addresses; use strict arg address; return "<presence to='"||self~escapeAttribute(addresses~encode(address))||"' type='unsubscribe'/>"
::method escapeText private
  use strict arg value
  text=value~string; text=changestr("&",text,"&amp;"); text=changestr("<",text,"&lt;"); text=changestr(">",text,"&gt;"); return text
::method escapeAttribute private
  use strict arg value
  text=self~escapeText(value); text=changestr("'",text,"&apos;"); text=changestr('"',text,"&quot;"); return text

::class XmppSession public
::method available abstract
::method capabilities abstract
::method sendXml abstract
::method receiveEvent abstract
::method currentPresence abstract

::class XmppInboundMessage public
::method init
  expose messageId fromJid toJid body subject threadId receivedAt metadata
  use strict arg messageId, fromJid, toJid, body, subject="", threadId="", receivedAt="", metadata=.nil
  messageId=messageId; fromJid=fromJid; toJid=toJid; body=body; subject=subject; threadId=threadId; receivedAt=receivedAt
  if metadata=.nil then metadata=.directory~new
::attribute messageId get
::attribute fromJid get
::attribute toJid get
::attribute body get
::attribute subject get
::attribute threadId get
::attribute receivedAt get
::attribute metadata get

::class XmppInboundPresence public
::method init
  expose jid availability statusText observedAt metadata
  use strict arg jid, availability, statusText="", observedAt="", metadata=.nil
  jid=jid; availability=translate(strip(availability)); statusText=statusText; observedAt=observedAt
  if metadata=.nil then metadata=.directory~new
::attribute jid get
::attribute availability get
::attribute statusText get
::attribute observedAt get
::attribute metadata get

::class XmppTransport public
::method open abstract
::method write abstract
::method read abstract
::method close abstract
::method secure abstract
::method supportsStartTls; return .false
::method startTls; use strict arg context=.nil; return .false

::class XmppSocketTransport public subclass XmppTransport
::method init
  expose socketProvider logicalName stream
  use strict arg socketProvider, logicalName="messaging.xmpp"
  socketProvider=socketProvider; logicalName=strip(logicalName); stream=.nil
::attribute logicalName get
::method open
  expose socketProvider logicalName stream
  use strict arg context=.nil
  stream=socketProvider~streamSender(logicalName); return stream<>.nil
::method write; expose stream; use strict arg bytes, context=.nil; if stream=.nil then return -1; return stream~write(bytes)
::method read; expose stream; use strict arg maximumBytes, context=.nil; if stream=.nil then return .nil; return stream~read(maximumBytes)
::method close
  expose stream
  if stream=.nil then return .true
  answer=stream~close; stream=.nil; return answer
::method socketAddress; expose stream; if stream=.nil then return .nil; return stream~socketAddress
::method secure
  expose stream
  if stream=.nil then return .false
  address=stream~socketAddress
  if address=.nil then return .false
  return address~transport=.SocketTransportKind~TLS
::method supportsStartTls; return .false
::method startTls; use strict arg context=.nil; return .false

::class XmppMessagingPresenceProvider public subclass MessagingPresenceProvider
::method init
  expose session addressCodec stanzaCodec priority providerName scope
  use strict arg session, addressCodec=.nil, priority=100, providerName="xmpp", scope=""
  if session=.nil then raise syntax 88.900 array("XMPP provider requires session")
  if addressCodec=.nil then addressCodec=.XmppAsciiAddressCodec~new
  session=session; addressCodec=addressCodec; stanzaCodec=.XmppStanzaCodec~new(addressCodec); priority=priority+0; providerName=strip(providerName); scope=strip(scope)
::method providerId; expose providerName; return providerName
::method offers
  expose session priority scope
  use strict arg context=.nil
  if \session~available(context) then return .array~new
  capabilities=session~capabilities(context)
  if capabilities=.nil then capabilities=.MessagingPresenceCapabilities~new
  return .array~of(.MessagingPresenceOffer~new(self,capabilities,priority,.true,scope,"current XMPP session capability"))
::method canRoute
  expose addressCodec
  use strict arg address, capability, context=.nil
  signal on syntax name routeFail
  ignore=addressCodec~encode(address)
  signal off syntax
  return .true
routeFail:
  signal off syntax
  return .false
::method send
  expose session stanzaCodec
  use strict arg message, context=.nil
  if \session~available(context) then return .MessagingDeliveryResult~new(.MessagingDeliveryStatus~UNAVAILABLE,message,self~providerId,"XMPP session unavailable")
  ok=session~sendXml(stanzaCodec~message(message),context)
  if ok then return .MessagingDeliveryResult~new(.MessagingDeliveryStatus~SENT,message,self~providerId,"XMPP stanza accepted by session")
  return .MessagingDeliveryResult~new(.MessagingDeliveryStatus~FAILED,message,self~providerId,"XMPP session rejected stanza")
::method receive
  expose session addressCodec
  use strict arg context=.nil
  if \session~available(context) then return .nil
  event=session~receiveEvent(context)
  if event=.nil then return .nil
  if event~isA(.XmppInboundMessage) then return .Message~new(event~messageId,addressCodec~decode(event~fromJid),addressCodec~decode(event~toJid),event~body,event~subject,"text/plain",event~threadId,event~receivedAt,.nil,event~metadata)
  if event~isA(.XmppInboundPresence) then return self~presenceState(event)
  return .nil
::method publishPresence; expose session stanzaCodec; use strict arg state, context=.nil; if \session~available(context) then return .false; return session~sendXml(stanzaCodec~presence(state),context)
::method presence
  expose session addressCodec
  use strict arg address, context=.nil
  if \session~available(context) then return .nil
  event=session~currentPresence(addressCodec~encode(address),context)
  if event=.nil then return .nil
  return self~presenceState(event)
::method subscribePresence; expose session stanzaCodec; use strict arg address, context=.nil; if \session~available(context) then return .false; return session~sendXml(stanzaCodec~subscribe(address),context)
::method unsubscribePresence; expose session stanzaCodec; use strict arg address, context=.nil; if \session~available(context) then return .false; return session~sendXml(stanzaCodec~unsubscribe(address),context)
::method presenceState private
  expose addressCodec
  use strict arg event
  return .PresenceState~new(addressCodec~decode(event~jid),event~availability,event~statusText,event~observedAt,self~providerId,event~metadata)

::requires "MessagingPresence.cls"
::requires "SocketProvider.cls"
