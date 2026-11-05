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
::attribute airframe get
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
  self~setAirframe('QUAD')
  system=self~briefing
::method setAirframe private
  expose airframe
  use strict arg kind
  airframe=kind~upper
  return .true
::method useAirframe
  /* v0.92: QUAD (default) or FIXED_WING. Call before becomeNavigator.
     Rebuilds the briefing so the model is told what it actually flies. */
  expose airframe system role
  use strict arg kind
  airframe=kind~upper
  if airframe\=='QUAD' & airframe\=='FIXED_WING' then raise syntax 88.900 array('airframe QUAD or FIXED_WING')
  if var('role') then if role=='NAVIGATOR' then do;system=self~navigatorBriefing;return .true;end
  system=self~briefing
  return .true
::method isWing private
  expose airframe
  return var('airframe') & airframe=='FIXED_WING'
::method craftLine private
  if self~isWing then return 'You fly a 450-size FIXED-WING aircraft (a small powered glider). One decision per tick; 1 tick = 1 second of flight.'
  return 'You fly a 450-size QUADCOPTER. One decision per tick; 1 tick = 1 second of flight.'
::method controlsLine private
  if self~isWing then return '- yaw: turn this tick, -30..30 degrees (+ = right; done by banking). forward: AIRSPEED 7.4..11 m/s.'||,
    ' climb: -3..2 m/s (+ = up; a wing climbs at most 2 m/s). side: always 0 (a wing cannot slide sideways).'||'0a'x||,
    '- A WING CANNOT HOVER, STOP OR REVERSE. It stalls below 6.6 m/s; the flight computer will not let you go below 7.4 m/s'||,
    ' and will tell you when it overrode you. To wait or search, fly a circle (yaw 25-30 each tick).'||'0a'x||,
    '- Turning circle: at 8 m/s and 30 deg per tick a full circle takes 12 s and is about 30 m across (tightest turn radius ~11 m). A target that is close'||,
    ' and more than 70 deg off the nose is INSIDE your turn: fly straight away for 3-4 s, then turn back to it.'
  return '- yaw: turn this tick, -25..25 degrees (+ = right). forward: -3..7 m/s. climb: -4..4 m/s (+ = up). side: -3..3 m/s (+ = right).'
::method energyLine private
  /* Costs are in the COSTS table (costsLine); this states the battery only. */
  if self~isWing then return 'BATTERY: 613 units (prices in COSTS above). Empty battery = you are out.'
  return 'BATTERY: 900 units (prices in COSTS above). Empty battery = you are out.'
::method approachLine private
  if self~isWing then return '- you pass a target at 7.4 m/s or more: line it up early (centre it, small yaw), and match its height before you arrive;'||,
    ' if you miss, extend straight 3-4 s and come round again.'
  return '- slow down as a target grows large (k>20) so you do not overshoot; small yaw corrections near the target.'
::method cameraName private
  /* v0.92 (Tom Dyer: make the check feed useful): "lookup" may name one of
     the five fixed harbour cameras instead of true. Returns '' otherwise. */
  use strict arg v
  if \v~isA(.String) then return ''
  u=v~strip~upper
  if wordpos(u,'CAFE_SYDNEY OPERA_WEST_WALK KIRRIBILLI NORTH_PTZ BLUES_PT')>0 then return u
  return ''
::method chooseView private
  expose wantedView
  use strict arg nm
  wantedView=nm
  return .true
::method noteView
  expose lastView
  use strict arg nm
  lastView=nm
  return .true
::method lastViewName private
  expose lastView
  if var('lastView') then return lastView
  return 'fixed camera'
::method takeView
  /* Runner: the camera this pilot named for its lookup ('' = rotation). */
  expose wantedView
  if \var('wantedView') then return ''
  v=wantedView;wantedView=''
  return v
::method lookupLogValue private
  expose wantedView
  use strict arg on
  if \on then return 0
  if var('wantedView') then if wantedView\=='' then return wantedView
  return 1
