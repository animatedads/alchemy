/* UiKit.cls -- browser UI adapters (Claude, ChatGPT, ...) and the sign-in hand-over, on CdpBrowser.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
 *
 *   UiSelectorMap   one etc/adapters/NAME.ui file: the page's landmarks as data (dated, re-capturable)
 *   UiAdapter       map-driven operations: state, open, conversations, openConversation, send (waits for the reply)
 *   UiAdapters      registry: every NAME.ui file in etc/adapters; class= names a plug-in subclass (file:Class) if needed
 *   UiFindings      STOP / WARN / INFO buckets; an operation that cannot proceed says why in them
 *   UiHandover      a person signs in in a VISIBLE browser on a named profile; the kit only watches the page
 *                   state (SIGNED_OUT -> AWAY at the identity provider -> SIGNED_ON), then closes the browser so
 *                   the profile is written; later headless runs on the same profile are signed on
 *
 * States: SIGNED_OUT, SIGNED_ON, AWAY (another origin, e.g. Google during sign-in), UNKNOWN.
 * The kit never types real credentials; only the fixture tests type the fixture's test account.
 */

::class UiSelectorMap public
::attribute file get
::method init
  expose file props
  use strict arg file
  props=uiReadProps(file)
::method get
  expose props
  use strict arg key, default=''
  v=props[key~lower]
  if v=.nil then return default
  return v
::method set
  expose props
  use strict arg key, value
  props[key~lower]=value

/* ------------------------------------------------------------------------------------------------------------ */
::class UiFindings public
::method init
  expose buckets
  buckets=.directory~new
  do b over .array~of('STOP', 'WARN', 'INFO')
    buckets[b]=.array~new
  end
::method add
  expose buckets
  use strict arg level, id, text
  buckets[level]~append(left(id, 12) text)
::method count
  expose buckets
  use strict arg level
  return buckets[level]~items
::method lines
  expose buckets
  out=.array~new
  do b over .array~of('STOP', 'WARN', 'INFO')
    do l over buckets[b]
      out~append(b l)
    end
  end
  return out

/* ------------------------------------------------------------------------------------------------------------ */
::class UiAdapter public
::attribute map get
/* .true when a person is at a visible browser window (browser-ui sets it): only then does the kit wait for a
 * person to answer a site's bot check; it never answers one itself */
::attribute personPresent
::method init
  expose map personPresent
  use strict arg map
  personPresent=.false
::method name
  expose map
  return map~get('name')
::method baseUrl
  expose map
  return map~get('base_url')
::method origin
  parse value self~baseUrl with scheme '://' host '/' .
  return scheme'://'host
/* A JavaScript expression, true while the page shows the site's bot check (title or element from the map). */
::method botCheckJs
  expose map
  parts=.array~new
  if map~get('bot_check_title')<>'' then parts~append('document.title==='self~sel('bot_check_title'))
  /* visible elements only: a site may keep an invisible check widget on ordinary pages */
  if map~get('bot_check_selector')<>'' then parts~append('[...document.querySelectorAll('self~sel('bot_check_selector')')].some(e=>e.getClientRects().length>0&&e.offsetWidth>0)')
  if parts~items=0 then return 'false'
  return '('parts~makeString('L', '||')')'

/* .true when the site refuses headless browsers (browser_mode=headed in the map): use a visible window. */
::method wantsHeaded
  expose map
  return (map~get('browser_mode', 'headless')=='headed')

/* Capture the signed-on page, then (if there is one) the first conversation, without naming it.
 * Structure only: no message text and no conversation titles.  Labels of the form "X for <name>" are folded to
 * "X for ..." with a count; link paths have their id-like parts masked. */
::method capture
  expose map
  use strict arg page
  out=.array~new
  out~append('== page' page~probe('location.pathname'))
  self~captureHere(page, out)
  href=page~probe('(()=>{const a=document.querySelector('self~sel('conversation_link_selector')');return a?a.getAttribute("href"):null;})()')
  if href=.nil then do
    out~append('== no conversation link matched' map~get('conversation_link_selector') '- conversation turns not captured')
    return out
  end
  ok=page~navigate(self~origin||href, 20)
  out~append('== page (first conversation, id masked)')
  self~captureHere(page, out)
  return out

