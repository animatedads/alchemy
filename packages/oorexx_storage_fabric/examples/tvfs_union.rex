cat=.StorageCatalogue~new
modern=.StorageObject~new(.StorageRef~new("obj:modern-common"),"COMMON.CMD",1,"text/plain")
legacy=.StorageObject~new(.StorageRef~new("obj:legacy-common"),"COMMON.CMD",1,"text/plain")
oldOnly=.StorageObject~new(.StorageRef~new("obj:legacy-only"),"OLD.CMD",1,"text/plain")
cat~put(modern); cat~put(legacy); cat~put(oldOnly)

env=.StorageEnvironment~new("LIVE",.StorageEnvironmentKind~LIVE,"",0,1,.StorageWritePolicy~DIRECT)
newTree=.StorageNamespace~new("new-tree",cat,env)
oldTree=.StorageNamespace~new("old-tree",cat,env)
newTree~bind("/new/COMMON.CMD",modern~ref,.StorageWritePolicy~READ_ONLY)
oldTree~bind("/old/COMMON.CMD",legacy~ref,.StorageWritePolicy~READ_ONLY)
oldTree~bind("/old/OLD.CMD",oldOnly~ref,.StorageWritePolicy~READ_ONLY)

view=.StorageUnionView~new("commands")
view~addLayer(newTree,"/new","new")
view~addLayer(oldTree,"/old","old")

say "COMMON.CMD ->" view~resolve("/COMMON.CMD")~entry~ref~objectId
say "OLD.CMD    ->" view~resolve("/OLD.CMD")~entry~ref~objectId
say "visible entries:"
do e over view~list("/")
  say " " e~path "->" e~ref~objectId "via" e~origin
end
exit 0

::requires "src/StorageFabric.cls"
