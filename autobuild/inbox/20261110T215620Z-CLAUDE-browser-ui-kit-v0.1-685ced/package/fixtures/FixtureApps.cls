/* FixtureApps.cls -- test chat applications for the browser UI kit, served by the ooRexx HTTPS server.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
 *
 * Two test apps carry the same landmarks (attributes, roles, labels, paths) as the real Claude and ChatGPT pages,
 * so the adapters run against them unchanged apart from base_url.  They do NOT copy either product's look or
 * branding: neutral styling and a TEST FIXTURE banner on every page.  A third origin plays an outside identity
 * provider (as Google is for Tom's sign-in) with a password step and a one-time-code step, then hands a single-use
 * ticket back to the app.  Test credentials come from etc/fixtures.conf and work only here.
 *
 *   FixtureStore         sessions, tickets, conversations, replies (one per host process, shared by all apps)
 *   FixtureApp           base: cookies, sign-in, sign-out, identity-provider hand-back, the send/reply API
 *   FixtureClaudeShaped  /login, /new, /chat/<id>                                   cookie fxc_sid
 *   FixtureChatGptShaped /, /auth/login, /c/<id>                                    cookie fxg_sid
 *   FixtureIdp           /authorize (password) -> /code (one-time code) -> app /idp-return?ticket=
 *
 * Each app is an HTTPS server interceptor: beforeRequest answers every path it owns.  Pages load the shared
 * client fixture.rex (ooRexx/WASM, Josep Maria Blasco's runtime) for the composer, send and streamed reply.
 */

::class FixtureStore public
/* seconds between the composer clearing and the user turn appearing (tests a slow page; 0 = at once) */
::attribute turnDelay
/* the User-Agent of the last /api/send, for the tests (shown at /api/last-agent) */
::attribute lastAgent
::method init
  expose config sessions tickets conversations replies seq turnDelay lastAgent
  use strict arg config
  turnDelay=0
  lastAgent=''
  sessions=.directory~new
  tickets=.directory~new
  replies=.directory~new
  seq=0
  conversations=.array~new
  do t over .array~of('Operations', 'Rasen Falcon', 'General')
    c=.directory~new
    c['id']=fxId(t)
    c['title']=t
    c['turns']=.array~new
    conversations~append(c)
  end
::method config
  expose config
  return config
::method newToken guarded
  expose seq
  seq=seq+1
  return fxRandomHex(16)||seq
::method startSession guarded
  expose sessions
  use strict arg app, user
  sid=self~newToken
  sessions[app'/'sid]=user
  return sid
::method sessionUser guarded
  expose sessions
  use strict arg app, sid
  if sid='' then return ''
  u=sessions[app'/'sid]
  if u=.nil then return ''
  return u
::method endSession guarded
  expose sessions
  use strict arg app, sid
  sessions~remove(app'/'sid)
::method issueTicket guarded
  expose tickets
  use strict arg app, user
  t=self~newToken
  tickets[t]=app'/'user
  return t
/* Single use: the ticket is gone after one redemption. */
::method redeemTicket guarded
  expose tickets
  use strict arg app, ticket
  v=tickets[ticket]
  if v=.nil then return ''
  tickets~remove(ticket)
  parse var v forApp '/' user
  if forApp<>app then return ''
  return user
::method conversations
  expose conversations
  return conversations
::method conversation
  expose conversations
  use strict arg id
  do c over conversations
    if c['id']=id then return c
  end
  return .nil
/* A user turn and its pending reply; the reply streams out over time (FixtureStore~reply). */
::method addTurn guarded
  expose replies
  use strict arg conv, text
  turnId=self~newToken
  conv['turns']~append(.array~of('user', text))
  r=.directory~new
  r['text']='Fixture reply to: 'text
  r['start']=.DateTime~new
  r['conv']=conv
  replies[turnId]=r
  return turnId
/* .array(done, text so far): ~40 characters a second, done half a second after the last one. */
::method reply guarded
  expose replies
  use strict arg turnId
  r=replies[turnId]
  if r=.nil then return .nil
  secs=(.DateTime~new-r['start'])~totalSeconds
  full=r['text']
  n=min(full~length, max(0, trunc((secs-0.4)*40)))
  done=(secs>=0.9+full~length/40)
  if done, \r~hasIndex('recorded') then do
    r['conv']['turns']~append(.array~of('assistant', full))
    r['recorded']=.true
  end
  return .array~of(done, full~left(n))

/* ------------------------------------------------------------------------------------------------------------ */
::class FixtureApp public
::attribute name get
::attribute port get
::method init
  expose name port store cookie origin idpOrigin assets web
  use strict arg name, port, store, cookie, idpOrigin, assets, web
  origin='https://127.0.0.1:'port
::method origin
  expose origin
  return origin
::method store
  expose store
  return store

/* Interceptor entry: every request to this app's server. */
::method beforeRequest unguarded
  expose name
  use strict arg request, context
  path=request~path
  select
    when path='/ooRexx.js' | path='/ooRexx-worker.js' | path='/rexx.js' | path='/js-realm.js' | path='/polygon-clipping.umd.min.js' then return self~asset(path)
    when path='/rexx.wasm' | path='/rexx.data' then return self~asset(path)
    when path='/fixture.rex' then return self~webFile('fixture.rex', 'text/plain; charset=utf-8')
    when path='/idp-start' then return self~redirect(self~idpUrl)
    when path='/idp-return' then return self~idpReturn(request)
    when path='/logout' then return self~logout(request)
    when path='/fixture-check' then return self~html('<!doctype html><html><head><title>Just a moment...</title></head><body><div class="fx-banner">TEST FIXTURE - stand-in for a site bot check</div><div id="challenge-running">checking (test)</div></body></html>')
    when path='/api/send' then return self~apiSend(request)
    when path='/api/last-agent' then return self~text(self~store~lastAgent)
    when path='/api/turn-delay' then do
      n=fxQuery(request~query, 'seconds')
      if \datatype(n, 'W') then n=0
      self~store~turnDelay=max(0, min(n, 10))
      return self~text('turn delay' self~store~turnDelay)
    end
    when path='/api/sleep' then do
      n=fxQuery(request~query, 'seconds')
      if datatype(n, 'W') then call SysSleep max(0, min(n, 10))
      return self~text('slept')
    end
    when path='/api/reply' then return self~apiReply(request)
    when path=self~loginPath then return self~login(request)
    otherwise return self~page(request)
  end

::method idpUrl
  expose idpOrigin name origin
  return idpOrigin'/authorize?app='name'&return='fxUrlEncode(origin'/idp-return')

::method user
  expose store name cookie
  use strict arg request
  return store~sessionUser(name, fxCookie(request~header('cookie'), cookie))

::method login
  expose store name
  use strict arg request
  if request~method='POST' then do
    f=fxForm(request~body)
    if self~checkPassword(f['email'], f['password']) then return self~signedIn(f['email'])
    return self~html(self~loginPage('That test account and password do not match.'), 401)
  end
  return self~html(self~loginPage(''))
::method checkPassword
  expose store
  use strict arg user, password
  c=store~config
  if user=.nil | password=.nil then return .false
  return (user==c['test_user']) & (password==c['test_password'])
::method signedIn
  expose store name cookie
  use strict arg user
  sid=store~startSession(name, user)
  r=self~redirect(self~homePath)
  r~header('Set-Cookie', cookie'='sid'; Path=/; Max-Age=86400; HttpOnly; Secure; SameSite=Lax')
  return r
::method idpReturn
  expose store name
  use strict arg request
  user=store~redeemTicket(name, fxQuery(request~query, 'ticket'))
  if user='' then return self~html(self~loginPage('The identity provider ticket was not valid.'), 401)
  return self~signedIn(user)
::method logout
  expose store name cookie
  use strict arg request
  store~endSession(name, fxCookie(request~header('cookie'), cookie))
  r=self~redirect(self~loginPath)
  r~header('Set-Cookie', cookie'=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax')
  return r

::method apiSend
  expose store
  use strict arg request
  if self~user(request)='' then return self~text('signed out', 401)
  if request~method<>'POST' then return self~text('POST only', 405)
  store~lastAgent=request~header('User-Agent', '')          /* tests check the declared-automation token */
  parse value request~body with convId '09'x text
  conv=store~conversation(convId)
  if conv=.nil then return self~text('no such conversation', 404)
  if text~strip='' then return self~text('empty message', 400)
  return self~text(store~addTurn(conv, text))
/* Long poll: waits up to 1 s for more reply text; answers "done<TAB>text so far". */
::method apiReply unguarded
  expose store
  use strict arg request
  if self~user(request)='' then return self~text('signed out', 401)
  turnId=fxQuery(request~query, 'turn')
  seen=fxQuery(request~query, 'seen')
  if \seen~datatype('W') then seen=0
  do i=1 to 5
    r=store~reply(turnId)
    if r=.nil then return self~text('no such turn', 404)
    if r[1] then leave
    if r[2]~length>seen then leave
    call SysSleep 0.2
  end
  return self~text((r[1]=1)'09'x||r[2])

