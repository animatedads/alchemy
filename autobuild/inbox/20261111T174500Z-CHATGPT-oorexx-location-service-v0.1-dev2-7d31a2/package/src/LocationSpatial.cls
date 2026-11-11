/* Alchemy Location Spatial v0.1-dev2. Architecture: Tom Dyer; code: ChatGPT GPT-6.
   Explicit coordinate systems and temporally valid, overlapping jurisdictions.
   Fixtures are synthetic: this code is not a national boundary database. */
::class LocationReference public
::method init
  expose kind raw crs precision
  use arg kind,raw,crs,precision
  if crs == '' then raise syntax 40.1 array ('CRS is required')
::attribute kind get
::attribute raw get
::attribute crs get
::attribute precision get

::class LocationRect public
::method init
  expose crs west south east north
  use arg crs,west,south,east,north
  if crs == '' | \datatype(west,'N') | \datatype(south,'N') | \datatype(east,'N') | \datatype(north,'N') then raise syntax 40.1 array ('invalid rectangle')
  if west > east | south > north then raise syntax 40.1 array ('inverted rectangle')
::attribute crs get
::method includes
  expose west south east north
  use arg crs,x,y
  if crs \== self~crs then return 'UNSUPPORTED_CRS'
  return (x >= west & x <= east & y >= south & y <= north)

::class LocationJurisdiction public
::method init
  expose id region fromDate toDate provider hash operator
  use arg id,region,fromDate,toDate,provider,hash,operator
::attribute id get
::attribute provider get
::attribute hash get
::attribute operator get
::method eligible
  expose fromDate toDate
  use arg time
  if time == '' then return .false
  if fromDate \== '' & time < fromDate then return .false
  if toDate \== '' & time >= toDate then return .false
  return .true
::method includes
  expose region
  use arg crs,x,y
  return region~includes(crs,x,y)

::class LocationQuery public
::method init
  expose status matches providers
  use arg status
  matches=.array~new
  providers=.array~new
::attribute status get
::attribute matches get
  expose matches
  return matches~copy
::attribute providers get
  expose providers
  return providers~copy
::method record
  expose matches providers status
  use arg jurisdiction
  matches~append(jurisdiction)
  providers~append(jurisdiction~provider || ':' || jurisdiction~hash)
  status='FOUND'

::class LocationJurisdictionIndex public
::method init
  expose zones
  zones=.array~new
::method add
  expose zones
  use arg zone
  zones~append(zone)
::method at
  expose zones
  use arg crs,x,y,time
  if time == '' then return .LocationQuery~new('UNKNOWN_TIME')
  if crs == '' then return .LocationQuery~new('UNSUPPORTED_CRS')
  answer=.LocationQuery~new('NOT_FOUND')
  do i=1 to zones~items
    z=zones[i]
    if z~eligible(time) \== .true then iterate
    hit=z~includes(crs,x,y)
    if hit == 'UNSUPPORTED_CRS' then return .LocationQuery~new('UNSUPPORTED_CRS')
    if hit == .true then answer~record(z)
  end
  return answer
