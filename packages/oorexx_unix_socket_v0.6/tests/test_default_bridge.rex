p=.UnixSocket~socketPair('SOCK_STREAM')
if p==.nil then do
  say 'FAIL default bridge resolution errno=' .UnixSocket~lastErrno .UnixSocket~lastErrorText
  exit 1
end
if pos('libc',.UnixSocket~providerPath)=0 then do
  say 'FAIL default bridge provider=' .UnixSocket~providerPath
  exit 1
end
if \.UnixSocket~abiQualified then do; say 'FAIL default bridge ABI qualification'; exit 1; end
if .UnixSocket~abiProfile \== .foreign~runtimeInfo~abiProfile then do; say 'FAIL default bridge ABI profile'; exit 1; end
p[1]~close; p[2]~close
say 'PASS qualified ABI bridge resolves relative to unixsocket.cls profile=' .UnixSocket~abiProfile
::requires 'unixsocket.cls'