::method page
  use strict arg request
  if self~user(request)='' then return self~signedOutPage(request)
  return self~signedOnPage(request)

/* --- what the shapes override --- */
::method loginPath abstract
::method homePath abstract
::method signedOutPage abstract
::method signedOnPage abstract
::method shapeName abstract

/* --- responses --- */
::method secure
  use strict arg r
  r~header('Cache-Control', 'no-store')
  r~header('X-Content-Type-Options', 'nosniff')
  r~header('Cross-Origin-Opener-Policy', 'same-origin')
  r~header('Cross-Origin-Embedder-Policy', 'require-corp')
  r~header('Cross-Origin-Resource-Policy', 'same-origin')
  return r
::method html
  use strict arg body, status=200
  return self~secure(.HttpResponse~new(status, body, 'text/html; charset=utf-8'))
::method text
  use strict arg body, status=200
  return self~secure(.HttpResponse~text(body, status))
::method redirect
  use strict arg location
  r=.HttpResponse~new(302, '', 'text/plain; charset=utf-8')
  r~header('Location', location)
  return self~secure(r)
::method asset
  expose assets
  use strict arg path
  mime='text/javascript; charset=utf-8'
  if path='/rexx.wasm' then mime='application/wasm'
  if path='/rexx.data' then mime='application/octet-stream'
  return self~file(assets||path, mime)
::method webFile
  expose web
  use strict arg name, mime
  return self~file(web'/'name, mime)
::method file
  use strict arg path, mime
  if \SysFileExists(path) then return self~text('missing' path, 404)
  s=.stream~new(path)
  s~open('read')
  body=s~charin(1, s~chars)
  s~close
  return self~secure(.HttpResponse~new(200, body, mime))

/* The page frame: neutral look, TEST FIXTURE banner, the WASM client. */
::method frame
  use strict arg title, bodyAttrs, inner
  h='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
  h=h'<title>'fxEsc(title)'</title><style>'
  h=h':root{color-scheme:light}body{margin:0;font:15px/1.5 system-ui,sans-serif;background:#f3f3f1;color:#222}'
  h=h'.fx-banner{background:#fff3c4;border-bottom:2px solid #c9a227;padding:8px 16px;font-weight:600}'
  h=h'.fx-shell{display:grid;grid-template-columns:230px 1fr;min-height:calc(100vh - 42px)}nav{background:#e9e9e6;padding:12px}'
  h=h'nav a{display:block;padding:7px 9px;border-radius:6px;color:#222;text-decoration:none}nav a:hover{background:#dcdcd8}'
  h=h'main{display:flex;flex-direction:column;padding:16px}.fx-turns{flex:1}.fx-turn{margin:8px 0;padding:10px 12px;border-radius:8px;background:#fff;border:1px solid #ddd;white-space:pre-wrap}'
  h=h'.fx-composer{display:flex;gap:8px;border-top:1px solid #ccc;padding-top:12px}[contenteditable]{flex:1;min-height:40px;background:#fff;border:1px solid #aaa;border-radius:8px;padding:8px}'
  h=h'button{padding:8px 14px;border-radius:8px;border:1px solid #888;background:#fff;cursor:pointer}form{max-width:360px;margin:40px auto;display:grid;gap:10px}'
  h=h'input{padding:8px;border:1px solid #aaa;border-radius:6px}.fx-error{color:#a00}</style></head>'
  h=h'<body 'bodyAttrs'><div class="fx-banner">TEST FIXTURE - page structure shaped like 'self~shapeName' for adapter tests. Not affiliated with it; test accounts only.</div>'
  return h||inner'</body></html>'

::method loginForm
  use strict arg message
  h='<form method="post" action="'self~loginPath'"><h2>Sign in (test)</h2>'
  if message<>'' then h=h'<p class="fx-error">'fxEsc(message)'</p>'
  h=h'<input data-testid="email" name="email" type="email" autocomplete="username" placeholder="test account">'
  h=h'<input name="password" type="password" autocomplete="current-password" placeholder="test password">'
  h=h'<button data-testid="continue" type="submit">Continue</button>'
  h=h'<a data-testid="login-with-idp" href="/idp-start">Continue with the test identity provider</a></form>'
  return h
::method loginPage
  use strict arg message
  return self~frame('Sign in (test fixture)', '', self~loginForm(message))

