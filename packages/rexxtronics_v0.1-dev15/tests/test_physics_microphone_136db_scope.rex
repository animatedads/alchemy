/* Physics pressure -> Rexx-tronics microphone -> virtual oscilloscope.
 * The 136 dB value is specified at the microphone, so this test does not make
 * assumptions about a human source's distance/directivity/acoustic power.
 */
numeric digits 50
referencePa = '0.00002'
splDb = 136
pressureRms = referencePa * RxCalcExp((splDb / 20) * RxCalcLog(10,40),40)
frequency = 1000
sampleRate = 96000
duration = '0.010'
pi = 4 * RxCalcArcTan(1, 40, 'R')
root2 = RxCalcSqrt(2, 40)
count = (duration * sampleRate)~trunc
samples = .array~new
do i = 0 to count - 1
  t = i / sampleRate
  samples~append(root2 * pressureRms * RxCalcSin(2*pi*frequency*t, 40, 'R'))
end
buffer = .AcousticSampleBuffer~new(samples, .Units~q(sampleRate,.Units~hertz), .Units~q(0,.Units~second))

sensitivityUnit = .Units~volt / .Units~pascal
mic = .LinearMicrophoneTransducer~new('MIC1', .Units~q('0.010', sensitivityUnit), '2.5 V', '0 V', '5 V')
mic~bindAcousticBuffer(buffer)

scope = .VirtualOscilloscope~new
/* Last physical pressure sample is at (count-1)/rate, not at buffer duration. */
traceDurationPs = (((count-1) * .SimTime~PS_PER_S) / sampleRate)~round
trace = scope~acquireSignal(mic, 0, traceDurationPs, .Units~q(sampleRate,.Units~hertz))
measured = trace~measuredFrequency('2.5 V')
if abs(measured-frequency) > '0.001' then do
  say 'FAIL scope frequency actual='measured 'expected='frequency
  exit 1
end

/* A 136 dB SPL pressure is exactly recoverable from the buffer definition. */
actualDb = buffer~rmsSplDb(referencePa)
if abs(actualDb-splDb) > '0.000000001' then do
  say 'FAIL SPL actual='actualDb 'expected='splDb
  exit 1
end
expectedPeak = '2.5' + '0.010' * root2 * pressureRms
if abs(trace~maxVoltage-expectedPeak) > '0.0001' then do
  say 'FAIL microphone peak voltage actual='trace~maxVoltage 'expected='expectedPeak
  exit 1
end
say 'REXX-TRONICS PHYSICS MICROPHONE 136 dB -> SCOPE: OK'
say 'pressure RMS Pa:' pressureRms
say 'scope frequency Hz:' measured
say 'scope min/max V:' trace~minVoltage trace~maxVoltage
exit 0

::requires 'RexxTronicsAcoustics.cls'
::requires 'Acoustics.cls'
::requires 'rxmath' LIBRARY
