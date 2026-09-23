/* Composition sketch: the HTTPS server is authoritative for TLS; WebDAV is
 * installed as an interceptor and therefore needs no HTTPS fork. */
cat=.StorageCatalogue~new
env=.StorageEnvironment~new('DAV-LIVE',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('DAV-LIVE',cat,env)
storage=.WebDavStorageAdapter~new(ns)
dav=.WebDavHttpsAdapter~new(storage,'/dav')
/* server=.HttpsServer~new(config)
 * dav~install(server)
 * server~start
 */
say 'WebDAV adapter ready at /dav'
::requires 'WebDavHttpsAdapter.cls'