::method cameraList private
  return '  Cameras (360 deg panoramas from fixed places; positions as on the map): CAFE_SYDNEY = Customs House rooftop, south'||,
    ' edge of Circular Quay; OPERA_WEST_WALK = Opera House western forecourt, east of Circular Quay; KIRRIBILLI = Kirribilli'||,
    ' shore, east of the bridge''s north end; NORTH_PTZ = north-shore rooftop just east of the bridge''s north end;'||,
    ' BLUES_PT = Blues Point rooftop, far north-west. A camera near a target shows it large; far away it may be a dot or hidden.'
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
::method lastClimb
  expose lastCmd
  if var('lastCmd') then return lastCmd[3]
  return 0
::method setSensor private
  expose sensorScan sensorAlt sensorGps
  use strict arg which,value
  on=jsonTrue(value)
  select
    when which=='SCAN' then sensorScan=on
    when which=='GPS' then sensorGps=on
    otherwise sensorAlt=on
  end
::method lastForward
  expose lastCmd
  if var('lastCmd') then return lastCmd[2]
  return 0
::method scannerWanted
  /* v0.92: the pilot's own sensor switches (default off). */
  expose sensorScan
  if var('sensorScan') then return sensorScan
  return .false
::method gpsWanted
  expose sensorGps
  if var('sensorGps') then return sensorGps
  return .false
::method altimeterWanted
  expose sensorAlt
  if var('sensorAlt') then return sensorAlt
  return .false
::method pngLane
  expose encoder
  return encoder~lane
::method palette
  /* Same colours as the SLAM PPM exporter. */
  p=.directory~new
  p['.']='191 218 238';p['~']='51 126 173';p['x']='101 104 112';p['G']='169 180 143'
  sp=.Slam450Camera~palette;do k over sp~allIndexes;p[k]=sp[k];end
  p['V']='70 205 255';p['R']='255 230 0';p['P']='60 225 145'
  p['S']='255 252 225';p['M']='214 214 206'
  p['A']='235 184 26';p['B']='249 219 79';p['C']='251 249 227';p['D']='56 106 198'
  p['1']='70 0 0';p['2']='112 0 0';p['3']='158 0 0';p['4']='208 0 0';p['5']='255 0 0'
  return p
::method briefing
  expose label team teamNote
  hints=.Slam450FlightWindowHints~new~describe
  h='';do line over hints;h=h||line||'0a'x;end
  b='You are' label', an autonomous pilot of team' team 'in SLAM 450, an aircraft race over a synthetic Sydney Harbour.'||'0a'x||,
    self~craftLine||'0a'x||,
    'TEAM: '||teamNote||'0a'x||'0a'x||,
    'GOAL: your team must claim more of the 5 red targets than the other team. A target is claimed by the first aircraft'||,
    ' that flies within 2.5 m of it; claimed targets vanish from every image.'||'0a'x||'0a'x||,
    'YOUR IMAGE each tick: a 360x180 degree equirectangular panorama from your aircraft, 960x242 pixels.'||'0a'x||,
    '- Column x=480 is straight ahead. Bearing off the nose = (x-480)*0.375 degrees: left of centre = turn left (negative yaw).'||,
    ' The far left and far right edges are directly behind you.'||'0a'x||,
    '- Row y=121 is the horizon. Elevation = (121-y)*0.744 degrees: above the middle row = above you (climb), below = below you.'||'0a'x||,
    '- Colours: light blue = sky, blue = water,'||self~landColourNote||' structures are solid (never fly into them) and coloured by kind:'||self~structureLegend||,
    ' small yellow/white/blue squares = fixed landmarks.'||'0a'x||,
    '- RED squares are targets. Their shade gives the number: 1 darkest (70,0,0), 2 (112,0,0), 3 (158,0,0), 4 (208,0,0), 5 brightest (255,0,0).'||'0a'x||,
    '- Other aircraft: YELLOW blobs = rivals, GREEN blobs = teammates. A square blob is a quadcopter, a wide flat blob is a fixed-wing.'||'0a'x||,
    '- Size tells range: a 2 m target spanning k pixels is about 2/tan(k*0.375 deg) metres away (k=3 -> ~100 m, k=10 -> ~30 m, k=40 -> ~8 m).'||'0a'x||,
    '- A target hidden behind grey is not drawn; search by turning and changing height.'||'0a'x||self~skyLine||'0a'x||,
    'CONTROLS: reply with ONE JSON object and NOTHING else - no text before or after it. Put your reasoning inside "note".'||'0a'x||,
    self~controlTemplate||'0a'x||,
    self~controlsLine||'0a'x||,
    '- lookup: false, true (next camera in rotation) or a camera NAME, e.g. "BLUES_PT"; it buys ONE fixed harbour-camera'||,
    ' panorama shown to you next tick (costs 3 units). It shows targets from a different place.'||'0a'x||self~cameraList||'0a'x||,
    '- note: your only memory between ticks. Write what you are doing and what you saw.'||'0a'x||self~sensorKeys||'0a'x||,
    self~energyLine||'0a'x||'0a'x||,
    'SAFETY (breaking any rule knocks you OUT of the race permanently):'||'0a'x||,
    '- never touch grey structures; never go near the water (lowest legal height is about 2 m);'||'0a'x||,
    '- never come within 4 m of any other aircraft: a big yellow or green blob near the centre means turn or climb away;'||'0a'x||,
    self~approachLine||'0a'x||,
    '- many targets sit low, just above the water: if a target is BELOW the horizon (y>121) you must DESCEND (negative climb)'||,
    ' to reach it. Descending is free and safe while you stay above about 5 m.'||'0a'x||'0a'x||,
    'BASIC NORMAL OPERATING PARAMETERS (shared pilot knowledge):'||'0a'x||h||'0a'x||self~mapNote||self~bookBriefing||self~gpwsNote||,
    'You do NOT know your true position, the target positions or the wind. Fly by what you see and by your flight book.'
  return b
