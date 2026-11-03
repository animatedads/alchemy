/* ooRexx AI Provider - Anthropic v0.2 : transport
 *
 * Real-time (/v1/messages) and batch (/v1/messages/batches...) transport
 * for the DIRECT channel only, following the same discipline as the
 * sibling Grok/OpenAI-compatible providers:
 *   - credential resolved by opaque reference, never a literal in code;
 *   - Authorization/x-api-key written into a mode-600 temporary curl
 *     config file, never onto the command line;
 *   - temp files removed after each request;
 *   - raw provider error bodies are sanitised before they reach the
 *     caller or any instrumentation.
 *
 * v0.2 uses oorexx_secret_broker_v0.2 for both real-time and Batch
 * credential acquisition.  Secret values are materialized only inside the
 * trusted transport boundary and the lease is retired immediately after the
 * curl invocation.
 */

/* Compatibility adapter retained for callers that still construct a config
 * with an environment-variable credential source.  Provider execution no
 * longer calls resolve() directly; the adapter produces a Secret Broker. */
::class AnthropicCredentialSource public
::method brokerFor public
  use arg envVarName, reference = "provider.anthropic.primary"
  mapping = .directory~new
  mapping[reference] = envVarName
  return .SecretBroker~new(.MappedEnvironmentSecretProvider~new(mapping))
::method resolve public
  use arg envVarName
  v = value(envVarName,, "ENVIRONMENT")
  if v = "" then raise syntax 88.900 array("Anthropic credential" envVarName "is not set")
  return v


::class AnthropicRuntimeConfig public
::attribute channel get
::attribute secretBroker get
::attribute credentialReference get
::attribute credentialSource get
::attribute credentialEnvVar get
::attribute model get
::attribute maxOutputTokens get
::attribute timeoutSeconds get
::attribute curlPath get

::method init
  expose channel secretBroker credentialReference credentialSource credentialEnvVar model maxOutputTokens timeoutSeconds curlPath
  use arg channelArg, brokerOrSourceArg, credentialReferenceArg = "provider.anthropic.primary", modelArg = "claude-haiku-4-5-20251001", maxOutputArg = 1024, timeoutArg = 60, curlArg = "curl"
  channel = channelArg
  credentialSource = .nil
  credentialEnvVar = ""
  if brokerOrSourceArg \== .nil, brokerOrSourceArg~hasMethod("ACQUIRE") then do
    secretBroker = brokerOrSourceArg
    credentialReference = credentialReferenceArg~string
  end
  else do
    if brokerOrSourceArg == .nil then credentialSource = .AnthropicCredentialSource~new
    else credentialSource = brokerOrSourceArg
    credentialEnvVar = credentialReferenceArg~string
    credentialReference = "provider.anthropic.compat"
    if \credentialSource~hasMethod("BROKERFOR") then raise syntax 88.900 array("Anthropic credential source must implement brokerFor(envVar, reference)")
    secretBroker = credentialSource~brokerFor(credentialEnvVar, credentialReference)
  end
  model = modelArg
  maxOutputTokens = maxOutputArg
  timeoutSeconds = timeoutArg
  curlPath = curlArg

::method fromEnvironment class
  channel = .AnthropicChannel~direct
  reference = value("AI_ANTHROPIC_CREDENTIAL_REFERENCE",, "ENVIRONMENT")
  if reference = "" then reference = "provider.anthropic.primary"
  envVar = value("AI_ANTHROPIC_CREDENTIAL_ENV",, "ENVIRONMENT")
  if envVar = "" then envVar = "ANTHROPIC_API_KEY"
  mapping = .directory~new
  mapping[reference] = envVar
  broker = .SecretBroker~new(.MappedEnvironmentSecretProvider~new(mapping))
  model = value("AI_ANTHROPIC_MODEL",, "ENVIRONMENT")
  if model = "" then model = "claude-haiku-4-5-20251001"
  maxOut = value("AI_ANTHROPIC_MAX_OUTPUT",, "ENVIRONMENT")
  if maxOut = "" then maxOut = 1024
  timeout = value("AI_ANTHROPIC_TIMEOUT",, "ENVIRONMENT")
  if timeout = "" then timeout = 60
  curl = value("AI_ANTHROPIC_CURL",, "ENVIRONMENT")
  if curl = "" then curl = "curl"
  return self~new(channel, broker, reference, model, maxOut, timeout, curl)


