/* test_order_gate.rex -- ALCHEMYFETCH through the OrderGate: is it an order, is it lawful, execute, report.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 9 November 2026.  Legal Effect v0.14: ChatGPT.
 *   bin/kit.sh rexx tests/test_order_gate.rex        (fake curl; nothing leaves the machine)
 */
kit=value('KIT',, 'ENVIRONMENT')
store=kit'/var/test-gate'
address system 'rm -rf' gateQ(store)
conf=fxReadConf(kit'/etc/fetch.conf')
conf['store_dir']=store
policy=.FetchPolicy~new(conf)
issuers=fxWords(conf, 'order_issuers', 'TOM')~makeString('L', ' ')~upper~makeArray(' ')
tools=.directory~new
tools['curl']='sh' gateQ(kit'/tests/fakes/curl-fetch-fake')
tools['svn']='false'
log=uiLog(kit)
gate=.OrderGate~new('ALCHEMYFETCH', .FetchOrderReader~new(policy, issuers), .FetchRules~new(policy, issuers), .FetchExecutor~new(policy, tools), log, store'/traces')
pass=0
fail=0
readme='https://sourceforge.net/p/oorexx/code-0/HEAD/tree/README.txt?format=raw'

call check 'issuers come from etc/fetch.conf', issuers~makeString('L', ' ')=='CLAUDE CHATGPT COORDINATOR TOM', issuers~makeString('L', ' ')

r=run('g1', 'CLAUDE', 'FETCH' readme)
call check 'lawful order from CLAUDE: CLEAR', r~pos('1. Order: CLEAR')>0, r
call check 'lawful order: ADMISSIBLE with a decision trace id', r~pos('2. Rules of engagement: ADMISSIBLE (decision trace ')>0, r
call check 'lawful order: executed and reported with its hash', r~pos('3. Executed.')>0 & r~pos('SHA-256:')>0, r
call check 'lawful order: the trace is kept on disk', traces()>=1

r=run('g2', 'CLAUDE', 'FETCH https://example.com/x')
call check 'unlisted host: BLOCKED by ROE-HOST, not executed', r~pos('BLOCKED')>0 & r~pos('ROE-HOST')>0 & r~pos('Not executed.')>0 & \SysFileExists(store'/g2'), r

r=run('g3', 'GEMINI', 'FETCH' readme)
call check 'issuer not in the chain of command: BLOCKED by ROE-ISSUER', r~pos('ROE-ISSUER')>0 & r~pos('Not executed.')>0, r

r=run('g4', 'CLAUDE', 'FETCH http://sourceforge.net/x')
call check 'plain http: BLOCKED by ROE-HTTPS', r~pos('ROE-HTTPS')>0 & r~pos('BLOCKED')>0, r

r=run('g5', 'CLAUDE', 'please get me the readme')
call check 'not an order: says what an order looks like, nothing assessed', r~pos('NOT AN ORDER')>0 & r~pos('Rules of engagement')=0, r

r=run('g6', 'CLAUDE', 'FETCH the ooRexx readme')
call check 'free text: REQUIRES CLARIFICATION (no guessing)', r~pos('REQUIRES CLARIFICATION')>0 & r~pos('Rules of engagement')=0, r

r=run('g7', 'CLAUDE', 'FETCH sourceforge.net/x')
call check 'no scheme: facts unknown -> REVIEW_REQUIRED, referred to TOM', r~pos('REVIEW_REQUIRED')>0 & r~pos('referred up the chain')>0 & r~pos('unresolved ROE-HOST')>0, r

r=run('g8', 'CLAUDE', 'FETCH https://sourceforge.net/evil')
call check 'redirect to an unlisted host: re-assessed and BLOCKED mid-task, with its own trace', r~pos('ADMISSIBLE')>0 & r~pos('STOP roe')>0 & r~pos('BLOCKED by ROE-HOST')>0, r

r=run('g9', 'CLAUDE', 'FETCH https://sourceforge.net/projects/oorexx/files/x.zip/download')
call check 'redirects through allowed mirrors: each re-assessed ADMISSIBLE, fetched', r~pos('3. Executed.')>0, r

r=run('g10', 'tom', 'fetch' readme)
call check 'issuer and verb are case-insensitive', r~pos('3. Executed.')>0, r

r1=run('g11', 'CLAUDE', 'FETCH https://example.com/same')
r2=run('g11', 'CLAUDE', 'FETCH https://example.com/same')
parse var r1 . '(decision trace ' t1 ')' .
parse var r2 . '(decision trace ' t2 ')' .
call check 'the same order and facts give the same decision trace id', t1==t2 & t1<>'', t1 t2

address system 'rm -rf' gateQ(store)
say 'order gate tests:' pass 'passed,' fail 'failed'
exit (fail>0)

run:
  use arg id, who, text
  return gate~process(.GateOrder~new(id, who~upper, 'ALCHEMYFETCH', text))~makeString('L', '0a'x)

traces:
  call SysFileTree store'/traces/*.trace', 't.', 'FO'
  return t.0

check:
  use arg what, ok, detail=''
  if ok then do
    pass=pass+1
    say 'PASS gate     ' what
  end
  else do
    fail=fail+1
    say 'FAIL gate     ' what '--' detail
  end
  return

::requires 'FetchOrders.cls'
::requires 'UiKit.cls'
