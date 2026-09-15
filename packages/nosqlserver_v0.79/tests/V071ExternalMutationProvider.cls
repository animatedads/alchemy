/*
 * Independent external-provider mutation probe for NoSQLServer v0.71.
 *
 * The provider knows only the relation object supplied by the host and the
 * host's DatabaseResult class object.  It deliberately does not require or
 * resolve NoSQLServer.cls itself.
 */
::class V071ExternalMutationProvider public
::attribute relation get
::attribute resultClass get
::attribute insertCalls get
::attribute insertManyCalls get
::attribute updateCalls get
::attribute deleteCalls get

::method init
  expose relation resultClass insertCalls insertManyCalls updateCalls deleteCalls
  use arg relationArg, resultClassArg
  relation = relationArg
  resultClass = resultClassArg
  insertCalls = 0
  insertManyCalls = 0
  updateCalls = 0
  deleteCalls = 0

::method table
  expose relation
  use arg tableName
  if relation == .nil then return .nil
  if relation~definition~name~caselessEquals(tableName) then return relation
  return .nil

::method insert
  expose resultClass insertCalls
  use arg tableName, values
  insertCalls += 1
  rs = resultClass~new('INSERT')
  rs~affectedRows = 1
  rs~message = 'EXTERNAL_INSERT'
  return rs

::method insertMany
  expose resultClass insertManyCalls
  use arg tableName, rows
  insertManyCalls += 1
  rs = resultClass~new('INSERT')
  rs~affectedRows = rows~items
  rs~message = 'EXTERNAL_INSERT_MANY'
  return rs

::method updateWhere
  expose resultClass updateCalls
  use arg tableName, predicate, assignments
  updateCalls += 1
  rs = resultClass~new('UPDATE')
  rs~affectedRows = 1
  rs~message = 'EXTERNAL_UPDATE'
  return rs

::method deleteWhere
  expose resultClass deleteCalls
  use arg tableName, predicate
  deleteCalls += 1
  rs = resultClass~new('DELETE')
  rs~affectedRows = 1
  rs~message = 'EXTERNAL_DELETE'
  return rs