::method captureHere
  expose map
  use strict arg page, out
  call SysSleep 3                                   /* sidebars and turns render after the first paint */
  do k over .array~of('signed_out_selector', 'signed_on_selector', 'composer_selector', 'send_selector', 'conversation_link_selector', 'user_turn_selector', 'assistant_turn_selector', 'busy_selector', 'assistant_text_container', 'bot_check_selector')
    sel=map~get(k)
    if sel=='' then iterate
    out~append(left(k, 28) right(page~count(sel), 4) ' ' sel)
  end
  /* a label that may carry a user's own words (a title, a host name) is withheld: more than 4 words, or any
   * digit or , : ; dash in it.  Seen 9 Nov: "<title>, rename session", "Share <title>", "Hide <name> - ..." */
  js='(()=>{const fold=s=>{const m=/^(.{2,40}?) for .+$/.exec(s);if(m)return m[1]+" for ...";if(s.split(/\s+/).length>4||/[0-9,:;–—-]/.test(s))return "(label withheld, "+s.split(/\s+/).length+" words)";return s;};'
  js=js'const mask=h=>h.split("?")[0].split("/").map(x=>/[0-9]/.test(x)||x.length>24?":id":x).join("/");'
  js=js'const tally=a=>{const t={};a.forEach(x=>t[x]=(t[x]||0)+1);return Object.entries(t).map(([k,n])=>n>1?k+"  x"+n:k);};'
  js=js'const attrs={};document.querySelectorAll("*").forEach(e=>{for(const at of e.attributes){if(!at.name.startsWith("data-"))continue;const r=attrs[at.name]||(attrs[at.name]={n:0,v:new Set()});r.n++;if(!/title|name|label/.test(at.name)&&/^[a-z-]{1,20}$/i.test(at.value))r.v.add(at.value);}});'
  js=js'return JSON.stringify({'
  js=js'testids:tally([...document.querySelectorAll("[data-testid]")].map(e=>e.tagName.toLowerCase()+" "+e.getAttribute("data-testid"))).slice(0,150),'
  js=js'buttons:tally([...document.querySelectorAll("button[aria-label]")].map(e=>fold(e.getAttribute("aria-label")))).slice(0,60),'
  js=js'editable:[...document.querySelectorAll("[contenteditable=true]")].map(e=>e.tagName.toLowerCase()+" role="+e.getAttribute("role")+" aria-label="+e.getAttribute("aria-label")+" class="+(e.className||"").toString().slice(0,60)),'
  js=js'links:tally([...document.querySelectorAll("a[href^=\"/\"]")].map(a=>mask(a.getAttribute("href")))).slice(0,40),'
  js=js'dataAttributes:Object.entries(attrs).map(([k,r])=>k+"  x"+r.n+(r.v.size&&r.v.size<=6?"  values: "+[...r.v].join(" "):"")).slice(0,200)});})()'
  v=page~probe(js)
  if v=.nil then do
    out~append('page did not answer the marker scan')
    return
  end
  d=.json~new~fromJson(v)
  do part over .array~of('testids', 'buttons', 'editable', 'links', 'dataAttributes')
    out~append(part':')
    do x over d[part]
      out~append('  '||x~string)
    end
  end

/* Point the adapter at another host with the same landmarks (the test fixtures). */
::method rebase
  expose map
  use strict arg base
  map~set('base_url', base)

::method sel
  expose map
  use strict arg key
  return cdpJs(map~get(key))

::method state
  expose map
  use strict arg page
  js='(()=>{if(location.origin!=='cdpJs(self~origin)')return "AWAY";'
  /* the site's bot check (e.g. Cloudflare "Just a moment..."): reported, waited on, never answered */
  js=js'if('self~botCheckJs')return "BOT_CHECK";'
  if map~get('signed_out_path')<>'' then js=js'if(location.pathname.startsWith('self~sel('signed_out_path')'))return "SIGNED_OUT";'
  js=js'if(document.querySelector('self~sel('signed_out_selector')'))return "SIGNED_OUT";'
  js=js'if(document.querySelector('self~sel('signed_on_selector')')&&document.querySelector('self~sel('composer_selector')'))return "SIGNED_ON";'
  js=js'return "UNKNOWN";})()'
  v=page~probe(js)
  if v=.nil then return 'UNKNOWN'
  return v

/* Evidence for a state the map does not recognise: title, address, the start of the visible text. */
::method describe
  use strict arg page
  js='JSON.stringify({title:document.title,url:location.href,text:(document.body?document.body.innerText:"").replace(/\s+/g," ").trim().slice(0,300),ua:navigator.userAgent})'
  v=page~probe(js)
  if v=.nil then return 'page did not answer'
  d=.json~new~fromJson(v)
  return 'title="'d['title']~string'" url='d['url']~string 'ua="'d['ua']~string'" text="'d['text']~string'"'

