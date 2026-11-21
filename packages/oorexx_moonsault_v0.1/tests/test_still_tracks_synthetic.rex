/* Standalone ooRexx timeline/aircraft rejection check, no private images. */
numeric digits 30
frames=.array~new
rows=.array~of( -
  '917 147 564 189 851 235', -
  '903 164 548 196 835 249', -
  '887 181 531 203 818 264', -
  '887 182 531 203 817 264 317 260 318 261 322 262 321 263', -
  '877 193 519 207 806 274')
do r over rows
  pts=.array~new
  do i=1 to words(r) by 2
    p=.directory~new
    p['X']=word(r,i);p['Y']=word(r,i+1)
    pts~append(p)
  end
  frames~append(pts)
end
clock=.array~of(0,425,880,892,1186)
registration=.array~of(.array~of(0,0),.array~of(0,0),.array~of(0,0),.array~of(0,0),.array~of(0,0))
tracks=.MoonsaultStillPointScan~trackFive(frames,clock,registration)
if tracks~items<>3 then do
  say 'FAIL expected 3 five-frame tracks, actual' tracks~items
  exit 21
end
do tr over tracks
  if tr['RMS']>1 then do
    say 'FAIL track exceeds 1 pixel RMS' tr['RMS']
    exit 22
  end
end
clusters=.MoonsaultStillPointScan~elongatedClusters(frames[4])
if clusters~items<1 then exit 23
found=.false
do cl over clusters
  if cl['LEFT']=317 & cl['RIGHT']=322 & cl['TOP']=260 & cl['BOTTOM']=263 & -
     cl['MEMBERS']=4 then found=.true
end
if \found then exit 24
say 'PASS 3 time-coherent sky point tracks, 4-peak aircraft-like transient excluded'
exit 0
::requires '../src/MoonsaultStillPointScan.cls'