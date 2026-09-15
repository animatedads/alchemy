/* v0.22.5 ABI profile qualification / fail-closed loading. */
assertions=0
ri=.foreign~runtimeInfo
call ok ri~abiProfile='linux-x86_64-le-lp64', 'runtime ABI profile'; assertions+=1
call ok ri~abiQualified, 'runtime ABI is qualified by this release'; assertions+=1
call ok ri~architecture='x86_64', 'runtime architecture'; assertions+=1
call ok ri~dataModel='lp64', 'runtime data model'; assertions+=1
call ok ri~osFamily='linux', 'runtime OS family'; assertions+=1
profiles=.foreign~qualifiedAbiProfiles
call ok profiles~items=1, 'one qualified ABI profile in v0.22.5'; assertions+=1
call ok profiles[1]='linux-x86_64-le-lp64', 'qualified profile identity'; assertions+=1

lib=.foreign~load('abi-profile.bridge.json')
call ok lib~abiQualified, 'bridge ABI qualified'; assertions+=1
call ok lib~abiProfile=ri~abiProfile, 'bridge selected runtime profile'; assertions+=1
call ok lib~constant('ABI_MAGIC')~value='0x225', 'profile constant overrides portable default'; assertions+=1
call ok lib~constant('ABI_POINTER_BITS')~value='64', 'profile-only constant visible'; assertions+=1
call ok lib~structTypes~items=1, 'profile-only struct visible'; assertions+=1
s=lib~struct('abi_pair')
call ok s~size=16, 'profile struct size'; assertions+=1
call ok s~alignment=8, 'profile struct alignment'; assertions+=1
s~set('tag',17)
s~set('value',123456789)
call ok s~get('tag')=17, 'profile struct u32 field'; assertions+=1
call ok s~get('value')=123456789, 'profile struct u64 field'; assertions+=1
s~close
lib~close

mismatchCaught=0
call mismatchProbe
call ok mismatchCaught=1, 'mismatched ABI profile rejected before load'; assertions+=1
say 'PASS ABI profile qualification' assertions 'assertions'
exit 0

mismatchProbe:
  signal on syntax name mismatchExpected
  bad=.foreign~load('abi-mismatch.bridge.json')
  if bad<>.nil then bad~close
  return
mismatchExpected:
  mismatchCaught=1
  return

ok:
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  return

::requires '../rexx/foreign.cls'
