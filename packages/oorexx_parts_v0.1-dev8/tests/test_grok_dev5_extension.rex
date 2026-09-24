/* Qualification for v0.1-dev5 catalogue extension */
failCount = 0

/* Fasteners */
sizes = .array~of('M3','M4','M5','M6','M8','M10','M12')
do s over sizes
  b = .CommonParts~metricBolt(s,'20 mm','STEEL-8.8-REFERENCE','HEX')
  if b~family <> 'FASTENER' then call fail 'bolt family' s
  if b~parameter('PITCH') = '' then call fail 'bolt pitch' s
  if \b~parameters~hasIndex('HEAD_SHEAR_CAPACITY_N') then call fail 'bolt capacity' s
  n = .CommonParts~metricNut(s)
  if n~family <> 'FASTENER' then call fail 'nut family' s
  w = .CommonParts~plainWasher(s)
  if w~geometry['FORM'] <> 'PLAIN_WASHER' then call fail 'washer form' s
end
ny = .CommonParts~nylocNut('M6')
if ny~parameters['LOCKING'] <> 'NYLON_INSERT' then call fail 'nyloc'
if .CommonMaterials~byId(ny~material('INSERT')) = .nil then call fail 'nyloc insert material'
rod = .CommonParts~threadedRod('M8','500 mm')
if rod~parameter('PITCH') <> '1.25 mm' then call fail 'rod pitch'
ss = .CommonParts~setScrew('M4','6 mm')
if ss~geometry['FORM'] <> 'SET_SCREW' then call fail 'set screw'

/* Head styles */
sk = .CommonParts~metricBolt('M5','16 mm','STEEL-8.8-REFERENCE','SOCKET')
if sk~geometry['FORM'] <> 'SOCKET_HEAD' then call fail 'socket head'
ck = .CommonParts~metricBolt('M4','12 mm','STEEL-8.8-REFERENCE','COUNTERSUNK')
if ck~geometry['FORM'] <> 'COUNTERSUNK' then call fail 'csk head'

/* Motion hardware */
col = .CommonParts~shaftCollar('8 mm')
if col~family <> 'SHAFT_HARDWARE' then call fail 'collar'
key = .CommonParts~keyStock
if key~geometry['FORM'] <> 'SQUARE_KEY' then call fail 'key'
rc = .CommonParts~rigidCoupler
if rc~family <> 'COUPLER' then call fail 'rigid coupler'
fc = .CommonParts~flexibleCoupler
if fc~provenance['NOTE'] = '' then call fail 'flex coupler note'
jc = .CommonParts~jawCoupler
if jc~geometry['FORM'] <> 'JAW_COUPLER' then call fail 'jaw'
ls = .CommonParts~leadScrew
if ls~family <> 'LEAD_SCREW' then call fail 'leadscrew'
belt = .CommonParts~gt2Belt
if belt~parameter('PITCH') <> '2 mm' then call fail 'gt2 belt'
pul = .CommonParts~gt2Pulley(20)
if \pul~geometry~hasIndex('PITCH_DIAMETER') then call fail 'gt2 pitch dia'
gear = .CommonParts~spurGear(1,30)
if gear~geometry['PITCH_DIAMETER'] <> '30 mm' then call fail 'spur pitch dia'
rk = .CommonParts~rack
if rk~family <> 'GEAR' then call fail 'rack'

/* Springs */
ext = .CommonParts~extensionSpring
if ext~geometry['FORM'] <> 'HELICAL_EXTENSION' then call fail 'ext spring'
tor = .CommonParts~torsionSpring
if tor~geometry['FORM'] <> 'HELICAL_TORSION' then call fail 'torsion spring'

/* Structural */
bar = .CommonParts~roundBar('12 mm','200 mm','SS-304-REFERENCE')
if bar~material('BODY') <> 'SS-304-REFERENCE' then call fail 'round bar mat'
sq = .CommonParts~squareBar
if sq~family <> 'STRUCTURAL_BAR' then call fail 'square bar'
ang = .CommonParts~angleStock
if ang~geometry['FORM'] <> 'ANGLE' then call fail 'angle'
shs = .CommonParts~squareHollowSection
if shs~geometry['FORM'] <> 'SHS' then call fail 'shs'
rhs = .CommonParts~rectangularHollowSection
if rhs~geometry['FORM'] <> 'RHS' then call fail 'rhs'
tub = .CommonParts~tube
if tub~geometry['FORM'] <> 'ROUND_TUBE' then call fail 'tube'

/* Packages */
dip = .CommonParts~packageDIP(16)
if dip~parameter('PINS') <> 16 then call fail 'dip pins'
to220 = .CommonParts~packageTO220
if to220~geometry['FORM'] <> 'TO-220' then call fail 'to220'
chip = .CommonParts~packageChip('0805')
if chip~geometry['LENGTH'] <> '2.0 mm' then call fail '0805'

/* Actuators */
mot = .CommonParts~brushedDCMotor
if mot~family <> 'MOTOR' then call fail 'dc motor'
stp = .CommonParts~nema17Stepper
if stp~geometry['FORM'] <> 'NEMA17' then call fail 'nema17'
srv = .CommonParts~hobbyServo
if srv~family <> 'SERVO' then call fail 'servo'
sol = .CommonParts~solenoid
if sol~family <> 'SOLENOID' then call fail 'solenoid'
rel = .CommonParts~relayPCB
if rel~family <> 'RELAY' then call fail 'relay'

/* Thermal / tools / sensors / batteries */
pad = .CommonParts~thermalPad
if pad~family <> 'THERMAL' then call fail 'thermal pad'
dr = .CommonParts~drillBit('3 mm')
if dr~family <> 'CUTTING_TOOL' then call fail 'drill'
em = .CommonParts~endMill
if em~parameter('FLUTES') <> 4 then call fail 'endmill'
tc = .CommonParts~thermocouple('K')
if tc~parameter('TYPE') <> 'K' then call fail 'tc'
rtd = .CommonParts~rtdPT100
if rtd~parameter('R0') <> '100 Ohm' then call fail 'rtd'
aa = .CommonParts~batteryAA
if aa~geometry['FORM'] <> 'AA_CELL' then call fail 'aa'
li = .CommonParts~battery18650
if li~parameter('CHEMISTRY') <> 'LI-ION' then call fail '18650'

/* Bench set material resolution */
bench = .CommonParts~standardBenchSet
checked = 0
do key over bench
  part = bench[key]
  do role over part~materials
    mid = part~materials[role]
    if mid = .nil | mid = '' then iterate
    if .CommonMaterials~byId(mid) = .nil then call fail 'unresolved' part~id role mid
    checked += 1
  end
end

if failCount > 0 then do
  say 'FAIL:' failCount 'checks failed'
  exit 1
end
say 'PASS dev5 extension' sizes~items 'bolt sizes, bench material refs' checked
exit 0

fail: procedure expose failCount
  parse arg msg
  say 'FAIL:' msg
  failCount += 1
  return

::requires 'PartsCatalog.cls'
