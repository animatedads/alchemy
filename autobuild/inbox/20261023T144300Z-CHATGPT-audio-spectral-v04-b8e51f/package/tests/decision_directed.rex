numeric digits 16
m=.AudioDecisionDirected~new(0.9,0.01)
a=m~advance(.array~of(10,0),.array~of(2,2))
if abs(a[1]-0.8)>0.000001 | a[2]<>0 then raise syntax 93.900 array('initial gain')
s=m~snapshot
b=m~advance(.array~of(2,2),.array~of(2,2))
if abs(b[1]-(2.88/3.88))>0.000001 then raise syntax 93.900 array('decision-directed update')
m~restore(s)
c=m~advance(.array~of(2,2),.array~of(2,2))
if abs(c[1]-b[1])>0.000001 then raise syntax 93.900 array('replay')
say 'PASS decision-directed SNR, Wiener gain, replay'
::requires 'AudioDecisionDirected.cls'