::method remember private
  expose notes
  use strict arg tick,text
  if notes~items>=8 then do;kept=.array~new;do i=2 to notes~items;kept~append(notes[i]);end;notes=kept;end
  notes~append('t'||tick||': '||text~left(min(100,text~length)))
::method decide
  /* Returns array(command, chosenTarget, lookupWanted). Never raises:
     a failed call or unparseable reply hovers and counts a fault. */
  expose id mode eyes model client catalog encoder notes lastCmd system calls faults totalIn totalOut totalCacheRead totalCacheWrite totalCost totalLatency log pngMain pngFixed think book
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
  if meter~hasIndex('GPWS') then state=state||'0a'x||meter['GPWS']
  if meter~hasIndex('GPS') then state=state||'0a'x||meter['GPS']
  if meter~hasIndex('ENVELOPE') then state=state||'0a'x||meter['ENVELOPE']
  if meter~hasIndex('UTC') then state=state||'0a'x||'Time: '||meter['UTC']||' UTC.'
  if self~hasBook then state=state||'0a'x||book~bookText
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
      req~addText('Second image: the fixed harbour camera view you bought ('||self~lastViewName||'; same panorama format, seen from that camera).')
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
      if self~isWing then cmd=.array~of(self~num(parsed,'yaw',-30,30),self~num(parsed,'forward',-3,11),,
                    self~num(parsed,'climb',-3,3),self~num(parsed,'side',-3,3))
      else cmd=.array~of(self~num(parsed,'yaw',-25,25),self~num(parsed,'forward',-3,7),,
                    self~num(parsed,'climb',-4,4),self~num(parsed,'side',-3,3))
      target=self~num(parsed,'target',0,5)~format(,0)
      if parsed~hasIndex('lookup') then do
        lookup=jsonTrue(parsed['lookup'])
        nm=self~cameraName(parsed['lookup'])
        if nm\=='' then do;lookup=.true;self~chooseView(nm);end
      end
      if parsed~hasIndex('scanner') then self~setSensor('SCAN',parsed['scanner'])
      if parsed~hasIndex('altimeter') then self~setSensor('ALT',parsed['altimeter'])
      if parsed~hasIndex('gps') then self~setSensor('GPS',parsed['gps'])
      if parsed~hasIndex('note') then note=parsed['note']~string~changestr('0a'x,' ')
      if self~hasBook then ignored=self~writeBook(tick,parsed,'PILOT')
    end
  end
  if status\=='OK' then do;faults+=1;cmd=.array~of(0,0,0,0);lookup=.false;end
  if note\=='' then self~remember(tick,note)
  lastCmd=cmd
  e=.directory~new
  e['TICK']=tick;e['STATUS']=status;e['LATENCY_MS']=lat;e['IN']=inT;e['OUT']=outT
  e['CACHE_READ']=cr;e['CACHE_WRITE']=cw;e['COST']=cost;e['TARGET']=target
  e['CMD']=cmd;e['LOOKUP']=self~lookupLogValue(lookup);e['NOTE']=note;e['RAW']=reply~left(min(300,reply~length))
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
::method navigatorTemplate private
  if .local['SLAM450.AVOID']\=='ON' then return '{"target":n,"speed":"NORMAL","lookup":false,'||self~bookTemplate||'"note":"<=100 chars"}'
  return '{"target":n,"speed":"NORMAL","gps":false,"lookup":false,'||self~bookTemplate||'"note":"<=100 chars"}'
