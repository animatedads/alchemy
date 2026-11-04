/* Sydney Harbour bare-ground heights. Read-only ELVIS derived-word provider.
 * Architecture: Tom Dyer. Input words: Claude (Opus 5.5), 2026-11-02.
 * Native adapter: ChatGPT GPT-6. Does NOT replace Top Rope SLAM height_map.
 * No visual x4 height scale, DEM-only water assertion, or vessel positioning.
 */
::class HarbourHeightWords public
::attribute rows get
::attribute filePath get
::attribute sourceStatus get
::attribute width get
::attribute height get
::attribute east0 get
::attribute north0 get
::attribute cellSize get
::attribute missingCount get
::attribute placeCount get

::method init
  expose rows filePath sourceStatus width height east0 north0 cellSize missingCount placeCount
  use strict arg path
  filePath=path
  sourceStatus='ELVIS_DERIVED_WORDS_NOT_INDEPENDENT_SURVEY'
  width=0; height=0; east0=0; north0=0; cellSize=0
  missingCount=0; placeCount=0
  rows=.array~new
  if stream(path,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('height words file missing')
  call stream path,'C','OPEN READ'
  haveHeader=.false;haveGrid=.false;closed=.false
  do while lines(path)>0
    line=strip(linein(path))
    if line=='' | left(line,2)=='--' then iterate
    if closed then raise syntax 88.900 array('non-comment text after end')
    key=word(line,1)
    select
      when key=='height' then do
        if line\=='height map sydney harbour' | haveHeader then raise syntax 88.900 array('invalid height map title')
        haveHeader=.true
      end
      when key=='grid' then do
        if \haveHeader | haveGrid | words(line)<>13 then raise syntax 88.900 array('bad grid header')
        if word(line,2)\=='mga' | word(line,3)\=='56' | word(line,4)\=='top' | word(line,5)\=='left' | word(line,8)\=='step' | word(line,10)\=='across' | word(line,12)\=='down' then raise syntax 88.900 array('unsupported grid projection')
        east0=word(line,6);north0=word(line,7);cellSize=word(line,9)
        width=word(line,11);height=word(line,13)
        if \datatype(east0,'N') | \datatype(north0,'N') | \datatype(cellSize,'N') | \datatype(width,'W') | \datatype(height,'W') then raise syntax 88.900 array('invalid grid numeric fields')
        if width<>226 | height<>204 | cellSize<>50 then raise syntax 88.900 array('unexpected grid extent/resolution')
        haveGrid=.true
      end
      when key=='place' then do
        if \haveGrid | rows~items>0 then raise syntax 88.900 array('place outside metadata block')
        if pos(' height ',line)=0 | pos(' at ',line)=0 then raise syntax 88.900 array('invalid place metadata')
        placeCount=placeCount+1
      end
      when key=='row' then do
        if \haveGrid | rows~items>=height then raise syntax 88.900 array('unexpected row')
        if words(line)<>width+1 then raise syntax 88.900 array('row width differs from grid width')
        rowText=subword(line,2)
        do col=1 to width
          h=word(rowText,col)
          if h=='-' then missingCount=missingCount+1
          else if \datatype(h,'N') then raise syntax 88.900 array('non-numeric height word')
        end
        rows~append(rowText)
      end
      when key=='end' then do
        if line\=='end' | \haveGrid | rows~items<>height then raise syntax 88.900 array('incomplete or invalid end marker')
        closed=.true
      end
      otherwise raise syntax 88.900 array('unrecognised height word statement: 'key)
    end
  end
  call stream path,'C','CLOSE'
  if \closed | \haveGrid | rows~items<>height then raise syntax 88.900 array('height map truncated')

::method queryXY
  expose rows width height east0 north0 cellSize filePath
  use strict arg east,north,mapWaterPositive=.false
  if \datatype(east,'N') | \datatype(north,'N') then raise syntax 88.900 array('MGA56 coordinate must be numeric')
  if mapWaterPositive\==.true & mapWaterPositive\==.false then raise syntax 88.900 array('map evidence must be explicit boolean')
  obs=.directory~new
  obs['SOURCE']='ELVIS_WORDS_USER_SUPPLIED_NO_UPSTREAM_ASC_HASH'
  obs['HORIZONTAL_CRS']='GDA94_MGA_ZONE_56'
  obs['VERTICAL_DATUM']='AHD71_DECLARED_BY_WORDS_HEADER'
  obs['SPACING_METRES']=cellSize
  obs['EVIDENCE_STATE']='OBSERVED_UNTESTED'
  obs['STRUCTURE_LAYER']='NOT_PRESENT_IN_DEM'
  obs['GEOMETRY']='BARE_GROUND_GRID_ONLY'
  obs['METRIC_VERTICAL_EXAGGERATION']=1
  obs['QUERY_EASTING']=east;obs['QUERY_NORTHING']=north
  obs['MAP_WATER_WITNESS']=mapWaterPositive
  obs['WATER']='UNKNOWN'
  obs['HEIGHT_STATUS']='OUTSIDE_COVERAGE'
  obs['HEIGHT_AHD_METRES']='UNAVAILABLE'
  obs['INTERPOLATION']='NEAREST_GRID_WORD_NOT_SURVEYED'
  if mapWaterPositive then obs['WATER']='WATER_FROM_EXTERNAL_POSITIVE_MAP_WITNESS'
  if east<east0 | east>east0+(width-1)*cellSize | north>north0 | north<north0-(height-1)*cellSize then return obs
  col=trunc((east-east0)/cellSize+0.5)+1
  row=trunc((north0-north)/cellSize+0.5)+1
  if col<1 | col>width | row<1 | row>height then return obs
  obs['ROW_1_BASED']=row;obs['COLUMN_1_BASED']=col
  obs['SAMPLE_EASTING']=east0+(col-1)*cellSize
  obs['SAMPLE_NORTHING']=north0-(row-1)*cellSize
  v=word(rows[row],col)
  if v=='-' then do
    obs['HEIGHT_STATUS']='NO_DATA'
    return obs
  end
  obs['HEIGHT_STATUS']='HEIGHT_WORD_AVAILABLE'
  obs['HEIGHT_AHD_METRES']=v
  /* Elevation below 1m is an advisory only, never automatically WATER. */
  if \mapWaterPositive & v<1 then obs['WATER']='LOW_ELEVATION_CANDIDATE_UNCONFIRMED'
  return obs

::method provenance
  expose filePath width height east0 north0 cellSize missingCount placeCount
  d=.directory~new
  d['FILE']=filePath;d['CRS']='GDA94_MGA_ZONE_56';d['DATUM']='AHD71_REPORTED'
  d['WIDTH']=width;d['HEIGHT']=height;d['CELLS']=width*height
  d['SPACING_METRES']=cellSize;d['TOP_LEFT_E']=east0;d['TOP_LEFT_N']=north0
  d['MISSING_SAMPLES']=missingCount;d['PLACES']=placeCount
  d['UPSTREAM_ASC_HASH']='NOT_PROVIDED'
  d['VERTICAL_ACCURACY']='REPORTED_PLUS_MINUS_0.9M_AT_95_PERCENT_NOT_INDEPENDENTLY_CHECKED'
  return d
