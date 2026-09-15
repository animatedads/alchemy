/* Qualification for SecurityManager-contained read-only machine abilities. */

parse source . . testPath
testDir = filespec("L", testPath)
helper = testDir || "/fake_sshnode.sh"
runner = .LlmPaSecuredMachineRunner~new(helper)

/* Positive: fixed sshnode shape is accepted and stdout stays in memory. */
safeCmd = "timeout 20 " || helper || " ed209a 'cat /proc/meminfo'"
r = runner~run(safeCmd, "guard-safe")
call must r~ok, "safe delegated sshnode command allowed"
call must r~value["rc"] = 0, "safe command rc"
call must r~value["stdout"]~items >= 2, "safe stdout captured in memory"

/* Negative: command may be exact-listed by runner, but SecurityManager independently rejects non-probe remote text. */
target = "/tmp/llmpa-machine-guard-target"
call lineout target, "KEEP"
call lineout target
nr = runner~run("timeout 20 " || helper || " ed209a 'printf damaged > " || target || "'", "guard-redirection")
call must \nr~ok, "redirection rejected"
call must nr~code = "MACHINE_SECURITY_DENIED", "redirection deny code"
call must linein(target) = "KEEP", "redirection did not alter target"
call stream target, "C", "CLOSE"
nr = runner~run("timeout 20 " || helper || " ed209a 'rm -f " || target || "'", "guard-rm")
call must \nr~ok, "rm rejected"
call must linein(target) = "KEEP", "rm did not delete target"
call stream target, "C", "CLOSE"
nr = runner~run("timeout 20 " || helper || " ed209a 'touch /tmp/llmpa-should-not-exist'", "guard-touch")
call must \nr~ok, "touch rejected"
nr = runner~run("timeout 20 " || helper || " --transfer ed209a 'cat /proc/meminfo'", "guard-transfer")
call must \nr~ok, "sshnode transfer form rejected"

realService = .LlmPaMachineAbilityService~new(helper)
rr = realService~invoke("memory_status", "ed209a")
call must rr~ok, "secured service via fake sshnode"
call must rr~value["mem_total_kb"] = 2000000, "secured sshnode stdout parsed"
call must rr~value["mem_available_percent"] = 75, "secured sshnode memory percent"
call must rr~value["probes"][1]["security_manager"] = "LlmPaMachineCheckSecurityManager", "real SecurityManager evidence"

fake = .FakeMachineRunner~new
service = .LlmPaMachineAbilityService~new("/home/hc3/alchemy-autobuild/sshnode.sh", fake)

caps = service~capabilities
call must caps~items = 8, "eight bounded abilities"
do c over caps
  call must c["access_mode"] = "READ_ONLY", "ability read only"
  call must c["mutating"] = .false, "ability non-mutating"
  call must c["eventable"] = .true, "ability eventable"
end

r = service~invoke("memory_status", "ed209e")
call must r~ok, "memory ability"
call must r~value["mem_total_kb"] = 1000000, "memory total parsed"
call must r~value["mem_available_kb"] = 500000, "memory available parsed"
call must r~value["mem_available_percent"] = 50, "memory percent parsed"

r = service~invoke("space_status", "ed209e")
call must r~ok, "space ability"
call must r~value["root"]["used_percent"] = 60, "root used percent parsed"
call must r~value["root"]["free_percent"] = 40, "root free percent parsed"

/* Fake process contains a 6m20s installer -> conservative stuck suspicion. */
r = service~invoke("deployment_status", "ed209a", "0.18.143")
call must r~ok, "deployment ability"
call must r~value["deployment_state"] = "STUCK_SUSPECTED", "long installer classified stuck suspected"
call must r~value["oldest_deployment_process_seconds"] = 380, "installer elapsed parsed"
call must r~value["deployment_processes"][1]["kind"] = "DEPLOYMENT", "deployment process typed"
call must r~value["probes"][2]["stdout_redacted"] = .true, "raw process stdout redacted"
call must r~value["probes"][2]["stdout"]~items = 0, "redacted process output empty"

/* When installer vanishes, exact expected installed version qualifies as deployed. */
fake~installActive = .false
r = service~invoke("deployment_status", "ed209a", "0.18.143")
call must r~ok, "deployment complete ability"
call must r~value["deployment_state"] = "DEPLOYED", "expected deployed version"
r = service~invoke("deployment_status", "ed209a", "0.18.999")
call must r~ok, "deployment stale ability"
call must r~value["deployment_state"] = "NOT_DEPLOYED_OR_STALE", "unexpected version classified stale"

