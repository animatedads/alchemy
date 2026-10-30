parse arg target discoveryDir
if strip(target) == "" then target = "ED209Z"
if strip(discoveryDir) == "" then discoveryDir = value("MVS_DISCOVERY_DIR",, "ENVIRONMENT")
if strip(discoveryDir) == "" then backend = .MvsThreePlaneFixtureBackend~new
else backend = .MvsDiscoveryDirectoryBackend~new(discoveryDir)
runner = .MvsIntentionRunner~new(target, backend)
say "MVS INTENTION -" translate(target)
if strip(discoveryDir) == "" then say "DISCOVERY: three-plane qualification fixture"
else say "DISCOVERY:" discoveryDir
say "Plain English in; safe discovery occurs before every proposal. Empty line exits."
do forever
  call charout , "> "
  line = linein()
  if strip(line) == "" then leave
  d = runner~input(line)
  say "STATUS:" d~status
  say "DISCOVERY_PROBES:" runner~snapshot~probeCount
  if d~status == "READY" then do
    say "INTENTION:" d~registration~id
    say runner~render(d)
  end
  else say "MEANING:" d~question
end
exit 0
::requires "MvsIntention.cls"
