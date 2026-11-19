/* WorkflowMailbox.cls - Alchemy Workflow v0.1-dev1: posting the failure reports to the Rasen Falcon mailbox.
 *
 * Architecture: Tom Dyer (a failure sends a message back to the task telling it what it did wrong).
 * Code: Claude (Opus 5.5), 2026-11-19.
 *
 * The HTTPS side is not written again here: it is MailboxClient (oorexx_browser_ui_kit_v0.4, Claude
 * (Opus 5.5), 10 Nov 2026), which keeps the bearer token off every command line and out of every log. This
 * class adds what the workflow needs on top of it:
 *   - create(lane, recipient, type, subject, body): MailboxClient has reply but no create;
 *   - post(file): one outbox message; a reply when it names a parent request, else a new request on its lane;
 *   - postAll(outboxDir): every message waiting there. A posted message moves to outboxDir/sent with a
 *     .posted file beside it (request id, when, principal, the nudge); one that fails stays where it is, with
 *     its error in a .error file, and the next run tries it again. Nothing is posted twice.
 *
 * The nudge (the one sentence that tells the chat to look in its mailbox) is kept in the .posted file for the
 * nudger (MailNudger in the same kit), which owns the lane-to-chat map. This class does not drive a browser.
 */
::requires 'MailboxClient.cls'
::requires 'AlchemyWorkflow.cls'
::requires 'json.cls'

::class WorkflowMailboxCheck public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-19'
::attribute items get

::method init
  expose items
  items = .array~new

/* the shape MailboxClient~ready expects: add(level, what, text) */
::method add
  expose items
  use strict arg level, what, text
  items~append(level what || ':' text)

::method stopped
  expose items
  do t over items
    if t~word(1) == 'STOP' then return .true
  end
  return .false

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowMailbox public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-19'
::attribute client get
::attribute log get

::method init
  expose client log
  use strict arg client, log

/* a new request on a lane; the answer is MailboxClient's .directory (ok, code, value, text, error) */
::method create
  expose client
  use strict arg lane, recipient, type, subject, body
  a = .directory~new
  a['componentId'] = .JsonString~new(lane)
  a['recipientId'] = .JsonString~new(recipient)
  a['requestType'] = .JsonString~new(type)
  a['subject'] = .JsonString~new(subject)
  a['body'] = .JsonString~new(body)
  return client~call('project.request.create', a)

::method readMessage
  use strict arg path
  s = .stream~new(path)
  if s~open('read shareread') \= 'READY:' then return .nil
  text = s~charIn(1, s~chars)
  s~close
  return mbParse(text)

/* one outbox message: a .directory (ok, requestId, error) */
::method post
  expose client
  use strict arg path
  out = .directory~new
  out['ok'] = .false
  out['requestId'] = ''
  out['error'] = ''
  m = self~readMessage(path)
  if \m~isA(.Directory) then do
    out['error'] = 'not a readable outbox message'
    return out
  end
  do k over .array~of('recipientId', 'componentId', 'subject', 'body')
    if m[k] == .nil then do
      out['error'] = 'the message has no' k
      return out
    end
  end
  parent = ''
  if m['parentRequestId'] \== .nil then parent = m['parentRequestId']~string
  if parent \== '' then answer = client~reply(parent, m['body']~string, m['subject']~string)
  else answer = self~create(m['componentId']~string, m['recipientId']~string, 'workflow', m['subject']~string, m['body']~string)
  if \answer['ok'] then do
    out['error'] = answer['error']
    return out
  end
  if answer['value']~isA(.Directory) then if answer['value']['requestId'] \== .nil then out['requestId'] = answer['value']['requestId']~string
  out['ok'] = .true
  return out

/* every message waiting in outboxDir; returns (posted, failed) */
::method postAll
  expose client log
  use strict arg outboxDir
  sent = outboxDir || '/sent'
  call SysMkDir sent
  call SysFileTree outboxDir || '/*.json', 'f.', 'FO'
  waiting = .array~new
  do i = 1 to f.0
    waiting~append(f.i)
  end
  posted = 0
  failed = 0
  do path over waiting~sort
    name = path~substr(path~lastPos('/') + 1)
    m = self~readMessage(path)
    log~info('posting' name)
    r = self~post(path)
    if \r['ok'] then do
      failed += 1
      call wfWriteFile path || '.error', .DateTime~new~isoDate r['error']
      log~error('not posted:' name '|' r['error'])
      iterate
    end
    posted += 1
    nudge = ''
    if m~isA(.Directory) then if m['nudge'] \== .nil then nudge = m['nudge']~string
    rec = 'requestId' r['requestId'] || '0a'x || 'postedAt' .DateTime~new~isoDate || '0a'x || 'principal' client~principal || '0a'x || 'nudge' nudge
    call wfWriteFile sent || '/' || name || '.posted', rec
    address system 'mv -f' wfq(path) wfq(sent || '/' || name)
    call SysFileDelete path || '.error'
    log~info('posted' name 'as' r['requestId'])
  end
  return .array~of(posted, failed)

::routine wfWriteFile public
  use strict arg path, text
  call SysFileDelete path
  s = .stream~new(path)
  s~open('write replace')
  s~lineOut(text)
  s~close
  return
