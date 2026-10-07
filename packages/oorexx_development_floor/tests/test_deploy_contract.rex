phases = .DFTestDeploymentContract~phases
call assertEqual 12, phases~items, "phase count"
call assertEqual "REQUEST_RESOURCE_SET", phases[1], "first phase"
call assertEqual "RESERVE_WLU", phases[3], "WLU before execution"
call assertEqual "ASSIGN_QEMU", phases[4], "QEMU assignment"
call assertEqual "ACQUIRE_NETWORK_LEASE", phases[5], "network lease"
call assertEqual "COLLECT_EVIDENCE", phases[8], "evidence before cleanup"
call assertEqual "CLEAR_DOWN", phases[9], "clear down"
call assertEqual "REVOKE_NETWORK_LEASE", phases[10], "un-punch ports"
call assertEqual "RELEASE_HOST", phases[12], "host released last"

profiles = .DFTestDeploymentContract~networkProfiles
call assertEqual 4, profiles~items, "network profiles"
call assertEqual "NONE", profiles[1], "no network profile"
call assertEqual "CROSS_HOST", profiles[4], "cross-host network profile"

topologies = .DFTestDeploymentContract~topologies
call assertEqual 4, topologies~items, "topologies"
call assertEqual "PAIRED_RTO", topologies[2], "paired RTO topology"
call assertEqual "FORENSIC_FAILOVER", topologies[4], "forensic failover topology"

say "PASS test_deploy_contract"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "Registrations.cls"
