numeric digits 30
pc=oct("100")
mem=.KL10Memory~new; mem~mapZeroPage(0,0)
mem~put(pc,io(0,0,1)) /* BLKI APR,1 -> AC1 */
cpu=.KL10CPU~new~~loadImage(mem,pc)
tr=cpu~step
call eq tr["mnemonic"],"BLKI","decode"
call eq tr["ioAction"],"APR_APRID","action"
call eq cpu~accumulator(1),oct("400500002001"),"base KL10 APRID"
say "PASS test_cpu_aprid"; exit
io: procedure
 use arg device,fn,y
 return 7*(2**33)+(device%4)*(2**26)+fn*(2**23)+y
oct: procedure; use arg t; t=changestr(",",t,""); n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure; use arg a,e,l; if a\=e then do; say "FAIL" l e a; exit 1; end; return
::requires "../KL10IPL.cls"
