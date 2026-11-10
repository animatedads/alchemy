/* Maths v0.21: MathTerrainPanorama PURE semantics.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.
 * 20 x 20 grid of 10 m cells, axis-aligned, cell (1,1) centred at (0,190):
 * columns run east, rows run south. Water everywhere except a 30 m hill
 * block (cols 9-12, rows 1-4: north) and an unknown block (cols 9-12,
 * rows 17-20: south). Camera at (100,100,10). */
fails=0
signal on syntax
cols=20;rows=20;hts=.array~new;k=.array~new
do r=1 to rows
  do c=1 to cols
    i=(r-1)*cols+c;hts[i]=0;k[i]=0
    if c>=9 & c<=12 & r<=4 then do;hts[i]=30;k[i]=1;end
    if c>=9 & c<=12 & r>=17 then do;hts[i]=0;k[i]=-1;end
  end
end
t=.MathTerrainPanorama~new(hts,k,cols,rows,.array~of(0,190),.array~of(10,0),.array~of(0,-10),3000,'PURE',16)
call check t~lane=='PURE','PURE lane selected'
call check t~schedule[1]=10 & t~schedule[2]=15,'distance schedule starts 10, 15'
/* yaw 0: north is the centre column (W/2+..), south is the edge. */
W=72;H=36
out=t~runs(.array~of(100,100,10,0),W,H)
call check out~items=W,'one entry per column'
north=out[W/2+1]
call check north~items=1,'hill visible straight ahead (north)'
if north~items=1 then do
  /* The hill's near face is at y=150 (rows 1-4 -> y 190..160, cell edge 155),
     d ~ 55-60 m, height 30 over cam 10 -> el ~ +18..20 deg -> top rows above horizon. */
  call check north[1][1]<=H/2,'hill top is above the horizon'
  call check north[1][2]>=H/2,'hill reaches down to the horizon or below'
end
south=out[1]
call check south~items=0,'unknown block to the south is transparent (nothing painted)'
east=out[W*3/4+1]
call check east~items=0,'open water to the east paints no land'
/* A camera above the hill top sees the hill below the horizon only. */
out2=t~runs(.array~of(100,100,80,0),W,H)
n2=out2[W/2+1]
call check n2~items=1,'hill seen from above'
if n2~items=1 then call check n2[1][1]>H/2,'hill from above lies below the horizon'
x=.MathTerrainPanorama~new(hts,k,cols,rows,.array~of(0,190),.array~of(10,0),.array~of(20,0),3000,'PURE')
call check .false,'degenerate grid vectors rejected'
done:
if fails=0 then say 'PASS oorexx_maths terrain panorama PURE semantics'
else say 'FAIL oorexx_maths terrain panorama' fails
exit (fails>0)
check: if \arg(1) then do;fails+=1;say 'FAIL:' arg(2);end;return
syntax:
  if condition('C')=='SYNTAX' & condition('O')~code=='88.900' then do;say 'ok: degenerate grid rejected';signal done;end
  raise propagate
::requires 'MathFastLanes.cls'
