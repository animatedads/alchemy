/* SLAM450 v0.89 — an LLM in the pilot's seat.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * The LLM receives exactly what a SLAM pilot receives, nothing more:
 *   - its own onboard 360 x 180 panorama (the indexed raster every pilot
 *     sees), encoded as a PNG by oorexx_compress v0.1-dev3;
 *   - its own battery meter, its own airflow packet (flight level band,
 *     pitot, cup, sail), public target claims, the shared flight-window
 *     hints, and (if it paid for one) a fixed-camera panorama;
 *   - its own short notes from previous ticks (bounded memory, 8 slots);
 *   - for a pilot whose team runs the buddy radio: the team's own radio
 *     traffic summary (assignments, observed rival type).
 * No XYZ, no target coordinates, no wind truth, no referee state.
 *
 * Transport: oorexx_ai_provider_anthropic v0.3 AnthropicMessageClient
 * (Secret Broker credential, mode-600 curl config, cached system prompt).
 * MODE  LIVE    real model calls
 *       STANDIN deterministic image-reading stand-in (no network), used to
 *               qualify the harness without spending credit.
 * EYES  EYES    image + instruments only
 *       ASSIST  also gives the onboard vision routine's target bearings
 */
::requires 'Slam450Flight.cls'
::requires 'Slam450AircraftType.cls'
::requires 'IndexedPngEncoder.cls'
::requires 'Slam450PlanMap.cls'
::requires 'ForeignPngProvider.cls'

::class Slam450LlmPilot public
::attribute id get
::attribute label get
::attribute team get
::attribute calls get
::attribute faults get
::attribute totalIn get
::attribute totalOut get
::attribute totalCacheRead get
::attribute totalCacheWrite get
::attribute totalCost get
::attribute totalLatency get
::attribute log get
::method init
  expose id label team teamNote mode eyes model client catalog encoder notes lastCmd calls faults totalIn totalOut totalCacheRead totalCacheWrite totalCost totalLatency log system think
  use strict arg craftId, pilotLabel, teamName, teamDescription, pilotMode='STANDIN', eyesMode='EYES', modelId='claude-haiku-5-5', messageClient=.nil, rateCatalog=.nil, pngLane='AUTO', thinkMode='OFF'
  id=craftId;label=pilotLabel;team=teamName;teamNote=teamDescription
  mode=pilotMode~upper;eyes=eyesMode~upper;model=modelId;think=thinkMode~upper
  if mode\=='LIVE' & mode\=='STANDIN' then raise syntax 88.900 array('pilot mode LIVE or STANDIN')
  if eyes\=='EYES' & eyes\=='ASSIST' then raise syntax 88.900 array('eyes mode EYES or ASSIST')
  if mode=='LIVE' & messageClient==.nil then raise syntax 88.900 array('LIVE pilot needs a message client')
  client=messageClient;catalog=rateCatalog
  provider=.nil
  if pngLane~upper\=='PURE' then if .ForeignPngProvider~available then provider=.ForeignPngProvider~new
  encoder=.IndexedPngEncoder~new(self~palette,2,provider)
  notes=.array~new;lastCmd=.array~of(0,0,0,0)
  calls=0;faults=0;totalIn=0;totalOut=0;totalCacheRead=0;totalCacheWrite=0;totalCost=0;totalLatency=0
  log=.array~new
  system=self~briefing
::method prepare
  /* Main thread only: encode this tick's images before the parallel
     decide() calls, so the Foreign Runtime bridge is never shared. */
  expose mode encoder pngMain pngFixed
  use strict arg frame,fixedFrame=.nil
  pngMain='';pngFixed=''
  if mode\=='LIVE' then return .true
  pngMain=encoder~encodeBase64(frame['PIXELS'])
  if fixedFrame\==.nil then pngFixed=encoder~encodeBase64(fixedFrame['PIXELS'])
  return .true
::method pngLane
  expose encoder
  return encoder~lane
::method palette
  /* Same colours as the SLAM PPM exporter. */
  p=.directory~new
  p['.']='191 218 238';p['~']='51 126 173';p['x']='101 104 112';p['G']='169 180 143'
  p['V']='70 205 255';p['R']='255 230 0';p['P']='60 225 145'
  p['A']='235 184 26';p['B']='249 219 79';p['C']='251 249 227';p['D']='56 106 198'
  p['1']='70 0 0';p['2']='112 0 0';p['3']='158 0 0';p['4']='208 0 0';p['5']='255 0 0'
  return p