/* Open the base page and wait (up to timeout) for a definite state. */
::method open
  use strict arg page, timeout=20
  ok=page~navigate(self~baseUrl, timeout)
  return self~settle(page, timeout)
::method settle
  use strict arg page, timeout=20
  t0=.DateTime~new
  do forever
    s=self~state(page)
    /* a bot check may clear itself in a real window within seconds; the kit only waits, it never clicks it */
    if wordpos(s, 'UNKNOWN BOT_CHECK')=0 then return s
    if (.DateTime~new-t0)~totalSeconds>=timeout then return s
    call SysSleep 0.25
  end

/* .array of .directory(title, href) from the conversation list. */
::method conversations
  expose map
  use strict arg page
  attr=map~get('conversation_title_attribute', 'text')
  pick='a.textContent.trim()'
  if attr<>'text' then pick='(a.getAttribute('cdpJs(attr)')||a.textContent.trim())'
  js='JSON.stringify([...document.querySelectorAll('self~sel('conversation_link_selector')')].map(a=>({title:'pick',href:a.getAttribute("href")})))'
  v=page~probe(js)
  out=.array~new
  if v=.nil then return out
  do c over .json~new~fromJson(v)
    out~append(c)
  end
  return out

::method openConversation
  use strict arg page, title, findings
  do c over self~conversations(page)
    if c['title']~string==title then do
      ok=page~navigate(self~origin||c['href'], 20)
      if self~settle(page, 15)=='SIGNED_ON' then return .true
      findings~add('STOP', 'conversation', 'opened' c['href'] 'but the page is not signed on')
      return .false
    end
  end
  findings~add('STOP', 'conversation', 'no conversation titled' title)
  return .false

/* Send a message and wait for the reply.  Returns the reply text, or .nil with the reason in findings.
 * The last assistant turn present before sending is marked, so windowed pages (turns leaving the DOM) still
 * tell the new reply from the old ones. */
