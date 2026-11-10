/* SLAM 450 v0.92 cockpit snapshot from recorded race evidence (after the race).
 * Re-renders the exact panorama format the pilot saw at one tick, from the
 * oracle truth tracks: own pose, rivals R / teammates P, moving targets at
 * their recorded positions, claimed targets removed. Arch world included.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.
 * usage: rexx cockpit_snap.rex runPrefix seed course aircraft tick out.ppm [width] */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg pfx seed course me tick out width .
if width=='' then width=960
height=trunc(width*121/480)
g=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
w=.Slam450World~new(seed,course,.false,g)
cam=.Slam450Camera~new(w)
team=.directory~new;team['A1']='RED';team['A4']='RED';team['A2']='BLUE';team['A3']='BLUE';team['A5']='BLUE'
kind=.directory~new
f=pfx'_airframes.csv';call linein f
do while lines(f)>0;parse value linein(f) with id ',' k ',' .;kind[id]=k;end
call stream f,'C','CLOSE'
poses=.directory~new
do id over team~allIndexes
  f=pfx'_'id'_truth_ORACLE_ONLY.csv'
  if stream(f,'C','QUERY EXISTS')=='' then iterate
  call linein f
  do while lines(f)>0
    parse value linein(f) with tk ',' x ',' y ',' z ',' h ',' .
    if tk>tick then leave
    if tk==tick then poses[id]=.array~of(x+0,y+0,z+0,h+0)
  end
  call stream f,'C','CLOSE'
end
if \poses~hasIndex(me) then do;say 'no pose for' me 'at tick' tick;exit 2;end
claims=.directory~new
f=pfx'_claims.csv';call linein f
do while lines(f)>0;parse value linein(f) with tk ',' . ',' t ',' who ',' .;if tk<tick then claims[t+0]=who;end
call stream f,'C','CLOSE'
f=pfx'_targets_track_ORACLE_ONLY.csv'
if stream(f,'C','QUERY EXISTS')\=='' then do
  call linein f
  do while lines(f)>0
    parse value linein(f) with tk ',' n ',' x ',' y ',' z ',' .
    if tk>tick then leave
    t=w~targets[n];t[1]=x+0;t[2]=y+0;t[3]=z+0
  end
  call stream f,'C','CLOSE'
end
others=.directory~new;okinds=.directory~new
rl=.array~new;rk=.array~new;pl=.array~new;pk=.array~new
do who over poses~allIndexes
  if who==me then iterate
  if team[who]==team[me] then do;pl~append(poses[who]);pk~append(kind[who]);end
  else do;rl~append(poses[who]);rk~append(kind[who]);end
end
if rl~items>0 then do;others['R']=rl;okinds['R']=rk;end
if pl~items>0 then do;others['P']=pl;okinds['P']=pk;end
fr=cam~renderAt(poses[me],width,height,.false,claims,others,.nil,okinds)
call SysFileDelete out
cam~writePPM(fr,out)
p=poses[me]
say 'SNAP' me 'tick' tick 'pose' format(p[1],,1) format(p[2],,1) format(p[3],,1) format(p[4],,0) 'claimed' claims~items '->' out
::requires 'Slam450Flight.cls'
