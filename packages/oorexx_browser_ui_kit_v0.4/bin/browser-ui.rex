/* browser-ui.rex -- drive the Claude and ChatGPT web pages through the kit's adapters.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
 *
 *   bin/kit.sh rexx bin/browser-ui.rex doctor
 *        checks this machine before anything else: kit.env paths, the packages, Chrome (a real headless launch
 *        on a scratch profile under the profile root), and the test fixtures' bridge and ooRexx/WASM files
 *   bin/kit.sh rexx bin/browser-ui.rex adapters
 *   bin/kit.sh rexx bin/browser-ui.rex handover NAME [--minutes 15]
 *        opens a VISIBLE browser on the profile for NAME; you sign in yourself (Google, authenticator...);
 *        the kit only watches the page, closes the browser when you are signed on, then checks that a
 *        headless browser on the same profile is signed on too.  Recorded in var/handover.tsv.
 *   bin/kit.sh rexx bin/browser-ui.rex capture NAME                     count every landmark of the map on the
 *                                                                       signed-on page and list the page's own
 *                                                                       markers (structure only, no message text)
 *   bin/kit.sh rexx bin/browser-ui.rex nudge NAME --in CHAT -- REQ-ID   type the nudge into that conversation and
 *                                                                       wait only until the page has taken it
 *   bin/kit.sh rexx bin/browser-ui.rex mail NAME --in CHAT -- LANE REQ-ID [REQ-ID...] [+N]     (LANE ALL: any lane)
 *        the mail nudge (bin/mailnudge.rex runs it): fixed text naming the lane and the request ids, nothing
 *        else; exit 3, with nothing typed, when a reply is streaming in that conversation (busy)
 *   bin/kit.sh rexx bin/browser-ui.rex mailbatch NAME --jobs FILE   all of one pass's mail nudges for one site in
 *        one browser run (bin/mailnudge.rex writes FILE); prints RESULT tab KEY tab sent|busy|failed: why per job
 *   CHAT: the conversation's path (/c/<id>, /chat/<uuid>) or its title
 *   Declared automation: every page opened by state/conversations/send/capture APPENDS to its user agent
 *     AlchemyAgent/0.1 (LLM-driven request; requested-by=AGENT; +AGENT_CONTACT)
 *   AGENT from --for, else AGENT_REQUESTED_BY in kit.env, else "operator" (then "scripted request").
 *   AGENT_CONTACT defaults to https://rasenfalcon.com.  The hand-over carries no token: a person signs in.
 *   A site that refuses headless browsers (claude.ai: Cloudflare check) has browser_mode=headed in its .ui
 *   and runs in a visible window.  --headed / --headless override.  The kit never answers a bot check.
 *   Whenever a page is not SIGNED_ON, its title, address, browser identity and opening text are printed and
 *   a screenshot is saved in var/evidence.
 *   bin/kit.sh rexx bin/browser-ui.rex state NAME                       headless: SIGNED_ON / SIGNED_OUT / ...
 *   bin/kit.sh rexx bin/browser-ui.rex conversations NAME               the conversations in the sidebar: title,
 *                                                                       a tab, and its path (/c/<id>, /chat/<uuid>)
 *   bin/kit.sh rexx bin/browser-ui.rex send NAME [--in TITLE] -- TEXT   send (in that conversation, else a
 *                                                                       new one) and print the reply
 * Profiles: $BROWSER_PROFILES/NAME, default ~/.config/alchemy/browser-profiles/NAME (mode 700).  They hold your session cookies: treat them
 * like a password.  The kit never types credentials into a real site.
 * Exit 0 ok, 1 refused/failed (reasons printed), 2 usage, 3 busy (mail: nothing typed).
 */
parse arg cmd rest
kit=value('KIT',, 'ENVIRONMENT')
chrome=value('CHROME',, 'ENVIRONMENT')
log=uiLog(kit)
reg=.UiAdapters~new(kit'/etc/adapters')
if cmd=='doctor' then exit doctor(kit, chrome, log)
if cmd=='adapters' then do
  do n over reg~names
    a=reg~adapter(n)
    say left(n, 10) left(a~baseUrl, 28) a~map~get('captured')
  end
  exit 0
end
parse var rest name rest
a=reg~adapter(name)
if a=.nil then do
  say 'browser-ui: no adapter' name '(have:' reg~names~makeString('L', ' ')')'
  exit 2
