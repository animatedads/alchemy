/* BoshApiClientAdapter.cls
 * Optional BOSH -> ooRexx API Client HTTP exchange adapter.
 * No XMPP, SocketProvider or XTP semantics belong here.
 */
::class BoshApiClientAdapterBuild public
::constant VERSION "0.1-dev1"
::constant API "bosh.api-client.exchange/0.1"

::class BoshApiClientExchangeProvider public subclass BoshHttpExchangeProvider
::method init
  expose client routeRequirement trafficClass priority expectedMicroWlu requestedRate originNode allowCleartext sequence
  use strict arg apiClient, routeRequirementArg=.nil, trafficClassArg="INTERACTIVE", priorityArg=50, -
      expectedMicroWluArg=1000000, requestedRateArg=1000000, originNodeArg="", allowCleartextArg=.false
  if apiClient=.nil then raise syntax 88.900 array("BOSH API Client adapter requires ApiClient")
  client=apiClient
  if routeRequirementArg=.nil then routeRequirement=.ApiRouteRequirement~new
  else routeRequirement=routeRequirementArg
  trafficClass=translate(strip(trafficClassArg))
  priority=priorityArg+0
  expectedMicroWlu=expectedMicroWluArg+0
  requestedRate=requestedRateArg+0
  originNode=originNodeArg~string
  allowCleartext=allowCleartextArg<>.false
  sequence=0

::method exchange
  expose client routeRequirement trafficClass priority expectedMicroWlu requestedRate originNode allowCleartext sequence
  use strict arg uri, method, headers, body
  target=uri~string~strip
  if target="" then return .BoshHttpResponse~new(0,"",self~metadata("EMPTY_URI"))
  lower=translate(target)
  if pos("HTTPS://",lower)<>1 then do
    if pos("HTTP://",lower)=1 then do
      if \allowCleartext then return .BoshHttpResponse~new(0,"",self~metadata("CLEARTEXT_HTTP_DENIED"))
    end
    else return .BoshHttpResponse~new(0,"",self~metadata("UNSUPPORTED_URI_SCHEME"))
  end

  sequence+=1
  requestId="bosh-http-"||sequence
  if headers=.nil then requestHeaders=.directory~new
  else requestHeaders=headers
  metadata=.directory~new
  metadata["source"]="BOSH"
  request=.ApiRequest~new(requestId,method,target,requestHeaders,body,trafficClass,priority, -
      expectedMicroWlu,requestedRate,"",metadata,routeRequirement,originNode)
  response=client~execute(request)
  if response=.nil then return .BoshHttpResponse~new(0,"",self~metadata("API_CLIENT_NO_RESPONSE"))

  responseMetadata=.directory~new
  responseMetadata["api_client_error"]=response~errorCode
  responseMetadata["http_version"]=response~httpVersion
  responseMetadata["final_url"]=response~finalUrl
  responseMetadata["redirect_count"]=response~redirectCount
  responseMetadata["egress_node_id"]=response~egressNodeId
  responseMetadata["session_id"]=response~sessionId
  responseMetadata["headers"]=response~headers
  return .BoshHttpResponse~new(response~status,response~body,responseMetadata)

::method metadata private
  use strict arg code
  d=.directory~new
  d["api_client_error"]=code
  return d

::requires "BoshTransport.cls"
::requires "ApiClient.cls"
