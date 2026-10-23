/* Social Media v0.1-dev4 — publication journal boundary.
 * The production SPI requires ordered, durable, acknowledged save() and replay().
 * File implementation is a single-writer development adapter ONLY: close() is
 * NOT fsync, and no interprocess locking, tamper-proof MAC or atomicity is claimed.
 * It recovers process restarts, not machine crashes or malicious edits. */
::class SocialPublicationJournal public
::method replay abstract
::method save abstract

/* Development file journal: append complete snapshots of a publication receipt.
 * Every record is hex-framed, sequence-numbered and checksum-detected.
 * Detects torn/edited records; arithmetic checksum is not authentication. */
::class SocialFilePublicationJournal public subclass SocialPublicationJournal
::method filename attribute
::method sequence attribute
::method init
  expose filename sequence
  use strict arg filename
  if filename == '' then raise syntax 93.900 array ('Journal path required')
  sequence = 0
  /* On construction fail closed against corrupted files. */
  recovered = self~replay
::method checksum private
  use strict arg value
  numeric digits 20
  h = 0
  do i = 1 to length(value)
    b = x2d(c2x(substr(value,i,1)))
    h = (h * 131 + b) // 2147483647
  end
  return h
::method serialize private
  use strict arg ticket
  data = ticket~context
  fields = .array~of(ticket~requestId, ticket~fingerprint, ticket~providerId, ticket~status, -
     ticket~providerStatus, ticket~providerEvidence, ticket~detail, data['brandId'], -
     data['accountId'], data['surfaceKey'], data['action'], data['contentId'], -
     data['contentVersion'], data['body'], data['approvalRef'], data['intentionRef'], -
     data['narrativeRef'], data['parentKey'], data['surfaceFamily'])
  fields~append(data['assets']~items)
  do asset over data['assets']
    fields~append(asset)
  end
  encoded = ''
  do i = 1 to fields~items
    if i > 1 then encoded ||= '|'
    encoded ||= c2x(fields[i]~string)
  end
  return encoded
::method deserialize private
  use strict arg payload
  cols = payload~makearray('|')
  if cols~items < 20 then raise syntax 93.900 array ('Truncated social journal snapshot')
  data = .array~new
  do i = 1 to cols~items
    if (length(cols[i]) // 2) <> 0 then raise syntax 93.900 array ('Malformed hex journal payload')
    data~append(x2c(cols[i]))
  end
  if data[1] == '' | data[2] == '' | data[3] == '' then raise syntax 93.900 array ('Journal identity missing')
  if \datatype(data[20],'W') then raise syntax 93.900 array ('Journal asset count not an integer')
  count = data[20] + 0
  if count < 0 | data~items <> 20 + count then raise syntax 93.900 array ('Journal asset count mismatch')
  ctx = .directory~new
  ctx['requestId'] = data[1]
  ctx['providerId'] = data[3]
  ctx['brandId'] = data[8]
  ctx['accountId'] = data[9]
  ctx['surfaceKey'] = data[10]
  ctx['action'] = data[11]
  ctx['contentId'] = data[12]
  ctx['contentVersion'] = data[13]
  ctx['body'] = data[14]
  ctx['approvalRef'] = data[15]
  ctx['intentionRef'] = data[16]
  ctx['narrativeRef'] = data[17]
  ctx['parentKey'] = data[18]
  ctx['surfaceFamily'] = data[19]
  assets = .array~new
  do i = 21 to data~items
    assets~append(data[i])
  end
  ctx['assets'] = assets
  ticket = .SocialPublicationReceipt~new
  ticket~requestId = data[1]
  ticket~fingerprint = data[2]
  ticket~providerId = data[3]
  ticket~status = data[4]
  ticket~providerStatus = data[5]
  ticket~providerEvidence = data[6]
  ticket~detail = data[7]
  ticket~context = ctx
  return ticket
::method replay
  expose filename sequence
  numeric digits 20
  journal = .directory~new
  sequence = 0
  if stream(filename, 'c', 'query exists') == '' then return journal
  state = stream(filename, 'c', 'open read')
  if left(state,5) <> 'READY' then raise syntax 93.900 array ('Unable to read social journal')
  signal on syntax name badJournal
  do while lines(filename) > 0
    line = linein(filename)
    parse var line schema '|' seq '|' crc '|' payload
    if schema <> 'social.outbox/0.1' then raise syntax 93.900 array ('Unknown outbox record schema')
    if \datatype(seq,'W') | \datatype(crc,'W') then raise syntax 93.900 array ('Corrupt outbox record sequence/checksum')
    if seq <> sequence + 1 then raise syntax 93.900 array ('Outbox sequence gap or replay')
    if self~checksum(seq || '|' || payload) <> crc then raise syntax 93.900 array ('Outbox record checksum mismatch')
    ticket = self~deserialize(payload)
    if journal~hasIndex(ticket~requestId) then do
      old = journal[ticket~requestId]
      if old~fingerprint <> ticket~fingerprint then raise syntax 93.900 array ('Outbox ID collision during replay')
      if old~providerId <> ticket~providerId then raise syntax 93.900 array ('Outbox provider changed during replay')
      select
        when old~status == 'prepared' then do
          if ticket~status <> 'dispatching' & ticket~status <> 'unknown' then raise syntax 93.900 array ('Invalid prepared transition')
        end
        when old~status == 'dispatching' then do
          if ticket~status <> 'unknown' & ticket~status <> 'submitted' & ticket~status <> 'rejected' & ticket~status <> 'simulated' then raise syntax 93.900 array ('Invalid dispatch transition')
        end
        when old~status == 'unknown' | old~status == 'submitted' then do
          if ticket~status <> 'delivered' & ticket~status <> 'rejected' then raise syntax 93.900 array ('Invalid reconciliation transition')
        end
        otherwise raise syntax 93.900 array ('Terminal outbox record overwritten')
      end
    end
    else if ticket~status <> 'prepared' then raise syntax 93.900 array ('Missing outbox prepared record')
    journal[ticket~requestId] = ticket
    sequence += 1
  end
  call stream filename,'c','close'
  /* In-flight on restart must be treated as unknown, never auto-dispatched. */
  do id over journal~allIndexes
    ticket = journal[id]
    if ticket~status == 'prepared' | ticket~status == 'dispatching' then do
      ticket~status = 'unknown'
      ticket~detail = 'Interrupted publication; reconcile before any new action'
      /* Durable recovery marker permits subsequent verified terminal evidence. */
      self~save(ticket)
    end
  end
  return journal
  badJournal:
    call stream filename,'c','close'
    raise syntax 93.900 array ('Publication journal corrupt/incomplete: no dispatch permitted')
::method save
  expose filename sequence
  numeric digits 20
  use strict arg ticket
  seq = sequence + 1
  payload = self~serialize(ticket)
  crc = self~checksum(seq || '|' || payload)
  row = 'social.outbox/0.1|' || seq || '|' || crc || '|' || payload
  state = stream(filename,'c','open append')
  if left(state,5) <> 'READY' then raise syntax 93.900 array ('Outbox journal unavailable: cannot dispatch')
  written = lineout(filename,row)
  closed = stream(filename,'c','close')
  if written <> 0 | left(closed,5) <> 'READY' then raise syntax 93.900 array ('Outbox journal write failed: no dispatch')
  sequence = seq
  return .true

::requires 'SocialPublication.cls'
