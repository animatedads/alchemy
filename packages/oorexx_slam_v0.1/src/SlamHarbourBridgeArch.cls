/* Power SLAM v0.41 — Sydney Harbour Bridge arch (provisional model solids).
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Until v0.40 the scene held the bridge DECK, the four PYLON_TOWER_PHOTO
 * solids and the two abutments, but not the arch: aircraft could fly
 * straight through the arch steel and nothing had to choose over or under.
 * This class adds the arch as oriented cuboids in the SAME scene frame,
 * deriving its axis from the existing DECK solid (the midpoints of the
 * deck's two short ends), so it stays consistent if the deck is revised.
 *
 * Model (public, rounded figures; NOT surveyed, NOT AHD-qualified, same
 * standing as the other v0.21+ bridge solids):
 *   span between bearings  503 m, centred on the deck midpoint
 *   upper chord            parabola, 134 m at the crown, 69 m at the bearings
 *   lower chord            parabola, 116 m at the crown, 12 m at the bearings
 *                          (truss depth 18 m at the crown, 57 m at the ends)
 *   two arch ribs          centre lines 15 m either side of the axis, 4 m wide
 *   28 panels              of 503/28 m; each panel is one solid per rib,
 *                          0.2 m longer than the panel so neighbours overlap
 *                          (no zero-width seam at a panel joint)
 * Solids per panel (the envelope of the panel: lowest lower chord to highest
 * upper chord over the panel, so a solid is never smaller than the profile):
 *   - where the lower chord is above the deck top (49 m) plus 3 m, the two
 *     ribs and their lateral bracing are ONE block 34 m across (no flying
 *     between the ribs inside the truss), and a pair of 1.5 m hangers drops
 *     from the panel point to the deck top in each rib plane;
 *   - near the ends, where the lower chord passes below the deck, the two
 *     ribs are separate 4 m slabs and only a 6 m top-bracing block joins
 *     them, so the road passage between the ribs stays open, as on the
 *     real bridge.
 * Open by design: the space above the deck, below the lower chord, between
 * the hanger planes — the passage traffic uses — and everything outside
 * the ribs.
 *
 * apply(scene) appends the solids to scene~boxes and returns their count.
 * It is opt-in: HarbourOcclusionPanorama~configure is unchanged in v0.41,
 * so every earlier Power SLAM qualification is untouched. Names: ARCH_Pnn
 * (truss blocks), ARCH_Pnn_W / _E (end rib slabs), ARCH_Pnn_TOP (end top
 * bracing), HANGER_Pnn_W / _E.
 */
::class HarbourBridgeArch public
::method constants class
  d=.directory~new
  d['SPAN_M']=503;d['UPPER_CROWN_M']=134;d['UPPER_END_M']=69
  d['LOWER_CROWN_M']=116;d['LOWER_END_M']=12;d['RIB_OFFSET_M']=15
  d['RIB_WIDTH_M']=4;d['PANELS']=28;d['DECK_TOP_M']=49;d['HANGER_M']=1.5
  d['TOP_BRACING_M']=6
  return d
::method axis class
  /* Deck centreline from the DECK solid: returns centre x,y and unit u. */
  use strict arg scene
  numeric digits 16
  deck=.nil
  do b over scene~boxes
    if b[1]=='DECK' then deck=b
  end
  if deck==.nil then raise syntax 88.900 array('scene has no DECK solid to carry the arch')
  v=deck[2]
  s=.array~of((v[1][1]+v[2][1])/2,(v[1][2]+v[2][2])/2)
  n=.array~of((v[3][1]+v[4][1])/2,(v[3][2]+v[4][2])/2)
  dx=n[1]-s[1];dy=n[2]-s[2];len=RxCalcSqrt(dx*dx+dy*dy,16)
  d=.directory~new
  d['CX']=(s[1]+n[1])/2;d['CY']=(s[2]+n[2])/2;d['UX']=dx/len;d['UY']=dy/len;d['DECK_LENGTH_M']=len
  return d
::method upper class
  use strict arg s
  c=self~constants;half=c['SPAN_M']/2
  return c['UPPER_CROWN_M']-(c['UPPER_CROWN_M']-c['UPPER_END_M'])*(s/half)**2
::method lower class
  use strict arg s
  c=self~constants;half=c['SPAN_M']/2
  return c['LOWER_CROWN_M']-(c['LOWER_CROWN_M']-c['LOWER_END_M'])*(s/half)**2
::method apply class
  use strict arg scene
  numeric digits 16
  c=self~constants;a=self~axis(scene)
  ux=a['UX'];uy=a['UY'];vx=0-uy;vy=ux
  half=c['SPAN_M']/2;panel=c['SPAN_M']/c['PANELS'];off=c['RIB_OFFSET_M'];w=c['RIB_WIDTH_M']
  deckTop=c['DECK_TOP_M'];added=0
  do k=1 to c['PANELS']
    s0=-half+(k-1)*panel;s1=s0+panel;sm=(s0+s1)/2
    /* envelope over the panel: the parabolas are monotone on each half */
    lo=min(self~lower(s0),self~lower(s1));hi=max(self~upper(s0),self~upper(s1))
    if s0<0 & s1>0 then hi=c['UPPER_CROWN_M']
    upLo=min(self~upper(s0),self~upper(s1))
    px=a['CX']+sm*ux;py=a['CY']+sm*uy
    tag='ARCH_P'right(k,2,'0')
    if lo>deckTop+3 then do
      scene~boxes~append(scene~cuboid(tag,px,py,lo,panel+0.2,2*off+w,hi-lo,ux,uy,vx,vy));added+=1
    end
    else do
      do side over .array~of(-1,1)
        nm=tag||'_'||word('W E',(side+3)/2)
        scene~boxes~append(scene~cuboid(nm,px+side*off*vx,py+side*off*vy,lo,panel+0.2,w,hi-lo,ux,uy,vx,vy));added+=1
      end
      tb=c['TOP_BRACING_M']
      scene~boxes~append(scene~cuboid(tag'_TOP',px,py,upLo-tb,panel+0.2,2*off+w,hi-(upLo-tb),ux,uy,vx,vy));added+=1
    end
  end
  /* Hangers at interior panel points where the lower chord clears the deck. */
  do k=1 to c['PANELS']-1
    s=-half+k*panel;z=self~lower(s)
    if z<=deckTop+3 then iterate
    do side over .array~of(-1,1)
      nm='HANGER_P'right(k,2,'0')'_'word('W E',(side+3)/2)
      hx=a['CX']+s*ux+side*off*vx;hy=a['CY']+s*uy+side*off*vy
      scene~boxes~append(scene~cuboid(nm,hx,hy,deckTop,c['HANGER_M'],c['HANGER_M'],z-deckTop,ux,uy,vx,vy));added+=1
    end
  end
  return added
::requires 'rxmath' LIBRARY
