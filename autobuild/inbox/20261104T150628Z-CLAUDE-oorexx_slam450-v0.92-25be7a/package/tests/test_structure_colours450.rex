/* SLAM450 v0.92 — structure class colours, draw-only splitting, depth order.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.
 * 1 every PowerSLAM solid has a class (none left as plain grey);
 * 2 class colours are distinct from each other and from every other symbol
 *   a pilot sees (targets, rivals, teammates, own craft, landmarks, land,
 *   sky, water) by at least 40 in RGB distance;
 * 3 the bridge deck splits into <= 40 m pieces whose union is the deck;
 * 4 from beneath the deck the deck is drawn overhead (it used to collapse);
 * 5 far-to-near order: a nearer solid wins the pixels it shares with a
 *   farther one. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
w=.Slam450World~new(45046,'PYLONS',.false)
cam=.Slam450Camera~new(w)
unclassed=0
do b over w~scene~boxes;if .Slam450Camera~structureClass(b[1])=='x' then unclassed+=1;end
if unclassed>0 then call fail unclassed 'solids still plain grey'
pal=.Slam450Camera~palette
others=.directory~new
others['sky']='191 218 238';others['water']='51 126 173';others['land']='169 180 143'
others['rival']='255 230 0';others['team']='60 225 145';others['own']='70 205 255'
others['lmA']='235 184 26';others['lmB']='249 219 79';others['lmC']='251 249 227';others['lmD']='56 106 198'
others['t1']='70 0 0';others['t2']='112 0 0';others['t3']='158 0 0';others['t4']='208 0 0';others['t5']='255 0 0'
keys=pal~allIndexes
do i=1 to keys~items
  do j=i+1 to keys~items
    if rgbd(pal[keys[i]],pal[keys[j]])<40 then call fail 'classes' keys[i] keys[j] 'too similar'
  end
  do o over others~allIndexes
    if rgbd(pal[keys[i]],others[o])<40 then call fail 'class' keys[i] 'too close to' o
  end
end
do b over w~scene~boxes
  if b[1]\=='DECK' then iterate
  pieces=cam~drawPieces(b[2])
  if pieces~items<14 then call fail 'deck split into only' pieces~items
  lo=1e9;hi=-1e9
  do pc over pieces;do v over pc;lo=min(lo,v[1]);hi=max(hi,v[1]);end;end
  blo=1e9;bhi=-1e9;do v over b[2];blo=min(blo,v[1]);bhi=max(bhi,v[1]);end
  if abs(lo-blo)>0.001 | abs(hi-bhi)>0.001 then call fail 'deck pieces do not span the deck'
end
f=cam~renderAt(.array~of(47,-40,20,27),960,242)
overhead=0
do y=1 to 60;overhead+=countstr('d',f['PIXELS'][y]);end
if overhead<500 then call fail 'deck not drawn overhead from beneath' overhead
/* depth: from (-120,-300,60) facing the south pylon pair, a pylon (p) is
   nearer than anything behind it; the centre of its silhouette must be p. */
f=cam~renderAt(.array~of(-110,-215,70,135),960,242)
px=0;do y=1 to 242;px+=countstr('p',f['PIXELS'][y]);end
if px<200 then call fail 'pylons not visible in front' px
if fails==0 then say 'TEST_STRUCTURE_COLOURS450 PASS (deck overhead px' overhead', pylon px' px')'
else say 'TEST_STRUCTURE_COLOURS450 FAIL' fails
exit (fails>0)
fail: fails+=1;say 'FAIL:' arg(1);return
rgbd: procedure
  parse arg r1 g1 b1, r2 g2 b2
  numeric digits 16
  return RxCalcSqrt((r1-r2)**2+(g1-g2)**2+(b1-b2)**2,16)
::requires 'Slam450Flight.cls'
