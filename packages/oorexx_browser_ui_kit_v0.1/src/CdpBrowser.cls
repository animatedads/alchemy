/* CdpBrowser.cls -- drive Chromium from native ooRexx over the DevTools protocol.  No Node, no Playwright.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
 *
 * Transport: the estate WebSocket client (oorexx_websocket_access on SocketProvider/RxSock) and json.cls.
 * Discovery and tab creation use the browser's local HTTP endpoints through curl.
 *
 *   b=.CdpBrowser~new(chrome, profileDir, headless, port, log)    one browser process, one profile
 *   b~launch                                                       waits until the DevTools endpoint answers
 *   p=b~newPage                                                    a CdpPage on a fresh tab
 *   p~navigate(url) / p~evaluate(js) / p~waitFor(js, secs, label) / p~click(css) / p~typeText(css, text)
 *   b~close                                                        Browser.close, so the profile is written out
 *
 * A profile directory keeps cookies between runs: a person signs in once in a visible browser, and later
 * headless runs on the same profile are signed on (UiHandover).  The profile directory is created mode 700.
 * --ignore-certificate-errors is NEVER on by default: only the fixture tests (self-signed localhost) set it.
 * Every DevTools call is logged at TRACE and every wait reports progress at INFO through the given log.
 */

::class CdpBrowser public
::attribute port get
::attribute profileDir get
::attribute headless get
::attribute log get
::attribute insecureCerts
::attribute extraFlags
/* Declared automation: a token APPENDED to the browser's own user agent on every page this browser opens,
 * e.g. "AlchemyAgent/0.1 (LLM-driven request; requested-by=CLAUDE; +https://rasenfalcon.com)".  Appended,
 * never replacing: what the browser says about itself (HeadlessChrome included) stays. */
::attribute agentIdentity
::method init
  expose chrome profileDir headless port log insecureCerts extraFlags agentIdentity
  use strict arg chrome, profileDir, headless=.true, port=9333, log=.nil
  insecureCerts=.false
  extraFlags=''
  agentIdentity=''
  if log=.nil then log=.CdpLog~new

::method launch
  expose chrome profileDir headless port log insecureCerts extraFlags
  if self~httpGet('/json/version')<>'' then raise syntax 40.900 array('a browser already answers on port' port)
  address system 'mkdir -p' cdpQ(profileDir) '&& chmod 700' cdpQ(profileDir)
  flags='--remote-debugging-port='port '--remote-allow-origins=* --user-data-dir='cdpQ(profileDir)
  flags=flags '--password-store=basic --no-first-run --no-default-browser-check --disable-search-engine-choice-screen'
  if headless then flags=flags '--headless=new'
  if insecureCerts then flags=flags '--ignore-certificate-errors'
  if extraFlags<>'' then flags=flags extraFlags
  logFile=profileDir'/../'filespec('N', profileDir)'.chrome.log'
  log~info('launch' filespec('N', profileDir) 'headless='headless 'port='port)
  address system 'nohup' cdpQ(chrome) flags 'about:blank >'cdpQ(logFile) '2>&1 &'
  do i=1 to 60
    if self~httpGet('/json/version')<>'' then do
      log~info('browser ready after' format(i*0.25,,2)'s')
      return .true
    end
    call SysSleep 0.25
  end
  raise syntax 40.900 array('browser did not open its DevTools port' port 'within 15 s; see' logFile)

::method running
  return (self~httpGet('/json/version')<>'')

/* A new tab at about:blank; navigate it with CdpPage~navigate. */
::method newPage
  expose log agentIdentity
  doc=.json~new~fromJson(self~httpPut('/json/new?about:blank'))
  page=self~attach(doc['id'])
  if agentIdentity<>'' then do
    own=page~evaluate('navigator.userAgent')
    p=.directory~new
    p['userAgent']=.JsonString~new(own~string' 'agentIdentity)
    r=page~send('Emulation.setUserAgentOverride', p)
    log~info('agent identity:' agentIdentity)
  end
  return page

::method attach
  expose log
  use strict arg targetId
  return .CdpPage~new(self, targetId, self~connect('/devtools/page/'targetId), log)

::method pages
  out=.array~new
  do t over .json~new~fromJson(self~httpGet('/json/list'))
    if t['type']='page' then out~append(t)
  end
  return out

/* Browser.close on the browser endpoint: the clean shutdown that writes the profile (cookies) out. */
::method close
  expose port log
  v=self~httpGet('/json/version')
  if v='' then return .true
  url=.json~new~fromJson(v)['webSocketDebuggerUrl']
  conn=self~connect(url~substr(url~pos('/devtools/')))
  msg=.directory~new
  msg['id']=1
  msg['method']='Browser.close'
  ok=conn~sendText(.json~new~toJson(msg))
  do i=1 to 40
    if \self~running then do
      log~info('browser closed')
      return .true
    end
    call SysSleep 0.25
  end
  log~warn('browser still answering 10 s after Browser.close')
  return .false

