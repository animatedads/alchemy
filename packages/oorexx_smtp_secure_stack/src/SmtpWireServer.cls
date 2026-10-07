/* Minimal RFC-5321 style SMTP listener over RxSock. STARTTLS is provider-neutral.
 * This dev3 edge intentionally supports a bounded command set and delegates all
 * security authority to SmtpService/providers.
 */
::class SmtpLineReader public
::method init
  expose transport buffer
  use strict arg transportArg
  transport=transportArg; buffer=""
::method replaceTransport
  expose transport buffer
  use strict arg transportArg
  transport=transportArg; buffer=""; return .true
::method readLine
  expose transport buffer
  use strict arg maxBytes=1048576
  do forever
    p=buffer~pos("0d0a"x)
    if p>0 then do
      line=buffer~left(p-1)
      buffer=buffer~substr(p+2)
      return line
    end
    if buffer~length>=maxBytes then return .nil
    chunk=transport~recv(4096)
    if chunk==.nil | chunk="" then return .nil
    buffer||=chunk
  end

::class SmtpWireServer public
::method init
  expose service host port banner secureProvider listener running
  use strict arg serviceArg,hostArg="127.0.0.1",portArg=2525,bannerArg="oorexx-smtpd",secureProviderArg=.nil
  service=serviceArg; host=hostArg; port=portArg; banner=bannerArg; secureProvider=secureProviderArg; listener=.nil; running=.false
::method serve unguarded
  expose host port listener running
  use strict arg maxConnections=0,readyFile=""
  listener=.Socket~new; listener~setOption("SO_REUSEADDR",1)
  if listener~bind(.InetAddress~new(host,port))<0 then raise syntax 93.900 additional("SMTP bind failed errno="||listener~errno)
  if listener~listen(32)<0 then raise syntax 93.900 additional("SMTP listen failed errno="||listener~errno)
  running=.true
  if readyFile<>"" then do; call lineout readyFile,"READY "||host||":"||port; call stream readyFile,"C","CLOSE"; end
  served=0
  do while running
    client=listener~accept; if client==.nil then leave
    self~serveClient(client); served+=1
    if maxConnections>0 then if served>=maxConnections then leave
  end
  running=.false; if listener<>.nil then listener~close
  return served
::method stop unguarded
  expose listener running
  running=.false; if listener<>.nil then listener~close
::method sendLine private
  use strict arg transport,line
  data=line||"0d0a"x; off=1
  do while off<=data~length
    n=transport~send(data~substr(off)); if n==.nil | n<=0 then return .false; off+=n
  end
  return .true
::method decodeBase64 private
  use strict arg token
  signal on syntax name invalid
  value=token~decodebase64
  signal off syntax
  return value
invalid:
  say "SmtpWireServer decode syntax rc=" rc "sigl=" sigl "condition=" condition("C") "detail=" condition("D")
  signal off syntax
  return .nil
::method serveClient
  expose service banner secureProvider
  use strict arg socket
  transport=socket; reader=.SmtpLineReader~new(transport); tlsActive=.false; session=.SmtpSession~new(socket~string,"","",.false,.false)
  env=.SmtpEnvelope~new
  ignore=self~sendLine(transport,"220 "||banner||" ESMTP ooRexx")
  signal on syntax name clientFailure
  do forever
    line=reader~readLine; if line==.nil then leave
    upper=line~upper
    parse var upper command " " remainder
    if command="EHLO" | command="HELO" then do
      caps="250-"||banner||" SIZE 26214400"
      ignore=self~sendLine(transport,caps)
      if tlsActive then ignore=self~sendLine(transport,"250-AUTH PLAIN")
      else if secureProvider<>.nil then do
        if secureProvider~available then ignore=self~sendLine(transport,"250-STARTTLS")
      end
      ignore=self~sendLine(transport,"250 OK")
      iterate
    end
    if upper="STARTTLS" then do
      if tlsActive | secureProvider==.nil | \secureProvider~available then do; ignore=self~sendLine(transport,"454 TLS not available"); iterate; end
      ignore=self~sendLine(transport,"220 Ready to start TLS")
      r=secureProvider~upgradeServer(socket)
      if \r~ok then leave
      transport=.SecureSocketTransport~new(socket,r~value); ignore=reader~replaceTransport(transport); tlsActive=.true
      session=.SmtpSession~new(socket~string,"","",.false,.true)
      env=.SmtpEnvelope~new
      iterate
    end
    if upper~left(10)="AUTH PLAIN" then do
      if \tlsActive then do; ignore=self~sendLine(transport,"538 5.7.11 Encryption required for requested authentication mechanism"); iterate; end
      token=line~substr(11)~strip
      if token="" then do
        ignore=self~sendLine(transport,"334 ")
        token=reader~readLine
        if token==.nil then leave
      end
      credentials=self~decodeBase64(token)
      if credentials==.nil then do; ignore=self~sendLine(transport,"501 5.5.2 Invalid AUTH PLAIN encoding"); iterate; end
      ar=service~authenticate(session,"PLAIN",credentials)
      if ar~ok then do; session=ar~value; ignore=self~sendLine(transport,"235 2.7.0 Authentication successful"); end
      else ignore=self~sendLine(transport,"535 5.7.8 Authentication credentials invalid")
      iterate
    end
    if upper~left(10)="MAIL FROM:" then do
      env=.SmtpEnvelope~new(line~substr(11)~strip); ignore=self~sendLine(transport,"250 2.1.0 Sender OK"); iterate
    end
    if upper~left(8)="RCPT TO:" then do
      env~addRecipient(line~substr(9)~strip); ignore=self~sendLine(transport,"250 2.1.5 Recipient OK"); iterate
    end
    if upper="DATA" then do
      if env~recipients~items=0 then do; ignore=self~sendLine(transport,"503 5.5.1 Need RCPT TO"); iterate; end
      ignore=self~sendLine(transport,"354 End data with <CRLF>.<CRLF>")
      body=""
      do forever
        dl=reader~readLine(1048576); if dl==.nil then leave
        if dl="." then leave
        if dl~left(2)=".." then dl=dl~substr(2)
        body||=dl||"0d0a"x
      end
      msg=.SmtpMessage~new(env,body); acceptResult=service~acceptInbound(session,msg)
      if acceptResult~ok then ignore=self~sendLine(transport,"250 2.0.0 Accepted")
      else if acceptResult~code~pos("QUARANTINE")>0 then ignore=self~sendLine(transport,"250 2.0.0 Accepted for policy quarantine")
      else ignore=self~sendLine(transport,"550 5.7.1 "||acceptResult~code)
      env=.SmtpEnvelope~new; iterate
    end
    if upper="RSET" then do; env=.SmtpEnvelope~new; ignore=self~sendLine(transport,"250 2.0.0 Reset"); iterate; end
    if upper="NOOP" then do; ignore=self~sendLine(transport,"250 2.0.0 OK"); iterate; end
    if upper="QUIT" then do; ignore=self~sendLine(transport,"221 2.0.0 Bye"); leave; end
    ignore=self~sendLine(transport,"502 5.5.2 Command not implemented")
  end
  transport~close
  return
clientFailure:
  say "SMTP client failure rc=" rc "sigl=" sigl "condition=" condition("C") "detail=" condition("D")
  if transport<>.nil then transport~close
  return

::requires "socket.cls"
::requires "src/SmtpCore.cls"
::requires "src/SecureSocket.cls"
