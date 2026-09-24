/* Rexx-tronics electrically meaningful display devices v0.1-dev15. */

::class SevenSegmentDisplay subclass ElectricalComponent public
::attribute commonType get
::attribute forwardVoltageVolts get
::attribute segmentResistanceOhms get
::attribute offResistanceOhms get
::attribute lightThresholdAmps get

::method init
  expose commonType forwardVoltageVolts segmentResistanceOhms offResistanceOhms lightThresholdAmps hysteresisVolts segmentStates segmentCurrents lastPowerWatts
  numeric digits 50
  use strict arg idArg, commonTypeArg='COMMON_CATHODE', forwardVoltageArg='1.7 V', segmentResistanceArg='1 kOhm', lightThresholdArg='0.5 mA', offResistanceArg=1000000000000, hysteresisArg='1 mV'
  self~init:super(idArg, 'SEVEN_SEGMENT_DISPLAY')

  commonType = commonTypeArg~string~upper
  if commonType <> 'COMMON_CATHODE' & commonType <> 'COMMON_ANODE' then raise syntax 93.900 array('seven-segment common type must be COMMON_CATHODE or COMMON_ANODE')
  forwardVoltageVolts = .RexxTronicsUnits~canonical(forwardVoltageArg, .Units~volt, 'display segment forward voltage')
  segmentResistanceOhms = .RexxTronicsUnits~canonical(segmentResistanceArg, .Units~ohm, 'display segment series resistance')
  offResistanceOhms = .RexxTronicsUnits~canonical(offResistanceArg, .Units~ohm, 'display segment off resistance')
  lightThresholdAmps = .RexxTronicsUnits~canonical(lightThresholdArg, .Units~ampere, 'display segment light threshold')
  hysteresisVolts = .RexxTronicsUnits~canonical(hysteresisArg, .Units~volt, 'display segment switching hysteresis')
  if forwardVoltageVolts < 0 then raise syntax 93.900 array('display forward voltage must not be negative')
  if segmentResistanceOhms <= 0 | offResistanceOhms <= 0 then raise syntax 93.900 array('display segment resistances must be positive')
  if lightThresholdAmps < 0 then raise syntax 93.900 array('display light threshold must not be negative')

  do seg over self~segmentNames
    self~definePin(seg, seg, 'SEGMENT', 'LED_INPUT')
  end
  self~definePin(8, 'COM', 'COMMON', 'LED_COMMON')

  segmentStates = .directory~new
  segmentCurrents = .directory~new
  do seg over self~segmentNames
    segmentStates[seg] = 'OFF'
    segmentCurrents[seg] = 0
  end
  lastPowerWatts = 0

::method segmentNames
  return .array~of('A','B','C','D','E','F','G')

::method common
  return self~pin('COM')

::method polaritySign private
  expose commonType
  if commonType = 'COMMON_CATHODE' then return 1
  return -1

::method segmentPin
  use strict arg segment
  return self~pin(segment~string~upper)

::method segmentState
  expose segmentStates
  use strict arg segment
  key = segment~string~upper
  if \segmentStates~hasIndex(key) then raise syntax 93.900 array('unknown display segment ' || key)
  return segmentStates[key]

::method segmentCurrent
  expose segmentCurrents
  use strict arg segment
  key = segment~string~upper
  if \segmentCurrents~hasIndex(key) then raise syntax 93.900 array('unknown display segment ' || key)
  return .Units~q(segmentCurrents[key], .Units~ampere)

::method segmentLit
  expose segmentCurrents lightThresholdAmps
  use strict arg segment
  key = segment~string~upper
  if \segmentCurrents~hasIndex(key) then raise syntax 93.900 array('unknown display segment ' || key)
  return abs(segmentCurrents[key]) >= lightThresholdAmps

::method litSegments
  out = .array~new
  do seg over self~segmentNames
    if self~segmentLit(seg) then out~append(seg)
  end
  return out

::method displayedDigit
  pattern = ''
  do seg over self~segmentNames
    if self~segmentLit(seg) then pattern ||= '1'
    else pattern ||= '0'
  end
  select
    when pattern = '1111110' then return 0
    when pattern = '0110000' then return 1
    when pattern = '1101101' then return 2
    when pattern = '1111001' then return 3
    when pattern = '0110011' then return 4
    when pattern = '1011011' then return 5
    when pattern = '1011111' then return 6
    when pattern = '1110000' then return 7
    when pattern = '1111111' then return 8
    when pattern = '1111011' then return 9
    otherwise return .nil
  end

::method power
  expose lastPowerWatts
  return .Units~q(lastPowerWatts, .Units~watt)

::method electricalPathPeers
  expose segmentStates
  use strict arg pin
  if pin == self~common then do
    peers = .array~new
    do seg over self~segmentNames
      if segmentStates[seg] = 'FORWARD' then peers~append(self~segmentPin(seg))
    end
    return peers
  end
  do seg over self~segmentNames
    if pin == self~segmentPin(seg) then do
      if segmentStates[seg] = 'FORWARD' then return .array~of(self~common)
      return .array~new
    end
  end
  return .array~new

::method dcStamp
  expose segmentStates forwardVoltageVolts segmentResistanceOhms offResistanceOhms
  numeric digits 50
  use strict arg context
  p = self~polaritySign
  do seg over self~segmentNames
    sp = self~segmentPin(seg)
    if segmentStates[seg] = 'FORWARD' then do
      g = 1 / segmentResistanceOhms
      context~stampConductance(sp, self~common, g)
      /* i(segment -> COM) = g*(Vsegment-Vcom) - p*g*Vf. */
      context~stampCurrent(sp, self~common, -p * g * forwardVoltageVolts)
    end
    else context~stampConductance(sp, self~common, 1 / offResistanceOhms)
  end
  return .true

::method dcNeedsResolve
  expose segmentStates forwardVoltageVolts hysteresisVolts
  numeric digits 50
  use strict arg solution
  p = self~polaritySign
  vcom = solution~voltage(self~common~net)
  changed = .false
  do seg over self~segmentNames
    vs = solution~voltage(self~segmentPin(seg)~net)
    effective = p * (vs - vcom)
    old = segmentStates[seg]
    if old = 'FORWARD' & effective >= forwardVoltageVolts - hysteresisVolts then desired = 'FORWARD'
    else if effective >= forwardVoltageVolts then desired = 'FORWARD'
    else desired = 'OFF'
    if desired <> old then do
      segmentStates[seg] = desired
      changed = .true
    end
  end
  return changed

::method dcUpdate
  expose segmentStates segmentCurrents forwardVoltageVolts segmentResistanceOhms offResistanceOhms lastPowerWatts
  numeric digits 50
  use strict arg solution
  p = self~polaritySign
  vcom = solution~voltage(self~common~net)
  totalSigned = 0
  totalPower = 0
  do seg over self~segmentNames
    vs = solution~voltage(self~segmentPin(seg)~net)
    dv = vs - vcom
    if segmentStates[seg] = 'FORWARD' then i = dv / segmentResistanceOhms - p * forwardVoltageVolts / segmentResistanceOhms
    else i = dv / offResistanceOhms
    segmentCurrents[seg] = i
    totalSigned += i
    totalPower += dv * i
  end
  lastPowerWatts = totalPower
  solution~setCurrent(self, totalSigned)
  solution~setPower(self, totalPower)
  return .true

::requires 'RexxTronicsDC.cls'
