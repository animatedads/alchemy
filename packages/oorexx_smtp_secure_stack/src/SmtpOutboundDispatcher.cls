/* Durable outbound SMTP release/dispatch.
 * Spool state schedules work only. Every dispatch re-loads the immutable
 * Storage Fabric object and re-enters SmtpService~validateRelayRelease.
 */
::class SmtpOutboundBuild public
::constant API "smtp.outbound.dispatch/0.1"

::class SmtpNextHop public
::attribute host get
::attribute port get
::attribute heloName get
::attribute requireStartTls get
::method init
  expose host port heloName requireStartTls
  use strict arg hostArg,portArg=25,heloArg="oorexx-smtpd",requireStartTlsArg=.true
  host=hostArg~string; port=portArg; heloName=heloArg~string; requireStartTls=requireStartTlsArg
::method key
  expose host port
  return host||":"||port

::class SmtpNextHopResolver public
::method resolve
  use strict arg recipient
  return .SmtpResult~failure("NEXT_HOP_NOT_CONFIGURED",recipient)

::class StaticSmtpNextHopResolver subclass SmtpNextHopResolver public
::method init
  expose routes defaultHop
  use strict arg defaultHopArg=.nil
  routes=.directory~new; defaultHop=defaultHopArg
::method put
  expose routes
  use strict arg domain,hop
  routes[domain~string~lower]=hop; return self
::method resolve
  expose routes defaultHop
  use strict arg recipient
  s=recipient~string~strip("B","<>"); p=lastpos("@",s)
  if p=0 then return .SmtpResult~failure("RECIPIENT_DOMAIN_REQUIRED",recipient)
  domain=s~substr(p+1)~lower
  hop=routes[domain]; if hop==.nil then hop=defaultHop
  if hop==.nil then return .SmtpResult~failure("NEXT_HOP_NOT_FOUND",domain)
  return .SmtpResult~success(hop,"NEXT_HOP_RESOLVED")

::class SmtpRemoteReply public
::attribute code get
::attribute lines get
::method init
  expose code lines
  use strict arg codeArg,linesArg
  code=codeArg; lines=linesArg
::method classCode
  expose code
  if code="" then return 0
  return code~left(1)
::method text
  expose lines
  out=""; do i=1 to lines~items; if i>1 then out||=" | "; out||=lines[i]; end
  return out

::class SmtpRelayAttempt public
::attribute recipientResults get
::attribute remoteHost get
::attribute tlsProtocol
::attribute tlsCipher
::attribute detail get
::method init
  expose recipientResults remoteHost tlsProtocol tlsCipher detail
  use strict arg hostArg=""
  recipientResults=.directory~new; remoteHost=hostArg; tlsProtocol=""; tlsCipher=""; detail=""
::method setRecipient
  expose recipientResults
  use strict arg recipient,state,code="",detail=""
  d=.directory~new; d["state"]=state; d["code"]=code; d["detail"]=detail
  recipientResults[recipient~string]=d; return .true

::class SmtpRelayTransport public
::method deliver
  use strict arg hop,message,recipients
  return .SmtpResult~failure("RELAY_TRANSPORT_NOT_CONFIGURED")

::class SmtpClientIo public
::method init
  expose transport buffer
  use strict arg transportArg
  transport=transportArg; buffer=""
::method replaceTransport
  expose transport buffer
  use strict arg transportArg
  transport=transportArg; buffer=""; return .true
::method sendRaw
  expose transport
  use strict arg data
  off=1
  do while off<=data~length
    n=transport~send(data~substr(off))
    if n==.nil then return .false
    if n<=0 then return .false
    off+=n
  end
  return .true
::method sendLine
  use strict arg line
  return self~sendRaw(line||"0d0a"x)
::method readLine
  expose transport buffer
  use strict arg maxBytes=510
  do forever
    p=buffer~pos("0d0a"x)
    if p>0 then do
      if p-1>maxBytes then return .nil
      line=buffer~left(p-1); buffer=buffer~substr(p+2); return line
    end
    if buffer~length>maxBytes then return .nil
    remaining=maxBytes+2-buffer~length
    if remaining<=0 then return .nil
    chunk=transport~recv(4096~min(remaining))
    if chunk==.nil then return .nil
    if chunk="" then return .nil
    buffer||=chunk
  end
