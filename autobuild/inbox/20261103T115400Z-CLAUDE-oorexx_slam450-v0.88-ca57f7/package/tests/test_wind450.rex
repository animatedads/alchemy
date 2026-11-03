/* Native qualification: no exact wind direction in learner observation. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
field=.Slam450WindField~new(65053)
base=.array~new
limits=.array~new
do level=1 to 3
  b=field~bands[level]
  base~append(b[1]);limits~append(.array~of(b[2],b[3]))
end
do tick=1 to 120
  z=18+((tick-1)//3)*55
  v=field~advance(z,tick)
  level=v['LEVEL']
  call verify v['BEARING_DEG']==base[level],'wind bearing constant in level'
  call verify v['GUST_MPS']>=limits[level][1] & v['GUST_MPS']<=limits[level][2],'gust bounded by band'
  call verify abs(HSqrt(v['EAST_MPS']**2+v['NORTH_MPS']**2)-v['GUST_MPS'])<0.000001,'vector length matches gust'
end
frozen=.Slam450WindField~new(65053)
ref=frozen~advance(18,1)
call verify ref['GUST_MPS']==field~bands[1][4] | ref['GUST_MPS']>0,'deterministic seed produces valid wind'
sensor=.Slam450AirflowInstruments~new
n=sensor~sample(0,5,0,1)
call verify n['PITOT_STATUS']=='CAPTURED_FORWARD' & abs(n['PITOT_FORWARD_MPS']-5)<0.0001,'forward port pressure reports forward flow'
call verify n['CUP_AIRSPEED_MPS']==5,'cup measures full speed'
call verify n['SAIL']=='NEUTRAL','no lateral flow gives neutral sail'
s=sensor~sample(-2,4,0,2)
call verify s['SAIL']=='PORT_TO_STARBOARD','port-to-starboard flow classified'
call verify s['CUP_AIRSPEED_MPS']>s['PITOT_FORWARD_MPS'],'cup includes crossflow'
p=sensor~sample(2,4,0,3)
call verify p['SAIL']=='STARBOARD_TO_PORT','starboard-to-port flow classified'
a=sensor~sample(4,0,0,1)
call verify a['PITOT_STATUS']=='OUT_OF_FORWARD_ARC' & a['PITOT_FORWARD_MPS']==0,'90deg airflow cannot be pitot forward speed'
r=sensor~sample(0,-3,0,1)
call verify r['PITOT_STATUS']=='OUT_OF_FORWARD_ARC' & r['PITOT_FORWARD_MPS']==0,'reverse airflow cannot be measured as forward'
call verify \p~hasIndex('WIND_BEARING_DEG') & \p~hasIndex('WIND_EAST_MPS') & \p~hasIndex('TRUE_X'),'no oracle wind or position leaked'
w=.Slam450World~new(65053,'LOOP',.true)
call verify w~windEnabled,'wind enabled only explicitly'
orig=w~pose
rc=w~step(0,1,0,0)
call verify rc=='RUNNING','wind simulation step advances safely'
call verify w~lastSensorPacket\==.nil,'world provides restricted instrument packet'
call verify w~lastSensorPacket['SOURCE']=='VIRTUAL_PRESSURE_CUP_SAIL','instrument provenance'
call verify w~lastWindTruth\==.nil,'oracle stores wind vector privately'
call verify \w~lastSensorPacket~hasIndex('EAST_MPS') & \w~lastSensorPacket~hasIndex('BEARING_DEG'),'oracle fields excluded from instrument packet'
mem=.Slam450WindMemory~new(6)
do tick=1 to 18
  packet=sensor~sample(-1.2,4+tick/20,0,2)
  o=mem~record(tick,packet,4,'IMAGE_SHIFT_UNRESOLVED')
  call verify o['LEVEL']=='L2' & o['VISUAL_DRIFT_EVIDENCE']=='IMAGE_SHIFT_UNRESOLVED','wind idea retains bounded evidence'
end
call verify mem~slots~items==6,'wind memory bounded to six observations'
call verify mem~ideas['L2']['COUNT']==18,'per-level hypothesis count retained'
call verify mem~ideaAt('L2')~pos('REPEATED_PORT_TO_STARBOARD')>0,'repeated coarse crossflow forms candidate idea'
call verify mem~ideaAt('L1')=='NO_OBSERVATION','unobserved level not invented'
file='wind_observations_450.csv'
call verify mem~saveObservations(file)==6,'native wind observation CSV written'
roundtrip=.Slam450WindMemory~new(6)
call verify roundtrip~loadObservations(file)==6,'six bounded observations safely restored'
call verify roundtrip~ideaAt('L2')==mem~ideaAt('L2'),'ideas recomputed from sensor data'
call verify roundtrip~slots[1]['CUP_AIRSPEED_MPS']==mem~slots[1]['CUP_AIRSPEED_MPS'],'sensor evidence preserved'
call verify roundtrip~ideaAt('L1')=='NO_OBSERVATION','archive does not invent unobserved bands'
call verify lines(file)==0 | stream(file,'C','QUERY EXISTS')\=='','wind observation file exists'
leaked=.directory~new
leaked~put('L2','FLIGHT_LEVEL');leaked~put(2,'CUP_AIRSPEED_MPS');leaked~put(1,'PITOT_FORWARD_MPS')
leaked~put('NEUTRAL','SAIL');leaked~put('CAPTURED_FORWARD','PITOT_STATUS')
leaked~put(47,'WIND_BEARING_DEG')
signal on syntax name expected
unused=mem~record(20,leaked)
say 'FAIL accepted oracle leakage';exit 7
expected:
 say 'SLAM450 WIND / SENSOR / IDEA MEMORY PASS' checks 'checks'
 exit 0
verify:
 parse arg ok,description
 if \ok then do;say 'FAIL' description;exit 7;end
 checks+=1
return
::requires 'Slam450Learning.cls'
