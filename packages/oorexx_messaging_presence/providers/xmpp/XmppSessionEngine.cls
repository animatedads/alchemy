/* XmppSessionEngine.cls
 * ooRexx Messaging & Presence v0.1-dev4
 * Provider-private RFC 6120 session mechanics.
 */
::class XmppSessionEngineBuild public
::constant VERSION "0.1-dev4"
::constant SESSION_API "messaging.presence.xmpp.session/0.1"
::class XmppSessionState public
::constant DISCONNECTED "DISCONNECTED"
::constant STREAM_SENT "STREAM_SENT"
::constant STARTTLS_SENT "STARTTLS_SENT"
::constant SASL_SENT "SASL_SENT"
::constant AUTHENTICATED_STREAM_SENT "AUTHENTICATED_STREAM_SENT"
::constant BIND_SENT "BIND_SENT"
::constant READY "READY"
::constant FAILED "FAILED"
::constant CLOSED "CLOSED"
::class XmppFrameKind public
::constant STREAM_OPEN "STREAM_OPEN"
::constant STREAM_CLOSE "STREAM_CLOSE"
::constant ELEMENT "ELEMENT"
::class XmppFrame public
::method init
  expose kind xml
  use strict arg kind, xml
  kind=translate(strip(kind)); xml=xml
::attribute kind get
::attribute xml get

::class XmppCredentials public
::method init
  expose authenticationId secret authorizationId
  use strict arg authenticationId, secret, authorizationId=""
  authenticationId=strip(authenticationId); authorizationId=strip(authorizationId)
  if authenticationId="" then raise syntax 88.900 array("XMPP authentication id must not be empty")
  secret=secret
::attribute authenticationId get
::attribute secret get
::attribute authorizationId get
::class XmppCredentialsProvider public
::method resolve abstract
::class StaticXmppCredentialsProvider public subclass XmppCredentialsProvider
::method init; expose credentials; use strict arg credentials; credentials=credentials
::method resolve; expose credentials; use strict arg domain, context=.nil; return credentials

