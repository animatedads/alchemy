/* Actual-source ooRexx proof. No artificial harbour geo-position admission. */
parse arg path
if path=='' then path='/mnt/data/harbour_heights.words'
numeric digits 18
n=0
h=.HarbourHeightWords~new(path)
p=h~provenance
call test p['CELLS']=46104,'expected grid 226x204'
call test p['WIDTH']=226 & p['HEIGHT']=204,'expected shape'
call test p['SPACING_METRES']=50,'sample scale 50m not 5m'
call test p['MISSING_SAMPLES']=939,'unknown-data samples preserved'
call test p['PLACES']=6,'six source-landmark metadata records'
call test p['DATUM']='AHD71_REPORTED','source vertical datum'
call test p['UPSTREAM_ASC_HASH']='NOT_PROVIDED','upstream raw DEM SHA not known'
base=h~queryXY(330586.9,6259261.5)
call test base['HEIGHT_AHD_METRES']=68.8,'first real data cell'
call test base['ROW_1_BASED']=1 & base['COLUMN_1_BASED']=1,'grid top-left indices'
call test base['WATER']='UNKNOWN','dryness not inferred from elevation'
bridge=h~queryXY(334475.5,6252780.5)
call test bridge['HEIGHT_AHD_METRES']=0.1,'bridge under-deck ground sample near 0.1m'
call test bridge['GEOMETRY']='BARE_GROUND_GRID_ONLY','bridge deck not inferred from DEM'
call test bridge['STRUCTURE_LAYER']='NOT_PRESENT_IN_DEM','bridge structure separate'
call test bridge['WATER']='LOW_ELEVATION_CANDIDATE_UNCONFIRMED','under-1m is weak water evidence, not water fact'
fort=h~queryXY(335849.7,6252527.0)
call test fort['HEIGHT_AHD_METRES']=2.5,'Fort Denison ~2.5m anomaly retained'
call test fort['WATER']='UNKNOWN','high near-water height does not establish dry land'
fortMap=h~queryXY(335849.7,6252527.0,.true)
call test fortMap['WATER']='WATER_FROM_EXTERNAL_POSITIVE_MAP_WITNESS','positive map water may add evidence'
call test fortMap['HEIGHT_AHD_METRES']=2.5,'map layer never overwrites source height'
observatory=h~queryXY(333907,6251949.8)
call test observatory['HEIGHT_AHD_METRES']=41.0,'Observatory Hill nearest sample, not place metadata 41.6'
call test observatory['INTERPOLATION']='NEAREST_GRID_WORD_NOT_SURVEYED','no interpolated/surveyed claim'
noData=h~queryXY(330586.9+50*225,6259261.5-50*203)
call test noData['HEIGHT_STATUS']='NO_DATA','literal dash preserves unknown height'
call test noData['HEIGHT_AHD_METRES']='UNAVAILABLE','missing height not fabricated'
out=h~queryXY(330586.9-100,6259261.5)
call test out['HEIGHT_STATUS']='OUTSIDE_COVERAGE','outside grid abstains'
call test out['WATER']='UNKNOWN','outside grid is unknown not dry'
call test base['METRIC_VERTICAL_EXAGGERATION']=1,'no x4 render exaggeration in metric data'
call test base['HORIZONTAL_CRS']='GDA94_MGA_ZONE_56','GDA94/MGA56 horizontal CRS'
call test base['VERTICAL_DATUM']='AHD71_DECLARED_BY_WORDS_HEADER','AHD71 vertical datum explicit'
call test base['EVIDENCE_STATE']='OBSERVED_UNTESTED','no SLAM TESTED escalation'
call test base['SOURCE']='ELVIS_WORDS_USER_SUPPLIED_NO_UPSTREAM_ASC_HASH','source provenance unknown upstream SHA'
say 'HARBOUR_HEIGHT_WORDS_NATIVE_PASS checks='n 'rows='p['HEIGHT'] 'cols='p['WIDTH'] 'missing='p['MISSING_SAMPLES']
exit 0
test: procedure expose n
 use arg passed,label
 if \passed then do
  say 'HEIGHT_TEST_FAIL:' label
  exit 3
 end
 n=n+1
 return
::requires 'HarbourHeightWords.cls'
