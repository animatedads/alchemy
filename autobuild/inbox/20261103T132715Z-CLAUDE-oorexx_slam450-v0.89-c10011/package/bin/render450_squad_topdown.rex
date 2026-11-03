/* SLAM 450 v0.89 native squad plan view (SVG). Not AI illustration.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 * Draws every aircraft's recorded track for one or more squad races side by
 * side at ONE common scale: PowerSLAM v0.40 cuboid footprints, the five
 * targets (claimed-by and tick), start, knock-outs and track ends.
 * Oracle tracks are used only after the race, for the picture.
 * usage: rexx render450_squad_topdown.rex out.svg seed prefix1 "title1" [prefix2 "title2" ...]
 */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg outFile seed rest
if outFile=='' then do;say 'usage: rexx render450_squad_topdown.rex out.svg seed prefix "title" ...';exit 2;end
races=.array~new
do while rest~strip\==''
  parse var rest pfx rest
  rest=rest~strip
  if rest~left(1)=='"' then parse var rest '"' title '"' rest
  else parse var rest title rest
  races~append(.array~of(pfx,title))
end
w=.Slam450World~new(seed,'LEGACY',.false)
ids=.array~of('A1','A4','A2','A3','A5')
colour=.directory~new;dash=.directory~new;label=.directory~new
colour['A1']='#ff7a45';dash['A1']='';label['A1']='A1 RED  SLAM quad'
colour['A4']='#ff3b6b';dash['A4']='7,5';label['A4']='H1 RED  Haiku quad'
colour['A2']='#3d8bff';dash['A2']='';label['A2']='A2 BLUE SLAM quad'
colour['A3']='#22e3d0';dash['A3']='';label['A3']='A3 BLUE SLAM fixed-wing'
colour['A5']='#a58bff';dash['A5']='7,5';label['A5']='H2 BLUE Haiku quad'
/* Load every track; common bounds across all races (+ targets). */
tracks=.directory~new
minX=1e9;maxX=-1e9;minY=1e9;maxY=-1e9
do i=1 to 5
  t=w~targets[i];minX=min(minX,t[1]);maxX=max(maxX,t[1]);minY=min(minY,t[2]);maxY=max(maxY,t[2])
end
do r=1 to races~items
  pfx=races[r][1]
  do id over ids
    f=pfx||'_'||id||'_truth_ORACLE_ONLY.csv'
    pts=.array~new
    if stream(f,'C','QUERY EXISTS')\=='' then do
      call linein f
      do while lines(f)>0
        parse value linein(f) with tk ',' x ',' y ',' z ',' .
        if \datatype(x,'N') then iterate
        pts~append(.array~of(x,y,z,tk))
        minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y)
      end
      call stream f,'C','CLOSE'
    end
    tracks[r||id]=pts
  end
