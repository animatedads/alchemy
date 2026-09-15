/* Real ooRexx activity stress through the ordinary Crypto SHA API.
 * The provider is shared process-wide; each activity owns its SHA objects and
 * Foreign Runtime owns per-call output buffers/pins. */
parse arg bridge
if bridge = "" then bridge = "../native/openssl_direct.bridge.json"
installed = .CryptoForeignRuntimeInstaller~install(bridge)
broker = installed["broker"]

payload = copies("thread-safe-rocket-" || '00ff'x, 4096)
expected256 = "2afdeab55f248f666cd22b2256ad9f56f64ac11f8a46b8254ba99ddf8d726112"
expected512 = "db15892c4edf2407bf8e62609a939c193662ed5318a2514ae2934524eba7c71f0f4c51ec374b8d02d56d81e54797d60de801e100cc4bc99d9df0cfcbb9984d86"

threads = 12
loops = 40
workers = .Array~new
messages = .Array~new

do i = 1 to threads
  worker = .CryptoShaThreadWorker~new(payload, expected256, expected512, loops)
  workers~append(worker)
  messages~append(worker~start("run"))
end

do i = 1 to threads
  call assertEqual 1, messages[i]~result, "SHA worker " || i
end

/* lastEvidence is deliberately process-global observational state; under
 * concurrency its exact call is nondeterministic, but it must remain a valid
 * completed record from the shared foreign provider. */
e = broker~lastEvidence
call assertEqual "COMPLETED", e~outcomeCode, "concurrent global evidence outcome"
call assertEqual "foreign.openssl.crypto", e~providerId, "concurrent global evidence provider"

installed["target"]~close
.RuntimeImplementationSwitch~reset
.CryptoLibraryBuild~referenceSwitch = .nil
say "PASS thread-safe Foreign Runtime SHA-256/SHA-512 rocket skates"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say "FAIL:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::class CryptoShaThreadWorker
::method init
  expose payload expected256 expected512 loops
  use strict arg payload, expected256, expected512, loops
::method run
  expose payload expected256 expected512 loops
  do i = 1 to loops
    if .SHA256~new(payload)~digest \= expected256 then return 0
    if .SHA512~new(payload)~digest \= expected512 then return 0
  end
  return 1

::requires "CryptoForeignRuntimeProvider.cls"
