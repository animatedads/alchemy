/* SLAM 450 v0.94 (v0.96): the situation as Boston Crab reads it.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
 *
 * Boston Crab (oorexx_slam_bostoncrab v0.8) checks a plain-English order
 * against a situation written as narration, plus a map: sight.words ("sight
 * alpha ruby CANNOT 0 1") bound to the narration by bind.words ("bind ruby
 * Ruby"). This class writes those three files and cast.words from the SLAM
 * 450 world, so nothing about who can see what is typed by hand:
 *   - places: the fixed named places of the HARBOUR box (towers, pylons,
 *     bridge, wharves, station, hill, base, Opera House) and the five
 *     targets, named Ruby, Garnet, Coral, Scarlet and Crimson;
 *   - the squad A1..A5 as Alpha..Echo (A6 Foxtrot in 3V3), and Control (the remote commander);
 *   - sight for each craft from its true pose: SLAM 450's own line of sight
 *     (scene solids, the arch and the ground; Top Rope's grid is bare earth
 *     and would miss the buildings) and the identification rule of the
 *     briefing, a 2 m target at 500 m, i.e. size/range >= 1/250. A fixed
 *     place on the craft's map is identifiable without sight (MAPPED);
 *   - Control sees no camera: it knows the map and what has been reported.
 *     An unreported target is CANNOT for Control.
 * Verdict words in sight.words: SEES, CANNOT, MAPPED. Boston Crab rules out
 * CANNOT and leaves every other word in. */
::class Slam450Situation public
::attribute places get      /* array of directories: KEY PHRASE X Y Z SIZE KIND BOX */
::attribute craftNames get  /* A1 -> Alpha */

::method init
  expose places craftNames
  use strict arg world
  numeric digits 16
  places=.array~new
  f=world~scene~features
  /* v0.94b (Boston Crab v0.10): real names, capitalised, as the map shows them */
  call add 'salesforce','Salesforce Tower','tower',f['T'],263,'SALESFORCE','Salesforce Tower was a tower.'
  call add 'bluespoint','Blues Point Tower','tower',f['BPT_ROOF'],83,'BLUES_POINT_TOWER','Blues Point Tower was a tower.'
  call add 'bridge','the Harbour Bridge','bridge',f['ARCH_CROWN'],500,'','The Harbour Bridge was a bridge.'
  call add 'pylon-ne','the northeast pylon','pylon',f['NE'],89,'PYLON_TOWER_PHOTO','The northeast pylon was beside the Harbour Bridge.'
  call add 'pylon-nw','the northwest pylon','pylon',f['NW'],89,'PYLON_TOWER_PHOTO','The northwest pylon was beside the Harbour Bridge.'
  call add 'pylon-se','the southeast pylon','pylon',f['SE'],89,'PYLON_TOWER_PHOTO','The southeast pylon was beside the Harbour Bridge.'
  call add 'pylon-sw','the southwest pylon','pylon',f['SW'],89,'PYLON_TOWER_PHOTO','The southwest pylon was beside the Harbour Bridge.'
  call add 'opera','the Opera House','building',.array~of(482,-519,69),180,'OPERA','The Opera House was a building.'
  call add 'station','the station','station',f['STATION_C'],13,'CQ_STATION','The station was at Circular Quay.'
  q=mean(.array~of(f['CQ2'],f['CQ3'],f['CQ4'],f['CQ5'],f['CQ6']))
  /* Boston Crab v0.14: noun-before-noun groups stay apart, a plural takes
     single things only when no group fits, numbered names are names */
  call add 'ferry','the ferry wharves','wharf',q,200,'','The ferry wharves were at Circular Quay.'
  places[places~items]['LABEL']='Circular Quay wharves'
  call add 'quay','Circular Quay','area',q,250,'',''
  do wn=2 to 6
    lines='Wharf' wn 'was a wharf.|Wharf' wn 'was at Circular Quay.'
    if wn=2 then lines=lines'|Wharf 2 was east.'
    if wn=6 then lines=lines'|Wharf 6 was west.'
    call add 'wharf'wn,'Wharf' wn,'wharf',f['CQ'wn],40,'CQ'wn'_ROOF',lines
  end
  w=mean(.array~of(f['WB23'],f['WB45'],f['WB67'],f['WB89']))
  call add 'finger','the finger wharves','wharf',w,400,'','The finger wharves were at Walsh Bay.'
  places[places~items]['LABEL']='Walsh Bay wharves'
  hz=0;if world~ground\==.nil then do;hz=world~ground~surface(-510,-870);if \datatype(hz,'N') then hz=0;end
  call add 'hill','Observatory Hill','hill',.array~of(-510,-870,hz),200,'','Observatory Hill was a hill.'
  call add 'base','the base','base',.array~of(-250,-100,30),20,'','The base was beside the Harbour Bridge.'
  /* v0.96 (Boston Crab v0.15): the race field is a place, so "the field" and
     "поля" check against it in both languages; centre of SLAM's field box */
  fb=world~fieldBox
  if fb\==.nil then call add 'field','the field','area',.array~of((fb[1]+fb[2])/2,(fb[3]+fb[4])/2,30),min(fb[2]-fb[1],fb[4]-fb[3]),'','The field was an area.'
  tn=.array~of('Ruby','Garnet','Coral','Scarlet','Crimson')
  do t=1 to world~targets~items
    p=world~targets[t]
    /* v0.97 (Boston Crab v0.16): Control's briefing calls the targets "2 m red
       markers", and its orders do too ("шукайте червоні маркери") */
    call add tn[t]~lower,tn[t],'target',p,2,'',tn[t] 'was a target.|'tn[t] 'was a red marker.'
  end
  craftNames=.directory~new
  cn=.array~of('Alpha','Bravo','Charlie','Delta','Echo','Foxtrot')
  do i=1 to 6;craftNames['A'i]=cn[i];end   /* A6 Foxtrot: Red's fixed wing in 3V3 (v0.97) */
  return