end
pad=25;minX-=pad;maxX+=pad;minY-=pad;maxY+=pad
panelW=760;panelH=trunc(panelW*(maxY-minY)/(maxX-minX))
sc=panelW/(maxX-minX)
gap=30;top=120;left=30
totalW=left*2+races~items*panelW+(races~items-1)*gap
totalH=top+panelH+190
call SysFileDelete outFile
call emit '<svg xmlns="http://www.w3.org/2000/svg" width="'totalW'" height="'totalH'" viewBox="0 0 'totalW totalH'">'
call emit '<rect width="'totalW'" height="'totalH'" fill="#08131e"/>'
call emit '<text x="'left'" y="48" fill="#e9f2f6" font-size="28" font-family="monospace">SLAM 450 v0.89 squad races, plan view (seed 'seed', PowerSLAM v0.40 harbour)</text>'
call emit '<text x="'left'" y="80" fill="#98b2c6" font-size="16" font-family="monospace">Recorded tracks in local metres, x=east, y=north, one common scale. RED: A1 SLAM quad + H1 Haiku 5.5. BLUE: A2 SLAM quad + A3 SLAM wing + H2 Haiku 5.5. Dashed = Haiku.</text>'
do r=1 to races~items
  ox=left+(r-1)*(panelW+gap);oy=top
  pfx=races[r][1];title=races[r][2]
  call emit '<clipPath id="panel'r'"><rect x="'ox'" y="'oy'" width="'panelW'" height="'panelH'"/></clipPath>'
  call emit '<rect x="'ox'" y="'oy'" width="'panelW'" height="'panelH'" fill="#0b1c2b" stroke="#2b4a63"/>'
  call emit '<g clip-path="url(#panel'r')">'
  call emit '<text x="'ox+12'" y="'oy+28'" fill="#e9f2f6" font-size="19" font-family="monospace">'esc(title)'</text>'
  /* Structures: cuboid footprints that intersect the panel. */
  do box over w~scene~boxes
    v=box[2];line='';inside=.false
    do ii over .array~of(1,2,4,3)
      pt=v[ii]
      if pt[1]>=minX & pt[1]<=maxX & pt[2]>=minY & pt[2]<=maxY then inside=.true
      line=line||' '||px(pt[1],ox)||','||py(pt[2],oy)
    end
    if \inside then iterate
    fill='#5b6f7c'
    if box[1]=='OPERA' then fill='#d6c8a7'
    if box[1]~left(6)=='CAHILL' | box[1]=='DECK' then fill='#ce704c'
    call emit '<polygon points="'line'" fill="'fill'" fill-opacity="0.40" stroke="'fill'" stroke-width="1"/>'
  end
  call emit '</g>'
  call emit '<g clip-path="url(#panel'r')">'
  /* Tracks. */
  do id over ids
    pts=tracks[r||id]
    if pts~items==0 then iterate
    line=''
    do p over pts;line=line||' '||px(p[1],ox)||','||py(p[2],oy);end
    d='';if dash[id]\=='' then d=' stroke-dasharray="'dash[id]'"'
    call emit '<polyline points="'line'" fill="none" stroke="'colour[id]'" stroke-width="2.4" stroke-opacity="0.92" stroke-linejoin="round"'d'/>'
    e=pts[pts~items]
    call emit '<circle cx="'px(e[1],ox)'" cy="'py(e[2],oy)'" r="5" fill="'colour[id]'" stroke="#ffffff" stroke-width="1.2"/>'
  end
  /* Start. */
  s=tracks[r||'A1'][1]
  call emit '<circle cx="'px(s[1],ox)'" cy="'py(s[2],oy)'" r="9" fill="none" stroke="#ffffff" stroke-width="2"/>'
  call emit '<text x="'px(s[1],ox)-20'" y="'py(s[2],oy)+26'" fill="#ffffff" font-size="14" font-family="monospace">START</text>'
  /* Claims. */
  claimBy=.directory~new;claimAt=.directory~new
  cf=pfx||'_claims.csv'
  if stream(cf,'C','QUERY EXISTS')\=='' then do
    call linein cf
    do while lines(cf)>0
      parse value linein(cf) with tk ',' frac ',' num ',' who ',' .
      if datatype(num,'W') then do;claimBy[num]=who;claimAt[num]=tk;end
    end
    call stream cf,'C','CLOSE'
  end
  reds=.array~of('#610000','#890000','#b60000','#dd0000','#ff2323')
  do i=1 to 5
    t=w~targets[i];xx=px(t[1],ox);yy=py(t[2],oy)
    call emit '<rect x="'xx-8'" y="'yy-8'" width="16" height="16" fill="'reds[i]'" stroke="#ffe9e4" stroke-width="1.3"/>'
    txt='T'i' z='format(t[3],,0)'m'
    if claimBy~hasIndex(i) then do
      txt=txt' '||shortName(claimBy[i])||' @'claimAt[i]
      call emit '<circle cx="'xx'" cy="'yy'" r="13" fill="none" stroke="'colour[claimBy[i]]'" stroke-width="3"/>'
    end
    else txt=txt' unclaimed'
    if xx>ox+panelW-230 then call emit '<text x="'xx-18'" y="'yy+5'" text-anchor="end" fill="#ffdfdb" font-size="14" font-family="monospace">'txt'</text>'
    else call emit '<text x="'xx+16'" y="'yy+5'" fill="#ffdfdb" font-size="14" font-family="monospace">'txt'</text>'
  end
  call emit '</g>'
  /* Knock-outs. */
  of=pfx||'_out_events.csv'
  if stream(of,'C','QUERY EXISTS')\=='' then do
    do while lines(of)>0
      parse value linein(of) with tk ',' who ',' tm ',' why
      pts=tracks[r||who]
      if pts~items>0 then do
        e=pts[pts~items];xx=px(e[1],ox);yy=py(e[2],oy)
        call emit '<path d="M 'xx-7 yy-7' L 'xx+7 yy+7' M 'xx+7 yy-7' L 'xx-7 yy+7'" stroke="#ffffff" stroke-width="3"/>'
      end
    end
    call stream of,'C','CLOSE'
  end
end
/* Legend + scale bar + north. */
ly=top+panelH+40
do k=1 to ids~items
  id=ids[k];lx=left+(k-1)*300
  d='';if dash[id]\=='' then d=' stroke-dasharray="'dash[id]'"'
  call emit '<line x1="'lx'" y1="'ly'" x2="'lx+40'" y2="'ly'" stroke="'colour[id]'" stroke-width="4"'d'/>'
  call emit '<text x="'lx+50'" y="'ly+5'" fill="#e9f2f6" font-size="15" font-family="monospace">'label[id]'</text>'
end
bar=trunc(50*sc)
call emit '<line x1="'left'" y1="'ly+40'" x2="'left+bar'" y2="'ly+40'" stroke="#e3f5fa" stroke-width="3"/>'
call emit '<text x="'left+bar+10'" y="'ly+45'" fill="#e3f5fa" font-size="14" font-family="monospace">50 m</text>'
call emit '<text x="'left'" y="'ly+80'" fill="#98b2c6" font-size="14" font-family="monospace">Squares = targets (shade = number, z = height). Ring = claimed (ring colour = claimant, @tick). Dot = track end. X = knocked out. North is up.</text>'
call emit '<text x="'left'" y="'ly+104'" fill="#98b2c6" font-size="14" font-family="monospace">PowerSLAM model footprints only; not surveyed coastline. Generated natively by bin/render450_squad_topdown.rex from the race evidence.</text>'
call emit '</svg>'
call stream outFile,'C','CLOSE'
say 'SQUAD PLAN WRITTEN' outFile 'PANELS' races~items 'SCALE' format(sc,,3)'px/m'
exit 0
emit:
  parse arg text
  call lineout outFile,text
  return
px:
  use arg xx,ox
  return trunc(ox+(xx-minX)*sc)
py:
  use arg yy,oy
  return trunc(oy+(maxY-yy)*sc)
esc: procedure
  parse arg s
  return s~changestr('&','&amp;')~changestr('<','&lt;')~changestr('>','&gt;')
shortName: procedure
  parse arg id
  select
    when id=='A4' then return 'H1'
    when id=='A5' then return 'H2'
    otherwise return id
  end
::requires 'Slam450Flight.cls'
