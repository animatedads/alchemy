/* True ooRexx -> native libxtp -> named-service FIRST loopback contract. */
path=value('MF_TEST_REGISTRY',,'ENVIRONMENT')
reg=.ServiceRegistry~new(path)
reg~register(.ServiceDescriptor~new('memory.block.read','normal.memory','mem-mu5','memory.block.read'))
manager=.XtpNamedServiceManager~new(reg)
control=.MemoryXtpNamedControl~new(manager)
bytes='MF-CONTROL-FIRST'
rc=control~send('memory.block.read',bytes)
if rc<>length(bytes) then do
  say 'FAIL named service send' rc
  exit 75
end
say 'PASS real ooRexx XTP named-service send' rc
exit 0
::requires 'MemoryXtpTransferPlanning.cls'
::requires 'ServiceDescriptors.cls'
::requires 'XtpNamedServices.cls'