::method connect
  expose port
  use strict arg path
  addrp=.RegisteredSocketAddressProvider~new
  addrp~register('cdp', .SocketAddresses~tcp('127.0.0.1', port, 'cdp'), 'SENDER')
  sp=.SocketProvider~new(addrp)
  sp~registerBinding(.SocketTransportKind~TCP, .RxSockTcpBinding~new)
  entropy=.CdpUrandom~new
  access=.WebSocketAccess~new(sp, .WebSocketCryptoAuthHandshake~new(entropy), .WebSocketCryptoAuthMaskSource~new(entropy))
  conn=access~connect('cdp', .WebSocketClientOptions~new(path, '127.0.0.1:'port))
  if conn=.nil then raise syntax 40.900 array('DevTools WebSocket handshake failed for' path)
  return conn

::method httpGet
  expose port
  use strict arg path
  address system 'curl -s -m 3 http://127.0.0.1:'port||path with output stem o.
  if o.0=0 then return ''
  text=''
  do i=1 to o.0
    text=text o.i
  end
  return text~strip
::method httpPut
  expose port
  use strict arg path
  address system 'curl -s -m 5 -X PUT "http://127.0.0.1:'port||path'"' with output stem o.
  text=''
  do i=1 to o.0
    text=text o.i
  end
  return text~strip

/* ------------------------------------------------------------------------------------------------------------ */
::class CdpPage public
::attribute targetId get
::attribute log get
::method init
  expose browser targetId conn log nextId
  use strict arg browser, targetId, conn, log
  nextId=0

/* One DevTools command; events arriving meanwhile are skipped.  A protocol error is a syntax error. */
::method send
  expose conn log nextId
  use strict arg method, params=.nil
  nextId=nextId+1
  msg=.directory~new
  msg['id']=nextId
  msg['method']=method
  if params<>.nil then msg['params']=params
  log~trace('>' method)
  if \conn~sendText(.json~new~toJson(msg)) then raise syntax 40.900 array('DevTools connection closed while sending' method)
  do forever
    m=conn~receive
    if m=.nil then raise syntax 40.900 array('DevTools connection closed waiting for' method)
    doc=.json~new~fromJson(m~payload)
    if \doc~hasIndex('id') then iterate
    if doc['id']<>nextId then iterate
    if doc~hasIndex('error') then raise syntax 40.900 array(method 'failed:' doc['error']['message'])
    return doc['result']
  end

/* The value of a JavaScript expression (promises awaited); a thrown exception is a syntax error. */
::method evaluate
  use strict arg expression
  p=.directory~new
  p['expression']=expression
  p['returnByValue']=.json~true
  p['awaitPromise']=.json~true
  r=self~send('Runtime.evaluate', p)
  if r~hasIndex('exceptionDetails') then raise syntax 40.900 array('page script failed:' cdpExceptionText(r['exceptionDetails']))
  return r['result']['value']

/* evaluate, but a script failure (page between navigations, element gone) answers .nil instead of raising. */
::method probe
  use strict arg expression
  signal on syntax name failed
  return self~evaluate(expression)
failed:
  return .nil

::method navigate
  expose log
  use strict arg url, timeout=30
  p=.directory~new
  p['url']=url
  log~info('navigate' url)
  r=self~send('Page.navigate', p)
  if r~hasIndex('errorText') then raise syntax 40.900 array('navigation to' url 'failed:' r['errorText'])
  return self~waitFor('document.readyState==="complete"', timeout, 'page load')

/* Poll a JavaScript condition until it is truthy.  Progress every 5 s; .false on timeout (the caller decides). */
/* quiet=.true: no give-up warning (for a caller that waits in steps and reports progress itself) */
::method waitFor
  expose log
  use strict arg expression, timeout, label, quiet=.false
  t0=.DateTime~new
  next=5
  do forever
    v=self~probe(expression)
    if cdpTruthy(v) then return .true
    secs=(.DateTime~new-t0)~totalSeconds
    if secs>=timeout then do
      if \quiet then log~warn('gave up waiting for' label 'after' format(secs,,0)'s')
      return .false
    end
    if secs>=next then do
      log~info('still waiting for' label '('format(secs,,0)'s of' timeout')')
      next=next+5
    end
    call SysSleep 0.25
  end

/* A real mouse click at the element's centre.  .false when the element is not there. */
::method click
  expose log
  use strict arg selector
  js='(()=>{const e=document.querySelector('cdpJs(selector)');if(!e)return null;e.scrollIntoView({block:"center"});const b=e.getBoundingClientRect();return [b.x+b.width/2,b.y+b.height/2];})()'
  at=self~evaluate(js)
  if at=.nil then do
    log~warn('click: no element' selector)
    return .false
  end
  do kind over .array~of('mouseMoved', 'mousePressed', 'mouseReleased')
    p=.directory~new
    p['type']=kind
    p['x']=at[1]
    p['y']=at[2]
    p['button']='left'
    p['clickCount']=1
    r=self~send('Input.dispatchMouseEvent', p)
  end
  log~trace('clicked' selector)
  return .true