::method briefing
  expose label team teamNote
  hints=.Slam450FlightWindowHints~new~describe
  h='';do line over hints;h=h||line||'0a'x;end
  b='You are' label', an autonomous pilot of team' team 'in SLAM 450, an aircraft race over a synthetic Sydney Harbour.'||'0a'x||,
    'You fly a 450-size QUADCOPTER. One decision per tick; 1 tick = 1 second of flight.'||'0a'x||,
    'TEAM: '||teamNote||'0a'x||'0a'x||,
    'GOAL: your team must claim more of the 5 red targets than the other team. A target is claimed by the first aircraft'||,
    ' that flies within 2.5 m of it; claimed targets vanish from every image.'||'0a'x||'0a'x||,
    'YOUR IMAGE each tick: a 360x180 degree equirectangular panorama from your aircraft, 960x242 pixels.'||'0a'x||,
    '- Column x=480 is straight ahead. Bearing off the nose = (x-480)*0.375 degrees: left of centre = turn left (negative yaw).'||,
    ' The far left and far right edges are directly behind you.'||'0a'x||,
    '- Row y=121 is the horizon. Elevation = (121-y)*0.744 degrees: above the middle row = above you (climb), below = below you.'||'0a'x||,
    '- Colours: light blue = sky, blue = water, grey = buildings/bridge/structures (never fly into grey),'||self~landColourNote||,
    ' small yellow/white/blue squares = fixed landmarks.'||'0a'x||,
    '- RED squares are targets. Their shade gives the number: 1 darkest (70,0,0), 2 (112,0,0), 3 (158,0,0), 4 (208,0,0), 5 brightest (255,0,0).'||'0a'x||,
    '- Other aircraft: YELLOW blobs = rivals, GREEN blobs = teammates. A square blob is a quadcopter, a wide flat blob is a fixed-wing.'||'0a'x||,
    '- Size tells range: a 2 m target spanning k pixels is about 2/tan(k*0.375 deg) metres away (k=3 -> ~100 m, k=10 -> ~30 m, k=40 -> ~8 m).'||'0a'x||,
    '- A target hidden behind grey is not drawn; search by turning and changing height.'||'0a'x||'0a'x||,
    'CONTROLS: reply with ONE JSON object and NOTHING else - no text before or after it. Put your reasoning inside "note".'||'0a'x||,
    '{"target":n,"yaw":deg,"forward":mps,"climb":mps,"side":mps,"lookup":false,"note":"<=100 chars for your next turn"}'||'0a'x||,
    '- yaw: turn this tick, -25..25 degrees (+ = right). forward: -3..7 m/s. climb: -4..4 m/s (+ = up). side: -3..3 m/s (+ = right).'||'0a'x||,
    '- lookup: true buys ONE fixed harbour-camera panorama next tick (costs 3 units). It shows targets from a different place.'||'0a'x||,
    '- note: your only memory between ticks. Write what you are doing and what you saw.'||'0a'x||'0a'x||,
    'ENERGY (900-unit battery; per tick): hover 1.00, 3 m/s 0.96, 5 m/s 0.91, 7 m/s 0.875 (cruising fast is CHEAPER than hovering),'||,
    ' climbing adds about 0.05 per m/s, descending is free. Empty battery = you are out.'||'0a'x||'0a'x||,
    'SAFETY (breaking any rule knocks you OUT of the race permanently):'||'0a'x||,
    '- never touch grey structures; never go near the water (lowest legal height is about 2 m);'||'0a'x||,
    '- never come within 4 m of any other aircraft: a big yellow or green blob near the centre means turn or climb away;'||'0a'x||,
    '- slow down as a target grows large (k>20) so you do not overshoot; small yaw corrections near the target.'||'0a'x||,
    '- many targets sit low, just above the water: if a target is BELOW the horizon (y>121) you must DESCEND (negative climb)'||,
    ' to reach it. Descending is free and safe while you stay above about 5 m.'||'0a'x||'0a'x||,
    'BASIC NORMAL OPERATING PARAMETERS (shared pilot knowledge):'||'0a'x||h||'0a'x||self~mapNote||,
    'You do NOT know your position, the target positions or the wind. Fly by what you see.'
  return b
::method remember private
  expose notes
  use strict arg tick,text
  if notes~items>=8 then do;kept=.array~new;do i=2 to notes~items;kept~append(notes[i]);end;notes=kept;end
  notes~append('t'||tick||': '||text~left(min(100,text~length)))
::method decide
  /* Returns array(command, chosenTarget, lookupWanted). Never raises:
     a failed call or unparseable reply hovers and counts a fault. */
  expose id mode eyes model client catalog encoder notes lastCmd system calls faults totalIn totalOut totalCacheRead totalCacheWrite totalCost totalLatency log pngMain pngFixed think
  use strict arg tick,frame,meter,packet,available,claimsText,teamFeed,fixedFrame=.nil
  calls+=1
  status='OK';text='';lat=0;inT=0;outT=0;cr=0;cw=0;cost=0;stop='end_turn'
  avail='';do t=1 to 5;if available~hasIndex(t) then avail=avail t;end
  state='TICK' tick'. Unclaimed targets:'avail~strip'. Claims so far:' claimsText||'0a'x||,
        'Battery:' format(meter['REMAINING'],,1)'/'format(meter['CAPACITY'],,0) '('format(meter['PERCENT'],,1)'%).'
  if packet\==.nil then state=state' Flight level band:' packet['FLIGHT_LEVEL']'(L1 low, L3 high). Pitot airspeed:' format(packet['PITOT_FORWARD_MPS'],,1) 'm/s.'
  state=state||'0a'x||'Your last command: yaw' lastCmd[1] 'forward' lastCmd[2] 'climb' lastCmd[3] 'side' lastCmd[4]'.'
  if notes~items>0 then do;state=state||'0a'x||'Your notes:';do n over notes;state=state||'0a'x||'  '||n;end;end
  if teamFeed\=='' then state=state||'0a'x||'Team radio: '||teamFeed
  if eyes=='ASSIST' then state=state||'0a'x||self~assistText(frame,available)
  if mode=='STANDIN' then do
    reply=self~standIn(frame,available)
  end
  else do
    if think=='OFF' then req=.AnthropicMessageRequest~new(model,system,.true,600)~thinkingOff
    else req=.AnthropicMessageRequest~new(model,system,.true,3000)~thinkingAdaptive(think)
    if .local['SLAM450.MAP']=='MAP' then do
      req~addText('Map of the race area (static; you are not marked):')
      req~addPngBase64(.local['SLAM450.MAP_PNG'])
    end
    req~addText(state)
    req~addPngBase64(pngMain)
    if pngFixed\=='' then do
      req~addText('Second image: the fixed harbour camera view you bought (same panorama format, seen from that camera).')
      req~addPngBase64(pngFixed)
    end
    r=client~send(req)
    stop=r~stopReason;lat=r~latencyMs;inT=r~inputTokens;outT=r~outputTokens;cr=r~cacheReadTokens;cw=r~cacheWriteTokens
    if catalog\==.nil & r~ok then cost=r~costUsd(catalog)
    if \r~ok then do;status='CALL_FAILED:'r~code;reply=r~message;end
    else reply=r~text
  end
  totalIn+=inT;totalOut+=outT;totalCacheRead+=cr;totalCacheWrite+=cw;totalLatency+=lat
  if cost\=='' then totalCost+=cost
  cmd=.array~of(0,0,0,0);target=0;lookup=.false;note=''
  if status=='OK' then do
    if stop=='max_tokens' & reply~strip=='' then status='NO_TEXT_MAX_TOKENS'
  end
  if status=='OK' then do
    parsed=self~parseReply(reply)
    if parsed==.nil then status='UNPARSEABLE'
    else do
      cmd=.array~of(self~num(parsed,'yaw',-25,25),self~num(parsed,'forward',-3,7),,
                    self~num(parsed,'climb',-4,4),self~num(parsed,'side',-3,3))
      target=self~num(parsed,'target',0,5)~format(,0)
      if parsed~hasIndex('lookup') then lookup=(parsed['lookup']==.true | parsed['lookup']=='true' | parsed['lookup']==1)
      if parsed~hasIndex('note') then note=parsed['note']~string~changestr('0a'x,' ')
    end
  end
  if status\=='OK' then do;faults+=1;cmd=.array~of(0,0,0,0);lookup=.false;end
  if note\=='' then self~remember(tick,note)
  lastCmd=cmd
  e=.directory~new
  e['TICK']=tick;e['STATUS']=status;e['LATENCY_MS']=lat;e['IN']=inT;e['OUT']=outT
  e['CACHE_READ']=cr;e['CACHE_WRITE']=cw;e['COST']=cost;e['TARGET']=target
  e['CMD']=cmd;e['LOOKUP']=lookup;e['NOTE']=note;e['RAW']=reply~left(min(300,reply~length))
  log~append(e)
  return .array~of(cmd,target,lookup)
