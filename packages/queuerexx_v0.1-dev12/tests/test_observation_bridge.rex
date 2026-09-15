root = "observation-fixture-" || random(100000, 999999)
address system "rm -rf " || root
address system "mkdir -p " || root || "/running"
path = root || "/running/job1.job"
call lineout path, "JOB_ID=job1"
call lineout path, "JOB_NAME=job1"
call lineout path, "PRIORITY=10"
call lineout path, "COMMAND=(/bin/true)"
call lineout path, "RUNNER_USED=direct"
call lineout path, "RUN_PID=123"
call lineout path
record = .QueueRecord~new(path, .QueueState~RUNNING, root)
evidence = .Directory~new; evidence["run_pid"] = "123"
obs = .QueueJobObservation~new(.QueueJobObservation~LIVE, .QueueRunnerKind~DIRECT, "TEST_LIVE", "test", evidence)
source = .QueueObservationSource~new(record~qid)
source~capture(record, obs)
checked = .ObservationProtocol~validateObserver(source)
if \checked~ok then do; say "FAIL observation protocol" checked~code; exit 1; end
bridge = .QueueObservationBridge~new(record, obs)
rec = bridge~publish(record, obs)
if rec == .nil then do; say "FAIL observation publish"; exit 1; end
if rec~kind \= .QueueObservationKind~LIVENESS then do; say "FAIL observation kind"; exit 1; end
address system "rm -rf " || root
say "PASS test_observation_bridge"
exit 0
::requires "../src/QueueRexxObservationV05Adapter.cls"
