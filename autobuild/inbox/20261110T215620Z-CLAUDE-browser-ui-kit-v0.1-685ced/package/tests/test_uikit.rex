/* test_uikit.rex -- the browser UI kit against the local test fixtures, signed out AND signed on.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
 *
 *   bin/kit.sh rexx tests/test_uikit.rex      (tests/run_matrix.sh starts the fixture host first)
 *
 * For each adapter (claude, chatgpt), pointed at its test fixture:
 *   signed out   state is SIGNED_OUT; send refuses with a STOP that says a person must sign in
 *   hand-over    UiHandover watches while a simulated person signs in through the test identity provider
 *                (password, then code) on a second DevTools connection: SIGNED_OUT -> AWAY -> SIGNED_ON
 *   signed on    conversations listed; one opened by title; send returns the streamed reply
 *   profile      browser closed and relaunched headless on the same profile: still SIGNED_ON
 *   sign out     /logout: SIGNED_OUT again
 * Plus the fixture's own password form (no identity provider) on one adapter.
 * Only the fixture's TEST account is ever typed.
 */
kit=value('KIT',, 'ENVIRONMENT')
chrome=value('CHROME',, 'ENVIRONMENT')
conf=uiReadProps(kit'/etc/fixtures.conf')
t=.UiTest~new
log=uiLog(kit)
reg=.UiAdapters~new(kit'/etc/adapters')
t~check('registry', 'both adapters registered', reg~names~makeString('L', ' ')=='chatgpt claude')
ports=.directory~new
ports['claude']=conf['claude_port']
ports['chatgpt']=conf['chatgpt_port']
profileRoot=value('BROWSER_PROFILES',, 'ENVIRONMENT')
if profileRoot=='' then profileRoot=kit'/var/test-profiles'
else profileRoot=profileRoot'/kit-tests'
address system 'rm -rf' cdpQ(profileRoot)

