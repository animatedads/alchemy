/* FetchOrders.cls -- ALCHEMYFETCH's plug-ins for the OrderGate: its reader, its rules of engagement, its executor.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 9 November 2026.  Legal Effect v0.14: ChatGPT.
 *
 *   FetchOrderReader  step 1: "FETCH URL" or "FETCH svn URL" is an order; anything else is not (yet).  Free
 *                     text ("fetch the ooRexx README") is for Boston Crab once it reads fetch orders: until
 *                     then it is REQUIRES CLARIFICATION, never a guess.
 *   FetchRules        step 2: the rules of engagement as a sealed Legal Effect rule generation, written from
 *                     etc/fetch.conf (Tom's policy): who may order, HTTPS only, allowlisted hosts only, allowed
 *                     kinds only, no shell metacharacters.  Every rule is a PROHIBITION with a condition, so a
 *                     fact the reader could not establish leaves the rule unresolved -> REVIEW_REQUIRED.
 *   FetchExecutor     step 3: FetchRun, with every redirect re-assessed by the gate before it is followed.
 */

::class FetchOrderReader public
::method init
  expose policy issuers
  use strict arg policy, issuers
::method read
  expose policy issuers
  use strict arg order
  out=.directory~new
  out['reasons']=.array~new
  out['facts']=.directory~new
  out['action']=.LegalAction~new('FETCH_URL', 'fetch for' order~issuer)
  line=''
  do l over order~text~makeArray('0a'x)
    l=l~strip('B', '0d'x)~strip
    if l<>'' then do
      line=l
      leave
    end
  end
  parse var line verb rest
  if verb~upper<>'FETCH' then do
    out['verdict']='NOT AN ORDER'
    out['reasons']~append('ALCHEMYFETCH takes fetch orders only, written: FETCH https://... or FETCH svn https://...')
    return out
  end
  kind='http'
  if rest~word(1)~lower=='svn' then do
    kind='svn'
    rest=rest~subword(2)
  end
  if rest~words<>1 then do
    out['verdict']='REQUIRES CLARIFICATION'
    if rest~words=0 then out['reasons']~append('no address: say which URL to fetch')
    else out['reasons']~append('expected one URL after FETCH; free-text orders are not read yet (Boston Crab will read them)')
    return out
  end
  url=rest
  facts=out['facts']
  facts['ISSUER_AUTHORISED']=(issuers~hasItem(order~issuer~upper))
  parse var url scheme '://' hostpart
  if hostpart<>'' then do
    facts['SCHEME_HTTPS']=(scheme~lower=='https')
    facts['HOST_ALLOWLISTED']=policy~hostAllowed(fxHost(url))
  end
  /* no "scheme://": the host and scheme facts stay unknown, so their rules are unresolved -> review */
  facts['KIND_ALLOWED']=policy~kinds~hasItem(kind)
  facts['URL_SAFE']=(url~verify(' "''`$\;|&<>'||'0a0d09'x, 'M')=0)
  out['verdict']='CLEAR'
  out['reasons']~append('fetch' kind url)
  out['kind']=kind
  out['url']=url
  return out

/* ------------------------------------------------------------------------------------------------------------ */
::class FetchRules public
::attribute generation get
::method init
  expose generation
  use strict arg policy, issuers
  generation=.LegalRuleGeneration~new('ALCHEMYFETCH-ROE', '1')
  src=.NormativeSource~new('TOM-FETCH-ROE', 'POLICY', 'ALCHEMYFETCH rules of engagement (etc/fetch.conf)', 'Tom Dyer')
  x=generation~addSource(src)
  call fetchRule generation, 'ROE-ISSUER', 'ISSUER_AUTHORISED', 'only' issuers~makeString('L', ', ') 'may order a fetch'
  call fetchRule generation, 'ROE-HTTPS', 'SCHEME_HTTPS', 'https only'
  call fetchRule generation, 'ROE-HOST', 'HOST_ALLOWLISTED', 'allowlisted hosts only:' policy~hosts~makeString('L', ' ')
  call fetchRule generation, 'ROE-KIND', 'KIND_ALLOWED', 'allowed kinds only:' policy~kinds~makeString('L', ' ')
  call fetchRule generation, 'ROE-URL', 'URL_SAFE', 'no spaces, quotes or shell metacharacters in the address'
  x=generation~seal

::routine fetchRule
  use strict arg gen, id, fact, why
  n=.LegalNorm~new(id, 'TOM-FETCH-ROE', id, 'PROHIBITION', 'FETCH_URL', 'PROHIBITED', 'FETCH', why)
  x=n~addCondition(.LegalPredicate~new(fact, 'KNOWN_FALSE'))
  x=gen~addNorm(n)

/* ------------------------------------------------------------------------------------------------------------ */
::class FetchExecutor public
::method init
  expose policy tools
  use strict arg policy, tools
::method execute
  expose policy tools
  use strict arg order, reading, gate
  res=.directory~new
  res['lines']=.array~new
  run=.FetchRun~new(policy, .FetchRequest~new(order~id, reading['kind'], reading['url'], order~issuer), tools)
  run~hopGate=.FetchHopGate~new(gate, policy, reading['facts'], order~id)
  res['ok']=run~fetch
  if res['ok'] then do
    s=.stream~new(policy~storeDir'/'order~id'/reply.md')
    s~open('read')
    do while s~lines>0
      res['lines']~append(s~linein)
    end
    s~close
  end
  else do l over run~findings~lines
    res['lines']~append(l)
  end
  return res

/* A redirect is a new target: re-assessed against the same rules before it is followed. */
::class FetchHopGate public
::method init
  expose gate policy facts id hops
  use strict arg gate, policy, facts, id
  hops=0
::method allowHop
  expose gate policy facts id hops
  use strict arg url
  hops=hops+1
  f=facts~copy
  parse var url scheme '://' .
  f['SCHEME_HTTPS']=(scheme~lower=='https')
  f['HOST_ALLOWLISTED']=policy~hostAllowed(fxHost(url))
  f['URL_SAFE']=(url~verify(' "''`$\;|&<>'||'0a0d09'x, 'M')=0)
  g=gate~assess('FETCH_URL', f, id'-hop'hops)
  if g~status=='ADMISSIBLE' then return ''
  return g~status 'by' g~deciding~makeString('L', '; ') '(trace' g~traceId')'

::requires 'OrderGate.cls'
::requires 'FetchForMe.cls'