/* Focus an element and insert text as typed input (works for inputs and contenteditable editors). */
::method typeText
  use strict arg selector, text
  /* replaces what the field holds (select all, then insert), so typing twice never doubles the text */
  ok=self~evaluate('(()=>{const e=document.querySelector('cdpJs(selector)');if(!e)return false;e.focus();if(e.select){e.select();}else{const r=document.createRange();r.selectNodeContents(e);const s=getSelection();s.removeAllRanges();s.addRange(r);}return true;})()')
  if \cdpTruthy(ok) then return .false
  p=.directory~new
  p['text']=.JsonString~new(text)
  r=self~send('Input.insertText', p)
  return .true

/* Type key by key (real key events), one key every intervalMs, steady.  For pages whose fields act on key
 * events (search boxes with suggestions).  Replaces what the field holds, like typeText. */
::method typeKeys
  use strict arg selector, text, intervalMs=60
  ok=self~evaluate('(()=>{const e=document.querySelector('cdpJs(selector)');if(!e)return false;e.focus();if(e.select){e.select();}else{const r=document.createRange();r.selectNodeContents(e);const s=getSelection();s.removeAllRanges();s.addRange(r);}return true;})()')
  if \cdpTruthy(ok) then return .false
  do i=1 to text~length
    c=text~substr(i, 1)
    p=.directory~new
    p['type']='keyDown'
    p['text']=.JsonString~new(c)
    p['unmodifiedText']=.JsonString~new(c)
    p['key']=.JsonString~new(c)
    r=self~send('Input.dispatchKeyEvent', p)
    p=.directory~new
    p['type']='keyUp'
    p['key']=.JsonString~new(c)
    r=self~send('Input.dispatchKeyEvent', p)
    call SysSleep intervalMs/1000
  end
  return .true

::method count
  use strict arg selector
  n=self~probe('document.querySelectorAll('cdpJs(selector)').length')
  if n=.nil then return 0
  return n

/* Save a PNG of the visible page.  .true when written. */
::method screenshot
  use strict arg file
  p=.directory~new
  p['format']='png'
  r=self~send('Page.captureScreenshot', p)
  s=.stream~new(file)
  s~open('write replace')
  s~charout(r['data']~string~decodeBase64)
  s~close
  return SysFileExists(file)

::method location
  v=self~probe('location.href')
  if v=.nil then return ''
  return v

::method close
  expose browser targetId
  r=browser~httpGet('/json/close/'targetId)
  return .true

/* ------------------------------------------------------------------------------------------------------------ */
/* Log adapter: an estate logger when given one (oorexx_logging), otherwise progress lines on stderr. */
::class CdpLog public
::method init
  expose logger who
  use strict arg logger=.nil, who='browser-ui'
::method emit
  expose logger who
  use strict arg level, text
  if logger<>.nil then do
    logger~log(logger~send(level), .CdpEvent~new(level, text))
    if wordpos(level, 'TRACE')>0 then return
  end
  if level='TRACE' then return
  .error~lineout(who':' left(level, 5) text)
::method trace
  use strict arg text
  self~emit('TRACE', text)
::method info
  use strict arg text
  self~emit('INFO', text)
::method warn
  use strict arg text
  self~emit('WARN', text)
::method error
  use strict arg text
  self~emit('ERROR', text)

::class CdpEvent public
::attribute level get
::attribute text get
::method init
  expose level text
  use strict arg level, text
::method string
  expose level text
  return text

::class CdpUrandom public subclass WebSocketEntropySource
::method nextBytes
  use strict arg n
  s=.stream~new('/dev/urandom')
  s~open('read')
  b=s~charin(, n)
  s~close
  return b

/* ------------------------------------------------------------------------------------------------------------ */
::routine cdpQ public
  use strict arg s
  return "'"s~changeStr("'", "'\''")"'"
/* A JavaScript string literal (JSON string syntax is valid JavaScript). */
::routine cdpJs public
  use strict arg s
  return .json~new~toJson(.JsonString~new(s))
::routine cdpTruthy public
  use strict arg v
  if v~isNil then return .false
  if v~isA(.String) then do
    if v=='' then return .false
    if v=='0' then return .false
    return .true
  end
  if v=0 then return .false
  return .true
::routine cdpExceptionText public
  use strict arg d
  if d~hasIndex('exception') then do
    e=d['exception']
    if e~hasIndex('description') then return e['description']~string~left(200)
  end
  return ccStr2(d['text'])
::routine ccStr2
  use strict arg v
  if v~isNil then return ''
  return v~string

::requires 'WebSocketAccess.cls'
::requires 'WebSocketPlatformCrypto.cls'
::requires 'RxSockSocketBinding.cls'
::requires 'json.cls'
