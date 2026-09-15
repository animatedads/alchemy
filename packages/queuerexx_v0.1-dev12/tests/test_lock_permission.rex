parse arg root
fs = .QueuePosixAtomicFileSystem~new
locks = .QueueStateLockManager~new(root, fs)
r = locks~acquireDetailed('permq', 'permission-test', 0)
say r~status
say r~detail
svc = .QueueTransitionService~new(root)
receipt = svc~transition('permjob', .QueueState~PENDING, .QueueState~RUNNING, .QueueEvent~JOB_CLAIMED, 'permission-test', 0)
say receipt~status
exit 0
::requires "../src/QueueRexxMutation.cls"
