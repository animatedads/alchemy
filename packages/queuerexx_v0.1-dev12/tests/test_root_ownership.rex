parse arg root owner
fs=.QueuePosixAtomicFileSystem~new
locks=.QueueStateLockManager~new(root,fs)
h=locks~acquire("ownerq","ownership-test",0)
if h==.nil then do; say "FAIL ownership lock"; exit 1; end
lockPath=h~path
h~release
/* reserve leaves its job file in place but releases lock only when caller asks */
r=.QueuePendingAllocator~new(root,fs)~reserve(10,5)
if r==.nil then do; say "FAIL ownership reserve"; exit 1; end
jobPath=r~path
r~release
say lockPath
say jobPath
exit 0
::requires "../src/QueueRexxMutation.cls"
