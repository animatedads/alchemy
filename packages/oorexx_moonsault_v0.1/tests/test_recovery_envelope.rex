numeric digits 30
p=.MoonsaultPlateIdentity
stars=p~loadCatalogue('../fixtures/yale_nine_matched.csv')
tracks=.array~new
path='../fixtures/six_frame_star_tracks.tsv'
ignored=linein(path)
do while lines(path)>0
  line=linein(path)
  parse var line x '09'x y '09'x x2 '09'x y2 '09'x rest
  if datatype(x,'W') & datatype(y,'W') then tracks~append(.array~of(x,y,x2,y2))
end
ignored=stream(path,'C','CLOSE')
if stars~items<>9 | tracks~items<>9 then do
 say 'FAIL missing star data';exit 10
end
plate=p~fit(stars,tracks)
JD=2461354.91979166667
lms=.array~of( -
 .array~of('Sydney Opera House',-33.8568,151.2153,211.3895,625), -
 .array~of('Bridge South Pylons',-33.85454,151.20926,1173.5763,600), -
 .array~of('Bridge North Pylons',-33.85003,151.21209,1682.36,600))
fix=.MoonsaultCameraFix~locate(plate,JD,lms)
e=.MoonsaultRecoveryEnvelope
a=e~evaluate(plate,JD,lms,fix,2,2500,50)
say 'ANGULAR_ENVELOPE' a['STATUS']
say 'FEASIBLE_GRID' a['POINTS_FEASIBLE'] '/' a['POINTS_EXAMINED']
say 'ENVELOPE_PADDED_METRES' a['GRID_PADDED_RADIUS_METRES']
say 'EAST' a['EAST_LIMITS'][1] a['EAST_LIMITS'][2]
say 'NORTH' a['NORTH_LIMITS'][1] a['NORTH_LIMITS'][2]
say 'EDGE_TOUCHES' a['BOUNDARY_TOUCH_COUNT']
if a['POINTS_FEASIBLE']<1 | a['BOUNDARY_TOUCH_COUNT']<>0 then do
 say 'FAIL no closed feasible region';exit 11
end
if a['INDEPENDENT_GROUND_TRUTH'] | a['SURVEY_5M_QUALIFIED'] | a['ONE_NM_CERTIFIED'] then do
 say 'FAIL false survey qualification';exit 12
end
if a['SAMPLED_WITHIN_ONE_NM']<>(a['GRID_PADDED_RADIUS_METRES']<=1852) then do
 say 'FAIL one-nautical-mile classification';exit 13
end
b=e~evaluate(plate,JD,lms,fix,0.1,1000,50)
say 'STRICT_0.1_DEG' b['STATUS'] 'feasible=' b['POINTS_FEASIBLE']
if b['STATUS']<>'NO_FEASIBLE_POSITION' then do
 say 'FAIL unrealistic angular tolerance passed';exit 14
end
audit=e~stress(plate,JD,lms,fix,20,25)
say 'STRESS_SAMPLES' audit['RUNS']
say 'MAX_LOCATION_SHIFT_METRES' audit['MAX_LOCATION_CHANGE_METRES']
say 'MAX_STRESS_LANDMARK_ERROR' audit['MAX_LANDMARK_ANGULAR_RESIDUAL']
if audit['RUNS']<>54 | audit['ONE_NM_QUALIFIED'] then do
 say 'FAIL stress receipt validity';exit 15
end
if audit['MAX_LOCATION_CHANGE_METRES']<=0 then do
 say 'FAIL no response to landmark perturbations';exit 16
end
/* Synthetic independent position: build three chart landmarks along actual
 * sky-derived rays and leave a fourth out of the location fit. The bearing
 * equality is generated independently of the fitter's line intersection. */
cam=.MoonsaultCameraFix
o=.MoonsaultAngle;ignore=o~load
trueLat=-33.8491;trueLon=151.2146
points=.array~of( .array~of(155,630,750), .array~of(1040,620,950), -
 .array~of(1810,560,800), .array~of(670,400,1200))
known=.array~new
j=0
do item over points
 j=j+1
 heading=cam~direction(plate,item[1],item[2],JD,trueLat,trueLon)['AZIMUTH_TRUE']
 lat=trueLat+item[3]*o~cos(heading)/111320
 lon=trueLon+item[3]*o~sin(heading)/(111320*o~cos(trueLat))
 known~append(.array~of('SYNTHETIC_'||j,lat,lon,item[1],item[2]))
end
training=.array~of(known[1],known[2],known[3])
recovered=cam~locate(plate,JD,training,-33.853,151.207)
northErr=(recovered['LATITUDE']-trueLat)*111320
eastErr=(recovered['LONGITUDE']-trueLon)*111320*o~cos(trueLat)
metres=o~sqrt(eastErr*eastErr+northErr*northErr)
held=known[4]
chartHeading=cam~landmarkBearing(recovered['LATITUDE'],recovered['LONGITUDE'],held[2],held[3])
imageHeading=cam~direction(plate,held[4],held[5],JD,recovered['LATITUDE'],recovered['LONGITUDE'])['AZIMUTH_TRUE']
heldoutErr=abs(cam~angleError(chartHeading,imageHeading))
say 'SYNTHETIC_GROUND_TRUTH_ERROR_METRES' metres
say 'SYNTHETIC_HELDOUT_BEARING_RESIDUAL_DEG' heldoutErr
if metres>5 | heldoutErr>0.5 then do
 say 'FAIL synthetic independent location recovery';exit 18
end
say 'PASS bounded angular grid and landmark stress; NO survey/GPS certification' 
::requires '../src/MoonsaultRecoveryEnvelope.cls'