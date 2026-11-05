/* SLAM 450 v0.94: Control, the remote commander.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
 * Control has no camera: a map, the squad's own position reports, the
 * targets reported to it, and a radio. It gives orders in plain English;
 * Boston Crab checks each one and SLAM relays it at once whatever the check
 * says (Tom Dyer: "there is not time to have multiple chatter confirm"). The
 * race clock runs while Control thinks and while the check runs.
 * Modes:
 *   SCRIPT:file  lines "tick|Name: order", for tests (no model call);
 *   LIVE         a Claude model through oorexx_ai_provider_anthropic. */
::class Slam450Commander public
::attribute mode get
::attribute log get
::attribute totalCost get
::attribute crafts      /* the call signs this Control commands */
::attribute teamNote    /* its team and rules (v0.95) */
::attribute language    /* '' = CONTROL_LANGUAGE; 'uk' = Ukrainian-speaking (v0.95) */
::attribute mapPng      /* base64 PNG of Control's map (bin/control450_map.rex), or '' */

::method init
  expose mode client model catalog script lastTick log totalCost
  use strict arg spec,messageClient=.nil,modelName='claude-haiku-5-5',rateCatalog=.nil,craftList='Alpha Bravo Charlie Delta Echo',note=''
  self~crafts=craftList;self~teamNote=note;self~language=''
  parse var spec m ':' file
  mode=m~upper;client=messageClient;model=modelName;catalog=rateCatalog
  lastTick=-1;log=.array~new;totalCost=0;self~mapPng=''
  script=.array~new
  if mode=='SCRIPT' then do
    if stream(file,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('order script not found:' file)
    do while lines(file)>0
      ln=linein(file)
      if ln~strip=='' | ln~left(1)=='#' then iterate
      parse var ln t '|' order
      script~append(.array~of(t~strip,order~strip))
    end
    call stream file,'C','CLOSE'
  end
  else if mode\=='LIVE' then raise syntax 88.900 array('order mode SCRIPT:file or LIVE')
  if mode=='LIVE' & client==.nil then raise syntax 88.900 array('LIVE orders need a message client')

::method briefing
  cl=self~crafts;n=words(cl)
  if n>1 then cl=subword(cl,1,n-1)~changeStr(' ',', ') 'and' word(cl,n)
  tn='';if self~teamNote\=='' then tn=self~teamNote||'0a'x
  return 'You are Control, commanding drones over Sydney Harbour from a remote room.'||'0a'x||tn||,
    'You have no camera. You have a map, the positions your drones report, the targets reported to you,'||,
    ' and a radio. Your drones are' cl'; each flies itself and carries the same map.'||'0a'x||,
    'The task: five targets (2 m red markers) are somewhere in the field. A drone claims a target by touching it.'||,
    ' A drone can identify a target reliably within about 500 m if nothing is in the way; beyond that it may miss it.'||'0a'x||,
    'Orders: plain English, one per line, as "Name: order". Example: "Bravo: Search Observatory Hill."'||,
    ' Drones understand go/fly to, search/sweep, hold/wait at, and return to the base, at a place named'||,
    ' on the map, a reported target, or a grid reference "E <east> N <north>" in map metres.'||'0a'x||,
    'Time does not stop. The race clock runs while you think and while the radio carries your words;'||,
    ' an order arrives some seconds after you send it. A drone acts on its own reading of your words at once;'||,
    ' there is no time to confirm. SLAM checks every order on the way and tells you, next time you look,'||,
    ' where a drone could read it differently from you. Give at most five orders a turn; give none to leave a drone on its task.'||'0a'x||,
    'Reply with the order lines only.'||self~languageNote

::method languageNote
  /* CONTROL_LANGUAGE=uk: Control is a Ukrainian speaker and gives its orders
     in Ukrainian; the pilots work in English. Nothing translates: Boston
     Crab reads the Ukrainian against the same concepts. */
  lang=self~language~lower
  if lang=='' then lang=value('CONTROL_LANGUAGE',,'ENVIRONMENT')~lower
  if lang=='uk' then return '0a'x||'You are a Ukrainian-speaking ground controller: give every order in Ukrainian,'||,
    ' as a radio call that starts with the call sign, for example "'word(self~crafts,1)', прямуйте до Observatory Hill."'||,
    ' Use the place names exactly as written on the map. The drones answer in English.'
  return ''

::method turn
  /* returns a directory: ORDERS (array of .array(name,text)), LATENCY_S, STATUS, RAW, COST */
  expose mode client model catalog script lastTick log totalCost
  use strict arg tick,mapText,feedback
  r=.directory~new;r['ORDERS']=.array~new;r['LATENCY_S']=0;r['STATUS']='OK';r['RAW']='';r['COST']=0
  if mode=='SCRIPT' then do
    raw=''
    do s over script
      if s[1]>lastTick & s[1]<=tick then raw=raw||s[2]||'0a'x
    end
    lastTick=tick
  end
  else do
    req=.AnthropicMessageRequest~new(model,self~briefing,.true,400)~thinkingOff
    if self~mapPng\=='' then do
      req~addText('Your map (north up; grid labels are the E/N metres used below):')
      req~addPngBase64(self~mapPng)
    end
    req~addText('Race time' tick 's.'||'0a'x||mapText||'0a'x||feedback)
    t0=time('E')
    res=client~send(req)
    r['LATENCY_S']=time('E')-t0
    if \res~ok then do;r['STATUS']='CALL_FAILED:'res~code;raw='';end
    else do
      raw=res~text
      if catalog\==.nil then do;r['COST']=res~costUsd(catalog);totalCost+=r['COST'];end
    end
  end
  r['RAW']=raw
  do ln over raw~makeArray('0a'x)
    ln=ln~strip~changeStr('0d'x,'')
    /* "Bravo: order" or a radio call "Bravo, order" (the call sign stays in
       the words: Boston Crab reads the addressing itself) */
    ln=ln~strip('L','*')~strip('L','-')~strip
    parse var ln who ':' text
    who=who~strip~strip('B','*')~strip
    mine=self~crafts~lower
    if wordpos(who~lower,mine)=0 then do
      parse var ln who ',' .
      who=who~strip~strip('B','*')~strip
      if wordpos(who~lower,mine)=0 then iterate
      text=ln
    end
    text=text~changeStr('«','')~changeStr('»','')~strip~strip('B','"')~strip
    if text=='' then iterate
    if pos(text~right(1),'.!?')=0 then text=text'.'
    r['ORDERS']~append(.array~of(who~left(1)~upper||who~substr(2)~lower,text))
  end
  log~append(r)
  return r
::requires 'AnthropicMessages.cls'
::requires 'AnthropicProvider.cls'