::method becomeNavigator
  /* v0.90 back-seat role: the LLM advises, SLAM's own pilot flies. */
  expose role system
  role='NAVIGATOR'
  system=self~navigatorBriefing
  return .true
::method role
  expose role
  if var('role') then return role
  return 'PILOT'
::method navigatorBriefing
  expose label team teamNote
  hints=.Slam450FlightWindowHints~new~describe
  h='';do line over hints;h=h||line||'0a'x;end
  b='You are' label', the NAVIGATOR in the back seat of a 450-size quadcopter of team' team 'in SLAM 450,'||,
    ' an aircraft race over a synthetic Sydney Harbour. You do NOT fly. An autonomous pilot (SLAM) flies the aircraft'||,
    ' with its own vision, steering and collision avoidance. You give it strategic guidance every few seconds.'||'0a'x||,
    'TEAM: '||teamNote||'0a'x||'0a'x||,
    'GOAL: your team must claim more of the 5 red targets than the other team. A target is claimed by the first aircraft'||,
    ' that flies within 2.5 m of it; claimed targets vanish.'||'0a'x||'0a'x||,
    'WHAT YOU GET: the same 360x180 panorama the pilot sees (960x242 px; x=480 straight ahead, bearing=(x-480)*0.375 deg;'||,
    ' y=121 horizon, elevation=(121-y)*0.744 deg; red squares = targets, shade 1 darkest .. 5 brightest; yellow = rivals,'||,
    ' green = teammates;'||self~landColourNote||' square blob = quadcopter, wide flat blob = fixed-wing), the pilot''s own vision readout of target'||,
    ' bearings/elevations/sizes, what the pilot is doing now, battery and claims, and your earlier notes.'||'0a'x||'0a'x||,
    'YOUR ADVICE (reply with ONE JSON object and NOTHING else; reasoning goes in "note"):'||'0a'x||,
    '{"target":n,"speed":"NORMAL","lookup":false,"note":"<=100 chars"}'||'0a'x||,
    '- target: which unclaimed target the pilot should go for (0 = let the pilot choose). Prefer targets that are near,'||,
    ' visible, not already being chased by a closer rival, and not the one your teammates are taking.'||'0a'x||,
    '- speed: NORMAL (pilot decides), FAST (allow full 7 m/s while the target is far; 7 m/s is the CHEAPEST cruise),'||,
    ' or HOLD (hover in place; costs 1.0 per second, the most expensive way to wait).'||'0a'x||,
    '- lookup: true buys one fixed harbour-camera panorama (3 units) that you will see next time; useful when targets are hidden.'||'0a'x||'0a'x||,
    'ENERGY per second: hover 1.00, 3 m/s 0.96, 5 m/s 0.91, 7 m/s 0.875; climbing adds about 0.05 per m/s; descending free.'||,
    ' Battery 900. A target you cannot see may be hidden behind grey structures.'||'0a'x||self~targetMotionNote||'0a'x||,
    'BASIC NORMAL OPERATING PARAMETERS (shared pilot knowledge):'||'0a'x||h||'0a'x||self~mapNote||,
    'You do NOT know positions or wind. Advise from what you see and what the pilot reports.'
  return b
::method landColourNote
  /* v0.91: with real ground on, land is drawn as green-grey. */
  if .local['SLAM450.GROUND']\=='GROUND' then return ''
  return ' green-grey = land/terrain (solid ground, never fly into it),'
::method mapNote
  /* v0.90: static plan map (Slam450PlanMap), when the runner enables it. */
  if .local['SLAM450.MAP']\=='MAP' then return ''
  return .Slam450PlanMap~briefingText(.local['SLAM450.MAP_W'],.local['SLAM450.MAP_H'])
