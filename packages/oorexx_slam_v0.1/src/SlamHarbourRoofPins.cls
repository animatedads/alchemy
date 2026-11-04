/* Power SLAM v0.12. Architecture Tom Dyer. Implemented ChatGPT GPT-6.
 * Four Google Earth pins dropped visibly inside the four masonry pylon ROOFS.
 * User evidence screenshots: 1000066729..6732.jpg, 2026-11-01.
 * Pin coordinates are a non-surveyed ROOF-INTERIOR control, not exact roof
 * centroids, bounds, surveyed coordinates, or GPS photo-taking positions.
 * Tangent-plane conversion is the established HarbourScene approximation.
 */
::requires 'SlamHarbourBridgeSemantics.cls'
::class HarbourBridgeRoofPins public
::method coordinates class
  d=.directory~new
  d['NW']=.array~of(-33.849759,151.211889)
  d['NE']=.array~of(-33.849915,151.212276)
  d['SW']=.array~of(-33.854271,151.209068)
  d['SE']=.array~of(-33.854422,151.209463)
  return d
::method screenshot class
  use strict arg id
  select
    when id=='NW' then return '1000066729.jpg'
    when id=='NE' then return '1000066730.jpg'
    when id=='SW' then return '1000066731.jpg'
    when id=='SE' then return '1000066732.jpg'
    otherwise raise syntax 88.900 array('unknown roof pin')
  end
::method sourceClass class
  return 'GOOGLE_EARTH_USER_DROPPED_PIN_ON_VISIBLE_ROOF_NON_SURVEYED'
::method localCoordinates class
  use strict arg scene
  pins=self~coordinates
  d=.directory~new
  do id over .array~of('NW','NE','SW','SE')
    d[id]=scene~local(pins[id][1],pins[id][2])
  end
  return d
::method frame class
  use strict arg scene
  d=self~localCoordinates(scene)
  nw=d['NW'];ne=d['NE'];sw=d['SW'];se=d['SE']
  wNorth=ne[1]-nw[1];nNorth=ne[2]-nw[2]
  wSouth=se[1]-sw[1];nSouth=se[2]-sw[2]
  northCross=HSqrt(wNorth*wNorth+nNorth*nNorth)
  southCross=HSqrt(wSouth*wSouth+nSouth*nSouth)
  longW=HSqrt((nw[1]-sw[1])**2+(nw[2]-sw[2])**2)
  longE=HSqrt((ne[1]-se[1])**2+(ne[2]-se[2])**2)
  midS=.array~of((sw[1]+se[1])/2,(sw[2]+se[2])/2)
  midN=.array~of((nw[1]+ne[1])/2,(nw[2]+ne[2])/2)
  dx=midN[1]-midS[1];dy=midN[2]-midS[2]
  len=HSqrt(dx*dx+dy*dy)
  ux=dx/len;uy=dy/len
  vx=uy;vy=0-ux
  southAlong=abs(wSouth*ux+nSouth*uy)
  northAlong=abs(wNorth*ux+nNorth*uy)
  dotCross=(wSouth*wNorth+nSouth*nNorth)/(southCross*northCross)
  f=.directory~new
  f['N_CROSS_M']=northCross
  f['S_CROSS_M']=southCross
  f['W_LONG_M']=longW
  f['E_LONG_M']=longE
  f['AXIS_M']=len
  f['N_PAIR_AXIS_M']=northAlong
  f['S_PAIR_AXIS_M']=southAlong
  f['PARALLEL_DOT']=dotCross
  f['S_MID']=midS
  f['N_MID']=midN
  f['UX']=ux;f['UY']=uy;f['VX']=vx;f['VY']=vy
  f['STATUS']='REJECTED_ROOF_PIN_GEOMETRY'
  if northCross>35 & northCross<45 & southCross>35 & southCross<45 & longW>550 & longW<580 & longE>550 & longE<580 & southAlong<5 & northAlong<5 & dotCross>0.999 then f['STATUS']='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED'
  return f
::method apply class
  use strict arg scene
  f=self~frame(scene)
  if f['STATUS']\=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED' then raise syntax 88.900 array('unqualified roof pin set rejected')
  pts=self~localCoordinates(scene)
  feature=scene~features
  do id over .array~of('NW','NE','SW','SE')
    p=pts[id]
    feature[id]=.array~of(p[1],p[2],89)
    feature[id||'_ROOF_PIN']=.array~of(p[1],p[2],89)
    feature[id||'_DECK_PROXY']=.array~of(p[1],p[2],50)
  end
  s=f['S_MID'];n=f['N_MID']
  feature['S']=.array~of(s[1],s[2],89)
  feature['N']=.array~of(n[1],n[2],89)
  feature['S_TOP']=feature['S']
  feature['N_TOP']=feature['N']
  feature['S_DECK']=.array~of(s[1],s[2],50)
  feature['N_DECK']=.array~of(n[1],n[2],50)
  feature['D']=.array~of((s[1]+n[1])/2,(s[2]+n[2])/2,50)
  feature['ARCH_CROWN']=.array~of(feature['D'][1],feature['D'][2],134)
  revised=.array~new
  do box over scene~boxes
    if box[1]=='PYLON' | box[1]=='DECK' | box[1]=='PYLON_TOWER_PHOTO' then iterate
    revised~append(box)
  end
  /* Roof envelopes 19x11m are ILLUSTRATIVE, not georeferenced roof corners.
     Towers start at approx deck elevation, per conservation semantics.
     Never project these invented envelope corners as surveyed landmarks. */
  do id over .array~of('NW','NE','SW','SE')
    p=pts[id]
    revised~append(scene~cuboid('PYLON_TOWER_PHOTO',p[1],p[2],50,19,11,39,f['UX'],f['UY'],f['VX'],f['VY']))
  end
  revised~append(scene~cuboid('DECK',feature['D'][1],feature['D'][2],48,f['AXIS_M'],49,4,f['UX'],f['UY'],f['VX'],f['VY']))
  scene~boxes=revised
  return f
::method cameraAdmission class
  /* Pin interior is NOT a survey of masonry apex, but sufficient for a
     labelled provisional camera test if image correspondences are qualified. */
  return 'PROVISIONAL_PHOTO_FIT_ONLY_ROOF_PIN_SEMANTICS'
::method documentation class
  return 'Four direct user map roof pins 2026-11-01. XY reproducible, roof-corner 19x11m and Z=50..89 envelopes provisional. NEVER claim surveyed roof corners.'