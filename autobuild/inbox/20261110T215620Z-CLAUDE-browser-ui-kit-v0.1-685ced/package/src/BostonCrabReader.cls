/* BostonCrabReader.cls -- step 1 of the OrderGate for free-text orders: Boston Crab reads the order.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 9 November 2026.
 * Boston Crab (oorexx_slam_bostoncrab v0.21+): its own chat, Claude (Opus 5.5).
 *
 * ALCHEMYFETCH writes a story folder:
 *   # Situation   from its own catalogue (etc/fetch.catalogue: NAME|SITE|URL): "SITE was a website."
 *                 and "The NAME was on SITE."
 *   # Order — Issuer to Alchemyfetch    the message text
 * runs Boston Crab's order_check.rex on it, and reads orders.words:
 *   - fail|...                -> REQUIRES CLARIFICATION (Boston Crab could not check it)
 *   - message|...             -> NOT AN ORDER
 *   - end other than CLEAR    -> REQUIRES CLARIFICATION, with Boston Crab's own words from orders.txt
 *   - parts with how=not      -> prohibitions: noted, never executed
 *   - the fetch parts' target -> a "url ..." ref is fetched as written; a named ref is looked up in the catalogue
 *                                by its exact name (never guessed); a site name is a place, not a target
 *   - exactly one target, else REQUIRES CLARIFICATION (one document per order)
 * An exact structured order ("FETCH URL", "FETCH svn URL") is read by FetchOrderReader without Boston Crab.
 */

::class BostonCrabReader public
::method init
  expose policy issuers crabDir workDir catalogue sites fetchActions plain
  use strict arg policy, issuers, crabDir, workDir, catalogueFile, fetchActions
  plain=.FetchOrderReader~new(policy, issuers)
  catalogue=.directory~new
  sites=.array~new
  if SysFileExists(catalogueFile) then do
    s=.stream~new(catalogueFile)
    s~open('read')
    do while s~lines>0
      l=s~linein~strip
      if l=='' | l~left(1)=='#' then iterate
      parse var l name '|' site '|' url
      catalogue[name~strip~lower]=.array~of(name~strip, site~strip, url~strip)
      if \sites~hasItem(site~strip) then sites~append(site~strip)
    end
    s~close
  end

