/* Independent 360-image rival wind/altitude inference qualification. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
sensor=(.Slam450AirflowInstruments~new)~sample(0,5,0,2)
cmd=.array~of(0,0,0,0)
a=.Slam450RivalAir~new('A1',8)
b=.Slam450RivalAir~new('A2',8)
f=makeFrame(205,42,10,0)
o=a~observe(f,0,.nil,cmd,1)
call check o['RIVAL_STATUS']=='VISUAL_SILHOUETTE','sees rival onboard only'
call check o['OWN_LEVEL']=='UNKNOWN','no invented own level'
call check o['HEIGHT_ORDER']=='ABOVE','image-derived higher rival'
call check o['RIVAL_GROUND_SPEED_MPS']=='UNKNOWN','relative visual rate is not ground velocity'
call check o['RIVAL_WIND_VECTOR']=='UNKNOWN','cannot infer wind vector by sight alone'
call check o['RANGE_APPROX_M']\=='UNKNOWN','size gives a quantised approximate range'
call check o['RELATIVE_SPEED_APPROX_MPS']=='UNKNOWN','one image cannot measure speed'
f=makeFrame(205,42,10,0)
o=a~observe(f,1,sensor,cmd,1)
call check o['OWN_LEVEL']=='L2','own sensor flight level used'
call check o['RIVAL_LEVEL_CANDIDATE']=='UNRESOLVED','wide own band must not invent rival exact altitude'
call check o['EGO_YAW_REMOVED']=='SHARED_LANDMARKS','stationary anchors cancel panorama rotation'
call check o['RELATIVE_SPEED_APPROX_MPS']\=='UNKNOWN','temporal image pair yields apparent speed'
call check o['RIVAL_ALTITUDE_LOW_M']\=='UNKNOWN','rough altitude interval inferred'
call check o['RIVAL_ALTITUDE_HIGH_M']>o['RIVAL_ALTITUDE_LOW_M'],'altitude expressed as uncertainty interval'
do tick=2 to 5
  f=makeFrame(205,42,10,0)
  o=a~observe(f,tick,sensor,cmd,1)
end
call check o['WIND_IDEA']=='POSSIBLE_HEADWIND_HOVER_OR_MATCHED_MOTION','stationary rival is ambiguous headwind hypothesis'
call check o['CONFIDENCE']=='LOW_CANDIDATE','stall is not wind proof'
r=a~recommendAltitude('L2',cmd)
call check r['ACTION']=='ALTITUDE_EXPERIMENT','visual rival evidence influences flight-level trial'
call check r['CLIMB_M_PER_STEP']<0,'rival apparently struggling above suggests downward trial'
call check r['CONFIDENCE']=='HYPOTHESIS_REQUIRES_TRIAL','trial distinguished from wind truth'
r=a~recommendAltitude('L1',cmd)
call check r['ACTION']=='HOLD','does not descend below first band'
call check b~slots~items==0,'rival ideas private to first pilot'
/* A PHOTO-based own-altitude estimate may narrow the otherwise wide band.
 * Never give a referee aircraft Z to the learner. */
est=.directory~new
est['ESTIMATE_SOURCE']='ONBOARD_LANDMARK_INVERSE'
est['STATUS']='IMAGE_BEARING_ESTIMATE'
est['Z']=75;est['Z_UNCERTAINTY_M']=6
z=.Slam450RivalAir~new('A2',8)
do step=1 to 5
  zn=z~observe(makeFrame(205,42,10,0),step,sensor,cmd,1,est)
end
call check zn['OWN_ALTITUDE_EXACT_M']=='UNKNOWN','inverse image estimate never promoted to exact altitude'
call check zn['OWN_ALTITUDE_IMAGE_EST_M']==75,'image-derived own altitude accepted with bounded uncertainty'
call check zn['RIVAL_LEVEL_CANDIDATE']=='L2','sufficiently narrow image geometry locates rival probable band'
call check z~levelIdeas~hasIndex('L2'),'rival wind hypotheses recorded in estimated band'
call check z~levelIdeas['L2']['OBSERVATIONS']>0,'per-band wind idea observations counted'
call check a~slots~items==6,'six distinct onboard observations retained'
/* Visual yaw alone must not look like crosswind. Shift both A-D and rival
 * by the same amount, and verify corrected drift is zero. */
