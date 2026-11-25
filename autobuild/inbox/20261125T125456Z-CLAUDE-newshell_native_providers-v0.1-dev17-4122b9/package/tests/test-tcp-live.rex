/* Architecture: Tom Dyer. Coding: ChatGPT. Optional live kernel TCP_INFO test. */
parse arg path fixture
numeric digits 30
pr=.ProcessProvider~new; prov=.POSIXProvider~new
runner=.ProcessRunner~new(pr);spec=.ProcessSpec~new(.Array~of(fixture,path));spec~detach=.true;spec~stdoutPolicy='DISCARD';spec~stderrPolicy='DISCARD';child=runner~run(spec)
if \child~started then do;say 'FAIL tcp disposable fixture launch';exit 1;end
signal on syntax name failed
call waitFile path'/port'
f=.Stream~new(path'/port');port=f~lineIn;f~close
call touch path'/go';call waitFile path'/ready'
first=prov~tcpCounters(port)
if \first['OK'] then do
  call touch path'/stop'
  if value('REQUIRE_TCP_DIAG',,'ENVIRONMENT')=='1' | \.Array~of(1,2,13,38,93,95,97)~hasItem(first['ERRNO']) then do
    say 'FAIL live TCP_INFO required or unexpected error:' first['ERRNO'] first['ERROR'];exit 1
  end
  say 'SKIP live TCP_INFO loopback transfer:' first['ERRNO'] first['ERROR'];exit 0
end
call check first['SOCKETS']~items>=1,'tcp live established local-port counters'
probe=.SecurityTcpRateProbe~new(port,5000)
call check \probe~evaluate(first)['OK'],'tcp live initial counter baseline'
old=.Directory~new;do s over first['SOCKETS'];old[s['COOKIE']]=s;end
call touch path'/burst';call waitFile path'/burst.done'
advanced=.false
 do i=1 to 60
   last=prov~tcpCounters(port)
   if \last['OK'] then leave
   rx=0;ack=0
   do s over last['SOCKETS']
     if old~hasIndex(s['COOKIE']) then do
       rx+=s['RECEIVED_BYTES']-old[s['COOKIE']]['RECEIVED_BYTES'];ack+=s['ACKED_BYTES']-old[s['COOKIE']]['ACKED_BYTES']
     end
   end
   if rx>=8192 & ack>=8192 then do;advanced=.true;leave;end
   call SysSleep 0.02
 end
call check advanced,'tcp live acknowledged and received byte counters advance'
r=probe~evaluate(last)
call check r['OK'] & r['TCP_ACKED_BPS']>0 & r['TCP_RECEIVED_BPS']>0,'tcp live rate from stable socket identities'
say 'MEASURE TCP_ACKED_BPS' r['TCP_ACKED_BPS'] 'TCP_RECEIVED_BPS' r['TCP_RECEIVED_BPS'] 'ELAPSED_MS' r['ELAPSED_MS']
call touch path'/stop'
say 'LIVE TCP_INFO SUITE PASSED'
exit 0
check: use arg ok,label; if \ok then do; say 'FAIL' label; call touch path'/stop'; exit 1;end; say 'PASS' label;return
failed:
 say 'FAIL tcp live fixture syntax' condition('D');call touch path'/stop';exit 1
::routine waitFile
 use strict arg path
 do i=1 to 200
   if stream(path,'C','QUERY EXISTS')\=='' then return
   call SysSleep 0.02
 end
 raise syntax 93.900 array ('Fixture did not become ready' path)
::routine touch
 use strict arg path
 f=.Stream~new(path);f~charOut('1');f~close
::requires 'ShellSecurityCorrelation.cls'
