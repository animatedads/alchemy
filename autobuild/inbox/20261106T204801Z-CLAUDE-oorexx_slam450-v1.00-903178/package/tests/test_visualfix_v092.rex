/* SLAM450 v0.92 visual position fix: unit checks (no grid files needed).
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.
 * - rotate by k then -k restores a surface; diff ignores unknown points;
 * - surfaceOf maps panorama symbols to feature classes in the +-45 band;
 * - lookup on a three-point synthetic grid finds the right point and the
 *   heading from the column shift, and refuses a featureless view;
 * - landmarks include Salesforce, Blues, Opera, 4 pylons and the arch top;
 * - the battery accepts the VISUAL category and the squad debits it. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
s=''
do r=1 to 24;do c=1 to 96;s=s||d2c((r*7+c*3)//13);end;end
if .Slam450VisualFix~rotate(.Slam450VisualFix~rotate(s,5),-5)\==s then call fail 'rotate +5 then -5 must restore'
q=s~overlay('00'x,1)
m=q~translate(copies('FF'x,15),xrange('01'x,'0F'x))
c=s~overlay(d2c(12),1)
if .Slam450VisualFix~diff(q,m,c)\=0 then call fail 'unknown query point must not count'
p50=c2d(s~substr(50,1));nv=(p50+1)//13;if nv=0 then nv=1
c2=s~overlay(d2c(nv),50)
if p50>0 then if .Slam450VisualFix~diff(q,m,c2)\=1 then call fail 'one changed known point must count 1'
/* synthetic frame: sky top half, water bottom, a pylon column near centre */
rows=.array~new
do y=1 to 121
  if y<=60 then line='.'~copies(480);else line='~'~copies(480)
  if y>=40 & y<=60 then line=line~overlay('ppppp',241)
  rows~append(line)
end
fr=.directory~new;fr['WIDTH']=480;fr['HEIGHT']=121;fr['PIXELS']=rows
sf=.Slam450VisualFix~surfaceOf(fr)
if length(sf)\=2304 then call fail 'surface must be 96x24'
if sf~pos(d2c(6))=0 then call fail 'pylon class 6 missing from surface'
if c2d(sf~substr(1,1))\=1 | c2d(sf~substr(2304,1))\=2 then call fail 'band corners should be sky (top) and water (bottom)'
/* three-point grid: A has the pylon at column 49, B at column 10, C nothing */
f='/tmp/test_visualfix_grid.txt';call SysFileDelete f
call lineout f,'VISUALFIX 96 24 50 40 TEST -100,100,-100,100,1'
call lineout f,'2 2 25 25 OK 0' c2x(sf)
other=sf~translate(d2c(1),d2c(6))
pB=other;do r=0 to 23;if c2d(sf~substr(r*96+49,1))=6 then pB=pB~overlay(d2c(6),r*96+10);end
call lineout f,'6 2 225 25 OK 0' c2x(pB)
call lineout f,'2 6 25 225 OK 3' c2x(other)
call stream f,'C','CLOSE'
vf=.Slam450VisualFix~new(f)
r=vf~lookup(sf,40,30,0,400,30,1.05)
if \r['ACCEPT'] | abs(r['BLOCK_X']-25)>0.1 | abs(r['BLOCK_Y']-25)>0.1 then call fail 'should fix on block A, got' r['BLOCK_X'] r['BLOCK_Y'] r['ACCEPT'] r['SCORE'] r['SECOND'] r['N']
rot=.Slam450VisualFix~rotate(sf,-4)
r=vf~lookup(rot,40,30,15,400,30,1.05)
if abs(r['HEADING']-15)>0.01 then call fail 'heading from a 4-column shift should be 15, got' r['HEADING']
flat=other
r=vf~lookup(flat,40,30,0,400,30,1.05)
if r['ACCEPT'] & abs(r['BLOCK_Y']-225)>0.1 then call fail 'featureless view must not fix on a feature block'
if vf~groundAt(30,230)\=3 then call fail 'groundAt should read block C ground 3'
/* landmarks */
.local['SLAM450.GROUND']='NONE'
w=.Slam450World~new(45046,'LEGACY')
lm=.Slam450Landmarks~new(w)
kinds=.directory~new;do d over lm~items;k=d['KIND'];if kinds~hasIndex(k) then kinds[k]+=1;else kinds[k]=1;end
do k over .array~of('SALESFORCE','BLUES','OPERA','PYLON')
  if \kinds~hasIndex(k) then call fail 'landmark' k 'missing'
end
if kinds['PYLON']\=4 then call fail 'expected 4 pylons, got' kinds['PYLON']
/* battery VISUAL category */
b=.Slam450Battery~new(900,.Slam450QuadAirframe~new)
if \b~debit('VISUAL',0.03) then call fail 'battery must accept VISUAL'
if abs(b~report['REMAINING']-899.97)>1e-9 then call fail 'VISUAL debit must reduce remaining by 0.03'
if fails==0 then say 'TEST_VISUALFIX_V092 PASS'
else say 'TEST_VISUALFIX_V092 FAIL' fails
exit (fails>0)
fail: fails+=1;say 'FAIL:' arg(1);return
::requires 'Slam450Flight.cls'
::requires 'Slam450VisualFix.cls'
::requires 'Slam450Battery.cls'
::requires 'Slam450AircraftType.cls'
