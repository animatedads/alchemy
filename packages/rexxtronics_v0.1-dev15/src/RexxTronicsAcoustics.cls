/* Rexx-tronics <-> ooRexx Physics acoustic/electrical bridge v0.1-dev15.
 *
 * Physics owns acoustic propagation and pressure samples.  Rexx-tronics owns
 * the electrical transducer and circuit.  This first microphone model is an
 * explicitly ideal, flat, linear pressure-to-voltage transfer.  It is intended
 * as a qualification surface and a base for exact part-number definitions;
 * it is not a claim that all microphones have flat response or infinite
 * dynamic range.
 */

::class LinearMicrophoneTransducer subclass TwoTerminalComponent public
::attribute sensitivityVoltsPerPascal get
::attribute biasVolts get
::attribute lowerRailVolts get
::attribute upperRailVolts get
::attribute interpolation get
::attribute acousticBuffer get
::attribute lastPressurePascals get
::attribute lastOutputVolts get

::method init
  expose sensitivityVoltsPerPascal biasVolts lowerRailVolts upperRailVolts interpolation acousticBuffer lastPressurePascals lastOutputVolts
  numeric digits 50
  use strict arg idArg, sensitivityArg, biasArg='0 V', lowerRailArg=.nil, upperRailArg=.nil, interpolationArg='LINEAR'
  self~init:super(idArg, 'MICROPHONE_TRANSDUCER', 'OUT', 'REF')

  sensitivityUnit = .Units~volt / .Units~pascal
  sensitivityVoltsPerPascal = .RexxTronicsUnits~canonical(sensitivityArg, sensitivityUnit, 'microphone sensitivity')
  biasVolts = .RexxTronicsUnits~canonical(biasArg, .Units~volt, 'microphone bias')
  if lowerRailArg == .nil then lowerRailVolts = .nil
  else lowerRailVolts = .RexxTronicsUnits~canonical(lowerRailArg, .Units~volt, 'microphone lower rail')
  if upperRailArg == .nil then upperRailVolts = .nil
  else upperRailVolts = .RexxTronicsUnits~canonical(upperRailArg, .Units~volt, 'microphone upper rail')
  if lowerRailVolts <> .nil & upperRailVolts <> .nil then do
    if lowerRailVolts >= upperRailVolts then raise syntax 93.900 array('microphone lower rail must be below upper rail')
  end
  interpolation = interpolationArg~string~upper
  if interpolation <> 'LINEAR' & interpolation <> 'HOLD' then -
      raise syntax 93.900 array('microphone interpolation must be LINEAR or HOLD')
  acousticBuffer = .nil
  lastPressurePascals = 0
  lastOutputVolts = biasVolts

::method output
  return self~pin('OUT')

::method reference
  return self~pin('REF')

::method sensitivity
  expose sensitivityVoltsPerPascal
  return .Units~q(sensitivityVoltsPerPascal, .Units~volt / .Units~pascal)

::method bias
  expose biasVolts
  return .Units~q(biasVolts, .Units~volt)

::method bindAcousticBuffer
  expose acousticBuffer
  use strict arg buffer
  if \buffer~hasMethod('PRESSUREAT') | \buffer~hasMethod('SAMPLERATEHZ') | \buffer~hasMethod('SAMPLECOUNT') | \buffer~hasMethod('STARTTIME') then -
      raise syntax 93.900 array('microphone acoustic source must implement AcousticSampleBuffer pressure/sample-rate/start-time surface')
  if buffer~sampleRateHz <= 0 then raise syntax 93.900 array('microphone acoustic buffer sample rate must be positive')
  if buffer~sampleCount < 1 then raise syntax 93.900 array('microphone acoustic buffer must contain at least one pressure sample')
  acousticBuffer = buffer
  return self

::method pressureAt
  expose acousticBuffer interpolation
  numeric digits 50
  use strict arg timeArg
  if acousticBuffer == .nil then raise syntax 93.900 array('microphone has no bound acoustic buffer')

  timeSeconds = .RexxTronicsUnits~timePicoseconds(timeArg) / .SimTime~PS_PER_S
  start = acousticBuffer~startTime
  rate = acousticBuffer~sampleRateHz
  count = acousticBuffer~sampleCount
  relativeSample = (timeSeconds - start) * rate
  epsilon = '0.000001'
  if relativeSample < -epsilon | relativeSample > (count - 1) + epsilon then -
      raise syntax 93.900 array('microphone observation time lies outside bound acoustic buffer')
  if relativeSample < 0 then relativeSample = 0
  if relativeSample > count - 1 then relativeSample = count - 1

  leftZero = relativeSample~trunc
  leftIndex = leftZero + 1
  fraction = relativeSample - leftZero
  p1 = acousticBuffer~pressureAt(leftIndex)
  if interpolation = 'HOLD' | leftIndex >= count | fraction = 0 then return p1
  p2 = acousticBuffer~pressureAt(leftIndex + 1)
  return p1 + fraction * (p2 - p1)

::method pressureQuantityAt
  use strict arg timeArg
  return .Units~q(self~pressureAt(timeArg), .Units~pascal)

::method unclippedVoltageForPressure private
  expose sensitivityVoltsPerPascal biasVolts
  use strict arg pressurePascals
  return biasVolts + sensitivityVoltsPerPascal * pressurePascals

::method clampVoltage private
  expose lowerRailVolts upperRailVolts
  use strict arg value
  if lowerRailVolts <> .nil then if value < lowerRailVolts then value = lowerRailVolts
  if upperRailVolts <> .nil then if value > upperRailVolts then value = upperRailVolts
  return value

::method voltageAt
  expose lastPressurePascals lastOutputVolts
  numeric digits 50
  use strict arg timeArg
  pressure = self~pressureAt(timeArg)
  value = self~clampVoltage(self~unclippedVoltageForPressure(pressure))
  lastPressurePascals = pressure
  lastOutputVolts = value
  return value

::method voltageQuantityAt
  use strict arg timeArg
  return .Units~q(self~voltageAt(timeArg), .Units~volt)

::method dcExtraEquations
  return 1

::method transientExtraEquations
  return 1

::method dcStamp
  expose biasVolts
  use strict arg context
  context~stampVoltageSource(self, self~output, self~reference, biasVolts)
  return .true

::method transientStamp
  use strict arg context, deltaSeconds, timePs
  context~stampVoltageSource(self, self~output, self~reference, self~voltageAt(timePs))
  return .true

::method dcUpdate
  use strict arg solution
  i = solution~current(self)
  if i == .nil then return .true
  vp = solution~voltage(self~output~net)
  vn = solution~voltage(self~reference~net)
  solution~setPower(self, (vp - vn) * i)
  return .true

::method electricalPathPeers
  use strict arg pin
  if pin == self~output then return .array~of(self~reference)
  if pin == self~reference then return .array~of(self~output)
  return .array~new

::requires 'RexxTronicsDC.cls'
::requires 'RexxTronicsDevices.cls'
