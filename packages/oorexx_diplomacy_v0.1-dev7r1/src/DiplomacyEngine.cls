/* Architecture Tom Dyer; implementation ChatGPT GPT-6.2.
   Provider codecs for pinned, single-turn, text-only runtime calls.
   Transport is injected. A fresh request is constructed for every call. */
::requires 'json.cls'

::class DiplomacyEngineProfile public
::attribute provider get
::attribute model get
::attribute effort get
::attribute maxOutput get
::attribute timeout get
::method init
  expose provider model effort maxOutput timeout
  use strict arg provider, model, effort, maxOutput, timeout
  if wordpos(provider,'HAIKU SOL STUB') = 0 then raise syntax 93.900 array('Unsupported runtime provider')
  if model == '' | model~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-') \= 0 then raise syntax 93.900 array('Invalid exact model ID')
  if model~upper == 'UNPINNED' | model~lower~right(7) == '-latest' then raise syntax 93.900 array('Unpinned runtime model')
  if provider == 'HAIKU' & model~left(16) \== 'claude-haiku-5-5' then raise syntax 93.900 array('Unsupported Haiku family')
  if provider == 'SOL' & model~left(11) \== 'gpt-6.2-sol' then raise syntax 93.900 array('Unsupported Sol family')
  if wordpos(effort,'low medium high') = 0 then raise syntax 93.900 array('Unsupported runtime effort')
  if \engineInteger(maxOutput) | maxOutput = 0 then raise syntax 93.900 array('Positive output budget required')
  if \engineInteger(timeout) | timeout = 0 then raise syntax 93.900 array('Positive timeout required')
::method load class
  use strict arg path
  input = .stream~new(path)
  if input~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot open runtime profile')
  fields = .directory~new
  do while input~lines > 0
    line = input~linein
    if line == '' then iterate
    if line~left(1) == '#' then iterate
    parse var line key '=' value
    if wordpos(key,'PROVIDER MODEL EFFORT MAX_OUTPUT TIMEOUT') = 0 then raise syntax 93.900 array('Unsupported runtime setting:' key)
    if fields~hasIndex(key) then raise syntax 93.900 array('Duplicate runtime setting:' key)
    fields[key] = value
  end
  input~close
  if fields~items \= 5 then raise syntax 93.900 array('Incomplete runtime profile')
  return self~new(fields['PROVIDER'],fields['MODEL'],fields['EFFORT'],fields['MAX_OUTPUT'],fields['TIMEOUT'])
::method identity
  expose provider model effort maxOutput timeout
  return provider'|'model'|'effort'|'maxOutput'|'timeout
::method module_version class
  return '0.1-dev7'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::class DiplomacyEngine public
::attribute profile get
::method init
  expose profile transport
  use strict arg profile, transport
  if \profile~isA(.DiplomacyEngineProfile) then raise syntax 93.900 array('Explicit runtime profile required')
::method request
  expose profile
  use strict arg system, input
  model = diplomacyJsonQuote(profile~model)
  effort = diplomacyJsonQuote(profile~effort)
  sys = diplomacyJsonQuote(system)
  usr = diplomacyJsonQuote(input)
  if profile~provider == 'HAIKU' then return '{"model":'||model||',"max_tokens":'||profile~maxOutput||',"thinking":{"type":"adaptive"},"output_config":{"effort":'||effort||'},"system":'||sys||',"messages":[{"role":"user","content":'||usr||'}]}'
  if profile~provider == 'SOL' then return '{"model":'||model||',"max_output_tokens":'||profile~maxOutput||',"reasoning":{"effort":'||effort||'},"store":false,"instructions":'||sys||',"input":[{"role":"user","content":'||usr||'}]}'
  return '{"model":'||model||',"effort":'||effort||',"max_output_tokens":'||profile~maxOutput||',"system":'||sys||',"input":'||usr||'}'
::method invoke
  expose profile transport
  use strict arg system, input
  reply = transport~post(profile~provider,self~request(system,input),profile~timeout)
  if \reply~isA(.array) then return engineReply('BAD_RESPONSE','','-','-')
  if reply~items \= 3 then return engineReply('BAD_RESPONSE','','-','-')
  if reply[1] == 'TIMEOUT' then return engineReply('TIMEOUT','','-','-')
  if reply[1] \== 'OK' | reply[2] \== 200 then return engineReply('ERROR','','-','-')
  return self~decode(reply[3])