::method navigatorSpeedLine private
  if self~isWing then return '- speed: NORMAL (pilot decides), FAST (up to 10 m/s while the target is far),'||,
    ' or HOLD (a wing cannot hover: it circles about 30 m across until you release it). A close target well off the nose'||,
    ' costs the wing a loop; prefer targets roughly ahead.'
  return '- speed: NORMAL (pilot decides), FAST (allow full 7 m/s while the target is far; 7 m/s is the CHEAPEST cruise),'||,
    ' or HOLD (hover in place; costs 1.0 per second, the most expensive way to wait).'
::method navigatorEnergyLine private
  if self~isWing then return 'ENERGY per second: cruise 8 m/s about 0.14; climbing about 0.2 per metre gained; descending glides free. Battery 613.'
  return 'ENERGY per second: hover 1.00, 3 m/s 0.96, 5 m/s 0.91, 7 m/s 0.875; climbing adds about 0.05 per m/s; descending free. Battery 900.'
::method navigatorBriefing
  expose label team teamNote
  hints=.Slam450FlightWindowHints~new~describe
  h='';do line over hints;h=h||line||'0a'x;end
  craft='quadcopter';if self~isWing then craft='fixed-wing aircraft (cannot hover; cruises 8 m/s, loiters in circles)'
  b='You are' label', the NAVIGATOR in the back seat of a 450-size' craft 'of team' team 'in SLAM 450,'||,
    ' an aircraft race over a synthetic Sydney Harbour. You do NOT fly. An autonomous pilot (SLAM) flies the aircraft'||,
    ' with its own vision, steering and collision avoidance. You give it strategic guidance every few seconds.'||'0a'x||,
    'TEAM: '||teamNote||'0a'x||'0a'x||,
    'GOAL: your team must claim more of the 5 red targets than the other team. A target is claimed by the first aircraft'||,
    ' that flies within 2.5 m of it; claimed targets vanish.'||'0a'x||'0a'x||,
    'WHAT YOU GET: the same 360x180 panorama the pilot sees (960x242 px; x=480 straight ahead, bearing=(x-480)*0.375 deg;'||,
    ' y=121 horizon, elevation=(121-y)*0.744 deg; red squares = targets, shade 1 darkest .. 5 brightest; yellow = rivals,'||,
    ' green = teammates;'||self~landColourNote||' structures by kind:'||self~structureLegend||' square blob = quadcopter, wide flat blob = fixed-wing), the pilot''s own vision readout of target'||,
    ' bearings/elevations/sizes, what the pilot is doing now, battery and claims, and your earlier notes.'||'0a'x||'0a'x||,
    'YOUR ADVICE (reply with ONE JSON object and NOTHING else; reasoning goes in "note"):'||'0a'x||,
    self~navigatorTemplate||'0a'x||,
    '- target: which unclaimed target the pilot should go for (0 = let the pilot choose). Prefer targets that are near,'||,
    ' visible, not already being chased by a closer rival, and not the one your teammates are taking.'||'0a'x||,
    self~navigatorSpeedLine||'0a'x||,
    '- lookup: false, true (next camera in rotation) or a camera NAME such as "CAFE_SYDNEY"; buys one fixed harbour-camera'||,
    ' panorama (3 units) that you will see next time; useful when targets are hidden or far.'||'0a'x||self~cameraList||'0a'x||self~navigatorGpsKey||'0a'x||,
    self~navigatorEnergyLine||' A target you cannot see may be hidden behind grey structures.'||'0a'x||self~targetMotionNote||'0a'x||,
    'BASIC NORMAL OPERATING PARAMETERS (shared pilot knowledge):'||'0a'x||h||'0a'x||self~mapNote||self~bookBriefing||self~gpwsNote||,
    'You do NOT know true positions or wind. Advise from what you see, what the pilot reports and the flight book'||,
    ' (the aircraft''s book: the pilot dead-reckons it; your "where" corrects it, your "seen" adds targets).'
  return b
