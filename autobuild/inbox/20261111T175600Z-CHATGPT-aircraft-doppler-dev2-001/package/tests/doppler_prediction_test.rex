/* Interpret the CLI output independently of internal helper calculations. */
numeric digits 16
parse arg path
if path = '' then exit 2
sep = '09'x
input = .stream~new(path)
if input~open('read') <> 'READY:' then exit 2
expected = 'cell_id'||sep||'flight_id'||sep||'emission_utc_s'||sep||'heard_utc_s'||sep||'slant_m'||sep||'radial_mps'||sep||'doppler_ratio'
call check input~linein = expected, 'schema'
prevArrival = 0
n = 0
do while input~lines > 0
  fields = input~linein~makeArray(sep)
  call check fields~items = 7, 'row width'
  n += 1
  if fields[2] = 'TEST1' then do
    call check fields[4] > fields[3], 'retarded sound arrival'
    call check (fields[4] > prevArrival | prevArrival = 0), 'increasing heard UTC'
    if n = 1 then call check fields[7] > 1, 'approach frequency ratio'
    if n = 3 then call check abs(fields[7]-1) < 0.000001, 'closest approach zero shift'
    if n = 5 then call check fields[7] < 1, 'recede frequency ratio'
    prevArrival = fields[4]
  end
  if n = 6 then call check fields[2] = 'TEST2', 'new flight admission'
end
input~close
call check n = 7, 'sample count'
say 'PASS' n 'sampled trajectory predictions and physical invariants'
exit 0
check: procedure
 use arg truth, label
 if \truth then do
   say 'FAIL' label
   exit 1
 end
 return