/* Real-time provider: subclasses the AI Access adapter base so it plugs
 * straight into oorexx_ai_access_v0.6's narrow-request boundary. */
::class AnthropicProvider subclass AIProviderAdapterBase public

::method init
  expose config
  use arg configArg = .nil
  if configArg == .nil then config = .AnthropicRuntimeConfig~fromEnvironment
  else config = configArg
  self~init:super
  self~registerStateVariable("config", "INTERNAL", "Anthropic direct-channel runtime configuration containing only secret reference/broker authority, never persisted secret material")
  self~registerExternalRequirement("library", "oorexx_ai_access", "v" || .AnthropicProviderBuild~AI_ACCESS_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_secret_broker", "v" || .AnthropicProviderBuild~SECRET_BROKER_VERSION, .true)
  self~recordRelationship("SECRET_BROKER", config~secretBroker, "credential acquisition authority", "SECRET")

::method completeRequest protected
  expose config
  use arg request

  secretOutcome = config~secretBroker~acquire(config~credentialReference)
  if \secretOutcome~ok then
    return .AIProviderReply~failure("AI_ANTHROPIC_CREDENTIAL_MISSING", "credential could not be acquired", .AIProviderUsage~new(0, 0), request~model)
  lease = secretOutcome~value
  secretValue = lease~secretForTrustedConsumer
  if \secretValue~ok then do
    ignore = lease~retire
    return .AIProviderReply~failure("AI_ANTHROPIC_CREDENTIAL_MISSING", "credential lease is unavailable", .AIProviderUsage~new(0, 0), request~model)
  end
  credential = secretValue~value

  bodyDir = .directory~new
  bodyDir["model"] = request~model
  bodyDir["max_tokens"] = request~maxOutputTokens
  msg = .directory~new
  msg["role"] = "user"
  msg["content"] = request~prompt
  bodyDir["messages"] = .array~of(msg)
  bodyJson = .JSON~toJSON(bodyDir)

  workDir = "/tmp/anthropic_req_" || self~identityHash || "_" || .dateTime~new~microseconds
  call sysMkDir workDir
  bodyFile = workDir || "/body.json"
  cfgFile = workDir || "/curl.cfg"
  outFile = workDir || "/out.json"
  errFile = workDir || "/err.txt"

  call charout bodyFile, bodyJson
  call charout bodyFile
  call stream bodyFile, "c", "close"

  cfgLines = ""
  cfgLines = cfgLines || 'header = "x-api-key: ' || credential || '"' || "0a"x
  cfgLines = cfgLines || 'header = "anthropic-version: ' || .AnthropicProviderBuild~ANTHROPIC_API_VERSION_HEADER || '"' || "0a"x
  cfgLines = cfgLines || 'header = "content-type: application/json"' || "0a"x
  cfgLines = cfgLines || 'data-binary = @' || bodyFile || "0a"x
  cfgLines = cfgLines || 'silent' || "0a"x
  cfgLines = cfgLines || 'show-error' || "0a"x
  cfgLines = cfgLines || 'max-time = ' || config~timeoutSeconds || "0a"x
  cfgLines = cfgLines || 'url = "https://' || config~channel~baseHost || .AnthropicProviderBuild~PATH_MESSAGES || '"' || "0a"x

  call charout cfgFile, cfgLines
  call charout cfgFile
  call stream cfgFile, "c", "close"
  address system 'chmod 600 "' || cfgFile || '"'

  cmd = config~curlPath || ' --config "' || cfgFile || '" > "' || outFile || '" 2> "' || errFile || '"'
  rc = self~runShell(cmd)
  ignore = lease~retire
  credential = ""

  outText = self~readWholeFile(outFile)
  errText = self~readWholeFile(errFile)

  call sysRmDir workDir  -- best effort; see cleanupWorkDir for the real removal
  self~cleanupWorkDir(workDir)

  if rc \= 0 then
    return .AIProviderReply~failure("AI_ANTHROPIC_TRANSPORT", "transport failed, exit" rc, .AIProviderUsage~new(0, 0), request~model)

  signal on syntax name parseFailed
  parsed = .JSON~fromJSON(outText)
  signal off syntax

  if parsed == .nil | \parsed~isa(.Directory) then
    return .AIProviderReply~failure("AI_ANTHROPIC_BAD_REPLY", "unparseable response body", .AIProviderUsage~new(0, 0), request~model)

  errObj = parsed~at("error")
  if errObj \== .nil then do
    etype = "AI_ANTHROPIC_API_ERROR"
    if errObj~isa(.Directory) then do
      t = errObj~at("type")
      if t \== .nil then etype = "AI_ANTHROPIC_" || t~string~upper
    end
    return .AIProviderReply~failure(etype, "provider returned an error", .AIProviderUsage~new(0, 0), request~model)
  end

  contentArr = parsed~at("content")
  text = ""
  if contentArr \== .nil, contentArr~isa(.Array) then do
    do blk over contentArr
      if blk~isa(.Directory) then do
        t = blk~at("type")
        if t = "text" then do
          tv = blk~at("text")
          if tv \== .nil then text = text || tv
        end
      end
    end
  end

  usageDir = parsed~at("usage")
  inTok = 0; outTok = 0
  if usageDir \== .nil, usageDir~isa(.Directory) then do
    iv = usageDir~at("input_tokens"); if iv \== .nil then inTok = iv
    ov = usageDir~at("output_tokens"); if ov \== .nil then outTok = ov
  end
  usage = .AIProviderUsage~new(inTok, outTok)

  modelOut = parsed~at("model")
  if modelOut == .nil then modelOut = request~model
  stopReason = parsed~at("stop_reason")
  if stopReason == .nil then stopReason = "stop"

  return .AIProviderReply~success(text, modelOut, stopReason, usage)

parseFailed:
  signal off syntax
  return .AIProviderReply~failure("AI_ANTHROPIC_BAD_REPLY", "response body did not parse as JSON", .AIProviderUsage~new(0, 0), request~model)


::method runShell private
  use arg cmd
  address system cmd
  return rc

::method readWholeFile private
  use arg path
  if \sysFileExists(path) then return ""
  text = charin(path, 1, chars(path))
  call stream path, "c", "close"
  return text

::method cleanupWorkDir private
  use arg workDir
  do f over .array~of("body.json", "curl.cfg", "out.json", "err.txt")
    p = workDir || "/" || f
    if sysFileExists(p) then call sysFileDelete p
  end
  call sysRmDir workDir


/* ---------------------------------------------------------------------
 * Batch provider: real /v1/messages/batches CRUD, distinct WLU/cost
 * treatment matching the Grok batch pattern -- create is cheap, the
 * expensive part happens later and is priced/settled separately.
 * --------------------------------------------------------------------- */
::class AnthropicBatchRequestItem public
::attribute customId get
::attribute model get
::attribute prompt get
::attribute maxOutputTokens get

::method init
  expose customId model prompt maxOutputTokens
  use arg customIdArg, modelArg, promptArg, maxOutputArg = 1024
  customId = customIdArg~string
  model = modelArg~string
  prompt = promptArg~string
  maxOutputTokens = maxOutputArg

::method toParamsDirectory
  expose customId model prompt maxOutputTokens
  item = .directory~new
  item["custom_id"] = customId
  params = .directory~new
  params["model"] = model
  params["max_tokens"] = maxOutputTokens
  msg = .directory~new
  msg["role"] = "user"
  msg["content"] = prompt
  params["messages"] = .array~of(msg)
  item["params"] = params
  return item


::class AnthropicBatchProvider subclass AlchemyObject public

::method init
  expose config selector
  use arg configArg = .nil, selectorArg = .nil
  if configArg == .nil then config = .AnthropicRuntimeConfig~fromEnvironment
  else config = configArg
  if selectorArg == .nil then selector = .AnthropicCapabilitySelector~new
  else selector = selectorArg
  meta = .directory~new
  meta["purpose"] = "Anthropic direct Batch API adapter with Secret Broker credential leasing and explicit cost-estimate settlement boundary"
  meta["package_version"] = .AnthropicProviderBuild~RELEASE
  meta["api_version"] = .AnthropicProviderBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; Anthropic Messages Batch API; secret.broker/0.2"
  meta["design_limitations"] = "Implements the Anthropic direct channel only; Bedrock and Vertex signing/transport remain separate authority boundaries"
  self~init:super(meta)
  self~registerStateVariable("config", "INTERNAL", "non-secret direct-channel runtime configuration")
  self~registerStateVariable("selector", "INTERNAL", "capability/cost selector")
  self~registerExternalRequirement("library", "oorexx_secret_broker", "v" || .AnthropicProviderBuild~SECRET_BROKER_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_ai_access", "v" || .AnthropicProviderBuild~AI_ACCESS_VERSION, .true)
  self~registerMethodContract("CREATEBATCH", "submit an Anthropic Messages Batch request", .array~of("ITEMS"), "ANTHROPICBATCHRESULT", .false, "AUTO", "SECRET", "NORMAL", "EXTERNAL", "USE")
  self~registerMethodContract("GETBATCH", "read Anthropic Batch status", .array~of("BATCHID"), "ANTHROPICBATCHRESULT", .false, "AUTO", "SECRET", "NORMAL", "EXTERNAL", "USE")

::method selector public
  expose selector
  return selector

/* createBatch: real POST /v1/messages/batches. Records an estimated cost
 * against the returned batch id immediately, via the capability selector's
 * job ledger, so queryJobCost works even before the batch settles. */
::method createBatch public
  expose config selector
  use arg items
  if \items~isa(.Array) then raise syntax 88.900 array("Anthropic batch: items must be an Array")
  if items~items = 0 then raise syntax 88.900 array("Anthropic batch: items must not be empty")

  requestsArr = .array~new
  estInTotal = 0; estOutTotal = 0; modelForCost = items[1]~model
  do it over items
    requestsArr~append(it~toParamsDirectory)
    estInTotal = estInTotal + max(1, it~prompt~length % 4)
    estOutTotal = estOutTotal + it~maxOutputTokens
  end
  bodyDir = .directory~new
  bodyDir["requests"] = requestsArr
  bodyJson = .JSON~toJSON(bodyDir)

  curlOutcome = self~invokeCurl("POST", .AnthropicProviderBuild~PATH_BATCHES, bodyJson)
  if \curlOutcome~ok then return curlOutcome

  parsed = .JSON~fromJSON(curlOutcome~body)
  batchId = parsed~at("id")
  estCost = selector~estimateCost(modelForCost, estInTotal, estOutTotal, .true)
  selector~recordJobCost(batchId, modelForCost, estCost, .nil, "SUBMITTED")
  return .AnthropicBatchResult~success(parsed)

::method getBatch public
  expose config
  use arg batchId
  curlOutcome = self~invokeCurl("GET", .AnthropicProviderBuild~PATH_BATCHES || "/" || batchId, "")
  if \curlOutcome~ok then return curlOutcome
  return .AnthropicBatchResult~success(.JSON~fromJSON(curlOutcome~body))

::method listResults public
  expose config
  use arg batchId
  curlOutcome = self~invokeCurl("GET", .AnthropicProviderBuild~PATH_BATCHES || "/" || batchId || "/results", "")
  return curlOutcome

::method cancelBatch public
  expose config
  use arg batchId
  return self~invokeCurl("POST", .AnthropicProviderBuild~PATH_BATCHES || "/" || batchId || "/cancel", "")

::method settleJobCost public
  -- Call once a batch has actually completed and its real usage is known,
  -- so queryJobCost reflects billed reality rather than the estimate.
  expose selector
  use arg batchId, modelId, actualInputTokens, actualOutputTokens
  actual = selector~estimateCost(modelId, actualInputTokens, actualOutputTokens, .true)
  selector~recordJobCost(batchId, modelId, .nil, actual, "SETTLED")
  return actual

::method invokeCurl private
  expose config
  use arg verb, path, bodyJson

  secretOutcome = config~secretBroker~acquire(config~credentialReference)
  if \secretOutcome~ok then return .AnthropicBatchResult~failure("AI_ANTHROPIC_CREDENTIAL_MISSING", "credential could not be acquired")
  lease = secretOutcome~value
  secretValue = lease~secretForTrustedConsumer
  if \secretValue~ok then do
    ignore = lease~retire
    return .AnthropicBatchResult~failure("AI_ANTHROPIC_CREDENTIAL_MISSING", "credential lease is unavailable")
  end
  credential = secretValue~value
  workDir = "/tmp/anthropic_batch_" || .dateTime~new~microseconds
  call sysMkDir workDir
  cfgFile = workDir || "/curl.cfg"
  bodyFile = workDir || "/body.json"
  outFile = workDir || "/out.json"

  cfgLines = ""
  cfgLines = cfgLines || 'header = "x-api-key: ' || credential || '"' || "0a"x
  cfgLines = cfgLines || 'header = "anthropic-version: ' || .AnthropicProviderBuild~ANTHROPIC_API_VERSION_HEADER || '"' || "0a"x
  cfgLines = cfgLines || 'header = "content-type: application/json"' || "0a"x
  if bodyJson \= "" then do
    call charout bodyFile, bodyJson
    call charout bodyFile
    call stream bodyFile, "c", "close"
    cfgLines = cfgLines || 'data-binary = @' || bodyFile || "0a"x
  end
  if verb \= "GET" then cfgLines = cfgLines || 'request = ' || verb || "0a"x
  cfgLines = cfgLines || 'silent' || "0a"x
  cfgLines = cfgLines || 'show-error' || "0a"x
  cfgLines = cfgLines || 'max-time = ' || config~timeoutSeconds || "0a"x
  cfgLines = cfgLines || 'url = "https://' || config~channel~baseHost || path || '"' || "0a"x

  call charout cfgFile, cfgLines
  call charout cfgFile
  call stream cfgFile, "c", "close"
  address system 'chmod 600 "' || cfgFile || '"'

  cmd = config~curlPath || ' --config "' || cfgFile || '" > "' || outFile || '" 2>&1'
  address system cmd
  exitRc = rc
  ignore = lease~retire
  credential = ""

  outText = ""
  if sysFileExists(outFile) then do
    outText = charin(outFile, 1, chars(outFile))
    call stream outFile, "c", "close"
  end

  do f over .array~of("curl.cfg", "body.json", "out.json")
    p = workDir || "/" || f
    if sysFileExists(p) then call sysFileDelete p
  end
  call sysRmDir workDir

  if exitRc \= 0 then return .AnthropicBatchResult~failure("AI_ANTHROPIC_TRANSPORT", "batch transport failed, exit" exitRc)

  /* curl without --fail exits 0 even on HTTP 4xx/5xx, so an API-level error
   * body must be detected here rather than trusted as success. */
  signal on syntax name batchParseFailed
  parsedCheck = .JSON~fromJSON(outText)
  signal off syntax
  if parsedCheck~isa(.Directory) then do
    errObj = parsedCheck~at("error")
    if errObj \== .nil then do
      etype = "AI_ANTHROPIC_API_ERROR"
      if errObj~isa(.Directory) then do
        t = errObj~at("type")
        if t \== .nil then etype = "AI_ANTHROPIC_" || t~string~upper
      end
      return .AnthropicBatchResult~failure(etype, "provider returned an error")
    end
  end
  return .AnthropicBatchResult~successRaw(outText)

batchParseFailed:
  signal off syntax
  return .AnthropicBatchResult~successRaw(outText)


::class AnthropicBatchResult public
::attribute ok get
::attribute code get
::attribute body get
::attribute detail get

::method init
  expose ok code body detail
  use arg okArg, codeArg = "OK", bodyArg = "", detailArg = ""
  ok = okArg == .true
  code = codeArg~string
  body = bodyArg~string
  detail = detailArg~string

::method success class
  use arg parsedDirectory
  return self~new(.true, "OK", .JSON~toJSON(parsedDirectory), "")

::method successRaw class
  use arg rawBody
  return self~new(.true, "OK", rawBody, "")

::method failure class
  use arg code, detail
  return self~new(.false, code, "", detail)

::requires "rxunixsys" LIBRARY
::requires "AnthropicProvider.cls"
::requires "AIProviderAccess.cls"
::requires "SecretBroker.cls"
