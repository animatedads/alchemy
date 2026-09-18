/* Optional Storage Fabric self-observation adapter for component.projection/0.1.
 * It observes supplied authoritative Storage Fabric objects only. It does not
 * make Component Projection a Storage Fabric dependency and exposes no control. */
::class ComponentProjectionStorageFabricBuild public
::constant VERSION "0.1-dev1"
::constant API "component.projection.storage-fabric/0.1"

::class StorageFabricComponentProjectionSource subclass ComponentProjectionSource public
::method init
  expose catalogue workspace
  use strict arg catalogueArg=.nil,workspaceArg=.nil
  catalogue=catalogueArg; workspace=workspaceArg
  if catalogue==.nil & workspace==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_STORAGE_SOURCE_REQUIRED")
::method read
  expose catalogue workspace
  use strict arg keyArg
  if keyArg~isA(.Array) | keyArg~items<2 then raise syntax 88.900 array("COMPONENT_PROJECTION_STORAGE_KEY_INVALID")
  scope=keyArg[1]~string; field=keyArg[2]~string
  if scope="catalogue" then do
    if catalogue==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_STORAGE_CATALOGUE_UNAVAILABLE")
    if field="count" then return catalogue~count
    if field="objects" then return catalogue~all
  end
  if scope="workspace" then do
    if workspace==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_STORAGE_WORKSPACE_UNAVAILABLE")
    if field="allocations" then return workspace~allocations
    if field="allocation_count" then return workspace~allocations~items
  end
  if scope="allocation" then do
    if workspace==.nil | keyArg~items<3 then raise syntax 88.900 array("COMPONENT_PROJECTION_STORAGE_WORKSPACE_UNAVAILABLE")
    id=keyArg[2]~string; field=keyArg[3]~string; found=.nil
    do a over workspace~allocations; if a~allocationId=id then do; found=a; leave; end; end
    if found==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_STORAGE_ALLOCATION_NOT_FOUND",id)
    select
      when field="state" then return found~state
      when field="reserved_bytes" then return found~reservedBytes
      when field="owner" then return found~owner
      when field="locator" then return found~locator
      when field="pool_id" then return found~pool~poolId
      otherwise raise syntax 88.900 array("COMPONENT_PROJECTION_STORAGE_FIELD_INVALID",field)
    end
  end
  raise syntax 88.900 array("COMPONENT_PROJECTION_STORAGE_KEY_INVALID")

::class StorageFabricComponentProjectionAdapter public
::method init
  expose registry catalogue workspace root componentName source knownAllocations
  use strict arg registryArg,catalogueArg=.nil,workspaceArg=.nil,rootArg="/storage",componentArg="StorageFabric"
  registry=registryArg; catalogue=catalogueArg; workspace=workspaceArg
  if registry==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_STORAGE_REGISTRY_REQUIRED")
  root=.ComponentProjectionPath~normalize(rootArg); componentName=componentArg~string
  source=.StorageFabricComponentProjectionSource~new(catalogue,workspace); knownAllocations=.directory~new
::method install
  expose catalogue workspace root
  if catalogue<>.nil then do
    self~report(root||"/catalogue/count",.array~of("catalogue","count"),"Storage catalogue object count")
    self~report(root||"/catalogue/objects",.array~of("catalogue","objects"),"Storage catalogue objects","application/x-oorexx-array")
  end
  if workspace<>.nil then do
    self~report(root||"/workspace/allocation_count",.array~of("workspace","allocation_count"),"Workspace allocation count")
    self~report(root||"/workspace/allocations",.array~of("workspace","allocations"),"Workspace allocations","application/x-oorexx-array")
  end
  return self~refresh
::method refresh
  expose registry workspace root componentName knownAllocations
  if workspace==.nil then return 0
  now=.directory~new
  do a over workspace~allocations
    id=a~allocationId~string; now[id]=.true
    if knownAllocations[id]<>.nil then iterate
    base=root||"/workspace/allocations/"||self~pathName(id)
    self~report(base||"/state",.array~of("allocation",id,"state"),"Allocation state")
    self~report(base||"/reserved_bytes",.array~of("allocation",id,"reserved_bytes"),"Reserved bytes")
    self~report(base||"/owner",.array~of("allocation",id,"owner"),"Allocation owner")
    self~report(base||"/locator",.array~of("allocation",id,"locator"),"Allocation locator")
    self~report(base||"/pool_id",.array~of("allocation",id,"pool_id"),"Owning pool id")
  end
  do old over knownAllocations
    if now[old]<>.nil then iterate
    registry~unregisterTree(root||"/workspace/allocations/"||self~pathName(old),componentName)
  end
  knownAllocations=now
  return now~items
::method uninstall
  expose registry root componentName knownAllocations
  n=registry~unregisterTree(root,componentName); knownAllocations=.directory~new; return n
::method report private
  expose registry componentName source
  use strict arg pathArg,keyArg,descriptionArg,mediaTypeArg="text/plain"
  if registry~endpoint(pathArg)==.nil then registry~registerReport(componentName,pathArg,source,keyArg,mediaTypeArg,descriptionArg)
  return .true
::method pathName private
  use strict arg nameArg
  name=nameArg~string; name=changestr("%",name,"%25"); name=changestr("/",name,"%2F"); return name
::requires "ComponentProjection.cls"
