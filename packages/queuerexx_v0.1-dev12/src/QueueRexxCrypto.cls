/* QueueRexxCrypto.cls - Crypto/Foreign Runtime acceleration seam, v0.1-dev6.
 *
 * QueueRexx keeps the ordinary Crypto .SHA256 API.  Installing the Crypto
 * Foreign Runtime provider changes execution, not the caller-visible API.
 * Pure ooRexx SHA remains Crypto's failover path.
 */

::class QueueCryptoOperation public
::constant SHA256 "crypto.sha256.digest/1"

::class QueueCryptoProvider public
::constant FOREIGN_OPENSSL "foreign.openssl.crypto"
::constant FALLBACK "oorexx.crypto.fallback"

::class QueueCryptoOutcome public
::constant COMPLETED "COMPLETED"

::class QueueDigestResult public
::attribute digest get
::attribute providerId get
::attribute accelerated get
::attribute outcomeCode get
::method init
  expose digest providerId accelerated outcomeCode
  use strict arg digestArg, providerArg = "", acceleratedArg = .false, outcomeArg = ""
  digest = digestArg~string~lower
  providerId = providerArg~string
  accelerated = (acceleratedArg == .true)
  outcomeCode = outcomeArg~string
::method asDirectory
  expose digest providerId accelerated outcomeCode
  d = .Directory~new
  d["digest"] = digest
  d["provider_id"] = providerId
  d["accelerated"] = .QueueRexxUtil~jsonBoolean(accelerated)
  d["outcome_code"] = outcomeCode
  d["operation"] = .QueueCryptoOperation~SHA256
  return d

::class QueueCryptoAcceleration public
::constant DEFAULT_PRIORITY 1000
::constant ENV_DIRECT_BRIDGE "QUEUEREXX_CRYPTO_DIRECT_BRIDGE"
::constant ENV_COMPAT_BRIDGE "QUEUEREXX_CRYPTO_COMPAT_BRIDGE"
::method install class
  use arg directBridgeArg = "", compatBridgeArg = "", priorityArg = .nil
  directBridge = directBridgeArg~string
  compatBridge = compatBridgeArg~string
  if directBridge == "" then directBridge = value(self~ENV_DIRECT_BRIDGE,,"ENVIRONMENT")
  if compatBridge == "" then compatBridge = value(self~ENV_COMPAT_BRIDGE,,"ENVIRONMENT")
  if priorityArg == .nil then priority = self~DEFAULT_PRIORITY; else priority = priorityArg + 0
  if directBridge == "" | compatBridge == "" then raise syntax 88.900 array("Foreign Runtime Crypto bridge paths required")
  if .CryptoLibraryBuild~referenceSwitch == .nil then
    installed = .CryptoForeignRuntimeInstaller~install(directBridge, .nil, priority, .QueueCryptoProvider~FOREIGN_OPENSSL, compatBridge)
  else installed = .Directory~new
  return installed

::method installed class
  return .CryptoLibraryBuild~referenceSwitch \== .nil

::method ensurePreferred class
  if self~installed then return .true
  directBridge = value(self~ENV_DIRECT_BRIDGE,,"ENVIRONMENT")
  compatBridge = value(self~ENV_COMPAT_BRIDGE,,"ENVIRONMENT")
  if directBridge == "" | compatBridge == "" then return .false
  signal on syntax name accelerationUnavailable
  ignore = self~install(directBridge, compatBridge)
  signal off syntax
  return self~installed
accelerationUnavailable:
  signal off syntax
  return .false

::method lastEvidence class
  broker = .RuntimeImplementationSwitch~broker
  if broker == .nil then return .nil
  return broker~lastEvidence

::method foreignSha256Active class
  e = self~lastEvidence
  if e == .nil then return .false
  return e~outcomeCode == .QueueCryptoOutcome~COMPLETED & e~providerId == .QueueCryptoProvider~FOREIGN_OPENSSL

::class QueueDigestProvider public
::method digest
  use strict arg material
  /* Prefer Foreign Runtime automatically when its bridge configuration is
   * available.  The public Crypto API remains unchanged and therefore falls
   * back to pure ooRexx when acceleration is unavailable. */
  ignore = .QueueCryptoAcceleration~ensurePreferred
  return .SHA256~new(material)~digest

::method digestWithEvidence
  use strict arg material
  digestValue = self~digest(material)
  e = .QueueCryptoAcceleration~lastEvidence
  if e == .nil then return .QueueDigestResult~new(digestValue, .QueueCryptoProvider~FALLBACK, .false, "")
  accelerated = e~outcomeCode == .QueueCryptoOutcome~COMPLETED & e~providerId == .QueueCryptoProvider~FOREIGN_OPENSSL
  return .QueueDigestResult~new(digestValue, e~providerId, accelerated, e~outcomeCode)

::requires "QueueRexxCore.cls"
::requires "CryptoForeignRuntimeProvider.cls"
