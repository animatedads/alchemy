/* SLAM 450 v0.92 one-time precompute: the visual-fix grid.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.
 * usage: rexx precompute450_visualfix.rex COURSE seed altitude out.txt [cell]
 * For every 50 m block of the course's map crop, render the static scene
 * (structures, land, water; no targets, no aircraft) from the block centre
 * at the given altitude facing north, reduce it to a 96 x 24 feature
 * surface (Slam450VisualFix~surfaceOf) and write one line per block:
 *   gx gy x y OK|BLOCKED ground_m surface   (ground_m: Power SLAM ground top,
 *   0 = water; surface: 2304 letters a..m, one per point, value 0..12)
 * Wire size in V5V terms: bin/v5vsize450_visualfix.rex. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg course seed alt out cell .
if cell=='' then cell=50
.local['SLAM450.GROUND']='GROUND'
g=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
w=.Slam450World~new(seed,course,.false,g)
crop=.Slam450PlanMap~crop(w)
cam=.Slam450Camera~new(w)
noTargets=.directory~new;do t=1 to 5;noTargets[t]='PRECOMPUTE';end
nc=trunc((crop[2]-crop[1])/cell);nr=trunc((crop[4]-crop[3])/cell)
call SysFileDelete out
call lineout out,'VISUALFIX2 96 24' cell alt course crop~toString(,',')
t0=time('E');ok=0;blocked=0;surfaces=.array~new
do gy=0 to nr-1
  /* serpentine: neighbouring blocks follow each other (V5V deltas stay small) */
  do i=0 to nc-1
    gx=i;if gy//2=1 then gx=nc-1-i
    x=crop[1]+(gx+0.5)*cell;y=crop[3]+(gy+0.5)*cell
    p=.array~of(x,y,alt,0)
    gm=g~surface(x,y);if \datatype(gm,'N') then gm=0
    if \w~safePoint(p,2) then do
      call lineout out,gx gy format(x,,1) format(y,,1) 'BLOCKED' format(gm,,1)
      blocked+=1;iterate
    end
    f=cam~renderAt(p,480,121,.false,noTargets)
    s=.Slam450VisualFix~surfaceOf(f)
    call lineout out,gx gy format(x,,1) format(y,,1) 'OK' format(gm,,1) s~translate('abcdefghijklm',xrange('00'x,'0C'x))
    surfaces~append(s);ok+=1
  end
end
call stream out,'C','CLOSE'
say 'PRECOMPUTE' course 'ALT' alt 'CELL' cell 'GRID' nc'x'nr 'OK' ok 'BLOCKED' blocked 'SECONDS' format(time('E')-t0,,1)
/* V5V wire size: see bin/v5vsize450_visualfix.rex (dev14's codec delta path
   calls a VisionSurfaceDelta~between that Vision.cls lacks). */
exit 0
::requires 'Slam450Flight.cls'
::requires 'Slam450PlanMap.cls'
::requires 'Slam450VisualFix.cls'
