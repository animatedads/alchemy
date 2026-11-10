/* ooRexx AI Provider - Anthropic v0.3 : multi-block Messages client.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Adds what v0.2's narrow AIProviderRequest (one text prompt) cannot carry:
 *   - a system prompt, optionally marked cache_control:ephemeral so a long
 *     static briefing is billed at the cache-read rate after the first call;
 *   - an ordered list of content blocks: text and image (PNG, base64);
 *   - full usage accounting: input, output, cache-write, cache-read tokens,
 *     wall-clock latency, and a rate-card cost estimate.
 * Credential discipline is unchanged from v0.2: the secret is acquired from
 * the Secret Broker by reference, written only into a mode-600 curl config,
 * the lease is retired as soon as curl returns, temp files are removed.
 */
::class AnthropicMessageRequest public
::attribute model
::attribute system
::attribute cacheSystem
::attribute blocks
::attribute maxTokens
::attribute temperature
::attribute thinking
::attribute effort
::method init
  expose model system cacheSystem blocks maxTokens temperature thinking effort
  use strict arg model, system = "", cacheSystem = .false, maxTokens = 512, temperature = .nil
  blocks = .array~new
  thinking = "DEFAULT"; effort = .nil
  if \datatype(maxTokens, "W") | maxTokens < 1 then raise syntax 88.900 array("positive maxTokens")
::method addText
  expose blocks
  use strict arg text
  b = .directory~new; b["type"] = "text"; b["text"] = text
  blocks~append(b)
  return self
::method addPngBase64
  expose blocks
  use strict arg base64
  if base64~length = 0 then raise syntax 88.900 array("non-empty base64 PNG")
  src = .directory~new
  src["type"] = "base64"; src["media_type"] = "image/png"; src["data"] = base64
  b = .directory~new; b["type"] = "image"; b["source"] = src
  blocks~append(b)
  return self
::method thinkingOff
  /* thinking:{type:disabled} -- answer directly (Haiku 5.5 thinks by default). */
  expose thinking effort
  thinking = "DISABLED"; effort = .nil
  return self
::method thinkingAdaptive
  /* thinking:{type:adaptive} + output_config.effort (LOW|MEDIUM|HIGH). */
  expose thinking effort
  use strict arg level = "LOW"
  if level~upper \= "LOW" & level~upper \= "MEDIUM" & level~upper \= "HIGH" then raise syntax 88.900 array("effort LOW, MEDIUM or HIGH")
  thinking = "ADAPTIVE"; effort = level~lower
  return self
::method toBody
  expose model system cacheSystem blocks maxTokens temperature thinking effort
  body = .directory~new
  body["model"] = model
  body["max_tokens"] = maxTokens
  if temperature \== .nil then body["temperature"] = temperature
  if thinking = "DISABLED" then do
    t = .directory~new; t["type"] = "disabled"; body["thinking"] = t
  end
  if thinking = "ADAPTIVE" then do
    t = .directory~new; t["type"] = "adaptive"; body["thinking"] = t
    oc = .directory~new; oc["effort"] = effort; body["output_config"] = oc
  end
  if system \== "" then do
    sb = .directory~new; sb["type"] = "text"; sb["text"] = system
    if cacheSystem then do
      cc = .directory~new; cc["type"] = "ephemeral"; sb["cache_control"] = cc
    end
    body["system"] = .array~of(sb)
  end
  msg = .directory~new; msg["role"] = "user"; msg["content"] = blocks
  body["messages"] = .array~of(msg)
  return body

::class AnthropicMessageReply public
::attribute ok get
::attribute code get
::attribute message get
::attribute text get
::attribute model get
::attribute stopReason get
::attribute inputTokens get
::attribute outputTokens get
::attribute cacheWriteTokens get
::attribute cacheReadTokens get
::attribute latencyMs get
::method init
  expose ok code message text model stopReason inputTokens outputTokens cacheWriteTokens cacheReadTokens latencyMs
  use strict arg ok, code, message, text, model, stopReason, inputTokens, outputTokens, cacheWriteTokens, cacheReadTokens, latencyMs
::method costUsd
  /* Rate card from the v0.3 catalog entry (micro-dollars per Mtok).
     Cache write = 1.25x input, cache read = 0.1x input (5-minute TTL). */
  expose model inputTokens outputTokens cacheWriteTokens cacheReadTokens
  use strict arg catalog
  numeric digits 16
  e = catalog~entry(model)
  if e == .nil then return ""
  inRate = e~inputMicroUsdPerMtok / 1000000; outRate = e~outputMicroUsdPerMtok / 1000000
  return (inputTokens * inRate + cacheWriteTokens * inRate * 1.25 + cacheReadTokens * inRate * 0.1 + outputTokens * outRate) / 1000000

::class AnthropicMessageClient public
::method init
  expose config
  use strict arg config
