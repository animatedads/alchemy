/* Architecture Tom Dyer; implementation ChatGPT GPT-6.2.
   Trusted transport only. SecretBroker lease, stdin header configuration,
   fixed HTTPS destinations, no retries, no provider conversation state.
   No shell interpolation of player data or credentials. */
::class DiplomacyCurlTransport public
::method init
  expose broker reference
  use strict arg broker, reference
  if reference == '' then raise syntax 93.900 array('Secret reference required')
::method post
  expose broker reference
  use strict arg provider, body, timeout
  if provider == 'HAIKU' then endpoint = 'https://api.anthropic.com/v1/messages'
  else if provider == 'SOL' then endpoint = 'https://api.openai.com/v1/responses'
  else return .array~of('ERROR',0,'')
  if timeout == '' | timeout~verify('0123456789') \= 0 then return .array~of('ERROR',0,'')
  if timeout < 1 | timeout~length > 9 then return .array~of('ERROR',0,'')
  lease = .nil
  scratch = ''
  signal on syntax name failed
  lease = broker~acquire(reference)
  if \lease~ok then return .array~of('ERROR',0,'')
  secret = lease~secretForTrustedConsumer
  if \secret~ok then do
    self~cleanup(lease,scratch)
    return .array~of('ERROR',0,'')
  end
  key = secret~value
  -- The credential must be a single token safe inside curl config quotes.
  if key == '' | key~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-') \= 0 then do
    self~cleanup(lease,scratch)
    return .array~of('ERROR',0,'')
  end
  dirs = .array~new
  address system 'mktemp -d /tmp/diplomacy-call.XXXXXXXXXX' with output using (dirs)
  if rc \= 0 | dirs~items \= 1 then do
    self~cleanup(lease,scratch)
    return .array~of('ERROR',0,'')
  end
  candidate = dirs[1]
  if candidate~left(20) \== '/tmp/diplomacy-call.' | candidate~substr(21)~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789') \= 0 then do
    self~cleanup(lease,scratch)
    return .array~of('ERROR',0,'')
  end
  scratch = candidate
  out = .stream~new(scratch'/request')
  if out~open('WRITE REPLACE') \== 'READY:' then signal failed
  if out~charout(body) \= 0 then signal failed
  out~close
  cfg = .array~of('header = "Content-Type: application/json"')
  if provider == 'HAIKU' then do
    cfg~append('header = "x-api-key: '||key||'"')
    cfg~append('header = "anthropic-version: 2023-06-01"')
  end
  else cfg~append('header = "Authorization: Bearer '||key||'"')
  key = ''
  secret = .nil
  http = .array~new
  command = 'timeout --kill-after=2' timeout 'curl -q --silent --proto =https --max-time' timeout '--config - --request POST --data-binary @' || scratch || '/request --output ' || scratch || '/response --write-out "%{http_code}\n" ' || endpoint
  address system command with input using (cfg) output using (http)
  curlCode = rc
  cfg~empty
  lease~retire
  status = 'ERROR'
  httpCode = 0
  raw = ''
  if curlCode = 28 | curlCode = 124 | curlCode = 137 then status = 'TIMEOUT'
  else if curlCode = 0 & http~items = 1 then do
    httpCode = http[1]
    incoming = .stream~new(scratch'/response')
    if incoming~open('READ') == 'READY:' then do
      raw = incoming~charin(1,incoming~chars)
      incoming~close
      status = 'OK'
    end
  end
  self~cleanup(lease,scratch)
  return .array~of(status,httpCode,raw)
failed:
  self~cleanup(lease,scratch)
  return .array~of('ERROR',0,'')
::method cleanup private
  use strict arg lease, scratch
  if lease \== .nil then if lease~active then lease~retire
  if scratch \== '' then address system 'rm -rf --' scratch
::method module_version class
  return '0.1-dev7'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged
