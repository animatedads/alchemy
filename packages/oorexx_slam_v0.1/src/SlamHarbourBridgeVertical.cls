/* Power SLAM Harbour v0.18 — bridge deck/abutment/pylon vertical continuity.
 * Architecture: Tom Dyer; implementation: ChatGPT GPT-6.
 * Only used after HarbourBridgeRoofPins~apply and successful pin qualification.
 * Distinguishes the two below-deck abutment towers from four above-deck pylons.
 * Source: NSW Bridge Conservation Management Plan: pylons begin at deck level;
 * abutments support the deck below. NSW government: road deck ~49m above water,
 * masonry pylon top 89m ASL. Local z in provisional approximate ASL metres,
 * NOT an AHD geodetic certification or roof survey.
 */
::requires 'SlamHarbourRoofPins.cls'
::class HarbourBridgeVertical public
::method levels class
  d=.directory~new
  d['BASE_APPROX_M']=5.5
  d['DECK_BOTTOM_APPROX_M']=46
  d['DECK_SURFACE_APPROX_M']=49
  d['PYLON_TOP_M']=89
  d['ABUTMENT_ACROSS_APPROX_M']=58
  d['ABUTMENT_ALONG_APPROX_M']=49
  d['DECK_WIDTH_M']=49
  d['PYLON_ALONG_APPROX_M']=19
  d['PYLON_ACROSS_APPROX_M']=11
  return d
::method apply class
  use strict arg scene
  props=self~levels
  roof=.HarbourBridgeRoofPins~frame(scene)
  if roof['STATUS']\=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED' then raise syntax 88.900 array('unqualified bridge roof pin geometry')
  feats=scene~features
  do id over .array~of('NW','NE','SW','SE')
    if \feats~hasIndex(id||'_ROOF_PIN') then raise syntax 88.900 array('apply roof-pin geometry first')
  end
  lower=props['BASE_APPROX_M'];road=props['DECK_SURFACE_APPROX_M']
  bottom=props['DECK_BOTTOM_APPROX_M'];top=props['PYLON_TOP_M']
  if lower>=bottom | bottom>=road | road>=top then raise syntax 88.900 array('invalid elevation ordering')
  old=scene~boxes
  revised=.array~new
  do b over old
    if b[1]=='DECK' | b[1]=='PYLON_TOWER_PHOTO' | b[1]=='ABUTMENT_S' | b[1]=='ABUTMENT_N' then iterate
    revised~append(b)
  end
  ux=roof['UX'];uy=roof['UY'];vx=roof['VX'];vy=roof['VY']
  /* Each masonry abutment is continuous from local ground up to the deck.
   * The exact foundations are not surveyed. Never infer a ferry coordinate
   * or a true camera height from these approximate lower solids. */
  s=roof['S_MID'];n=roof['N_MID']
  revised~append(scene~cuboid('ABUTMENT_S',s[1],s[2],lower,props['ABUTMENT_ALONG_APPROX_M'],props['ABUTMENT_ACROSS_APPROX_M'],road-lower,ux,uy,vx,vy))
  revised~append(scene~cuboid('ABUTMENT_N',n[1],n[2],lower,props['ABUTMENT_ALONG_APPROX_M'],props['ABUTMENT_ACROSS_APPROX_M'],road-lower,ux,uy,vx,vy))
  /* The slab is continuous at z=46..49 and meets/overlaps the abutment heads.
   * Four decorative granite-faced towers rise from exactly z=49 to z=89. */
  revised~append(scene~cuboid('DECK',(s[1]+n[1])/2,(s[2]+n[2])/2,bottom,roof['AXIS_M'],props['DECK_WIDTH_M'],road-bottom,ux,uy,vx,vy))
  pts=.HarbourBridgeRoofPins~localCoordinates(scene)
  do id over .array~of('NW','NE','SW','SE')
    p=pts[id]
    revised~append(scene~cuboid('PYLON_TOWER_PHOTO',p[1],p[2],road,props['PYLON_ALONG_APPROX_M'],props['PYLON_ACROSS_APPROX_M'],top-road,ux,uy,vx,vy))
    feats[id||'_DECK_PROXY']=.array~of(p[1],p[2],road)
  end
  feats['S_DECK']=.array~of(s[1],s[2],road)
  feats['N_DECK']=.array~of(n[1],n[2],road)
  feats['D']=.array~of((s[1]+n[1])/2,(s[2]+n[2])/2,road)
  feats['ABUTMENT_S_BASE']=.array~of(s[1],s[2],lower)
  feats['ABUTMENT_N_BASE']=.array~of(n[1],n[2],lower)
  feats['ABUTMENT_S_TOP']=.array~of(s[1],s[2],road)
  feats['ABUTMENT_N_TOP']=.array~of(n[1],n[2],road)
  scene~boxes=revised
  status=.directory~new
  status['STATUS']='CORRECTED_CONTINUITY_GEOMETRY_UNSURVEYED'
  status['PREVIOUS_BOXES']=old~items
  status['CORRECTED_BOXES']=revised~items
  status['DECK_SURFACE_M']=road
  status['PYLON_TOP_M']=top
  status['ABUTMENT_BASE_M']=lower
  status['ROOF_PINS']=roof['STATUS']
  return status