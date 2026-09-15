numeric digits 9
/* Methods must internally raise precision; caller precision is deliberately 9. */
call eq .KL10Word~allOnes,68719476735,"all ones"
call eq .KL10Word~fromOctal("777777,,777777"),68719476735,"octal all ones"
call eq .KL10Word~fromOctal("400500,,002001"),34443625473,"APRID word"
call eq .KL10Word~bit(0),34359738368,"bit zero"
call eq .KL10Word~bit(35),1,"bit 35"
say "PASS test_kl10_word"
exit
eq: procedure
 use arg a,e,l
 numeric digits 30
 if a\=e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
