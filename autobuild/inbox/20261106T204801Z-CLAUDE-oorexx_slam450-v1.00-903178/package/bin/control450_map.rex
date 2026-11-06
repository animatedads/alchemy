/* SLAM 450 v0.94: Control's map, drawn from Tombstone's ELVIS terrain.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
 * usage: rexx control450_map.rex out.svg seed
 * Needs TOMBSTONE_ELVIS (folder holding Tombstone's HarbourHeightWords.cls,
 * examples/tombstone_sydney_elvis_terrain_v0.36) on REXX_PATH and
 * SLAM450_HARBOUR_WORDS (the harbour_heights.words it reads; SHA-256
 * 3243f644... checked here before drawing).
 * Every 25 m of the map is one query to Tombstone's read-only provider
 * (queryXY, GDA94 MGA56, AHD71, nearest 50 m word, bare earth). Scene metres
 * go to MGA56 through SLAM 450's verified affine (Slam450Ground~mga,
 * residual < 1 m). Water: Tombstone itself never asserts water; Power SLAM's
 * harbour_water.words is passed as the external witness Tombstone's API
 * provides for, and the legend says so. Structures: Power SLAM scene solids
 * (footprints, the arch included). Names: the SLAM 450 places Control and
 * Boston Crab use. Static: the same picture for every seed and race; no
 * targets, no aircraft. Rasterise with rsvg-convert for Control's PNG. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg out seed .
if out=='' then do;say 'usage: rexx control450_map.rex out.svg seed';exit 2;end
if seed=='' then seed=1
words=value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT')'/harbour_heights.words'
want='3243f644556f084bf8f524b6b080f8b539fdf5986622b4b207a3a690c32a102e'
sha=.array~new
address system 'sha256sum' words with output using (sha)
got='';if sha~items>0 then got=sha[1]~word(1)
if got\==want then do;say 'FAIL: harbour_heights.words is not the ELVIS words Tombstone qualified';exit 3;end
.local['SLAM450.GROUND']='GROUND'
g=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
w=.Slam450World~new(seed,'HARBOUR',.false,g)
elvis=.HarbourHeightWords~new(words)
sit=.Slam450Situation~new(w)
/* view: the field plus the named places just outside it */
x0=-700;x1=560;y0=-1200;y1=420;s=0.5;cell=25;m=60
extra=0;if .local['SLAM450.CBD']\==.nil then extra=26
mapW=trunc((x1-x0)*s)+2*m;mapH=trunc((y1-y0)*s)+2*m+102+extra
call SysFileDelete out
call emit '<svg xmlns="http://www.w3.org/2000/svg" width="'mapW'" height="'mapH'" viewBox="0 0 'mapW mapH'">'
call emit '<rect width="'mapW'" height="'mapH'" fill="#101418"/>'
stats=.directory~new;do k over 'WATER NODATA LOW LAND OUTSIDE'~subWords;stats[k]=0;end
do y=y0 to y1-cell by cell
  do x=x0 to x1-cell by cell
    cx=x+cell/2;cy=y+cell/2
    f=g~mga(cx,cy)
    o=elvis~queryXY(f[1],f[2],(g~cellAt(cx,cy)['ROLE']=='W'))
    select
      when o['HEIGHT_STATUS']=='OUTSIDE_COVERAGE' then do;col='#202428';stats['OUTSIDE']+=1;end
      when o['WATER']~left(5)=='WATER' then do;col='#1f4d68';stats['WATER']+=1;end
      when o['HEIGHT_STATUS']=='NO_DATA' then do;col='#3a3a3a';stats['NODATA']+=1;end
      otherwise do
        h=o['HEIGHT_AHD_METRES']
        if h<1 then do;col='#7f8f7a';stats['LOW']+=1;end
        else do
          stats['LAND']+=1
          select
            when h<10 then col='#9fb488'
            when h<20 then col='#bcc189'
            when h<30 then col='#d2bd86'
            when h<40 then col='#d6a679'
            otherwise col='#c98b66'
          end
        end
      end
    end
    call emit '<rect x="'px(x)'" y="'py(y+cell)'" width="'format(cell*s,,2)'" height="'format(cell*s,,2)'" fill="'col'"/>'
  end
