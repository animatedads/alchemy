/* SLAM450 v0.90 — plan map test. Architecture: Tom Dyer. Written by: Claude (Opus 5.5).
 * Fixed crop and scale, north-up, Opera footprint present, open water at the
 * start position (no start marker, no "you are here"), identical for two
 * seeds (carries no target information), valid PNG via IndexedPngEncoder. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
a=.Slam450PlanMap~new(.Slam450World~new(45046,'LEGACY',.false))
b=.Slam450PlanMap~new(.Slam450World~new(45047,'LEGACY',.false))
if a~width\==540 | a~height\==810 then call fail 'size' a~width a~height
same=1;do r=1 to a~height;if a~rows[r]\==b~rows[r] then same=0;end
if \same then call fail 'map differs between seeds'
/* start pose (270,-610): col=(270-100)*1.5, row=(-340+610)*1.5 */
row=trunc((-340+610)*1.5)+1;col=trunc((270-100)*1.5)+1
if substr(a~rows[row],col,1)\=='~' then call fail 'start position not plain water'
/* Opera (x 422..542, y -611..-428) inside the crop on the east edge */
row=trunc((-340+520)*1.5)+1;col=trunc((450-100)*1.5)+1
if substr(a~rows[row],col,1)\=='x' then call fail 'Opera footprint missing'
png=a~pngBase64
if left(png,11)\=='iVBORw0KGgo' then call fail 'not a PNG'
if fails==0 then say 'TEST_PLANMAP450 PASS'
else say 'TEST_PLANMAP450 FAIL' fails
exit (fails>0)
fail: fails+=1;say 'FAIL:' arg(1);return
::requires 'Slam450Flight.cls'
::requires 'Slam450PlanMap.cls'