::method targetMotionNote
  /* v0.90: tell the navigator, as plain pilot knowledge, how targets move. */
  if .local['SLAM450.TARGETS']\=='MOVING' then return ''
  return 'TARGETS MOVE: each target flies slowly (about' .local['SLAM450.TARGET_SPEED'] 'm/s through the air, drifted by wind)'||,
    ' in straight legs to a point it has chosen, then picks a new heading. It never dodges aircraft. Aim where it is going,'||,
    ' not where it is: a target crossing the panorama is moving that way.'||'0a'x
::method advise
  /* Returns directory TARGET, SPEED, LOOKUP, NOTE, STATUS. Never raises. */
  expose id mode model client catalog encoder notes system calls faults totalIn totalOut totalCacheRead totalCacheWrite totalCost totalLatency log pngMain pngFixed think lastAdvice
  use strict arg tick,frame,meter,available,claimsText,teamFeed,pilotStatus
  calls+=1
  status='OK';reply='';lat=0;inT=0;outT=0;cr=0;cw=0;cost=0;stop='end_turn'
  avail='';do t=1 to 5;if available~hasIndex(t) then avail=avail t;end
  state='TICK' tick'. Unclaimed targets:'avail~strip'. Claims so far:' claimsText||'0a'x||,
        'Battery:' format(meter['REMAINING'],,1)'/'format(meter['CAPACITY'],,0) '('format(meter['PERCENT'],,1)'%).'||'0a'x||,
        'Pilot status: '||pilotStatus||'0a'x||self~assistText(frame,available)
  if notes~items>0 then do;state=state||'0a'x||'Your notes:';do n over notes;state=state||'0a'x||'  '||n;end;end
  if teamFeed\=='' then state=state||'0a'x||'Team radio: '||teamFeed
  if mode=='STANDIN' then reply=self~standInAdvice(frame,available)
  else do
    if think=='OFF' then req=.AnthropicMessageRequest~new(model,system,.true,600)~thinkingOff
    else req=.AnthropicMessageRequest~new(model,system,.true,3000)~thinkingAdaptive(think)
    if .local['SLAM450.MAP']=='MAP' then do
      req~addText('Map of the race area (static; you are not marked):')
      req~addPngBase64(.local['SLAM450.MAP_PNG'])
    end
    req~addText(state)
    req~addPngBase64(pngMain)
    if pngFixed\=='' then do
      req~addText('Second image: the fixed harbour camera view you bought (same panorama format, seen from that camera).')
      req~addPngBase64(pngFixed)
    end
    r=client~send(req)
    stop=r~stopReason;lat=r~latencyMs;inT=r~inputTokens;outT=r~outputTokens;cr=r~cacheReadTokens;cw=r~cacheWriteTokens
    if catalog\==.nil & r~ok then cost=r~costUsd(catalog)
    if \r~ok then do;status='CALL_FAILED:'r~code;reply=r~message;end
    else reply=r~text
  end
  totalIn+=inT;totalOut+=outT;totalCacheRead+=cr;totalCacheWrite+=cw;totalLatency+=lat
  if cost\=='' then totalCost+=cost
  a=.directory~new;a['TARGET']=0;a['SPEED']='NORMAL';a['LOOKUP']=.false;a['NOTE']=''
  if status=='OK' & stop=='max_tokens' & reply~strip=='' then status='NO_TEXT_MAX_TOKENS'
  if status=='OK' then do
    parsed=self~parseReply(reply)
    if parsed==.nil then status='UNPARSEABLE'
    else do
      a['TARGET']=self~num(parsed,'target',0,5)~format(,0)
      if parsed~hasIndex('speed') then do
        sp=parsed['speed']~string~upper
        if sp=='FAST' | sp=='HOLD' | sp=='NORMAL' then a['SPEED']=sp
      end
      if parsed~hasIndex('lookup') then a['LOOKUP']=(parsed['lookup']==.true | parsed['lookup']=='true' | parsed['lookup']==1)
      if parsed~hasIndex('note') then a['NOTE']=parsed['note']~string~changestr('0a'x,' ')
    end
  end
  if status\=='OK' then faults+=1
  a['STATUS']=status
  if a['NOTE']\=='' then self~remember(tick,a['NOTE'])
  e=.directory~new
  e['TICK']=tick;e['STATUS']=status;e['LATENCY_MS']=lat;e['IN']=inT;e['OUT']=outT
  e['CACHE_READ']=cr;e['CACHE_WRITE']=cw;e['COST']=cost;e['TARGET']=a['TARGET']
  e['CMD']=.array~of(a['SPEED'],'','','');e['LOOKUP']=a['LOOKUP'];e['NOTE']=a['NOTE'];e['RAW']=reply~left(min(300,reply~length))
  log~append(e)
  lastAdvice=a
  return a
