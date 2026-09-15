/*
 * First-party live Builder backend.
 * Owns one ObjectQueueManager shared by WireUIServer and the private browser
 * bridge.  It never launches a second queue manager and never delegates the
 * application runtime to Python or another HTTP server.
 */
parse source . . script
builderRoot=value("WUIB_BUILDER_ROOT",,"ENVIRONMENT")
if builderRoot="" then builderRoot=filespec("P",script)".."
studioPackage=value("WUIB_STUDIO_PACKAGE",,"ENVIRONMENT")
if studioPackage="" then studioPackage=builderRoot"/studio/wire_ui_builder_studio_v0.11.json"
bridgeToken=value("WUIB_BRIDGE_TOKEN",,"ENVIRONMENT")
pathToken=value("WUIB_PATH_TOKEN",,"ENVIRONMENT")
if bridgeToken="" | pathToken="" then do
  say "BUILDER_LIVE_ERROR missing launcher tokens"
  exit 2
end

gatewayPrincipal="wire-ui-builder-gateway"
applicationId="WIRE-UI-BUILDER"
sessionId="BUILDER-LIVE"
accessPointId="BUILDER-WEB"
moduleUrl="/wire-ui-js/src/index.js"
siteId="WIRE_UI_BUILDER_STUDIO"

signal on halt name shutdown

target=.WireUIBuilderLiveWorkspaceFixture~build
sources=.WireUISourceCatalogue~new("WIRE_UI_BUILDER_V082_LIVE_SOURCE")
r=sources~addTree(builderRoot,"*.cls",.true,"builder")
if \r~ok then do; say "BUILDER_LIVE_ERROR" r~code r~detail; exit 3; end
r=sources~seal
if \r~ok then do; say "BUILDER_LIVE_ERROR" r~code r~detail; exit 4; end

built=.WireUIBuilderRuntimeFactory~build(target,sources,applicationId,sessionId,accessPointId,studioPackage)
if \built~ok then do; say "BUILDER_LIVE_ERROR" built~code built~detail; exit 5; end
app=built~value

manager=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
topics=.QueueTopicFabric~new(manager)
server=.WireUIServer~new(manager,topics,"admin")
server~registerApplication(app)
binding=.WireUIWebAccessPointBinding~new(manager,server,app,gatewayPrincipal,bridgeToken,pathToken,moduleUrl,siteId,"127.0.0.1",0,"/wire-ui")
if \binding~startBridge then do; say "BUILDER_LIVE_ERROR bridge-start-failed"; exit 6; end

ready=.directory~new
ready["event"]="builder-backend-ready"
ready["bridgePort"]=binding~bridgeListener~port
ready["inQueue"]=binding~inQueue
ready["outQueue"]=binding~outQueue
ready["applicationId"]=app~applicationId
ready["sessionId"]=app~sessionId
ready["accessPointId"]=app~accessPointId
ready["moduleUrl"]=moduleUrl
ready["siteId"]=siteId
ready["targetProjectId"]=target~projectId
ready["targetRevision"]=target~revision
ready["targetDraftCount"]=target~drafts~items
say .JSON~toJSON(ready)

call rxfuncadd "SysLoadFuncs","rxunixsys","SysLoadFuncs"
call SysLoadFuncs

do forever
  depth=manager~depth(binding~inQueue,"admin")
  if depth~ok & depth~value["ready"]>0 then do
    result=server~receiveFromAccessPoint(accessPointId,gatewayPrincipal)
    if \result~ok then say "BUILDER_LIVE_ERROR receive" result~code result~detail
    outbound=app~drainOutbound
    do message over outbound
      enqueued=server~enqueueToAccessPoint(accessPointId,message)
      if \enqueued~ok then do
        say "BUILDER_LIVE_ERROR outbound" enqueued~code enqueued~detail
        signal shutdown
      end
    end
  end
  else call SysSleep 0.01
end

shutdown:
  signal off halt
  if symbol("binding")="VAR" then ignore=binding~stopBridge
  exit 0

::requires "json.cls"
::requires "WireUIBuilderApplication.cls"
::requires "WireUIBuilderLiveWorkspaceFixture.cls"
::requires "WireUIServer.cls"
::requires "WireUIWebAccessPointBinding.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"