end
profile=profileRoot()'/'name
/* declared automation: requested-by (--for, else AGENT_REQUESTED_BY, else "operator") and the contact */
requestedBy=value('AGENT_REQUESTED_BY',, 'ENVIRONMENT')
if requestedBy=='' then requestedBy='operator'
agentContact=value('AGENT_CONTACT',, 'ENVIRONMENT')
if agentContact=='' then agentContact='https://rasenfalcon.com'
f=.UiFindings~new
select
  when cmd=='handover' then do
    minutes=15
    parse var rest opt val .
    if opt=='--minutes' then minutes=val
    address system 'mkdir -p' cdpQ(filespec('L', profile)) '&& chmod 700' cdpQ(filespec('L', profile))
    b=.CdpBrowser~new(chrome, profile, .false, 9340, log)
    b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
    ok=b~launch
    p=b~newPage
    say 'browser-ui: a browser window has opened on' a~baseUrl
    say 'browser-ui: sign in there yourself; this waits up to' minutes 'minutes and closes the window when you are in'
    h=.UiHandover~new(a, log)
    signedOn=h~watch(p, minutes*60)
    ok=b~close
    if \signedOn then do
      call record kit, name, 'NOT signed on', h~transitions
      say 'browser-ui: no sign-in seen; nothing recorded as signed on'
      exit 1
    end
    /* verify in the mode later runs will use: headless, or a visible window for a site that refuses headless */
    headless=\a~wantsHeaded
    mode='headless'
    if \headless then mode='visible-window'
    b=.CdpBrowser~new(chrome, profile, headless, 9340, log)
    b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
    ok=b~launch
    p=b~newPage
    s=a~open(p)
    if s<>'SIGNED_ON' then ev=evidence(kit, a, p, 'handover-'name'-'mode)
    ok=b~close
    call record kit, name, mode 'check' s, h~transitions
    if s=='SIGNED_ON' then do
      say 'browser-ui:' name 'hand-over complete:' mode 'runs on this profile are signed on'
      exit 0
    end
    say 'browser-ui: signed on in the window, but a' mode 'browser on the same profile sees' s
    say 'browser-ui: what it saw:' ev
    exit 1
  end
  when wordpos(cmd, 'state conversations send capture nudge mail mailbatch')>0 then do
    if \SysFileExists(profile) then do
      say 'browser-ui: no profile for' name 'yet: run  bin/kit.sh rexx bin/browser-ui.rex handover' name
      exit 1
    end
    /* The shell removes quotes, so words cannot be grouped by quoting.  Grammar instead:
     *   [--headed|--headless] [--in TITLE WORDS] -- TEXT WORDS
     * everything after the first " -- " is the message text, untouched; --in takes the words up to "--". */
    opts=rest
    text=''
    if wordpos('--', rest)>0 then do
      at=wordindex(rest, wordpos('--', rest))
      opts=rest~left(at-1)
      text=rest~substr(at+2)~strip
    end
    headless=\a~wantsHeaded
    title=''
    jobsFile=''
    do while opts~words>0
      parse var opts w opts
      select
        when w=='--headed' then headless=.false
        when w=='--headless' then headless=.true
        when w=='--for' then parse var opts requestedBy opts
        when w=='--jobs' then parse var opts jobsFile opts
        when w=='--in' then do
          title=opts~strip
          opts=''
        end
        otherwise do
          say 'browser-ui: unknown option' w
          call usage
          exit 2
        end
      end
    end
    if cmd=='mailbatch' then if jobsFile=='' | \SysFileExists(jobsFile) then do
      say 'browser-ui: mailbatch needs --jobs FILE (lines: KEY tab CHAT tab LANE tab REQ-ID... [+N])'
      call usage
      exit 2
    end
    if cmd=='send' & text=='' then do
      say 'browser-ui: send needs the message after --'
      call usage
      exit 2
    end
    /* a nudge carries only the request id (Tom's contract): the result itself is in the mailbox */
    if cmd=='nudge' then do
      if title=='' | text~words<>1 | text~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.')>0 then do
        say 'browser-ui: nudge needs --in CONVERSATION TITLE and one request id after --'
        call usage
        exit 2
      end
      text='The event you registered a request for' text 'has occurred, check Rasen Falcon MCP.'
    end
    /* the mail nudge: lane and request ids only, checked word by word, so no mailbox text can reach a chat */
    if cmd=='mail' then do
      parse var text lane ids
      bad=(title=='' | ids~words==0 | ids~words>21)
      if lane<>'ALL' then if \mnIsLane(lane) then bad=.true
      more=0
      list=.array~new
      do w over ids~makeArray(' ')
        if w~left(1)=='+' then do
          if datatype(w~substr(2), 'W') then more=w~substr(2)
          else bad=.true
        end
        else if mnIsRequestId(w) then list~append(w)
        else bad=.true
      end
      if bad | list~items==0 then do
        say 'browser-ui: mail needs --in CHAT, then after -- a lane id and request ids (REQ-nnn), optionally +N'
        call usage
        exit 2
      end
      text=mnNudgeText(lane, list, more)
    end
    if requestedBy=='' | requestedBy~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.')>0 then do
      say 'browser-ui: --for needs an agent name (letters, digits, - _ .), e.g. --for CLAUDE'
      exit 2
    end
    if \headless then say 'browser-ui:' name 'runs in a visible window (browser_mode=headed in its .ui, or --headed)'
    /* one page run at a time on this machine: the DevTools port (9341) and a profile cannot be shared, and the
     * mail nudger, ALCHEMYFETCH and a person may all start one (15 Nov 2026) */
    lock=kit'/var/browser-ui.lock'
    if \takeLock(lock, 180, log) then do
      say 'browser-ui: another browser-ui run has held' lock 'for 3 minutes; try again later'
      exit 1
    end
    b=.CdpBrowser~new(chrome, profile, headless, 9341, log)
    b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
    /* every page says it is automated: who asked, and where the operator is reached */
    b~agentIdentity=uiAgentIdentity(requestedBy, agentContact)
    /* a visible window has a person at it: they, not the kit, answer a site's "are you a person?" check */
    a~personPresent=\headless
    /* test hook: BROWSER_UI_BASE points the adapter at the local fixtures (127.0.0.1 only, which also
     * allows their self-signed certificate); never set for real use */
    testBase=value('BROWSER_UI_BASE',, 'ENVIRONMENT')
    if testBase<>'' then do
      if testBase~left(18)<>'https://127.0.0.1:' then do
        say 'browser-ui: BROWSER_UI_BASE may only point at https://127.0.0.1 (the test fixtures)'
        exit 2
      end
      a~rebase(testBase)
      b~insecureCerts=.true
    end
    ok=b~launch
    p=b~newPage
    s=a~open(p)
    if s<>'SIGNED_ON' then say 'browser-ui: page seen:' evidence(kit, a, p, cmd'-'name)
    code=0
    select
      when cmd=='state' then say s
      when s<>'SIGNED_ON' & cmd=='capture' then do
        say 'browser-ui: capture needs a signed-on page; this one is' s
        code=1
      end
      when cmd=='capture' then do
        out=a~capture(p)
        file=kit'/var/evidence/capture-'name'-'.DateTime~new~isoDate~changeStr(':', '')~left(17)'.txt'
        address system 'mkdir -p' cdpQ(kit'/var/evidence') '&& chmod 700' cdpQ(kit'/var/evidence')
        s2=.stream~new(file)
        s2~open('write replace')
        do l over out
          say l
          s2~lineout(l)
        end
        s2~close
        say 'browser-ui: capture written to' file
      end
      when s<>'SIGNED_ON' then do
        say 'browser-ui:' name 'is' s': run  bin/kit.sh rexx bin/browser-ui.rex handover' name
        code=1
      end
      when cmd=='mailbatch' then call mailBatch a, p, jobsFile
      when cmd=='conversations' then do c over a~conversations(p)
        say c['title']||'09'x||c['href']      /* title, tab, path: mailnudge.rex bind resolves titles with it */
      end
      otherwise do
        if title=='' then do
          r=a~send(p, text, f)
          if r<>.nil then say r
          else code=1
        end
        else if a~openChat(p, title, f) then do
          if cmd=='mail' & a~busy(p) then do
            say 'browser-ui: BUSY a reply is streaming in' title'; nothing typed'
            code=3
          end
          else do
            r=a~send(p, text, f, 120, wordpos(cmd, 'nudge mail')==0)
            if r<>.nil then say r
            else code=1
          end
        end
        else code=1
      end
    end
    ok=b~close
    address system 'rmdir' cdpQ(lock) '2>/dev/null'
    do l over f~lines
      say '  'l
    end
    exit code
  end
  otherwise do
    call usage
    exit 2
  end