::method standInAdvice private
  /* Deterministic stand-in navigator: nearest visible target, FAST if small. */
  use strict arg frame,available
  v=.Slam450Vision~new;best=0;bestSize=0
  do t=1 to 5
    if \available~hasIndex(t) then iterate
    o=v~observe(frame,t)
    if o==.nil then iterate
    s=max(o['WIDTH'],o['HEIGHT'])
    if s>bestSize then do;best=t;bestSize=s;end
  end
  sp='NORMAL';if best>0 & bestSize<6 then sp='FAST'
  look='false';if best==0 then look='true'
  return '{"target":'best',"speed":"'sp'","lookup":'look',"note":"advise target' best '"}'
::method num private
  use strict arg d,key,lo,hi
  if \d~hasIndex(key) then return 0
  v=d[key]
  if \datatype(v,'N') then return 0
  return max(lo,min(hi,v))
::method parseReply private
  use strict arg text
  a=text~pos('{');b=text~lastPos('}')
  if a=0 | b<=a then return .nil
  signal on syntax name bad
  d=.JSON~fromJSON(text~substr(a,b-a+1))
  signal off syntax
  if \d~isA(.directory) then return .nil
  return d
bad:
  signal off syntax
  return .nil
::method assistText private
  use strict arg frame,available
  v=.Slam450Vision~new;out='Onboard vision readout:'
  do t=1 to 5
    if \available~hasIndex(t) then iterate
    o=v~observe(frame,t)
    if o==.nil then out=out 'target' t 'not visible;'
    else out=out 'target' t 'bearing' format(o['AZ'],,1)'deg elevation' format(o['EL'],,1)'deg size' max(o['WIDTH'],o['HEIGHT'])'px;'
  end
  return out
::method standIn private
  /* Deterministic stand-in: same inputs, simple image rules, JSON reply. */
  use strict arg frame,available
  v=.Slam450Vision~new;best=0;bestObs=.nil
  do t=1 to 5
    if \available~hasIndex(t) then iterate
    o=v~observe(frame,t)
    if o==.nil then iterate
    take=(bestObs==.nil)
    if \take then take=(max(o['WIDTH'],o['HEIGHT'])>max(bestObs['WIDTH'],bestObs['HEIGHT']))
    if take then do;best=t;bestObs=o;end
  end
  if bestObs==.nil then return '{"target":0,"yaw":15,"forward":1,"climb":0,"side":0,"lookup":false,"note":"scanning"}'
  az=bestObs['AZ'];el=bestObs['EL'];size=max(bestObs['WIDTH'],bestObs['HEIGHT'])
  yaw=max(-25,min(25,az*0.7));climb=max(-3,min(3,el*0.15))
  fwd=5;if size>=20 then fwd=1.5;if abs(az)>30 then fwd=1
  return '{"target":'best',"yaw":'format(yaw,,2)',"forward":'fwd',"climb":'format(climb,,2)',"side":0,"lookup":false,"note":"chasing' best '"}'
::method saveLog
  expose log label
  use strict arg file
  call lineout file,'tick,pilot,status,latency_ms,input_tokens,cache_write,cache_read,output_tokens,cost_usd,target,yaw,forward,climb,side,lookup,note,raw_reply'
  do e over log
    c=e['CMD']
    call lineout file,e['TICK']','label','e['STATUS']','e['LATENCY_MS']','e['IN']','e['CACHE_WRITE']','e['CACHE_READ']','e['OUT']','e['COST']','e['TARGET']','c[1]','c[2]','c[3]','c[4]','e['LOOKUP']','csv(e['NOTE'])','csv(e['RAW'])
  end
  call stream file,'C','CLOSE'
  return log~items
::routine csv
  use strict arg s
  return '"'||s~changestr('"','""')~changestr('0a'x,' ')~changestr('0d'x,' ')||'"'
::requires 'AnthropicMessages.cls'
::requires 'AnthropicProvider.cls'
