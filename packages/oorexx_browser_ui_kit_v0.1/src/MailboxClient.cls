/* MailboxClient.cls -- the Rasen Falcon mailbox over HTTPS, as one principal with a static bearer token.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 10 November 2026.
 *
 *   MailboxClient~new(url, tokenFile, curl)    url: .../mcp; tokenFile: mode 600, the token only
 *   ~call(tool, args)   -> .directory: ok, code, value (the parsed JSON after "OK CODE: "), text, error
 *   ~unread             -> .array of request .directory objects addressed to this principal and not marked read
 *   ~reply(requestId, body, subject)          ~markRead(requestId)
 *
 * The token never appears on a command line or in a log: curl reads the Authorization header from stdin
 * (-H @-) and the JSON body from a mode-600 temp file.  JSON-RPC tools/call, MCP protocol 2025-11-25.
 */

::class MailboxClient public
::attribute principal get
::method init
  expose url tokenFile curl principal tmpDir seq
  use strict arg url, tokenFile, curl, principal, tmpDir
  seq=0
  address system 'mkdir -p' mbQ(tmpDir) '&& chmod 700' mbQ(tmpDir)

/* Checks before any call: the token file exists, is mode 600 or 400, and holds one word. */
::method ready
  expose tokenFile
  use strict arg findings
  if \SysFileExists(tokenFile) then do
    findings~add('STOP', 'token', 'no token file' tokenFile)
    return .false
  end
  address system 'stat -c %a' mbQ(tokenFile) with output stem o.
  mode=''
  if o.0>0 then mode=o.1~strip
  if wordpos(mode, '600 400')=0 then do
    findings~add('STOP', 'token', tokenFile 'must be mode 600 or 400 (is' mode')')
    return .false
  end
  if mbFile(tokenFile)~strip~words<>1 then do
    findings~add('STOP', 'token', tokenFile 'must hold exactly one token')
    return .false
  end
  return .true

::method call
  expose url tokenFile curl tmpDir seq
  use strict arg tool, args
  seq=seq+1
  req=.directory~new
  req['jsonrpc']='2.0'
  req['id']=seq
  req['method']='tools/call'
  p=.directory~new
  p['name']=tool
  p['arguments']=args
  req['params']=p
  bodyFile=tmpDir'/call-'seq'.json'
  outFile=tmpDir'/out-'seq'.json'
  call mbWrite bodyFile, .json~new~toJson(req)
  hdr=tmpDir'/hdr-'seq
  call mbWrite hdr, 'Authorization: Bearer' mbFile(tokenFile)~strip
  cmd=curl '-sS --max-time 30 -X POST -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" -H "MCP-Protocol-Version: 2025-11-25" -H @-' '--data-binary' '@'mbQ(bodyFile) '-o' mbQ(outFile) '-w "%{http_code}"' mbQ(url) '<' mbQ(hdr)
  address system cmd with output stem o. error stem e.
  crc=rc
  address system 'rm -f' mbQ(hdr) mbQ(bodyFile)
  res=.directory~new
  res['ok']=.false
  res['code']=''
  res['value']=.nil
  res['text']=''
  res['error']=''
  http=''
  if o.0>0 then http=o.[o.0]~strip
  if crc<>0 | http<>200 then do
    msg='curl rc='crc 'http='http
    if e.0>0 then msg=msg e.1
    res['error']=msg
    return res
  end
  raw=mbFile(outFile)
  /* a streamed answer arrives as "data: {...}" lines */
  if raw~pos('data:')>0 & raw~strip~left(1)<>'{' then parse var raw 'data:' raw
  j=mbParse(raw~strip)
  if j=.nil then do
    /* kept in the mode-700 temp dir (no token in it) so the fault can be read; the call may still have taken effect */
    address system 'mv -f' mbQ(outFile) mbQ(tmpDir'/bad-answer-'seq'.json')
    res['error']='unreadable answer, kept in' tmpDir'/bad-answer-'seq'.json:' raw~left(120)
    return res
  end
  address system 'rm -f' mbQ(outFile)
  if j~hasIndex('error') then do
    res['error']='json-rpc error:' j['error']['message']~string
    return res
  end
  /* structuredContent carries the whole answer; content[1].text is a summary the server cuts at 500 characters */
  sc=.nil
  if j['result']~hasIndex('structuredContent') then sc=j['result']['structuredContent']
  text=j['result']['content'][1]['text']~string
  res['text']=text
  if sc<>.nil then do
    res['code']=sc['code']~string
    if sc['ok']\==.json~true then do
      detail=''
      if sc~hasIndex('detail') then if sc['detail']<>.nil then detail=sc['detail']~string
      res['error']='ERROR' res['code']':' detail
      return res
    end
    res['value']=sc['value']
    res['ok']=.true
    return res
  end
  parse var text status code ':' rest
  res['code']=code
  if status<>'OK' then do
    res['error']=text~left(300)
    return res
  end
  /* no structuredContent: the status line decides success; the JSON after it may be cut short */
  rest=rest~strip
  if rest~left(1)=='{' then res['value']=mbParse(rest)
  res['ok']=.true
  return res

