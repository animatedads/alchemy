/* Qualification: compact piecewise-linear BJT model covers cutoff, forward-active,
 * saturation and both NPN/PNP polarity conventions without a hidden SPICE core.
 */
numeric digits 50

/* NPN forward-active. */
c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', '5 V'))
rc = c~add(.Resistor~new('RC', '1 kOhm'))
rb = c~add(.Resistor~new('RB', '220 kOhm'))
q = c~add(.NPNTransistor~new('Q1', 100))
c~connectGround(v~negative)
c~connectGround(q~emitter)
c~connect('VCC', .array~of(v~positive, rc~pin('A'), rb~pin('A')))
c~connect('COLLECTOR', .array~of(rc~pin('B'), q~collector))
c~connect('BASE', .array~of(rb~pin('B'), q~base))
s = c~solveDC
if q~state <> 'ACTIVE' then do; say 'FAIL: NPN active state' q~state; exit 1; end
if q~baseCurrent~in(.Units~ampere) <= 0 then do; say 'FAIL: NPN base current sign'; exit 1; end
if q~collectorCurrent~in(.Units~ampere) <= 0 then do; say 'FAIL: NPN collector current sign'; exit 1; end
ratio = q~collectorCurrent~in(.Units~ampere) / q~baseCurrent~in(.Units~ampere)
if abs(ratio - 100) > 0.001 then do; say 'FAIL: NPN active beta' ratio; exit 1; end
if s~voltage('COLLECTOR') <= '0.2' then do; say 'FAIL: NPN active collector too low' s~voltage('COLLECTOR'); exit 1; end

/* NPN saturation under strong base drive. */
cs = .Circuit~new
vs = cs~add(.DCVoltageSource~new('V1', '5 V'))
rcs = cs~add(.Resistor~new('RC', '1 kOhm'))
rbs = cs~add(.Resistor~new('RB', '10 kOhm'))
qs = cs~add(.NPNTransistor~new('Q1', 100))
cs~connectGround(vs~negative)
cs~connectGround(qs~emitter)
cs~connect('VCC', .array~of(vs~positive, rcs~pin('A'), rbs~pin('A')))
cs~connect('COLLECTOR', .array~of(rcs~pin('B'), qs~collector))
cs~connect('BASE', .array~of(rbs~pin('B'), qs~base))
ss = cs~solveDC
if qs~state <> 'SATURATED' then do; say 'FAIL: NPN saturation state' qs~state; exit 1; end
if ss~voltage('COLLECTOR') > '0.30' then do; say 'FAIL: NPN saturated Vce' ss~voltage('COLLECTOR'); exit 1; end

/* NPN cutoff. */
co = .Circuit~new
vo = co~add(.DCVoltageSource~new('V1', '5 V'))
rco = co~add(.Resistor~new('RC', '1 kOhm'))
rbo = co~add(.Resistor~new('RB', '100 kOhm'))
qo = co~add(.NPNTransistor~new('Q1', 100))
co~connectGround(vo~negative)
co~connectGround(qo~emitter)
co~connectGround(rbo~pin('A'))
co~connect('VCC', .array~of(vo~positive, rco~pin('A')))
co~connect('COLLECTOR', .array~of(rco~pin('B'), qo~collector))
co~connect('BASE', .array~of(rbo~pin('B'), qo~base))
so = co~solveDC
if qo~state <> 'CUTOFF' then do; say 'FAIL: NPN cutoff state' qo~state; exit 1; end
if abs(qo~collectorCurrent~in(.Units~ampere)) > 0.000000001 then do; say 'FAIL: NPN cutoff leakage' qo~collectorCurrent; exit 1; end

/* PNP forward-active mirrors the polarity and current signs. */
cp = .Circuit~new
vp = cp~add(.DCVoltageSource~new('V1', '5 V'))
rpc = cp~add(.Resistor~new('RC', '1 kOhm'))
rpb = cp~add(.Resistor~new('RB', '220 kOhm'))
qp = cp~add(.PNPTransistor~new('Q1', 100))
cp~connectGround(vp~negative)
cp~connect('VCC', .array~of(vp~positive, qp~emitter))
cp~connectGround(rpc~pin('B'))
cp~connectGround(rpb~pin('B'))
cp~connect('COLLECTOR', .array~of(rpc~pin('A'), qp~collector))
cp~connect('BASE', .array~of(rpb~pin('A'), qp~base))
sp = cp~solveDC
if qp~state <> 'ACTIVE' then do; say 'FAIL: PNP active state' qp~state; exit 1; end
if qp~baseCurrent~in(.Units~ampere) >= 0 then do; say 'FAIL: PNP base current sign'; exit 1; end
if qp~collectorCurrent~in(.Units~ampere) >= 0 then do; say 'FAIL: PNP collector current sign'; exit 1; end
pratio = qp~collectorCurrent~in(.Units~ampere) / qp~baseCurrent~in(.Units~ampere)
if abs(pratio - 100) > 0.001 then do; say 'FAIL: PNP active beta' pratio; exit 1; end

say 'REXX-TRONICS BJT PIECEWISE-LINEAR MODEL: OK'
say 'NPN active Ic mA:' q~collectorCurrent~in(.Units~milliampere)
say 'NPN active Ib uA:' q~baseCurrent~in(.Units~microampere)
say 'NPN saturation Vce:' ss~voltage('COLLECTOR') 'V'
say 'PNP active Ic mA:' qp~collectorCurrent~in(.Units~milliampere)
exit 0

::requires 'RexxTronicsSemiconductors.cls'
