/* test_alchemyfetch.rex -- the ALCHEMYFETCH inbox loop against a fake mailbox, a fake curl and a fake nudge.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 10 November 2026.
 *   bin/kit.sh rexx tests/test_alchemyfetch.rex        (nothing leaves the machine; no browser is opened)
 */
kit=value('KIT',, 'ENVIRONMENT')
work=kit'/var/test-alchemyfetch'
address system 'rm -rf' mbQ(work) '&& mkdir -p' mbQ(work)
token=work'/token'
call mbWrite token, 'faketoken'
call mbWrite work'/local.conf', 'store_dir='work'/store' || '0a'x || 'token_file='token || '0a'x || 'mailbox_url=https://mailbox.invalid/mcp'
call mbWrite work'/nudge.sh', 'echo "$@" >>' mbQ(work'/nudges.log')
pass=0
fail=0

env='ALCHEMYFETCH_LOCAL_CONF='mbQ(work'/local.conf') 'MAILBOX_CURL="sh' kit'/tests/fakes/curl-mailbox-fake"',
    'FETCH_CURL="sh' kit'/tests/fakes/curl-fetch-fake"' 'FETCH_SVN=false BOSTON_CRAB_DIR=',
    'MAILBOX_FAKE_LOG='mbQ(work'/calls.log') 'NUDGE_CMD="sh' work'/nudge.sh"'

/* a token file anyone can read is refused before any call */
address system 'chmod 644' mbQ(token)
out=run()
call check 'token mode 644: STOP, exit 2, no mailbox call', rcOut==2 & out~pos('must be mode 600')>0 & \SysFileExists(work'/calls.log'), out
address system 'chmod 600' mbQ(token)

out=run()
calls=mbFile(work'/calls.log')
nudges=mbFile(work'/nudges.log')
call check 'one pass exits 0', rcOut==0, out
call check 'the list asks for everything (unreadOnly also hides answered requests)', calls~pos('unreadOnly')==0, calls
call check 'REQ-T1 (CLAUDE, lawful) answered with an executed report', replyFor(calls, 'REQ-T1')~pos('3. Executed.')>0, replyFor(calls, 'REQ-T1')
call check 'the reply carries the attribution line', replyFor(calls, 'REQ-T1')~pos('Architecture: Tom Dyer')>0
call check 'REQ-T2 (unlisted host) answered BLOCKED, not executed', replyFor(calls, 'REQ-T2')~pos('BLOCKED')>0 & replyFor(calls, 'REQ-T2')~pos('Not executed.')>0, replyFor(calls, 'REQ-T2')
call check 'REQ-T3 (addressed to CLAUDE) untouched', calls~pos('REQ-T3')==0
call check 'answers longer than the 500-character summary are read from structuredContent', out~pos('replied to CLAUDE about REQ-T1')>0 & out~pos('unreadable')==0, out
call check 'REQ-T5 (already marked read) untouched', calls~pos('REQ-T5')==0
call check 'REQ-T6 (its own reply to CLAUDE) untouched', calls~pos('"requestId":"REQ-T6"')==0
call check 'REQ-T4 (already answered) marked read, not answered again', replyFor(calls, 'REQ-T4')=='' & markedRead(calls, 'REQ-T4')
call check 'REQ-T4 (already answered) still nudged', nudges~pos('-- REQ-T4')>0, nudges
call check 'REQ-T1 and REQ-T2 marked read', markedRead(calls, 'REQ-T1') & markedRead(calls, 'REQ-T2')
call check 'REQ-T1 nudged into the mapped conversation', nudges~pos('claude --for ALCHEMYFETCH --in Browser control for ChatGPT coordination -- REQ-T1')>0, nudges
call check 'REQ-T2 (lane not mapped) not nudged', nudges~pos('REQ-T2')==0, nudges
call check 'the token never reaches the store or the log', grepTree(work'/store', 'faketoken')==0 & grepTree(kit'/var', 'faketoken')<=1
call check 'no header or body left in the temp dir', fileCount(work'/store/mailbox-tmp')==0

