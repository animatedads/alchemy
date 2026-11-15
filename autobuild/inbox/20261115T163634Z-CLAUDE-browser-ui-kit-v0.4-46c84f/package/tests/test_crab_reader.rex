/* test_crab_reader.rex -- free-text fetch orders read by Boston Crab, through the OrderGate.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 9 November 2026.
 * Boston Crab v0.21: its own chat.  Legal Effect v0.14: ChatGPT.
 *   BOSTON_CRAB_DIR=<compiled copy> bin/kit.sh rexx tests/test_crab_reader.rex     (skips without it)
 */
kit=value('KIT',, 'ENVIRONMENT')
crab=value('BOSTON_CRAB_DIR',, 'ENVIRONMENT')
if crab=='' | \SysFileExists(crab'/order_check.rex') then do
  say 'SKIP crab reader tests: BOSTON_CRAB_DIR does not name a Boston Crab copy'
  exit 0
end
store=kit'/var/test-crab'
address system 'rm -rf' gateQ(store)
conf=fxReadConf(kit'/etc/fetch.conf')
conf['store_dir']=store
policy=.FetchPolicy~new(conf)
issuers=fxWords(conf, 'order_issuers', 'TOM')~makeString('L', ' ')~upper~makeArray(' ')
tools=.directory~new
tools['curl']='sh' gateQ(kit'/tests/fakes/curl-fetch-fake')
tools['svn']='false'
reader=.BostonCrabReader~new(policy, issuers, crab, store'/stories', kit'/etc/fetch.catalogue', fxWords(conf, 'fetch_actions', '')~makeString('L', ' '))
gate=.OrderGate~new('ALCHEMYFETCH', reader, .FetchRules~new(policy, issuers), .FetchExecutor~new(policy, tools), uiLog(kit), store'/traces')
pass=0
fail=0

r=run('c1', 'Fetch the ooRexx README.')
call check 'a named document in the catalogue: CLEAR, its catalogued address, fetched', r~pos('fetch https://sourceforge.net/p/oorexx/code-0/HEAD/tree/README.txt?format=raw')>0 & r~pos('3. Executed.')>0, r
r=run('c2', 'Fetch the README.')
call check 'a name that fits two documents: not executed, Boston Crab names both', r~pos('Not executed')>0 & r~pos('NetRexx README')>0 & r~pos('ooRexx README')>0, r
r=run('c3', 'Get the manual.')
call check 'no such document: NO REFERENT, not executed', r~pos('NO REFERENT')>0 & r~pos('Not executed')>0, r
r=run('c4', 'Do not fetch the ooRexx README.')
call check 'only a prohibition: NOTED, nothing executed', r~pos('NOTED')>0 & r~pos('Noted; nothing to execute.')>0 & r~pos('Executed')=0, r
r=run('c5', 'Fetch https://sourceforge.net/projects/oorexx/files/x.zip/download')
call check 'a URL in free text: fetched as written', r~pos('3. Executed.')>0, r
r=run('c6', 'Fly to the ooRexx README.')
call check 'not a fetch: ALCHEMYFETCH only fetches', r~pos('ALCHEMYFETCH only fetches')>0 & r~pos('Not executed')>0, r
r=run('c7', 'Fetch https://example.com/page')
call check 'an unlisted host: read CLEAR, then BLOCKED by ROE-HOST', r~pos('1. Order: CLEAR')>0 & r~pos('ROE-HOST')>0 & r~pos('BLOCKED')>0, r
r=run('c8', 'FETCH https://sourceforge.net/p/oorexx/code-0/HEAD/tree/README.txt?format=raw')
call check 'the exact structured form still needs no reading', r~pos('3. Executed.')>0 & r~pos('Boston Crab')=0, r

address system 'rm -rf' gateQ(store)
say 'crab reader tests:' pass 'passed,' fail 'failed'
exit (fail>0)

run:
  use arg id, text
  return gate~process(.GateOrder~new(id, 'CLAUDE', 'ALCHEMYFETCH', text))~makeString('L', '0a'x)

check:
  use arg what, ok, detail=''
  if ok then do
    pass=pass+1
    say 'PASS crab     ' what
  end
  else do
    fail=fail+1
    say 'FAIL crab     ' what '--' detail
  end
  return

::requires 'BostonCrabReader.cls'
::requires 'UiKit.cls'
