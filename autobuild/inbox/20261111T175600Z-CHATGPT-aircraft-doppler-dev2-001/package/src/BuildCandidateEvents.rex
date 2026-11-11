/* Precompute coarse acoustic arrival-time catalogue from receiver-relative
   Cartesian 3D flight samples. Every dx/dy/dz is aircraft minus receiver,
   in METRES, with velocities in the SAME frame. Data must be grouped by
   cell_id, then flight_id, then increasing emission_utc_s. This is sampled
   closest approach, NOT an interpolated closest approach. Outputs sorted
   event records by cell and acoustic arrival time for CoarsePairMatcher.rex.
   Usage: rexx src/BuildCandidateEvents.rex receiver_relative_samples.tsv [sound_speed_mps]
*/
numeric digits 16
parse arg path c
if path = '' then do
  say 'ERROR: input receiver-relative sample TSV required'
  exit 2
end
if c = '' then c = 343
if \datatype(c,'N') | c <= 0 then do
  say 'ERROR: invalid sound speed'
  exit 2
end
sep = '09'x
source = .stream~new(path)
if source~open('read') <> 'READY:' then do
  say 'ERROR: source not readable'
  exit 2
end
expected = 'cell_id'||sep||'flight_id'||sep||'emission_utc_s'||sep||'dx_m'||sep||'dy_m'||sep||'dz_m'||sep||'vx_mps'||sep||'vy_mps'||sep||'vz_mps'
if source~lines <= 0 | source~linein <> expected then do
  say 'ERROR: invalid source header'
  exit 2
end
currentCell = ''
currentFlight = ''
prevEmitted = 0
prevMinRange = -1
cellEvents = .array~new
closedCells = .directory~new
closedFlights = .directory~new
say 'cell_id'||sep||'flight_id'||sep||'heard_utc_s'||sep||'approx_speed_mps'||sep||'cpa_slant_m'
do while source~lines > 0
  line = source~linein
  if line = '' then iterate
  fields = line~makeArray(sep)
  if fields~items <> 9 then do
    say 'ERROR: malformed input row'
    exit 2
  end
  do k = 3 to 9
    if \datatype(fields[k],'N') then do
      say 'ERROR: nonnumeric input field'
      exit 2
    end
  end
  cell = fields[1]; flight = fields[2]
  if cell = '' | flight = '' then do
    say 'ERROR: missing identity'
    exit 2
  end
  if currentCell <> '' & cell <> currentCell then do
    call finishFlight
    call emitCell cellEvents
    closedCells[currentCell] = .true
    if closedCells~hasIndex(cell) then do
      say 'ERROR: noncontiguous receiver cell rows'
      exit 2
    end
    cellEvents = .array~new
    closedFlights = .directory~new
    prevMinRange = -1
    currentFlight = ''
  end
  if currentFlight <> '' & flight <> currentFlight then do
    call finishFlight
    closedFlights[currentFlight] = .true
    if closedFlights~hasIndex(flight) then do
      say 'ERROR: noncontiguous flight rows'
      exit 2
    end
    prevMinRange = -1
  end
  if currentCell = cell & currentFlight = flight & fields[3] < prevEmitted then do
    say 'ERROR: flight emission times unsorted'
    exit 2
  end
  currentCell = cell
  currentFlight = flight
  prevEmitted = fields[3]
  range = .AcousticFlyoverPhysics~slantRange(fields[4],fields[5],fields[6])
  speed = .AcousticFlyoverPhysics~slantRange(fields[7],fields[8],fields[9])
  if prevMinRange < 0 | range < prevMinRange then do
    prevMinRange = range
    bestHeard = .AcousticFlyoverPhysics~arrivalUtc(fields[3],range,c)
    bestSpeed = speed
    bestRange = range
  end
end
source~close
if currentCell <> '' then do
  call finishFlight
  call emitCell cellEvents
end
exit 0

finishFlight: procedure expose currentCell currentFlight cellEvents bestHeard bestSpeed bestRange prevMinRange sep
  if currentFlight = '' | prevMinRange < 0 then return
  line = currentCell||sep||currentFlight||sep||bestHeard||sep||bestSpeed||sep||bestRange
  cellEvents~append(.array~of(bestHeard,line))
  return

emitCell: procedure
  use arg cellEvents
  /* Per-receiver arrival-time ordering, small local insertion sort */
  n = cellEvents~items
  do i = 2 to n
    item = cellEvents[i]
    j = i
    do while j > 1
      earlier = cellEvents[j-1]
      if earlier[1] <= item[1] then leave
      cellEvents[j] = earlier
      j -= 1
    end
    cellEvents[j] = item
  end
  do i = 1 to n
    say cellEvents[i][2]
  end
  return

::requires 'src/AcousticFlyoverPhysics.cls'