add:
  use arg key,phrase,kind,pt,size,box,lines
  d=.directory~new
  d['KEY']=key;d['PHRASE']=phrase;d['KIND']=kind
  d['X']=pt[1];d['Y']=pt[2];d['Z']=pt[3];d['SIZE']=size;d['BOX']=box
  lb=phrase;if lb~left(4)=='the ' then lb=lb~substr(5)
  d['LABEL']=lb~left(1)~upper||lb~substr(2)
  d['LINES']=lines
  places~append(d)
  return

mean: procedure
  use arg pts
  sx=0;sy=0;sz=0
  do p over pts;sx+=p[1];sy+=p[2];sz+=p[3];end
  n=pts~items
  return .array~of(sx/n,sy/n,sz/n)

::method place
  expose places
  use strict arg key
  do d over places;if d['KEY']==key then return d;end
  return .nil

::method nearestPlace
  /* the nearest fixed place (not a target) to a point, for "Alpha was near X" */
  expose places
  use strict arg x,y
  best=.nil;bd=1e20
  do d over places
    if d['KIND']=='target' then iterate
    dd=(d['X']-x)**2+(d['Y']-y)**2
    if dd<bd then do;bd=dd;best=d;end
  end
  return best

::method identifies
  /* can a craft at eye identify place d? MAPPED, SEES or CANNOT */
  use strict arg world,eye,d,mapOn
  numeric digits 16
  if mapOn & d['KIND']\=='target' then return 'MAPPED'
  r=RxCalcSqrt((d['X']-eye[1])**2+(d['Y']-eye[2])**2+(d['Z']-eye[3])**2,16)
  if r>0 then if d['SIZE']/r<1/250 then return 'CANNOT'
  pts=.array~of(.array~of(d['X'],d['Y'],d['Z']))
  if d['KIND']\=='target' then pts~append(.array~of(d['X'],d['Y'],d['Z']/2+1))
  a=.array~of(eye[1],eye[2],eye[3])
  do p over pts
    if \world~sightBlocked(a,p,d['BOX']) then return 'SEES'
  end
  return 'CANNOT'