/* waitReply=.false: return 'sent' once the page has taken the message (a nudge needs no answer) */
::method send
  expose map
  use strict arg page, text, findings, timeout=120, waitReply=.true
  s=self~state(page)
  if s=='BOT_CHECK' then do
    findings~add('STOP', 'botcheck', self~name 'is showing its bot check; the kit does not answer bot checks (use a visible window: --headed)')
    return .nil
  end
  if s<>'SIGNED_ON' then do
    findings~add('STOP', 'signedout', self~name 'page is' s': a person must sign in first (browser_ui handover' self~name')')
    return .nil
  end
  mark='(()=>{const a=[...document.querySelectorAll('self~sel('assistant_turn_selector')')];a.forEach(e=>e.setAttribute("data-uikit-seen","1"));document.querySelectorAll('self~sel('user_turn_selector')').forEach(e=>e.setAttribute("data-uikit-seen","1"));return a.length;})()'
  before=page~evaluate(mark)
  /* A page can show its composer before its script is running (found 9 Nov: a click straight after load was
   * lost).  So the send is confirmed: a new user turn must appear.  If none appears:
   *   - the text is still in the composer: the click was lost, so click again (cannot double-send);
   *   - the composer is empty: the page took the text (its user turn is merely slow), so stop clicking and
   *     wait for the reply.  The text is NEVER typed a second time: a missed send is better than a double one.
   * (9 Nov 16:20, real claude.ai: attempt 1 had no user turn after 5 s on both runs; the earlier rule retyped
   * when the composer was empty, which could have sent twice.  Fixture test: /api/turn-delay.) */
  accepted='[...document.querySelectorAll('self~sel('user_turn_selector')')].some(e=>!e.hasAttribute("data-uikit-seen"))'
  stillTyped='(document.querySelector('self~sel('composer_selector')')||{textContent:""}).textContent.includes('cdpJs(text~left(min(30, text~length)))')'
  /* typing=keys in the map: real key events at a steady key_interval_ms; otherwise one text insertion */
  if map~get('typing', 'insert')=='keys' then typed=page~typeKeys(map~get('composer_selector'), text, map~get('key_interval_ms', 60))
  else typed=page~typeText(map~get('composer_selector'), text)
  if \typed then do
    findings~add('STOP', 'composer', 'no composer' map~get('composer_selector'))
    return .nil
  end
  ok=.false
  do attempt=1 to 6
    if attempt>1 then if \cdpTruthy(page~probe(stillTyped)) then do
      findings~add('INFO', 'taken', 'composer cleared without a user turn yet: treated as sent; waiting for the reply')
      ok=.true
      leave
    end
    if \page~click(map~get('send_selector')) then do
      findings~add('STOP', 'send', 'no send button' map~get('send_selector'))
      return .nil
    end
    if page~waitFor(accepted, 5, self~name 'message accepted', .true) then do
      ok=.true
      leave
    end
    if self~state(page)=='BOT_CHECK' then do
      if \self~personPresent then do
        findings~add('STOP', 'botcheck', self~name 'asked whether a person is there; no one is at this browser, and the kit does not answer bot checks')
        return .nil
      end
      page~log~warn(self~name 'is asking whether a person is there: please answer it yourself in the browser window; waiting up to 5 minutes')
      findings~add('INFO', 'botcheck', self~name 'asked whether a person is there before taking the message; waited for the person at the window')
      if \page~waitFor('!('self~botCheckJs')', 300, 'the person to answer the check') then do
        findings~add('STOP', 'botcheck', 'the check was not answered within 5 minutes')
        return .nil
      end
      iterate
    end
    findings~add('INFO', 'resend', 'attempt' attempt': no new user turn yet after 5 s; the page may still be starting')
  end
  if \ok then do
    findings~add('STOP', 'notaccepted', 'the page did not take the message after 6 attempts (30 s)')
    return .nil
  end
  if \waitReply then do
    page~log~info(self~name 'message taken; not waiting for a reply')
    return 'sent'
  end
  /* the turn marker may be a heading beside the text (chatgpt.com): read the text from its container */
  box=map~get('assistant_text_container')
  last='(()=>{const a=[...document.querySelectorAll('self~sel('assistant_turn_selector')')].pop();if(!a||a.hasAttribute("data-uikit-seen"))return null;'
  if box<>'' then last=last'const c=a.closest('cdpJs(box)')||a;let t=c.innerText;if(c!==a){const h=a.innerText;if(h&&t.startsWith(h))t=t.slice(h.length);}return t.trim();})()'
  else last=last'return a.innerText.trim();})()'
  done='(()=>{const a=[...document.querySelectorAll('self~sel('assistant_turn_selector')')].pop();return !!a&&!a.hasAttribute("data-uikit-seen")&&document.querySelectorAll('self~sel('busy_selector')').length===0;})()'
  /* Wait for the reply in 5 s steps, watching for the site's "are you a person?" check meanwhile (seen 9 Nov
   * 17:11 on claude.ai, in a visible window, mid-send).  The kit never answers it.  With a person at the window
   * (personPresent) it asks them to, and waits up to 5 more minutes while the check shows; without one it stops. */
  t0=.DateTime~new
  limit=timeout
  asked=.false
  next=5
  do forever
    if page~waitFor(done, 5, self~name 'reply', .true) then leave
    if self~state(page)=='BOT_CHECK' then do
      if \self~personPresent then do
        findings~add('STOP', 'botcheck', self~name 'asked whether a person is there; no one is at this browser, and the kit does not answer bot checks')
        return .nil
      end
      if \asked then do
        page~log~warn(self~name 'is asking whether a person is there: please answer it yourself in the browser window; waiting')
        findings~add('INFO', 'botcheck', self~name 'asked whether a person is there; waited for the person at the window to answer')
        limit=limit+300
        asked=.true
      end
    end
    secs=(.DateTime~new-t0)~totalSeconds
    if secs>=next then do
      page~log~info('still waiting for' self~name 'reply ('format(secs,,0)'s of' limit')')
      next=next+5
    end
    if secs>=limit then do
      findings~add('STOP', 'noreply', 'no finished reply within' limit 's (before:' before 'assistant turns)')
      return .nil
    end
  end
  /* the text must hold still for half a second: the busy marker can clear a moment before the last chunk */
  prev=page~probe(last)
  do 10
    call SysSleep 0.5
    now=page~probe(last)
    if now==prev then do
      page~log~info(self~name 'reply received:' now~string~length 'characters')
      return now
    end
    prev=now
  end
  findings~add('WARN', 'unsettled', 'reply text still changing after 5 s; returning the latest')
  return prev

/* ------------------------------------------------------------------------------------------------------------ */
::class UiAdapters public
::method init
  expose dir adapters
  use strict arg dir
  adapters=.directory~new
  call SysFileTree dir'/*.ui', 'f.', 'FO'
  do i=1 to f.0
    m=.UiSelectorMap~new(f.i)
    adapters[m~get('name')]=self~make(m)
  end
