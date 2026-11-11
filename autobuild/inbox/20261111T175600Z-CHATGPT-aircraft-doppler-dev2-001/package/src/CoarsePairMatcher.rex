/* ooRexx coarse flyover pairs from PRECOMPUTED candidate-receiver events.
 * No audio, personal location, tracks, or original recording stored here.
 * Input predicted rows MUST be cell-grouped and increasing in arrival UTC.
 * Data format TSV with header:
 *   cell_id flight_id heard_utc_s approx_speed_mps cpa_slant_m
 * Observation TSV with header:
 *   event_id relative_s approx_speed_mps cpa_slant_m speed_sigma_mps slant_sigma_m
 * Results are ranked by a heuristic residual; not probabilities or a location fix.
 * Usage: rexx src/CoarsePairMatcher.rex predicted.tsv observations.tsv [max_delta_s] [top_n]
 */
numeric digits 16
parse arg predictedPath observedPath maxDelta topN
if predictedPath = '' | observedPath = '' then do
  say 'USAGE: rexx CoarsePairMatcher.rex predicted.tsv observed.tsv [max_delta_s] [top_n]'
  exit 2
end
if maxDelta = '' then maxDelta = 5
if topN = '' then topN = 30
if \datatype(maxDelta, 'N') | \datatype(topN,'W') then do
  say 'ERROR: invalid numeric argument'
  exit 2
end
if maxDelta <= 0 | topN < 1 | topN > 10000 then do
  say 'ERROR: positive tolerance and top_n in 1..10000 required'
  exit 2
end
sep = '09'x
obs = .array~new
input = .stream~new(observedPath)
if input~open('read') <> 'READY:' then do
  say 'ERROR: observation file not readable'
  exit 2
end
if input~lines <= 0 then do
  say 'ERROR: empty observations'
  exit 2
end
header = input~linein
if header <> 'event_id'||sep||'relative_s'||sep||'approx_speed_mps'||sep||'cpa_slant_m'||sep||'speed_sigma_mps'||sep||'slant_sigma_m' then do
  say 'ERROR: bad observation header'
  exit 2
end
do while input~lines > 0
  line = input~linein
  if line = '' then iterate
  columns = line~makeArray(sep)
  if columns~items <> 6 then do
    say 'ERROR: malformed observation row'
    exit 2
  end
  do i = 2 to 6
    if \datatype(columns[i], 'N') then do
      say 'ERROR: nonnumeric observation'
      exit 2
    end
  end
  if columns[5] <= 0 | columns[6] <= 0 then do
    say 'ERROR: positive observation uncertainties required'
    exit 2
  end
  obs~append(columns)
end
input~close
if obs~items <> 2 then do
  say 'ERROR: exactly two measured events required in this coarse matcher'
  exit 2
end
if obs[2][2] <= obs[1][2] then do
  say 'ERROR: measured events must be time-ordered'
  exit 2
end
observedDelta = obs[2][2] - obs[1][2]
input = .stream~new(predictedPath)
if input~open('read') <> 'READY:' then do
  say 'ERROR: predicted file not readable'
  exit 2
end
if input~lines <= 0 then do
  say 'ERROR: empty predicted file'
  exit 2
end
header = input~linein
if header <> 'cell_id'||sep||'flight_id'||sep||'heard_utc_s'||sep||'approx_speed_mps'||sep||'cpa_slant_m' then do
  say 'ERROR: bad predicted header'
  exit 2
end
currentCell = ''
cellRows = .array~new
ranks = .array~new
count = 0
previousCell = .directory~new
prevTime = 0
hasPrevious = .false
do while input~lines > 0
  line = input~linein
  if line = '' then iterate
  columns = line~makeArray(sep)
  if columns~items <> 5 then do
    say 'ERROR: malformed predicted row'
    exit 2
  end
  do i = 3 to 5
    if \datatype(columns[i], 'N') then do
      say 'ERROR: nonnumeric predicted row'
      exit 2
    end
  end
  cell = columns[1]
  if cell = '' | columns[2] = '' then do
    say 'ERROR: empty cell or flight'
    exit 2
  end
  if currentCell <> '' & cell <> currentCell then do
    call scoreCell currentCell, cellRows
    previousCell[currentCell] = 1
    if previousCell~hasIndex(cell) then do
      say 'ERROR: noncontiguous cell rows'
      exit 2
    end
    cellRows = .array~new
    hasPrevious = .false
  end
  if hasPrevious & columns[3] < prevTime then do
    say 'ERROR: predicted times unsorted within cell'
    exit 2
  end
  currentCell = cell
  cellRows~append(columns)
  prevTime = columns[3]
  hasPrevious = .true
end
input~close
if currentCell <> '' then call scoreCell currentCell, cellRows
/* sorted best-first; ordering is deterministic by score, then receiver/flight IDs */
say 'cell_id'||sep||'flight_1'||sep||'flight_2'||sep||'recording_start_utc_s'||sep||'delta_residual_s'||sep||'heuristic_cost'
do i = 1 to ranks~items
  say ranks[i][2]
end
exit 0

scoreCell: procedure expose obs observedDelta maxDelta ranks topN sep
  use arg cell, rows
  numeric digits 16
  if rows~items < 2 then return
  /* rows already sorted; stop each inner scan at target + tolerance */
  do a = 1 to rows~items - 1
    one = rows[a]
    target = one[3] + observedDelta
    do b = a+1 to rows~items
      two = rows[b]
      if two[3] > target + maxDelta then leave
      if two[3] < target - maxDelta then iterate
      if one[2] = two[2] then iterate
      timeResidual = (two[3] - one[3]) - observedDelta
      speed1 = (one[4] - obs[1][3]) / obs[1][5]
      speed2 = (two[4] - obs[2][3]) / obs[2][5]
      range1 = (one[5] - obs[1][4]) / obs[1][6]
      range2 = (two[5] - obs[2][4]) / obs[2][6]
      cost = (timeResidual/maxDelta)**2 + (speed1**2 + speed2**2 + range1**2 + range2**2)/4
      startUtc = ((one[3] - obs[1][2]) + (two[3] - obs[2][2]))/2
      formatted = cell||sep||one[2]||sep||two[2]||sep||startUtc||sep||timeResidual||sep||cost
      candidate = .array~of(cost, formatted)
      call retainCandidate candidate
    end
  end
  return

retainCandidate: procedure expose ranks topN
  use arg candidate
  if ranks~items >= topN then do
    last = ranks[ranks~items]
    if candidate[1] > last[1] | (candidate[1] = last[1] & candidate[2] >= last[2]) then return
  end
  ranks~append(candidate)
  k = ranks~items
  do while k > 1
    previous = ranks[k-1]
    if previous[1] < candidate[1] then leave
    if previous[1] = candidate[1] & previous[2] <= candidate[2] then leave
    ranks[k] = previous
    k -= 1
  end
  ranks[k] = candidate
  if ranks~items > topN then ranks~remove(ranks~items)
  return
