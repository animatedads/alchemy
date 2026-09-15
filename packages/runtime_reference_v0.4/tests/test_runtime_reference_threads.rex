/* Runtime Reference v0.4 real ooRexx activity concurrency proof.
 * The provider deliberately remains in-flight long enough to prove that the
 * process-wide switch, broker, and object-provider adapter do not hold ooRexx
 * object monitors across provider execution. */

counter = .OverlapCounter~new
target = .ConcurrentProvider~new(counter)
provider = .RuntimeObjectImplementationProvider~new("test.concurrent", target)
reference = .RuntimeImplementationReference~new(provider, 100, .true, 2, 1)
broker = .RuntimeImplementationBroker~new
broker~register("test.concurrent.echo/1", reference)
.RuntimeImplementationSwitch~installBroker(broker)

workers = .Array~new
messages = .Array~new
threads = 8

do i = 1 to threads
  worker = .ReferenceThreadWorker~new
  workers~append(worker)
  messages~append(worker~start("run", i))
end

do i = 1 to threads
  value = messages[i]~result
  call assertEqual i, value, "concurrent provider result " || i
end

call assertTrue counter~peak >= 2, "provider calls overlap across ooRexx activities"
call assertEqual "test.concurrent", broker~lastEvidence~providerId, "global evidence remains valid under concurrency"
call assertEqual "COMPLETED", broker~lastEvidence~outcomeCode, "global evidence completion under concurrency"

.RuntimeImplementationSwitch~reset
say "PASS Runtime Reference real activity concurrency"
exit 0

assertTrue: procedure
  use arg truth, label
  if \truth then do
    say "FAIL:" label
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say "FAIL:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::class OverlapCounter
::method init
  expose active peakValue
  active = 0
  peakValue = 0
::method enter
  expose active peakValue
  active += 1
  if active > peakValue then peakValue = active
::method leave
  expose active
  active -= 1
::method peak
  expose peakValue
  return peakValue

::class ConcurrentProvider
::method init
  expose counter
  use strict arg counter
::method runtimeImplementationInvoke unguarded
  expose counter
  use strict arg operationId, request, contract
  if operationId \= "test.concurrent.echo/1" then return .RuntimeProviderResult~failure("UNSUPPORTED", operationId, "test.concurrent")
  counter~enter
  call SysSleep .08
  counter~leave
  return .RuntimeProviderResult~success(request["value"], "test.concurrent", "sleep.echo/1")

::class ReferenceThreadWorker
::method run
  use strict arg value
  request = .Directory~new
  request["value"] = value
  attempt = .RuntimeImplementationSwitch~invokePure("test.concurrent.echo/1", request)
  if \attempt~handled then return -1
  return attempt~value

::requires "RuntimeImplementationReference.cls"
