#!/usr/bin/env rexx
/* Example policy/service setup for parallel Storage Fabric ingress.
 * Requires OperationalPlanner.cls and ServiceDescriptors.cls on REXX_PATH. */
::requires 'OperationalPlanner.cls'
::requires 'ServiceDescriptors.cls'

op=value('OOREXX_OPERATIONAL_PLANNER',,'ENVIRONMENT')
if op='' then op='opctl'
classes=.OperationalClassRegistry~new(op)
classes~register('normal.storage','allow:100:allow:any:30:2:60','throttle:75:allow:any:25:2:50','throttle:50:forbid:protected:15:1:15','suspend:0:forbid:protected:10:1:10')

registry=value('OOREXX_SERVICE_REGISTRY',,'ENVIRONMENT')
if registry='' then registry='services.tsv'
services=.ServiceRegistry~new(registry)
services~register(.ServiceDescriptor~new('storage.range.search','normal.storage','storage-fabric','storage.range.search'))
services~register(.ServiceDescriptor~new('storage.range.read','normal.storage','storage-fabric','storage.range.read'))
say 'PASS normal.storage and named Storage Fabric services registered'
