/* Rexx-tronics initial executable devices v0.1-dev15 */

::class DigitalOscillator public
::attribute name get
::attribute output get
::attribute frequencyHz get
::attribute highVoltage get
::attribute lowVoltage get
::attribute running get

::method init
  expose name clock output frequencyHz highVoltage lowVoltage halfPeriodPs running highState
  numeric digits 50
  use strict arg nameArg, clockArg, frequencyArg, highArg=5, lowArg=0
  name = nameArg~string
  clock = clockArg
  frequencyHz = .RexxTronicsUnits~canonical(frequencyArg, .Units~hertz, 'oscillator frequency')
  if frequencyHz <= 0 then raise syntax 93.900 array('oscillator frequency must be positive')
  highVoltage = .RexxTronicsUnits~canonical(highArg, .Units~volt, 'oscillator high voltage')
  lowVoltage = .RexxTronicsUnits~canonical(lowArg, .Units~volt, 'oscillator low voltage')
  halfPeriodPs = (.SimTime~PS_PER_S / (frequencyHz * 2))~round
  if halfPeriodPs <= 0 then raise syntax 93.900 array('oscillator period is below simulation time resolution')
  output = .Pin~new(1, 'OUT', 'OUTPUT', 'PUSH_PULL')
  running = .false
  highState = .false

::method frequency
  expose frequencyHz
  return .Units~q(frequencyHz, .Units~hertz)

::method highVoltageQuantity
  expose highVoltage
  return .Units~q(highVoltage, .Units~volt)

::method lowVoltageQuantity
  expose lowVoltage
  return .Units~q(lowVoltage, .Units~volt)

::method periodPs
  expose frequencyHz
  numeric digits 50
  return (.SimTime~PS_PER_S / frequencyHz)~round

::method period
  expose frequencyHz
  return .Units~q(1 / frequencyHz, .Units~second)

::method start
  expose clock output lowVoltage running highState
  numeric digits 50
  if running then return self
  if output~net == .nil then raise syntax 93.900 array('oscillator output pin is not connected')
  running = .true
  highState = .false
  output~net~drive(clock~now, output, lowVoltage, 'oscillator start')
  self~scheduleToggle
  return self

::method stop
  expose running
  numeric digits 50
  running = .false
  return self

::method scheduleToggle private
  expose clock halfPeriodPs running
  numeric digits 50
  if \running then return
  clock~scheduleAfter(halfPeriodPs, self, 'TOGGLE')

::method toggle
  expose clock output highVoltage lowVoltage running highState
  numeric digits 50
  if \running then return
  highState = \highState
  if highState then value = highVoltage
  else value = lowVoltage
  output~net~drive(clock~now, output, value, 'oscillator toggle')
  self~scheduleToggle

::class ScopeSample public
::attribute timePs get
::attribute voltage get

::method init
  expose timePs voltage
  numeric digits 50
  use strict arg timeArg, voltageArg
  timePs = .RexxTronicsUnits~timePicoseconds(timeArg)
  voltage = .RexxTronicsUnits~canonical(voltageArg, .Units~volt, 'scope sample voltage')

::method voltageQuantity
  expose voltage
  return .Units~q(voltage, .Units~volt)

::method time
  expose timePs
  return .Units~q(timePs / .SimTime~PS_PER_S, .Units~second)

::class OscilloscopeTrace public
::attribute samples get
::attribute sampleIntervalPs get

::method init
  expose samples sampleIntervalPs
  numeric digits 50
  use strict arg samplesArg, sampleIntervalArg
  samples = samplesArg
  sampleIntervalPs = .RexxTronicsUnits~timePicoseconds(sampleIntervalArg)

::method sampleInterval
  expose sampleIntervalPs
  return .Units~q(sampleIntervalPs / .SimTime~PS_PER_S, .Units~second)

::method measuredFrequency
  expose samples
  numeric digits 50
  use strict arg threshold=2.5
  threshold = .RexxTronicsUnits~canonical(threshold, .Units~volt, 'scope threshold')
  rising = .array~new
  if samples~items < 2 then return .nil
  previous = samples[1]
  do i = 2 to samples~items
    current = samples[i]
    if previous~voltage < threshold & current~voltage >= threshold then rising~append(current~timePs)
    previous = current
  end
  if rising~items < 2 then return .nil
  totalPeriod = 0
  do i = 2 to rising~items
    totalPeriod += rising[i] - rising[i-1]
  end
  averagePeriod = totalPeriod / (rising~items - 1)
  if averagePeriod <= 0 then return .nil
  return .SimTime~PS_PER_S / averagePeriod

::method measuredFrequencyQuantity
  use strict arg threshold=2.5
  hz = self~measuredFrequency(threshold)
  if hz == .nil then return .nil
  return .Units~q(hz, .Units~hertz)

::method minVoltage
  expose samples
  numeric digits 50
  if samples~items = 0 then return .nil
  v = samples[1]~voltage
  do s over samples
    if s~voltage < v then v = s~voltage
  end
  return v

::method maxVoltage
  expose samples
  numeric digits 50
  if samples~items = 0 then return .nil
  v = samples[1]~voltage
  do s over samples
    if s~voltage > v then v = s~voltage
  end
  return v

::method minVoltageQuantity
  value = self~minVoltage
  if value == .nil then return .nil
  return .Units~q(value, .Units~volt)

::method maxVoltageQuantity
  value = self~maxVoltage
  if value == .nil then return .nil
  return .Units~q(value, .Units~volt)

::class VirtualOscilloscope public
::method acquire
  use strict arg net, startTime, duration, sampleRateHz
  return self~acquireSignal(net, startTime, duration, sampleRateHz)

::method acquireSignal
  numeric digits 50
  use strict arg signal, startTime, duration, sampleRateHz
  if \signal~hasMethod('VOLTAGEAT') then raise syntax 93.900 array('scope signal must implement voltageAt(time)')
  startPs = .RexxTronicsUnits~timePicoseconds(startTime)
  durationPs = .RexxTronicsUnits~timePicoseconds(duration)
  sampleRateHz = .RexxTronicsUnits~canonical(sampleRateHz, .Units~hertz, 'scope sample rate')
  if sampleRateHz <= 0 then raise syntax 93.900 array('sample rate must be positive')
  intervalPs = (.SimTime~PS_PER_S / sampleRateHz)~round
  if intervalPs <= 0 then raise syntax 93.900 array('sample interval is below simulation time resolution')
  finishPs = startPs + durationPs
  samples = .array~new
  t = startPs
  do while t <= finishPs
    samples~append(.ScopeSample~new(t, signal~voltageAt(t)))
    t += intervalPs
  end
  return .OscilloscopeTrace~new(samples, intervalPs)

::requires 'RexxTronicsTime.cls'
::requires 'RexxTronicsElectrical.cls'