::method readReply
  use strict arg maxLines=100,maxBytes=51000
  first=self~readLine
  if first==.nil then return .nil
  if first~length<3 then return .nil
  code=first~left(3)
  if verify(code,"0123456789")<>0 then return .nil
  lines=.array~new; lines~append(first); totalBytes=first~length+2
  if first~length>=4 then do
    sep=first~substr(4,1)
    if sep<>" " then if sep<>"-" then return .nil
  end
  if first~length>=4 then do
    if first~substr(4,1)="-" then do
      do forever
        if lines~items>=maxLines then return .nil
        line=self~readLine
        if line==.nil then return .nil
        totalBytes+=line~length+2
        if totalBytes>maxBytes then return .nil
        if line~length<4 then return .nil
        if line~left(3)<>code then return .nil
        sep=line~substr(4,1)
        if sep<>" " then if sep<>"-" then return .nil
        lines~append(line)
        if sep=" " then leave
      end
    end
  end
  return .SmtpRemoteReply~new(code,lines)

::class RxSockStartTlsSmtpRelayTransport subclass SmtpRelayTransport public
::method init
  expose secureProvider socketConnector
  use strict arg secureProviderArg,socketConnectorArg=.nil
  secureProvider=secureProviderArg
  if socketConnectorArg==.nil then socketConnector=.SmtpRxSockConnector~new
  else socketConnector=socketConnectorArg
::method deliver
  expose secureProvider socketConnector
  use strict arg hop,message,recipients
  attempt=.SmtpRelayAttempt~new(hop~host)
  connected=socketConnector~connect(hop)
  if connected==.nil then return .SmtpResult~failure("NEXT_HOP_CONNECT_FAILED","connector returned .nil")
  if \connected~ok then return connected
  socket=connected~value
  if socket==.nil then return .SmtpResult~failure("NEXT_HOP_CONNECT_FAILED","connector returned no endpoint")
  io=.SmtpClientIo~new(socket)
  signal on syntax name transportFailure
  r=io~readReply; if r==.nil then do; socket~close; return .SmtpResult~failure("NEXT_HOP_GREETING_FAILED",self~replyText(r)); end
  if r~classCode<>2 then do; socket~close; return .SmtpResult~failure("NEXT_HOP_GREETING_FAILED",self~replyText(r)); end
  if \io~sendLine("EHLO "||hop~heloName) then do; socket~close; return .SmtpResult~failure("NEXT_HOP_WRITE_FAILED"); end
  ehlo=io~readReply; if ehlo==.nil then do; socket~close; return .SmtpResult~failure("NEXT_HOP_EHLO_FAILED",self~replyText(ehlo)); end
  if ehlo~classCode<>2 then do; socket~close; return .SmtpResult~failure("NEXT_HOP_EHLO_FAILED",self~replyText(ehlo)); end

  if hop~requireStartTls then do
    if \self~hasCapability(ehlo,"STARTTLS") then do; socket~close; return .SmtpResult~failure("NEXT_HOP_STARTTLS_REQUIRED"); end
    if secureProvider==.nil then do; socket~close; return .SmtpResult~failure("NEXT_HOP_TLS_PROVIDER_UNAVAILABLE"); end
    if \secureProvider~available then do; socket~close; return .SmtpResult~failure("NEXT_HOP_TLS_PROVIDER_UNAVAILABLE"); end
    if \io~sendLine("STARTTLS") then do; socket~close; return .SmtpResult~failure("NEXT_HOP_WRITE_FAILED"); end
    tr=io~readReply; if tr==.nil then do; socket~close; return .SmtpResult~failure("NEXT_HOP_STARTTLS_REJECTED",self~replyText(tr)); end
    if tr~code<>"220" then do; socket~close; return .SmtpResult~failure("NEXT_HOP_STARTTLS_REJECTED",self~replyText(tr)); end
    rawSocket=socket
    if socket~hasMethod("RAW") then rawSocket=socket~raw
    up=secureProvider~upgradeClient(rawSocket,hop~host)
    if \up~ok then do; socket~close; return .SmtpResult~failure("NEXT_HOP_TLS_FAILED",up~detail); end
    tlsSession=up~value; transport=.SecureSocketTransport~new(rawSocket,tlsSession); io~replaceTransport(transport)
    attempt~tlsProtocol=tlsSession~protocol; attempt~tlsCipher=tlsSession~cipher
    if \io~sendLine("EHLO "||hop~heloName) then do; transport~close; return .SmtpResult~failure("NEXT_HOP_WRITE_FAILED"); end
    ehlo=io~readReply; if ehlo==.nil then do; transport~close; return .SmtpResult~failure("NEXT_HOP_TLS_EHLO_FAILED",self~replyText(ehlo)); end
    if ehlo~classCode<>2 then do; transport~close; return .SmtpResult~failure("NEXT_HOP_TLS_EHLO_FAILED",self~replyText(ehlo)); end
  end
  else transport=socket

  if \io~sendLine("MAIL FROM:"||message~envelope~mailFrom) then do; transport~close; return .SmtpResult~failure("NEXT_HOP_WRITE_FAILED"); end
  mr=io~readReply; if mr==.nil then do; transport~close; return .SmtpResult~failure("NEXT_HOP_MAIL_REPLY_MISSING"); end
  if mr~classCode<>2 then do
    state=self~replyState(mr)
    do rcpt over recipients
      attempt~setRecipient(rcpt,state,mr~code,mr~text)
    end
    ignore=io~sendLine("QUIT"); transport~close; return .SmtpResult~success(attempt,"REMOTE_ATTEMPT")
  end

  accepted=.array~new
  do rcpt over recipients
    if \io~sendLine("RCPT TO:"||rcpt) then do; transport~close; return .SmtpResult~failure("NEXT_HOP_WRITE_FAILED"); end
    rr=io~readReply; if rr==.nil then do; transport~close; return .SmtpResult~failure("NEXT_HOP_RCPT_REPLY_MISSING"); end
    if rr~classCode=2 then accepted~append(rcpt)
    else attempt~setRecipient(rcpt,self~replyState(rr),rr~code,rr~text)
  end
  if accepted~items=0 then do; ignore=io~sendLine("QUIT"); transport~close; return .SmtpResult~success(attempt,"REMOTE_ATTEMPT"); end

  if \io~sendLine("DATA") then do; transport~close; return .SmtpResult~failure("NEXT_HOP_WRITE_FAILED"); end
  dr=io~readReply; if dr==.nil then do
    do rcpt over accepted
      attempt~setRecipient(rcpt,.SmtpSpoolState~DEFERRED,"","no DATA reply")
    end
    transport~close; return .SmtpResult~success(attempt,"REMOTE_ATTEMPT")
  end
  if dr~code<>"354" then do
    state=self~replyState(dr); code=""; detail=self~replyText(dr); if dr<>.nil then code=dr~code
    do rcpt over accepted
      attempt~setRecipient(rcpt,state,code,detail)
    end
    transport~close; return .SmtpResult~success(attempt,"REMOTE_ATTEMPT")
  end
  wire=self~dotStuff(message~content)
  if \io~sendRaw(wire||"."||"0d0a"x) then do; transport~close; return .SmtpResult~failure("NEXT_HOP_DATA_WRITE_FAILED"); end
  final=io~readReply; if final==.nil then do; transport~close; return .SmtpResult~failure("NEXT_HOP_DATA_REPLY_MISSING"); end
  state=self~replyState(final)
  do rcpt over accepted
    attempt~setRecipient(rcpt,state,final~code,final~text)
  end
  /* Final DATA reply is the transaction result. QUIT is cleanup only and must
   * never turn an accepted message into an ambiguous retry. */
  ignore=io~sendLine("QUIT")
  transport~close
  return .SmtpResult~success(attempt,"REMOTE_ATTEMPT")