::method decode
  expose profile
  use strict arg raw
  signal on syntax name malformed
  doc = .JSON~fromJSON(diplomacyJsonUtf8(raw))
  if \doc~isA(.directory) then return engineReply('BAD_RESPONSE','','-','-')
  partial = self~visibleFrom(doc)
  if \doc~hasIndex('model') | \doc~hasIndex('usage') then return engineReply('BAD_RESPONSE',partial,'-','-')
  if doc['model'] \== profile~model then return engineReply('BAD_RESPONSE',partial,'-','-')
  usage = doc['usage']
  if \usage~isA(.directory) then return engineReply('BAD_RESPONSE',partial,'-','-')
  if \usage~hasIndex('input_tokens') | \usage~hasIndex('output_tokens') then return engineReply('BAD_RESPONSE',partial,'-','-')
  nIn = usage['input_tokens']
  nOut = usage['output_tokens']
  if \engineInteger(nIn) | \engineInteger(nOut) then return engineReply('BAD_RESPONSE',partial,'-','-')
  if profile~provider == 'HAIKU' then do
    if doc['stop_reason'] \== 'end_turn' then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
    do key over .array~of('cache_creation_input_tokens','cache_read_input_tokens')
      if usage~hasIndex(key) then do
        if \engineInteger(usage[key]) then return engineReply('BAD_RESPONSE',partial,'-','-')
        nIn += usage[key]
      end
    end
    items = doc['content']
  end
  else if profile~provider == 'SOL' then do
    if doc['status'] \== 'completed' then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
    if \doc['output']~isA(.array) then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
    items = .array~new
    do item over doc['output']
      if \item~isA(.directory) then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
      if item['type'] == 'reasoning' then iterate
      if item['type'] \== 'message' | item['role'] \== 'assistant' | item['status'] \== 'completed' then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
      if \item['content']~isA(.array) then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
      do part over item['content']
        items~append(part)
      end
    end
  end
  else do
    if doc['status'] \== 'completed' then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
    items = doc['content']
  end
  if \items~isA(.array) then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
  visible = .array~new
  do item over items
    if \item~isA(.directory) then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
    if profile~provider == 'HAIKU' & wordpos(item['type'],'thinking redacted_thinking') > 0 then iterate
    expected = 'text'
    if profile~provider == 'SOL' then expected = 'output_text'
    if item['type'] \== expected then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
    if \item['text']~isA(.JsonString) then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
    visible~append(item['text']~string)
  end
  if visible~items = 0 then return engineReply('BAD_RESPONSE',partial,nIn,nOut)
  return engineReply('OK',visible~makeString('l','0A'x),nIn,nOut)
malformed:
  return engineReply('BAD_RESPONSE','','-','-')
::method visibleFrom private
  -- Capture visible text even when validation later rejects the envelope.
  expose profile
  use strict arg doc
  pieces = .array~new
  signal on syntax name partialFault
  if profile~provider == 'SOL' then do
    if \doc['output']~isA(.array) then return ''
    do item over doc['output']
      if \item~isA(.directory) then iterate
      if item['type'] \== 'message' | item['role'] \== 'assistant' then iterate
      if \item['content']~isA(.array) then iterate
      do part over item['content']
        if \part~isA(.directory) then iterate
        if part['type'] == 'output_text' & part['text']~isA(.JsonString) then pieces~append(part['text']~string)
        if part['type'] == 'refusal' & part['refusal']~isA(.JsonString) then pieces~append(part['refusal']~string)
      end
    end
  end
  else do
    if \doc['content']~isA(.array) then return ''
    do part over doc['content']
      if \part~isA(.directory) then iterate
      if part['type'] == 'text' & part['text']~isA(.JsonString) then pieces~append(part['text']~string)
    end
  end
partialFault:
  return pieces~makeString('L','0A'x)
::method module_version class
  return '0.1-dev7'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine engineInteger
  use strict arg value
  if \value~isA(.string) then return .false
  if value~isA(.JsonString) then return .false
  if value == '' | value~length > 9 then return .false
  if value~length > 1 & value~left(1) == '0' then return .false
  return value~verify('0123456789') = 0

::routine engineReply
  use strict arg status, visible, nIn, nOut
  reply = .directory~new
  reply['STATUS'] = status
  reply['TEXT'] = visible
  reply['INPUT_TOKENS'] = nIn
  reply['OUTPUT_TOKENS'] = nOut
  return reply

::routine diplomacyJsonQuote public
  use strict arg value
  buffer = .MutableBuffer~new('"')
  do idx = 1 to value~length
    byte = value~substr(idx,1)
    select
      when byte == '"' then buffer~append('\"')
      when byte == '\' then buffer~append('\\')
      when byte~c2d < 32 then buffer~append('\u00'||byte~c2x)
      otherwise buffer~append(byte)
    end
  end
  buffer~append('"')
  return buffer~string

::routine diplomacyJsonUtf8 public
  -- The native JSON decoder retains non-ASCII unicode escapes. Convert
  -- genuine escaped code points only, leaving escaped backslashes literal.
  use strict arg raw
  buffer = .MutableBuffer~new
  quoted = .false
  idx = 1
  do while idx <= raw~length
    byte = raw~substr(idx,1)
    if byte == '"' then quoted = \quoted
    if quoted & byte == '\' then do
      seq = raw~substr(idx,6)
      if seq~left(2) == '\u' & seq~substr(3)~datatype('X') then do
        cp = seq~substr(3)~x2d
        if cp >= 128 then do
          if cp >= 55296 & cp <= 56319 then do
            following = raw~substr(idx+6,6)
            if following~left(2) \== '\u' | \following~substr(3)~datatype('X') then raise syntax 93.900 array('Unpaired surrogate')
            low = following~substr(3)~x2d
            if low < 56320 | low > 57343 then raise syntax 93.900 array('Unpaired surrogate')
            cp = 65536+(cp-55296)*1024+low-56320
            idx += 6
          end
          else if cp >= 56320 & cp <= 57343 then raise syntax 93.900 array('Unpaired surrogate')
          buffer~append(engineUtf8(cp))
          idx += 6
          iterate
        end
      end
      buffer~append(raw~substr(idx,2))
      idx += 2
      iterate
    end
    buffer~append(byte)
    idx += 1
  end
  return buffer~string

::routine engineUtf8
  use strict arg cp
  if cp < 2048 then return (192+cp%64)~d2c||(128+cp//64)~d2c
  if cp < 65536 then return (224+cp%4096)~d2c||(128+cp%64//64)~d2c||(128+cp//64)~d2c
  return (240+cp%262144)~d2c||(128+cp%4096//64)~d2c||(128+cp%64//64)~d2c||(128+cp//64)~d2c
