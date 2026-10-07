cred=.TotpCredential~new("work",.AuthBase32~encode("12345678901234567890"),"Example","alice@example.com","SHA1",6,30)
uri=.OtpAuthUri~fromCredential(cred)
parsed=.OtpAuthUri~parse(uri,"parsed")
call ok parsed~issuer="Example", "issuer roundtrip"
call ok parsed~accountName="alice@example.com", "account roundtrip"
call ok parsed~secretBase32=cred~secretBase32, "secret roundtrip"
vault=.InMemoryAuthenticatorVault~new
auth=.Authenticator~new(vault)
ignore=auth~enroll(.AuthenticatorEnrollment~new(cred))
/* 59 is one second before rollover; request at least 12 seconds, so return next step. */
c=auth~codeWhenUsable("work",59,12)
call ok c~counter=2, "next counter selected"
call ok c~validFrom=60, "next validFrom"
guard=.TotpReplayGuard~new
v=.TotpVerifier~verify(cred,c~value,60,1,guard)
call ok v~ok, "code verifies"
v2=.TotpVerifier~verify(cred,c~value,60,1,guard)
call ok \v2~ok & v2~code="REPLAY", "replay rejected"
say "PASS authenticator"
exit 0
ok: procedure
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
::requires "TotpAuthenticator.cls"
