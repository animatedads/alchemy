/* render450_plan.rex - SLAM 450 v0.95: a race's flight plans, drawn on Control's map.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
 * usage: rexx render450_plan.rex out.svg seed prefix map.png team title words
 *   team: ALL, RED or BLUE (whose plans and tracks to draw)
 * Background: Control's map (bin/control450_map.rex, Tombstone ELVIS terrain),
 * drawn at the same scale. Over it:
 *   - flight plans: each craft's ordered places, in the order it worked them
 *     (prefix_<craft>_order.csv), joined by a dotted line in the craft colour;
 *   - flown tracks (prefix_<craft>_truth_ORACLE_ONLY.csv: the referee's truth,
 *     used only after the race, for the picture), Red solid, Blue dashed;
 *   - area X (west of the deck's west edge) shaded, and ROE-1's evidence:
 *     each drone sighting, each camera visual with its ray carried on to the
 *     bridge, the moment authority was given, and every WOULD_BREACH;
 *   - claims (star, who, when) and knock-outs (cross, when). */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg out seed prefix png team title
if out=='' then do;say 'usage: rexx render450_plan.rex out.svg seed prefix map.png team "title"';exit 2;end
team=team~upper;if team=='' then team='ALL'
.local['SLAM450.GROUND']='GROUND'
g=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
w=.Slam450World~new(seed,'HARBOUR',.false,g)
sit=.Slam450Situation~new(w)
/* the map's own frame (control450_map.rex) */
x0=-700;x1=560;y0=-1200;y1=420;s=0.5;m=60
mapW=trunc((x1-x0)*s)+2*m;mapH=trunc((y1-y0)*s)+2*m+102
extra=34;foot=46
call SysFileDelete out
call emit '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="'mapW'" height="'mapH+extra+foot'" viewBox="0 0 'mapW mapH+extra+foot'">'
call emit '<rect width="'mapW'" height="'mapH+extra+foot'" fill="#101418"/>'
b64=charin(png,1,chars(png))~encodeBase64;call stream png,'C','CLOSE'
call emit '<image x="0" y="'extra'" width="'mapW'" height="'mapH'" xlink:href="data:image/png;base64,'b64'"/>'
call emit '<text x="14" y="23" fill="#ffffff" font-size="13" font-weight="bold" font-family="sans-serif">'title'</text>'
call emit '<g transform="translate(0,'extra')">'
call emit '<clipPath id="v"><rect x="'px(x0)'" y="'py(y1)'" width="'format((x1-x0)*s,,1)'" height="'format((y1-y0)*s,,1)'"/></clipPath><g clip-path="url(#v)">'
/* area X: west of the line 25 m west of the span axis */
ux=260/564.94;uy=501.5/564.94;nx=-uy;ny=ux          /* n points west */
ax=-68+25*nx;ay=-261+25*ny
pa=(ax-3000*ux)||','||(ay-3000*uy);pb=(ax+3000*ux)||','||(ay+3000*uy)
pc=(ax+3000*ux+3000*nx)||','||(ay+3000*uy+3000*ny);pd=(ax-3000*ux+3000*nx)||','||(ay-3000*uy+3000*ny)
call emit '<polygon points="'pt(pa) pt(pb) pt(pc) pt(pd)'" fill="#ff1744" fill-opacity="0.07"/>'
call emit '<line x1="'px(ax-3000*ux)'" y1="'py(ay-3000*uy)'" x2="'px(ax+3000*ux)'" y2="'py(ay+3000*uy)'" stroke="#ff8a80" stroke-width="2" stroke-dasharray="10,6"/>'
call emit '<text x="'px(-420)'" y="'py(260)'" fill="#ff8a80" font-size="13" font-weight="bold" font-family="sans-serif">AREA X (west of the deck)</text>'
/* v0.97: the squad from the race's <prefix>_squad.csv, however many craft;
   races before v0.97 have no file and get the five-craft line-up. Colours:
   warm for Red, cool for Blue, taken in turn. */
