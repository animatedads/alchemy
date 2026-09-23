numeric digits 50
failures = 0

/* DC: ideal inductor is a short and branch current remains observable. */
dc = .Circuit~new
vd = dc~add(.DCVoltageSource~new('VDC', .Units~q(5, .Units~volt)))
rd = dc~add(.Resistor~new('RDC', .Units~q(1, .Units~kiloohm)))
ld = dc~add(.Inductor~new('LDC', .Units~q(1, .Units~henry)))
dc~connect('VCC', .array~of(vd~positive, rd~pin('A')))
dc~connect('RL', .array~of(rd~pin('B'), ld~pin('A')))
dc~connectGround(ld~pin('B'))
dc~connectGround(vd~negative)
dcs = dc~solveDC
call near dcs~currentQuantity(ld)~in(.Units~milliampere), 5, 'DC inductor current', '0.0000001'
call near dcs~voltageQuantity('RL')~in(.Units~volt), 0, 'DC inductor voltage', '0.0000001'

/* Transient: 5 V step through 1 kohm / 1 H. tau = L/R = 1 ms. */
clock = .SimulationClock~new
c = .Circuit~new
v = c~add(.StepVoltageSource~new('VSTEP', '0 V', '5 V', '1 ms'))
r = c~add(.Resistor~new('R', '1 kΩ'))
l = c~add(.Inductor~new('L', '1000 mH', '0 A'))
c~connect('VCC', .array~of(v~positive, r~pin('A')))
c~connect('RL', .array~of(r~pin('B'), l~pin('A')))
c~connectGround(l~pin('B'))
c~connectGround(v~negative)
run = c~simulateTransient(clock, '6 ms', '0.01 ms')

before = run~currentAtQuantity(l, '0.99 ms')~in(.Units~milliampere)
oneTau = run~currentAtQuantity(l, '2 ms')~in(.Units~milliampere)
fiveTau = run~currentAtQuantity(l, '6 ms')~in(.Units~milliampere)
if abs(before) > '0.000001' then call fail 'inductor current changed before source step'
/* Backward Euler at 10 us should closely approach the analytic 3.1606 mA at one tau. */
call near oneTau, '3.1697464752475247524752475247524752475247524752475', 'RL current one tau', '0.03'
call near fiveTau, '4.966', 'RL current five tau', '0.02'
call near l~inductance~in(.Units~millihenry), 1000, 'inductance quantity', '0.0000001'
if l~storedEnergy~in(.Units~joule) <= 0 then call fail 'inductor stored energy should be positive'

if failures = 0 then do
  say 'REXX-TRONICS INDUCTOR TRANSIENT: OK'
  say 'one-tau current mA:' oneTau
  say 'five-tau current mA:' fiveTau
  say 'stored energy J:' l~storedEnergy~in(.Units~joule)
  exit 0
end
say 'FAIL inductor transient failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label, tolerance='0.00001'
  if abs(actual - expected) > tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected 'tolerance='tolerance
    failures += 1
  end
  return

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures += 1
  return

::requires 'RexxTronicsTransient.cls'
