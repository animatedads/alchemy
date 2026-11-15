/* test_cli.rex -- bin/browser-ui.rex itself, run as a person runs it, against the Claude-shaped test fixture.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 9 November 2026.
 *
 * Written after the CLI's send was found unusable on 9 Nov: it expected quoted words, and the shell strips
 * quotes.  These tests pass arguments through sh exactly as typed at a prompt.
 * Needs the fixture host (tests/run_matrix.sh starts it).  Signs a profile in with the fixture's TEST account.
 */
kit=value('KIT',, 'ENVIRONMENT')
chrome=value('CHROME',, 'ENVIRONMENT')
conf=uiReadProps(kit'/etc/fixtures.conf')
pass=0
fail=0
root=kit'/var/cli-profiles'
address system 'rm -rf' cdpQ(root)
address system 'mkdir -p' cdpQ(root)
call value 'BROWSER_PROFILES', root, 'ENVIRONMENT'
base='https://127.0.0.1:'conf['claude_port']'/new'
call value 'BROWSER_UI_BASE', base, 'ENVIRONMENT'

/* a signed-on profile for "claude", made with the fixture's own sign-in form */
b=.CdpBrowser~new(chrome, root'/claude', .true, 9344)
b~insecureCerts=.true
b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
ok=b~launch
p=b~newPage
ok=p~navigate('https://127.0.0.1:'conf['claude_port']'/login', 20)
ok=p~typeText('[data-testid="email"]', conf['test_user'])
ok=p~typeText('input[name="password"]', conf['test_password'])
ok=p~click('[data-testid="continue"]')
ok=p~waitFor('location.pathname!=="/login"', 10, 'fixture sign-in')
ok=b~close

cli='rexx' cdpQ(kit'/bin/browser-ui.rex')
call run 'state claude --headless'
call check 'state, typed as at a prompt', rc=0 & out~pos('SIGNED_ON')>0, out
call run 'conversations claude --headless'
call check 'conversations lists the fixture titles', rc=0 & out~pos('Rasen Falcon')>0, out
call run 'send claude --headless -- hello from the cli'
call check 'send to a new conversation: unquoted words after --', rc=0 & out~pos('Fixture reply to: hello from the cli')>0, out
call check 'the message was sent once, not typed twice', out~pos('hello from the clihello')=0, out
ua=fixtureGet(conf, '/api/last-agent')
call check 'declared automation: the user agent carries the AlchemyAgent token', ua~pos('AlchemyAgent/0.1 (scripted request; requested-by=operator; +https://rasenfalcon.com)')>0, ua
call check 'declared automation: appended, the browser still says HeadlessChrome', ua~pos('HeadlessChrome/')>0, ua
call run 'send claude --headless --for CLAUDE -- asked by an agent'
ua=fixtureGet(conf, '/api/last-agent')
call check '--for CLAUDE: "LLM-driven request; requested-by=CLAUDE"', rc=0 & ua~pos('(LLM-driven request; requested-by=CLAUDE; +https://rasenfalcon.com)')>0, ua
call run 'send claude --headless --for bad/name -- x'
call check '--for with a bad name is a usage error', rc=2 & out~pos('--for needs an agent name')>0, out
call run 'send claude --headless --in Rasen Falcon -- second: with "quotes" -- and dashes'
call check 'send --in TITLE WORDS; a later -- stays in the text (sh removes the quotes, as at a prompt)', rc=0 & out~pos('Fixture reply to: second: with quotes -- and dashes')>0, out
/* a slow page: the composer clears at once but the user turn shows 7 s later (longer than one 5 s attempt).
 * The kit must treat the cleared composer as sent, and the server must see the message exactly once. */
fx='https://127.0.0.1:'conf['claude_port']
address system 'curl -sk' cdpQ(fx'/api/turn-delay?seconds=7') '>/dev/null'
call run 'send claude --headless --in General -- slow page message'
address system 'curl -sk' cdpQ(fx'/api/turn-delay?seconds=0') '>/dev/null'
call check 'slow page: the reply still comes back', rc=0 & out~pos('Fixture reply to: slow page message')>0, out
call check 'slow page: the kit stopped clicking once the composer cleared', out~pos('treated as sent')>0, out
b=.CdpBrowser~new(chrome, root'/claude', .true, 9344)
b~insecureCerts=.true
b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
ok=b~launch
p=b~newPage
ok=p~navigate(fx'/chat/general', 20)
n=p~probe('[...document.querySelectorAll(''[data-testid="user-message"]'')].filter(e=>e.textContent.trim()==="slow page message").length')
ok=b~close
call check 'slow page: the message reached the server exactly once', n=1, 'user turns with that text:' n