transportFailure:
  say "SmtpRelayTransport syntax rc=" rc "sigl=" sigl "condition=" condition("C") "detail=" condition("D")
  detail=condition("D"); if socket<>.nil then socket~close
  return .SmtpResult~failure("NEXT_HOP_TRANSPORT_EXCEPTION",detail)
::method replyState private
  use strict arg reply
  if reply==.nil then return .SmtpSpoolState~DEFERRED
  if reply~classCode=2 then return .SmtpSpoolState~DELIVERED
  if reply~classCode=5 then return .SmtpSpoolState~FAILED
  return .SmtpSpoolState~DEFERRED
::method replyText private
  use strict arg reply
  if reply==.nil then return "no reply"
  return reply~text
::method hasCapability private
  use strict arg reply,name
  target=name~upper
  do line over reply~lines
    if line~length>4 then do
      text=line~substr(5)~strip~upper
      if text=target | text~left(target~length+1)=target||" " then return .true
    end
  end
  return .false
::method dotStuff private
  use strict arg content
  data=content
  if data~left(1)="." then data="."||data
  data=changestr("0d0a2e"x,data,"0d0a2e2e"x)
  if data~right(2)<>"0d0a"x then data||="0d0a"x
  return data

::class SmtpRetryPolicy public
::attribute maxAttempts get
::method init
  expose maxAttempts
  use strict arg maxAttemptsArg=8
  maxAttempts=maxAttemptsArg
