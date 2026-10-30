/* XtpSession.cls: ooRexx interface to XTP interactive contexts (libxtp dev31; evidence dev36).
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
  use strict arg peer, services = '', requireProtection = .false
  /* dev32: a service with keys always requires its protection profile;
   * requireProtection also refuses unprotected opens of services without keys. */
  if requireProtection then flag = 1
  else flag = 0
  handle = xtpNativeSessionListen(peer, services, flag)

/* The next opened session, or .nil when timeoutMs passes (-1 waits). */
::method accept unguarded
  expose handle
  use strict arg timeoutMs = (-1)
  sessionHandle = xtpNativeSessionAccept(handle, timeoutMs)
  if sessionHandle = 0 then return .nil
  return .XtpSession~new(sessionHandle, 'acceptor')

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
  use strict arg peer, service, openTimeoutMs = 3000, protection = 'auto', keyPrincipal = ''
  /* dev32: protection 'auto' uses the service's profile (rexx/XtpServiceKeys.cls
   * installs the keys); 'none', 'authenticate' or 'encrypt' sets a minimum.
   * dev35: keyPrincipal opens with the keys held for that principal (a
   * client's keys, gateway mode B); '' uses the service's own keys. */
  return self~new(xtpNativeSessionOpen(peer, service, openTimeoutMs, protection, keyPrincipal), 'opener')

/* dev36: protection evidence for a session not yet opened (docs/SECURITY.md,
 * "Protection evidence").  What an open of service on the route of peer would
 * get now, from libxtp's route table and key table; no secrets.  principal and
 * minimum are the same as open's keyPrincipal and protection.  A directory
 * with BOUND = 'route'; see evidence below for the indexes. */
::method serviceEvidence class
  use strict arg peer, service, keyPrincipal = '', minimum = 'auto', mode = ''
  /* mode: 'session' or 'message', as the caller's socket will be (XtpSocketBackend sets it) */
  text = xtpNativeServiceEvidence(peer, service, keyPrincipal, minimum)
  if mode <> '' then text = 'mode='mode text
  return xtpEvidenceDirectory('route', '', text)

::method init
  expose handle lastFlag role finalEvidence
  use strict arg handle, role = ''
  lastFlag = ''
  finalEvidence = ''

/* 'opener' (from open) or 'acceptor' (from a listener's accept). */
::attribute role get unguarded

/* dev36: protection evidence bound to this session, read from libxtp now; no
 * secrets.  A directory:
 *   SCHEMA 'xtp.protection.evidence/1'   BOUND 'session'   ROLE opener|acceptor
 *   SERVICE PEER OPEN PROTECTION SUITE KEYID KEYPRINCIPAL PROFILE
 *   KEYSUITE KEYSOURCE KEYSTATE KEYNOTAFTERMS ATMS
 *   LINE  the same as one line of text, for a receipt
 * A value that does not apply is '-'.  After close or abort: the record read
 * as the session was released, with OPEN 0 (review 5). */
::method evidence unguarded
  expose handle role finalEvidence
  if handle = 0 then do
    if finalEvidence = '' then raise syntax 88.900 array('XTP session evidence: the session was never open')
    return xtpEvidenceDirectory('session', role, finalEvidence)
  end
  return xtpEvidenceDirectory('session', role, xtpNativeSessionEvidence(handle))

/* Keep the evidence of a session being released, marked closed. */
::method keepFinalEvidence private unguarded
  expose handle finalEvidence
  signal on syntax name noEvidence
  text = xtpNativeSessionEvidence(handle)
  parse var text before ' open=' . after
  finalEvidence = before 'open=0' after
  return
noEvidence:
  return

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
  self~keepFinalEvidence
  closed = xtpNativeSessionClose(handle, timeoutMs)
  handle = 0
  return closed = 1

::method abort unguarded
  expose handle
  if handle <> 0 then do
    self~keepFinalEvidence
    call xtpNativeSessionAbort handle
  end
  handle = 0
  return 0

/* A session dropped without close is aborted, so its socket, thread and the
 * peer are not left waiting. */
::method uninit
  expose handle
  if handle <> 0 then call xtpNativeSessionAbort handle
  handle = 0

/* A directory: KEY SERVICE PEER OPEN PEERCLOSED SRTTMS RETRANSMITTED PROTECTION
 * KEYID AUTHFAILURES REPLAYSREJECTED WRITTEN READ ERROR (PROTECTION and after: dev32). */
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

::routine xtpEvidenceDirectory
  use strict arg bound, role, text
  line = 'schema=xtp.protection.evidence/1 bound='bound
  if bound = 'session' then do
    if role = '' then role = '-'
    line = line 'role='role
  end
  line = line text
  evidence = .directory~new
  do word over line~makeArray(' ')
    if word = '' then iterate
    parse var word name '=' value
    evidence[name~upper] = value
  end
  evidence['LINE'] = line
  return evidence

::routine xtpNativeSessionEvidence external "library oorexx_xtp_native xtpNativeSessionEvidence"
::routine xtpNativeServiceEvidence external "library oorexx_xtp_native xtpNativeServiceEvidence"
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
