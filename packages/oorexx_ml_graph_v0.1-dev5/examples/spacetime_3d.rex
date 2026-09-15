/* Time is an explicit coordinate, not accidental array order. */
parse arg out
if out='' then out='spacetime_3d.png'
g=.MLGraph~spaceTime('3D evidence: time × normalized radius × bend','time','radius','bend')
pts=.array~new
do t=0 to 15
  v=.directory~new
  v['time']=t
  v['radius']=((t*3)//11)/10
  v['bend']=((t*5)//9)-4
  pts~append(.MLGraphPoint~new(v,'sample-time='||t))
end
g~addSeries(.MLGraphSeries~new('trace',pts,'PRIMARY',.false,'time is supplied evidence'))
r=.MLGraphRenderers~byName('MATPLOTLIB')
g~render(r,out)
say 'PNG' out
say 'PASS spacetime_3d'
::requires 'MLGraphMatplotlib.cls'
