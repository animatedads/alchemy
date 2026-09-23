/* Create one measured Job-to-Node v0.6 node probe for FD managed placement. */
parse arg probePath
probePath=probePath~strip
if probePath='' then do; say 'usage: rexx make_fd_job_to_node_probe.rex PROBE.tsv'; exit 64; end
jobId=value('FD_JOB_ID',,'ENVIRONMENT'); nodeId=value('FD_SOURCE_NODE_ID',,'ENVIRONMENT'); ownerNodeId=value('FD_OWNER_NODE_ID',,'ENVIRONMENT'); if ownerNodeId='' then ownerNodeId=nodeId
sourceEvidenceRef=value('FD_SOURCE_EVIDENCE_REF',,'ENVIRONMENT'); arch=value('FD_AUTH_ARCHITECTURE',,'ENVIRONMENT'); memoryMiB=value('FD_AUTH_MEMORY_MIB',,'ENVIRONMENT'); diskMiB=value('FD_AUTH_DISK_MIB',,'ENVIRONMENT'); cpuUnits=value('FD_AUTH_CPU_UNITS',,'ENVIRONMENT'); freeMemoryMiB=value('FD_AUTH_FREE_MEMORY_MIB',,'ENVIRONMENT'); freeDiskMiB=value('FD_AUTH_FREE_DISK_MIB',,'ENVIRONMENT'); availableCpuUnits=value('FD_AUTH_AVAILABLE_CPU_UNITS',,'ENVIRONMENT')
observed=value('FD_AUTH_OBSERVED_EPOCH_MS',,'ENVIRONMENT'); if observed='' then observed=time('T')*1000
leaseMs=value('FD_AUTH_LEASE_MS',,'ENVIRONMENT'); if leaseMs='' then leaseMs=604800000
capGen=value('FD_AUTH_CAPABILITY_GENERATION',,'ENVIRONMENT'); if capGen='' then capGen=1
obsGen=value('FD_AUTH_OBSERVATION_GENERATION',,'ENVIRONMENT'); if obsGen='' then obsGen=1
runtimeGen=value('FD_AUTH_RUNTIME_GENERATION',,'ENVIRONMENT'); if runtimeGen='' then runtimeGen='5.3-r13196'
proofRef=value('FD_AUTH_PROOF_REF',,'ENVIRONMENT')
if jobId='' | nodeId='' | sourceEvidenceRef='' | arch='' | memoryMiB='' | diskMiB='' | cpuUnits='' | freeMemoryMiB='' | freeDiskMiB='' | availableCpuUnits='' then do; say 'FD_MANAGED_PROBE_ERROR missing required job/node/evidence/architecture/capacity environment'; exit 65; end
if \datatype(memoryMiB,'N') | \datatype(diskMiB,'N') | \datatype(cpuUnits,'N') | \datatype(freeMemoryMiB,'N') | \datatype(freeDiskMiB,'N') | \datatype(availableCpuUnits,'N') | \datatype(observed,'N') | \datatype(leaseMs,'N') then do; say 'FD_MANAGED_PROBE_ERROR non-numeric capability/capacity/time value'; exit 65; end
if memoryMiB+0<1 | diskMiB+0<1 | cpuUnits+0<1 | freeMemoryMiB+0<1 | freeDiskMiB+0<1 | availableCpuUnits+0<=0 | observed+0<1 | leaseMs+0<1 then do; say 'FD_MANAGED_PROBE_ERROR invalid capability/capacity/time value'; exit 65; end
if proofRef='' then proofRef='fd-node-probe:'||nodeId||':source='||sourceEvidenceRef||':observed='||observed
s=.FDCheckpointState~new
s~put('schema',.FDDoorMicroMotionManagedPlacementBuild~PROBE_SCHEMA); s~put('job_id',jobId); s~put('source_node_id',nodeId); s~put('owner_node_id',ownerNodeId); s~put('source_evidence_ref',sourceEvidenceRef)
s~put('architecture',arch~upper); s~put('memory_mib',memoryMiB); s~put('disk_mib',diskMiB); s~put('cpu_units',cpuUnits); s~put('free_memory_mib',freeMemoryMiB); s~put('free_disk_mib',freeDiskMiB); s~put('available_cpu_units',availableCpuUnits)
s~put('observed_epoch_ms',observed); s~put('lease_duration_ms',leaseMs); s~put('expires_epoch_ms',(observed+0)+(leaseMs+0)); s~put('capability_generation',capGen); s~put('observation_generation',obsGen); s~put('runtime_generation',runtimeGen); s~put('proof_ref',proofRef)
.FDControlFile~write(probePath,s)
say 'FD_MANAGED_PROBE_OK' probePath 'job='jobId 'node='nodeId 'lease_ms='leaseMs
exit 0
::requires 'FDDoorMicroMotionManagedPlacement.cls'
