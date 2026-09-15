root = "/tmp/queuerexx-dev3-lock-" || random(100000,999999)
call SysMkDir root
fs = .QueuePosixAtomicFileSystem~new
locks = .QueueStateLockManager~new(root, fs)
first = locks~acquire("qid1", "test-first", 0)
call must first \= .nil, "first lock"
second = locks~acquire("qid1", "test-second", 0)
call must second == .nil, "second lock blocked"
call must first~release, "release first"
third = locks~acquire("qid1", "test-third", 0)
call must third \= .nil, "third lock after release"
call must third~release, "release third"
/* QueueBash-compatible stale meta PID can be reclaimed conservatively. */
path = locks~pathFor("stale")
fs~ensureDirectory(path~left(path~lastpos("/")-1))
call SysMkDir path
call lineout path || "/meta", "pid=99999999"
call lineout path || "/meta", "created_at=2000-01-01T00:00:00+00:00"
call lineout path || "/meta", "actor=test-stale"
call lineout path || "/meta"
stale = locks~acquire("stale", "test-reclaim", 0)
call must stale \= .nil, "stale lock reclaimed"
call must stale~release, "release reclaimed"
/* QueueRexx locks add a process-start cookie so a reused live PID does not
 * make stale ownership look current. */
reusePath = locks~pathFor("pid-reuse")
call SysMkDir reusePath
pid = fs~processId
call lineout reusePath || "/meta", "pid=" || pid
call lineout reusePath || "/meta", "created_at=2000-01-01T00:00:00+00:00"
call lineout reusePath || "/meta", "actor=test-pid-reuse"
call lineout reusePath || "/meta", "host=" || .QueueRexxUtil~shellOutput("hostname 2>/dev/null")
call lineout reusePath || "/meta", "process_start_cookie=definitely-not-current"
call lineout reusePath || "/meta"
reused = locks~acquire("pid-reuse", "test-reclaim-reused-pid", 0)
call must reused \= .nil, "reused PID lock reclaimed by start cookie"
call must reused~release, "release reused PID lock"
/* A lock explicitly owned by another host is not reclaimed merely because its
 * numeric PID happens to be live on this host.  Cross-host authority is
 * conservative until a distributed lock provider supplies stronger evidence. */
foreignPath = locks~pathFor("foreign-host")
call SysMkDir foreignPath
call lineout foreignPath || "/meta", "pid=" || pid
call lineout foreignPath || "/meta", "created_at=2000-01-01T00:00:00+00:00"
call lineout foreignPath || "/meta", "actor=test-foreign-host"
call lineout foreignPath || "/meta", "host=definitely-another-host.invalid"
call lineout foreignPath || "/meta", "process_start_cookie=definitely-not-current"
call lineout foreignPath || "/meta"
foreign = locks~acquireDetailed("foreign-host", "test-foreign-host", 0)
call must foreign~status == .QueueLockAcquireStatus~TIMEOUT, "foreign-host lock is not reclaimed from local PID coincidence"
call cleanup root
say "PASS test_state_lock"
exit 0

must:
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
cleanup:
 use arg path
 address system "rm -rf -- " || .QueuePosixShell~quote(path)
 return
::requires "../src/QueueRexxMutation.cls"
