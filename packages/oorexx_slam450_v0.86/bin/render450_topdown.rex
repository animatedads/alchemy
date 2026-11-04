/* Native PowerSLAM top-down geometry and flight trace. Not AI illustration.
 * Oracle uses recorded trajectory only AFTER navigation is complete.
 * Structure outlines are PowerSLAM v0.40 cuboid footprints, not real survey.
 */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg sourceFile outFile seed mode
if sourceFile=='' | outFile=='' then do
 say 'usage: rexx render450_topdown.rex truth.csv plan.svg [seed] [mode]';exit 2
end
if seed=='' then seed=45042
if mode=='' then mode='LOOP'
w=.Slam450World~new(seed,mode)
plotWidth=1300;plotHeight=1100;sc=0.505
if stream(sourceFile,'C','QUERY EXISTS')=='' then do;say 'UNKNOWN TRACE FILE';exit 3;end
call SysFileDelete outFile
call emit '<svg xmlns="http://www.w3.org/2000/svg" width="1300" height="1100" viewBox="0 0 1300 1100">'
call emit '<rect width="1300" height="1100" fill="#08131e"/>'
call emit '<text x="60" y="65" fill="#e9f2f6" font-size="30" font-family="monospace">SLAM 450 — PowerSLAM v0.40 | native plan view</text>'
call emit '<text x="60" y="94" fill="#98b2c6" font-size="16" font-family="monospace">Local ENU metres, x=east / y=north. Model footprints only; not surveyed coastline.</text>'
/* Solid footprint: each cuboid directly from the actual PowerSLAM scene. */
do box over w~scene~boxes
 name=box[1]
 fill='#667c89'
 if name=='OPERA' then fill='#d6c8a7'
 if name=='DECK' | name=='CAHILL' | name=='CAHILL_RAMP' | name=='CAHILL_EAST_EXTENSION' then fill='#ce704c'
 if name=='CAHILL_BERM' then fill='#8a6b50'
 if name=='BLUES_POINT_TOWER' then fill='#6c54a3'
 if name~left(2)=='CQ' then fill='#13a69f'
 if name~left(2)=='WB' then fill='#c8a16a'
 v=box[2];line=''
 do ii over .array~of(1,2,4,3)
  pt=v[ii]
  line=line||' '||pointx(pt[1])||','||pointy(pt[2])
 end
 call emit '<polygon points="'||line||'" fill="'||fill||'" fill-opacity="0.48" stroke="'||fill||'" stroke-width="1"/>'
end
/* Lines are generated from the actual independent continuous flight log. */
header=linein(sourceFile)
track=pointx(270)||','||pointy(-610)
prevStage=1
arrival=.array~new
steps=0
repeatStatus=''
do while lines(sourceFile)>0
 line=linein(sourceFile)
 if line~strip=='' then iterate
 parse var line step ',' x ',' y ',' z ',' bearing ',' active ',' state ',' rest
 if \datatype(x,'N') | \datatype(y,'N') then iterate
 track=track||' '||pointx(x)||','||pointy(y)
 steps=step;repeatStatus=state
 if datatype(active,'W') & active>prevStage then do
  arrival~append(.array~of(prevStage,x,y,step))
  prevStage=active
 end
end
call stream sourceFile,'C','CLOSE'
call emit '<polyline points="'||track||'" fill="none" stroke="#20d9e9" stroke-opacity="0.90" stroke-width="2.7" stroke-linejoin="round" stroke-linecap="round"/>'
/* Physical targets remain at their actual synthetic model coordinates. The
 * icon is intentionally enlarged; target dimensions remain 2m x 2m. */
reds=.array~of('#610000','#890000','#b60000','#dd0000','#ff2323')
do i=1 to 5
 t=w~targets[i]
 xx=pointx(t[1]);yy=pointy(t[2])
 call emit '<rect x="'||(xx-10)||'" y="'||(yy-10)||'" width="20" height="20" fill="'||reds[i]||'" stroke="#ffe9e4" stroke-width="1.4"/>'
 labelY=yy-13
 if i==5 then labelY=yy+45
 call emit '<text x="'||(xx+15)||'" y="'||labelY||'" font-size="17" font-family="monospace" fill="#ffdfdb">'||i||' '||w~courseAreas[i]||' | '||t[3]~format(3,1)||'m</text>'
end
sx=pointx(270);sy=pointy(-610)
call emit '<circle cx="'||sx||'" cy="'||sy||'" r="8" fill="#20d9e9" stroke="#ffffff" stroke-width="2"/>'
call emit '<text x="'||(sx+13)||'" y="'||(sy+19)||'" font-size="17" font-family="monospace" fill="#20d9e9">START</text>'
do a over arrival
 xx=pointx(a[2]);yy=pointy(a[3])
 call emit '<circle cx="'||xx||'" cy="'||yy||'" r="4.5" fill="#fbf6db"/>'
end
call emit '<path d="M 1170 172 L 1170 127 M 1160 143 L 1170 127 L 1180 143" fill="none" stroke="#e3f5fa" stroke-width="3"/>'
call emit '<text x="1187" y="146" font-size="24" fill="#e3f5fa" font-family="monospace">N</text>'
call emit '<rect x="38" y="982" width="1224" height="100" fill="#102637" fill-opacity="0.93"/>'
call emit '<text x="58" y="1014" font-size="18" fill="#e9f2f6" font-family="monospace">Flight trace recorded in metres; no map repositioning or generated Sydney scenery.</text>'
call emit '<text x="58" y="1043" font-size="17" fill="#9cbaca" font-family="monospace">SEED '||seed||' | MODE '||mode||' | STEPS '||steps||' | LAST STATUS '||repeatStatus||' | '||w~scene~boxes~items||' PowerSLAM structure solids</text>'
call emit '</svg>'
call stream outFile,'C','CLOSE'
say 'SLAM450 NATIVE PLAN WRITTEN' outFile 'STEPS' steps 'ARRIVALS' arrival~items
exit 0
emit:
 parse arg line
 call lineout outFile,line
return
pointx:
 parse arg xx
 return trunc(plotWidth/2+(xx+0)*sc)
pointy:
 parse arg yy
 return trunc(plotHeight/2-(yy+350)*sc)
::requires 'Slam450Flight.cls'
