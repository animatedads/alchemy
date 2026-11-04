::class StorageRef public
::attribute objectId get
::attribute digest get
::method init
 expose objectId digest
 use strict arg objectId,digest
::class StorageCatalogue public
::method init
 expose objects
 objects=.directory~new
::method put
 expose objects
 use strict arg object
 objects[object~ref~objectId]=object
::method get
 expose objects
 use strict arg id
 return objects~at(id)
::class StorageObject public
::attribute ref get
::attribute eas get
::method init
 expose ref eas
 use strict arg ref,name,bytes,mime
 eas=.StorageEASet~new
::class StorageEASet public
::method init
 expose table
 table=.directory~new
::method put
 expose table
 use strict arg ea
 table[ea~key]=ea
::method get
 expose table
 use strict arg key
 return table~at(key)
::class StorageEA public
::attribute value get
::attribute key get
::method init
 expose value key
 use strict arg namespace,name,value,type,provenance,authority
 key=namespace||'.'||name