::method send
  expose config
  use strict arg request
  t0 = .dateTime~new
  secretOutcome = config~secretBroker~acquire(config~credentialReference)
  if \secretOutcome~ok then return self~failure("AI_ANTHROPIC_CREDENTIAL_MISSING", "credential could not be acquired", request, t0)
  lease = secretOutcome~value
  secretValue = lease~secretForTrustedConsumer
  if \secretValue~ok then do
    ignore = lease~retire
    return self~failure("AI_ANTHROPIC_CREDENTIAL_MISSING", "credential lease is unavailable", request, t0)
  end
  credential = secretValue~value
  workDir = "/tmp/anthropic_msg_" || self~identityHash || "_" || .dateTime~new~microseconds
  call sysMkDir workDir
  bodyFile = workDir || "/body.json"; cfgFile = workDir || "/curl.cfg"
  outFile = workDir || "/out.json"; errFile = workDir || "/err.txt"
  call charout bodyFile, .JSON~toJSON(request~toBody)
  call stream bodyFile, "c", "close"
  cfg = 'header = "x-api-key: ' || credential || '"' || "0a"x || -
        'header = "anthropic-version: ' || .AnthropicProviderBuild~ANTHROPIC_API_VERSION_HEADER || '"' || "0a"x || -
        'header = "content-type: application/json"' || "0a"x || -
        'data-binary = @' || bodyFile || "0a"x || 'silent' || "0a"x || 'show-error' || "0a"x || -
        'max-time = ' || config~timeoutSeconds || "0a"x || -
        'url = "https://' || config~channel~baseHost || .AnthropicProviderBuild~PATH_MESSAGES || '"' || "0a"x
  call charout cfgFile, cfg
  call stream cfgFile, "c", "close"
  address system 'chmod 600 "' || cfgFile || '"'
  address system config~curlPath || ' --config "' || cfgFile || '" > "' || outFile || '" 2> "' || errFile || '"'
  curlRc = rc
  ignore = lease~retire
  credential = ""
  outText = self~slurp(outFile)
  call SysFileDelete cfgFile; call SysFileDelete bodyFile; call SysFileDelete outFile; call SysFileDelete errFile
  call SysRmDir workDir
  if curlRc \= 0 then return self~failure("AI_ANTHROPIC_TRANSPORT", "transport failed, exit" curlRc, request, t0)
  signal on syntax name badJson
  parsed = .JSON~fromJSON(outText)
  signal off syntax
  if parsed == .nil | \parsed~isa(.Directory) then return self~failure("AI_ANTHROPIC_BAD_REPLY", "unparseable response body", request, t0)
  err = parsed~at("error")
  if err \== .nil then do
    etype = "AI_ANTHROPIC_API_ERROR"; emsg = "provider returned an error"
    if err~isa(.Directory) then do
      if err~at("type") \== .nil then etype = "AI_ANTHROPIC_" || err~at("type")~string~upper
      if err~at("message") \== .nil then emsg = self~sanitise(err~at("message")~string)
    end
    return self~failure(etype, emsg, request, t0)
  end
  text = ""
  content = parsed~at("content")
  if content \== .nil, content~isa(.Array) then do
    do blk over content
      if blk~isa(.Directory) then if blk~at("type") = "text" then text = text || blk~at("text")
    end
  end
  u = parsed~at("usage"); inT = 0; outT = 0; cw = 0; cr = 0
  if u \== .nil, u~isa(.Directory) then do
    if u~at("input_tokens") \== .nil then inT = u~at("input_tokens")
    if u~at("output_tokens") \== .nil then outT = u~at("output_tokens")
    if u~at("cache_creation_input_tokens") \== .nil then cw = u~at("cache_creation_input_tokens")
    if u~at("cache_read_input_tokens") \== .nil then cr = u~at("cache_read_input_tokens")
  end
  model = parsed~at("model"); if model == .nil then model = request~model
  stop = parsed~at("stop_reason"); if stop == .nil then stop = "unknown"
  return .AnthropicMessageReply~new(.true, "OK", "", text, model, stop, inT, outT, cw, cr, self~elapsed(t0))
badJson:
  signal off syntax
  return self~failure("AI_ANTHROPIC_BAD_REPLY", "response body did not parse as JSON", request, t0)
::method failure private
  use strict arg code, message, request, t0
  return .AnthropicMessageReply~new(.false, code, message, "", request~model, "error", 0, 0, 0, 0, self~elapsed(t0))
::method elapsed private
  use strict arg t0
  return trunc((.dateTime~new - t0)~microseconds / 1000)
::method sanitise private
  use strict arg text
  /* Never echo anything shaped like a credential back to a caller. */
  p = text~pos("sk-ant-")
  do while p > 0
    e = verify(text, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_", "N", p)
    if e = 0 then e = text~length + 1
    text = text~left(p - 1) || "<redacted>" || text~substr(e)
    p = text~pos("sk-ant-")
  end
  return text~left(min(300, text~length))
::method slurp private
  use strict arg path
  if \SysFileExists(path) then return ""
  s = charin(path, 1, chars(path))
  call stream path, "c", "close"
  return s

::requires "AnthropicTransport.cls"