do name over .array~of('claude', 'chatgpt')
  a=reg~adapter(name)
  a~rebase('https://127.0.0.1:'ports[name]'/')
  prof=profileRoot'/'name
  b=.UiTest~browser(chrome, prof, log)
  p=b~newPage
  f=.UiFindings~new

  /* signed out */
  s=a~open(p)
  t~check(name, 'fresh profile is SIGNED_OUT', s=='SIGNED_OUT', s)
  r=a~send(p, 'should not send', f)
  t~check(name, 'send while signed out refuses', r=.nil, r)
  t~check(name, 'refusal is a STOP naming the hand-over', f~count('STOP')=1 & f~lines[1]~pos('handover')>0, f~lines~makeString('L', ' / '))

  /* hand-over: a simulated person signs in through the identity provider while UiHandover watches */
  person=.FixturePerson~new(b, p~targetId, conf)
  person~signInViaIdp(2)
  h=.UiHandover~new(a, log)
  ok=h~watch(p, 60)
  t~check(name, 'hand-over reached SIGNED_ON', ok)
  seq=h~transitions~makeString('L', ' ')
  t~check(name, 'hand-over passed through the identity provider', seq~pos('SIGNED_OUT')=1 & seq~pos('AWAY')>0 & seq~word(seq~words)=='SIGNED_ON', seq)
  t~check(name, 'the person finished without error', person~result=='done', person~result)

  /* signed on */
  convs=a~conversations(p)
  titles=.array~new
  do c over convs
    titles~append(c['title'])
  end
  t~check(name, 'three conversations listed', convs~items=3, titles~makeString('L', ', '))
  ok=a~openConversation(p, 'Rasen Falcon', f)
  t~check(name, 'open conversation by title', ok, p~location)
  t~check(name, 'opened the right one', p~location~pos('rasen-falcon')>0, p~location)
  ok=p~waitFor('document.getElementById("fx-status")&&document.getElementById("fx-status").textContent==="ready"', 60, 'ooRexx/WASM page script')
  t~check(name, 'page script (ooRexx/WASM) ready', ok)
  usersBefore=p~count(a~map~get('user_turn_selector'))
  text='hello from the kit, '||name
  r=a~send(p, text, f, 60)
  t~check(name, 'send returns the streamed reply', r=='Fixture reply to:' text, r)
  if name=='claude' then do
    /* typing=keys: real key events at a steady interval (for fields that act on key events) */
    a~map~set('typing', 'keys')
    a~map~set('key_interval_ms', 40)
    t0=.DateTime~new
    rk=a~send(p, 'typed key by key', f, 60)
    secs=(.DateTime~new-t0)~totalSeconds
    a~map~set('typing', 'insert')
    t~check(name, 'typing=keys: the reply comes back', rk=='Fixture reply to: typed key by key', rk)
    t~check(name, 'typing=keys: 16 keys at 40 ms take at least 0.64 s', secs>=0.64, secs)
    /* the site asks "are you a person?" mid-send (as claude.ai did 9 Nov 17:11).  The user turn is held back
     * 7 s so the kit is still waiting when it sees the check.  A person present: the kit waits while the
     * "person" (a second DevTools connection) shows the check and then answers it.  No person: STOP. */
    fx=a~origin
    address system 'curl -sk' cdpQ(fx'/api/turn-delay?seconds=7') '>/dev/null'
    ok=p~navigate(p~location, 20)                        /* the page reads the delay when it loads */
    ok=p~waitFor('document.getElementById("fx-status")&&document.getElementById("fx-status").textContent==="ready"', 60, 'page script ready')
    a~personPresent=.true
    checker=.FixtureChecker~new(b, p~targetId)
    checker~showThenAnswer(0.5, 9)
    fc=.UiFindings~new
    rc2=a~send(p, 'check while sending', fc, 60)
    t~check(name, 'person present: the reply comes back after the check is answered', rc2=='Fixture reply to: check while sending', rc2)
    t~check(name, 'person present: the kit noted the check and left it to the person', fc~lines~makeString('L', ' ')~pos('asked whether a person is there')>0, fc~lines~makeString('L', ' / '))
    t~check(name, 'person present: the kit never touched the check', checker~result=='answered by the person', checker~result)
    a~personPresent=.false
    checker=.FixtureChecker~new(b, p~targetId)
    checker~showThenAnswer(0.5, 9)
    fc=.UiFindings~new
    rc3=a~send(p, 'check with nobody there', fc, 60)
    t~check(name, 'nobody present: the check is a STOP', rc3=.nil & fc~lines~makeString('L', ' ')~pos('no one is at this browser')>0, fc~lines~makeString('L', ' / '))
    address system 'curl -sk' cdpQ(fx'/api/turn-delay?seconds=0') '>/dev/null'
    call SysSleep 10                                    /* let the held-back turn and its reply land */
  end
  r2=a~send(p, 'second message', f, 60)
  t~check(name, 'second send returns the NEW reply, not the old one', r2=='Fixture reply to: second message', r2)
  added=p~count(a~map~get('user_turn_selector'))-usersBefore
  expected=2
  if name=='claude' then expected=5                     /* plus typing=keys and the two bot-check sends */
  t~check(name, expected 'user turns added to the page', added=expected, added)
  fm=.UiFindings~new                                  /* its own findings: f holds the earlier sends' notes */
  ok=a~openConversation(p, 'Nonexistent', fm)
  t~check(name, 'missing conversation is a STOP', \ok & fm~count('STOP')=1 & fm~lines[1]~pos('no conversation titled')>0, fm~lines~makeString('L', ' / '))

  /* capture: landmarks counted on the home page and the first conversation, no titles or message text */
  cap=a~capture(p)~makeString('L', '0a'x)
  t~check(name, 'capture covers the first conversation', cap~pos('== page (first conversation')>0, cap~left(200))
  t~check(name, 'capture counts the composer', cap~pos('composer_selector')>0)
  leaked=''
  do w over .array~of('Operations', 'Rasen Falcon', 'General', 'hello from the kit', 'Fixture reply')
    if cap~pos(w)>0 then leaked=leaked w
  end
  t~check(name, 'capture holds no conversation title or message text', leaked=='', leaked)

  /* the profile carries the sign-in into a new headless browser */
  t~check(name, 'browser closed cleanly', b~close)
  b=.UiTest~browser(chrome, prof, log)
  p=b~newPage
  s=a~open(p)
  t~check(name, 'relaunched on the same profile: SIGNED_ON', s=='SIGNED_ON', s)

  /* the site's bot check: recognised, waited on, never answered; send refuses */
  ok=p~navigate(a~origin'/fixture-check', 20)
  s=a~settle(p, 2)
  t~check(name, 'bot check page is BOT_CHECK', s=='BOT_CHECK', s)
  f2=.UiFindings~new
  r=a~send(p, 'should not send', f2)
  t~check(name, 'send on a bot check refuses with a STOP', r=.nil & f2~lines~makeString('L', ' ')~pos('does not answer bot checks')>0, f2~lines~makeString('L', ' / '))

  /* sign out */
  ok=p~navigate(a~origin'/logout', 20)
  s=a~settle(p, 10)
  t~check(name, 'after /logout: SIGNED_OUT', s=='SIGNED_OUT', s)
  ok=b~close
end

