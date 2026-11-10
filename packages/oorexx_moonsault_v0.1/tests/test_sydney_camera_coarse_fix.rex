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
 say 'FAIL missing authoritative nine-star observations';exit 10
end
plate=p~fit(stars,tracks)
fit=p~score(plate,stars,tracks)
say 'Yale 9-star sidereal fit RMS='format(fit[1],,5) 'max='format(fit[2],,5)
if fit[1]>0.65 | fit[2]>1.20 then do
 say 'FAIL sky plate could not reproduce original 330s observations';exit 11
end
JD=2461354.91979166667 /* 10 Nov 2026 10:04:30 UTC, Sydney 21:04:30 AEDT */
solver=.MoonsaultCameraFix
axis=solver~direction(plate,960,540,JD,-33.85,151.21)
say 'STAR_ONLY_AXIS AZ='format(axis['AZIMUTH_TRUE'],,5) 'ALT='format(axis['ELEVATION'],,5)
if abs(axis['AZIMUTH_TRUE']-208.05)>0.3 then do
 say 'FAIL optical-axis bearing';exit 20
end
lms=.array~of( -
 .array~of('Sydney Opera House',-33.8568,151.2153,211.3895,625), -
 .array~of('Bridge South Pylons',-33.85454,151.20926,1173.5763,600), -
 .array~of('Bridge North Pylons',-33.85003,151.21209,1682.36,600))
fix=solver~locate(plate,JD,lms)
say 'COARSE_3_LANDMARK_FIX LAT='format(fix['LATITUDE'],,6) 'LON='format(fix['LONGITUDE'],,6)
say 'NAV_AXIS AZ='format(fix['BEARING_TRUE'],,5) 'ELEV='format(fix['ELEVATION'],,5)
say 'MAX_LANDMARK_RESIDUAL_DEG' format(fix['MAX_LANDMARK_ANGULAR_RESIDUAL'],,4)
do item over fix['LANDMARKS']
 say 'LANDMARK' item[1] 'chart_bearing='format(item[2],,3) 'image_bearing='format(item[3],,3) 'delta='format(item[4],,3)
end
if abs(fix['LATITUDE']+33.8483)>0.0015 | abs(fix['LONGITUDE']-151.2151)>0.0015 then do
 say 'FAIL outside initial Kirribilli coarse nav cell';exit 21
end
if fix['MAX_LANDMARK_ANGULAR_RESIDUAL']>2 then do
 say 'FAIL inconsistent independent landmark bearings';exit 22
end
if fix['STATUS']<>'COARSE_NAVIGATION_CANDIDATE' then do
 say 'FAIL false precision status';exit 23
end
say 'PASS native ooRexx star pointing + independent bearing intersection; no precision claim'
::requires '../src/MoonsaultCameraFix.cls'