end
/* 100 m grid, labelled every 200 m in scene metres (E, N) */
do gx=-700 to 500 by 100
  op='0.18';if gx//200=0 then op='0.35'
  call emit '<line x1="'px(gx)'" y1="'py(y0)'" x2="'px(gx)'" y2="'py(y1)'" stroke="#ffffff" stroke-opacity="'op'" stroke-width="1"/>'
  if gx//200=0 then call emit '<text x="'px(gx)'" y="'py(y0)+14'" fill="#cfd8dc" font-size="10" font-family="monospace" text-anchor="middle">E'gx'</text>'
end
do gy=-1200 to 400 by 100
  op='0.18';if gy//200=0 then op='0.35'
  call emit '<line x1="'px(x0)'" y1="'py(gy)'" x2="'px(x1)'" y2="'py(gy)'" stroke="#ffffff" stroke-opacity="'op'" stroke-width="1"/>'
  if gy//200=0 then call emit '<text x="'px(x0)-4'" y="'py(gy)+3'" fill="#cfd8dc" font-size="10" font-family="monospace" text-anchor="end">N'gy'</text>'
end
/* Power SLAM structures (and the CBD LiDAR blocks when loaded), clipped to the map */
call emit '<clipPath id="view"><rect x="'px(x0)'" y="'py(y1)'" width="'format((x1-x0)*s,,1)'" height="'format((y1-y0)*s,,1)'"/></clipPath>'
call emit '<g clip-path="url(#view)">'
do b over w~scene~boxes
  pts=hull(b[2])
  t='';do p over pts;t=t px(p[1])','py(p[2]);end
  top=-1e9;do v over b[2];top=max(top,v[3]);end
  fill='#4b4f5c';if top>40 then fill='#2c2f3a'
  call emit '<polygon points="'t~strip'" fill="'fill'" fill-opacity="0.85" stroke="#e8e8e8" stroke-width="0.6"/>'
end
call emit '</g>'
/* the race field */
fb=w~fieldBox
call emit '<rect x="'px(fb[1])'" y="'py(fb[4])'" width="'format((fb[2]-fb[1])*s,,1)'" height="'format((fb[4]-fb[3])*s,,1)'" fill="none" stroke="#ffd54f" stroke-width="2" stroke-dasharray="8,5"/>'
call emit '<text x="'px(fb[1])+40'" y="'py(fb[4])-14'" fill="#ffd54f" font-size="11" font-family="monospace">Field (race area) E -640..260, N -1130..380, height 8-90 m</text>'
/* names */
do d over sit~places
  if d['KIND']=='target' | d['KEY']=='field' then iterate   /* the Field is the dashed box */
  lx=px(d['X']);ly=py(d['Y'])
  call emit '<circle cx="'lx'" cy="'ly'" r="4" fill="#ff5252" stroke="#ffffff" stroke-width="1"/>'
  nm=d['LABEL']
  anchor='start';tx=lx+7
  if d['X']>250 then do;anchor='end';tx=lx-7;end
  call emit '<text x="'tx'" y="'ly-6'" fill="#ffffff" stroke="#000000" stroke-width="2.5" paint-order="stroke" font-size="12" font-weight="bold" font-family="sans-serif" text-anchor="'anchor'">'nm'</text>'
