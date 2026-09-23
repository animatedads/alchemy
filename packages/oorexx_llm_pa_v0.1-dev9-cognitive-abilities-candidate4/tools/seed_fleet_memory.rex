/* Seed Gemma's durable operational memory through Queue Fabric.
 * Facts are operator-provided operational context; no live status is implied.
 */
parse source . . here
base = filespec("L", here)
storeRoot = value("LLMPA_STORE_ROOT", , "ENVIRONMENT")
if storeRoot = "" then storeRoot = base || "../runtime"
address command "mkdir -p" storeRoot
address command "mkdir -p" (storeRoot || "/queue")

facts = .array~of( -
  .array~of("ED209A", "video worker; Oracle Linux; host 193.123.184.140; user opc; use ./sshnode.sh; camera dependencies previously validated"), -
  .array~of("ED209B", "video worker; Oracle Linux; host 193.123.190.35; user opc; use ./sshnode.sh; dependency and availability recovery may be required before release"), -
  .array~of("ED209C", "audio worker; Azure host 52.146.17.8; user azureuser; use ./sshnode.sh; completed audio campaign work and should not receive FC camera work"), -
  .array~of("ED209D", "video worker; AWS host 16.170.244.216; user ec2-user; SSH key is ~/.ssh/AMAZON.pem; camera FFmpeg and native runtime were validated; strong video worker"), -
  .array~of("ED209E", "video worker; Google Compute Engine instance instance-20260906-161857; project delta-coil-353614; zone us-central1-a; current host may change after reboot; user animated.ads.cy; manage recovery with supplied GCloud tooling; serial console is useful when SSH is unavailable"), -
  .array~of("ED209H", "audio worker; host 155.138.214.182; user linuxuser; use ./sshnode.sh; completed audio campaign work and should not receive FC camera work"), -
  .array~of("ED209I", "video worker; Azure host 20.114.63.150; user azureuser; use ./sshnode.sh; camera dependencies require host-local validation"), -
  .array~of("ED209X", "Android phone running Termux; host 192.168.188.25; SSH port 8022; user u0_a329; use ./sshnode.sh ed209x; large data belongs on SD card /storage/9C33-6BBD; do not delete WhatsApp or perform broad cleanup"), -
  .array~of("FLEET_ROLES", "video processing uses A, B, D, E and I; audio processing uses C and H; X is a portability/performance node, not a normal campaign worker"), -
  .array~of("SSH", "use the repository ./sshnode.sh helper; it owns node usernames, hosts, keys and ED209X port 8022; do not invent alternate SSH commands unless diagnosing the helper"), -
  .array~of("GCloud", "Google operations use the supplied local gcloud path and project delta-coil-353614; E recovery may require serial output, reset/reboot, then SSH and queue verification"), -
  .array~of("QUEUEBASH", "fleet queue version target is 0.18.142; use BashQueues for rebuilds, dependency builds, campaign submissions, restarts and collection; replacement scripts take effect on the next usage cycle without restarting the queue service"), -
  .array~of("QUEUE_DEPENDENCIES", "when a build, runtime preparation and analysis depend on one another, submit them as an explicit queue dependency chain; do not start analysis before its dependency gate is complete"), -
  .array~of("CAMERA_PACKAGE", "FC Camera Events v0.1-dev2; entry point tools/analyse_fc_camera_events.rex; each successful job must produce camera_events, events, samples, scene, window, reflections and run TSV evidence; run status must be OK"), -
  .array~of("CAMERA_DEPENDENCIES", "camera processing requires ooRexx 5.3.0 r13196, host-compatible FFmpeg, host-local native Foreign Runtime, ooRexx AI/API dependencies where used, and a passed validation gate; FFmpeg/native shared libraries must not be assumed portable across hosts"), -
  .array~of("AUDIO_PACKAGE", "audio workers use Audio V9 Voice Recovery v0.1-dev16; dev16 adds bounded reflection-aware reconstruction evidence; logical worker identity must remain stable when work is moved between physical machines"), -
  .array~of("FC_SOURCE", "FC camera source files are provided under /home/hc3/alchemy-autobuild/bundles/space/fc/ on the controller; use the same FC files as the 2100-1400 audio campaign; never delete the source files from this machine"), -
  .array~of("AUDIO_CAMPAIGN", "the audio echo campaign covers the full 2100-1400 period split across multiple jobs; C and H are the audio workers; collect result bundles before considering the campaign complete"), -
  .array~of("VIDEO_CAMPAIGN", "the FC video campaign is split into multiple jobs across A, B, D, E and I; release a small smoke job after dependency validation, then release remaining jobs; B/E may be held independently while healthy nodes proceed"), -
  .array~of("EVIDENCE", "harvest evidence before cleanup; failed or timed-out jobs retain input and partial evidence for diagnosis; only successful jobs with run.tsv status OK may have node-local temporary inputs cleaned"), -
  .array~of("LOW_RAM", "the least capable nodes are the low-RAM machines; avoid excessive concurrency, watch memory pressure, swap, disk latency and I/O; a busy node is not automatically dead"), -
  .array~of("SAFETY", "development machines are in scope for low-risk queue and diagnostic work, but do not perform broad deletion, follow symlinks for deletion, or remove original source/archive data; preserve broken-build backups and historical evidence"), -
  .array~of("GEMMA_STYLE", "Gemma is cheerful and helpful but tends to add fluff; prefer evidence-backed machine-specific advice and explicitly distinguish remembered facts, observations, recommendations and actions"), -
  .array~of("MODEL_BOUNDARY", "Gemma may recommend or propose an action, but only the authorised ooRexx tool broker/Codex path can perform live machine operations; never claim live status without a tool result") )

manager = .ObjectQueueManager~new(storeRoot || "/queue", .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
ready = binding~ensureQueues
if \ready~ok then do; say "FAIL ensure queues" ready~code; exit 1; end
memory = .LlmPaMemoryStore~new(storeRoot || "/memory.journal")
worker = .LlmPaWorker~new(binding, memory)
passed = 0
do fact over facts
  submitted = binding~submit("remember", fact[1], fact[2], "codex")
  if \submitted~ok then do; say "FAIL submit" fact[1]; exit 1; end
  processed = worker~processOne
  if \processed~ok then do; say "FAIL process" fact[1]; exit 1; end
  reply = binding~collectReply(submitted~value["request_id"])
  if \reply~ok then do; say "FAIL reply" fact[1]; exit 1; end
  passed += 1
end
say "PASS seeded fleet facts=" || passed
say "LLMPA_STORE_ROOT=" || storeRoot
exit 0

::requires "LlmPaWorker.cls"
