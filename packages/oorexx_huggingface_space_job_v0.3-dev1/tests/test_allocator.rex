a=.HFSpaceAllocatorAdapter~new
cpu=.HFSpaceJobRequirement~new('CPU')
r=a~toJobNodeRequirement(cpu)
if \hasTag(r~tags,'CPU_ONLY_OK') then call fail 'CPU allocator tag missing'
if hasAbility(r~abilities,'GPU') then call fail 'CPU job demanded GPU'
g=.HFSpaceJobRequirement~new('GPU',16384,100)
gr=a~toJobNodeRequirement(g)
if \hasAbility(gr~abilities,'GPU') then call fail 'GPU ability missing'
if \hasTag(gr~tags,'HF_ZEROGPU_LARGE') then call fail 'large tag missing'
x=.HFSpaceJobRequirement~new('GPU',60000,100)
xr=a~toJobNodeRequirement(x)
if \hasTag(xr~tags,'HF_ZEROGPU_XLARGE') then call fail 'xlarge tag missing'
say 'PASS HF SPACE JOB NODE ALLOCATOR HARD ELIGIBILITY'
exit 0
hasTag: procedure
  use arg values,wanted
  do v over values; if v=wanted then return .true; end
  return .false
hasAbility: procedure
  use arg values,wanted
  do v over values; if v=wanted then return .true; end
  return .false
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'HuggingFaceAllocatorAdapter.cls'
