/* Ordinary XCT current-context I/O routing. */
numeric digits 30
pc=oct("000100")
dest=oct("000020")
mem=.KL10Memory~new
ignored=mem~mapZeroPage(0,0)
mem~put(pc,makeInstruction(oct("256"),0,0,0,3))
cpu=.KL10CPU~new~~loadImage(mem,pc)
cpu~pag~ioReset

/* AC3 = CONI PAG,dest */
ioWord=makeIo(2,5,0,0,dest) /* encoded device field 2 => architectural 010 */
cpu~setAccumulator(3,ioWord)

proposal=cpu~preview
call eq proposal["mnemonic"],"XCT","outer proposal"
call eq proposal["xctMnemonic"],"CONI","nested mnemonic"
call eq proposal["xctDeviceName"],"PAG","nested device"
call eq proposal["xctIoFunction"],5,"nested function"

tr=cpu~step
call eq tr["mnemonic"],"XCT","outer execution"
call eq tr["xctReferenceKind"],"CURRENT_IO","current-context route"
call eq tr["xctDeviceName"],"PAG","trace device"
call eq mem~word(dest),0,"CONI PAG reset status stored"
call eq cpu~pc,pc+1,"XCT sequencing"
say "PASS test_cpu_xct_io"
exit 0

makeInstruction: procedure
 use arg opcode,ac,ind,index,address
 return opcode*(2**27)+ac*(2**23)+ind*(2**22)+index*(2**18)+address
makeIo: procedure
 use arg deviceField,fn,ind,index,address
 return 7*(2**33)+deviceField*(2**26)+fn*(2**23)+ind*(2**22)+index*(2**18)+address
oct: procedure
 use arg t
 n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
