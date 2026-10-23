/* XmppBoshTransport.cls
 * XMPP-over-BOSH binding adapter v0.1-dev2
 *
 * XEP-0206 belongs above generic BOSH.  This adapter maps the XMPP byte-stream
 * contract used by Messaging & Presence onto a BOSH logical stream without
 * adding XMPP semantics to the BOSH package or BOSH semantics to Messaging.
 */

::class XmppBoshAdapterBuild public
::constant VERSION "0.1-dev2"
::constant API "xmpp.bosh.transport/0.1"
::constant XBOSH_NS "urn:xmpp:xbosh"

::class XmppBoshSecurityProjection public
::method protected abstract

::class XmppBoshFixedSecurity public subclass XmppBoshSecurityProjection
::method init
  expose protectedFlag
  use strict arg protectedFlag=.false
  protectedFlag=protectedFlag<>.false
::method protected
  expose protectedFlag
  return protectedFlag

::class XmppBoshTransport public subclass XmppTransport
::method init
  expose boshProvider endpoint security stream localBuffer opened clientOpenSeen
  use strict arg boshStreamProvider, boshEndpoint, securityProjection
  if boshStreamProvider=.nil then raise syntax 88.900 array("XMPP/BOSH adapter requires BOSH stream provider")
  if boshEndpoint=.nil then raise syntax 88.900 array("XMPP/BOSH adapter requires BOSH endpoint")
  if securityProjection=.nil then raise syntax 88.900 array("XMPP/BOSH adapter requires explicit security projection")
  boshProvider=boshStreamProvider
  endpoint=boshEndpoint
  security=securityProjection
  stream=.nil
  localBuffer=""
  opened=.false
  clientOpenSeen=.false

::method open
  expose boshProvider endpoint stream localBuffer opened clientOpenSeen
  use strict arg context=.nil
  if opened then return .true
  attrs=.directory~new
  attrs["xmlns:xmpp"]=.XmppBoshAdapterBuild~XBOSH_NS
  attrs["xmpp:version"]="1.0"
  stream=boshProvider~connect(endpoint,attrs)
  if stream=.nil then return .false
  localBuffer=self~syntheticStreamOpen
  if stream~pendingBytes>0 then localBuffer=localBuffer||stream~recv
  opened=.true
  clientOpenSeen=.false
  return .true

::method write
  expose stream localBuffer opened clientOpenSeen
  use strict arg bytes, context=.nil
  if \opened | stream=.nil then return -1
  text=strip(bytes,"L")
  if pos("<stream:stream",text)=1 then do
    if \clientOpenSeen then do
      clientOpenSeen=.true
      return length(bytes)
    end
    attrs=.directory~new
    attrs["xmlns:xmpp"]=.XmppBoshAdapterBuild~XBOSH_NS
    attrs["xmpp:restart"]="true"
    incoming=stream~session~exchange("",attrs)
    if incoming=.false then return -1
    localBuffer=localBuffer||self~syntheticStreamOpen||incoming
    return length(bytes)
  end
  if pos("</stream:stream",text)=1 then return length(bytes)
  return stream~send(bytes)

::method read
  expose stream localBuffer opened
  use strict arg maximumBytes, context=.nil
  if \opened | stream=.nil then return .nil
  if localBuffer<>"" then return self~takeLocal(maximumBytes)
  return stream~recv(maximumBytes)

::method close
  expose stream localBuffer opened
  if \opened then return .true
  ok=.true
  if stream<>.nil then ok=stream~close
  stream=.nil
  localBuffer=""
  opened=.false
  return ok

::method secure
  expose security
  return security~protected
::method supportsStartTls
  return .false
::method startTls
  use strict arg context=.nil
  return .false
::method syntheticStreamOpen private
  expose endpoint
  from=self~escapeAttribute(endpoint~targetDomain)
  return "<stream:stream from='"||from||"' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' version='1.0'>"
::method takeLocal private
  expose localBuffer
  use strict arg maximumBytes=0
  if maximumBytes<=0 | maximumBytes>=length(localBuffer) then do; out=localBuffer; localBuffer=""; return out; end
  out=left(localBuffer,maximumBytes); localBuffer=substr(localBuffer,maximumBytes+1); return out
::method escapeAttribute private
  use strict arg value
  text=value~string
  text=changestr("&",text,"&amp;")
  text=changestr("<",text,"&lt;")
  text=changestr(">",text,"&gt;")
  text=changestr("'",text,"&apos;")
  text=changestr('"',text,"&quot;")
  return text

::requires "BoshTransport.cls"
::requires "XmppMessagingPresenceProvider.cls"
