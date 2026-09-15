/* ooRexx Storage Fabric v0.1-dev6
 * Optional bridge from Storage bounded HTTP work to API Client v0.3+.
 */
::class StorageApiClientBridgeBuild public
::constant VERSION "0.1-dev6"
::constant API "storage.fabric.api-client-bridge/0.1"
::constant REQUIRES_API_CLIENT "api.client/0.3+"

::class StorageApiClientHttpExecutor subclass StorageHttpExecutor public
::attribute requestCount get
::method init
  expose client route originNode requestCount
  use arg clientArg, routeArg=.nil, originArg=""
  if clientArg==.nil then raise syntax 88.900 array("API Client object is required")
  client=clientArg; route=routeArg; originNode=originArg~string; requestCount=0
::method execute
  expose client route originNode requestCount
  use arg methodArg,urlArg,headersArg=.nil,bodyArg="",trafficArg="SOURCE_BULK"
  requestCount+=1
  if headersArg==.nil then headersArg=.directory~new
  metadata=.directory~new
  metadata["component"]="storage.fabric"
  metadata["adapter"]="google-drive"
  id="storage-drive-"||requestCount||"-"||date("S")||"-"||time("S")
  request=.ApiRequest~new(id,methodArg,urlArg,headersArg,bodyArg,trafficArg,50,1000000,1000000,"",metadata,route,originNode)
  return client~execute(request)

::requires "ApiClient.cls"
::requires "src/StorageGoogleDrive.cls"
