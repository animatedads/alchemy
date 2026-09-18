::class ObjectTableMapping public
::attribute name get
::attribute columns get
::attribute identityName get
::method init; expose name columns identityName; use strict arg nameArg; name=nameArg; columns=.array~new; identityName=''
::method column; expose columns; use strict arg sqlName,sqlType,methodName; columns~append(.array~of(sqlName,sqlType,methodName)); return self
::method identity; expose identityName; use strict arg nameArg; identityName=nameArg; return self

::class FakeObjectTableStorage public
::attribute collection get
::method init; expose collection; use strict arg c; collection=c

::class FakeObjectTable public
::attribute storage get
::attribute mapping get
::attribute isSnapshot get
::method init
  expose storage mapping isSnapshot
  use strict arg c,m,snapshotArg=.false
  storage=.FakeObjectTableStorage~new(c); mapping=m; isSnapshot=snapshotArg
::method rowCount; expose storage; return storage~collection~items
::method readRows; expose storage; return storage~collection

::class ObjectDatabaseEngine public
::method init; expose tables; tables=.directory~new
::method register; expose tables; use strict arg name,c,m; tables[name]=.FakeObjectTable~new(c,m,.false); return .true
::method registerSnapshot; expose tables; use strict arg name,c,m; tables[name]=.FakeObjectTable~new(c,m,.true); return .true
::method table; expose tables; use strict arg name; return tables[name]

::class NoSQLServerSQL public
::method init; expose engine; use strict arg e; engine=e
::method execute; expose engine; use strict arg sqlText; return .array~of('STUB',sqlText)
