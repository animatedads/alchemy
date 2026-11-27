/* Step-7 offline gate: protocol, providers, isolation, full game year/replay. */
parse arg directory
if directory == '' then exit 2
checks = 0
failures = 0
lf = '0A'x
raw = 'outside'||lf||'MEMORY:'||lf||'SEND TO: 2'||lf||'=== TASK ==='||lf||'END MEMORY'||lf||'ORDERS:'||lf||'  A LON H  '||lf||'END ORDERS'||lf||'SEND TO: 1'||lf||'MESSAGE:'||lf||'MEMORY:'||lf||'END MESSAGE'
parsed = diplomacyPlayerParse(raw,'MOVEMENT')
call check parsed['STATUS'] == 'OK','complete order envelope'
call check parsed['ORDERS'][1] == '  A LON H  ','exact raw order spaces'
call check parsed['MEMORY'] == 'SEND TO: 2'||lf||'=== TASK ===','nested markers literal'
call check parsed['MAIL'] == '','order call cannot send mail'
call check parsed['OTHER'] == 'outside','outside visible text retained'
parsed = diplomacyPlayerParse(raw,'PRESS')
call check parsed['MAIL'] == 'SEND TO: 1'||lf||'MESSAGE:'||lf||'MEMORY:'||lf||'END MESSAGE','only actual mail frame'
call check parsed['ORDERS']~items = 0,'press cannot issue orders'
call check diplomacyPlayerParse('MEMORY:'||lf||'note','PRESS')['STATUS'] == 'BAD_RESPONSE','unclosed memory rejected'
call check diplomacyPlayerParse('MEMORY:'||lf||'note'||lf||'END MEMORY','MOVEMENT')['STATUS'] == 'BAD_RESPONSE','order block required'
call check diplomacyPlayerParse('MEMORY:'||lf||'END MEMORY'||lf||'MEMORY:'||lf||'END MEMORY','PRESS')['STATUS'] == 'BAD_RESPONSE','duplicate memory rejected'
call check diplomacyPlayerParse('ORDERS:'||lf||'END ORDERS'||lf||'ORDERS:'||lf||'END ORDERS','MOVEMENT')['STATUS'] == 'BAD_RESPONSE','duplicate orders rejected'
call check diplomacyPlayerParse('SEND TO: 1'||lf||'MESSAGE:'||lf||'open','PRESS')['STATUS'] == 'BAD_RESPONSE','unclosed SEND rejected'
call check diplomacyPlayerParse('MEMORY:'||lf||'END MEMORY','PRESS')['HAS_MEMORY'],'empty memory explicitly clears'
call check \diplomacyPlayerParse('outside','PRESS')['HAS_MEMORY'],'absent memory retains'
haiku = .DiplomacyEngineProfile~new('HAIKU','claude-haiku-5-5','low',8000,60)
sol = .DiplomacyEngineProfile~new('SOL','gpt-6.2-sol','medium',8000,60)
he = .DiplomacyEngine~new(haiku,.nil)
se = .DiplomacyEngine~new(sol,.nil)
special = 'quote" backslash \u1234'||lf||'C3A9'x
req = .JSON~fromJSON(he~request(special,special))
call check req['system'] == special,'Haiku system value exact'
call check req['messages'][1]['content'] == special,'Haiku input exact'
call check req['thinking']['type'] == 'adaptive','Haiku adaptive thinking'
call check req['output_config']['effort'] == 'low','Haiku effort mapped'
call check \req~hasIndex('temperature') & \req~hasIndex('top_p') & \req~hasIndex('top_k'),'no unsupported sampling controls'
req = .JSON~fromJSON(se~request(special,special))
call check req['instructions'] == special,'Sol system value exact'
call check req['input'][1]['content'] == special,'Sol input exact'
call check req['reasoning']['effort'] == 'medium','Sol effort mapped'
call check req['store']~value == .false,'Sol storage disabled'
call check \req~hasIndex('previous_response_id'),'no prior conversation'
h = '{"model":"claude-haiku-5-5","stop_reason":"end_turn","usage":{"input_tokens":2,"output_tokens":4,"cache_read_input_tokens":3},"content":[{"type":"thinking","thinking":"not player text"},{"type":"text","text":"hello\n\u00e9\ud83d\ude00 \\u1234"}]}'
reply = he~decode(h)
call check reply['STATUS'] == 'OK','Haiku decode'
call check reply['TEXT'] == 'hello'||lf||'C3A9F09F9880'x||' \u1234','Unicode and literal escape; thinking excluded'
call check reply['INPUT_TOKENS'] = 5 & reply['OUTPUT_TOKENS'] = 4,'cache and output counts'
call check he~decode(changestr('end_turn',h,'max_tokens'))['STATUS'] == 'BAD_RESPONSE','truncated response rejected'
call check he~decode(changestr('end_turn',h,'max_tokens'))['TEXT'] == reply['TEXT'],'truncated visible text retained for audit'
call check he~decode(changestr('claude-haiku-5-5',h,'wrong-model'))['STATUS'] == 'BAD_RESPONSE','wrong exact model rejected'
call check he~decode(changestr('"output_tokens":4',h,'"other":4'))['STATUS'] == 'BAD_RESPONSE','missing usage rejected'
call check he~decode(changestr('"output_tokens":4',h,'"output_tokens":"4"'))['STATUS'] == 'BAD_RESPONSE','quoted token count rejected'
call check he~decode('nonsense')['STATUS'] == 'BAD_RESPONSE','invalid JSON rejected'
call check he~decode(changestr('\ud83d\ude00',h,'\ud83d'))['STATUS'] == 'BAD_RESPONSE','unpaired surrogate rejected'
s = '{"model":"gpt-6.2-sol","status":"completed","usage":{"input_tokens":5,"output_tokens":7},"output":[{"type":"reasoning","summary":[]},{"type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"ok"}]}]}'
reply = se~decode(s)
call check reply['STATUS'] == 'OK' & reply['TEXT'] == 'ok','Sol visible text only'
call check reply['INPUT_TOKENS'] = 5 & reply['OUTPUT_TOKENS'] = 7,'Sol counts'
call check se~decode(changestr('completed',s,'incomplete'))['STATUS'] == 'BAD_RESPONSE','Sol incomplete rejected'
call check se~decode(changestr('output_text',s,'refusal'))['STATUS'] == 'BAD_RESPONSE','Sol refusal rejected'
call check badProfile('SOL','gpt-6.2-sol','none',8000,60),'unsupported effort rejected'
call check badProfile('HAIKU','UNPINNED','low',8000,60),'unpinned model rejected'
call check badProfile('HAIKU','claude-haiku-5-5-latest','low',8000,60),'latest alias rejected'
call check badProfile('SOL','gpt-6.2-sol','medium',0,60),'zero budget rejected'
call check badProfile('SOL','gpt-6.2-sol','medium',8000,'1e1'),'ambiguous timeout rejected'