yaw=.Slam450RivalAir~new('A2',8)
o=yaw~observe(makeFrame(205,42,10,0),0,sensor,cmd,1)
o=yaw~observe(makeFrame(209,42,10,4),1,sensor,cmd,1)
call check abs(o['APPARENT_CROSS_TRACK_DEG'])<0.0001,'static landmark de-rotation prevents false drift'
/* Apparent zig-zag can suggest buffeting but may equally be manoeuvring. */
j=.Slam450RivalAir~new('A1',8)
path=.array~of(200,206,199,208,198,207,197)
do i=1 to path~items
  o=j~observe(makeFrame(path[i],38,12,0),i,sensor,cmd,1)
end
call check o['WIND_IDEA']=='POSSIBLE_RIVAL_BUFFETING_OR_STEERING','lateral reversals produce qualified candidate'
call check o['CONFIDENCE']=='LOW_CANDIDATE','buffeting not asserted as wind fact'
call check o['RELATIVE_SPEED_APPROX_MPS']\=='UNKNOWN','apparent speed measurable under anchors'
/* Missing/too small silhouettes may not be translated into range. */
s=.Slam450RivalAir~new('A1',8)
o=s~observe(makeFrame(205,55,1,0),1,sensor,cmd,1)
call check o['RANGE_APPROX_M']=='UNKNOWN','three-pixel silhouette not a distance measurement'
call check o['RIVAL_LEVEL_CANDIDATE']=='UNRESOLVED','no invented rival band when range unresolved'
/* A fixed camera is only comparable with its own earlier image. */
x=.Slam450RivalAir~new('A2',8)
fx=x~observeFixed('CAFE_SYDNEY',makeFrame(210,45,8,0),5)
call check fx['ANGULAR_SPEED_DEG_PER_STEP']=='UNKNOWN','first fixed observation has no speed baseline'
fx=x~observeFixed('CAFE_SYDNEY',makeFrame(220,45,8,0),30)
call check fx['STATUS']=='SAME_STATIONARY_VIEW_MOTION_CANDIDATE','same stationary site can estimate angular speed'
call check fx['ANGULAR_SPEED_DEG_PER_STEP']>0,'fixed camera angular motion positive'
call check fx['SPEED_APPROX_MPS']\=='UNKNOWN','repeated fixed images yield coarse apparent motion speed'
call check fx['WIND_PROVEN']=='NO','fixed image velocity alone does not prove wind'
call check x~fixedViews~items==1,'fixed camera owns one bounded prior per site'
/* Persist only image/sensor derived fields. */
do n=6 to 17
  o=a~observe(makeFrame(205,42,10,0),n,sensor,cmd,1)
end
call check a~slots~items==8,'memory fixed at eight slots'
file='rival_air450_test.csv'
call check a~saveObservations(file)==8,'pilot evidence CSV saved'
call check stream(file,'C','QUERY EXISTS')\=='','saved evidence exists'
leak=sensor~copy
leak['WIND_EAST_MPS']=3.2
signal on syntax name leakRejected
bad=b~observe(makeFrame(200,42,10,0),1,leak,cmd,1)
say 'FAIL oracle wind field accepted';exit 7
leakRejected:
 say 'SLAM450 RIVAL AIR / IMAGE WIND INFERENCE PASS' checks 'checks'
 exit 0
check:
 parse arg ok,label
 if \ok then do;say 'FAIL' label;exit 7;end
 checks+=1
return
makeFrame: procedure
 parse arg x,y,half,shift
 width=480;height=121
 rows=.array~new
 do ry=1 to height
   line='.'~copies(width)
   if ry==62 then do
     line=overlay('A',line,101+shift)
     line=overlay('B',line,141+shift)
     line=overlay('C',line,265+shift)
   end
   if ry>=y-half & ry<=y+half then ,
     line=overlay('R'~copies(2*half+1),line,x-half)
   rows~append(line)
 end
 frame=.directory~new
 frame['WIDTH']=width;frame['HEIGHT']=height;frame['PIXELS']=rows
return frame
::requires 'Slam450RivalAir.cls'
