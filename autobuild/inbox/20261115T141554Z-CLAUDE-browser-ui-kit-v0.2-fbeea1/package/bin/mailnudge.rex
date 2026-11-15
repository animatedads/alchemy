/* mailnudge.rex -- tell each chat when it has mail on Rasen Falcon, so nobody types "you have mail".
 *
 * Architecture: Tom Dyer (15 Nov 2026).  Coding: Claude (Opus 5.5), 15 November 2026.
 *
 * Run it on the machine that runs the mailbox (it reads the mailbox journal directly, read-only) and that holds
 * the signed-in browser profiles (browser-ui.rex handover claude / chatgpt).
 *
 *   bin/kit.sh rexx bin/mailnudge.rex                 keep going: a pass every poll_seconds
 *   bin/kit.sh rexx bin/mailnudge.rex --once          one pass
 *   bin/kit.sh rexx bin/mailnudge.rex --dry           one pass that says what it would nudge, and types nothing
 *   bin/kit.sh rexx bin/mailnudge.rex status          every bound chat: waiting, last nudge, stalled, held
 *   bin/kit.sh rexx bin/mailnudge.rex unbound         lanes with mail waiting for a chat and no chat bound
 *   bin/kit.sh rexx bin/mailnudge.rex bind LANE URL [PRINCIPAL]
 *                                                     bind a chat by the address in your browser's address bar
 *                                                     (https://chatgpt.com/c/... or https://claude.ai/chat/...)
 *   bin/kit.sh rexx bin/mailnudge.rex bind LANE ADAPTER CHAT [PRINCIPAL]
 *                                                     the same with adapter and path (or title) given
 *                                                     LANE '*' (quoted): every lane not bound by name, for that
 *                                                     principal: the coordinator's chat
 *                                                     Bindings are written to var/nudge.local.conf
 *   bin/kit.sh rexx bin/mailnudge.rex release REQ-ID  let a thread held by the loop guard be nudged again
 *
 * Exit 0 ok, 2 usage or a binding refused.
 *
 * Bindings: etc/nudge.conf, then var/nudge.local.conf.  Rules: etc/mail-nudge.conf, then var/mail-nudge.local.conf.
 * State: var/mail-nudge-state.tsv.  Log: var/events-YYYYMMDD.log (oorexx_logging) and the terminal.
 * The nudge itself: browser-ui.rex mail ADAPTER --for MAILNUDGE --in CHAT -- LANE REQ-ID... (fixed text; lane and
 * ids only).  Test hooks: MAILNUDGE_CMD replaces that command; MAILNUDGE_NOW fixes the clock (epoch seconds);
 * MAILNUDGE_VAR replaces var/ (bindings, rules, state).
 */
parse arg cmd rest
numeric digits 18
kit=value('KIT',, 'ENVIRONMENT')
home=value('HOME',, 'ENVIRONMENT')
/* var: this machine's bindings, rules and state (MAILNUDGE_VAR: the tests' own directory) */
var=value('MAILNUDGE_VAR',, 'ENVIRONMENT')
if var=='' then var=kit'/var'
rules=readRules(.array~of(kit'/etc/mail-nudge.conf', var'/mail-nudge.local.conf'), home)
log=uiLog(kit, 'mailnudge')
bindings=.ChatBindings~new(.array~of(kit'/etc/nudge.conf', var'/nudge.local.conf'))
do p over bindings~problems
  log~warn('binding refused:' p)
end
journal=.MailJournal~new(rules['journal'])
state=.NudgeState~new(var'/mail-nudge-state.tsv')
nudgeCmd=value('MAILNUDGE_CMD',, 'ENVIRONMENT')
if nudgeCmd=='' then nudgeCmd='sh' mnQ(kit'/bin/kit.sh') 'rexx' mnQ(kit'/bin/browser-ui.rex') 'mail'
nudger=.MailNudger~new(journal, bindings, state, rules, .CommandNudger~new(nudgeCmd, log), log)
principals=rules['principals']~upper