::method write
  /* dir: folder for Boston Crab. poses: A1.. -> true pose array. active:
     A1.. -> .true/.false. reported: blank-separated target keys known to
     Control. mapOn: crafts carry the map. Writes story.txt (situation only;
     the caller appends the order sections), cast.words, bind.words and
     sight.words. Returns the number of sight lines written. */
  expose places craftNames
  use strict arg dir,world,poses,active,reported,mapOn,tick,own=''
  numeric digits 16
  /* v0.97: the squad is the craft the race passes in (active's indexes),
     however many there are; craftNames only gives each its call sign */
  squad=active~allIndexes~sort
  st=dir'/story.txt'
  call SysFileDelete st
  call lineout st,'# Situation'
  do d over places
    if d['LINES']=='' then iterate
    do ln over d['LINES']~makeArray('|')
      call lineout st,ln
    end
  end
  do d over places
    if d['KIND']=='target' then do
      np=self~nearestPlace(d['X'],d['Y'])
      /* "beside", not "near": Boston Crab v0.14 leaves "X was near Y" unread */
      call lineout st,d['PHRASE'] 'was beside' np['PHRASE']'.'
    end
  end
  call lineout st,'Control was at the base.'
  /* v0.97 (Boston Crab v0.17): with two teams, the other team's drones are
     hostile to this Control ("з ворожими дронами"); own: this team's ids */
  if own\=='' then do id over squad
    if wordpos(id,own)=0 & active[id] then call lineout st,craftNames[id] 'was a hostile drone.'
  end
  /* v0.98 (Boston Crab v0.19 checks the object of a command): every craft in
     the race is a drone ("відведіть дрон", withdraw the drone); own craft
     here, the other team's as hostile drones above */
  do id over squad
    if active[id] & (own=='' | wordpos(id,own)>0) then call lineout st,craftNames[id] 'was a drone.'
  end
  do id over squad
    if \active[id] then iterate
    np=self~nearestPlace(poses[id][1],poses[id][2])
    call lineout st,craftNames[id] 'was beside' np['PHRASE']'.'
  end
  call stream st,'C','CLOSE'
  cf=dir'/cast.words';call SysFileDelete cf
  do w over 'control alpha bravo charlie delta echo foxtrot ruby garnet coral scarlet crimson'~subWords
    call lineout cf,w
  end
  call stream cf,'C','CLOSE'
  bf=dir'/bind.words';call SysFileDelete bf
  call lineout bf,'-- SLAM 450 v0.99: which thing in the situation each SLAM place stands for (tick' tick')'
  call lineout bf,'bind control Control'
  do id over squad
    if active[id] then call lineout bf,'bind' craftNames[id]~lower craftNames[id]
  end
  do d over places;call lineout bf,'bind' d['KEY'] d['PHRASE'];end
  call stream bf,'C','CLOSE'
  sf=dir'/sight.words';call SysFileDelete sf
  call lineout sf,'source SLAM 450 v0.99 line of sight (Tombstone ELVIS ground, Power SLAM solids and arch)'
  call lineout sf,'-- SLAM 450 v0.99 sight at tick' tick': each craft from its flight-book position (scene solids, arch, ground;'
  call lineout sf,'-- identification at size/range >= 1/250). MAPPED = a fixed place on the craft''s map.'
  call lineout sf,'-- control has no camera: CANNOT = not on the map and not reported.'
  n=0
  do d over places
    if d['KIND']=='target' & wordpos(d['KEY'],reported)=0 then do
      call lineout sf,'sight control' d['KEY'] 'CANNOT 0 1';n+=1
    end
  end
  do id over squad
    if \active[id] then iterate
    do d over places
      v=self~identifies(world,poses[id],d,mapOn)
      /* a reported target is on the shared picture */
      if v=='CANNOT' & d['KIND']=='target' & mapOn & wordpos(d['KEY'],reported)>0 then v='MAPPED'
      seen=0;if v\=='CANNOT' then seen=1
      call lineout sf,'sight' craftNames[id]~lower d['KEY'] v seen 1;n+=1
    end
  end
  call stream sf,'C','CLOSE'
  pf=dir'/places.words';call SysFileDelete pf
  do d over places;call lineout pf,'place' d['KEY'] format(d['X'],,1) format(d['Y'],,1) format(d['Z'],,1);end
  call lineout pf,'place control -250 -100 0'
  do id over squad
    if active[id] then call lineout pf,'place' craftNames[id]~lower format(poses[id][1],,1) format(poses[id][2],,1) format(poses[id][3],,1)
  end
  call stream pf,'C','CLOSE'
  return n

::method mapText
  /* Control's whole picture: no camera. Fixed places, the squad where each
     craft's flight book says it is, reported targets, claims. */
  expose places craftNames
  use strict arg books,active,reported,claimed,tick,only=''
  numeric digits 16
  t='MAP (metres: E east, N north; the Field, the race area: E -640..260, N -1130..380, height 8-90 m)'||'0a'x
  t=t||'Places:'||'0a'x
  do d over places
    if d['KIND']=='target' | d['KEY']=='field' then iterate
    t=t||'  'left(d['LABEL'],22) 'E' format(d['X'],5,0) 'N' format(d['Y'],5,0) 'top' format(d['Z'],4,0) 'm ('d['KIND']')'||'0a'x
  end
  t=t||'Targets reported to you:'||'0a'x
  k=0
  do d over places
    if d['KIND']\=='target' then iterate
    if wordpos(d['KEY'],reported)=0 then iterate
    k+=1;st='open';if wordpos(d['KEY'],claimed)>0 then st='CLAIMED'
    t=t||'  'left(d['PHRASE'],8) 'E' format(d['X'],5,0) 'N' format(d['Y'],5,0) 'height' format(d['Z'],4,0) 'm' st||'0a'x
  end
  if k=0 then t=t||'  none yet (5 targets are somewhere in the field)'||'0a'x
  t=t||'Squad (as each craft''s flight book believes):'||'0a'x
  do id over active~allIndexes~sort
    if only\=='' then if wordpos(id,only)=0 then iterate
    if \active[id] then do;t=t||'  'craftNames[id] 'out of the race'||'0a'x;iterate;end
    b=books[id]
    np=self~nearestPlace(b~x,b~y)
    dd=RxCalcSqrt((np['X']-b~x)**2+(np['Y']-b~y)**2,16)
    t=t||'  'left(craftNames[id],8) 'E' format(b~x,5,0) 'N' format(b~y,5,0) 'heading' format(b~heading,3,0) '-' format(dd,,0) 'm from' np['PHRASE']||'0a'x
  end
  return t