::method structureLegend
  /* v0.92 structure classes (Slam450Camera~palette). */
  return ' sandstone cream = Opera House, tan = bridge pylons/abutments, dark slate = bridge deck, teal = Salesforce tower,'||,
    ' periwinkle = Blues Point tower, grey-lavender = wharves, burnt clay = Cahill expressway/station/berm,'||,
    ' steel = bridge arch and its hangers (the road passage under the arch is open), grey = other;'
::method landColourNote
  /* v0.91: with real ground on, land is drawn as green-grey. */
  if .local['SLAM450.GROUND']\=='GROUND' then return ''
  return ' green-grey = land/terrain (solid ground, never fly into it),'
::method gpwsLine
  use strict arg meter
  out=''
  if meter~hasIndex('GPWS') then out=out||meter['GPWS']||'0a'x
  if meter~hasIndex('GPS') then out=out||meter['GPS']||'0a'x
  if self~hasBook then out=out||self~bookTextNow||'0a'x
  return out
::method navigatorGpsKey
  if .local['SLAM450.AVOID']\=='ON' then return ''
  return '- gps: an AIRCRAFT SYSTEM and a control like any other. Nobody switches it on for you: set it true if you want the'||,
    ' pilot''s GPS running (0.9 per tick from its battery; ~30 s to first fix), and you then see its map position. It stays'||,
    ' as you last set it; false switches it off. It starts OFF. All actions have costs: lookup 3 units, gps 0.9 per tick.'||'0a'x
::method skyLine private
  /* v0.93: race clock on -> the Sun and Moon are drawn and the time is given. */
  if .local['SLAM450.SKYON']\=='ON' then return ''
  return '- A small white dot in the sky is the Sun; a small pale grey dot is the Moon. With the UTC time given each tick'||,
    ' and the map north-up, they work as a compass (Sydney: the Sun is in the north at midday).'||'0a'x
::method bookTemplate private
  if \self~hasBook then return ''
  return '"where":[x,y],"sure":0.5,"seen":[[n,x,y]],'
::method hasBook private
  expose book
  return var('book') & .local['SLAM450.MAP']=='MAP'
::method attachBook
  /* v0.92 flight book (Slam450Belief): the runner owns it, the pilot writes. */
  expose book system role
  use strict arg aBook
  book=aBook
  if var('role') then if role=='NAVIGATOR' then do;system=self~navigatorBriefing;return .true;end
  system=self~briefing
  return .true
::method bookTextNow private
  expose book
  return book~bookText
::method writeBook private
  /* Parse "where"/"sure"/"seen" into the flight book. Never raises. */
  expose book lastView
  use strict arg tick,parsed,who
  signal on syntax name badBook
  if parsed~hasIndex('where') then do
    w=parsed['where']
    if w~isA(.array) then if w~items>=2 then do
      sure=.nil;if parsed~hasIndex('sure') then sure=parsed['sure']
      ignored=book~report(tick,w[1],w[2],sure)
    end
  end
  if parsed~hasIndex('seen') then do
    via='OWN_VIEW';if var('lastView') then if lastView\=='' then via='VIEW_OR_CAMERA'
    do e over parsed['seen']
      if e~isA(.array) then if e~items>=3 then ignored=book~sightPixel(tick,e[1],e[2],e[3],via)
    end
  end
  return .true
badBook:
  return .false
