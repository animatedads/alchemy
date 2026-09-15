ri=.foreign~runtimeInfo
lib=.foreign~load('openssl.bridge.json')
version=lib~invoke('version',0)
if lib~provider <> 'native' then do
  say 'FAIL unexpected provider:' lib~provider
  exit 1
end
if lib~providerPath~pos('libcrypto')=0 then do
  say 'FAIL provider path does not identify libcrypto:' lib~providerPath
  exit 1
end
m=lib~method('version')
if m~overloadCount <> 1 then do
  say 'FAIL OpenSSL version signature count:' m~overloadCount
  exit 1
end
sig=m~signatures[1]
if sig~symbol <> 'OpenSSL_version' | sig~inputs[1]~typeName <> 'i32' | sig~returnTypeName <> 'utf8' then do
  say 'FAIL OpenSSL introspection mismatch:' sig
  exit 1
end
say 'PROVIDER' lib~providerPath
say 'METHOD' sig
if version='' then do
  say 'FAIL OpenSSL_version returned empty string'
  exit 1
end
if version~pos('OpenSSL')=0 then do
  say 'FAIL unexpected OpenSSL version:' version
  exit 1
end
say 'OPENSSL' version
say 'RUNTIME' ri~runtimeVersion 'INTERPRETER' ri~interpreterVersion 'RAW' ri~interpreterVersionRaw
say 'PASS optional OpenSSL metadata probe'
lib~close
exit 0
::requires '../../rexx/foreign.cls'
