/* AlchemyInspectorBridge.cls - bounded bridge to the good Inspector Clouseau (Alchemy Objects v0.4.3). */

::class AlchemyInspectorBridge public
::attribute maxCollectionSample get
::attribute probesEnabled get

::method init
  expose allowProbes maxCollectionSample probesEnabled
  use strict arg allowProbes = .false, maxCollectionSample = 200
  probesEnabled = allowProbes

::method inspectObject public
  expose allowProbes
  use strict arg target
  if target == .nil then raise syntax 88.900 array("inspectObject target must not be .nil")
  inspector = .InspectorClouseau~new
  inspector~reportCollectionSizes(.true)
  inspector~reportQueueItems(.true)
  inspector~reportInheritanceMap(.true)
  inspector~suppressInternalClassMethods(.true)
  inspector~dontFollowPackage("REXX")

  /* Never traverse the base object's authority/key-bearing service links.  A
   * probe may report the slot as a bounded descriptor on the root object, but
   * the walker must not descend into sealers, capability authorities or locked
   * method vaults where in-memory provider keys may live. */
  inspector~dontFollowPath("*ALCHEMYEVIDENCESEALER*")
  inspector~dontFollowPath("*ALCHEMYCAPABILITYAUTHORITY*")
  inspector~dontFollowPath("*ALCHEMYLOCKEDMETHODVAULT*")
  inspector~suppressObjectOutputForPath("*ALCHEMYEVIDENCESEALER*", .true)
  inspector~suppressObjectOutputForPath("*ALCHEMYCAPABILITYAUTHORITY*", .true)
  inspector~suppressObjectOutputForPath("*ALCHEMYLOCKEDMETHODVAULT*", .true)
  if allowProbes then inspector~enableProbes(.true)

  /* Deliberately avoid attach(): attach() seeds .environment/.local/.context. */
  inspector~addRoot("alchemy-target", target)
  signal on syntax name noPackage
  inspector~addPackage(target~class~package)
noPackage:
  signal off syntax
  snap = inspector~snapshot
  return snap~asDirectory

::requires "../inspector/InspectorClouseau.cls"
