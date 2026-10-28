/* test_rxsock_shutdown_route.rex - "test 0": can an ooRexx .Socket be
 * half-closed with SockShutDown(socket~string, 1), and what does .Socket~recv
 * return at end of stream? Raw sockets on 127.0.0.1 only, no provider logic.
 * Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
 */
call main
exit 0

main:
  port=39191
  server=.nil; client=.nil; connected=.false
  server=.Socket~new()
  call check server<>-1,"server socket created"
  call check server~setOption("SO_REUSEADDR",1)<>-1,"SO_REUSEADDR set"
  call check server~bind(.InetAddress~new("127.0.0.1",port))<>-1,"server bound"
  call check server~listen(4)<>-1,"server listening"
  worker=.RouteWorker~new
  worker~run(server)
  call SysSleep .2

  client=.Socket~new()
  call check client<>-1,"client socket created"
  connected=client~connect(.InetAddress~new("127.0.0.1",port))<>-1
  call check connected,"client connected"
  say "INFO client descriptor:" client~string
  call check datatype(client~string,"W"),"socket string value is a whole number (the descriptor)"

  call check client~send("HELLO")=5,"client sent 5 bytes"
  rc=SockShutDown(client~string,1)
  say "INFO SockShutDown rc:" rc
  call check rc=0,"SockShutDown(fd,1) returned 0"

  /* The server answers only after it has seen end of stream. */
  answer=""
  do 20
    chunk=client~recv(64)
    if chunk=.nil then leave
    if chunk=="" then leave
    answer=answer||chunk
  end
  say "INFO client read after half-close:" answer
  call check answer=="SAW-EOF:HELLO","server saw end of stream and could still reply"
  /* No raw send after SHUT_WR here: on Linux it raises SIGPIPE unless the
   * library ignores it. ProviderSocketConnection refuses that send locally. */

  final=client~recv(64)
  say "INFO client recv at end of stream:" describe(final)
  ignore=client~close
  ignore=server~close
  say "INFO server recv at end of stream:" worker~eofValue
  call check worker~eofValue=="EMPTY_STRING","server .Socket~recv returns empty string at end of stream"
  say "PASS RxSock SockShutDown half-close route"
  return

describe: procedure
  use arg value
  if value=.nil then return "NIL"
  if value=="" then return "EMPTY_STRING"
  return "DATA("length(value)")"

/* A failure must first release the worker thread, which may be blocked in
 * accept or recv; otherwise ooRexx waits for it and the run hangs. */
check:
  use strict arg ok,label
  if ok then do; say "ok" label; return; end
  say "FAIL:" label
  if server<>.nil & server<>-1 then do
    if \connected then do
      probe=.Socket~new()
      if probe<>-1 then do
        ignore=probe~connect(.InetAddress~new("127.0.0.1",port))
        ignore=probe~close
      end
    end
  end
  if client<>.nil & client<>-1 then ignore=client~close
  if server<>.nil & server<>-1 then ignore=server~close
  exit 1

::class RouteWorker public
::method init
  expose eofValue
  eofValue="NOT_SEEN"
::attribute eofValue get
::method run
  expose eofValue
  use strict arg server
  reply
  peer=server~accept
  if peer=.nil then return
  got=""
  do 20
    chunk=peer~recv(64)
    if chunk=.nil then do; eofValue="NIL"; leave; end
    if chunk=="" then do; eofValue="EMPTY_STRING"; leave; end
    got=got||chunk
  end
  ignore=peer~send("SAW-EOF:"||got)
  ignore=peer~close
  return

::requires "socket.cls"
