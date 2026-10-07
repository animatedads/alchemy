/* RFC 6238 Appendix B */
times=.array~of(59,1111111109,1111111111,1234567890,2000000000,20000000000)
sha1=.array~of("94287082","07081804","14050471","89005924","69279037","65353130")
sha256=.array~of("46119246","68084774","67062674","91819424","90698825","77737706")
sha512=.array~of("90693936","25091201","99943326","93441116","38618901","47863826")
c1=.TotpCredential~new("sha1",.AuthBase32~encode("12345678901234567890"),"","","SHA1",8,30)
c2=.TotpCredential~new("sha256",.AuthBase32~encode("12345678901234567890123456789012"),"","","SHA256",8,30)
c3=.TotpCredential~new("sha512",.AuthBase32~encode("1234567890123456789012345678901234567890123456789012345678901234"),"","","SHA512",8,30)
do i=1 to times~items
 call eq .TotpGenerator~code(c1,times[i])~value,sha1[i],"sha1 "||times[i]
 call eq .TotpGenerator~code(c2,times[i])~value,sha256[i],"sha256 "||times[i]
 call eq .TotpGenerator~code(c3,times[i])~value,sha512[i],"sha512 "||times[i]
end
say "PASS RFC6238 TOTP"
exit 0
eq: procedure
 use arg a,e,l
 if a\==e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "TotpAuthenticator.cls"
