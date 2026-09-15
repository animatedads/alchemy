broker = .RuntimeImplementationBroker~new
provider = .RuntimeObjectImplementationProvider~new("demo.provider", .DemoProvider~new)
reference = .RuntimeImplementationReference~new(provider, 100)
broker~register("demo.square/1", reference)
.RuntimeImplementationSwitch~installBroker(broker)

request = .Directory~new
request["value"] = 12
attempt = .RuntimeImplementationSwitch~invokePure("demo.square/1", request)
if attempt~handled then say "reference result:" attempt~value
else say "native fallback would run; reason=" attempt~code

::class DemoProvider public
::method runtimeImplementationInvoke
  use strict arg operationId, request, contract
  if operationId == "demo.square/1" then return .RuntimeProviderResult~success(request["value"] ** 2, "demo.provider", "demo.square")
  return .RuntimeProviderResult~failure("UNSUPPORTED", operationId, "demo.provider")

::requires "RuntimeImplementationReference.cls"
