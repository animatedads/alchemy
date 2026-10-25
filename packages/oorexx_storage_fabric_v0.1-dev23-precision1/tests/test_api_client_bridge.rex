transport=.RecordingApiTransport~new
client=.ApiClient~new(transport)
bridge=.StorageApiClientHttpExecutor~new(client)
h=.directory~new; h['x-test']='yes'
r=bridge~execute('PUT','https://example.invalid/upload',h,'abc','SOURCE_BULK')
call assertEq 204,r~status,'response propagated'
call assertEq 1,bridge~requestCount,'request count'
req=transport~lastRequest
call assertEq 'PUT',req~method,'method mapped'
call assertEq 'https://example.invalid/upload',req~url,'url mapped'
call assertEq 'abc',req~body,'body mapped'
call assertEq 'SOURCE_BULK',req~trafficClass,'traffic class mapped'
call assertEq 'yes',req~headers~at('x-test'),'headers mapped'
say 'PASS Storage -> API Client v0.3+ finite-request bridge'
exit 0

::class RecordingApiTransport subclass ApiTransport public
::attribute lastRequest get
::method execute
  expose lastRequest
  use arg request,session=.nil
  lastRequest=request
  return .ApiResponse~new(request~id,204,.directory~new,'',1,'',0)
::routine assertEq
  use arg e,a,l
  if e<>a then do; say 'FAIL' l 'expected='e 'actual='a; raise syntax 88.900 array('test assertion failed'); end
::requires "src/StorageApiClientBridge.cls"
