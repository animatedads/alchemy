/* RH20 ATTN INT ENA (000040) regression from the authenticated MTBOOT refusal. */
numeric digits 30
parse arg checkpoint, roundtrip
if checkpoint="" then do
  say "usage: rexx test_rh20_attention_cono_state.rex refusal.state [roundtrip.state]"
  exit 2
end
if roundtrip="" then roundtrip="rh20-attention-roundtrip.state"

call exactHistorical checkpoint
call isolatedAndPersistence checkpoint, roundtrip
say "PASS test_rh20_attention_cono_state"
exit 0

exactHistorical: procedure
  use arg path
  cpu=.KL10State~new~load(path)
  rh=cpu~rh20(oct("540"))
  tape=rh~unit(0)
  dte=cpu~ioBus~device(oct("200"))
  before=.KL10State~new~freeze(cpu)~memoryDigest
  beforeRh=rh~state
  beforeTape=tape~state
  beforeDte=dte~state
  beforePag=cpu~pag~string
  beforeApr=cpu~apr~string
  call eq cpu~accumulator(1),oct("000000,,000400"),"historical AC1"
  tr=cpu~step
  call eq tr["ioCondition"],oct("000450"),"effective CONO condition"
  call eq cpu~pc,oct("774337"),"historical PC"
  call eq cpu~instructionCount,1233106,"historical ICOUNT"
  after=rh~state
  call eq after["statusWord"],beforeRh["statusWord"],"status"
  call eq after["preparation"],beforeRh["preparation"],"preparation"
  call eq after["resetCount"],beforeRh["resetCount"],"reset count"
  call eq after["massbusEnabled"],1,"Massbus enable"
  call eq after["channelResetCount"],beforeRh["channelResetCount"],"channel reset count"
  call eq after["sbar"],beforeRh["sbar"],"SBAR"
  call eq after["stcr"],beforeRh["stcr"],"STCR"
  call eq after["pbar"],beforeRh["pbar"],"PBAR"
  call eq after["ptcr"],beforeRh["ptcr"],"PTCR"
  call eq after["ivect"],beforeRh["ivect"],"IVIR"
  call eq after["attentionInterruptEnabled"],1,"ATTN INT ENA"
  call eq tape~position,855144,"tape position"
  call eq tape~state["readCount"],beforeTape["readCount"],"tape read count"
  call eq dte~state["serviceCount"],beforeDte["serviceCount"],"DTE service count"
  call eq dte~state["rxHex"],"","DTE RX"
  call eq cpu~pag~string,beforePag,"PAG"
  call eq cpu~apr~string,beforeApr,"APR"
  call eq .KL10State~new~freeze(cpu)~memoryDigest,before,"memory"
  return

isolatedAndPersistence: procedure
  use arg path,roundtrip
  cpu=.KL10State~new~load(path)
  cpu~setAccumulator(1,0)
  translated=cpu~memory~translate(cpu~pc,0,1)
  physical=translated["physical"]
  cpu~memory~physicalPut(physical,oct("754201,,000040"))
  rh=cpu~rh20(oct("540"))
  call eq rh~state["attentionInterruptEnabled"],0,"isolated initial enable"
  ignored=cpu~step
  call eq rh~state["attentionInterruptEnabled"],1,"isolated 000040 sets enable"

  /* A later CONO lacking the set control preserves the documented latch. */
  translated=cpu~memory~translate(cpu~pc,0,1)
  cpu~memory~physicalPut(translated["physical"],oct("754201,,000400"))
  ignored=cpu~step
  call eq rh~state["attentionInterruptEnabled"],1,"later CONO preserves enable"

  meta=.directory~new
  meta["checkpoint"]="test.rh20-attention-roundtrip"
  ignored=.KL10State~new~save(cpu,roundtrip,meta)
  loaded=.KL10State~new
  reloaded=loaded~load(roundtrip)
  call eq reloaded~rh20(oct("540"))~state["attentionInterruptEnabled"],1,"freeze/load enable"

  inp=.stream~new(roundtrip)~~open("READ")
  bad=roundtrip || ".missing"
  out=.stream~new(bad)~~open("WRITE REPLACE")
  removed=0
  do while inp~lines > 0
    line=inp~linein
    if \removed & left(line,5)="RH20 " then do
      line=changestr(" attentionInterruptEnabled=1","",line)
      removed=1
    end
    out~lineout(line)
  end
  inp~close
  out~close
  call eq removed,1,"new RH20 field located"
  call eq mustReject(bad),1,"missing new RH20 field rejected"
  call sysFileDelete roundtrip
  call sysFileDelete bad
  return

mustReject: procedure
  use arg path
  signal on syntax name rejected
  ignored=.KL10State~new~load(path)
  signal off syntax
  return 0
rejected:
  signal off syntax
  return 1

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
