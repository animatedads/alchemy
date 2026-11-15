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
 *   bin/kit.sh rexx bin/mailnudge.rex bind LANE ADAPTER TITLE WORDS... [--as PRINCIPAL]
 *                                                     by its title: looked up in the site's sidebar (opens a
 *                                                     browser window), and its path is what is stored
 *   bin/kit.sh rexx bin/mailnudge.rex bind LANE ADAPTER /PATH [PRINCIPAL]
 *   bin/kit.sh rexx bin/mailnudge.rex unbind LANE [PRINCIPAL]     (no principal: every chat bound to LANE)
 *   bin/kit.sh rexx bin/mailnudge.rex chats ADAPTER [WORDS]   the sidebar's conversations: path and title
 *                                                     LANE '*' (quoted): every lane not bound by name, for that
 *                                                     principal: the coordinator's chat
 *                                                     Bindings are written to var/nudge.local.conf (a line for
 *                                                     the same lane and principal is replaced); a running nudger
 *                                                     reads the binding files again whenever they change
 *   bin/kit.sh rexx bin/mailnudge.rex release REQ-ID  let a thread held by the loop guard be nudged again
 *
 * Exit 0 ok, 2 usage or a binding refused.
 *
 * Bindings: etc/nudge.conf, then var/nudge.local.conf.  Rules: etc/mail-nudge.conf, then var/mail-nudge.local.conf.
 * State: var/mail-nudge-state.tsv.  Log: var/events-YYYYMMDD.log (oorexx_logging) and the terminal.
 * The nudges: browser-ui.rex mailbatch ADAPTER --for MAILNUDGE --jobs FILE, one browser run per site per pass for
 * all of that site's chats (fixed text; lane and ids only).  Test hooks: MAILNUDGE_CMD replaces that command; MAILNUDGE_NOW fixes the clock (epoch seconds);
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
if nudgeCmd=='' then nudgeCmd='sh' mnQ(kit'/bin/kit.sh') 'rexx' mnQ(kit'/bin/browser-ui.rex') 'mailbatch'
nudger=.MailNudger~new(journal, bindings, state, rules, .CommandNudger~new(nudgeCmd, log, var), log)
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
  when cmd=='bind' then exit bindCommand(rest, kit, var, home)
  when cmd=='unbind' then do
    parse var rest lane principal .
    lane=lane~lower
    principal=principal~upper
    n=rewriteBindings(var'/nudge.local.conf', lane, principal, '')
    if n==0 then do
      say 'mailnudge: no line for' lane principal 'in' var'/nudge.local.conf (etc/nudge.conf is the package''s: edit that by hand)'
      exit 2
    end
    say 'mailnudge: unbound' lane principal '('n 'line(s) removed); a running nudger reloads it on its next pass'
    exit 0
  end
  when cmd=='chats' then do
    parse var rest adapter words
    convs=listChats(adapter~lower, kit)
    if convs==.nil then exit 1
    n=0
    do c over convs
      if words<>'' then if c[1]~lower~pos(words~strip~lower)==0 then iterate
      say left(c[2], 48) c[1]
      n=n+1
    end
    say n 'conversation(s)'
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
    say 'usage: mailnudge.rex [--once | --dry | status | unbound | chats ADAPTER [WORDS] | release REQ-ID'
    say '                      | bind LANE URL [PRINCIPAL] | bind LANE ADAPTER TITLE WORDS... [--as PRINCIPAL]'
    say '                      | bind LANE ADAPTER /PATH [PRINCIPAL] | unbind LANE [PRINCIPAL]]'
    exit 2
  end
end

dry=(cmd=='--dry')
once=(cmd=='--once' | dry)
log~info('mail nudge: journal' rules['journal']',' bindings~bindings~items 'chat(s) bound, poll' rules['poll_seconds']'s')
/* bindings are read again whenever etc/nudge.conf or var/nudge.local.conf changes (Tom, 15 Nov 2026) */
bindingFiles=.array~of(kit'/etc/nudge.conf', var'/nudge.local.conf')
watch=.BindingWatch~new(bindingFiles)
passes=value('MAILNUDGE_PASSES',, 'ENVIRONMENT')       /* test hook: stop after this many passes */
done=0
do forever
  if watch~changed then do
    bindings=.ChatBindings~new(bindingFiles)
    nudger~bindings=bindings
    log~info('bindings reloaded:' bindings~bindings~items 'chat(s) bound')
    do p over bindings~problems
      log~warn('binding refused:' p)
    end
  end
  now=value('MAILNUDGE_NOW',, 'ENVIRONMENT')
  if now=='' then now=mnNow()
  do l over nudger~pass(now, dry)
    say l
  end
  done=done+1
  if once then leave
  if datatype(passes, 'W') then if done>=passes then leave
  call SysSleep rules['poll_seconds']
end
exit 0

/* bind LANE URL [PRINCIPAL]
 * bind LANE ADAPTER /PATH [PRINCIPAL]
 * bind LANE ADAPTER TITLE WORDS... [--as PRINCIPAL]   the title is looked up in that site's sidebar (a browser run)
 *                                                     and the conversation's path is what is stored
 * A line for the same lane and principal in var/nudge.local.conf is replaced, not added to. */