/* Chat page with the shape's landmarks; client behaviour in fixture.rex reads the data-fx-* attributes. */
::method chatPage
  use strict arg conv, sidebar, composerAttrs, sendAttrs, userTemplate, assistantTemplate, busyAttr, busyValue, doneValue
  turns=''
  if conv<>.nil then do t over conv['turns']
    if t[1]='user' then turns=turns||userTemplate~changeStr('{TEXT}', fxEsc(t[2]))
    else turns=turns||assistantTemplate~changeStr('{TEXT}', fxEsc(t[2]))~changeStr('{STATE}', doneValue)
  end
  convId=''
  if conv<>.nil then convId=conv['id']
  attrs='data-fx-conversation="'convId'" data-fx-busy-attr="'busyAttr'" data-fx-busy="'busyValue'" data-fx-done="'doneValue'" data-fx-turn-delay="'self~store~turnDelay'"'
  inner='<div class="fx-shell"><nav>'sidebar'<a href="/logout">Sign out</a></nav><main><div class="fx-turns" id="fx-turns">'turns'</div>'
  inner=inner'<template id="fx-user">'userTemplate'</template><template id="fx-assistant">'assistantTemplate'</template>'
  inner=inner'<div class="fx-composer"><div 'composerAttrs'></div><button id="fx-send" 'sendAttrs'>Send</button></div>'
  inner=inner'<div id="fx-status" hidden>loading</div></main></div>'
  inner=inner'<script src="/ooRexx.js"></script><script type="text/rexx" src="/fixture.rex"></script>'
  title='Test chat'
  if conv<>.nil then title=conv['title']' (test)'
  return self~frame(title, attrs, inner)

/* ------------------------------------------------------------------------------------------------------------ */
::class FixtureClaudeShaped public subclass FixtureApp
::method shapeName
  return 'claude.ai'
::method loginPath
  return '/login'
::method homePath
  return '/new'
::method signedOutPage
  use strict arg request
  return self~redirect('/login')
::method signedOnPage
  use strict arg request
  path=request~path
  conv=.nil
  if path~startsWith('/chat/') then do
    conv=self~store~conversation(path~substr(7))
    if conv=.nil then return self~text('no such conversation', 404)
  end
  else if path<>'/new' then return self~redirect('/new')
  if conv=.nil then conv=self~store~conversations[1]
  side='<button data-testid="user-menu-button">Test user</button>'
  /* a label carrying the conversation title, as the real page has: capture must withhold it */
  side=side'<button aria-label="'fxEsc(conv['title'])', rename session">rename</button>'
  do c over self~store~conversations
    side=side'<a href="/chat/'c['id']'">'fxEsc(c['title'])'</a>'
  end
  composer='contenteditable="true" role="textbox" aria-label="Write your prompt to Claude"'
  send='data-testid="chat-input-send" aria-label="Send message"'
  user='<div class="fx-turn" data-testid="user-message">{TEXT}</div>'
  asst='<div class="fx-turn" data-testid="assistant-message" data-is-streaming="{STATE}"><div data-fx-text>{TEXT}</div></div>'
  return self~html(self~chatPage(conv, side, composer, send, user, asst, 'data-is-streaming', 'true', 'false'))

::class FixtureChatGptShaped public subclass FixtureApp
::method shapeName
  return 'chatgpt.com'
::method loginPath
  return '/auth/login'
::method homePath
  return '/'
/* chatgpt.com serves a page when signed out, with a log-in button and no conversation list. */
::method signedOutPage
  use strict arg request
  inner='<main style="padding:40px"><h2>Signed out (test)</h2><a data-testid="login-button" href="/auth/login">Log in</a></main>'
  return self~html(self~frame('Signed out (test fixture)', '', inner))
::method signedOnPage
  use strict arg request
  path=request~path
  conv=.nil
  if path~startsWith('/c/') then do
    conv=self~store~conversation(path~substr(4))
    if conv=.nil then return self~text('no such conversation', 404)
  end
  else if path<>'/' then return self~redirect('/')
  if conv=.nil then conv=self~store~conversations[1]
  side=''
  do c over self~store~conversations
    side=side'<a href="/c/'c['id']'" aria-label="'fxEsc(c['title'])'">'fxEsc(c['title'])'</a>'
  end
  composer='contenteditable="true" role="textbox" aria-label="Ask ChatGPT"'
  send='aria-label="Send"'
  user='<div class="fx-turn"><h4 data-conversation-role="user" hidden>You said:</h4><div data-fx-text>{TEXT}</div></div>'
  asst='<div class="fx-turn" data-talvt-turn-state="{STATE}"><h4 data-conversation-role="assistant" hidden>Reply:</h4><div data-fx-text>{TEXT}</div></div>'
  return self~html(self~chatPage(conv, side, composer, send, user, asst, 'data-talvt-turn-state', 'streaming', 'complete'))