::method nextDelay
  use strict arg attempt
  select
    when attempt<=1 then return 60
    when attempt=2 then return 300
    when attempt=3 then return 900
    when attempt=4 then return 3600
    otherwise return 14400
  end

::class SmtpOutboundDispatcher public
::method init
  expose service store resolver transport retryPolicy
  use strict arg serviceArg,storeArg,resolverArg,transportArg,retryPolicyArg=.nil
  service=serviceArg; store=storeArg; resolver=resolverArg; transport=transportArg
  if retryPolicyArg==.nil then retryPolicy=.SmtpRetryPolicy~new; else retryPolicy=retryPolicyArg
::method dispatch
  expose service store resolver transport retryPolicy
  use strict arg spoolId
  sr=store~loadSpool(spoolId); if \sr~ok then return sr
  spool=sr~value
  if spool~state=.SmtpSpoolState~DELIVERED then return .SmtpResult~success(spool,"DISPATCH_REPLAY_DELIVERED")
  mr=store~loadMessage(spool~objectId); if \mr~ok then return mr
  message=mr~value
  authenticated=self~asLogical(message~metadata["authenticated"])
  tlsActive=self~asLogical(message~metadata["tlsActive"])
  session=.SmtpSession~new("dispatch:"||spoolId,"",spool~principalId,authenticated,tlsActive)

  states=store~recipientStates(spoolId,spool~recipients)
  pending=.array~new
  do rcpt over spool~recipients
    state=self~stateOf(states[rcpt~string])
    if state<>.SmtpSpoolState~DELIVERED then if state<>.SmtpSpoolState~FAILED then pending~append(rcpt)
  end
  if pending~items=0 then return self~finalizeFromStates(spool,states)

  gate=service~validateRelayRelease(session,message,pending)
  if \gate~ok then do
    attempt=spool~attempts+1
    do rcpt over pending
      wr=store~transitionRecipient(spoolId,rcpt,.SmtpSpoolState~HELD,attempt,gate~code,gate~detail,"")
      if \wr~ok then return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
    end
    wr=store~transitionSpool(spoolId,.SmtpSpoolState~HELD,attempt,gate~code,gate~detail,"")
    if \wr~ok then return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
    message~metadata["spool.id"]=spoolId; message~metadata["spool.state"]=.SmtpSpoolState~HELD
    service~emitEvent("egress.dispatch.held",session,message,gate~code)
    return .SmtpResult~failure("DISPATCH_RELEASE_DENIED",gate~code||":"||gate~detail)
  end

  attemptNo=spool~attempts+1
  wr=store~transitionSpool(spoolId,.SmtpSpoolState~DISPATCHING,attemptNo,"","","")
  if \wr~ok then return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
  groups=.directory~new
  do rcpt over pending
    rr=resolver~resolve(rcpt)
    if \rr~ok then do
      wr=store~transitionRecipient(spoolId,rcpt,.SmtpSpoolState~FAILED,attemptNo,rr~code,rr~detail,"")
      if \wr~ok then return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
      wr=store~recordBounce(spoolId,spool~objectId,rcpt,rr~code,rr~detail)
      if \wr~ok then return .SmtpResult~failure("BOUNCE_EVIDENCE_WRITE_FAILED",wr~code||":"||wr~detail)
      iterate
    end
    hop=rr~value; key=hop~key; g=groups[key]
    if g==.nil then do; g=.directory~new; g["hop"]=hop; g["recipients"]=.array~new; groups[key]=g; end
    g["recipients"]~append(rcpt)
  end

  do key over groups~allIndexes
    g=groups[key]; hop=g["hop"]; recipients=g["recipients"]
    ar=transport~deliver(hop,message,recipients)
    if \ar~ok then do
      state=.SmtpSpoolState~DEFERRED
      if attemptNo>=retryPolicy~maxAttempts then state=.SmtpSpoolState~FAILED
      next=""; if state=.SmtpSpoolState~DEFERRED then next="+"||retryPolicy~nextDelay(attemptNo)||"s"
      do rcpt over recipients
        wr=store~transitionRecipient(spoolId,rcpt,state,attemptNo,ar~code,ar~detail,next)
        if \wr~ok then return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
        if state=.SmtpSpoolState~FAILED then do
          wr=store~recordBounce(spoolId,spool~objectId,rcpt,ar~code,ar~detail)
          if \wr~ok then return .SmtpResult~failure("BOUNCE_EVIDENCE_WRITE_FAILED",wr~code||":"||wr~detail)
        end
      end
      iterate
    end
    a=ar~value
    message~metadata["relay.remoteHost"]=a~remoteHost; message~metadata["relay.tlsProtocol"]=a~tlsProtocol; message~metadata["relay.tlsCipher"]=a~tlsCipher
    do rcpt over recipients
      d=a~recipientResults[rcpt~string]
      if d==.nil then do
        state=.SmtpSpoolState~DEFERRED; code="REMOTE_RESULT_MISSING"; detail="no per-recipient result"
      end
      else do; state=d["state"]; code=d["code"]; detail=d["detail"]; end
      if state=.SmtpSpoolState~DEFERRED then if attemptNo>=retryPolicy~maxAttempts then state=.SmtpSpoolState~FAILED
      next=""; if state=.SmtpSpoolState~DEFERRED then next="+"||retryPolicy~nextDelay(attemptNo)||"s"
      wr=store~transitionRecipient(spoolId,rcpt,state,attemptNo,code,detail,next)
      if \wr~ok then do
        if state=.SmtpSpoolState~DELIVERED then return .SmtpResult~failure("DELIVERY_STATE_UNCERTAIN",wr~code||":"||wr~detail)
        return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
      end
      if state=.SmtpSpoolState~FAILED then do
        wr=store~recordBounce(spoolId,spool~objectId,rcpt,code,detail)
        if \wr~ok then return .SmtpResult~failure("BOUNCE_EVIDENCE_WRITE_FAILED",wr~code||":"||wr~detail)
      end
    end
  end

  states=store~recipientStates(spoolId,spool~recipients)
  outcome=self~finalizeFromStates(spool,states,attemptNo)
  message~metadata["spool.id"]=spoolId; message~metadata["spool.state"]=outcome~code
  if outcome~ok then service~emitEvent("egress.dispatch.delivered",session,message,outcome~code)
  else service~emitEvent("egress.dispatch.incomplete",session,message,outcome~code)
  return outcome