/* a server without structuredContent, whose summary has a raw tab and CR: the status line decides */
address system 'rm -f' mbQ(work'/calls.log') mbQ(work'/nudges.log')
out=run('MAILBOX_FAKE_REPLY=textonly')
calls=mbFile(work'/calls.log')
call check 'text-only answer with raw control characters: reply taken, REQ-T1 marked read', out~pos('replied to CLAUDE about REQ-T1')>0 & markedRead(calls, 'REQ-T1'), out

/* an answer to the reply that cannot be read at all: kept for reading, the request left unread */
address system 'rm -f' mbQ(work'/calls.log') mbQ(work'/nudges.log')
out=run('MAILBOX_FAKE_REPLY=garbage')
calls=mbFile(work'/calls.log')
call check 'unreadable reply answer: error logged, the answer kept', out~pos('unreadable answer, kept in')>0 & fileCount(work'/store/mailbox-tmp')>0, out
call check 'unreadable reply answer: REQ-T1 left unread and not nudged', \markedRead(calls, 'REQ-T1') & mbFile(work'/nudges.log')~pos('-- REQ-T1')==0

/* raw control characters inside strings are escaped; outside strings and after a backslash they are left alone */
bs='5c'x
call check 'mbJsonClean escapes a raw tab inside a string', mbJsonClean('{"a":"x'||'09'x||'y"}')=='{"a":"x'bs'u0009y"}'
call check 'mbJsonClean leaves an escaped quote and the text after it', mbJsonClean('{"a":"q'bs'"'||'0d'x||'"}')=='{"a":"q'bs'"'bs'u000d"}'
call check 'mbJsonClean leaves a line feed between tokens', mbJsonClean('{'||'0a'x||'"a":1}')=='{'||'0a'x||'"a":1}'
call check 'mbParse reads JSON with a raw CR in a string', mbParse('{"a":"x'||'0d'x||'y"}')~at('a')=='x'||'0d'x||'y'

/* the mailbox refuses the token: a STOP finding, no request handled */
call mbWrite token, 'wrongtoken'
address system 'chmod 600' mbQ(token)
address system 'rm -f' mbQ(work'/calls.log')
out=run()
call check 'refused token: listing failure logged, nothing handled', out~pos('listing failed')>0 & \SysFileExists(work'/calls.log'), out

say pass 'passed,' fail 'failed'
exit (fail>0)

run:
  extra=''
  if arg(1, 'e') then extra=arg(1)
  address system env extra 'sh' mbQ(kit'/bin/kit.sh') 'rexx' mbQ(kit'/bin/alchemyfetch.rex') '--once 2>&1' with output stem o.
  rcOut=rc
  t=''
  do i=1 to o.0
    t=t || o.i || '0a'x
  end
  return t

replyFor: procedure
  use arg calls, id
  do l over calls~makeArray('0a'x)
    if l~left(6)=='reply'||'09'x & l~pos('"requestId":"'id'"')>0 then return l
  end
  return ''

markedRead: procedure
  use arg calls, id
  do l over calls~makeArray('0a'x)
    if l~left(5)=='read'||'09'x & l~pos('"requestId":"'id'"')>0 then return .true
  end
  return .false

grepTree: procedure
  use arg dir, word
  address system 'grep -rl' mbQ(word) mbQ(dir) '2>/dev/null | wc -l' with output stem g.
  return g.1~strip

fileCount: procedure
  use arg dir
  address system 'ls -A' mbQ(dir) '2>/dev/null | wc -l' with output stem g.
  return g.1~strip

check:
  parse arg name
  if arg(2) then do
    pass=pass+1
    say 'PASS' name
  end
  else do
    fail=fail+1
    say 'FAIL' name
    if arg(3, 'e') then say '     ' arg(3)~left(600)
  end
  return

::requires 'MailboxClient.cls'
