/* Provider-neutral application. This example uses the deterministic memory
   provider; a GDB/MI, JDWP or DbgEng provider occupies the same slot. */
registry=.DebugProviderRegistry~new
provider=.DebugMemoryProvider~new
registry~register(provider)
debugger=.DebugRuntime~new(registry)
target=.DebugTarget~new('demo','PROCESS','Demo Process',.nil,.array~of('DEBUG.MEMORY'))

session=debugger~attach(target)
session~when(.Execution~enters('calculateInvoice'))~notify(.Observer~new,'invoice')

say 'Application has registered semantic debugging behaviour.'
exit

::class Observer
::method invoice
  use strict arg event
  say 'calculateInvoice hit'

::requires "DebugRuntime.cls"
