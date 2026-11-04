/* Power SLAM v0.41 — Harbour Bridge arch qualification.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 * Model solids, not survey: checks geometry against the stated model. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
model=.HarbourOcclusionPanorama~new
r=model~configure
scene=model~scene
before=scene~boxes~items
call assert .HarbourBridgeArch~upper(0)=134,'upper chord crown 134 m'
call assert abs(.HarbourBridgeArch~upper(251.5)-69)<1e-9,'upper chord end 69 m'
call assert .HarbourBridgeArch~lower(0)=116,'lower chord crown 116 m'
call assert abs(.HarbourBridgeArch~lower(-251.5)-12)<1e-9,'lower chord end 12 m'
a=.HarbourBridgeArch~axis(scene)
call assert abs(a['DECK_LENGTH_M']-566)<2,'axis from the DECK solid (~566 m)'
n=.HarbourBridgeArch~apply(scene)
call assert scene~boxes~items=before+n,'apply appends exactly the solids it reports'
call assert n>=40,'arch has at least 40 solids'
call assert configureUntouched(),'configure alone adds no arch (opt-in)'
cx=a['CX'];cy=a['CY'];ux=a['UX'];uy=a['UY'];vx=-uy;vy=ux
/* Crown: a vertical ray at the axis centre from 100 m up to 150 m meets the arch. */
call assert hits(scene,cx+5*ux,cy+5*uy,100,cx+5*ux,cy+5*uy,150,'ARCH'),'crown solid on the axis (5 m off the panel joint)'
/* Above 134 m at the crown: clear. */
call assert \hits(scene,cx+5*ux,cy+5*uy,136,cx+5*ux,cy+5*uy,170,''),'clear above the crown'
/* Traffic passage: on the axis above the deck, below the lower chord, mid-span: clear. */
call assert \hits(scene,cx+5*ux,cy+5*uy,55,cx+5*ux,cy+5*uy,105,''),'open passage above the deck at mid-span'
/* A flight along the axis at 80 m from 110 m south to 110 m north (lower chord >= 95 m there) of centre stays clear (between the hanger planes). */
call assert \hits(scene,cx-110*ux,cy-110*uy,80,cx+110*ux,cy+110*uy,80,''),'fly-through under the arch along the axis'
/* The same flight 15 m to the side (a hanger plane) is blocked by hangers. */
call assert hits(scene,cx-110*ux+15*vx,cy-110*uy+15*vy,80,cx+110*ux+15*vx,cy+110*uy+15*vy,80,'HANGER'),'hanger plane blocks'
/* Crossing the arch sideways at 125 m near the crown is blocked (ribs + bracing as one block). */
call assert hits(scene,cx-40*vx,cy-40*vy,125,cx+40*vx,cy+40*vy,125,'ARCH'),'cannot cross the truss near the crown'
/* Every sampled point of both true chord profiles lies inside an arch solid (envelope never smaller). */
inside=0;total=0
do i=-25 to 25
  s=i*251.5/25*0.999
  do side over .array~of(-1,1)
    do which over .array~of('upper','lower')
      if which=='upper' then z=.HarbourBridgeArch~upper(s)-0.5
      else z=.HarbourBridgeArch~lower(s)+0.5
      px=cx+s*ux+side*15*vx;py=cy+s*uy+side*15*vy
      total+=1
      if hits(scene,px,py,z-0.2,px,py,z+0.2,'ARCH') then inside+=1
    end
  end
end
call assert inside=total,'chord profiles inside the solids' inside'/'total
say 'PASS' checks 'Power SLAM v0.41 bridge arch checks ('n' solids)'
exit 0
hits: procedure
  use arg scene,x0,y0,z0,x1,y1,z1,prefix
  a=.array~of(x0,y0,z0);b=.array~of(x1,y1,z1)
  do box over scene~boxes
    if prefix\=='' then if box[1]~left(length(prefix))\==prefix then iterate
    if .HarbourRayOcclusion~hitSegment(box,a,b)>=0 then return .true
  end
  return .false
configureUntouched: procedure
  m=.HarbourOcclusionPanorama~new;r=m~configure
  do b over m~scene~boxes;if b[1]~left(4)=='ARCH' | b[1]~left(6)=='HANGER' then return .false;end
  return .true
assert:
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  checks+=1
  return
::requires 'SlamHarbourOcclusion.cls'
::requires 'SlamHarbourBridgeArch.cls'
