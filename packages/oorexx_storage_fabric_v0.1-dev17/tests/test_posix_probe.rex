p=.StoragePosixDfProbe~new
s=p~sample("/tmp")
if s==.nil then do; say "FAIL df probe returned nil"; exit 1; end
if s~capacityDomainId="" | s~totalBytes<=0 | s~freeBytes<0 then do; say "FAIL invalid sample"; exit 1; end
say "PASS posix df probe" s~capacityDomainId s~freeBytes
exit 0
::requires "src/StorageFabric.cls"