select
  when cmd=='status' then do
    ok=journal~refresh
    say left('LANE', 26) left('PRINCIPAL', 12) left('CHAT', 34) right('WAITING', 7) ' LAST NUDGE        STATE'
    do b over bindings~bindings
      w=journal~waiting(b~lane, b~principal, rules['since'])~items
      c=state~chat(b~key, b~adapter)
      last='-'
      if c['last']>0 then last=date('S', trunc(c['last']), 'T') time('N', trunc(c['last'])//86400, 'S')
      st='ok'
      if c['stalled']==1 then st='STALLED'
      say left(b~lane, 26) left(b~principal, 12) left(b~adapter||':'||b~chat, 34)~left(34) right(w, 7) ' 'left(last, 18) st
    end
    if state~held~items>0 then say state~held~items 'request(s) held by the loop guard:' state~held~allIndexes~sort~makeString('L', ' ')
    exit 0
  end
  when cmd=='unbound' then do
    lines=nudger~unbound(principals)
    do l over lines
      say l
    end
    say lines~items 'lane(s) with mail waiting and no chat bound.  Bind one with: mailnudge.rex bind LANE ADAPTER /c/<id>'
    exit 0
  end
  when cmd=='bind' then do
    parse var rest lane adapter chat principal .
    /* bind LANE URL [PRINCIPAL]: the address copied from the browser; the adapter comes from the host */
    if adapter~left(8)~lower=='https://' then do
      principal=chat
      u=mnChatFromUrl(adapter)
      if u==.nil then do
        say 'mailnudge: not bound:' adapter 'is not a https://chatgpt.com/c/... or https://claude.ai/chat/... address'
        exit 2
      end
      adapter=u[1]; chat=u[2]
    end
    lane=lane~lower; adapter=adapter~lower
    if principal=='' then principal=mnPrincipalFor(adapter)
    principal=principal~upper
    why=''
    if adapter~verify('abcdefghijklmnopqrstuvwxyz0123456789-_')>0 | adapter=='' then why='adapter' adapter 'is not an adapter name'
    else if \SysFileExists(kit'/etc/adapters/'adapter'.ui') then why='no adapter' adapter '(etc/adapters/'adapter'.ui)'
    else if principal=='' then why='give the principal: mailnudge.rex bind LANE ADAPTER CHAT PRINCIPAL'
    else why=mnBindingProblem(lane, principal, adapter, chat)
    if why<>'' then do
      say 'mailnudge: not bound:' why
      exit 2
    end
    f=var'/nudge.local.conf'
    s=.stream~new(f)
    s~open('write append')
    s~lineout(lane'|'principal'|'adapter'|'chat)
    s~close
    say 'mailnudge: bound' lane principal 'to' adapter chat 'in' f
    exit 0
  end
  when cmd=='release' then do
    id=rest~strip
    if \mnIsRequestId(id) then do
      say 'mailnudge: release needs a request id (REQ-nnn)'
      exit 2
    end
    root=nudger~release(id)
    say 'mailnudge: thread' root 'released; its hop count starts again from now'
    exit 0
  end
  when cmd=='' | cmd=='--once' | cmd=='--dry' then nop
  otherwise do
    say 'usage: mailnudge.rex [--once | --dry | status | unbound | bind LANE ADAPTER CHAT [PRINCIPAL] | release REQ-ID]'
    exit 2
  end
end

dry=(cmd=='--dry')
once=(cmd=='--once' | dry)
log~info('mail nudge: journal' rules['journal']',' bindings~bindings~items 'chat(s) bound, poll' rules['poll_seconds']'s')
do forever
  now=value('MAILNUDGE_NOW',, 'ENVIRONMENT')
  if now=='' then now=mnNow()
  do l over nudger~pass(now, dry)
    say l
  end
  if once then leave
  call SysSleep rules['poll_seconds']
end
exit 0

/* key=value files, later ones overriding; $HOME expanded */
readRules: procedure
  use arg files, home
  r=.directory~new
  do f over files
    d=uiReadProps(f)
    do k over d~allIndexes
      r[k]=d[k]~changeStr('$HOME', home)
    end
  end
  if \r~hasIndex('journal') then r['journal']=home'/agent-mailbox-mcp/state/mailbox-journal.jsonl'
  if \r~hasIndex('principals') then r['principals']='CLAUDE CHATGPT COORDINATOR'
  if \r~hasIndex('poll_seconds') then r['poll_seconds']=60
  if \datatype(r['poll_seconds'], 'W') then r['poll_seconds']=60
  return r

::requires 'UiKit.cls'
::requires 'MailNudger.cls'
