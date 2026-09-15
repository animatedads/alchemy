a=.FDDoorMicroMotionMigratableExecutionAdapter~new('/tmp/fd-source-state','/tmp/media/source.mp4','/tmp/fd-dest/analysis','/tmp/fd-dest/state','sha256:test','/tmp/run_fd_worker.rex')
if \a~isA(.MigratableJobExecutionAdapter) then do; say 'FAIL adapter is not MigratableJobExecutionAdapter'; exit 1; end
if a~sourceControlDir<>'/tmp/fd-source-state' then do; say 'FAIL source control binding'; exit 1; end
if a~destinationSourcePath<>'/tmp/media/source.mp4' then do; say 'FAIL destination source binding'; exit 1; end
if a~profile<>'FD_NIGHT_F11' then do; say 'FAIL profile binding'; exit 1; end
say 'PASS Migratable Job v0.2.4 execution adapter load/binding'
exit 0
::requires 'FDDoorMicroMotionMigratable.cls'
