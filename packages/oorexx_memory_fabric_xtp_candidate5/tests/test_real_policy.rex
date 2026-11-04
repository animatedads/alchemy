/* Real Service Descriptors + Operational Degradation Planner dev2. */
services=.ServiceRegistry~new(value('MF_TEST_REGISTRY',,'ENVIRONMENT'))
services~register(.ServiceDescriptor~new('memory.block.read','normal.memory','mu5-mem'))
services~register(.ServiceDescriptor~new('memory.block.invalidate','memory.critical','mu5-mem'))
operational=.OperationalPlanner~new(value('MF_OPCTL',,'ENVIRONMENT'))
control=.MemoryXtpServicePolicy~new(services,operational)
normal=control~forService('memory.block.read','normal')
if normal~className<>'normal.memory' | normal~perContextCapPercent<>30 | normal~maxParallelContexts<>2 | normal~aggregateCapPercent<>60 then do
 say 'FAIL real normal.memory operational class';exit 90
end
emergency=control~forService('memory.block.read','emergency')
if emergency~transmit then do; say 'FAIL memory bulk emergency suspended';exit 91;end
critical=control~forService('memory.block.invalidate','emergency')
if \critical~transmit then do; say 'FAIL memory critical emergency allowed';exit 92;end
say 'PASS real ServiceDescriptor + Operational Planner dev2 memory class and scoped capacity'
exit 0
::requires 'MemoryXtpTransferPlanning.cls'
::requires 'OperationalPlanner.cls'
::requires 'ServiceDescriptors.cls'