bindCommand: procedure
  use arg rest, kit, var, home
  principal=''
  p=rest~pos(' --as ')
  if p>0 then do
    principal=rest~substr(p+6)~strip~upper
    rest=rest~left(p-1)
  end
  parse var rest lane adapter tail
  lane=lane~lower
  tail=tail~strip
  if adapter~left(8)~lower=='https://' then do
    if principal=='' then principal=tail~word(1)
    u=mnChatFromUrl(adapter)
    if u==.nil then do
      say 'mailnudge: not bound:' adapter 'is not a https://chatgpt.com/c/... or https://claude.ai/chat/... address'
      return 2
    end
    adapter=u[1]; chat=u[2]
  end
  else do
    adapter=adapter~lower
    if adapter~verify('abcdefghijklmnopqrstuvwxyz0123456789-_')>0 | adapter=='' then do
      say 'mailnudge: not bound: adapter' adapter 'is not an adapter name'
      return 2
    end
    if \SysFileExists(kit'/etc/adapters/'adapter'.ui') then do
      say 'mailnudge: not bound: no adapter' adapter '(etc/adapters/'adapter'.ui)'
      return 2
    end
    if tail~left(1)=='/' then do
      chat=tail~word(1)
      if principal=='' then principal=tail~word(2)
    end
    else do
      /* a title: find it in the sidebar, store its path */
      if tail=='' then do
        say 'mailnudge: not bound: give a URL, a /path or the chat''s title'
        return 2
      end
      convs=listChats(adapter, kit)
      if convs==.nil then return 1
      exact=.array~new
      near=.array~new
      do c over convs
        if c[1]~lower==tail~lower then exact~append(c)
        else if c[1]~lower~pos(tail~lower)>0 then near~append(c)
      end
      if exact~items==1 then pick=exact[1]
      else if exact~items==0 & near~items==1 then pick=near[1]
      else do
        cands=exact
        if cands~items==0 then cands=near
        if cands~items==0 then say 'mailnudge: not bound: no conversation in the' adapter 'sidebar has a title containing "'tail'"' ('of' convs~items'; an older chat: bind it by its address)')
        else do
          say 'mailnudge: not bound: "'tail'" matches' cands~items 'conversations; give more of the title, or its path:'
          do c over cands
            say '  'left(c[2], 48) c[1]
          end
        end
        return 2
      end
      chat=pick[2]
      say 'mailnudge: "'tail'" is' adapter chat '("'pick[1]'")'
    end
  end
  if principal=='' then principal=mnPrincipalFor(adapter)
  principal=principal~upper
  if principal=='' then do
    say 'mailnudge: not bound: give the principal (--as PRINCIPAL)'
    return 2
  end
  why=mnBindingProblem(lane, principal, adapter, chat)
  if why<>'' then do
    say 'mailnudge: not bound:' why
    return 2
  end
  f=var'/nudge.local.conf'
  n=rewriteBindings(f, lane, principal, lane'|'principal'|'adapter'|'chat)
  if n>0 then say 'mailnudge: bound' lane principal 'to' adapter chat 'in' f '(replacing' n 'line(s)); a running nudger reloads it on its next pass'
  else say 'mailnudge: bound' lane principal 'to' adapter chat 'in' f'; a running nudger reloads it on its next pass'
  return 0

/* Drop the lines for LANE|PRINCIPAL (every principal when PRINCIPAL is empty) from file f, append newLine if
 * given; return how many were dropped. */
rewriteBindings: procedure
  use arg f, lane, principal, newLine
  keep=.array~new
  dropped=0
  if SysFileExists(f) then do
    s=.stream~new(f)
    s~open('read')
    do while s~lines>0
      l=s~linein
      parts=l~strip~makeArray('|')
      key=''
      if parts~items==3 then key=parts[1]~strip~lower'|'mnPrincipalFor(parts[2]~strip~lower)
      if parts~items==4 then key=parts[1]~strip~lower'|'parts[2]~strip~upper
      hit=(key==lane'|'principal)
      if principal=='' then hit=(key~left(lane~length+1)==lane'|')
      if l~strip~left(1)<>'#' & hit then dropped=dropped+1
      else keep~append(l)
    end
    s~close
  end
  if newLine<>'' then keep~append(newLine)
  tmp=f'.tmp'
  s=.stream~new(tmp)
  s~open('write replace')
  do l over keep
    s~lineout(l)
  end
  s~close
  address system 'mv -f' mnQ(tmp) mnQ(f)
  return dropped

/* The conversations in an adapter's sidebar: .array of .array(title, path).  One browser run (browser-ui.rex
 * conversations, in a visible window: both sites refuse headless Chrome).  Test hook: MAILNUDGE_CHATS_CMD. */
listChats: procedure
  use arg adapter, kit
  cmd=value('MAILNUDGE_CHATS_CMD',, 'ENVIRONMENT')
  if cmd=='' then cmd='sh' mnQ(kit'/bin/kit.sh') 'rexx' mnQ(kit'/bin/browser-ui.rex') 'conversations'
  address system cmd adapter '--headed --for MAILNUDGE' with output stem o.
  if rc<>0 then do
    say 'mailnudge: could not list the' adapter 'conversations (rc' rc'):'
    do i=1 to o.0
      say '  'o.i
    end
    return .nil
  end
  out=.array~new
  do i=1 to o.0
    parse var o.i title '09'x path
    if path~left(1)=='/' then if mnIsChatPath(path) then out~append(.array~of(title~strip, path~strip))
  end
  return out

/* key=value files, later ones overriding; $HOME expanded */
readRules: procedure
  use arg files, home
  r=.directory~new
  do rf over files
    d=uiReadProps(rf)
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