end

/* The mail nudges of one pass for one site, in the one browser already open (Tom, 15 Nov 2026: do not open and
 * close the browser for each of several nudges).  Each line of the jobs file: KEY tab CHAT tab LANE tab
 * REQ-ID... [+N].  Every word is checked, as for "mail"; each job prints  RESULT tab KEY tab sent|busy|failed: why
 * and a job that fails does not stop the others. */
mailBatch: procedure
  use arg a, p, jobsFile
  s=.stream~new(jobsFile)
  s~open('read')
  lines=s~arrayIn
  s~close
  first=.true
  do line over lines
    if line~strip=='' then iterate
    parse var line key '09'x chat '09'x lane '09'x ids
    if key=='' | key~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789|*-_')>0 then iterate
    ok=(chat<>'' & ids~words>0 & ids~words<=21)
    if ok then if lane<>'ALL' then ok=mnIsLane(lane)
    if ok then if mnBindingProblem('x'||'x', 'X', 'x', chat)<>'' then ok=.false
    more=0
    list=.array~new
    do w over ids~makeArray(' ')
      if w~left(1)=='+' then do
        if datatype(w~substr(2), 'W') then more=w~substr(2)
        else ok=.false
      end
      else if mnIsRequestId(w) then list~append(w)
      else ok=.false
    end
    if \ok | list~items==0 then do
      say 'RESULT'||'09'x||key||'09'x||'failed: the job line did not check out'
      iterate
    end
    /* a moment between chats, so the last message has gone before the page is left */
    if \first then call SysSleep 3
    first=.false
    fj=.UiFindings~new
    if \a~openChat(p, chat, fj) then do
      say 'RESULT'||'09'x||key||'09'x||'failed:' fj~lines~makeString('L', '; ')
      iterate
    end
    if a~busy(p) then do
      say 'RESULT'||'09'x||key||'09'x||'busy'
      iterate
    end
    r=a~send(p, mnNudgeText(lane, list, more), fj, 120, .false)
    if r<>.nil then say 'RESULT'||'09'x||key||'09'x||'sent'
    else say 'RESULT'||'09'x||key||'09'x||'failed:' fj~lines~makeString('L', '; ')
  end
  call SysSleep 3
  return