::method read
  expose policy issuers crabDir workDir catalogue sites fetchActions plain
  use strict arg order
  /* the exact structured form needs no reading */
  first=order~text~strip~word(1)~upper
  if first=='FETCH' & order~text~strip~words<=3 then do
    r=plain~read(order)
    if r['verdict']=='CLEAR' then return r
  end
  out=.directory~new
  out['reasons']=.array~new
  out['facts']=.directory~new
  out['action']=.LegalAction~new('FETCH_URL', 'fetch for' order~issuer)
  if crabDir=='' | \SysFileExists(crabDir'/order_check.rex') then do
    out['verdict']='REQUIRES CLARIFICATION'
    out['reasons']~append('free-text orders need Boston Crab, which is not set up here (BOSTON_CRAB_DIR); write FETCH https://...')
    return out
  end
  /* the story folder */
  dir=workDir'/'order~id~translate('_', '/\:*?"<>| ')
  address system 'rm -rf' gateQ(dir) '&& mkdir -p' gateQ(dir'/out') '&& chmod 700' gateQ(workDir)
  cast=.array~of(order~issuer~lower, 'alchemyfetch')
  do s over sites
    cast~append(s~lower)
  end
  story=.array~of('# Situation')
  do s over sites
    story~append(s 'was a website.')
  end
  do k over catalogue~allIndexes~sort
    e=catalogue[k]
    story~append('The' e[1] 'was on' e[2]'.')
  end
  story~append('# Order — 'order~issuer~lower~left(1)~upper||order~issuer~lower~substr(2)' to Alchemyfetch')
  story~append(order~text~strip)
  call bcWrite dir'/story.txt', story
  call bcWrite dir'/cast.words', cast
  do f over .array~of('concepts.words', 'lexicon.words', 'rules.words')
    if \SysFileExists(crabDir'/'f) then do
      out['verdict']='REQUIRES CLARIFICATION'
      out['reasons']~append('Boston Crab is not compiled ('f' missing): run  cd' crabDir '&& rexx compile.rex .')
      return out
    end
    address system 'cp' gateQ(crabDir'/'f) gateQ(dir'/')
  end
  address system 'cd' gateQ(crabDir) '&& rexx order_check.rex' gateQ(dir) '>' gateQ(dir'/out/check.log') '2>&1'
  words=bcLines(dir'/out/orders.words')
  text=bcLines(dir'/out/orders.txt')
  if words~items=0 then do
    out['verdict']='REQUIRES CLARIFICATION'
    out['reasons']~append('Boston Crab gave no report (see' dir'/out/check.log)')
    return out
  end
  /* read the machine report */
  kind=''
  endVerdict=''
  targets=.array~new
  prohibited=.array~new
  fetchParts=0
  otherParts=.array~new
  partHow=.directory~new
  partAction=.directory~new
  do l over words
    if l~left(2)=='--' then iterate
    parse var l tag '|' n '|' rest
    select
      when tag=='fail' then do
        out['verdict']='REQUIRES CLARIFICATION'
        out['reasons']~append('Boston Crab could not check this order:' rest)
        return out
      end
      when tag=='message' then kind='message'
      when tag=='order' then if kind=='' then kind='order'
      when tag=='part' then do
        parse var rest i '|' verb '|' action '|' how '|' pw
        partHow[i]=how
        partAction[i]=action
        if how=='not' then prohibited~append(pw)
        else if wordpos(action, fetchActions)>0 then fetchParts=fetchParts+1
        else otherParts~append(action':' pw)
      end
      when tag=='ref' then do
        parse var rest i '|' verdict '|' rw '|' writer '|' reader
        if partHow[i]=='not' then iterate
        if wordpos(partAction[i], fetchActions)=0 then iterate
        if writer~left(4)=='url ' then targets~append(writer~substr(5))
        else if catalogue~hasIndex(writer~lower) then targets~append(catalogue[writer~lower][3])
        else if sites~hasItem(writer) then nop
        else targets~append('?'writer)
      end
      when tag=='end' then endVerdict=rest
      otherwise nop
    end
  end
  do l over prohibited
    out['reasons']~append('not to do (noted, never executed):' l)
  end
  if kind=='message' then do
    out['verdict']='NOT AN ORDER'
    out['reasons']~append('Boston Crab reads this as a message, not an order')
    return out
  end
  if endVerdict<>'CLEAR' then do
    out['verdict']='REQUIRES CLARIFICATION'
    do l over text
      if l~strip=='' then iterate
      if l~left(2)=='  ' & l~strip~word(1)<>'CLEAR' then out['reasons']~append('Boston Crab:' l~strip)
    end
    if out['reasons']~items=0 then out['reasons']~append('Boston Crab:' endVerdict)
    return out
  end
  if otherParts~items>0 then do
    out['verdict']='REQUIRES CLARIFICATION'
    out['reasons']~append('ALCHEMYFETCH only fetches; also asked:' otherParts~makeString('L', '; '))
    return out
  end
  if fetchParts=0 & prohibited~items>0 then do
    out['verdict']='NOTED'
    out['reasons']~append('the order only says what not to do')
    return out
  end
  if fetchParts=0 then do
    out['verdict']='REQUIRES CLARIFICATION'
    out['reasons']~append('no fetch to do (Boston Crab found no fetch, get, download or read)')
    return out
  end
  unique=.array~new
  do t over targets
    if \unique~hasItem(t) then unique~append(t)
  end
  if unique~items<>1 then do
    out['verdict']='REQUIRES CLARIFICATION'
    if unique~items=0 then out['reasons']~append('no document named that ALCHEMYFETCH can fetch')
    else out['reasons']~append('one document per order; this names' unique~items':' unique~makeString('L', ', '))
    return out
  end
  url=unique[1]
  if url~left(1)=='?' then do
    out['verdict']='REQUIRES CLARIFICATION'
    out['reasons']~append('ALCHEMYFETCH has no address for "'url~substr(2)'": give the URL, or ask Tom to add it to the catalogue')
    return out
  end
  /* from here on, exactly as the structured reader: the facts for the rules of engagement */
  r=plain~read(.GateOrder~new(order~id, order~issuer, order~recipient, 'FETCH' url))
  reasons=out['reasons']
  reasons~append('Boston Crab: CLEAR; fetch' url)
  r['reasons']=reasons
  return r

::routine bcWrite
  use strict arg file, lines
  s=.stream~new(file)
  s~open('write replace')
  do l over lines
    s~lineout(l)
  end
  s~close

::routine bcLines
  use strict arg file
  out=.array~new
  if \SysFileExists(file) then return out
  s=.stream~new(file)
  s~open('read')
  do while s~lines>0
    out~append(s~linein)
  end
  s~close
  return out

::requires 'FetchOrders.cls'
