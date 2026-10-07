/* Runtime HTTPS transport using the portfolio ooRexx API Client. */
::class OdooApiClientTransport subclass OdooJSON2Transport public
::attribute client get
::attribute baseUrl get
::method init
  expose client baseUrl apiKey database requestSeq
  use arg clientArg,baseUrlArg,apiKeyArg,databaseArg=""
  client=clientArg; baseUrl=baseUrlArg~strip("T","/"); apiKey=apiKeyArg~string; database=databaseArg~string; requestSeq=0
  if client==.nil | baseUrl="" | apiKey="" then raise syntax 88.940 array("API Client, Odoo base URL and API key required")
::method call
  expose client baseUrl apiKey database requestSeq
  use arg model,method,args
  requestSeq+=1
  headers=.directory~new
  headers["Authorization"]="bearer "||apiKey
  headers["Content-Type"]="application/json"
  headers["User-Agent"]="ooRexx-Odoo-CRM/0.1"
  if database<>"" then headers["X-Odoo-Database"]=database
  body=.json~toJson(args)
  url=baseUrl||"/json/2/"||model||"/"||method
  id="odoo-"||requestSeq||"-"||date("S")||"-"||time("S")
  request=.ApiRequest~new(id,"POST",url,headers,body,"API_CONTROL",50,2000000,2000000,"",.directory~new,.nil,"")
  response=client~execute(request)
  if response~status<200 | response~status>=300 then return .OdooCRMProviderResult~failure("ODOO_HTTP_"||response~status,response~body)
  if response~body="" then return .OdooCRMProviderResult~success(.nil)
  return .OdooCRMProviderResult~success(.json~fromJson(response~body))
::requires "json.cls"