::method finalizeFromStates private
  expose store
  use strict arg spool,states,attemptNo=0
  if attemptNo=0 then attemptNo=spool~attempts
  delivered=0; failed=0; deferred=0; held=0
  do rcpt over spool~recipients
    state=self~stateOf(states[rcpt~string])
    select
      when state=.SmtpSpoolState~DELIVERED then delivered+=1
      when state=.SmtpSpoolState~FAILED then failed+=1
      when state=.SmtpSpoolState~HELD then held+=1
      otherwise deferred+=1
    end
  end
  if delivered=spool~recipients~items then do
    wr=store~transitionSpool(spool~spoolId,.SmtpSpoolState~DELIVERED,attemptNo,"250","all recipients delivered","")
    if \wr~ok then return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
    return .SmtpResult~success(spool,"DELIVERED")
  end
  if held>0 then do
    wr=store~transitionSpool(spool~spoolId,.SmtpSpoolState~HELD,attemptNo,"HELD","release authority denied","")
    if \wr~ok then return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
    return .SmtpResult~failure("HELD","release authority denied")
  end
  if deferred>0 then do
    wr=store~transitionSpool(spool~spoolId,.SmtpSpoolState~DEFERRED,attemptNo,"DEFERRED","recipient retry pending","")
    if \wr~ok then return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
    return .SmtpResult~failure("DEFERRED","recipient retry pending")
  end
  wr=store~transitionSpool(spool~spoolId,.SmtpSpoolState~FAILED,attemptNo,"FAILED",failed||" recipient(s) permanently failed","")
  if \wr~ok then return .SmtpResult~failure("DURABLE_STATE_WRITE_FAILED",wr~code||":"||wr~detail)
  return .SmtpResult~failure("FAILED",failed||" recipient(s) permanently failed")
::method stateOf private
  use strict arg value
  if value==.nil then return .SmtpSpoolState~PENDING
  if value~isA(.Directory) then return value["state"]
  return value~string
::method asLogical private
  use strict arg value
  if value==.nil then return .false
  s=value~string~lower
  return s="1" | s="true" | s="yes"

::requires "socket.cls"
::requires "src/SmtpCore.cls"
::requires "src/SmtpDurableDelivery.cls"
::requires "src/SecureSocket.cls"

::requires "SmtpSocketProviderBinding.cls"
