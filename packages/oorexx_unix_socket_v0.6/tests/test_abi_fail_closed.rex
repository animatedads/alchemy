caught=0
signal on syntax name expectedMismatch
bad=.foreign~load('abi-mismatch.bridge.json')
if bad<>.nil then bad~close
say 'FAIL mismatched ABI bridge unexpectedly loaded'
exit 1
expectedMismatch:
  detail=condition('A')
  if pos('ABI_PROFILE_MISMATCH',detail)=0 then do
    say 'FAIL ABI mismatch did not fail at profile gate:' detail
    exit 1
  end
  if pos('__unixsocket_must_never_dlopen__',detail)>0 then do
    say 'FAIL ABI mismatch reached dlopen:' detail
    exit 1
  end
  say 'PASS mismatched ABI profile rejected before dlopen'
  exit 0
::requires 'foreign.cls'
