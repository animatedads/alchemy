/* SMTP -> platform Socket Provider acquisition bridge.
 *
 * SMTP owns SMTP sequencing and STARTTLS protocol timing.  Socket Provider owns
 * native TCP acquisition.  The existing secure.socket/OpenSSL provider owns the
 * in-place TLS upgrade after the SMTP peer has returned 220 to STARTTLS.
 */
::class SmtpSocketProviderBuild public
::constant API "smtp.socket.provider.binding/0.1"

::class SmtpSocketConnector public
::method connect abstract

::class SmtpRxSockConnector subclass SmtpSocketConnector public
::method connect
  use strict arg hop
  socket=.Socket~new
  if socket~connect(.InetAddress~new(hop~host,hop~port))<0 then
    return .SmtpResult~failure("NEXT_HOP_CONNECT_FAILED","errno="||socket~errno)
  return .SmtpResult~success(socket,"RXSOCK_CONNECTED")

::class SmtpPlatformSocketConnector subclass SmtpSocketConnector public
::method init
  expose socketProvider logicalPrefix
  use strict arg socketProviderArg,logicalPrefixArg="smtp.next-hop"
  if socketProviderArg==.nil then raise syntax 88.900 array("SocketProvider is required")
  socketProvider=socketProviderArg
  logicalPrefix=logicalPrefixArg~string
::method connect
  expose socketProvider logicalPrefix
  use strict arg hop
  meta=.directory~new
  meta["protocol"]="SMTP"
  meta["role"]="NEXT_HOP"
  address=.SocketAddresses~tcp(hop~host,hop~port,logicalPrefix||":"||hop~key,meta)
  endpoint=socketProvider~senderAt(address)
  if endpoint==.nil then return .SmtpResult~failure("NEXT_HOP_CONNECT_FAILED","SocketProvider returned .nil")
  return .SmtpResult~success(endpoint,"SOCKET_PROVIDER_CONNECTED")

::requires "SmtpCore.cls"
::requires "socket.cls"
::requires "SocketProvider.cls"
