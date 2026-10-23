journal='/tmp/webdav-dev5-props-'||time('S')||'.txt'
address system 'rm -f' journal

p=.WebDavDurableCollectionPropertyStore~new(journal)
call must p~set('/docs','urn:test','owner','architect'),'set property'
call must p~set('/docs','urn:test','note','alpha beta'),'set second'
call eq p~all('/docs')~items,2,'two properties'

p2=.WebDavDurableCollectionPropertyStore~new(journal)
call eq p2~all('/docs')~items,2,'properties survive restart'

p2~moveTree('/docs','/archive',.false)
p3=.WebDavDurableCollectionPropertyStore~new(journal)
call eq p3~all('/docs')~items,0,'source metadata moved'
call eq p3~all('/archive')~items,2,'destination metadata survives restart'

call must p3~remove('/archive','urn:test','note'),'remove persistent property'
p4=.WebDavDurableCollectionPropertyStore~new(journal)
call eq p4~all('/archive')~items,1,'removal survives restart'

address system 'rm -f' journal
say 'WEBDAV DEV5 DURABLE COLLECTION PROPERTIES: OK'
exit 0
must: procedure; use arg c,l; if \c then do; say 'FAIL:' l; exit 1; end; return
eq: procedure; use arg a,e,l; if a<>e then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'WebDavDurableProperties.cls'
