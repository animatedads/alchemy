/* Wobbly Value demo: mixed radar returns contain two coherent tracks.
 * Three returns prevent Track A from fitting.  Setting aside the minimal
 * restoring set gives distance-to-fit 3; those same observations fit Track B.
 */
obs=.array~new
/* primary track A: y=2x+1 */
call addObs obs,'A0',0,1,'A'
call addObs obs,'A1',1,3,'A'
call addObs obs,'A2',2,5,'A'
/* interleaved secondary track B: y=-x+20 */
call addObs obs,'B3',3,17,'B'
call addObs obs,'A4',4,9,'A'
call addObs obs,'A5',5,11,'A'
call addObs obs,'B6',6,14,'B'
call addObs obs,'A7',7,15,'A'
call addObs obs,'A8',8,17,'A'
call addObs obs,'B9',9,11,'B'
call addObs obs,'A10',10,21,'A'
call addObs obs,'A11',11,23,'A'

criterion=.MLFitCriterion~new(0.00001,'LOWER_IS_BETTER')
search=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,criterion,4,10000)
norm=.MLWobbleNorm~new(.array~of(.00,.04,.05,.06,.08,.08,.10,.10,.12,.15))
study=.MLWobbleStudy~new('RADAR-MIXED-RETURNS')
a=study~analyze(search,obs,norm)

say 'WOBBLY VALUE / DISTANCE-TO-FIT RADAR DEMO'
say 'full-fit RMS        =' a~baseline~value
say 'distance to fit     =' a~distanceToFit 'of' obs~items
say 'normalized distance =' a~normalizedDistance
say 'normative class     =' a~normativeClass
say 'norm percentile     =' a~percentile
say 'minimal sets        =' a~restoringSets~items
ws=a~restoringSets[1]
say 'restoring set       =' ws~ids~canonicalText
say 'restored Track A RMS=' ws~assessment~value

removed=.array~new
idxs=ws~indexes~toArray
do ix over idxs; removed~append(obs[ix]); end
bfit=.MLLinearTrackFitScorer~new~assess(removed)
say 'same set Track B RMS=' bfit~value
say 'reassignment:'
do o over removed
  ev=.directory~new; ev['secondary_fit_rms']=bfit~value; ev['reason']='coherent alternate linear track'
  r=.MLWobbleReassignment~new(o['id'],'ALTERNATE_TRACK','TRACK-B',ev)
  say ' ' r~id '->' r~target '('r~disposition')'
end

svgPath='wobbly_radar_demo.svg'
if arg()>=1 then parse arg svgPath
call writeSvg svgPath,obs
say 'SVG='svgPath
say 'PASS wobbly_radar_demo'
exit 0

addObs: procedure
  use strict arg a,id,x,y,truth
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; d['truth']=truth; a~append(d); return

writeSvg: procedure
  use strict arg path,obs
  s=.stream~new(path); s~open('write replace')
  s~lineout('<svg xmlns="http://www.w3.org/2000/svg" width="920" height="560" viewBox="0 0 920 560">')
  s~lineout('<rect width="920" height="560" fill="white"/>')
  s~lineout('<text x="40" y="38" font-family="sans-serif" font-size="24">Wobbly Value: mixed radar returns</text>')
  s~lineout('<text x="40" y="65" font-family="sans-serif" font-size="14">Three valid returns break Track A; removal restores A and the same returns form Track B.</text>')
  /* axes */
  s~lineout('<line x1="70" y1="490" x2="870" y2="490" stroke="#333"/>')
  s~lineout('<line x1="70" y1="90" x2="70" y2="490" stroke="#333"/>')
  /* reference lines */
  x1=70; yA1=490-(1/24)*380; x2=850; yA2=490-(23/24)*380
  s~lineout('<line x1="'||x1||'" y1="'||yA1||'" x2="'||x2||'" y2="'||yA2||'" stroke="#3274a1" stroke-width="2" stroke-dasharray="7,5"/>')
  yB1=490-(20/24)*380; yB2=490-(9/24)*380
  s~lineout('<line x1="'||x1||'" y1="'||yB1||'" x2="'||x2||'" y2="'||yB2||'" stroke="#d04a3a" stroke-width="2" stroke-dasharray="7,5"/>')
  do o over obs
    x=70+(o['x']/11)*780; y=490-(o['y']/24)*380
    if o['truth']='A' then fill='#3274a1'; else fill='#d04a3a'
    s~lineout('<circle cx="'||x||'" cy="'||y||'" r="7" fill="'||fill||'"/>')
    s~lineout('<text x="'||(x+9)||'" y="'||(y-7)||'" font-family="sans-serif" font-size="11">'||o['id']||'</text>')
  end
  s~lineout('<text x="680" y="110" font-family="sans-serif" font-size="13" fill="#3274a1">Track A: y=2x+1</text>')
  s~lineout('<text x="680" y="132" font-family="sans-serif" font-size="13" fill="#d04a3a">Track B: y=-x+20</text>')
  s~lineout('<text x="330" y="540" font-family="sans-serif" font-size="14">event / scan progress</text>')
  s~lineout('<text x="12" y="300" font-family="sans-serif" font-size="14" transform="rotate(-90 12 300)">measured position</text>')
  s~lineout('</svg>'); s~close; return

::requires "OorexxML.cls"
