/* slam_reply.rex - send Heel Turn one press message and show its reply.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   The message is put into a press call the framework itself rendered
   (tests/fixtures/spring1901_aus_press.txt: Spring 1901, round 1), addressed
   from one seat to another, and the real engine answers it. Printed: what
   Heel Turn read (acts, tone, intent, flags, commitments, requests), what it
   believes about each promise (Reasoned Thought status), and the SEND blocks
   it wrote, with each number resolved to the power it addresses.
   Usage: rexx tools/slam_reply.rex MESSAGE_FILE FROM TO [PROMPT_FILE] [LOG]
   FROM and TO are seat codes (AUS ENG FRA GER ITA RUS TUR). */
parse arg msgFile from to promptFile logPath
if to == '' then do
  say 'usage: rexx tools/slam_reply.rex MESSAGE_FILE FROM TO [PROMPT_FILE] [LOG]'
  exit 2
end
from = from~upper
to = to~upper
seats = 'AUS ENG FRA GER ITA RUS TUR'
if wordpos(from, seats) = 0 | wordpos(to, seats) = 0 | from == to then do
  say 'FROM and TO must be two different seats of' seats
  exit 2
end
root = value('HEELTURN_ROOT', , 'ENVIRONMENT')
if root == '' then root = '.'
body = heelTurnGameRead(msgFile)~strip('T', '0A'x)
prompt = 'Play well.'
if promptFile \== '' then prompt = heelTurnGameRead(promptFile)
fx = .HeelTurnFixture~new(root'/tests/fixtures/spring1901_aus_press.txt')
system = fx~system(prompt)
input = fx~input(.array~of('1901S-R1-001|'from'|'to'|'body), , , 'PRESS', 'SPRING_MOVEMENT', to)
engine = .HeelTurnEngine~new(root'/data', logPath, .false)
-- what Heel Turn read, by the same classes the engine uses
view = .HeelTurnView~new(system, input)
map = .HeelTurnMap~new(view~mapLines)
a = .HeelTurnAssessment~new(map, view)
mr = .HeelTurnMessageReader~new(.HeelTurnReader~new(engine~vocab, .HeelTurnPlaces~new(view~mapLines)), map, a)
r = mr~readMail(view~mail[1])
say 'HEEL TURN READ (as' to', from' from')'
say '  acts:    ' r['ACTS']~makeString('L', ', ')
say '  tone:    ' r['TONE_LABEL'] '  intent:' r['INTENT'] '  flags:' r['FLAGS']
do c over r['COMMITS']
  cond = ''
  if c['SCOPE'] == 'COND' then cond = 'if' c['COND'] 'then' c['THEN']
  if c['SCOPE'] == 'COND' then if c['COND'] == '' then cond = '(condition not checkable: never judged)'
  say '  commits: ' c['KIND'] (c['UNIT'] c['PROV'] c['TTYPE'] c['TLOC'] c['TDEST'])~space 'strength' c['STRENGTH'] 'scope' c['SCOPE'] cond
end
do q over r['REQUESTS']
  say '  requests:' q['KIND'] (q['UNIT'] q['TTYPE'] q['TLOC'] q['TDEST'] q['PROV'] q['SUPPORTER'])~space
end
do q over r['ASKS']
  say '  asks:    ' q['KIND'] (q['PROV'] q['POWER'])~space
end
do t over r['THIRD']
  say '  hearsay: ' t['POWER']
end
do f over r['REFS']
  say '  refers:  ' '"'f['PHRASE']'"' f['VERDICT'] '('f['CANDIDATES']')' 'into' f['DEST']
end
do u over r['UNREAD']
  say '  unread:  ' u
end
mind = .HeelTurnMind~new(view~memory, view, map, a, .HeelTurnPromptReader~new(.HeelTurnReader~new(engine~vocab))~read(view~prompt))
mind~absorb(.array~of(r))
mind~judge
do e over mind~ledgerIn
  d = mind~decisionFor(e)
  verdict = d['status']
  if d['disputed'] | wordpos(verdict, 'SUPPORTED SETTLED') = 0 then verdict = verdict '(CANNOT TELL)'
  if e['SCOPE'] == 'COND' then verdict = verdict '(conditional: not planned on until its condition is decided)'
  say '  believes:' e['FROM'] 'keeps' e['KIND'] (e['UNIT'] e['PROV'] e['TLOC'] e['TDEST'])~space '->' verdict
  do note over mind~policiesFor(e)
    say '    policy:' note
  end
end
do ev over mind~events
  say '  event:   ' ev
end
-- the real call
reply = engine~invoke(system, input)
say ''
say 'HEEL TURN REPLIED (status' reply['STATUS']')'
mode = ''
do line over reply['TEXT']~makeArray('0A'x)
  if line~left(8) == 'SEND TO:' then do
    nums = line~substr(9)~strip
    names = ''
    do num over nums~makeArray(' ')
      names = names view~playerList[num]
    end
    say '  to' names~strip':'
    iterate
  end
  if line == 'MESSAGE:' then do
    mode = 'MSG'
    iterate
  end
  if line == 'END MESSAGE' then do
    mode = ''
    iterate
  end
  if mode == 'MSG' then say '    'line
end
exit (reply['STATUS'] \== 'OK')
::requires 'HeelTurnGame.cls'
::requires 'HeelTurnFixture.cls'
