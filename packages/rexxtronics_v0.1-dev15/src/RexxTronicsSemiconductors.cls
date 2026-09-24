/* Rexx-tronics compact semiconductor devices v0.1-dev15.
 *
 * These are deliberately deterministic, inspectable piecewise-linear models,
 * not a hidden SPICE engine.  Exact part definitions are expected to supply
 * evidence-backed parameters (beta, junction knee, saturation voltage, etc.)
 * from a manufacturer datasheet when available.
 */

::class BipolarJunctionTransistor subclass ElectricalComponent public
::attribute polarity get
::attribute beta get
::attribute forwardVoltageVolts get
::attribute baseOnResistanceOhms get
::attribute saturationVoltageVolts get
::attribute saturationResistanceOhms get
::attribute offResistanceOhms get
::attribute state get
::attribute lastBaseCurrentAmps get
::attribute lastCollectorCurrentAmps get
::attribute lastEmitterCurrentAmps get
::attribute lastPowerWatts get

::method init
  expose polarity beta forwardVoltageVolts baseOnResistanceOhms saturationVoltageVolts saturationResistanceOhms offResistanceOhms hysteresisVolts state lastBaseCurrentAmps lastCollectorCurrentAmps lastEmitterCurrentAmps lastPowerWatts
  numeric digits 50
  use strict arg idArg, polarityArg='NPN', betaArg=100, forwardVoltageArg='0.7 V', baseOnResistanceArg='100 Ohm', saturationVoltageArg='0.2 V', saturationResistanceArg='10 Ohm', offResistanceArg=1000000000000, hysteresisArg='5 mV'

  polarity = polarityArg~string~upper
  if polarity <> 'NPN' & polarity <> 'PNP' then raise syntax 93.900 array('BJT polarity must be NPN or PNP')

  self~init:super(idArg, polarity || '_BJT')
  self~definePin(1, 'EMITTER', 'TERMINAL', 'SEMICONDUCTOR')
  self~definePin(2, 'BASE', 'CONTROL', 'SEMICONDUCTOR')
  self~definePin(3, 'COLLECTOR', 'TERMINAL', 'SEMICONDUCTOR')

  beta = .RexxTronicsUnits~ratio(betaArg, 'BJT beta')
  forwardVoltageVolts = .RexxTronicsUnits~canonical(forwardVoltageArg, .Units~volt, 'BJT base-emitter forward voltage')
  baseOnResistanceOhms = .RexxTronicsUnits~canonical(baseOnResistanceArg, .Units~ohm, 'BJT base-emitter on resistance')
  saturationVoltageVolts = .RexxTronicsUnits~canonical(saturationVoltageArg, .Units~volt, 'BJT saturation voltage')
  saturationResistanceOhms = .RexxTronicsUnits~canonical(saturationResistanceArg, .Units~ohm, 'BJT saturation resistance')
  offResistanceOhms = .RexxTronicsUnits~canonical(offResistanceArg, .Units~ohm, 'BJT off resistance')
  hysteresisVolts = .RexxTronicsUnits~canonical(hysteresisArg, .Units~volt, 'BJT switching hysteresis')

  if beta <= 0 then raise syntax 93.900 array('BJT beta must be positive')
  if forwardVoltageVolts < 0 then raise syntax 93.900 array('BJT forward voltage must not be negative')
  if baseOnResistanceOhms <= 0 | saturationResistanceOhms <= 0 | offResistanceOhms <= 0 then raise syntax 93.900 array('BJT resistances must be positive')
  if saturationVoltageVolts < 0 then raise syntax 93.900 array('BJT saturation voltage must not be negative')

  state = 'CUTOFF'
  lastBaseCurrentAmps = 0
  lastCollectorCurrentAmps = 0
  lastEmitterCurrentAmps = 0
  lastPowerWatts = 0

::method emitter
  return self~pin('EMITTER')

::method base
  return self~pin('BASE')

::method collector
  return self~pin('COLLECTOR')

::method polaritySign private
  expose polarity
  if polarity = 'NPN' then return 1
  return -1

::method baseCurrent
  expose lastBaseCurrentAmps
  return .Units~q(lastBaseCurrentAmps, .Units~ampere)

::method collectorCurrent
  expose lastCollectorCurrentAmps
  return .Units~q(lastCollectorCurrentAmps, .Units~ampere)

