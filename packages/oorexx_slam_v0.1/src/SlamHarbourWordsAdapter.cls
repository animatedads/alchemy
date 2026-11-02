/* Power SLAM real-height intake v0.23.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6.
 * Input: Claude Opus 5.5's harbour_heights.words, GDA94/MGA56, AHD71.
 * Preserves bare-earth values; never invents water from low elevations.
 */
::class HarbourWordsMGA public
::attribute crs get
::attribute datum get
::attribute source get
::attribute columns get
::attribute rows get
::attribute resolution get
::method init
  expose crs datum source columns rows resolution originE originN grid
  use strict arg filename
  crs='GDA94_MGA_ZONE_56'; datum='AHD71';source=filename
  columns=0;rows=0;resolution=0;originE=0;originN=0
  grid=.array~new
  found=.false
  do while lines(filename)>0
    line=linein(filename)~strip
    if line~left(9)=='grid mga ' then do
      parse var line 'grid mga' zone 'top left' originE originN 'step' resolution 'across' columns 'down' rows
      if zone\=56 | \datatype(originE,'N') | \datatype(originN,'N') | ,
        \datatype(resolution,'N') | \datatype(columns,'W') | \datatype(rows,'W') then ,
        raise syntax 88.900 array('invalid MGA grid declaration')
      if resolution<=0 | columns<2 | rows<2 then raise syntax 88.900 array('invalid MGA grid dimensions')
      found=.true
    end
    else if line~left(4)=='row ' then do
      if \found then raise syntax 88.900 array('row before georeference')
      vals=line~substr(5)
      if vals~words\=columns then raise syntax 88.900 array('incomplete height row')
      a=.array~new
      do j=1 to columns
        v=vals~word(j)
        if v\='-' & \datatype(v,'N') then raise syntax 88.900 array('invalid elevation word')
        a~append(v)
      end
      grid~append(a)
    end
  end
  call stream filename,'C','CLOSE'
  if \found | grid~items\=rows then raise syntax 88.900 array('missing or incomplete MGA height grid')
::method sampleMGA
  expose originE originN resolution columns rows grid source
  use strict arg easting,northing
  d=.directory~new
  d['STATUS']='UNKNOWN_OUTSIDE_GRID';d['HEIGHT_M']='UNKNOWN'
  d['ROLE']='UNCLASSIFIED';d['PROVENANCE']=source
  if \datatype(easting,'N') | \datatype(northing,'N') then do
    d['STATUS']='UNKNOWN_INVALID_COORDINATE'; return d
  end
  col=trunc((easting-originE)/resolution+0.5)+1
  row=trunc((originN-northing)/resolution+0.5)+1
  if easting<originE-resolution/2 | northing>originN+resolution/2 then return d
  if col<1 | col>columns | row<1 | row>rows then return d
  v=grid[row][col]
  if v='-' then do
    d['STATUS']='UNKNOWN_NODATA'; return d
  end
  d['STATUS']='HEIGHT_AHD71';d['HEIGHT_M']=v+0
  return d
::method sample
  /* Coordinates are MGA56 eastings/northings, NOT SLAM_LOCAL_ENU. */
  use strict arg easting,northing
  return self~sampleMGA(easting,northing)
::method sampleLocal
  /* An explicitly supplied local origin is required. No assumed origin. */
  use strict arg eastLocal,northLocal,originE,originN
  if \datatype(originE,'N') | \datatype(originN,'N') then ,
      raise syntax 88.900 array('unresolved local origin MGA')
  return self~sampleMGA(originE+eastLocal,originN+northLocal)
