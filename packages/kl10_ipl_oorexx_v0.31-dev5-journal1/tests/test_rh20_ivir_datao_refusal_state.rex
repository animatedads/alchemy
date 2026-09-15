/* Exact RH20 IVIR DATAO regression from the authenticated MTBOOT refusal. */
numeric digits 30
parse arg checkpoint
if checkpoint="" then do
  say "usage: rexx test_rh20_ivir_datao_refusal_state.rex refusal.state"
  exit 2
end

call exactHistorical checkpoint
call isolatedVector checkpoint

say "PASS test_rh20_ivir_datao_refusal_state"
say "  AC1 744000,,000000 is delivered through E=1 to RH20 IVIR RS=74 with LR=1"
say "  IVIR stores DATAO bits 27..35 and has no controller, channel, interrupt, or tape side effect"
exit 0

exactHistorical: procedure
  use arg path
  cpu=.KL10State~new~load(path)
  rh=cpu~rh20(oct("540"))
  tape=rh~unit(0)
  dte=cpu~ioBus~device(oct("200"))
  source=cpu~accumulator(1)
  call eq source,oct("744000,,000000"),"historical AC1"
  call eq cpu~preview["effectiveAddress"],1,"historical DATAO E"
  beforeMem=.KL10State~new~freeze(cpu)~memoryDigest
  beforeRh=rh~state
  beforeExt=rh~extendedState
  beforeTape=tape~state
  beforeDte=dte~state
  beforePag=cpu~pag~string
  beforeApr=cpu~apr~string
  tr=cpu~step
  call eq tr["ioSource"],1,"historical DATAO source AC1"
  call eq tr["ioData"],source,"historical DATAO payload"
  call eq tr["ioData"],oct("744000,,000000"),"historical DATAO exact word"
  call eq tr["ioData"]% (2**30),oct("74"),"historical RS"
  call eq tr["ioData"]% (2**29)//2,1,"historical LR"
  call eq tr["ioData"]% (2**18)//8,0,"historical DS"
  call eq tr["ioData"]//(2**16),0,"historical external data"
  call eq cpu~pc,oct("774445"),"historical PC"
  call eq cpu~instructionCount,1233096,"historical ICOUNT"
  afterRh=rh~state
  afterExt=rh~extendedState
  call eq afterRh["statusWord"],beforeRh["statusWord"],"historical status"
  call eq afterRh["preparation"],source,"historical preparation"
  call eq afterRh["resetCount"],beforeRh["resetCount"],"historical reset count"
  call eq afterRh["massbusEnabled"],beforeRh["massbusEnabled"],"historical Massbus enable"
  call eq afterRh["channelResetCount"],beforeRh["channelResetCount"],"historical channel reset count"
  call eq afterExt["sbar"],beforeExt["sbar"],"historical SBAR"
  call eq afterExt["stcr"],beforeExt["stcr"],"historical STCR"
  call eq afterExt["pbar"],beforeExt["pbar"],"historical PBAR"
  call eq afterExt["ptcr"],beforeExt["ptcr"],"historical PTCR"
  call eq afterExt["ivect"],0,"historical IVIR"
  call eq tape~position,855144,"historical tape position"
  call eq tape~state["readCount"],beforeTape["readCount"],"historical tape reads"
  call eq dte~state["serviceCount"],beforeDte["serviceCount"],"historical DTE service count"
  call eq dte~state["rxHex"],"","historical DTE RX"
  call eq cpu~pag~string,beforePag,"historical PAG"
  call eq cpu~apr~string,beforeApr,"historical APR"
  call eq .KL10State~new~freeze(cpu)~memoryDigest,beforeMem,"historical memory"
  return

isolatedVector: procedure
  use arg path
  cpu=.KL10State~new~load(path)
  vector=oct("000052")
  payload=oct("74")*(2**30)+(2**29)+vector
  cpu~setAccumulator(1,payload)
  rh=cpu~rh20(oct("540"))
  tr=cpu~step
  call eq tr["ioData"],payload,"isolated IVIR payload"
  call eq rh~extendedState["ivect"],vector,"isolated IVIR vector"
  call eq rh~state["statusWord"],0,"isolated IVIR status"
  call eq cpu~pc,oct("774445"),"isolated IVIR PC"
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