::method emitterCurrent
  expose lastEmitterCurrentAmps
  return .Units~q(lastEmitterCurrentAmps, .Units~ampere)

::method power
  expose lastPowerWatts
  return .Units~q(lastPowerWatts, .Units~watt)

::method forwardVoltage
  expose forwardVoltageVolts
  return .Units~q(forwardVoltageVolts, .Units~volt)

::method saturationVoltage
  expose saturationVoltageVolts
  return .Units~q(saturationVoltageVolts, .Units~volt)

::method electricalPathPeers
  expose state
  use strict arg pin
  if state = 'CUTOFF' then return .array~new
  if pin == self~emitter then return .array~of(self~base, self~collector)
  if pin == self~base then return .array~of(self~emitter)
  if pin == self~collector then return .array~of(self~emitter)
  return .array~new

/* Effective voltages are expressed in the forward direction of the selected
 * polarity.  For an NPN they are Vbe/Vce; for a PNP they are Veb/Vec.
 */
::method effectiveVoltages private
  use strict arg solution
  p = self~polaritySign
  vb = solution~voltage(self~base~net)
  ve = solution~voltage(self~emitter~net)
  vc = solution~voltage(self~collector~net)
  return .array~of(p * (vb - ve), p * (vc - ve))

::method desiredState private
  expose state forwardVoltageVolts saturationVoltageVolts hysteresisVolts
  use strict arg vbe, vce

  if state = 'CUTOFF' then do
    if vbe < forwardVoltageVolts then return 'CUTOFF'
    if vce <= saturationVoltageVolts then return 'SATURATED'
    return 'ACTIVE'
  end

  if vbe < forwardVoltageVolts - hysteresisVolts then return 'CUTOFF'

  if state = 'SATURATED' then do
    if vce <= saturationVoltageVolts + 2 * hysteresisVolts then return 'SATURATED'
    return 'ACTIVE'
  end

  if vce <= saturationVoltageVolts + hysteresisVolts then return 'SATURATED'
  return 'ACTIVE'

::method stampBaseJunction private
  expose forwardVoltageVolts baseOnResistanceOhms
  use strict arg context
  p = self~polaritySign
  g = 1 / baseOnResistanceOhms
  context~stampConductance(self~base, self~emitter, g)
  /* i(B->E) = g*(Vb-Ve) - p*g*Vbe(on). */
  context~stampCurrent(self~base, self~emitter, -p * g * forwardVoltageVolts)
  return .true

::method dcStamp
  expose state beta baseOnResistanceOhms saturationVoltageVolts saturationResistanceOhms offResistanceOhms forwardVoltageVolts
  numeric digits 50
  use strict arg context
  p = self~polaritySign
  goff = 1 / offResistanceOhms

  select
    when state = 'CUTOFF' then do
      context~stampConductance(self~base, self~emitter, goff)
      context~stampConductance(self~collector, self~emitter, goff)
    end

    when state = 'ACTIVE' then do
      self~stampBaseJunction(context)
      /* A tiny output leakage conductance keeps an otherwise floating
       * collector numerically defined without changing the active law.
       */
      context~stampConductance(self~collector, self~emitter, goff)
      gm = beta / baseOnResistanceOhms
      /* i(C->E) = gm*(Vb-Ve) - p*gm*Vbe(on). */
      context~stampVCCS(self~collector, self~emitter, self~base, self~emitter, gm)
      context~stampCurrent(self~collector, self~emitter, -p * gm * forwardVoltageVolts)
    end

    when state = 'SATURATED' then do
      self~stampBaseJunction(context)
      gsat = 1 / saturationResistanceOhms
      /* i(C->E) = gsat*(Vc-Ve) - p*gsat*Vce(sat). */
      context~stampConductance(self~collector, self~emitter, gsat)
      context~stampCurrent(self~collector, self~emitter, -p * gsat * saturationVoltageVolts)
    end

    otherwise raise syntax 93.900 array('unknown BJT operating state ' || state)
  end
  return .true

