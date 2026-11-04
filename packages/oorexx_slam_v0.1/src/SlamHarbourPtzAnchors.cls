/* New eastern fixed geographic anchors for Power SLAM PTZ.
 * Geographic point is not a photographed pixel or surveyed building roof.
 * Do not project address-only structures as resolved 3D coordinates.
 * Architecture Tom Dyer. Implementation ChatGPT GPT-6.
 */
::class HarbourPtzAnchors public
::method catalogue class
  a=.array~new
  a~append(self~entry('BRADLEYS_HEAD_LIGHT','MOSMAN_LIGHTHOUSE',-33.853487,151.246664,'NSW_HERITAGE_POINT','https://apps.environment.nsw.gov.au/dpcheritageapp/ViewHeritageItemDetails.aspx?ID=5051364'))
  a~append(self~entry('SOUTH_MOSMAN_WHARF','MOSMAN_WHARF',-33.8433,151.2326,'PUBLISHED_WHARF_LOCATION_APPROX','https://en.wikipedia.org/wiki/South_Mosman_ferry_wharf'))
  a~append(self~entry('ROBERTSONS_POINT_LIGHT','CREMORNE_POINT_LIGHT',-33.8487833,151.2330139,'PUBLISHED_LIGHT_LOCATION','https://en.wikipedia.org/wiki/Robertson_Point_Light'))
  a~append(self~entry('CAPTAIN_COOK_GRAVING_DOCK','GARDEN_ISLAND_NAVAL_DOCK',-33.866406787364,151.22709774936,'HISTORIC_STRUCTURE_POINT','https://dictionaryofsydney.org/structure/captain_cook_dock'))
  a~append(self~entry('GARDEN_ISLAND_NAVAL_PRECINCT','GARDEN_ISLAND_AREA',-33.8654,151.2265,'PRECINCT_REFERENCE_NOT_DOCK_CENTRE','https://www.navy.gov.au/about-navy/bases-and-locations/fleet-base-east'))
  a~append(self~addressOnly('CLIFFORD_RESIDENCES','MOSMAN_BUILDING','1 Musgrave Street, Mosman NSW 2088','https://www.raywhite.com/nsw/mosman/2405870'))
  a~append(self~addressOnly('MOSMAN_ROWERS','MOSMAN_BUILDING','3 Centenary Drive, Mosman NSW 2088','https://www.mosmanrowers.com.au/contact-us'))
  return a
::method entry class private
  use strict arg id,kind,lat,lon,qual,source
  d=.directory~new
  d['ID']=id;d['KIND']=kind;d['LAT']=lat;d['LON']=lon
  d['PROVENANCE']=qual;d['SOURCE']=source
  d['ROOF_ELEVATION']='UNKNOWN'
  d['PHOTO_ASSOCIATION']='UNVERIFIED'
  d['GEOGRAPHIC_POINT_STATUS']='REFERENCE_POINT_ONLY'
  return d
::method addressOnly class private
  use strict arg id,kind,address,source
  d=.directory~new
  d['ID']=id;d['KIND']=kind;d['LAT']='UNKNOWN';d['LON']='UNKNOWN'
  d['ADDRESS']=address;d['PROVENANCE']='ADDRESS_ONLY'
  d['SOURCE']=source;d['ROOF_ELEVATION']='UNKNOWN'
  d['PHOTO_ASSOCIATION']='UNVERIFIED'
  d['GEOGRAPHIC_POINT_STATUS']='NOT_GEOREGISTERED'
  return d
::method find class
  use strict arg id
  c=self~catalogue
  do p over c
    if p['ID']=id then return p
  end
  raise syntax 88.900 array('UNKNOWN_PTZ_LANDMARK')