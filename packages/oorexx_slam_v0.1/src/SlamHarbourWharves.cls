/* Power SLAM harbour v0.4 -- Circular Quay / Walsh Bay wharf primitives.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-01.
 * Coarse cuboids only. Published point coordinates are not building corners,
 * and the dimensions, axes, roof heights and synthetic anchors are hypotheses.
 * No geometry parameter silently upgrades an estimated coordinate to a survey.
 */
::requires 'SlamHarbourPanorama.cls'

::class HarbourWharfPanorama public subclass HarbourPanorama
::attribute wharves
::method init
  expose wharves
  self~init:super
  scene=self~scene
  wharves=.directory~new
  /* Sources documented in README_WHARVES.md.
   * CQ2..CQ5 are cited stop representative points, not verified pier tips.
   * CQ6 is extrapolated from the western spacing (HYPOTHESIS).
   * Length, width, elevation and direction are estimates for ALL rows.
   */
  self~addWharf('CQ2','CIRCULAR',-33.860750,151.212056,90,16,8,'PUBLISHED_POINT','Wikipedia: List of Sydney Ferries wharves')
  self~addWharf('CQ3','CIRCULAR',-33.860667,151.211500,90,16,8,'PUBLISHED_POINT','Wikipedia: List of Sydney Ferries wharves')
  self~addWharf('CQ4','CIRCULAR',-33.860639,151.211000,90,16,8,'PUBLISHED_POINT','Wikipedia: List of Sydney Ferries wharves')
  self~addWharf('CQ5','CIRCULAR',-33.860583,151.210500,90,16,8,'PUBLISHED_POINT','Wikipedia: List of Sydney Ferries wharves')
  self~addWharf('CQ6','CIRCULAR',-33.860545,151.209970,90,16,8,'HYPOTHESIS','westward extrapolation: not independently surveyed')
  /* Walsh piers are long finger wharves, NW of Hickson Road.
   * WB23 point: nearby Sydney Theatre Walk monument, not a pier-centre survey.
   * WB45 point: Dictionary of Sydney Wharf structure, not a roof survey.
   * WB67, WB89 are estimated for this demonstrator. WB89 mapped building
   * at -33.85656,151.20338 is used as a provenance clue, not a tip point.
   */
  self~addWharf('WB23','WALSH',-33.854895,151.207063,165,24,13,'NEARBY_POINT','Monument Australia: Sydney Theatre Walk (approx GPS)')
  self~addWharf('WB45','WALSH',-33.855177,151.205810,175,25,13,'PUBLISHED_POINT','Dictionary of Sydney: The Wharf')
  self~addWharf('WB67','WALSH',-33.855620,151.204600,175,26,15,'HYPOTHESIS','not independently located: between WB45 and WB89')
  self~addWharf('WB89','WALSH',-33.856130,151.203220,175,25,14,'HYPOTHESIS','estimated using Pier 8/9 Delivery Office and wharf precinct anchors')

/* ID, group, representative lat/lon, length/width in metres, roof height ASL,
 * anchor provenance, source. Two boxes each: a deck and a roofed shed.
 * Ledger includes measured-vs-estimated status for downstream admission.
 */
::method addWharf
  expose wharves
  scene=self~scene
  use strict arg id,group,lat,lon,length,width,roof,status,source
  if wharves~hasIndex(id) then raise syntax 88.900 array('duplicate wharf ID')
  if group\=='CIRCULAR' & group\=='WALSH' then raise syntax 88.900 array('unknown wharf group')
  if length<=0 | width<=0 | roof<=3 then raise syntax 88.900 array('invalid wharf dimensions')
  if status\=='PUBLISHED_POINT' & status\=='NEARBY_POINT' & status\=='HYPOTHESIS' then raise syntax 88.900 array('unknown provenance class')
  ctr=scene~local(lat,lon)
  /* Along axis: north for Circular Quay; NNW for Walsh Bay. Both assumed. */
  if group=='CIRCULAR' then do
    ux=0;uy=1
    vx=1;vy=0
  end
  else do
    ux=-0.37;uy=0.929
    vx=0.929;vy=0.37
  end
  /* Deck top 2.2 metres ASL, roofed box z=3 to roof, not independent roof
   * surveys. Geometry intentionally NOT used as certified water-level mask. */
  scene~boxes~append(scene~cuboid(id||'_DECK',ctr[1],ctr[2],1.2,length,width,1.0,ux,uy,vx,vy))
  scene~boxes~append(scene~cuboid(id||'_ROOF',ctr[1],ctr[2],3.0,length-8,width-3,roof-3.0,ux,uy,vx,vy))
  scene~features[id]=.array~of(ctr[1],ctr[2],roof)
  ledger=.directory~new
  ledger['ID']=id;ledger['GROUP']=group
  ledger['LAT']=lat;ledger['LON']=lon
  ledger['LENGTH']=length;ledger['WIDTH']=width;ledger['ROOF']=roof
  ledger['STATUS']=status;ledger['SOURCE']=source
  ledger['SURVEYED_FOOTPRINT']=.false
  ledger['SURVEYED_ROOF']=.false
  wharves[id]=ledger
::method getWharf
  expose wharves
  use strict arg id
  if \wharves~hasIndex(id) then raise syntax 88.900 array('unknown wharf ID')
  return wharves[id]
::method bearingOf
  scene=self~scene
  use strict arg id,site
  v=self~getWharf(id)
  return self~pointAngles(scene~features[id],self~siteCamera(site))[1]