::method dcNeedsResolve
  expose state forwardVoltageVolts baseOnResistanceOhms beta saturationVoltageVolts saturationResistanceOhms hysteresisVolts
  numeric digits 50
  use strict arg solution
  v = self~effectiveVoltages(solution)
  vbe = v[1]
  vce = v[2]

  if vbe < forwardVoltageVolts - hysteresisVolts then desired = 'CUTOFF'
  else if state = 'SATURATED' then do
    /* A saturated solve naturally has Vce slightly above the knee because the
     * configured saturation resistance carries load current.  Deciding from
     * Vce alone would therefore chatter ACTIVE<->SATURATED forever.  Compare
     * the collector current the base drive requests with what the saturated
     * branch/load can actually carry at this solution.
     */
    ibEff = (vbe - forwardVoltageVolts) / baseOnResistanceOhms
    if ibEff < 0 then ibEff = 0
    activeDemand = beta * ibEff
    saturatedCapacity = (vce - saturationVoltageVolts) / saturationResistanceOhms
    if saturatedCapacity < 0 then saturatedCapacity = 0
    if activeDemand > saturatedCapacity then desired = 'SATURATED'
    else desired = 'ACTIVE'
  end
  else if vbe < forwardVoltageVolts then desired = 'CUTOFF'
  else if vce <= saturationVoltageVolts + hysteresisVolts then desired = 'SATURATED'
  else desired = 'ACTIVE'

  if desired = state then return .false
  state = desired
  return .true

::method dcUpdate
  expose state beta forwardVoltageVolts baseOnResistanceOhms saturationVoltageVolts saturationResistanceOhms offResistanceOhms lastBaseCurrentAmps lastCollectorCurrentAmps lastEmitterCurrentAmps lastPowerWatts
  numeric digits 50
  use strict arg solution
  p = self~polaritySign
  vb = solution~voltage(self~base~net)
  ve = solution~voltage(self~emitter~net)
  vc = solution~voltage(self~collector~net)

  select
    when state = 'CUTOFF' then do
      lastBaseCurrentAmps = (vb - ve) / offResistanceOhms
      lastCollectorCurrentAmps = (vc - ve) / offResistanceOhms
    end
    when state = 'ACTIVE' then do
      lastBaseCurrentAmps = (vb - ve) / baseOnResistanceOhms - p * forwardVoltageVolts / baseOnResistanceOhms
      lastCollectorCurrentAmps = beta * lastBaseCurrentAmps + (vc - ve) / offResistanceOhms
    end
    when state = 'SATURATED' then do
      lastBaseCurrentAmps = (vb - ve) / baseOnResistanceOhms - p * forwardVoltageVolts / baseOnResistanceOhms
      lastCollectorCurrentAmps = (vc - ve) / saturationResistanceOhms - p * saturationVoltageVolts / saturationResistanceOhms
    end
    otherwise raise syntax 93.900 array('unknown BJT operating state ' || state)
  end

  /* Pin-current convention: base and collector currents are positive into
   * their named pins; emitter current is positive into the emitter pin.
   * KCL therefore makes Ie = -(Ib + Ic).
   */
  lastEmitterCurrentAmps = -(lastBaseCurrentAmps + lastCollectorCurrentAmps)
  lastPowerWatts = (vb - ve) * lastBaseCurrentAmps + (vc - ve) * lastCollectorCurrentAmps
  solution~setCurrent(self, lastCollectorCurrentAmps)
  solution~setPower(self, lastPowerWatts)
  return .true


::class NPNTransistor subclass BipolarJunctionTransistor public
::method init
  use strict arg idArg, betaArg=100, forwardVoltageArg='0.7 V', baseOnResistanceArg='100 Ohm', saturationVoltageArg='0.2 V', saturationResistanceArg='10 Ohm', offResistanceArg=1000000000000
  self~init:super(idArg, 'NPN', betaArg, forwardVoltageArg, baseOnResistanceArg, saturationVoltageArg, saturationResistanceArg, offResistanceArg)


::class PNPTransistor subclass BipolarJunctionTransistor public
::method init
  use strict arg idArg, betaArg=100, forwardVoltageArg='0.7 V', baseOnResistanceArg='100 Ohm', saturationVoltageArg='0.2 V', saturationResistanceArg='10 Ohm', offResistanceArg=1000000000000
  self~init:super(idArg, 'PNP', betaArg, forwardVoltageArg, baseOnResistanceArg, saturationVoltageArg, saturationResistanceArg, offResistanceArg)


::requires 'RexxTronicsDC.cls'