/* ------------------------------------------------------------------------------------------------------------ */
/* The outside identity provider: a different origin, a password step, then a one-time-code step. */
::class FixtureIdp public subclass FixtureApp
::method init
  expose apps
  use strict arg name, port, store, cookie, idpOrigin, assets, web
  self~init:super(name, port, store, cookie, idpOrigin, assets, web)
  apps=.directory~new
::method addApp
  expose apps
  use strict arg app
  apps[app~name]=app~origin'/idp-return'
::method shapeName
  return 'an outside identity provider'
::method loginPath
  return '/authorize'
::method homePath
  return '/authorize'
::method beforeRequest unguarded
  expose apps
  use strict arg request, context
  path=request~path
  app=fxQuery(request~query, 'app')
  if \apps~hasIndex(app) then return self~text('unknown app', 400)
  back=apps[app]
  select
    when path='/authorize' then do
      if request~method='POST' then do
        f=fxForm(request~body)
        if self~checkPassword(f['email'], f['password']) then return self~redirect('/code?app='app'&user='fxUrlEncode(f['email']))
        return self~html(self~idpPage(app, 'That test account and password do not match.'), 401)
      end
      return self~html(self~idpPage(app, ''))
    end
    when path='/code' then do
      user=fxQuery(request~query, 'user')
      if request~method='POST' then do
        f=fxForm(request~body)
        if f['code']==self~store~config['test_code'] then return self~redirect(back'?ticket='self~store~issueTicket(app, user))
        return self~html(self~codePage(app, user, 'That code is not right.'), 401)
      end
      return self~html(self~codePage(app, user, ''))
    end
    otherwise return self~text('not found', 404)
  end
::method idpPage
  use strict arg app, message
  h='<form method="post" action="/authorize?app='app'"><h2>Test identity provider</h2>'
  if message<>'' then h=h'<p class="fx-error">'fxEsc(message)'</p>'
  h=h'<input id="idp-user" name="email" autocomplete="username" placeholder="test account"><input id="idp-password" name="password" type="password" placeholder="test password">'
  h=h'<button id="idp-next" type="submit">Next</button></form>'
  return self~frame('Test identity provider', '', h)
::method codePage
  use strict arg app, user, message
  h='<form method="post" action="/code?app='app'&user='fxUrlEncode(user)'"><h2>Test identity provider: one-time code</h2>'
  if message<>'' then h=h'<p class="fx-error">'fxEsc(message)'</p>'
  h=h'<input id="idp-code" name="code" inputmode="numeric" placeholder="6-digit test code"><button id="idp-verify" type="submit">Verify</button></form>'
  return self~frame('Test identity provider: code', '', h)

/* ------------------------------------------------------------------------------------------------------------ */
::routine fxEsc public
  use strict arg s
  s=s~changeStr('&', '&amp;')
  s=s~changeStr('<', '&lt;')
  s=s~changeStr('>', '&gt;')
  return s~changeStr('"', '&quot;')
::routine fxId public
  use strict arg title
  return title~lower~changeStr(' ', '-')
::routine fxRandomHex public
  use strict arg n
  s=.stream~new('/dev/urandom')
  s~open('read')
  b=s~charin(, n)
  s~close
  return b~c2x~lower
::routine fxUrlEncode public
  use strict arg s
  out=''
  do i=1 to s~length
    ch=s~subchar(i)
    if ch~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~')=0 then out=out||ch
    else out=out'%'ch~c2x
  end
  return out
::routine fxUrlDecode public
  use strict arg s
  s=s~changeStr('+', ' ')
  out=''
  i=1
  do while i<=s~length
    ch=s~subchar(i)
    if ch='%', i+2<=s~length then do
      out=out||s~substr(i+1, 2)~x2c
      i=i+3
      iterate
    end
    out=out||ch
    i=i+1
  end
  return out
::routine fxForm public
  use strict arg body
  d=.directory~new
  do while body<>''
    parse var body pair '&' body
    parse var pair k '=' v
    d[fxUrlDecode(k)]=fxUrlDecode(v)
  end
  return d
::routine fxQuery public
  use strict arg query, name
  if query~isNil then return ''
  f=fxForm(query)
  v=f[name]
  if v=.nil then return ''
  return v
::routine fxCookie public
  use strict arg header, name
  do while header<>''
    parse var header pair ';' header
    parse var pair k '=' v
    if k~strip==name then return v~strip
  end
  return ''

::requires 'https_server.cls'
