/* Live qualification fixture for HTTPS v0.4.8 + WebDAV dev6.
 * This is a test server only. It does not install or modify a host service.
 */
parse arg certificate privateKey port stagingDirectory
if certificate='' | privateKey='' | port='' | stagingDirectory='' then do
  say 'usage: rexx live_webdav_streaming_server.rex CERT KEY PORT STAGING_DIR'
  exit 2
end
if \datatype(port,'W') then exit 2

cat=.StorageCatalogue~new
env=.StorageEnvironment~new('DAV-STREAM-LIVE',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('DAV-STREAM-LIVE',cat,env)
storage=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new)
call storage~makeCollection('/data')

config=.HttpsServerConfig~new
config~certificateFile=certificate
config~privateKeyFile=privateKey
config~bindAddress='127.0.0.1'
config~port=port
config~bridgeDirectory=value('HTTPS_BRIDGE_DIR',,'ENVIRONMENT')
config~maxBodyBytes=1048576
config~maxStreamingBodyBytes=67108864
config~streamChunkSize=65536
config~connectionWorkers=4
config~maxPendingConnections=16

server=.HttpsServer~new(config)
dav=.WebDavHttpsStreamingAdapter~new(storage,'/dav',stagingDirectory,65536)
dav~install(server)
server~serve

::requires 'https_server.cls'
::requires 'WebDavStreaming.cls'