/* the app's own password form (no identity provider), on the claude-shaped fixture */
a=reg~adapter('claude')
b=.UiTest~browser(chrome, profileRoot'/form', log)
p=b~newPage
s=a~open(p)
ok=p~typeText('[data-testid="email"]', conf['test_user'])
ok=p~typeText('input[name="password"]', 'wrong-password')
ok=p~click('[data-testid="continue"]')
call SysSleep 1
t~check('form', 'wrong test password stays SIGNED_OUT', a~settle(p, 5)=='SIGNED_OUT', p~location)
ok=a~open(p)
ok=p~typeText('[data-testid="email"]', conf['test_user'])
ok=p~typeText('input[name="password"]', conf['test_password'])
ok=p~click('[data-testid="continue"]')
ok=p~waitFor('location.pathname!=="/login"', 10, 'form sign-in')
t~check('form', 'test password form signs on', a~settle(p, 10)=='SIGNED_ON', p~location)
ok=b~close

/* a real adapter, untouched base URL, is never pointed at by the fixture tests */
t~check('safety', 'claude adapter base is the fixture only after rebase', reg~adapter('claude')~baseUrl~pos('127.0.0.1')>0)
t~check('mode', 'claude map asks for a visible window', reg~adapter('claude')~wantsHeaded)
t~check('mode', 'chatgpt map asks for a visible window', reg~adapter('chatgpt')~wantsHeaded)
t~check('safety', 'insecure certificates are off by default', .CdpBrowser~new(chrome, profileRoot'/x')~insecureCerts==.false)
address system 'rm -rf' cdpQ(profileRoot)
exit t~finish

/* ------------------------------------------------------------------------------------------------------------ */
::class UiTest
::method init
  expose pass fail
  pass=0
  fail=0
::method check
  expose pass fail
  use strict arg group, what, ok, detail=''
  if ok then do
    pass=pass+1
    say 'PASS' left(group, 8) what
  end
  else do
    fail=fail+1
    say 'FAIL' left(group, 8) what '--' detail
  end
::method finish
  expose pass fail
  say 'browser-ui tests:' pass 'passed,' fail 'failed'
  if fail>0 then return 1
  return 0
::method browser class
  use strict arg chrome, prof, log
  b=.CdpBrowser~new(chrome, prof, .true, 9335, log)
  b~insecureCerts=.true                      /* the fixtures' self-signed localhost certificate: tests only */
  b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
  ok=b~launch
  return b

/* A simulated person: its own DevTools connection to the same tab, acting on a separate thread after a delay,
 * exactly as a human would in the visible window.  Types only the fixture's test account. */
/* Plays the site's check: shows a visible #challenge-running element, then after holdSecs removes it, as a
 * person answering it would.  If the element is already gone when it comes to remove it, someone else
 * touched it (the kit must not). */
::class FixtureChecker
::attribute result get
::method init
  expose browser targetId result
  use strict arg browser, targetId
  result='pending'
::method showThenAnswer
  expose browser targetId result
  use strict arg delay, holdSecs
  reply
  signal on syntax name broke
  call SysSleep delay
  p=browser~attach(targetId)
  v=p~evaluate('(()=>{const d=document.createElement("div");d.id="challenge-running";d.textContent="TEST: are you a person?";document.body.appendChild(d);return true;})()')
  call SysSleep holdSecs
  v=p~evaluate('(()=>{const d=document.getElementById("challenge-running");if(!d)return "gone";d.remove();return "removed";})()')
  if v=='removed' then result='answered by the person'
  else result='the check vanished before the person answered'
  return
broke:
  result='error:' condition('O')~message

::class FixturePerson
::attribute result get
::method init
  expose browser targetId conf result
  use strict arg browser, targetId, conf
  result='pending'
::method signInViaIdp
  expose browser targetId conf result
  use strict arg delay
  reply
  signal on syntax name broke
  call SysSleep delay
  p=browser~attach(targetId)
  if p~count('[data-testid="login-button"]')>0 then ok=p~click('[data-testid="login-button"]')
  if \p~waitFor('!!document.querySelector(''[data-testid="login-with-idp"]'')', 15, 'login page') then do
    result='no identity-provider link'
    return
  end
  call SysSleep 1
  ok=p~click('[data-testid="login-with-idp"]')
  if \p~waitFor('!!document.getElementById("idp-user")', 15, 'identity provider') then do
    result='identity provider page did not appear'
    return
  end
  call SysSleep 1.5
  ok=p~typeText('#idp-user', conf['test_user'])
  ok=p~typeText('#idp-password', conf['test_password'])
  ok=p~click('#idp-next')
  if \p~waitFor('!!document.getElementById("idp-code")', 15, 'code step') then do
    result='code step did not appear'
    return
  end
  call SysSleep 1
  ok=p~typeText('#idp-code', conf['test_code'])
  ok=p~click('#idp-verify')
  result='done'
  return
broke:
  result='error:' condition('O')~message

::requires 'UiKit.cls'