/* nudge: only the request id is typed, and the kit does not wait for the reply */
call run 'nudge claude --headless --in Rasen Falcon -- REQ-00000042'
call check 'nudge: sent, without waiting for a reply', rc=0 & out~pos('sent')>0 & out~pos('Fixture reply to')=0, out
b=.CdpBrowser~new(chrome, root'/claude', .true, 9344)
b~insecureCerts=.true
b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
ok=b~launch
p=b~newPage
ok=p~navigate(fx'/chat/rasen-falcon', 20)
n=p~probe('[...document.querySelectorAll(''[data-testid="user-message"]'')].filter(e=>e.textContent.trim()==="The event you registered a request for REQ-00000042 has occurred, check Rasen Falcon MCP.").length')
ok=b~close
call check 'nudge: the conversation holds exactly the contract sentence, once', n=1, n
/* the mail nudge (15 Nov 2026): by conversation path, fixed text with lane and ids, refuses a busy chat */
call run 'mail claude --headless --for MAILNUDGE --in /chat/general -- xtp REQ-00003501 REQ-00003502 +2'
call check 'mail by path: sent, without waiting for a reply', rc=0 & out~pos('sent')>0 & out~pos('Fixture reply to')=0, out
call run 'mail claude --headless --for MAILNUDGE --in /chat/general -- xtp REQ-00003503'
call check 'mail while the reply to the last one streams: BUSY, exit 3, nothing typed', rc=3 & out~pos('BUSY')>0, out
call SysSleep 7
call run 'mail claude --headless --for MAILNUDGE --in /chat/general -- xtp REQ-00003503'
call check 'mail once the reply has finished: sent', rc=0 & out~pos('sent')>0, out
mailText='You have mail on Rasen Falcon, lane xtp: REQ-00003501, REQ-00003502 and 2 more. Read them with project.requests.list (componentId xtp, unreadOnly true), act on each, reply, and mark each read.'
b=.CdpBrowser~new(chrome, root'/claude', .true, 9344)
b~insecureCerts=.true
b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
ok=b~launch
p=b~newPage
ok=p~navigate(fx'/chat/general', 20)
n=p~probe('[...document.querySelectorAll(''[data-testid="user-message"]'')].filter(e=>e.textContent.trim()==='cdpJs(mailText)').length')
n3=p~probe('[...document.querySelectorAll(''[data-testid="user-message"]'')].filter(e=>e.textContent.includes("REQ-00003503")).length')
ok=b~close
call check 'mail: the conversation holds exactly the fixed text, once', n=1, n
call check 'mail: the busy attempt typed nothing (REQ-00003503 once)', n3=1, n3
call run 'mail claude --headless --in /chat/general -- xtp hello'
call check 'mail with a word that is not a request id is a usage error', rc=2 & out~pos('mail needs')>0, out
call run 'mail claude --headless --in /chat/general -- Bad_Lane REQ-1'
call check 'mail with a bad lane id is a usage error', rc=2, out
call run 'mail claude --headless --in /chat/no-such-chat -- xtp REQ-1'
call check 'mail to a path the site does not have is a STOP, exit 1', rc=1 & out~pos('opened /chat/no-such-chat')>0, out
call check 'the browser lock is let go after a run', \SysIsFileDirectory(kit'/var/browser-ui.lock')
address system 'mkdir -p' cdpQ(kit'/var/browser-ui.lock') '&& touch -d "20 minutes ago"' cdpQ(kit'/var/browser-ui.lock')
call run 'state claude --headless'
call check 'a lock left for 20 minutes is taken over', rc=0 & out~pos('taking over')>0 & out~pos('SIGNED_ON')>0, out
/* mailbatch (v0.3): several nudges in one browser run, opened once and closed once */
jobs=kit'/var/test-mailbatch.tsv'
call SysFileDelete jobs
call lineout jobs, 'k1'||'09'x||'/chat/general'||'09'x||'xtp'||'09'x||'REQ-00003601'
call lineout jobs, 'k2'||'09'x||'/chat/rasen-falcon'||'09'x||'xtp'||'09'x||'REQ-00003602 REQ-00003604'
call lineout jobs, 'k3'||'09'x||'/chat/no-such-chat'||'09'x||'xtp'||'09'x||'REQ-00003603'
call lineout jobs, 'k4'||'09'x||'/chat/general'||'09'x||'xtp'||'09'x||'hello'
call lineout jobs
call run 'mailbatch claude --headless --for MAILNUDGE --jobs' jobs
call check 'mailbatch: four jobs, one browser launched and closed once', countStr2(out, 'launch claude')==1 & countStr2(out, 'browser closed')==1, out
call check 'mailbatch: the two good chats are sent', out~pos('RESULT'||'09'x||'k1'||'09'x||'sent')>0 & out~pos('RESULT'||'09'x||'k2'||'09'x||'sent')>0, out
call check 'mailbatch: an unknown chat fails without stopping the rest', out~pos('RESULT'||'09'x||'k3'||'09'x||'failed')>0, out
call check 'mailbatch: a job with a word that is not a request id is refused unsent', out~pos('RESULT'||'09'x||'k4'||'09'x||'failed: the job line did not check out')>0, out
b=.CdpBrowser~new(chrome, root'/claude', .true, 9344)
b~insecureCerts=.true
b~extraFlags=value('CHROME_FLAGS',, 'ENVIRONMENT')
ok=b~launch
p=b~newPage
ok=p~navigate(fx'/chat/rasen-falcon', 20)
n2=p~probe('[...document.querySelectorAll(''[data-testid="user-message"]'')].filter(e=>e.textContent.includes("lane xtp: REQ-00003602, REQ-00003604.")).length')
ok=b~close
call SysFileDelete jobs
call check 'mailbatch: the second chat holds its own fixed text', n2=1, n2
call run 'nudge claude --headless -- REQ-1'
call check 'nudge without --in is a usage error', rc=2 & out~pos('nudge needs --in')>0, out
call run 'nudge claude --headless --in General -- REQ 1'
call check 'nudge with more than one word after -- is a usage error', rc=2, out
call run 'send claude --headless --in No Such Title -- x'
call check 'unknown conversation is a STOP, exit 1', rc=1 & out~pos('no conversation titled No Such Title')>0, out
call run 'send claude --headless'
call check 'send without -- is a usage error before any browser starts', rc=2 & out~pos('launch')=0, out
call run 'send claude --bogus -- x'
call check 'unknown option is a usage error', rc=2 & out~pos('unknown option --bogus')>0, out
call value 'BROWSER_UI_BASE', 'https://example.com/', 'ENVIRONMENT'
call run 'state claude --headless'
call check 'the test hook refuses anything but 127.0.0.1', rc=2, out
call value 'BROWSER_UI_BASE', '', 'ENVIRONMENT'

address system 'rm -rf' cdpQ(root)
say 'cli tests:' pass 'passed,' fail 'failed'
exit (fail>0)

/* Run the CLI through sh with the arguments exactly as typed (sh does the word splitting and quote removal). */
countStr2: procedure
  use arg text, word
  return text~countStr(word)

run:
  parse arg args
  cmd='sh -c' cdpQ(cli args)
  address system cmd '2>&1' with output stem o.
  out=''
  do i=1 to o.0
    out=out o.i
  end
  return

check:
  use arg what, ok, detail=''
  if ok then do
    pass=pass+1
    say 'PASS cli      ' what
  end
  else do
    fail=fail+1
    say 'FAIL cli      ' what '--' detail~right(400)
  end
  return

::routine fixtureGet
  use strict arg conf, path
  address system 'curl -sk' cdpQ('https://127.0.0.1:'conf['claude_port']||path) with output stem o.
  t=''
  do i=1 to o.0
    t=t||o.i
  end
  return t

::requires 'UiKit.cls'
