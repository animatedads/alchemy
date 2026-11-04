/* Power SLAM v0.24 source reality + scene projection qualification. */
parse arg filename
if filename='' then filename='/mnt/data/harbour_heights.words'
checks=0
w=.HarbourWordsMGA~new(filename)
s=.HarbourWordsSceneTile~new(w,0.9)
call assert s~crs='SLAM_LOCAL_ENU_V1','scene frame name'
call assert s~frame='SCENE_33.852S_151.210E','scene frame ID'
call assert s~datum='AHD','AHD semantics'
call assert s~rawDatum='AHD71','AHD provenance'
call assert s~uncertainty=0.9,'error required'
call assert s~roleSource='UNKNOWN_UNCLASSIFIED','unqualified role provenance'
call assert s~resolution=50,'source sampling resolution'
p=s~sceneMGA(0,0)
call assert p[1]>330000 & p[1]<335000,'MGA easting plausible'
call assert p[2]>6250000 & p[2]<6261000,'MGA northing plausible'
u=s~sample(0,0)
call assert u['STATUS']='UNKNOWN_UNCLASSIFIED_ROLE','unqualified scene sample must UNKNOWN'
call assert u['ROLE']='X','unqualified role cannot be L'
call assert datatype(u['HEIGHT_M'],'N'),'height remains available without classification'
call assert u['FRAME_QUALIFICATION']='NOT_SURVEYED','scene model unqualified'
call assert u['SCENE_TRANSFORM']='APPROX_TANGENT_TO_GDA94_MGA56','transform provenance'
invalid=s~sample('INVALID',0)
call assert invalid['STATUS']='UNKNOWN_INVALID_COORDINATE','invalid coordinate rejected'
out=s~sample(100000,100000)
call assert out['STATUS']='UNKNOWN_OUTSIDE_GRID','outside grid not treated as land'
roles=.HarbourWordsRoleEvidence~new('SYNTHETIC_TEST_MASK_ONLY')
call assert roles~roleAt(1,1)='X','missing mask cell X'
call assert roles~source='SYNTHETIC_TEST_MASK_ONLY','provenance retained'
roles~setCell(1,1,'L')
call assert roles~roleAt(1,1)='L','explicit L accepted'
roles~setCell(1,1,'W')
call assert roles~roleAt(1,1)='W','explicit W accepted'
roles~setCell(1,1,'X')
call assert roles~roleAt(1,1)='X','explicit unknown accepted'
/* Use an actual REAL DEM grid sample, classified by SYNTHETIC test mask. */
cent=s~sample(0,0)
roles~setCell(cent['COLUMN'],cent['ROW'],'L')
st=.HarbourWordsSceneTile~new(w,0.9,roles)
land=st~sample(0,0)
call assert land['STATUS']='LAND_AHD','test mask land class'
call assert land['ROLE']='L','land role explicit'
call assert land['ROLE_PROVENANCE']='SYNTHETIC_TEST_MASK_ONLY','no provenance loss'
roles~setCell(cent['COLUMN'],cent['ROW'],'W')
water=st~sample(0,0)
call assert water['STATUS']='WATER_NOT_LAND','test mask water class'
call assert water['ROLE']='W','water role explicit'
call assert water['HEIGHT_M']=land['HEIGHT_M'],'water classification does not alter height'
roles~setCell(cent['COLUMN'],cent['ROW'],'X')
blocked=st~sample(0,0)
call assert blocked['STATUS']='UNKNOWN_UNCLASSIFIED_ROLE','explicit X no clearance'
call assert blocked['ROLE']='X','unknown stays unknown'
/* Observatory Hill: published Top Rope spot 41.6 m, no role certified. */
obsx=(151.2045-151.210)*92300
obsy=(-33.8597+33.852)*111200
obs=s~sample(obsx,obsy)
call assert datatype(obs['HEIGHT_M'],'N'),'observatory elevation from real DEM'
call assert abs(obs['HEIGHT_M']-41.6)<2.0,'observatory coarse-grid within 2 m of quoted spot'
call assert obs['STATUS']='UNKNOWN_UNCLASSIFIED_ROLE','real control not automatically land'
/* Six independently named geography controls on the provided 50m words. */
places=.array~of(,
  .array~of('GOAT_ISLAND',-33.8521,151.1966,18.4),,
  .array~of('FORT_DENISON',-33.8548,151.2256,2.5),,
  .array~of('BRADLEYS_LIGHT',-33.8535,151.2467,1.3),,
  .array~of('OPERA_HOUSE',-33.8568,151.2153,3.5),,
  .array~of('HARBOUR_BRIDGE',-33.8523,151.2108,0.1),,
  .array~of('OBSERVATORY_HILL',-33.8597,151.2045,41.0))
do spot over places
  xx=(spot[3]-151.210)*92300
  yy=(spot[2]+33.852)*111200
  reading=s~sample(xx,yy)
  call assert reading['STATUS']='UNKNOWN_UNCLASSIFIED_ROLE',spot[1] 'classification unknown'
  call assert abs(reading['HEIGHT_M']-spot[4])<0.11,spot[1] 'coarse DEM height'
end
/* A real missing-data sample is distinct from land or water. */
missing=.false
/* Finding first missing grid coordinate is a search over REAL source data. */
do rr=1 to w~rows
  do cc=1 to w~columns
    e=330586.9+(cc-1)*50;n=6259261.5-(rr-1)*50
    t=w~sampleMGA(e,n)
    if t['STATUS']='UNKNOWN_NODATA' then do
      missing=.true
      leave
    end
  end
  if missing then leave
end
call assert missing,'input contains nodata evidence'
call assert t['ROLE']='UNCLASSIFIED','nodata never water'
call assert t['STATUS']='UNKNOWN_NODATA','missing height remains unknown'
say 'PASS' checks 'native Power SLAM v0.24 checks'
exit 0
assert:
  use arg truth,msg
  if \truth then do
    say 'FAIL:' msg
    exit 1
  end
  checks+=1
  return
::requires 'SlamHarbourWordsScene.cls'
