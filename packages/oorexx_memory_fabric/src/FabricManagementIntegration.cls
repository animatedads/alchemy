/* FabricManagementIntegration.cls
 * Thin management seam for MU discovery and intention/commissioning presentation.
 * Does not implement Intention semantics: callers receive ordinary state objects.
 */

::class FabricManagementIntegration public

::method init
  expose memoryRegistry storageLocator
  use strict arg memoryRegistry, storageLocator=.nil

::method memoryServiceForMU
  expose memoryRegistry
  use strict arg muId
  return memoryRegistry~discoverForMU(muId)

::method memoryCapacityOptions
  expose memoryRegistry
  use strict arg requesterMuId, requesterMachineId="", requesterSiteId="", bytes=0
  result=.array~new
  do p over memoryRegistry~providers
    d=.directory~new
    d["provider_id"]=p~providerId
    d["provider_kind"]=p~kind
    d["provider_mu"]=p~muId
    d["provider_mi"]=p~miId
    d["state"]=p~providerState
    d["allocation_state"]=p~allocationState
    d["capacity_bytes"]=p~capacityBytes
    d["available_bytes"]=p~availableBytes
    d["eligible_general"]=p~acceptsGeneralAllocation
    d["eligible_spare"]=p~eligibleAsSpare
    d["locality_cost"]=memoryRegistry~localityCost(requesterMuId,requesterMachineId,requesterSiteId,p)
    d["fits"]=p~availableBytes>=bytes+0
    result~append(d)
  end
  return result

::method storageService
  expose storageLocator
  return storageLocator
