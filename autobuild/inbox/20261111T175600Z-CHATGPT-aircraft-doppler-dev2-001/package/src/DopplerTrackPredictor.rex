/* Sample-resolved, stationary-receiver Doppler prediction from relative flight
   geometry; ooRexx owns the transform. All positions in metres relative to
   one receiver cell, all velocities in the same right-handed frame, time UTC.
   Data are GROUPED cell/flight and STRICTLY increasing emission UTC in each.
   Model: still air, constant c, no refraction / terrain / aircraft acoustics.
   These are MODEL predictions, never captured sound or named emitters.
   Usage: rexx src/DopplerTrackPredictor.rex samples.tsv [sound_speed_mps]
*/
numeric digits 16
parse arg inputPath soundSpeed
if inputPath = '' then do
  say 'ERROR: receiver-relative TSV required'
  exit 2
end
if soundSpeed = '' then soundSpeed = 343
if \datatype(soundSpeed, 'N') then do
  say 'ERROR: sound speed must be numeric'
  exit 2
end
if soundSpeed <= 0 then do
  say 'ERROR: sound speed must be positive'
  exit 2
end
sep = '09'x
input = .stream~new(inputPath)
if input~open('read') <> 'READY:' then do
  say 'ERROR: unable to open receiver-relative data'
  exit 2
end
expected = 'cell_id'||sep||'flight_id'||sep||'emission_utc_s'||sep||'dx_m'||sep||'dy_m'||sep||'dz_m'||sep||'vx_mps'||sep||'vy_mps'||sep||'vz_mps'
if input~lines < 1 | input~linein <> expected then do
  say 'ERROR: unexpected source schema'
  input~close
  exit 2
end
say 'cell_id'||sep||'flight_id'||sep||'emission_utc_s'||sep||'heard_utc_s'||sep||'slant_m'||sep||'radial_mps'||sep||'doppler_ratio'
cell = ''
flight = ''
lastEmission = 0
lastArrival = 0
seenCells = .directory~new
seenFlights = .directory~new
count = 0
do while input~lines > 0
  line = input~linein
  if line = '' then iterate
  fields = line~makeArray(sep)
  if fields~items <> 9 then do
    say 'ERROR: row must contain nine columns'
    input~close
    exit 2
  end
  thisCell = fields[1]
  thisFlight = fields[2]
  if thisCell = '' | thisFlight = '' then do
    say 'ERROR: missing cell or flight ID'
    input~close
    exit 2
  end
  do k = 3 to 9
    if \datatype(fields[k],'N') then do
      say 'ERROR: nonnumeric flight measurement'
      input~close
      exit 2
    end
  end
  if cell <> '' & thisCell <> cell then do
    seenCells[cell] = 1
    if seenCells~hasIndex(thisCell) then do
      say 'ERROR: receiver cell not contiguous'
      input~close
      exit 2
    end
    seenFlights = .directory~new
    flight = ''
  end
  if flight <> '' & thisFlight <> flight then do
    seenFlights[flight] = 1
    if seenFlights~hasIndex(thisFlight) then do
      say 'ERROR: flight rows not contiguous'
      input~close
      exit 2
    end
  end
  if cell = thisCell & flight = thisFlight & fields[3] <= lastEmission then do
    say 'ERROR: flight time must strictly increase'
    input~close
    exit 2
  end
  range = .AcousticFlyoverPhysics~slantRange(fields[4],fields[5],fields[6])
  if range <= 0 then do
    say 'ERROR: co-located source and receiver unsupported'
    input~close
    exit 2
  end
  radial = .AcousticFlyoverPhysics~rangeRate(fields[4],fields[5],fields[6],fields[7],fields[8],fields[9])
  if soundSpeed + radial <= 0 then do
    say 'ERROR: non-causal radial velocity in still-air model'
    input~close
    exit 2
  end
  arrival = .AcousticFlyoverPhysics~arrivalUtc(fields[3],range,soundSpeed)
  if cell = thisCell & flight = thisFlight & arrival <= lastArrival then do
    say 'ERROR: sampled arrival time nonmonotonic (clock/geometry mismatch)'
    input~close
    exit 2
  end
  ratio = .AcousticFlyoverPhysics~observedFrequency(1,radial,soundSpeed)
  say thisCell||sep||thisFlight||sep||fields[3]||sep||arrival||sep||range||sep||radial||sep||ratio
  cell = thisCell
  flight = thisFlight
  lastEmission = fields[3]
  lastArrival = arrival
  count += 1
end
input~close
if count = 0 then do
  say 'ERROR: no trajectory samples'
  exit 2
end
exit 0

::requires 'src/AcousticFlyoverPhysics.cls'
