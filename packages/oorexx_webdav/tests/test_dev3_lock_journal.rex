journal='/tmp/webdav-dev3-locks-'||time('S')||'.txt'
call stream journal,'c','close'
address system 'rm -f' journal
s=.WebDavLockStore~new(journal)
r=s~lock('/persist','infinity','architect',3600)
call must r<>.nil,'persistent lock created'
token=r~token
s2=.WebDavLockStore~new(journal)
a=s2~applicable('/persist/child')
call eq a~items,1,'lock recovered from journal'
call eq a[1]~token,token,'token survives restart'
call must s2~unlock('/persist',token),'unlock recovered token'
s3=.WebDavLockStore~new(journal)
call eq s3~applicable('/persist')~items,0,'unlock persisted'
address system 'rm -f' journal
say 'WEBDAV DEV3 LOCK JOURNAL: OK'
exit 0
must: procedure; use arg c,l; if \c then do; say 'FAIL:' l; exit 1; end; return
eq: procedure; use arg a,e,l; if a<>e then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'WebDavCore.cls'