::method make
  use strict arg m
  spec=m~get('class', 'UiAdapter')
  if spec='UiAdapter' then return .UiAdapter~new(m)
  parse var spec file ':' className
  pkg=.context~package~loadPackage(file)
  cls=pkg~findClass(className)
  if cls=.nil then raise syntax 40.900 array('adapter' m~get('name') 'names class' spec 'which was not found')
  return cls~new(m)
::method adapter
  expose adapters
  use strict arg name
  return adapters[name]
::method names
  expose adapters
  return adapters~allIndexes~sort

/* ------------------------------------------------------------------------------------------------------------ */
::class UiHandover public
::attribute transitions get
::method init
  expose adapter log transitions
  use strict arg adapter, log
  transitions=.array~new
/* Watch the page while a person signs in.  Returns .true once SIGNED_ON; .false on timeout.  Never types. */
::method watch
  expose adapter log transitions
  use strict arg page, timeout=900
  t0=.DateTime~new
  last=''
  next=10
  ok=adapter~open(page)
  do forever
    s=adapter~state(page)
    secs=(.DateTime~new-t0)~totalSeconds
    if s<>last then do
      transitions~append(s)
      select
        when s='SIGNED_OUT' then log~info(adapter~name': waiting for you to sign in, in the browser window')
        when s='AWAY' then log~info(adapter~name': at the identity provider ('page~location~left(60)'...)')
        when s='SIGNED_ON' then log~info(adapter~name': signed on after' format(secs,,0)'s')
        otherwise log~info(adapter~name': page state' s)
      end
      last=s
    end
    if s='SIGNED_ON' then return .true
    if secs>=timeout then do
      log~warn(adapter~name': no sign-in within' timeout 's (last state' s')')
      return .false
    end
    if secs>=next then do
      log~info(adapter~name': still' s 'after' format(secs,,0)'s')
      next=next+30
    end
    call SysSleep 1
  end

/* ------------------------------------------------------------------------------------------------------------ */
/* Logging through the estate framework (oorexx_logging v0.7), as cloudctl does: one LogService 'browser-ui',
 * a file target writing var/events-YYYYMMDD.log, one rule on UiKitRun~RUN.  The console progress lines stay. */
::class UiKitRun public
::method run
  use strict arg service
  return service~loggerFor(self, 'RUN', .array~new, 'INTERNAL')

::class UiKitFileTarget public
::attribute name get
::method init
  expose name dir
  use strict arg name, dir
::method scope
  return 'INTERNAL'
::method accept
  expose dir
  use strict arg event
  f=dir'/events-'date('S')'.log'
  call lineout f, .DateTime~new~isoDate left(event~levelName, 5) event~payload~string
  call lineout f
  return .true

/* The declared-automation token for the user agent.  requestedBy: the agent that asked (CLAUDE, CHATGPT, ...)
 * or "operator" for a person at the prompt.  contact: where the operator can be reached. */
::routine uiAgentIdentity public
  use strict arg requestedBy, contact
  kind='LLM-driven request'
  if requestedBy=='operator' then kind='scripted request'
  return 'AlchemyAgent/0.1 ('kind'; requested-by='requestedBy'; +'contact')'

/* A CdpLog for this run: wired to oorexx_logging when its package is on REXX_PATH, else console only (and it
 * says so once, so a missing package is never silent). */
::routine uiLog public
  use strict arg kit, who='browser-ui'
  signal on syntax name noLogging
  pkg=.context~package~loadPackage('LoggingCore.cls')
  dir=kit'/var'
  address system 'mkdir -p' cdpQ(dir)
  service=.LogService~new(who)
  service~addTarget(.UiKitFileTarget~new('events', dir))
  rule=.LogRule~new(who'-run', who, 'UiKitRun', 'RUN', .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~of('events'), .array~new)
  service~addRule(rule)
  return .CdpLog~new(.UiKitRun~new~run(service), who)
noLogging:
  .error~lineout(who': WARN  oorexx_logging not loaded ('condition('O')~message'); console log only')
  return .CdpLog~new(.nil, who)

/* ------------------------------------------------------------------------------------------------------------ */
::routine uiReadProps public
  use strict arg file
  d=.directory~new
  if \SysFileExists(file) then return d
  s=.stream~new(file)
  s~open('read')
  do while s~lines>0
    l=s~linein~strip
    if l='' then iterate
    if l~left(1)='#' then iterate
    parse var l k '=' v
    d[k~strip~lower]=v~strip
  end
  s~close
  return d

::requires 'CdpBrowser.cls'
::requires 'json.cls'
