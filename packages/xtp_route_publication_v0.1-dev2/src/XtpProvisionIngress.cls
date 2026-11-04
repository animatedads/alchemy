/* XtpProvisionIngress.cls - fail-closed ingress for xtp.provision/1
 * Architecture: Tom Dyer. Code: ChatGPT GPT-6, 29 October 2026.
 * Consumes XtpSession dev34+ protected context evidence; never opens routes,
 * edits service registrations, or treats service-key possession as MI identity.
 * A trusted resolver MUST validate unique per-principal key ownership and
 * current directory ACL/epoch. Shared service keys are not enrollment proof.
 */
::class XtpProvisionIngress public
::method init
  expose resolver maxBytes maxFrames timeoutMs requiredService
  use strict arg resolver, maxBytes = 65536, maxFrames = 64, timeoutMs = 5000
  requiredService = 'xtp.provision'
  if resolver = .nil then raise syntax 93.900 array('trusted resolver required')
  if \maxBytes~datatype('W') then raise syntax 93.900 array('invalid maxBytes')
  if maxBytes < 1 | maxBytes > 1048576 then raise syntax 93.900 array('invalid maxBytes')
  if \maxFrames~datatype('W') then raise syntax 93.900 array('invalid maxFrames')
  if maxFrames < 1 | maxFrames > 1024 then raise syntax 93.900 array('invalid maxFrames')
  if \timeoutMs~datatype('W') then raise syntax 93.900 array('invalid timeoutMs')
  if timeoutMs < 1 | timeoutMs > 60000 then raise syntax 93.900 array('invalid timeoutMs')

::method rejected private
  use strict arg reason
  r = .directory~new
  r['OK'] = .false
  r['REASON'] = reason
  return r

::method authorize
  expose resolver requiredService
  use strict arg session
  if session = .nil then return self~rejected('SESSION_REQUIRED')
  signal on any name rejectedException
  info = session~info
  if info = .nil then return self~rejected('SESSION_INFO_REQUIRED')
  if \info~isInstanceOf(.directory) then return self~rejected('SESSION_INFO_REQUIRED')
  if \info~hasIndex('SERVICE') then return self~rejected('SERVICE_MISSING')
  if info['SERVICE'] <> requiredService then return self~rejected('SERVICE_MISMATCH')
  if \info~hasIndex('OPEN') then return self~rejected('SESSION_NOT_OPEN')
  if info['OPEN'] <> '1' then return self~rejected('SESSION_NOT_OPEN')
  if \info~hasIndex('PROTECTION') then return self~rejected('ENCRYPTION_REQUIRED')
  if info['PROTECTION'] <> 'encrypt' then return self~rejected('ENCRYPTION_REQUIRED')
  if \info~hasIndex('KEYID') then return self~rejected('KEY_ID_REQUIRED')
  key = info['KEYID']
  if key~length <> 16 then return self~rejected('KEY_ID_INVALID')
  if key~verify('0123456789ABCDEFabcdef') <> 0 then return self~rejected('KEY_ID_INVALID')
  if key = '0000000000000000' then return self~rejected('KEY_ID_INVALID')
  /* This resolver is a privileged adapter, not a caller-supplied claim. */
  identity = resolver~resolveSession(info)
  if identity = .nil then return self~rejected('IDENTITY_UNRESOLVED')
  if \identity~isInstanceOf(.directory) then return self~rejected('IDENTITY_UNRESOLVED')
  if \identity~hasIndex('OK') then return self~rejected('IDENTITY_UNRESOLVED')
  if identity['OK'] <> .true then return self~rejected('IDENTITY_DENIED')
  if \identity~hasIndex('EXCLUSIVE') then return self~rejected('EXCLUSIVE_KEY_REQUIRED')
  if identity['EXCLUSIVE'] <> .true then return self~rejected('EXCLUSIVE_KEY_REQUIRED')
  if \identity~hasIndex('KEYID') then return self~rejected('KEY_BINDING_MISMATCH')
  if identity['KEYID'] <> key then return self~rejected('KEY_BINDING_MISMATCH')
  if \identity~hasIndex('SERVICE') then return self~rejected('KEY_SERVICE_MISMATCH')
  if identity['SERVICE'] <> requiredService then return self~rejected('KEY_SERVICE_MISMATCH')
  if \identity~hasIndex('PRINCIPAL') then return self~rejected('PRINCIPAL_REQUIRED')
  principal = identity['PRINCIPAL']
  if principal~length < 4 | principal~length > 128 then return self~rejected('PRINCIPAL_INVALID')
  if principal~left(3) <> 'mi:' then return self~rejected('PRINCIPAL_INVALID')
  if principal~verify('abcdefghijklmnopqrstuvwxyz0123456789._:-') <> 0 then return self~rejected('PRINCIPAL_INVALID')
  if \identity~hasIndex('AUTHORITY') then return self~rejected('AUTHORITY_REQUIRED')
  if identity['AUTHORITY'] <> 'LDAP' & identity['AUTHORITY'] <> 'SIGNED_FILE' then return self~rejected('AUTHORITY_REQUIRED')
  if \identity~hasIndex('FENCED') then return self~rejected('FENCE_REQUIRED')
  if identity['FENCED'] <> .true then return self~rejected('FENCE_REQUIRED')
  verdict = .directory~new
  verdict['OK'] = .true
  verdict['REASON'] = 'ADMITTED'
  verdict['PRINCIPAL'] = principal
  verdict['KEYID'] = key
  verdict['SERVICE'] = requiredService
  verdict['AUTHORITY'] = identity['AUTHORITY']
  return verdict
rejectedException:
  return self~rejected('AUTHORITY_EXCEPTION')

::method receive
  expose maxBytes maxFrames timeoutMs
  use strict arg session
  verdict = self~authorize(session)
  if \verdict['OK'] then do
    if session <> .nil then session~abort
    return verdict
  end
  signal on any name readException
  payload = ''
  do frame = 1 to maxFrames
    /* Read at most maxBytes+1, so reject before allocating unbounded input. */
    remaining = maxBytes - payload~length
    request = remaining + 1
    if request > 4096 then request = 4096
    chunk = session~read(request, timeoutMs)
    flag = session~lastFlag
    if chunk~length > request then do
      session~abort
      return self~rejected('FRAME_EXCEEDS_READ_BOUND')
    end
    if payload~length + chunk~length > maxBytes then do
      session~abort
      return self~rejected('REQUEST_TOO_LARGE')
    end
    if flag = 'TIMEOUT' then do
      session~abort
      return self~rejected('REQUEST_TIMEOUT')
    end
    if flag = 'END' then do
      session~abort
      return self~rejected('REQUEST_INCOMPLETE')
    end
    if flag <> '' & flag <> 'EOM' then do
      session~abort
      return self~rejected('INVALID_FRAME_FLAG')
    end
    payload = payload || chunk
    if flag = 'EOM' then do
      if payload = '' then do
        session~abort
        return self~rejected('EMPTY_REQUEST')
      end
      verdict['PAYLOAD'] = payload
      verdict['FRAMES'] = frame
      return verdict
    end
    if chunk = '' then do
      session~abort
      return self~rejected('NO_PROGRESS')
    end
  end
  session~abort
  return self~rejected('FRAME_COUNT_EXCEEDED')
readException:
  session~abort
  return self~rejected('READ_EXCEPTION')
