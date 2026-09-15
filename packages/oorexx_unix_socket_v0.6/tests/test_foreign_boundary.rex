if .UnixSocket~implementation \== 'FOREIGN_RUNTIME' then do
  say 'FAIL implementation marker'
  exit 1
end
if .UnixSocket~foreignRuntimeVersion \== '0.22.6' then do
  say 'FAIL expected Foreign Runtime 0.22.6 actual=' .UnixSocket~foreignRuntimeVersion
  exit 1
end
provider=.UnixSocket~providerPath
if pos('libc',provider)=0 then do
  say 'FAIL expected libc provider actual='provider
  exit 1
end
caps=.foreign~capabilities
managed=.false; slices=.false; abi=.false; layouts=.false; constants=.false; nativeScalars=.false
do i=1 to caps~items
  if caps[i]=='transitive-struct-pinning' then managed=.true
  if caps[i]=='binary-buffer-slices' then slices=.true
  if caps[i]=='abi-profile-enforcement' then abi=.true
  if caps[i]=='profile-scoped-layouts' then layouts=.true
  if caps[i]=='profile-scoped-constants' then constants=.true
  if caps[i]=='abi-native-c-scalars' then nativeScalars=.true
end
if \managed | \slices | \abi | \layouts | \constants | \nativeScalars then do
  say 'FAIL required Foreign Runtime capabilities absent'
  exit 1
end
if \.UnixSocket~abiQualified then do; say 'FAIL UnixSocket bridge ABI not qualified'; exit 1; end
if .UnixSocket~abiProfile \== .foreign~runtimeInfo~abiProfile then do; say 'FAIL ABI profile mismatch'; exit 1; end
say 'PASS Foreign Runtime boundary version=' .UnixSocket~foreignRuntimeVersion 'abi=' .UnixSocket~abiProfile 'provider='provider
::requires '../unixsocket.cls'
