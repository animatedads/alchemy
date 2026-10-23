r=.AudioTechniqueRegistry~new
x=.array~of(1,2,3,4,5)
y=r~process('DC_REMOVE',x,0)
if abs(y[1]+2)>0.000001 then raise syntax 93.900 array('DC removal')
y=r~process('MOVING_AVERAGE',x,3)
if abs(y[3]-2)>0.000001 then raise syntax 93.900 array('moving average')
y=r~process('MEDIAN_FILTER',.array~of(1,99,2),3)
if y[2]<>2 then raise syntax 93.900 array('median')
y=r~process('PREEMPHASIS',x,0.5)
z=r~process('DEEMPHASIS',y,0.5)
do i=1 to x~items
 if abs(z[i]-x[i])>0.000001 then raise syntax 93.900 array('roundtrip')
end
say 'PASS: 7 ooRexx reference techniques; registry and DSP smoke'
::requires "src/AudioTechniques.cls"