/* mkdir is atomic: whoever makes the directory holds the lock.  A lock older than 15 minutes is a run that died
 * without letting go, and is taken over. */
takeLock: procedure
  use arg lock, waitSeconds, log
  t0=.DateTime~new
  said=.false
  do forever
    address system 'mkdir' cdpQ(lock) '2>/dev/null'
    if rc==0 then return .true
    address system 'find' cdpQ(lock) '-maxdepth 0 -mmin +15' with output stem o.
    if o.0>0 then do
      log~warn('taking over' lock': its holder has not let go for 15 minutes')
      address system 'rmdir' cdpQ(lock) '2>/dev/null'
      iterate
    end
    if (.DateTime~new-t0)~totalSeconds>=waitSeconds then return .false
    if \said then log~info('waiting for another browser-ui run to finish ('lock')')
    said=.true
    call SysSleep 1
  end

usage:
  say 'usage: browser-ui.rex doctor | adapters | handover NAME [--minutes N]'
  say '       browser-ui.rex state|conversations|capture NAME [--headed|--headless] [--for AGENT]'
  say '       browser-ui.rex send NAME [--headed|--headless] [--for AGENT] [--in CONVERSATION TITLE] -- MESSAGE TEXT'
  say '       (--for: the agent that asked; every page carries it in its user agent, with AGENT_CONTACT)'
  say '       (no --in: a new conversation.  Everything after -- is the message.)'
  say '       browser-ui.rex nudge NAME [--headed|--headless] [--for AGENT] --in CHAT -- REQUEST-ID'
  say '       browser-ui.rex mail NAME [--headed|--headless] [--for AGENT] --in CHAT -- LANE REQUEST-ID... [+N]'
  say '       browser-ui.rex mailbatch NAME [--headed|--headless] [--for AGENT] --jobs FILE'
  say '       (CHAT: the conversation path /c/<id> or /chat/<uuid>, or its title)'
  say '       (types "The event you registered a request for REQUEST-ID has occurred, check Rasen Falcon MCP.")'
  return

/* What a page showed when its state was not SIGNED_ON: a description, plus a PNG in var/evidence. */
evidence: procedure
  use arg kit, a, p, tag
  dir=kit'/var/evidence'
  address system 'mkdir -p' cdpQ(dir) '&& chmod 700' cdpQ(dir)
  file=dir'/'tag'-'.DateTime~new~isoDate~changeStr(':', '')~left(17)'.png'
  signal on syntax name noShot
  ok=p~screenshot(file)
  return a~describe(p) 'screenshot='file
noShot:
  return a~describe(p) '(no screenshot)'

