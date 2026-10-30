/* Runtime source-load smoke. Requires StorageFabric.cls and Mesh source on REXX_PATH. */
parse source . . here
call setlocal
signal on syntax name failed
say 'PASS storage instrumentation dev5 runtime source load'
call endlocal
exit 0
failed:
  say 'FAIL storage instrumentation dev5 runtime source load:' condition('D')
  call endlocal
  exit 1
::requires '../src/StorageInstrumentationMesh.cls'
