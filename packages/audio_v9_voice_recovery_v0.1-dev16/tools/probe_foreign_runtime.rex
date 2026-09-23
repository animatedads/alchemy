numeric digits 30
info=.foreign~runtimeInfo
if info~runtimeVersion<>"0.22.6" then do
  say 'FAIL foreign runtime version='info~runtimeVersion
  exit 2
end
if info~abiProfile<>"linux-x86_64-le-lp64" then do
  say 'FAIL foreign runtime ABI profile='info~abiProfile
  exit 2
end
say 'PASS foreign-runtime version='info~runtimeVersion' abi='info~abiProfile' qualified='info~abiQualified
exit 0
::requires 'foreign.cls'