/* Requests addressed to this principal that it has not marked read, including ones it has already answered
 * (unreadOnly would hide those, and an answered-but-unread request still needs its mark-read and nudge). */
::method unread
  expose principal
  use strict arg findings
  r=self~call('project.requests.list', .directory~new)
  out=.array~new
  if \r['ok'] then do
    findings~add('STOP', 'mailbox', 'listing failed:' r['error'])
    return out
  end
  if r['value']=.nil then do
    findings~add('STOP', 'mailbox', 'listing unreadable:' r['text']~left(200))
    return out
  end
  do q over r['value']['requests']
    if q['recipientId']~string<>principal then iterate
    if q['senderId']~string==principal then iterate
    if q['readByCaller']~string==1 then iterate
    out~append(q)
  end
  return out

::method reply
  use strict arg requestId, body, subject
  a=.directory~new
  a['requestId']=.JsonString~new(requestId)
  a['body']=.JsonString~new(body)
  a['subject']=.JsonString~new(subject)
  return self~call('project.request.reply', a)

::method markRead
  use strict arg requestId
  a=.directory~new
  a['requestId']=.JsonString~new(requestId)
  return self~call('project.request.mark_read', a)

/* ------------------------------------------------------------------------------------------------------------ */
::routine mbQ public
  use strict arg s
  return "'"s~changeStr("'", "'\''")"'"

/* JSON in, object out, or .nil.  A second try escapes raw control characters inside strings (a tab or CR the
 * sender did not escape), which strict json.cls rightly refuses. */
::routine mbParse public
  use strict arg t
  j=mbParseOnce(t)
  if j<>.nil then return j
  return mbParseOnce(mbJsonClean(t))

::routine mbParseOnce
  use strict arg t
  signal on syntax name bad
  return .json~new~fromJson(t)
bad:
  return .nil

::routine mbJsonClean public
  use strict arg s
  if s~verify(xrange('00'x, '1f'x), 'M')=0 then return s
  out=.mutableBuffer~new
  inStr=.false
  i=1
  n=s~length
  do while i<=n
    c=s~subchar(i)
    if inStr & c=='5c'x then do
      x=out~append(s~substr(i, 2))
      i=i+2
      iterate
    end
    if c=='"' then inStr=\inStr
    if inStr & c<<' ' then x=out~append('5c'x'u00'c~c2x~lower)
    else x=out~append(c)
    i=i+1
  end
  return out~string

::routine mbFile public
  use strict arg f
  if \SysFileExists(f) then return ''
  s=.stream~new(f)
  t=s~charin(1, s~chars)
  s~close
  return t

::routine mbWrite public
  use strict arg f, text
  address system 'umask 077 && : >' mbQ(f)
  s=.stream~new(f)
  s~open('write replace')
  s~charout(text)
  s~close

::requires 'json.cls'
