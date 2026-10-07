call eq .AuthBase64Url~encode(""), "", "b64 empty"
call eq .AuthBase64Url~encode("f"), "Zg", "b64 f"
call eq .AuthBase64Url~encode("fo"), "Zm8", "b64 fo"
call eq .AuthBase64Url~encode("foo"), "Zm9v", "b64 foo"
call eq .AuthBase64Url~decode("SGVsbG8td29ybGQ"), "Hello-world", "b64 decode"
call eq .AuthBase32~encode("foo"), "MZXW6", "base32 foo"
call eq .AuthBase32~decode("MZXW6"), "foo", "base32 decode"
call eq .AuthUriCodec~decodeComponent(.AuthUriCodec~encodeComponent("A b+c/@")), "A b+c/@", "uri roundtrip"
say "PASS codec"
exit 0
eq: procedure
 use arg a,e,l
 if a\==e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "AuthCodec.cls"
