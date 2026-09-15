/* Real-tape MTBOOT handoff through PXCT and DMOVE to paging activation. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_paging_boundary.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape=.SimhTapeReader~new~~mount(tapePath)
mtboot=.Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader=.KL10ExbLoader~new
mem=loader~load(mtboot)

/* First long loop, direct equivalent already proven instruction-by-instruction. */
src=octToDec("742000"); dst=octToDec("011000"); count=octToDec("036000")
do i=1 to count
  sw=mem~word(src); dw=mem~word(dst)
  mem~put(dst,sw); mem~put(src,dw)
  src=(src+1)//(2**18); dst=(dst+1)//(2**18)
end

cpu=.KL10CPU~new~~loadImage(mem,octToDec("771044"))
cpu~setAccumulator(0,0)
cpu~setAccumulator(1,octToDec("200612000000"))
cpu~setAccumulator(2,octToDec("250611000000"))
cpu~setAccumulator(3,octToDec("202612000000"))
cpu~setAccumulator(4,octToDec("350000000011"))
cpu~setAccumulator(5,octToDec("350000000012"))
cpu~setAccumulator(6,octToDec("367540000001"))
cpu~setAccumulator(7,octToDec("254010772044"))
cpu~setAccumulator(8,octToDec("000000777000"))
cpu~setAccumulator(9,octToDec("000000047000"))
cpu~setAccumulator(10,0); cpu~setAccumulator(11,0); cpu~setAccumulator(12,0); cpu~setAccumulator(13,0)
cpu~setAccumulator(14,octToDec("000000000047")); cpu~setAccumulator(15,octToDec("000000011000"))
/* Device state established by the real pre-loop path. */
cpu~pag~ioReset
ignored=cpu~pag~cono(octToDec("000047"),.nil)

/* Execute through the setup of the second AOBJN fill loop. */
do i=1 to 177
  tr=cpu~step
end
call eq cpu~pc,octToDec("771104"),"second fill loop entry"
call eq cpu~accumulator(1),octToDec("760000742000"),"second fill initial pointer"
call eq cpu~accumulator(3),octToDec("010000400000"),"second fill word"

/* Equivalent of 020000 repetitions of MOVEM/AOBJN. */
fillWord=cpu~accumulator(3)
base=octToDec("742000")
do i=0 to octToDec("017777")
  mem~put(base+i,fillWord)
end
cpu~setAccumulator(1,octToDec("000000762000"))
cpu~loadImage(mem,octToDec("771106"))

expected=.array~of("TLO","HRLI","DATAO","HRRZI","XCT","XCT","MOVE","XCT","TRO","CONI","ANDI","IOR","DMOVE","JRST")
do i=1 to expected~items
  tr=cpu~step
  call eq tr["mnemonic"],expected[i],"handoff step" i
end
call eq cpu~pc,1,"JRST enters live AC1"
call eq cpu~pag~currentAcBlock,0,"current AC block after DATAO"
call eq cpu~pag~previousAcBlock,6,"previous AC block after DATAO"
call eq cpu~pag~ubPtr,octToDec("765000"),"UBR after DATAO"
nextWord=cpu~fetch
next=cpu~decode(nextWord)
call eq next["mnemonic"],"CONO","paging boundary mnemonic"
call eq next["deviceName"],"PAG","paging boundary device"

tr=cpu~step
call eq tr["mnemonic"],"CONO","paging enable executes"
call eq cpu~pc,2,"CONO advances within AC window"
call eq cpu~pag~pageEnabled,1,"translation enabled"
call eq cpu~pag~tops20Page,1,"TOPS-20 paging selected"
call eq cpu~pag~ebPtr,octToDec("765000"),"executive base after CONO"

tr=cpu~step
call eq tr["mnemonic"],"JRST","AC2 panel switch"
call eq cpu~pc,octToDec("772350"),"JRST enters mapped MTBOOT"

proposal=cpu~preview
call eq proposal["instruction"],octToDec("202000772253"),"first mapped instruction"
call eq proposal["mnemonic"],"MOVEM","first mapped mnemonic"
call eq proposal["fetchSource"],"VIRTUAL","mapped fetch source"
mapping=proposal["translation"]
call eq mapping["sectionPointerAddress"],octToDec("765540"),"section pointer address"
call eq mapping["sectionPointer"],octToDec("220000000000"),"shared section pointer"
call eq mapping["sptBase"],octToDec("765760"),"SPT from physical AC block 6"
call eq mapping["pageMapPage"],octToDec("000766"),"section-zero page map"
call eq mapping["pagePointerAddress"],octToDec("766772"),"page pointer address"
call eq mapping["pagePointer"],octToDec("124000000772"),"page pointer"
call eq mapping["physical"],octToDec("772350"),"identity-mapped first fetch"

tape~close
say "KL10 MTBOOT paging-entry acceptance: PASS"
say "  CONO PAG,060765 enables authentic TOPS-20 section-zero translation"
say "  first mapped fetch walks EPT/SPT/page-map state to physical 772350"
exit 0

octToDec: procedure
 use arg t
 numeric digits 30
 n=0
 do i=1 to t~length
  n=n*8+t~substr(i,1)
 end
 return n
eq: procedure
 use arg a,e,l
 if a \= e then do
  say "FAIL:" l
  say "  expected:" e
  say "  actual:  " a
  exit 1
 end
 return
::requires "../KL10IPL.cls"
::requires "../MTBoot.cls"
