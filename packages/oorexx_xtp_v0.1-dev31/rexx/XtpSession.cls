/* XtpSession.cls: ooRexx interface to XTP interactive contexts (libxtp dev31).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 *
 * An XtpSession is one XTP context that stays open in both directions: bytes
 * arrive in order as they are sent, messages keep their boundaries (EOM), and
 * each end closes its own sending direction (shutdown) independently.
 * Routes come from the XTP route table (XTP_ROUTE_FILE), as for
 * XtpSocketProvider; a named service is required.  See docs/SESSIONS.md.
 *
 * read, write and accept block, so they are unguarded: one thread may read
 * while another writes the same session.
 */
::class XtpSessionListener public
::method init
  expose handle
  use strict arg peer, services = ''
  handle = xtpNativeSessionListen(peer, services)

/* The next opened session, or .nil when timeoutMs passes (-1 waits). */
::method accept unguarded
  expose handle
  use strict arg timeoutMs = (-1)
  sessionHandle = xtpNativeSessionAccept(handle, timeoutMs)
  if sessionHandle = 0 then return .nil
  return .XtpSession~new(sessionHandle)

/* Stop accepting; sessions already accepted continue. */
::method close
  expose handle
  if handle <> 0 then call xtpNativeSessionListenerClose handle
  handle = 0
  return 0

/* A listener dropped without close still releases its socket and thread. */
::method uninit
  expose handle
  if handle <> 0 then call xtpNativeSessionListenerClose handle
  handle = 0

::class XtpSession public
/* Open an interactive context to a named service on the route of peer.
 * Raises a syntax error with the peer's reason if it refuses. */
::method open class
  use strict arg peer, service, openTimeoutMs = 3000
  return self~new(xtpNativeSessionOpen(peer, service, openTimeoutMs))

::method init
  expose handle lastFlag
  use strict arg handle
  lastFlag = ''

/* After read: 'EOM' (the bytes end a message), 'END' (the peer has closed its
 * direction), 'TIMEOUT', or ''. */
::attribute lastFlag get unguarded

/* Queue data; eom = .true ends a message (data must not be empty then).
 * Blocks while the peer is not reading.  Returns the number of bytes. */
::method write unguarded
  expose handle
  use strict arg data, eom = .false, timeoutMs = (-1)
  if eom then flag = 1
  else flag = 0
  return xtpNativeSessionWrite(handle, data, flag, timeoutMs)

::method writeMessage unguarded
  use strict arg data
  return self~write(data, .true)

/* Up to maxBytes, never past a message boundary; see lastFlag. */
::method read unguarded
  expose handle lastFlag
  use strict arg maxBytes = 65536, timeoutMs = (-1)
  answer = xtpNativeSessionRead(handle, maxBytes, timeoutMs)
  lastFlag = answer[2]
  return answer[1]

/* One whole message.  Returns .nil if the peer closed its direction first. */
::method readMessage unguarded
  use strict arg timeoutMs = (-1)
  message = ''
  do forever
    chunk = self~read(65536, timeoutMs)
    flag = self~lastFlag
    if flag = 'END' then do
      if message <> '' then raise syntax 98.900 array('XTP session ended inside a message')
      return .nil
    end
    if flag = 'TIMEOUT' then raise syntax 98.900 array('XTP session read timed out')
    message = message || chunk
    if flag = 'EOM' then return message
  end

/* Everything until the peer closes its direction. */
::method readAll unguarded
  use strict arg timeoutMs = (-1)
  data = ''
  do forever
    chunk = self~read(65536, timeoutMs)
    flag = self~lastFlag
    if flag = 'END' then return data
    if flag = 'TIMEOUT' then raise syntax 98.900 array('XTP session read timed out')
    data = data || chunk
  end

/* Close our sending direction; reading continues. */
::method shutdown unguarded
  expose handle
  call xtpNativeSessionShutdown handle
  return 0

/* shutdown, then wait for the peer to close too.  .true if both directions
 * closed cleanly; otherwise the context is aborted.  Releases the session. */
::method close unguarded
  expose handle
  use strict arg timeoutMs = 5000
  if handle = 0 then return .false
  closed = xtpNativeSessionClose(handle, timeoutMs)
  handle = 0
  return closed = 1

::method abort unguarded
  expose handle
  if handle <> 0 then call xtpNativeSessionAbort handle
  handle = 0
  return 0

/* A session dropped without close is aborted, so its socket, thread and the
 * peer are not left waiting. */
::method uninit
  expose handle
  if handle <> 0 then call xtpNativeSessionAbort handle
  handle = 0

/* A directory: KEY SERVICE PEER OPEN PEERCLOSED SRTTMS RETRANSMITTED WRITTEN READ ERROR. */
::method info unguarded
  expose handle
  text = xtpNativeSessionInfo(handle)
  parse var text before 'error=' errorText
  info = .directory~new
  do word over before~makeArray(' ')
    if word = '' then iterate
    parse var word name '=' value
    info[name~upper] = value
  end
  info['ERROR'] = errorText
  return info

::routine xtpNativeSessionListen external "library oorexx_xtp_native xtpNativeSessionListen"
::routine xtpNativeSessionAccept external "library oorexx_xtp_native xtpNativeSessionAccept"
::routine xtpNativeSessionListenerClose external "library oorexx_xtp_native xtpNativeSessionListenerClose"
::routine xtpNativeSessionOpen external "library oorexx_xtp_native xtpNativeSessionOpen"
::routine xtpNativeSessionWrite external "library oorexx_xtp_native xtpNativeSessionWrite"
::routine xtpNativeSessionRead external "library oorexx_xtp_native xtpNativeSessionRead"
::routine xtpNativeSessionShutdown external "library oorexx_xtp_native xtpNativeSessionShutdown"
::routine xtpNativeSessionClose external "library oorexx_xtp_native xtpNativeSessionClose"
::routine xtpNativeSessionAbort external "library oorexx_xtp_native xtpNativeSessionAbort"
::routine xtpNativeSessionInfo external "library oorexx_xtp_native xtpNativeSessionInfo"