ids=.array~new;teamOf=.directory~new;wingOf=.directory~new
sq=prefix'_squad.csv'
if stream(sq,'C','QUERY EXISTS')\=='' then do
  call linein sq
  do while lines(sq)>0
    parse value linein(sq) with a_ ',' t_ ',' f_ ',' .
    if a_=='' then iterate
    ids~append(a_);teamOf[a_]=t_;wingOf[a_]=(f_=='FIXED_WING')
  end
  call stream sq,'C','CLOSE'
end
else do l_ over .array~of('A1 RED 0','A4 RED 0','A2 BLUE 0','A3 BLUE 1','A5 BLUE 0')
  parse var l_ a_ t_ w_;ids~append(a_);teamOf[a_]=t_;wingOf[a_]=w_
end
warm=.array~of('#ff5252','#ffab40','#ffd740','#ff80ab');cool=.array~of('#40c4ff','#69f0ae','#b388ff','#84ffff')
col=.directory~new;nr=0;nb=0
do id over ids
  if teamOf[id]=='RED' then do;nr+=1;col[id]=warm[1+(nr-1)//warm~items];end
  else do;nb+=1;col[id]=cool[1+(nb-1)//cool~items];end
end
nm=sit~craftNames
/* tracks and plans */
do id over ids
  if team\=='ALL' & teamOf[id]\==team then iterate
  tf=prefix'_'id'_truth_ORACLE_ONLY.csv'
  if stream(tf,'C','QUERY EXISTS')=='' then iterate
  ptsT='';first='';last=''
  call linein tf
  do while lines(tf)>0
    parse value linein(tf) with tk ',' x ',' y ',' .
    if \datatype(x,'N') then iterate
    ptsT=ptsT px(x)','py(y);if first=='' then first=x y;last=x y
  end
  call stream tf,'C','CLOSE'
  da='';if teamOf[id]=='BLUE' then da=' stroke-dasharray="7,4"'
  call emit '<polyline points="'ptsT~strip'" fill="none" stroke="'col[id]'" stroke-width="2.2" stroke-opacity="0.95"'da'/>'
  parse var first fx fy
  call emit '<circle cx="'px(fx)'" cy="'py(fy)'" r="5" fill="'col[id]'" stroke="#000" stroke-width="1"/>'
  call emit '<text x="'px(fx)+7'" y="'py(fy)+14'" fill="'col[id]'" stroke="#000" stroke-width="2.5" paint-order="stroke" font-size="12" font-weight="bold" font-family="sans-serif">'nm[id]' start</text>'
  /* the plan: distinct steps in the order worked */
  of=prefix'_'id'_order.csv'
  if stream(of,'C','QUERY EXISTS')=='' then iterate
  seen=.set~new;plan=.array~new
  do while lines(of)>0
    parse value linein(of) with tk ',' n ',' act ',' rot ',' pl ',' st ',' .
    key=n'|'pl
    if seen~hasItem(key) then iterate
    seen~put(key)
    xy=placeXY(pl)
    if xy=='' then iterate
    if plan~items>0 then if plan[plan~items][1]==xy then iterate
    plan~append(.array~of(xy,act,tk,pl))
  end
  call stream of,'C','CLOSE'
  pl2=''
  do k=1 to plan~items
    parse value plan[k][1] with qx qy
    pl2=pl2 px(qx)','py(qy)
  end
  if plan~items>1 then call emit '<polyline points="'pl2~strip'" fill="none" stroke="'col[id]'" stroke-width="1.6" stroke-dasharray="2,4" stroke-opacity="0.9"/>'
  do k=1 to plan~items
    parse value plan[k][1] with qx qy
    call emit '<rect x="'px(qx)-5'" y="'py(qy)-5'" width="10" height="10" transform="rotate(45 'px(qx) py(qy)')" fill="none" stroke="'col[id]'" stroke-width="2"/>'
    call emit '<text x="'px(qx)+8'" y="'py(qy)-6-8*(k//3)'" fill="'col[id]'" stroke="#000" stroke-width="2.5" paint-order="stroke" font-size="10" font-family="sans-serif">'nm[id]~left(1)||k plan[k][2]~lower 'at' plan[k][3]'s</text>'
  end
end
/* claims, knock-outs, ROE evidence from the log and the ROE file */
lg=prefix~left(prefix~lastPos('/')-1)'_'prefix~substr(prefix~lastPos('/')+1)'.log'
if stream(lg,'C','QUERY EXISTS')=='' then lg=prefix'.log'
do while lines(lg)>0
  ln=linein(lg)
  if ln~word(1)'_'ln~word(2)=='SQUAD_CLAIM' then do
    parse var ln . . tk . tn . who .
    if team\=='ALL' & teamOf[who]\==team then iterate
    xy=placeXY(sit~places[tnIndex(tn)]['KEY']);parse var xy qx qy
    call emit '<text x="'px(qx)'" y="'py(qy)+6'" fill="#ffeb3b" stroke="#000" stroke-width="2" paint-order="stroke" font-size="20" text-anchor="middle">&#9733;</text>'
    call emit '<text x="'px(qx)+10'" y="'py(qy)+18'" fill="#ffeb3b" stroke="#000" stroke-width="2.5" paint-order="stroke" font-size="11" font-weight="bold" font-family="sans-serif">'nm[who] tk's</text>'
  end
  if ln~word(1)'_'ln~word(2)=='SQUAD_OUT' then do
    parse var ln . . tk who .
    if team\=='ALL' & teamOf[who]\==team then iterate
    xy=trackAt(who,tk);if xy=='' then iterate
    parse var xy qx qy
    call emit '<text x="'px(qx)'" y="'py(qy)+6'" fill="#ff1744" stroke="#000" stroke-width="2" paint-order="stroke" font-size="20" font-weight="bold" text-anchor="middle">&#10006;</text>'
    call emit '<text x="'px(qx)+10'" y="'py(qy)-8'" fill="#ff1744" stroke="#000" stroke-width="2.5" paint-order="stroke" font-size="11" font-weight="bold" font-family="sans-serif">'nm[who] 'crashed' tk's</text>'
  end
end
call stream lg,'C','CLOSE'
rf=prefix'_roe.csv'
pano=.HarbourOcclusionPanorama~new;pano~configure
if stream(rf,'C','QUERY EXISTS')\=='' & team\=='RED' then do
  call linein rf
  do while lines(rf)>0
    parse value linein(rf) with tk ',' kind ',' who ',' detail
    detail=detail~strip~strip('B','"')
    select
      when kind=='WOULD_BREACH' then do
        xy=trackAt(who,tk);if xy=='' then iterate
        parse var xy qx qy
        call emit '<path d="M 'px(qx)' 'py(qy)-7' l 6 10 l -12 0 z" fill="#ff9100" stroke="#000" stroke-width="1"/>'
      end
      when kind=='SIGHTING' then do
        parse var detail aid .
        xa=trackAt(aid,tk);xb=trackAt(who,tk)
        if xa=='' | xb=='' then iterate
        parse var xa qx qy;parse var xb bx by
        call emit '<line x1="'px(bx)'" y1="'py(by)'" x2="'px(qx)'" y2="'py(qy)'" stroke="#ffffff" stroke-width="2.5"/>'
        call emit '<circle cx="'px(qx)'" cy="'py(qy)'" r="7" fill="none" stroke="#ffffff" stroke-width="2.5"/>'
        call emit '<text x="'px(qx)-8'" y="'py(qy)+22'" fill="#ffffff" stroke="#000" stroke-width="2.5" paint-order="stroke" font-size="11" font-weight="bold" font-family="sans-serif" text-anchor="end">'nm[who] 'sees' nm[aid] tk's</text>'
      end
      when kind=='CAMERA' then do
        parse var detail aid .
        xa=trackAt(aid,tk);if xa=='' then iterate
        parse var xa qx qy
        c=pano~siteCamera(who)
        /* the ray, carried on past the craft to the span plane */
        dx=qx-c[1];dy=qy-c[2];den=260*dy-501.5*dx
        ex=qx;ey=qy
        if den\=0 then do;ss=-(260*(c[2]+261)-501.5*(c[1]+68))/den;ex=c[1]+ss*dx;ey=c[2]+ss*dy;end
        call emit '<line x1="'px(c[1])'" y1="'py(c[2])'" x2="'px(qx)'" y2="'py(qy)'" stroke="#18ffff" stroke-width="2"/>'
        call emit '<line x1="'px(qx)'" y1="'py(qy)'" x2="'px(ex)'" y2="'py(ey)'" stroke="#18ffff" stroke-width="2" stroke-dasharray="3,3"/>'
        call emit '<circle cx="'px(c[1])'" cy="'py(c[2])'" r="5" fill="#18ffff"/>'
        call emit '<text x="'px(c[1])+8'" y="'py(c[2])-6'" fill="#18ffff" stroke="#000" stroke-width="2.5" paint-order="stroke" font-size="11" font-weight="bold" font-family="sans-serif">'who~changeStr('_',' ')' camera: bridge behind' nm[aid] tk's</text>'
      end
      when kind=='ESTABLISHED' then established=tk
      otherwise nop
    end
  end
  call stream rf,'C','CLOSE'
end
call emit '</g></g>'
/* legend, under the map */
lg=.array~of('Squares, dotted: each craft''s ordered places in the order worked (label: craft letter, step, action, time).',,
  'Lines: flown tracks (referee truth, drawn after the race), Red solid, Blue dashed. Star: claim. Cross: crash.',,
  'Orange: ROE-1 would-breach, held. White: drone sighting in area X. Cyan: camera ray, dotted on to the bridge.')
if symbol('established')=='VAR' then lg[3]=lg[3] 'Authority at' established's.'
do k=1 to lg~items
  call emit '<text x="14" y="'mapH+extra+k*13'" fill="#cfd8dc" font-size="10" font-family="monospace">'lg[k]'</text>'
end
call emit '</svg>'
call stream out,'C','CLOSE'
say 'PLAN' out
exit 0

wingTag: procedure expose wingOf
  if wingOf[arg(1)]==1 then return ' (fixed wing)'
  return ''
emit: procedure expose out
  parse arg t
  call lineout out,t
  return
px: procedure expose x0 s m
  return format(m+(arg(1)-x0)*s,,1)
py: procedure expose y1 s m
  return format(m+(y1-arg(1))*s,,1)
pt: procedure expose x0 y1 s m
  parse arg a ',' b
  return px(a)','py(b)

placeXY: procedure expose sit
  parse arg key
  if key~left(5)=='grid:' then do;parse var key 'grid:' gx ':' gy;return gx gy;end
  d=sit~place(key)
  if d==.nil then return ''
  return d['X'] d['Y']

tnIndex: procedure expose sit
  use arg n
  k=0
  do i=1 to sit~places~items
    if sit~places[i]['KIND']=='target' then do;k+=1;if k=n then return i;end
  end
  return 1

trackAt: procedure expose prefix
  use arg id, tick
  tf=prefix'_'id'_truth_ORACLE_ONLY.csv'
  if stream(tf,'C','QUERY EXISTS')=='' then return ''
  res=''
  call linein tf
  do while lines(tf)>0
    parse value linein(tf) with tk ',' x ',' y ',' .
    if \datatype(tk,'N') then iterate
    if tk<=tick then res=x y
    else leave
  end
  call stream tf,'C','CLOSE'
  return res

::requires 'Slam450Squad.cls'
::requires 'Slam450Situation.cls'
::requires 'SlamHarbourOcclusion.cls'