::method bookBriefing private
  /* v0.92 (Tom Dyer): flight book, identification range, cost calculation. */
  if \self~hasBook then return ''
  t='FLIGHT BOOK: keep a written record of where you believe you are and what you have found; it is shown back to you'||,
    ' every tick together with the map sectors you have searched (from your own reports).'||'0a'x||,
    '- where: your best estimate of your OWN position as a pixel [x,y] on the map image (x right, y down).'||,
    ' sure: 0..1, how confident you honestly are. Reports are scored after the race against your true position:'||,
    ' a correct report scores best, an honest low "sure" beats a confident wrong one. Omit "where" to keep the last estimate.'||'0a'x||,
    '- seen: targets you can place on the map, as [[target,x,y],...] map pixels (from your view or a camera view). Omit if none.'||'0a'x||,
    '- Between reports the book dead-reckons from your own commands (it does not know the wind, so it drifts).'||'0a'x||'0a'x||,
    'VISIBILITY (normal briefing): from any position you can reliably identify a target or aircraft within about 500 m.'||,
    ' Beyond 500 m a small object shows at most as a single pixel, and beyond about 800 m not at all. Out-of-range'||,
    ' targets may be visible on a fixed camera nearer to them, or found by search and sweep: fly so that every part of'||,
    ' the area passes within 500 m of you. The flight book''s sector table shows what you have already covered.'||'0a'x||'0a'x||,
    'COST CALCULATION - camera or search? Work it out each time, do not guess:'||'0a'x
  if self~isWing then t=t||'- a camera lookup costs 3 units and one tick, and shows the area round that camera (500 m).'||'0a'x||,
    '- sweeping 500 m of new ground costs you about 9 units (62 s at 8 m/s), and searches everything you pass.'||'0a'x||,
    '- so a lookup is worth about 170 m of flying: buy one when a camera covers ground you could not reach soon;'||,
    ' sweep when the unsearched ground is on your way. Time matters too: a rival may claim first.'||'0a'x
  else t=t||'- a camera lookup costs 3 units and one tick, and shows the area round that camera (500 m).'||'0a'x||,
    '- sweeping 500 m of new ground costs you about 62 units (71 s at 7 m/s), and searches everything you pass.'||'0a'x||,
    '- so one lookup costs about what 24 m of flying costs: for a quad a camera is the cheap first look at far ground;'||,
    ' sweep when the camera views have not found it or the ground is near. Time matters too: a rival may claim first.'||'0a'x
  return t||'0a'x
::method controlTemplate private
  /* v0.92 (Tom Dyer): aircraft systems are controls like any control surface. */
  if .local['SLAM450.AVOID']\=='ON' then return '{"target":n,"yaw":deg,"forward":mps,"climb":mps,"side":mps,"lookup":false,'||self~bookTemplate||'"note":"<=100 chars for your next turn"}'
  return '{"target":n,"yaw":deg,"forward":mps,"climb":mps,"side":mps,"scanner":false,"altimeter":false,"gps":false,"lookup":false,'||self~bookTemplate||'"note":"<=100 chars for your next turn"}'
::method sensorKeys
  if .local['SLAM450.AVOID']\=='ON' then return self~costsLine
  return '- scanner, altimeter, gps: AIRCRAFT SYSTEMS. They are controls, exactly like yaw, forward and climb. Nothing and nobody'||,
    ' switches them on for you: if you want a system working, YOU must set it true. It stays as you last set it until you set it'||,
    ' false. All start OFF. A system that is OFF gives no warnings and no readings.'||'0a'x||self~costsLine
::method costsLine private
  /* v0.92 (Tom Dyer): "All actions have costs." One table, per airframe. */
  t='COSTS - every action costs battery, including waiting; pay only for what helps you win:'||'0a'x
  if self~isWing then t=t||'- flying: about 0.14 per tick at 8 m/s cruise (more when faster); a wing cannot hover, waiting means circling.'||'0a'x||,
    '- climbing: about 0.2 per metre gained; descending glides for free.'||'0a'x
  else t=t||'- flying: hover 1.00 per tick (the most expensive way to wait), 3 m/s 0.96, 5 m/s 0.91, 7 m/s 0.875.'||'0a'x||,
    '- climbing: about 0.05 more per tick for each m/s of climb; descending is free.'||'0a'x
  t=t||'- lookup (fixed harbour-camera view): 3 units each.'||'0a'x
  if .local['SLAM450.AVOID']=='ON' then t=t||'- scanner: 0.020 per tick while ON. altimeter: 0.007 per tick while ON. gps: 0.9 per tick while ON (plus time to fix).'||'0a'x
  t=t||'- crashing or an empty battery costs you the race.'
  return t
