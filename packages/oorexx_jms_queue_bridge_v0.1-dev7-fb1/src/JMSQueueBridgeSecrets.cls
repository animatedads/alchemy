/*
 * JMSQueueBridgeSecrets.cls - optional Secret Broker credential adapter.
 *
 * This file keeps ooRexx Secret Broker as an optional side-by-side dependency.
 * JMSQueueBridge.cls itself remains usable with environment-backed credentials
 * and does not require SecretBroker.cls.
 */

::class JMSBridgeSecretBrokerCredentials subclass AlchemyObject public
::attribute usernameReference get
::attribute passwordReference get

::method init
  expose broker usernameReference passwordReference
  use strict arg brokerArg, usernameReferenceArg = "", passwordReferenceArg = ""
  if brokerArg == .nil then raise syntax 88.900 array("JMS Secret Broker credentials require a broker")
  if \brokerArg~hasMethod("ACQUIRE") then raise syntax 88.900 array("JMS Secret Broker credentials require acquire(reference)")
  broker = brokerArg
  usernameReference = usernameReferenceArg~string~strip
  passwordReference = passwordReferenceArg~string~strip

  meta = .directory~new
  meta["purpose"] = "Resolve JMS credential references through ooRexx Secret Broker into short-lived bridge credential leases"
  meta["package_version"] = .JMSQueueBridgeBuild~VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = .array~of(.JMSQueueBridgeBuild~API, "secret.broker/0.2", "ALCHEMY-HOUSE-OBJECT-0.8")
  meta["design_limitations"] = .array~of("Secret values exist transiently in one bridge credential lease while a JMS connection is established", "This adapter does not provide hardware-backed storage or cross-process secret isolation")
  self~init:super(meta)

  self~registerStateVariable("broker", "SECRET", "Secret Broker authority reference; secret values are not retained here")
  self~registerStateVariable("usernameReference", "INTERNAL", "logical Secret Broker reference for JMS username")
  self~registerStateVariable("passwordReference", "INTERNAL", "logical Secret Broker reference for JMS password")
  self~registerMethodContract("ACQUIRE", "Acquire one short-lived JMS credential pair", .array~new, "JMSBRIDGERESULT", .true, "AUTO", "SECRET", "SECURITY_BOUNDARY", "READ", "USE")
  self~describeMethodPolicy("ACQUIRE", "TRUE", "SECRET", "SENSITIVE", "READ", "USE")
  self~registerExternalRequirement("library", "oorexx_secret_broker", "secret.broker/0.2", .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~recordRelationship("SECRET_BROKER", broker, "credential lease authority", "SECRET")
  self~declareHouseCompliance(95)

::method acquire public protected
  expose broker usernameReference passwordReference
  usernameLease = .nil
  passwordLease = .nil

  username = ""
  if usernameReference \= "" then do
    usernameLease = broker~acquire(usernameReference)
    if usernameLease == .nil then return .JMSBridgeResult~failure("JMS_USERNAME_SECRET_UNAVAILABLE", usernameReference)
    if \usernameLease~hasMethod("OK") then return .JMSBridgeResult~failure("JMS_USERNAME_SECRET_UNAVAILABLE", usernameReference)
    if \usernameLease~ok then return .JMSBridgeResult~failure("JMS_USERNAME_SECRET_UNAVAILABLE", usernameReference)
    usernameValue = usernameLease~secretForTrustedConsumer
    if \usernameValue~ok then do
      ignore = usernameLease~retire
      return .JMSBridgeResult~failure("JMS_USERNAME_SECRET_UNAVAILABLE", usernameReference)
    end
    username = usernameValue~value
  end

  password = ""
  if passwordReference \= "" then do
    passwordLease = broker~acquire(passwordReference)
    if passwordLease == .nil then do
      if usernameLease \== .nil then ignore = usernameLease~retire
      return .JMSBridgeResult~failure("JMS_PASSWORD_SECRET_UNAVAILABLE", passwordReference)
    end
    if \passwordLease~hasMethod("OK") then do
      if usernameLease \== .nil then ignore = usernameLease~retire
      return .JMSBridgeResult~failure("JMS_PASSWORD_SECRET_UNAVAILABLE", passwordReference)
    end
    if \passwordLease~ok then do
      if usernameLease \== .nil then ignore = usernameLease~retire
      return .JMSBridgeResult~failure("JMS_PASSWORD_SECRET_UNAVAILABLE", passwordReference)
    end
    passwordValue = passwordLease~secretForTrustedConsumer
    if \passwordValue~ok then do
      if usernameLease \== .nil then ignore = usernameLease~retire
      ignore = passwordLease~retire
      return .JMSBridgeResult~failure("JMS_PASSWORD_SECRET_UNAVAILABLE", passwordReference)
    end
    password = passwordValue~value
  end

  credentialLease = .JMSBridgeCredentialLease~new(username, password)
  username = ""
  password = ""
  if usernameLease \== .nil then ignore = usernameLease~retire
  if passwordLease \== .nil then ignore = passwordLease~retire
  return .JMSBridgeResult~success(credentialLease, "SECRET_BROKER_CREDENTIALS_ACQUIRED")

::requires "JMSQueueBridge.cls"
::requires "SecretBroker.cls"
