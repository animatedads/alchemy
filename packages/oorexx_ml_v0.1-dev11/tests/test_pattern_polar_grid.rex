curve=.array~of(5,6,8,10,8,6)
s=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(12,16,1,4,8,.false,.false),'POLAR-GRID')
h=s~encode(curve); p=h~polarPoints
call eq 12,p~items,'polar point count'
call eq 0,p[1]~angleDegrees,'first angle zero'
call eq 90,p[4]~angleDegrees,'quarter-turn angle'
minRadius=1; maxRadius=0
do x over p; if x~radius<minRadius then minRadius=x~radius; if x~radius>maxRadius then maxRadius=x~radius; end
call truth minRadius<=.0000001,'central minimum maps to radius zero'
call truth maxRadius>=.99,'maximum maps near outer radius'
say 'PASS test_pattern_polar_grid'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
