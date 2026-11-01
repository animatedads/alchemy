/* Geometry-only wharf qualification. Does not claim surveyed roof corners.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-01.
 */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg dest
if dest=='' then dest='.'
p=.HarbourWharfPanorama~new
checks=0
ids=.array~of('CQ2','CQ3','CQ4','CQ5','CQ6','WB23','WB45','WB67','WB89')
call check p~wharves~items=9,'5 Circular Quay and 4 Walsh Bay named wharves'
call check p~scene~boxes~items=25,'base 7 solids plus 18 wharf solids'
call check p~scene~features~items=14,'5 original landmarks plus 9 wharf roof markers'
seen=.directory~new
cqCount=0;walshCount=0
unknown=0;published=0;nearby=0
 do id over ids
  m=p~getWharf(id)
  call check m['ID']==id,'stable wharf identity' id
  call check \seen~hasIndex(id),'no duplicate wharf' id
  seen[id]=1
  call check \m['SURVEYED_FOOTPRINT'] & \m['SURVEYED_ROOF'],'unmeasured dimensions explicitly flagged' id
  call check p~scene~features~hasIndex(id),'3D roof-point feature' id
  pt=p~scene~features[id]
  geo=p~scene~local(m['LAT'],m['LON'])
  call check abs(geo[1]-pt[1])<0.00001 & abs(geo[2]-pt[2])<0.00001,'feature coordinates follow ledger' id
  call check pt[3]=m['ROOF'],'roof elevation follows ledger' id
  if m['GROUP']=='CIRCULAR' then cqCount+=1
  else if m['GROUP']=='WALSH' then walshCount+=1
  else call check .false,'unknown group'
  if m['STATUS']=='PUBLISHED_POINT' then published+=1
  else if m['STATUS']=='NEARBY_POINT' then nearby+=1
  else if m['STATUS']=='HYPOTHESIS' then unknown+=1
  else call check .false,'unknown anchor status'
 end
call check cqCount=5 & walshCount=4,'both named wharf families populated'
call check published=5 & nearby=1 & unknown=3,'5 published, 1 nearby, 3 hypothetical point anchors'
/* Quay documented ordered from east to west, not equal spacing. */
prev=1e30
do id over .array~of('CQ2','CQ3','CQ4','CQ5','CQ6')
  x=p~scene~features[id][1]
  call check x<prev,id 'is west of the prior CQ pier'
  prev=x
end
/* Walsh box axes NNW and shed top higher than deck top. */
do id over .array~of('WB23','WB45','WB67','WB89')
  roof=.nil;deck=.nil
  do box over p~scene~boxes
    if box[1]==id||'_ROOF' then roof=box[2]
    if box[1]==id||'_DECK' then deck=box[2]
  end
  call check roof\==.nil & deck\==.nil,id 'deck and shed both present'
  call check roof[5][3]>deck[5][3],id 'roof higher than deck'
  dx=roof[4][1]-roof[2][1]
  dy=roof[4][2]-roof[2][2]
  call check dx<0 & dy>0,id 'finger pier along NW direction'
end
/* Check every SVG fully closed and full geometry contained in root. */
do site over .array~of('KIRRIBILLI','CIRCULAR','BLUES')
  c=p~siteCamera(site)
  call check c[3]=50,site 'camera height 50 m ASL'
  file=dest || '/' || site~lower || '_wharves_360.svg'
  p~render(site,file)
  call check stream(file,'C','QUERY EXISTS')\=='',site 'SVG created'
  xml=charin(file,1,chars(file));call stream file,'C','CLOSE'
  call check xml~left(4)=='<svg' & xml~strip('T','0a'x)~right(6)=='</svg>',site 'valid open/close root'
  call check occurrences(xml,'<polygon ')=450,site '25 boxes x 6 faces x 3 wraps'
  call check lastpos('<polygon ',xml)<lastpos('</svg>',xml),site 'geometry inside SVG'
  do id over ids
    call check pos('> ' || id || ' </text>',xml)>0,site id 'label rendered'
    b=p~bearingOf(id,site)
    call check b>=0 & b<360,site id 'bearing bounded'
  end
end
say 'POWER SLAM WHARF GEOMETRY QUALIFICATION: PASS (' || checks || ' checks)'
exit 0
occurrences: procedure
  use arg s,needle
  n=0
  do forever
    k=pos(needle,s)
    if k=0 then leave
    n+=1;s=s~substr(k+needle~length)
  end
  return n
check: procedure expose checks
  use arg yes,label
  checks+=1
  if yes then say 'PASS' label
  else do
    say 'FAIL' label
    exit 1
  end
  return
::requires 'SlamHarbourWharves.cls'

