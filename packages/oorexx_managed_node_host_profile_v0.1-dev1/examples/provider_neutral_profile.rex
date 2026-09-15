/* Provider IDs/endpoints are deployment configuration; example uses placeholders. */
id=.ManagedNodeHostIdentity~new("REMOTE-CPU-01","OCI","provider-resource-id","tiny-node","NO_INCREMENTAL_COST","UK-LONDON-1","AD-1","FD-1",.true)
p=.ManagedNodeCapabilityProfile~new(id~nodeId,.true,.true,"linux-boot-id","X86_64",946,30720,1,.array~of("OOREXX"),.array~of("COMMAND","TEST","COMPUTE"),"capability-proof-ref")
s=.ManagedNodeCapacitySample~new(id~nodeId,487,24576,1,0,0,0,"capacity-proof-ref")
pub=.ManagedNodeHostProfilePublisher~new
say pub~capability(id,p,1)~canonical
say pub~capacity(s,1,1,1000,61000)~canonical
::requires "../src/ManagedNodeHostProfile.cls"