::method gpwsNote
  /* v0.92 (Tom Dyer): two switchable onboard sensors; warnings are advisory. */
  if .local['SLAM450.AVOID']\=='ON' then return ''
  return 'ONBOARD WARNING SENSORS (aircraft systems: OFF until YOU switch them on; each costs battery while ON; when OFF they are silent):'||'0a'x||,
    '- SCANNER: short-range reflective scanner looking ahead (+-15 deg, -10..+10 deg, 60 m); reports the nearest'||,
    ' obstacle, ground or water and its side. Costs 0.020 per tick while on.'||'0a'x||,
    '- RADIO ALTIMETER: your height above whatever is directly below (water, ground or a structure top such as the'||,
    ' bridge deck). Costs 0.007 per tick while on. Below about 2 m above any surface you crash.'||'0a'x||,
    '- GPWS callouts from sensors that are ON: OBSTACLE <m> M AHEAD/LEFT/RIGHT, TOO LOW, PULL UP. They are ADVISORY:'||,
    ' heed them normally, but you MAY ignore them when you deliberately descend onto, thread between pylons to, or fly'||,
    ' under the bridge to a target you can see. The road passage under the arch and the space under the deck are open.'||'0a'x||,
    '- GPS (optional, power hungry like a phone): costs 0.9 per tick while ON (about doubles your consumption), and needs'||,
    ' time to fix after switching on: ~30 s cold, ~8 s if it was off under 2 minutes, ~1 s if off under 5 s. Once fixed it'||,
    ' gives your position as a pixel on the plan map ('self~mapScale' px per metre), altitude, ground speed and track (+-2 m).'||'0a'x
::method mapScale private
  sc=.local['SLAM450.MAP_SCALE'];if \datatype(sc,'N') then sc=1.5
  return sc
::method mapNote
  /* v0.90: static plan map (Slam450PlanMap), when the runner enables it. */
  if .local['SLAM450.MAP']\=='MAP' then return ''
  sc=.local['SLAM450.MAP_SCALE'];if \datatype(sc,'N') then sc=1.5
  return .Slam450PlanMap~briefingText(.local['SLAM450.MAP_W'],.local['SLAM450.MAP_H'],sc)
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
        'Pilot status: '||pilotStatus||'0a'x||self~gpwsLine(meter)||self~assistText(frame,available)
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
      req~addText('Second image: the fixed harbour camera view you bought ('||self~lastViewName||'; same panorama format, seen from that camera).')
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
      if parsed~hasIndex('lookup') then do
        a['LOOKUP']=jsonTrue(parsed['lookup'])
        nm=self~cameraName(parsed['lookup'])
        if nm\=='' then do;a['LOOKUP']=.true;self~chooseView(nm);end
      end
      if parsed~hasIndex('gps') then self~setSensor('GPS',parsed['gps'])
      if parsed~hasIndex('note') then a['NOTE']=parsed['note']~string~changestr('0a'x,' ')
      if self~hasBook then ignored=self~writeBook(tick,parsed,'NAVIGATOR')
    end
  end
  if status\=='OK' then faults+=1
  a['STATUS']=status
  if a['NOTE']\=='' then self~remember(tick,a['NOTE'])
  e=.directory~new
  e['TICK']=tick;e['STATUS']=status;e['LATENCY_MS']=lat;e['IN']=inT;e['OUT']=outT
  e['CACHE_READ']=cr;e['CACHE_WRITE']=cw;e['COST']=cost;e['TARGET']=a['TARGET']
  e['CMD']=.array~of(a['SPEED'],'','','');e['LOOKUP']=self~lookupLogValue(a['LOOKUP']);e['NOTE']=a['NOTE'];e['RAW']=reply~left(min(300,reply~length))
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

::routine jsonTrue public
  /* v0.92 fix: .JSON~fromJSON gives a JsonBoolean for true/false. It overrides
   * "=" but not "==", so the old strict test (v==.true) was never true and
   * every LLM "lookup":true (and sensor switch) was silently dropped since
   * the lookup key existed. Accept JsonBoolean, true/false, on/off, 1/0. */
  use strict arg v
  if v~isA(.String) then s=v
  else if v~class~id~upper=='JSONBOOLEAN' then return v~value=1
  else s=v~string
  s=s~strip~lower
  return s=='true' | s=='1' | s=='on' | s=='yes'
