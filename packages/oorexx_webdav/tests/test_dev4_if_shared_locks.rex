/* dev4 If-header + shared lock qualification */
tokens=.array~new
tokens~append('opaquelocktoken:t1')
etag='"sha256:abc"'

call must .WebDavIfEvaluator~evaluate('(<opaquelocktoken:t1> ["sha256:abc"])','/x',etag,tokens),'token + etag list'
call must \.WebDavIfEvaluator~evaluate('(Not <opaquelocktoken:t1>)','/x',etag,tokens),'Not token fails'
call must .WebDavIfEvaluator~evaluate('(Not <opaquelocktoken:other>)','/x',etag,tokens),'Not absent token succeeds'
call must .WebDavIfEvaluator~evaluate('(<opaquelocktoken:other>) (<opaquelocktoken:t1>)','/x',etag,tokens),'OR lists'
call must .WebDavIfEvaluator~evaluate('<http://localhost/dav/x> (<opaquelocktoken:t1>)','/x',etag,tokens),'tagged request URI'

locks=.WebDavLockStore~new
s1=locks~lock('/x','0','one',3600,'','shared')
s2=locks~lock('/x','0','two',3600,'','shared')
call must s1<>.nil & s2<>.nil,'two shared locks coexist'
x=locks~lock('/x','0','exclusive',3600,'','exclusive')
call must x==.nil,'exclusive conflicts with shared'
call must locks~mutationAllowed('/x','(< '||s1~token||' >)','',''),'shared holder may mutate'
call must \locks~mutationAllowed('/x','(<opaquelocktoken:wrong>)','',''),'wrong token rejected'
call must locks~unlock('/x',s1~token),'unlock first shared'
call must locks~unlock('/x',s2~token),'unlock second shared'
x=locks~lock('/x','0','exclusive',3600,'','exclusive')
call must x<>.nil,'exclusive allowed after shared release'

say 'WEBDAV DEV4 IF/SHARED LOCKS: OK'
exit 0
must: procedure
  use arg c,l
  if \c then do; say 'FAIL:' l; exit 1; end
  return
::requires 'WebDavCore.cls'
