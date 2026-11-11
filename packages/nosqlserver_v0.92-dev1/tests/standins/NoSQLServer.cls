/* TEST-ONLY NoSQLServer compatibility stubs.
 * For isolated columnar planner qualification. NEVER load in deployment.
 * Real-stack qualification uses src/NoSQLServer.cls instead.
 */
::class Error public
::constant SUCCESS "SUCCESS"
::constant NOTFOUND "NOTFOUND"
::constant SQLUNSUPPORTED "SQLUNSUPPORTED"
::class DatabaseOperationType public
::constant SELECT "SELECT"
::class DatabaseResult public
::attribute status
::attribute error
::attribute message
::attribute operationType
::attribute rows
::attribute rowsScanned
::attribute affectedRows
::attribute accessPath
::method init
  use arg operationType = "SELECT"
  self~operationType=operationType
  self~rows=.array~new
  self~status=.Error~SUCCESS
  self~rowsScanned=0
  self~affectedRows=0
  self~accessPath="UNPLANNED"
::method fail
  use arg error,message
  self~status="NOTEXECUTED"
  self~error=error
  self~message=message
  return self
::class DatabaseColumn public
::attribute name
::attribute type
::method init
  use arg name,type = "TEXT"
  self~name=name
  self~type=type
::method compare
  use arg actual,operator,wanted
  if actual == .nil | wanted == .nil then return .false
  if self~type = "INTEGER" | self~type = "DECIMAL" then do
    select
      when operator = "=" then return actual = wanted
      when operator = ">" then return actual > wanted
      when operator = "<" then return actual < wanted
      otherwise return .false
    end
  end
  return actual == wanted
::class TableDefinition public
::attribute name
::attribute columns
::attribute columnNames
::attribute primaryKey
::method init
  use arg raw
  self~name=raw["name"]
  self~columns=.array~new
  self~columnNames=.array~new
  self~primaryKey=.array~new
  do item over raw["columns"]
    col=.DatabaseColumn~new(item["name"],item["type"])
    self~columns~append(col)
    self~columnNames~append(col~name)
    if item["primaryKey"] == .true then self~primaryKey~append(col~name)
  end
::method column
  use arg name
  do col over self~columns
    if col~name~caselessEquals(name) then return col
  end
  return .nil
::class DatabaseRow public
::attribute values
::attribute rawValues
::attribute typeNames
::method init
  use arg values = .nil,raw = .nil,types = .nil
  if values == .nil then values=.table~new
  if raw == .nil then raw=values~copy
  if types == .nil then types=.table~new
  self~values=values
  self~rawValues=raw
  self~typeNames=types
::method "[]"
  use arg name
  return self~values[name]
::class SQLPredicate public
::method evaluate abstract
::class SQLComparisonPredicate subclass SQLPredicate public
::attribute column
::attribute operator
::attribute value
::method init
  use arg name,op,value
  self~column=name
  self~operator=op
  self~value=value
::method evaluate
  use arg row,definition
  col=definition~column(self~column)
  return col~compare(row[col~name],self~operator,self~value)
::class SQLNullPredicate subclass SQLPredicate public
::attribute column
::attribute negate
::method init
  use arg name,negate = .false
  self~column=name
  self~negate=negate
::method evaluate
  use arg row,definition
  col=definition~column(self~column)
  if self~negate then return row[col~name] \== .nil
  return row[col~name] == .nil
::class SQLLogicalPredicate subclass SQLPredicate public
::attribute left
::attribute right
::attribute operator
::method init
  use arg op,left,right
  self~operator=op
  self~left=left
  self~right=right
::method evaluate
  use arg row,definition
  if self~operator="AND" then return self~left~evaluate(row,definition) & self~right~evaluate(row,definition)
  if self~operator="OR" then return self~left~evaluate(row,definition) | self~right~evaluate(row,definition)
  return .false
::class SQLNotPredicate subclass SQLPredicate public
::attribute child
::method init
  use arg child
  self~child=child
::method evaluate
  use arg row,definition
  return \self~child~evaluate(row,definition)
::class NullQueryPatternLog public
::method record
  return .true
::class NoSQLServerVersionInfo public
::method init
  use arg generation
