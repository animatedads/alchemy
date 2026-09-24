n=.CommonParts~hexNut('M6')
if n~parameter('PITCH')<>'1 mm' then call fail 'M6 nut pitch'
w=.CommonParts~plainWasher('M6')
if w~geometry['BORE']<>'6.4 mm' then call fail 'M6 washer bore'
p=.CommonParts~gt2Pulley(20,'5 mm','6 mm')
if p~parameter('PITCH_DIAMETER_MM')<12 | p~parameter('PITCH_DIAMETER_MM')>13 then call fail 'GT2 pitch diameter'
g=.CommonParts~spurGear(1,20,'10 mm','5 mm')
if g~parameter('PITCH_DIAMETER_MM')<>20 then call fail 'gear pitch diameter'
if g~parameter('OUTSIDE_DIAMETER_MM')<>22 then call fail 'gear OD'
if .CommonParts~nema17Stepper~family<>'STEPPER_MOTOR' then call fail 'stepper family'
if .CommonParts~drillBit('6 mm')~family<>'CUTTING_TOOL' then call fail 'drill family'
if .CommonParts~endMill('6 mm',4)~geometry['FLUTES']<>4 then call fail 'end mill flutes'
say 'PASS motion/manufacturing families'
exit 0
fail: procedure
 parse arg m; say 'FAIL:' m; exit 1
::requires 'PartsCatalog.cls'
