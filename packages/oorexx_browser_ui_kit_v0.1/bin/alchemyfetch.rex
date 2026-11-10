/* alchemyfetch.rex -- the ALCHEMYFETCH principal: read its mailbox, put every request through the OrderGate,
 * reply to the sender with the report, mark the request read, and nudge the sender's chat.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 10 November 2026.
 * Legal Effect v0.14: ChatGPT.  Boston Crab (free-text orders, when BOSTON_CRAB_DIR is set): its own chat.
 *
 *   bin/kit.sh rexx bin/alchemyfetch.rex --once          one pass over the inbox, then stop
 *   bin/kit.sh rexx bin/alchemyfetch.rex                 keep polling (poll_seconds in etc/fetch.conf)
 *
 * The nudge (Tom's contract) carries only the request id:
 *   "The event you registered a request for REQ-... has occurred, check Rasen Falcon MCP."
 * It is typed into the conversation that etc/nudge.conf maps the request's lane to; a lane with no mapping
 * gets the mailbox reply only.  Settings (etc/fetch.conf, overridden by var/fetch.local.conf):
 *   mailbox_url   default https://rasenfalcon.duckdns.org/mcp
 *   token_file    default $HOME/.config/alchemy/alchemyfetch.token (mode 600, made by the mailbox admin CLI)
 *   poll_seconds  default 30
 * Log: var/events-YYYYMMDD.log through oorexx_logging, and progress on the terminal.
 */
parse arg args
once=(wordpos('--once', args)>0)
kit=value('KIT',, 'ENVIRONMENT')
conf=fxReadConf(kit'/etc/fetch.conf')
localFile=value('ALCHEMYFETCH_LOCAL_CONF',, 'ENVIRONMENT')
if localFile=='' then localFile=kit'/var/fetch.local.conf'
local=fxReadConf(localFile)
do k over local~allIndexes
  conf[k]=local[k]
end
log=uiLog(kit, 'alchemyfetch')
policy=.FetchPolicy~new(conf)
issuers=fxWords(conf, 'order_issuers', 'TOM')~makeString('L', ' ')~upper~makeArray(' ')
tools=.directory~new
tools['curl']=value('FETCH_CURL',, 'ENVIRONMENT')
if tools['curl']=='' then tools['curl']='curl'
tools['svn']=value('FETCH_SVN',, 'ENVIRONMENT')
if tools['svn']=='' then tools['svn']='svn'
crab=value('BOSTON_CRAB_DIR',, 'ENVIRONMENT')
if crab<>'' then reader=.BostonCrabReader~new(policy, issuers, crab, policy~storeDir'/stories', kit'/etc/fetch.catalogue', fxWords(conf, 'fetch_actions', 'download get retrieve')~makeString('L', ' '))
else reader=.FetchOrderReader~new(policy, issuers)
gate=.OrderGate~new('ALCHEMYFETCH', reader, .FetchRules~new(policy, issuers), .FetchExecutor~new(policy, tools), log, policy~storeDir'/traces')
url=fxStr(conf, 'mailbox_url', 'https://rasenfalcon.duckdns.org/mcp')
tokenFile=fxStr(conf, 'token_file', '$HOME/.config/alchemy/alchemyfetch.token')
mcurl=value('MAILBOX_CURL',, 'ENVIRONMENT')
if mcurl=='' then mcurl='curl'
mail=.MailboxClient~new(url, tokenFile, mcurl, 'ALCHEMYFETCH', policy~storeDir'/mailbox-tmp')
nudges=nudgeMap(kit'/etc/nudge.conf')
/* test hook: NUDGE_CMD replaces the browser nudge (it is given ADAPTER TITLE -- ID) */
nudgeCmd=value('NUDGE_CMD',, 'ENVIRONMENT')
if nudgeCmd=='' then nudgeCmd='sh' mbQ(kit'/bin/kit.sh') 'rexx' mbQ(kit'/bin/browser-ui.rex') 'nudge'
poll=fxNum(conf, 'poll_seconds', 30)

f=.FetchFindings~new
if \mail~ready(f) then do
  do l over f~lines
    say l
  end
  exit 2
end
log~info('ALCHEMYFETCH on' url 'reader' reader~class~id 'poll' poll's')
do forever
  f=.FetchFindings~new
  todo=mail~unread(f)
  do l over f~lines
    log~warn(l)
  end
  if todo~items>0 then log~info(todo~items 'request(s) to handle')
  do q over todo
    call handle q
  end
  if once then leave
  call SysSleep poll
end
exit 0

handle: procedure expose gate mail log nudges nudgeCmd
  use arg q
  id=q['requestId']~string
  issuer=q['senderId']~string~upper
  lane=q['componentId']~string
  if q['answeredByCaller']~string==1 then do
    /* answered on an earlier pass (its mark-read failed, or its reply was taken but the answer was unreadable):
     * never execute or reply twice; mark it read and nudge, since a repeated nudge costs less than a lost one */
    log~info(id 'was already answered: mark read and nudge only')
  end
  else do
    rep=gate~process(.GateOrder~new(id, issuer, 'ALCHEMYFETCH', q['body']~string))
    body=.array~of('Architecture: Tom Dyer. Coding: Claude (Opus 5.5); Legal Effect: ChatGPT. Report written by: ALCHEMYFETCH (automatic).', '')
    /* page text can carry tabs, CRs and other control characters: spaces in the reply */
    ctl=xrange('00'x, '09'x) || xrange('0b'x, '1f'x)
    do l over rep
      body~append(l~translate(' ', ctl))
    end
    r=mail~reply(id, body~makeString('L', '0a'x), 'ALCHEMYFETCH report for' id)
    if \r['ok'] then do
      log~error('reply to' id 'failed:' r['error'])
      log~error(id 'left unread: the next pass marks it read and nudges if the reply was taken, or answers it if not')
      return
    end
    log~info('replied to' issuer 'about' id)
  end
  m=mail~markRead(id)
  if \m['ok'] then log~warn('mark read' id 'failed:' m['error'])
  t=nudges[lane]
  if t=.nil then do
    log~info('no nudge target for lane' lane '(etc/nudge.conf): mailbox reply only')
    return
  end
  parse var t adapter '|' title
  log~info('nudging' adapter 'conversation "'title'" about' id)
  address system nudgeCmd adapter '--for ALCHEMYFETCH --in' title '--' id
  if rc<>0 then log~warn('nudge for' id 'failed (rc' rc'); the reply is in the mailbox')
  return

/* lane|adapter|conversation title */
nudgeMap: procedure
  use arg file
  d=.directory~new
  if \SysFileExists(file) then return d
  s=.stream~new(file)
  s~open('read')
  do while s~lines>0
    l=s~linein~strip
    if l=='' | l~left(1)=='#' then iterate
    parse var l lane '|' adapter '|' title
    d[lane~strip]=adapter~strip'|'title~strip
  end
  s~close
  return d

::requires 'MailboxClient.cls'
::requires 'BostonCrabReader.cls'
::requires 'UiKit.cls'