end
/* north arrow, scale */
call emit '<path d="M 'mapW-40' 30 l 10 26 l -10 -7 l -10 7 z" fill="#ffffff"/>'
call emit '<text x="'mapW-40'" y="24" fill="#ffffff" font-size="13" font-family="sans-serif" text-anchor="middle">N</text>'
call emit '<line x1="'m'" y1="'mapH-112-extra'" x2="'m+100*s'" y2="'mapH-112-extra'" stroke="#ffffff" stroke-width="3"/>'
call emit '<text x="'m+100*s+6'" y="'mapH-108-extra'" fill="#ffffff" font-size="11" font-family="monospace">100 m</text>'
foot=.array~of('Terrain: Tombstone ELVIS provider v0.36; harbour_heights.words (SHA 3243f644), 50 m words from',,
  'the NSW 5 m DEM; bare earth, AHD71, nearest word. Water: Power SLAM harbour_water.words (external witness).',,
  'Structures: Power SLAM scene solids, arch included. Names: SLAM 450 places.',,
  'Land bands: &lt;10, 10-20, 20-30, 30-40, &gt;40 m.',,
  'Contains NSW Government data: DCS Spatial Services 5 m DEM via ELVIS.',,
  '(c) State of New South Wales (DCS Spatial Services), CC BY 4.0')
if .local['SLAM450.CBD']\==.nil then do
  foot~append('CBD buildings:' .local['SLAM450.CBD']~word(1) 'LiDAR blocks (Power SLAM SlamHarbourCbdBlocks, PR #137). LiDAR: NSW Government')
  foot~append('(DCCEEW Marine LiDAR, August 2018), CC BY 4.0. Towers built since 2018 are missing or part-built.')
end
do k=1 to foot~items
  call emit '<text x="'m'" y="'mapH-102-extra+k*13'" fill="#cfd8dc" font-size="10" font-family="monospace">'foot[k]'</text>'
end
call emit '</svg>'
call stream out,'C','CLOSE'
say 'CONTROL MAP' out 'cells' (stats['WATER']+stats['NODATA']+stats['LOW']+stats['LAND']+stats['OUTSIDE']) 'water' stats['WATER'] 'land' stats['LAND'] 'low' stats['LOW'] 'nodata' stats['NODATA'] 'outside' stats['OUTSIDE']
exit 0

emit: procedure expose out
  parse arg t
  call lineout out,t
  return
px: procedure expose x0 s m
  return format(m+(arg(1)-x0)*s,,1)
py: procedure expose y1 s m
  return format(m+(y1-arg(1))*s,,1)

hull: procedure
  /* xy convex hull of a cuboid's vertices (monotone chain) */
  use arg vs
  pts=.array~new
  do v over vs;pts~append(format(v[1],,3) format(v[2],,3));end
  srt=pts
  /* sort by x then y numerically (8 vertices) */
  n=srt~items
  do i=1 to n-1
    do j=i+1 to n
      if srt[j]~word(1)<srt[i]~word(1) | (srt[j]~word(1)=srt[i]~word(1) & srt[j]~word(2)<srt[i]~word(2)) then do;t=srt[i];srt[i]=srt[j];srt[j]=t;end
    end
  end
  lo=.array~new;up=.array~new
  do p over srt
    do while lo~items>=2
      if cross(lo[lo~items-1],lo[lo~items],p)>0 then leave
      lo~delete(lo~items)
    end
    lo~append(p)
  end
  do i=n to 1 by -1
    p=srt[i]
    do while up~items>=2
      if cross(up[up~items-1],up[up~items],p)>0 then leave
      up~delete(up~items)
    end
    up~append(p)
  end
  res=.array~new
  do i=1 to lo~items-1;res~append(.array~of(lo[i]~word(1),lo[i]~word(2)));end
  do i=1 to up~items-1;res~append(.array~of(up[i]~word(1),up[i]~word(2)));end
  return res
cross: procedure
  use arg a,b,c
  return (b~word(1)-a~word(1))*(c~word(2)-a~word(2))-(b~word(2)-a~word(2))*(c~word(1)-a~word(1))

::requires 'Slam450Squad.cls'
::requires 'Slam450Situation.cls'
::requires 'HarbourHeightWords.cls'
