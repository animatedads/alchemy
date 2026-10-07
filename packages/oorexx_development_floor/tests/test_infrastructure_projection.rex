registry = .DFNodeProjectionRegistry~new

cloud = .Directory~new
cloud["schema"] = "development.floor.node-observation/0.1"
cloud["node_id"] = "ed209j"
cloud["provider"] = "GCP"
cloud["provider_account_id"] = "gcp-bashqueue"
obs = .Array~new
obs~append(observation("cloud_state", "ALCHEMY_CLOUD_CONTROL", "RUNNING"))
obs~append(observation("reachable", "ALCHEMY_CLOUD_CONTROL", 1))
cloud["observations"] = obs
fw = .Array~new
cloudFacet = .Directory~new
cloudFacet["scope"] = "CLOUD"
cloudFacet["source"] = "ALCHEMY_CLOUD_CONTROL"
cloudFacet["status"] = "OBSERVED"
cloudRules = .Array~new
cloudRules~append(rule("INBOUND", "TCP", "ALLOW", 22, "ADMIN", "ED209J"))
cloudFacet["rules"] = cloudRules
fw~append(cloudFacet)
cloud["firewall"] = fw
node = registry~applySnapshot(cloud)

host = .Directory~new
host["schema"] = "development.floor.node-observation/0.1"
host["node_id"] = "ed209j"
host["provider"] = "GCP"
host["provider_account_id"] = "gcp-bashqueue"
hostObs = .Array~new
hostObs~append(observation("reachable", "SSHNODE", 0))
hostObs~append(observation("free_space", "SSHNODE", "23.4G"))
hostObs~append(observation("memory", "SSHNODE", "3.8G"))
hostObs~append(observation("oorexx_version", "SSHNODE", "5.3.0 r13196"))
hostObs~append(observation("qemu_version", "SSHNODE", "QEMU 8.2.2"))
processes = .Array~of("qemu-system-x86_64 test-17", "rexx test_runner.rex")
hostObs~append(observation("task_processes", "SSHNODE", processes))
host["observations"] = hostObs
hostFw = .Array~new
localFacet = .Directory~new
localFacet["scope"] = "LOCAL"
localFacet["source"] = "SSHNODE"
localFacet["status"] = "OBSERVED"
localRules = .Array~new
localRules~append(rule("INBOUND", "TCP", "ALLOW", 8443, "127.0.0.1", "REXXOS"))
localFacet["rules"] = localRules
hostFw~append(localFacet)
host["firewall"] = hostFw
node2 = registry~applySnapshot(host)

call assertEqual "RUNNING", node~cloudState, "cloud state retained"
call assertEqual 0, node~reachable, "sshnode reachability has operational preference"
call assertEqual 2, node~observations("reachable")~items, "divergent reachability evidence retained"
call assertEqual 1, node~fact("reachable")~bySource("ALCHEMY_CLOUD_CONTROL")~value, "cloud reachability evidence preserved"
call assertEqual 0, node~fact("reachable")~bySource("SSHNODE")~value, "sshnode reachability evidence preserved"
call assertEqual "23.4G", node~freeSpace, "free space projection"
call assertEqual "3.8G", node~memory, "memory projection"
call assertEqual "5.3.0 r13196", node~ooRexxVersion, "ooRexx projection"
call assertEqual "QEMU 8.2.2", node~qemuVersion, "QEMU projection"
call assertEqual 2, node~taskProcesses~items, "task-process projection"
call assertEqual 2, node~firewall~rules~items, "one firewall surface aggregates cloud and local rules"
call assertTrue node~firewall~cloudFacet <> .nil, "cloud firewall facet retained"
call assertTrue node~firewall~localFacet <> .nil, "local firewall facet retained"
call assertEqual "OBSERVED", node~firewall~status, "firewall status"
call assertEqual "23.4G", node~free_space, "dynamic normalized field lookup"
call assertEqual "gcp-bashqueue", node2~providerAccountId, "identity object refreshed rather than replaced"
call assertEqual 1, registry~all~items, "one logical node object"

say "PASS test_infrastructure_projection"
exit 0

observation: procedure
  use arg name, source, value
  d = .Directory~new
  d["name"] = name
  d["source"] = source
  d["value"] = value
  d["status"] = "OBSERVED"
  return d

rule: procedure
  use arg direction, protocol, action, port, sourceSpec, destinationSpec
  d = .Directory~new
  d["direction"] = direction
  d["protocol"] = protocol
  d["action"] = action
  d["port_from"] = port
  d["port_to"] = port
  d["source_spec"] = sourceSpec
  d["destination_spec"] = destinationSpec
  return d

assertEqual: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg value, label
  if \value then do
    say "FAIL" label
    exit 1
  end
  return

::requires "InfrastructureProjection.cls"
