/* Native zlib cold-checkpoint path; precision regression from msqlshim v0.21.1. */
numeric digits 30
payload=""
do i=0 to 4999
  payload=payload || d2c((i*37+11)//256)
end
z=.KL10Deflate~compressZlib(payload)
call eq c2x(z~right(4)),"7247BAAC","external Adler-32 oracle"
call eq .KL10Deflate~decompressZlib(z),payload,"native zlib roundtrip"

path="/tmp/kl10-compressed-state.z"
mem=.KL10Memory~new
mem~mapZeroPage(0,0)
mem~put(oct("100"),oct("201040000123"))
cpu=.KL10CPU~new~~loadImage(mem,oct("100"))
cpu~setAccumulator(1,oct("765432123456"))
state=.KL10State~new
state~saveCompressed(cpu,path)
restored=.KL10State~new~loadCompressed(path)
call eq restored~pc,cpu~pc,"compressed restored PC"
call eq restored~accumulator(1),cpu~accumulator(1),"compressed restored AC1"
call eq restored~memory~physicalWord(oct("100")),cpu~memory~physicalWord(oct("100")),"compressed restored memory"
call sysFileDelete path
say "PASS test_state_compressed_freeze"
exit 0

oct: procedure
 use arg t
 t=changestr(",",t,""); n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l
 if a \== e then do; say "FAIL" l "expected=" e "actual=" a; exit 1; end
 return
::requires "../KL10IPL.cls"
