
::class HttpRequest public
::attribute method get
::attribute path get
::attribute body get
::attribute headers get
::method init
 expose method path body headers
 use arg methodArg,pathArg,rawPathArg='',queryArg='',versionArg='HTTP/1.1',headersArg=.nil,bodyArg='',completeArg=.true
 method=methodArg~string; path=pathArg~string; body=bodyArg~string
 if headersArg==.nil then headers=.directory~new; else headers=headersArg
::method header
 expose headers
 use arg nameArg, defaultArg=''
 key=nameArg~string~lower
 do k over headers
   if k~string~lower=key then return headers[k]
 end
 return defaultArg

::class HttpResponse public
::attribute status get
::attribute body get
::attribute contentType get
::attribute headers get
::method init
 expose status body contentType headers
 use arg statusArg,bodyArg='',typeArg='text/plain'
 status=statusArg+0; body=bodyArg~string; contentType=typeArg~string; headers=.directory~new
::method empty class
 use arg statusArg
 return .HttpResponse~new(statusArg,'','')
::method text class
 use arg bodyArg,statusArg=200
 return .HttpResponse~new(statusArg,bodyArg,'text/plain')
::method header
 expose headers
 use arg nameArg,valueArg
 headers[nameArg~string]=valueArg
 return self
