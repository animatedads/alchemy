/* MIDI percussion -> Physics drum-kit performance adapter.
 * MIDI owns score/event truth; Physics owns drum mechanics and acoustic radiation.
 */
::class MidiDrumRenderResult public
::method init
  expose _samples _events _gauges _start _duration _sampleRate
  use strict arg samples,events,gauges,startSeconds,durationSeconds,sampleRate
  _samples=samples; _events=events; _gauges=gauges; _start=startSeconds; _duration=durationSeconds; _sampleRate=sampleRate
::method samples; expose _samples; return _samples
::method events; expose _events; return _events
::method gauges; expose _gauges; return _gauges
::method startSeconds; expose _start; return _start
::method durationSeconds; expose _duration; return _duration
::method sampleRate; expose _sampleRate; return _sampleRate

::class MidiDrumPerformer public
::method impulseFor class
  use strict arg note,velocity
  v=velocity/127
  if v<0 then v=0
  if v>1 then v=1
  select
    when note=35 | note=36 then base=.72
    when note=38 | note=40 then base=.25
    when note=41 | note=43 then base=.26
    when note=45 then base=.24
    when note=47 | note=48 then base=.21
    when note=50 then base=.18
    when note=42 | note=44 | note=46 then base=.115
    when note=49 | note=55 then base=.135
    when note=57 then base=.145
    when note=51 | note=53 | note=59 then base=.12
    otherwise return 0
  end
  return base*v*(.35+.65*v)

::method dispatch class
  use strict arg kit,note,velocity
  impulse=self~impulseFor(note,velocity)
  if impulse=0 then return .false
  select
    when note=35 | note=36 then kit~strike('kick',impulse,.20,0)
    when note=38 then kit~strike('snare',impulse,.30,0)
    when note=40 then kit~strike('snare',impulse,.62,.18)
    when note=41 | note=43 then kit~strike('floorTom16',impulse,.32,0)
    when note=45 then kit~strike('rackTom12',impulse,.34,0)
    when note=47 | note=48 then kit~strike('rackTom12',impulse,.30,0)
    when note=50 then kit~strike('rackTom10',impulse,.28,0)
    when note=42 then do; kit~setHiHatOpen(.04); kit~strike('hihat',impulse,.52,0); end
    when note=44 then do; kit~setHiHatOpen(0); kit~strike('hihat',impulse*.82,.45,0); end
    when note=46 then do; kit~setHiHatOpen(.88); kit~strike('hihat',impulse,.64,0); end
    when note=49 | note=55 then kit~strike('crash16',impulse,.78,0)
    when note=57 then kit~strike('crash18',impulse,.80,0)
    when note=51 | note=53 | note=59 then kit~strike('ride20',impulse,.70,0)
    otherwise return .false
  end
  return .true

::class MidiDrumRenderer public
::method render class
  use strict arg song,startSeconds,durationSeconds,sampleRate=10000,listener=.nil,gaugeHz=100
  if durationSeconds<=0 then raise syntax 88.900 array('positive MIDI drum render duration',durationSeconds)
  if sampleRate<6000 then raise syntax 88.900 array('drum sample rate >= 8000',sampleRate)
  if listener==.nil then listener=.MathVector3~new(0,-2.2,1.15,.Maths~defaultContext)

  world=.PhysicalWorld~new(.nil,.AcousticMedium~air)
  solver=.AcousticSolver~new(world)
  kit=.DrumKitFactory~standardRockKit
  pressurePlan=kit~preparePressurePlan(listener,solver)
  mic=.DrumFixedMicStream~new(kit,pressurePlan,sampleRate)
  notes=.MidiEventSelector~notesForChannel(song,10)
  selected=.array~new
  renderEnd=startSeconds+durationSeconds
  do n over notes
    if n~startSeconds<startSeconds then iterate
    if n~startSeconds>=renderEnd then leave
    selected~append(n)
  end

  samples=.array~new
  gauges=.array~new
  dt=1/sampleRate
  total=(durationSeconds*sampleRate)~ceiling
  eventIndex=1
  gaugeStride=(sampleRate/gaugeHz)~trunc
  if gaugeStride<1 then gaugeStride=1
  do i=1 to total
    localTime=(i-1)*dt
    absoluteTime=startSeconds+localTime
    do while eventIndex<=selected~items
      n=selected[eventIndex]
      if n~startSeconds>absoluteTime+dt/2 then leave
      dispatched=.MidiDrumPerformer~dispatch(kit,n~note,n~velocity)
      eventIndex+=1
    end
    kit~stepWithoutHistory(dt)
    world~advanceSimulationTime(dt)
    pressure=mic~nextPressure
    samples~append(pressure)
    if (i-1)//gaugeStride=0 then do
      gauges~append(self~gaugeRowScalar(localTime,kit,pressure))
    end
  end
  return .MidiDrumRenderResult~new(samples,selected,gauges,startSeconds,durationSeconds,sampleRate)

::method gaugeRowScalar class
  use strict arg localTime,kit,pressure
  d=.directory~new
  d['TIME_S']=localTime; d['PRESSURE_PA']=pressure; d['TOTAL_J']=kit~totalMechanicalEnergy
  do v over kit~voices; d[v~name~upper||'_J']=v~mechanicalEnergy; end
  return d

::method gaugeRow class
  use strict arg localTime,kit,obs
  d=.directory~new
  d['TIME_S']=localTime
  d['PRESSURE_PA']=obs~pressurePa
  d['TOTAL_J']=kit~totalMechanicalEnergy
  do v over kit~voices; d[v~name~upper||'_J']=v~mechanicalEnergy; end
  return d

::method writeGaugesCsv class
  use strict arg path,renderResult
  call lineout path,'time_s,pressure_pa,total_j,kick_j,snare_j,rackTom10_j,rackTom12_j,floorTom16_j,hihat_j,crash16_j,crash18_j,ride20_j'
  do d over renderResult~gauges
    call lineout path,d['TIME_S']','d['PRESSURE_PA']','d['TOTAL_J']','d['KICK_J']','d['SNARE_J']','d['RACKTOM10_J']','d['RACKTOM12_J']','d['FLOORTOM16_J']','d['HIHAT_J']','d['CRASH16_J']','d['CRASH18_J']','d['RIDE20_J']
  end
  call lineout path
  return path

::requires 'MidiReader.cls'
::requires 'DrumKitPhysics.cls'
