/* MGA Zone 56 easting and northing ONLY, not WGS84 degrees. */
parse arg file e n mapWitness
if file=='' | e=='' | n=='' then do
 say 'USAGE: rexx query_harbour_xy.rex harbour_heights.words MGA56_E MGA56_N [MAP_WATER_POSITIVE]'
 exit 2
end
positive=.false
if mapWitness\='' then do
 if mapWitness\=='MAP_WATER_POSITIVE' then do
  say 'FAIL: map witness must be MAP_WATER_POSITIVE or omitted'
  exit 3
 end
 positive=.true
end
h=.HarbourHeightWords~new(file)
o=h~queryXY(e,n,positive)
say 'SOURCE_CRS:' o['HORIZONTAL_CRS'] 'VERTICAL:' o['VERTICAL_DATUM']
say 'MGA56 E/N:' o['QUERY_EASTING'] o['QUERY_NORTHING']
say 'HEIGHT_STATUS:' o['HEIGHT_STATUS'] 'ELEVATION_AHD_METRES:' o['HEIGHT_AHD_METRES']
say 'WATER:' o['WATER'] 'STRUCTURE:' o['STRUCTURE_LAYER']
say 'SOURCE_STATE:' o['EVIDENCE_STATE'] 'CAMERA_PROJECTION: BLOCKED_UNCALIBRATED'
exit 0
::requires 'HarbourHeightWords.cls'