::class XmppBase64 public
::method encode class
  use strict arg bytes
  alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  out=""; n=length(bytes); i=1
  do while i<=n
    remain=n-i+1; b1=c2d(substr(bytes,i,1))
    if remain>=2 then b2=c2d(substr(bytes,i+1,1)); else b2=0
    if remain>=3 then b3=c2d(substr(bytes,i+2,1)); else b3=0
    x1=b1 % 4; x2=(b1 // 4)*16 + (b2 % 16); x3=(b2 // 16)*4 + (b3 % 64); x4=b3 // 64
    out=out||substr(alphabet,x1+1,1)||substr(alphabet,x2+1,1)
    if remain>=2 then out=out||substr(alphabet,x3+1,1); else out=out||"="
    if remain>=3 then out=out||substr(alphabet,x4+1,1); else out=out||"="
    i+=3
  end
  return out

::class XmppStreamFramer public
::method init
  expose buffer streamSeen
  buffer=""; streamSeen=.false
::method reset
  expose buffer streamSeen
  buffer=""; streamSeen=.false
  return self
::method feed
  expose buffer streamSeen
  use strict arg chunk
  buffer=buffer||chunk
  frames=.array~new
  do forever
    buffer=self~trimLeadingWhitespace(buffer)
    if buffer="" then leave
    if left(buffer,5)="<?xml" then do; p=pos("?>",buffer); if p=0 then leave; buffer=substr(buffer,p+2); iterate; end
    if left(buffer,4)="<!--" then do; p=pos("-->",buffer); if p=0 then leave; buffer=substr(buffer,p+3); iterate; end
    if left(buffer,14)="<stream:stream" then do
      stop=self~tagEnd(buffer,1); if stop=0 then leave
      xml=substr(buffer,1,stop); buffer=substr(buffer,stop+1); streamSeen=.true
      frames~append(.XmppFrame~new(.XmppFrameKind~STREAM_OPEN,xml)); iterate
    end
    if left(buffer,15)="</stream:stream" then do
      stop=self~tagEnd(buffer,1); if stop=0 then leave
      xml=substr(buffer,1,stop); buffer=substr(buffer,stop+1); streamSeen=.false
      frames~append(.XmppFrame~new(.XmppFrameKind~STREAM_CLOSE,xml)); iterate
    end
    if left(buffer,1)<>"<" then raise syntax 88.900 array("non-XML data in XMPP stream")
    stop=self~elementEnd(buffer); if stop=0 then leave
    xml=substr(buffer,1,stop); buffer=substr(buffer,stop+1)
    frames~append(.XmppFrame~new(.XmppFrameKind~ELEMENT,xml))
  end
  return frames
::method trimLeadingWhitespace private
  use strict arg text
  do while text<>"" & pos(left(text,1)," "||d2c(9)||d2c(10)||d2c(13))>0; text=substr(text,2); end
  return text
::method tagEnd
  use strict arg text, start
  quote=""; i=start
  do while i<=length(text)
    ch=substr(text,i,1)
    if quote<>"" then do; if ch=quote then quote=""; end
    else do
      if ch="'" | ch='"' then quote=ch
      else if ch=">" then return i
    end
    i+=1
  end
  return 0
::method elementEnd private
  use strict arg text
  depth=0; i=1
  do while i<=length(text)
    lt=pos("<",text,i); if lt=0 then return 0
    if substr(text,lt,4)="<!--" then do; p=pos("-->",text,lt+4); if p=0 then return 0; i=p+3; iterate; end
    if substr(text,lt,9)="<![CDATA[" then do; p=pos("]]>",text,lt+9); if p=0 then return 0; i=p+3; iterate; end
    if substr(text,lt,2)="<?" then do; p=pos("?>",text,lt+2); if p=0 then return 0; i=p+2; iterate; end
    gt=self~tagEnd(text,lt); if gt=0 then return 0
    tag=substr(text,lt,gt-lt+1); closing=left(tag,2)="</"; selfClose=right(strip(left(tag,length(tag)-1)),1)="/"; declaration=left(tag,2)="<!"
    if \declaration then do
      if closing then depth-=1
      else if \selfClose then depth+=1
    end
    i=gt+1
    if depth=0 then return gt
  end
  return 0

::class XmppXmlLite public
::method tagName class
  use strict arg xml
  p=pos("<",xml); if p=0 then return ""; p+=1
  if substr(xml,p,1)="/" then p+=1
  start=p
  do while p<=length(xml)
    ch=substr(xml,p,1)
    if pos(ch," >"||d2c(9)||d2c(10)||d2c(13)||"/")>0 then leave
    p+=1
  end
  return substr(xml,start,p-start)
::method attribute class
  use strict arg xml, name, defaultValue=""
  start=pos("<",xml); if start=0 then return defaultValue
  stop=.XmppStreamFramer~new~tagEnd(xml,start); if stop=0 then return defaultValue
  tag=substr(xml,start,stop-start+1); p=1
  do while p<=length(tag)
    hit=pos(name,tag,p); if hit=0 then return defaultValue
    before=" "; if hit>1 then before=substr(tag,hit-1,1); after=hit+length(name)
    if pos(before," "||d2c(9)||d2c(10)||d2c(13)||"<")=0 then do; p=hit+1; iterate; end
    do while after<=length(tag) & pos(substr(tag,after,1)," "||d2c(9)||d2c(10)||d2c(13))>0; after+=1; end
    if substr(tag,after,1)<>"=" then do; p=hit+1; iterate; end
    after+=1
    do while after<=length(tag) & pos(substr(tag,after,1)," "||d2c(9)||d2c(10)||d2c(13))>0; after+=1; end
    quote=substr(tag,after,1)
    if quote<>"'" & quote<>'"' then do; p=hit+1; iterate; end
    valueStart=after+1; valueEnd=pos(quote,tag,valueStart)
    if valueEnd=0 then return defaultValue
    return self~unescape(substr(tag,valueStart,valueEnd-valueStart))
  end
  return defaultValue
::method elementText class
  use strict arg xml, name, defaultValue=""
  p=pos("<"||name,xml); if p=0 then return defaultValue
  gt=.XmppStreamFramer~new~tagEnd(xml,p); if gt=0 then return defaultValue
  close="</"||name||">"; q=pos(close,xml,gt+1); if q=0 then return defaultValue
  return self~unescape(substr(xml,gt+1,q-gt-1))
::method contains class; use strict arg xml, needle; return pos(needle,xml)>0
::method unescape class
  use strict arg text
  text=changestr("&lt;",text,"<"); text=changestr("&gt;",text,">"); text=changestr("&quot;",text,'"'); text=changestr("&apos;",text,"'"); text=changestr("&amp;",text,"&"); return text
::method escapeText class
  use strict arg value
  text=value~string; text=changestr("&",text,"&amp;"); text=changestr("<",text,"&lt;"); text=changestr(">",text,"&gt;"); return text
::method escapeAttribute class
  use strict arg value
  text=self~escapeText(value); text=changestr("'",text,"&apos;"); text=changestr('"',text,"&quot;"); return text

::class XmppSessionFailure public
::method init; expose code detail; use strict arg code, detail=""; code=strip(code); detail=detail
::attribute code get
::attribute detail get

::class XmppSessionEngine public subclass XmppSession
::method init
  expose transport domain credentialsProvider resource framer state failure authenticated boundJid eventQueue presenceCache bindId inboundCounter contextRef
  use strict arg transport, domain, credentialsProvider, resource=""
  if transport=.nil then raise syntax 88.900 array("XMPP session engine requires transport")
  if credentialsProvider=.nil then raise syntax 88.900 array("XMPP session engine requires credentials provider")
  domain=strip(domain); if domain="" then raise syntax 88.900 array("XMPP session engine requires domain")
  transport=transport; credentialsProvider=credentialsProvider; resource=strip(resource); framer=.XmppStreamFramer~new
  state=.XmppSessionState~DISCONNECTED; failure=.nil; authenticated=.false; boundJid=""; bindId="bind-1"; inboundCounter=0
  eventQueue=.queue~new; presenceCache=.directory~new; contextRef=.nil
::attribute state get
::attribute failure get
::attribute boundJid get
::method connect
  expose transport state contextRef
  use strict arg context=.nil
  contextRef=context
  if state<>.XmppSessionState~DISCONNECTED & state<>.XmppSessionState~CLOSED then return .false
  if \transport~open(context) then return self~fail("TRANSPORT_OPEN_FAILED","stream transport did not open")
  if \self~writeStreamOpen then return self~fail("STREAM_OPEN_WRITE_FAILED","could not write initial XMPP stream open")
  state=.XmppSessionState~STREAM_SENT
  return .true
::method available; expose state; use strict arg context=.nil; return state=.XmppSessionState~READY
::method capabilities
  expose state
  use strict arg context=.nil
  if state<>.XmppSessionState~READY then return .MessagingPresenceCapabilities~new
  return .MessagingPresenceCapabilities~new(.array~of(.MessagingPresenceCapability~SEND_MESSAGE,.MessagingPresenceCapability~RECEIVE_MESSAGE,.MessagingPresenceCapability~PUBLISH_PRESENCE,.MessagingPresenceCapability~CHECK_PRESENCE,.MessagingPresenceCapability~SUBSCRIBE_PRESENCE,.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE))
::method pump
  expose transport framer state contextRef
  use strict arg context=.nil
  if context=.nil then context=contextRef
  if state=.XmppSessionState~FAILED | state=.XmppSessionState~CLOSED then return state
  chunk=transport~read(65536,context)
  if chunk=.nil | chunk="" then return state
  signal on syntax name framingFailure
  frames=framer~feed(chunk)
  signal off syntax
  do frame over frames
    self~handleFrame(frame,context)
    if state=.XmppSessionState~FAILED | state=.XmppSessionState~CLOSED then leave
  end
  return state
framingFailure:
  signal off syntax
  return self~fail("XML_STREAM_FRAMING_FAILED","invalid or unsupported XML stream framing")
::method sendXml
  expose transport state contextRef
  use strict arg xml, context=.nil
  if state<>.XmppSessionState~READY then return .false
  if context=.nil then context=contextRef
  return transport~write(xml,context)>=0
::method receiveEvent
  expose eventQueue contextRef
  use strict arg context=.nil
  if context=.nil then context=contextRef
  if eventQueue~items=0 then self~pump(context)
  if eventQueue~items=0 then return .nil
  return eventQueue~pull
::method currentPresence
  expose presenceCache contextRef
  use strict arg jid, context=.nil
  if context=.nil then context=contextRef
  if \presenceCache~hasIndex(jid) then self~pump(context)
  return presenceCache[jid]
::method close
  expose transport state
  if state=.XmppSessionState~READY then transport~write("</stream:stream>")
  transport~close; state=.XmppSessionState~CLOSED; return .true
::method handleFrame private
  expose state authenticated transport framer contextRef
  use strict arg frame, context=.nil
  if context=.nil then context=contextRef
  if frame~kind=.XmppFrameKind~STREAM_CLOSE then do; state=.XmppSessionState~CLOSED; return; end
  if frame~kind=.XmppFrameKind~STREAM_OPEN then return
  xml=frame~xml; tag=translate(.XmppXmlLite~tagName(xml))
  if tag="STREAM:ERROR" then do; self~fail("STREAM_ERROR","peer returned stream:error"); return; end
  if tag="STREAM:FEATURES" then do; self~handleFeatures(xml,context); return; end
  if tag="PROCEED" then do
    if state<>.XmppSessionState~STARTTLS_SENT then do; self~fail("UNEXPECTED_TLS_PROCEED","TLS proceed outside STARTTLS state"); return; end
    if \transport~startTls(context) then do; self~fail("TLS_UPGRADE_FAILED","transport could not complete STARTTLS upgrade"); return; end
    framer~reset
    if \self~writeStreamOpen(context) then do; self~fail("STREAM_RESTART_FAILED","could not restart stream after TLS"); return; end
    state=.XmppSessionState~STREAM_SENT; return
  end
  if tag="SUCCESS" then do
    if state<>.XmppSessionState~SASL_SENT then do; self~fail("UNEXPECTED_SASL_SUCCESS","SASL success outside authentication state"); return; end
    authenticated=.true; framer~reset
    if \self~writeStreamOpen(context) then do; self~fail("STREAM_RESTART_FAILED","could not restart stream after SASL"); return; end
    state=.XmppSessionState~AUTHENTICATED_STREAM_SENT; return
  end
  if tag="FAILURE" then do
    if state=.XmppSessionState~SASL_SENT then self~fail("SASL_AUTHENTICATION_FAILED","server rejected authentication"); else self~fail("PROTOCOL_FAILURE","server returned protocol failure")
    return
  end
  if tag="IQ" then do; self~handleIq(xml); return; end
  if state=.XmppSessionState~READY then do
    if tag="MESSAGE" then self~queueMessage(xml)
    else if tag="PRESENCE" then self~observePresence(xml)
  end
::method handleFeatures private
  expose transport state authenticated credentialsProvider domain contextRef resource
  use strict arg xml, context=.nil
  if context=.nil then context=contextRef
  if \transport~secure then do
    if pos("<starttls",xml)=0 then do; self~fail("TLS_REQUIRED","XMPP provider refuses authentication without protected transport"); return; end
    if \transport~supportsStartTls then do; self~fail("STARTTLS_UNAVAILABLE","current transport cannot upgrade the existing XMPP stream to TLS"); return; end
    if transport~write("<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>",context)<0 then do; self~fail("STARTTLS_WRITE_FAILED","could not request STARTTLS"); return; end
    state=.XmppSessionState~STARTTLS_SENT; return
  end
  if \authenticated then do
    if pos("<MECHANISM>PLAIN</MECHANISM>",translate(xml))=0 then do; self~fail("NO_SUPPORTED_SASL_MECHANISM","SASL PLAIN is not offered"); return; end
    credentials=credentialsProvider~resolve(domain,context)
    if credentials=.nil then do; self~fail("CREDENTIALS_UNAVAILABLE","no XMPP authentication material is available"); return; end
    plain=credentials~authorizationId||d2c(0)||credentials~authenticationId||d2c(0)||credentials~secret
    auth="<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>"||.XmppBase64~encode(plain)||"</auth>"
    if transport~write(auth,context)<0 then do; self~fail("SASL_WRITE_FAILED","could not submit SASL authentication"); return; end
    state=.XmppSessionState~SASL_SENT; return
  end
  if pos("urn:ietf:params:xml:ns:xmpp-bind",xml)=0 then do; self~fail("RESOURCE_BIND_UNAVAILABLE","authenticated stream did not advertise resource binding"); return; end
  bind="<iq type='set' id='bind-1'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"
  if resource<>"" then bind=bind||"<resource>"||.XmppXmlLite~escapeText(resource)||"</resource>"
  bind=bind||"</bind></iq>"
  if transport~write(bind,context)<0 then do; self~fail("BIND_WRITE_FAILED","could not request resource binding"); return; end
  state=.XmppSessionState~BIND_SENT
::method handleIq private
  expose state bindId boundJid
  use strict arg xml
  if state<>.XmppSessionState~BIND_SENT then return
  if .XmppXmlLite~attribute(xml,"id","")<>bindId then return
  iqType=translate(.XmppXmlLite~attribute(xml,"type",""))
  if iqType="ERROR" then do; self~fail("RESOURCE_BIND_FAILED","server rejected resource binding"); return; end
  if iqType<>"RESULT" then return
  jid=.XmppXmlLite~elementText(xml,"jid","")
  if jid="" then do; self~fail("RESOURCE_BIND_FAILED","bind result did not contain bound JID"); return; end
  boundJid=jid; state=.XmppSessionState~READY
::method queueMessage private
  expose eventQueue boundJid inboundCounter
  use strict arg xml
  from=.XmppXmlLite~attribute(xml,"from",""); if from="" then return
  to=.XmppXmlLite~attribute(xml,"to",boundJid); id=.XmppXmlLite~attribute(xml,"id","")
  if id="" then do; inboundCounter+=1; id="xmpp-in-"||inboundCounter; end
  eventQueue~queue(.XmppInboundMessage~new(id,from,to,.XmppXmlLite~elementText(xml,"body",""),.XmppXmlLite~elementText(xml,"subject",""),.XmppXmlLite~elementText(xml,"thread","")))
::method observePresence private
  expose eventQueue presenceCache
  use strict arg xml
  from=.XmppXmlLite~attribute(xml,"from",""); if from="" then return
  ptype=translate(.XmppXmlLite~attribute(xml,"type",""))
  if ptype="SUBSCRIBE" | ptype="SUBSCRIBED" | ptype="UNSUBSCRIBE" | ptype="UNSUBSCRIBED" | ptype="PROBE" | ptype="ERROR" then return
  if ptype="UNAVAILABLE" then availability=.PresenceAvailability~UNAVAILABLE
  else do
    show=translate(.XmppXmlLite~elementText(xml,"show",""))
    if show="AWAY" | show="XA" then availability=.PresenceAvailability~AWAY
    else if show="DND" then availability=.PresenceAvailability~BUSY
    else availability=.PresenceAvailability~AVAILABLE
  end
  event=.XmppInboundPresence~new(from,availability,.XmppXmlLite~elementText(xml,"status",""))
  presenceCache[from]=event; eventQueue~queue(event)
::method writeStreamOpen private
  expose transport domain contextRef
  use strict arg context=.nil
  if context=.nil then context=contextRef
  xml="<stream:stream to='"||.XmppXmlLite~escapeAttribute(domain)||"' version='1.0' xml:lang='en' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>"
  return transport~write(xml,context)>=0
::method fail private
  expose state failure
  use strict arg code, detail=""
  failure=.XmppSessionFailure~new(code,detail); state=.XmppSessionState~FAILED; return .false
::requires "XmppMessagingPresenceProvider.cls"
