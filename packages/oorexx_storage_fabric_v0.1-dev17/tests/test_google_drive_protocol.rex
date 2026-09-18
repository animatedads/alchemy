p=.GoogleDriveStorageProvider~new('google-drive','bashqueues-test','root')
call assertTrue p~supportsResumableUpload,'resumable upload advertised'
call assertTrue p~supportsRangeDownload,'range download advertised'
call assertEq 262144,p~resumableChunkQuantumBytes,'Drive quantum'
call assertEq 8388608,p~recommendedTransferChunkBytes,'recommended chunk'
call assertTrue .GoogleDriveResumableProtocol~validChunk(262144),'one quantum valid'
call assertTrue .GoogleDriveResumableProtocol~validChunk(8388608),'8 MiB valid'
call assertFalse .GoogleDriveResumableProtocol~validChunk(300000),'non-final odd chunk invalid'
call assertTrue .GoogleDriveResumableProtocol~validChunk(300000,.true),'final odd chunk valid'
call assertEq 'bytes 0-524287/2000000',.GoogleDriveResumableProtocol~contentRange(0,524288,2000000),'content range'
call assertEq 'bytes */2000000',.GoogleDriveResumableProtocol~statusContentRange(2000000),'status range'
call assertEq 43,.GoogleDriveResumableProtocol~nextOffset('bytes=0-42'),'resume offset'
call assertEq 0,.GoogleDriveResumableProtocol~nextOffset(''),'empty range means zero'
call assertEq -1,.GoogleDriveResumableProtocol~nextOffset('nonsense'),'bad range rejected'
say 'PASS Google Drive resumable/range protocol primitives'
exit 0
::routine assertTrue
  use arg value,label
  if \value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertFalse
  use arg value,label
  if value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label 'expected='expected 'actual='actual; raise syntax 88.900 array('test assertion failed'); end
::requires "src/StorageStreaming.cls"