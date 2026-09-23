/* Optional Foreign Runtime/libzstd provider qualification. */
parse arg bridgePath outputPath
if bridgePath = '' | outputPath = '' then do
  say 'usage: test_foreign_provider.rex BRIDGE OUTPUT'
  exit 2
end
signal on syntax name failed
native = .Compress~new
provider = .ForeignCompressProvider~new(bridgePath)
codec = .Compress~new(provider)

if codec~provider \== 'foreign-runtime-libzstd' then do; say 'FAIL wrong provider'; exit 1; end
payload = copies('foreign-runtime-zstandard-payload-',2000)
compressedBytes = codec~zstd(payload,'AUTO',.true)
if compressedBytes == 'RESULT' then do; say 'FAIL RESULT special-variable collision regressed'; exit 1; end
if length(compressedBytes) >= length(payload) then do; say 'FAIL foreign zstd did not compress repetitive payload'; exit 1; end
if codec~unzstd(compressedBytes) \== payload then do; say 'FAIL foreign provider round trip'; exit 1; end

/* Foreign provider must also consume native bootstrap frames. */
nativeFrame = native~zstd(payload,'RAW',.true)
if codec~unzstd(nativeFrame) \== payload then do; say 'FAIL native-to-foreign interop'; exit 1; end

state = stream(outputPath,'c','open write replace')
if left(translate(state),5) \== 'READY' then do; say 'FAIL cannot open output'; exit 1; end
unwritten = charout(outputPath,compressedBytes)
call stream outputPath,'c','close'
if unwritten \== 0 then do; say 'FAIL short output write'; exit 1; end
provider~close
say 'PASS Foreign Runtime/libzstd provider qualification'
say 'input_bytes=' length(payload) 'compressed_bytes=' length(compressedBytes)
exit 0

failed:
  c=condition('O')
  say 'FAIL foreign provider condition'
  if c~hasIndex('ADDITIONAL') then do item over c['ADDITIONAL']; say '  ' item; end
  exit 1

::requires '../src/Compress.cls'
::requires '../foreign/ForeignCompressProvider.cls'