/* doctor: every rule on its own line, STOP / WARN / INFO; exit 1 on any STOP. */
doctor: procedure
  use arg kit, chrome, log
  f=.UiFindings~new
  pk=value('ALCHEMY_PACKAGES',, 'ENVIRONMENT')
  do d over .array~of('oorexx_websocket_access/src', 'oorexx_socket_provider/src', 'oorexx_crypto_auth/src', 'oorexx_crypto_v0.8.3/src', 'oorexx_https_server/rexx', 'oorexx_https_server/bridge')
    if SysIsFileDirectory(pk'/'d) then f~add('INFO', 'package', pk'/'d)
    else f~add('STOP', 'package', 'missing' pk'/'d '(ALCHEMY_PACKAGES in var/kit.env)')
  end
  fr=value('FOREIGN_RUNTIME_LIB',, 'ENVIRONMENT')~makeArray(':')[1]
  if SysFileExists(fr'/libforeign_runtime.so') then f~add('INFO', 'foreign', fr'/libforeign_runtime.so')
  else f~add('STOP', 'foreign', 'no libforeign_runtime.so in' fr '(FOREIGN_RUNTIME_LIB)')
  oc=value('OOREXX_CLS',, 'ENVIRONMENT')
  do c over .array~of('json.cls', 'socket.cls')
    if \SysFileExists(oc'/'c) then f~add('STOP', 'oorexxcls', 'no' c 'in' oc '(OOREXX_CLS)')
  end
  if \SysFileExists(chrome) then f~add('STOP', 'chrome', 'CHROME' chrome 'does not exist')
  else do
    if chrome~pos('/flatpak/')>0 & profileRoot()~pos('/.var/app/')=0 then f~add('WARN', 'flatpak', 'Chrome is a flatpak: it may not be able to write profiles in' profileRoot() '- set BROWSER_PROFILES=$HOME/.var/app/com.google.Chrome/alchemy-profiles')
    probe=profileRoot()'/doctor-probe'
    v=chromeProbe(chrome, probe, log)
    if v=='42' then do
      f~add('INFO', 'chrome', 'headless launch and DevTools OK on' probe)
      if \SysFileExists(probe'/Default') & \SysFileExists(probe'/Local State') then f~add('STOP', 'profile', 'Chrome ran but wrote nothing in' probe '- it cannot use that profile directory (flatpak?)')
      else f~add('INFO', 'profile', 'Chrome writes its profile in' probe)
    end
    else f~add('STOP', 'chrome', v)
    address system 'rm -rf' cdpQ(probe)
  end
  local=uiReadProps(kit'/var/fixtures.local.conf')
  bd=local['bridge_dir']
  wa=local['wasm_assets']
  if bd=.nil then f~add('WARN', 'fixtures', 'no bridge_dir in var/fixtures.local.conf (only the test fixtures need it)')
  else if \SysIsFileDirectory(bd) then f~add('WARN', 'fixtures', 'bridge_dir' bd 'does not exist')
  if wa=.nil then f~add('WARN', 'fixtures', 'no wasm_assets in var/fixtures.local.conf (only the test fixtures need it)')
  else do a over .array~of('ooRexx.js', 'ooRexx-worker.js', 'rexx.js', 'rexx.wasm', 'rexx.data', 'js-realm.js', 'polygon-clipping.umd.min.js')
    if \SysFileExists(wa'/'a) then f~add('WARN', 'fixtures', 'ooRexx/WASM file missing:' wa'/'a)
  end
  do l over f~lines
    say l
  end
  say 'browser-ui doctor:' f~count('STOP') 'STOP,' f~count('WARN') 'WARN,' f~count('INFO') 'INFO'
  return (f~count('STOP')>0)

/* Launch Chrome headless on a scratch profile and evaluate 6*7: '42', or the reason it failed. */
chromeProbe: procedure
  use arg chrome, probe, log
  signal on syntax name failed
  b=.CdpBrowser~new(chrome, probe, .true, 9342, log)
  b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
  ok=b~launch
  p=b~newPage
  v=p~evaluate('6*7')
  ok=b~close
  return v
failed:
  return condition('O')~message

profileRoot: procedure
  r=value('BROWSER_PROFILES',, 'ENVIRONMENT')
  if r=='' then r=value('HOME',, 'ENVIRONMENT')'/.config/alchemy/browser-profiles'
  return r

record: procedure
  use arg kit, name, outcome, transitions
  s=.stream~new(kit'/var/handover.tsv')
  s~open('write append')
  s~lineout(.DateTime~new~isoDate'09'x||name'09'x||outcome'09'x||transitions~makeString('L', ' '))
  s~close
  return

::requires 'UiKit.cls'
::requires 'MailNudger.cls'
