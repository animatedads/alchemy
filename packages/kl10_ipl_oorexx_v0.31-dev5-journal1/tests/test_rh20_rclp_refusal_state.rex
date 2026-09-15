/* Exact RH20 RCLP regression from the authenticated post-[OK] refusal. */
numeric digits 30
parse arg checkpoint
if checkpoint="" then do
  say "usage: rexx test_rh20_rclp_refusal_state.rex refusal.state"
  exit 2
end

call combined checkpoint
call individualRclp checkpoint

say "PASS test_rh20_rclp_refusal_state"
say "  CONO RH20,005610 admits CLR RAE, XFER ERR CLR, MASSBUS ENA, RCLP, and reserved 000010"
say "  RCLP restores PBAR/PTCR from SBAR/STCR, clears channel status, preserves controller/media state"
exit 0

combined: procedure
  use arg path
  cpu=.KL10State~new~load(path)
  rh=cpu~rh20(oct("540"))
  tape=rh~unit(0)
  dte=cpu~ioBus~device(oct("200"))
  beforeMem=.KL10State~new~freeze(cpu)~memoryDigest
  beforePag=cpu~pag~string
  beforeApr=cpu~apr~string
  beforeDte=dte~state
  beforeTape=tape~state
  tr=cpu~step
  call eq cpu~pc,oct("774331"),"combined PC"
  call eq cpu~instructionCount,1233089,"combined ICOUNT"
  call eq tr["ioAction"],"RH20_CLR_RAE+CLR_XFER_ERR+MASSBUS_ENA+RCLP+RESERVED_000010","combined action"
  after=rh~state
  ext=rh~extendedState
  call eq after["statusWord"],0,"combined status"
  call eq after["preparation"],0,"combined preparation"
  call eq after["resetCount"],5,"combined controller reset count"
  call eq after["massbusEnabled"],1,"combined Massbus enable"
  call eq after["channelResetCount"],1,"combined channel reset count"
  call eq ext["sbar"],0,"combined SBAR"
  call eq ext["stcr"],268500985,"combined STCR"
  call eq ext["pbar"],0,"combined PBAR"
  call eq ext["ptcr"],268500985,"combined PTCR"
  call eq ext["ivect"],0,"combined IVECT"
  call eq tape~position,855144,"combined tape position"
  call eq tape~state["readCount"],beforeTape["readCount"],"combined tape reads"
  call eq dte~state["txHex"],beforeDte["txHex"],"combined DTE tx"
  call eq dte~state["rxHex"],beforeDte["rxHex"],"combined DTE rx"
  call eq dte~state["serviceCount"],beforeDte["serviceCount"],"combined DTE service count"
  call eq cpu~pag~string,beforePag,"combined PAG"
  call eq cpu~apr~string,beforeApr,"combined APR"
  call eq .KL10State~new~freeze(cpu)~memoryDigest,beforeMem,"combined memory"
  return

individualRclp: procedure
  use arg path
  cpu=.KL10State~new~load(path)
  rh=cpu~rh20(oct("540"))
  s=.directory~new
  s["statusWord"]=oct("000130")
  s["preparation"]=123
  s["resetCount"]=5
  s["massbusEnabled"]=1
  s["channelResetCount"]=0
  ignored=rh~restoreState(s)
  e=.directory~new
  e["sbar"]=oct("000777")
  e["stcr"]=oct("001234")
  e["pbar"]=oct("000111")
  e["ptcr"]=oct("000222")
  e["ivect"]=oct("000333")
  ignored=rh~restoreExtendedState(e)
  call patchCondition cpu,oct("000200")
  ignored=cpu~step
  after=rh~state
  ext=rh~extendedState
  call eq after["statusWord"],0,"individual RCLP status"
  call eq after["preparation"],123,"individual RCLP preparation"
  call eq after["resetCount"],5,"individual RCLP reset count"
  call eq after["massbusEnabled"],1,"individual RCLP Massbus enable"
  call eq after["channelResetCount"],1,"individual RCLP channel count"
  call eq ext["pbar"],oct("000777"),"individual RCLP PBAR"
  call eq ext["ptcr"],oct("001234"),"individual RCLP PTCR"
  call eq ext["sbar"],oct("000777"),"individual RCLP SBAR"
  call eq ext["stcr"],oct("001234"),"individual RCLP STCR"
  return

patchCondition: procedure
  use arg cpu,condition
  tr=cpu~memory~translate(cpu~pc,0,1)
  old=cpu~memory~physicalWord(tr["physical"])
  base=old-(old//(2**18))
  cpu~memory~physicalPut(tr["physical"],base+condition)
  return

eq: procedure
  use arg actual,expected,label
  if actual\=expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

oct: procedure
  use arg text
  text=changestr(",",text,"")
  n=0
  do i=1 to length(text)
    n=n*8+substr(text,i,1)
  end
  return n

::requires "../KL10Execution.cls"