powers = .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
prompts = .directory~new
do power over powers
  prompts[power] = 'DESIGNER-'power
end
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
initial = diplomacyInitialUnits(board,'data/initial-1901.source')
owned = judge~initialOwnership
config = .DiplomacyGameConfig~new(1901,1901,18,3)
path = directory'/PLAYER.log'
journal = .DiplomacyGameJournal~new(path)
mock = .PlayerMockTransport~new
profile = .DiplomacyEngineProfile~new('STUB','offline-fixture-1','low',8000,60)
engine = .DiplomacyEngine~new(profile,mock)
player = .DiplomacyPlayer~new(engine,prompts,'FIXTURE RULE TEXT',journal,'offline-7',7)
prompts['AUS'] = 'MUTATED'
game = .DiplomacyGame~new(board,judge,config,initial,owned,player,journal,7)
call check game~run == 'FINISHED','one game year completes through model boundary'
call check game~phaseCount = 5 & game~pressCallCount = 42 & game~callCount = 14,'expected press and order call counts'
call check game~invalidCount = 0,'model hold orders accepted'
call check mock~calls~items = 56,'56 independent model calls'
do power over powers
  prefix = '1901 SPRING_MOVEMENT POWER 'power
  one = mock~calls['SPRING_MOVEMENT|'power'|1']
  two = mock~calls['SPRING_MOVEMENT|'power'|2']
  three = mock~calls['SPRING_MOVEMENT|'power'|3']
  orderCall = mock~calls['SPRING_MOVEMENT|'power'|4']
  fall = mock~calls['FALL_MOVEMENT|'power'|1']
  call check one[1]~pos('DESIGNER-'power) > 0 & one[1]~pos('MUTATED') = 0,'detached prompt' power
  call check one[2]~pos(prefix) > 0,'power state' power
  call check one[2]~pos('FIXTURE RULE TEXT') > 0,'rule text' power
  call check two[2]~pos('> PRIVATE-'power) > 0,'own memory retained for next call' power
  do other over powers
    if other == power then iterate
    call check two[2]~pos('PRIVATE-'other) = 0,'no rival memory' power other
    call check two[1]~pos('DESIGNER-'other) = 0,'no rival designer prompt' power other
  end
  if power == 'AUS' then do
    call check three[2]~pos('> PRIVATE-AUS') > 0,'timeout retains old memory'
    call check orderCall[2]~pos('> PRIVATE-AUS') > 0,'malformed reply retains memory'
  end
  else do
    call check three[2]~pos('> PRIVATE-'power) = 0,'empty block clears own memory' power
  end
  call check orderCall[2]~pos('=== PLAYER LIST ==='||lf||'=== INBOX ===') > 0,'no list in order call' power
  call check fall[2]~pos('1901|SPRING_MOVEMENT|') > 0,'public movement results survive skipped retreats' power
