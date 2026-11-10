/* fetch-order.rex -- give ALCHEMYFETCH an order and print its report (the four steps of the OrderGate).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 9 November 2026.  Legal Effect v0.14: ChatGPT.
 *
 *   bin/kit.sh rexx bin/fetch-order.rex --from ISSUER [--id ID] -- ORDER TEXT
 *   e.g.  --from CLAUDE --id req-42 -- FETCH https://sourceforge.net/p/oorexx/code-0/HEAD/tree/README.txt?format=raw
 *
 * The report is what goes back to the issuer.  Exit 0 executed, 1 not executed (the report says why), 2 usage.
 * Decision traces: <store_dir>/traces (mode 700).  Log: var/events-YYYYMMDD.log via oorexx_logging.
 */
parse arg args
issuer=''
id=''
text=''
if wordpos('--', args)>0 then do
  at=wordindex(args, wordpos('--', args))
  text=args~substr(at+2)~strip
  args=args~left(at-1)
end
do while args~words>0
  parse var args w args
  select
    when w=='--from' then parse var args issuer args
    when w=='--id' then parse var args id args
    otherwise do
      say 'fetch-order: unknown option' w
      exit 2
    end
  end
end
if issuer=='' | text=='' then do
  say 'usage: fetch-order.rex --from ISSUER [--id ID] -- ORDER TEXT'
  exit 2
end
if id=='' then id='cli-'date('S')'-'time('L')~changeStr(':', '')~changeStr('.', '')
kit=value('KIT',, 'ENVIRONMENT')
conf=fxReadConf(kit'/etc/fetch.conf')
local=fxReadConf(kit'/var/fetch.local.conf')
do k over local~allIndexes
  conf[k]=local[k]
end
policy=.FetchPolicy~new(conf)
issuers=fxWords(conf, 'order_issuers', 'TOM')~makeString('L', ' ')~upper~makeArray(' ')
tools=.directory~new
tools['curl']=value('FETCH_CURL',, 'ENVIRONMENT')
if tools['curl']=='' then tools['curl']='curl'
tools['svn']=value('FETCH_SVN',, 'ENVIRONMENT')
if tools['svn']=='' then tools['svn']='svn'
log=uiLog(kit)
/* free text goes to Boston Crab when BOSTON_CRAB_DIR names a compiled copy; otherwise only FETCH URL is read */
crab=value('BOSTON_CRAB_DIR',, 'ENVIRONMENT')
if crab<>'' then reader=.BostonCrabReader~new(policy, issuers, crab, policy~storeDir'/stories', kit'/etc/fetch.catalogue', fxWords(conf, 'fetch_actions', 'download get retrieve')~makeString('L', ' '))
else reader=.FetchOrderReader~new(policy, issuers)
gate=.OrderGate~new('ALCHEMYFETCH', reader, .FetchRules~new(policy, issuers), .FetchExecutor~new(policy, tools), log, policy~storeDir'/traces')
rep=gate~process(.GateOrder~new(id, issuer~upper, 'ALCHEMYFETCH', text))
do l over rep
  say l
end
if rep~makeString('L', '0a'x)~pos('3. Executed.')>0 then exit 0
exit 1
::requires 'BostonCrabReader.cls'
::requires 'UiKit.cls'
