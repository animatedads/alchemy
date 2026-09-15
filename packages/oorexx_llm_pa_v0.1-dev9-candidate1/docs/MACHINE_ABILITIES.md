# Delegated read-only machine abilities

The PA has a deliberately narrow machine-observation surface for the ED209 fleet.  It is not a shell and Gemma is never given arbitrary SSH command text.

The transport is the installation-owned helper:

    /home/hc3/alchemy-autobuild/sshnode.sh

That helper continues to own node usernames, addresses, SSH configuration and key selection.  The PA is not given `--transfer`, credentials, host addresses, key paths, or a generic remote-command ability.

## Authority boundary

Each actual host command is issued by a tiny floating ooRexx `Method` with `LlmPaMachineCheckSecurityManager` attached through `Method~setSecurityManager`.  The manager receives the language processor's `COMMAND` checkpoint and authorises only the exact command created by the selected ability.  Any other host command is rejected.

The SecurityManager independently validates the complete host-command shape: `timeout 20 <configured sshnode.sh> <delegated node> '<known read probe>'`.  The runner cannot enlarge that catalogue merely by passing a new string.  The allowlist is backed by a second deny guard. Delegated machine observations reject shell composition/output mutation and common state-changing operations, including:

    |  >  <  ;  &  backticks
    --transfer
    rm mv cp touch mkdir rmdir ln unlink sudo kill chmod chown truncate tee dd
    mkfs mount umount reboot shutdown poweroff
    systemctl start/stop/restart
    queue submit/run/start/daemon and queue health --fix

stdout and stderr are captured directly into Rexx arrays using `ADDRESS SYSTEM ... WITH OUTPUT USING (...) ERROR USING (...)`; the observation code does not redirect output to files.

The SecurityManager audit remains attached to each probe result.  This is interpreter-enforced containment in addition to the PA's model instructions.

## Delegated abilities

All abilities declare `READ_ONLY`, `mutating=false`, and `eventable=true`.

- `machine_health NODE` — sshnode reachability, kernel, uptime and load.
- `memory_status NODE` — `/proc/meminfo` totals/availability/swap.
- `space_status NODE` — mounted filesystem capacity/free space via `df -Pk`.
- `process_status NODE` — bounded typed observation of relevant queue/worker/analysis/deployment processes. Raw process argument strings are used only for local classification and are redacted before the observation leaves the ability.
- `queue_status NODE` — QueueBash version and aggregate `queue stats` state counts; job payloads/commands are not exposed.
- `configuration_status NODE` — OS release, QueueBash version and installed queue script metadata/hash.
- `file_status NODE ABSOLUTE_PATH` — metadata only (`stat`), with path validation and sensitive-path denial. File contents are never read.
- `deployment_status NODE [EXPECTED_VERSION]` — combines installed QueueBash version, queue script metadata/hash, read-only service state and deployment-process age.

`deployment_status` is conservative.  With an expected version it can report `DEPLOYED` or `NOT_DEPLOYED_OR_STALE`.  If an installer/deployment process is present it reports `IN_PROGRESS`, or `STUCK_SUSPECTED` after five minutes.  Without an expected version and with a quiet installed tree it reports `INSTALLED_QUIESCENT`; it does not invent a deployment event merely because files exist.

## Direct qualification surface

Codex can bypass model selection and request a named observation directly:

    rexx bin/llmpa.rex '-machine "memory_status ed209e"'
    rexx bin/llmpa.rex '-machine "space_status ed209e"'
    rexx bin/llmpa.rex '-machine "deployment_status ed209a 0.18.143"'
    rexx bin/llmpa.rex '-machine "file_status ed209a /usr/local/share/bashqueues/queuebash.sh"'

The response is structured `llm.pa.machine.observation/0.1` evidence with `authority=SECURITY_MANAGER_DELEGATED_READ_ONLY`.

## Natural PA use

For ordinary chat Gemma performs only a constrained selection turn.  It may return:

    NONE

or:

    ABILITY|ability_name|node|argument

Gemma is shown ability descriptions and delegated node IDs but no shell syntax.  ooRexx validates the selected ability/node/argument, executes the fixed SecurityManager-contained probe, then gives the resulting structured evidence back to Gemma for the final answer.

Examples:

    rexx bin/llmpa.rex '-ask "check memory on ED209E"'
    rexx bin/llmpa.rex '-ask "is ED209A healthy and reachable?"'
    rexx bin/llmpa.rex '-ask "did 0.18.143 actually deploy on ED209A or is it stuck?"'

## Eventable, not recurring

An Alarm-fired PA turn may use the same read-only machine abilities.  This does not grant recurrence or mutation authority.

For example:

    remind in ten minutes to check whether deployment 0.18.143 on ED209A is stuck

means:

    one-shot Alarm
      -> fresh PA turn
      -> SecurityManager-contained deployment_status observation
      -> Gemma decides from the evidence
      -> DONE, or Gemma explicitly asks to arm one NEW Alarm

The fired Alarm is over.  The machine ability cannot create another Alarm itself.