/* File ability is metadata-only and rejects secret/traversal locations. */
r = service~invoke("file_status", "ed209a", "/usr/local/share/bashqueues/queuebash.sh")
call must r~ok, "ordinary file metadata permitted"
call must r~value["exists"] = .true, "ordinary file exists metadata"
nr = service~invoke("file_status", "ed209a", "/home/opc/.ssh/id_rsa")
call must \nr~ok, "ssh secret path denied"
call must nr~code = "MACHINE_PATH_SENSITIVE", "ssh path sensitivity code"
nr = service~invoke("file_status", "ed209a", "/home/opc/../root/secret")
call must \nr~ok, "traversal denied"
call must nr~code = "MACHINE_PATH_INVALID", "traversal deny code"

nr = service~invoke("memory_status", "ed209z")
call must \nr~ok, "unknown node denied"
call must nr~code = "MACHINE_NODE_NOT_DELEGATED", "unknown node code"

/* Inspect every generated sshnode invocation. No model/user shell primitives leak in. */
do cmd over fake~commands
  call must cmd~pos("/home/hc3/alchemy-autobuild/sshnode.sh") > 0, "sshnode transport fixed"
  call must cmd~pos("--transfer") = 0, "no transfer command"
  call must cmd~pos(">") = 0, "no output redirection"
  call must cmd~pos("<") = 0, "no input redirection"
  call must cmd~pos("|") = 0, "no shell pipe"
  call must cmd~pos(";") = 0, "no shell list"
  call must cmd~lower~pos(" rm ") = 0, "no rm"
  call must cmd~lower~pos(" sudo ") = 0, "no sudo"
end

call sysfiledelete target
say "PASS test_machine_abilities commands=" || fake~commands~items
exit 0

must: procedure
  use arg ok, label
  if \ok then do
    say "FAIL" label
    exit 1
  end
return

::class FakeMachineRunner public
::attribute commands get
::attribute installActive

::method init
  expose commands installActive
  commands = .array~new
  installActive = .true

::method run
  expose commands installActive
  use arg commandText, label = ""
  commands~append(commandText)
  out = .array~new
  err = .array~new
  rc = 0
  lower = commandText~lower
  select
    when lower~pos("cat /proc/meminfo") > 0 then do
      out~append("MemTotal:        1000000 kB")
      out~append("MemAvailable:     500000 kB")
      out~append("SwapTotal:        200000 kB")
      out~append("SwapFree:         150000 kB")
    end
    when lower~pos("df -pk") > 0 then do
      out~append("Filesystem 1024-blocks Used Available Capacity Mounted on")
      out~append("/dev/root 1000000 600000 400000 60% /")
    end
    when lower~pos("ps -eo pid,ppid,user,stat,etime,pcpu,pmem,args") > 0 then do
      out~append("PID PPID USER STAT ELAPSED %CPU %MEM COMMAND")
      if installActive then out~append("220 1 root S 00:06:20 0.0 0.1 /bin/bash /tmp/bashqueues-0.18.143/install-system.sh")
      out~append("300 1 opc S 00:10:00 0.1 0.2 queue system-daemon")
    end
    when lower~pos("queue version") > 0 then out~append("queuebash 0.18.143")
    when lower~pos("queue stats") > 0 then out~append("pending=0 running=0 waiting=0 done=12 failed=1")
    when lower~pos("stat -c") > 0 then out~append("regular file:12345:1780000000:755:root:root:/usr/local/share/bashqueues/queuebash.sh")
    when lower~pos("sha256sum") > 0 then out~append("0123456789abcdef  /usr/local/share/bashqueues/queuebash.sh")
    when lower~pos("systemctl is-active bashqueues-daemon.service") > 0 then out~append("active")
    when lower~pos("systemctl is-active bashqueues-cron.timer") > 0 then out~append("active")
    when lower~pos("cat /etc/os-release") > 0 then do
      out~append('NAME="Oracle Linux Server"')
      out~append('VERSION_ID="9"')
    end
    when lower~pos("uname -a") > 0 then out~append("Linux ed209a 5.15 test")
    when lower~pos("uptime") > 0 then out~append("up 4 days, load average: 0.20, 0.10, 0.05")
    when lower~pos("cat /proc/loadavg") > 0 then out~append("0.20 0.10 0.05 1/100 1234")
    when lower~pos(" 'true'") > 0 then nop
    otherwise do
      rc = 1
      err~append("fake unknown probe " || label)
    end
  end
  d = .directory~new
  d["rc"] = rc
  d["stdout"] = out
  d["stderr"] = err
  d["security_audit"] = .array~of("FAKE delegated command")
  d["security_manager"] = "FakeMachineRunner"
  return .LlmPaResult~success(d)

::requires "LlmPaMachineChecks.cls"