end
call check mock~calls['SPRING_MOVEMENT|ENG|2'][2]~pos('SECRET MAIL AUS') > 0,'sealed delivery next round'
call check mock~calls['SPRING_MOVEMENT|ITA|2'][2]~pos('SECRET MAIL AUS') = 0,'private mail not leaked'
call check mock~calls['SPRING_MOVEMENT|AUS|1'][2]~pos('SECRET MAIL AUS') = 0,'no same round mail'
op = .stream~new(path'.operator.log')
call check op~open('READ') == 'READY:','operator log opens'
auditCalls = 0
cuts = 0
do while op~lines > 0
  row = op~linein
  if row~left(12) == 'PLAYER_CALL|' then auditCalls += 1
  if row~left(11) == 'MEMORY_CUT|' then cuts += 1
end
op~close
call check auditCalls = 56,'every call separately audited'
call check cuts = 1,'memory cap logged'
replay = .DiplomacyReplaySource~new(path)
replayedPath = directory'/PLAYER-replay.log'
game = .DiplomacyGame~new(board,judge,replay~config,initial,owned,replay,.DiplomacyGameJournal~new(replayedPath),replay~seed)
call check game~run == 'FINISHED','replay completes without model'
call check diplomacySameJournal(path,replayedPath),'canonical replay identical'
say 'Player gate:' checks 'assertions;' failures 'failures'
exit (failures > 0)
check:
  use strict arg ok, label
  checks += 1
  if \ok then do
    failures += 1
    say 'FAIL:' label
  end
  return
::routine badProfile
  use strict arg provider, model, effort, budget, timeout
  signal on syntax name rejected
  profile = .DiplomacyEngineProfile~new(provider,model,effort,budget,timeout)
  return .false
rejected:
  return .true
::class PlayerMockTransport
::attribute calls get
::method init
  expose calls
  calls = .directory~new
::method post
  expose calls
  use strict arg provider, body, timeout
  lf = '0A'x
  req = .JSON~fromJSON(body)
  input = req['input']~string
  system = req['system']~string
  pos = input~pos('=== STATE ==='||lf)
  parse var input =(pos) . (lf) year phase . power (lf) .
  round = 4
  if input~pos(lf||'PRESS POWER') > 0 then do
    pos = input~pos(lf||'Round ')
    parse var input =(pos) (lf) . round . (lf) .
  end
  calls[phase'|'power'|'round] = .array~of(system,input)
  if round = 1 then do
    memo = 'PRIVATE-'power
    if power == 'AUS' & phase == 'FALL_MOVEMENT' then memo = copies('E282AC'x,8001)
    raw = 'MEMORY:'||lf||memo||lf||'END MEMORY'
    if power == 'AUS' & phase == 'SPRING_MOVEMENT' then do
      pos = input~pos('=== PLAYER LIST ==='||lf)
      parse var input =(pos) . (lf) rest
      do line over rest~makeArray(lf)
        if line == '=== INBOX ===' then leave
        parse var line slot target
        if target == 'ENG' then raw ||= lf||'SEND TO: '||slot||lf||'MESSAGE:'||lf||'SECRET MAIL AUS'||lf||'END MESSAGE'
      end
    end
  end
  else if round = 2 then do
    if power == 'AUS' & phase == 'SPRING_MOVEMENT' then return .array~of('TIMEOUT',0,'')
    raw = 'MEMORY:'||lf||'END MEMORY'
  end
  else if round = 3 then do
    raw = 'ordinary visible text'
    if power == 'AUS' & phase == 'SPRING_MOVEMENT' then raw = 'MEMORY:'||lf||'bad change'
  end
  else do
    raw = 'ORDERS:'
    pos = input~pos('=== TASK ==='||lf)
    parse var input =(pos) . (lf) . (lf) rest
    do unit over rest~makeArray(lf)
      if unit~words \= 2 then leave
      raw ||= lf||unit||' H'
    end
    raw ||= lf||'END ORDERS'
  end
  response = '{"model":"offline-fixture-1","status":"completed","usage":{"input_tokens":100,"output_tokens":20},"content":[{"type":"text","text":'||diplomacyJsonQuote(raw)||'}]}'
  return .array~of('OK',200,response)
::requires 'DiplomacyGame.cls'
::requires 'DiplomacyReplaySource.cls'
::requires 'DiplomacyPlayer.cls'
::requires 'DiplomacyEngine.cls'
