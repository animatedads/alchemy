parse source . . here
base=filespec('D',here) || filespec('P',here)
req=.ColabJobRequirement~new('GPU','T4',.false,16384,30720,.true,.true)
j=.ColabAllocatorAdapter~new~toJobNodeRequirement(req)
call assert j~abilities~at('GPU')<>.nil,'GPU must be hard ability'
call assert j~tags~at('GPU_T4')<>.nil,'T4 must be hard tag'
call assert j~minimumMemoryMiB=16384,'memory maps'
call assert j~minimumDiskMiB=30720,'disk maps'
cpu=.ColabAllocatorAdapter~new~toJobNodeRequirement(.ColabJobRequirement~new('CPU'))
call assert cpu~abilities~at('GPU')==.nil,'CPU must not acquire GPU ability'
call assert cpu~tags~at('CPU_ONLY_OK')<>.nil,'CPU eligibility explicit'
say 'PASS allocator adapter hard-resource mapping'
exit 0
assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires '../src/ColabJobAllocatorAdapter.cls'
