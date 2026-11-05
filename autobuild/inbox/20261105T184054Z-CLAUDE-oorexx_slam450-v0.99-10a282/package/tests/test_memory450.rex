/* Independent native tests of image-only memory, rotation invariance,
 * bounded slots, revisits, and on-disk steering state. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
count=0
w=.Slam450World~new(45042,'LOOP')
s=.Slam450Camera~new(w)
base=.array~of(w~pose[1],w~pose[2],w~pose[3],0)
a=s~renderAt(base,360,91)
base[4]=90
b=s~renderAt(base,360,91)
m=.Slam450VisualMemory~new(8)
c=m~signature(a)
d=m~signature(b)
call check c['PAIR_COUNT']>=2,'at least two landmark pair keys'
call check d['PAIR_COUNT']>=2,'rotated image landmark pairs'
call check m~similarity(c,c)<0.0001,'self equality'
call check m~similarity(c,d)<7,'yaw-shift tolerant descriptor'
r=m~ingest(a,0,'DEPARTURE')
call check r['STATUS']=='NOVEL_OR_UNOBSERVABLE','first view novel'
r=m~ingest(b,45,'RETURN')
call check r['STATUS']=='VISUAL_SIMILARITY_CANDIDATE','return rotation recognised'
call check r['MATCH_STEP']=0,'old first slot retrieved'
call check r['POSITION_CONFIRMED']==.false,'visual similarity is not a geolocation proof'
call check r['MEANING']=='VISUAL_ONLY_NOT_GEOLOCALISED','ambiguity recorded'
call check m~firstViewSimilar(b)<7,'first-slot loop closure'
call check m~pinFrame(a,1,1)=='PINNED_VISUAL_WAYPOINT','arrival frame stored'
call check m~matchPinned(b,1)<7,'arrival revisit matches rotated frame'
call check m~pinFrame(b,30,1)=='PRESERVED_FIRST_VISIT','first-arrival image cannot be overwritten'
call check m~pins~items=1,'one separate pinned waypoint'
call check m~pins~items=1,'one separate pinned waypoint'
checkpoint='pins_roundtrip_v2.csv'
call check m~savePinned(checkpoint)=1,'pinned descriptor saved'
loaded=.Slam450VisualMemory~new(8)
call check loaded~loadPinned(checkpoint)=1,'pinned descriptor loaded'
call check loaded~matchPinned(b,1)<7,'persisted visual memory is usable'
do i=50 to 150 by 5
  unused=m~ingest(b,i,'NEW')
end
call check m~slots~items<=8,'bounded ring memory'
call check m~slots[1]['TAG']=='DEPARTURE','first slot pinned'
call check m~revisits>=1,'revisits counted'
file='policy_test_v2.txt'
p=.Slam450LearningPilot~new(m)
call check p~savePolicy(file)=='SAVED','policy persisted'
q=.Slam450LearningPilot~new(m,file)
call check q~learnedYawResponse=p~learnedYawResponse,'policy roundtrip'
call check q~responseUpdates=p~responseUpdates,'update count roundtrip'
command=q~control(a,1)
call check command~items>=3,'pilot returns controls from only frame'
call check q~memory==m,'pilot holds memory'
/* Memory retrieval when a previously seen numbered square disappears. */
recalled=.Slam450VisualMemory~new(8)
unused=recalled~ingest(a,0,'T1')
r=recalled~recallDirection(b,1,40)
call check r['STATUS']=='VISUAL_DIRECTION_RECALLED','prior target bearing recovered'
call check r['SCORE']<7,'recalled scene matches rotated image'
call check r['STEP']=0,'target direction comes from old frame'
miss=recalled~recallDirection(b,2,40)
call check miss['STATUS']=='NO_VISUAL_RECALL','unseen target is not invented'
say 'SLAM450 MEMORY + LEARNING PASS' count 'checks'
exit 0
check:
 parse arg ok,desc
 if \ok then do;say 'FAIL' desc;exit 7;end
 count+=1
return
::requires 'Slam450Learning.cls'
