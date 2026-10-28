/* Candidate NotNotes storage adapter over the existing RexxSqlSqliteSession.
 * Not an independent SQLite driver or database authority.
 * REXX_PATH must include the accepted Rexx/SQL backend; it must be loaded by
 * the composition root. Failure is explicit (never switches mid-session).
 */
::class MiniNotesDatabaseSelector public
::method open class
  use strict arg root
  provider = value('MININOTES_DATABASE_PROVIDER',,'ENVIRONMENT')~strip~lower
  if provider = '' then provider = 'rexxsql-sqlite'
  select
    when provider = 'rexxsql-sqlite' then return .MiniNotesIndexedSqliteEngine~new(root)
    when provider = 'file-legacy' then return .FileDatabaseEngine~new(root)
    otherwise raise syntax 93.900 array('Unknown MiniNotes database provider:' provider)
  end

::class MiniNotesIndexedSqliteEngine public
::method init
  expose root session
  use strict arg root, injectedSession = .nil
  if root = '' then raise syntax 93.900 array('SQLite database root is required')
  if stream(root || '/database.yaml', 'c', 'query exists') \= '' then ,
    raise syntax 93.900 array('Legacy FileDatabaseEngine store detected; explicit backup/migration required:' root)
  if injectedSession == .nil then do
    if \.environment~hasIndex('REXXSQLSQLITESESSION') then ,
      raise syntax 93.900 array('Rexx/SQL provider not loaded. Require the qualified RexxSqlBackend.cls in the composition root; no fallback')
    sessionClass = .environment['REXXSQLSQLITESESSION']
    if \.RexxSqlFunctions~load then ,
      raise syntax 93.900 array('Missing qualified librexxsql.so / SQLite native library; no fallback')
    call SysMkDir root
    session = sessionClass~open(root || '/mininotes.sqlite')
  end
  else session = injectedSession

::attribute root get
::method providerId
  return 'rexxsql-sqlite'
::method session
  expose session
  return session

::method identifier private
  use strict arg name
  n = name~string
  if n = '' | verify(n,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_') \= 0 then ,
     raise syntax 93.900 array('Invalid internal SQL identifier:' n)
  if '0123456789'~pos(n~substr(1,1)) > 0 then ,
     raise syntax 93.900 array('SQL identifier cannot begin with a digit:' n)
  return '"' || n || '"'

::method result private
  use strict arg operation, queryResult
  out = .DatabaseResult~new(operation)
  if queryResult~status \= 'SUCCESS' then return out~fail(.Error~SQLERROR, queryResult~message)
  out~rows = queryResult~rows
  out~affectedRows = queryResult~rowCount
  out~accessPath = 'SQLITE_REXXSQL'
  return out

::method table
  expose session
  use strict arg name
  ignore = self~identifier(name)
  binds = .array~of(.array~of('TEXT',name))
  r = session~executeBound('SELECT name FROM sqlite_master WHERE type = ''table'' AND name = ? LIMIT 1', binds)
  if r~status \= 'SUCCESS' then raise syntax 93.900 array('Cannot inspect SQLite schema:' r~message)
  if r~rows~items > 0 then return .true
  return .nil

::method createTable
  expose session
  use strict arg name, columns, primaryKey = .nil
  if columns == .nil | columns~items = 0 then raise syntax 93.900 array('Empty schema')
  tableName = self~identifier(name)
  schema = ''
  do col over columns
    sqlType = col~type~translate
    select
      when sqlType = 'TEXT' | sqlType = 'VARCHAR' then sqlType = 'TEXT'
      when sqlType = 'DECIMAL' then sqlType = 'TEXT' /* exact lexical amount */
      when sqlType = 'INTEGER' then sqlType = 'INTEGER'
      otherwise raise syntax 93.900 array('Unqualified SQLite column type:' sqlType)
    end
    if schema \= '' then schema = schema || ', '
    schema = schema || self~identifier(col~name) || ' ' || sqlType
    if \col~nullable then schema = schema || ' NOT NULL'
  end
  if primaryKey \== .nil & primaryKey~items > 0 then do
    keys = ''
    do k over primaryKey
      if keys \= '' then keys = keys || ', '
      keys = keys || self~identifier(k)
    end
    schema = schema || ', PRIMARY KEY (' || keys || ')'
  end
  statement = 'CREATE TABLE ' || tableName || ' (' || schema || ')'
  return self~result(.DatabaseOperationType~CREATE_TABLE, session~execute(statement))

::method dropTable
  expose session
  use strict arg name
  return self~result(.DatabaseOperationType~DROP_TABLE, session~execute('DROP TABLE ' || self~identifier(name)))

::method selectAll
  expose session
  use strict arg name
  statement = 'SELECT * FROM ' || self~identifier(name)
  return self~result(.DatabaseOperationType~SELECT, session~execute(statement))

/* Bounded window for renderer-neutral list consumers. SQL rather than in-memory slice. */
::method selectWindow
  expose session
  use strict arg name, orderColumn, offset, count
  if \datatype(offset,'W') | \datatype(count,'W') | offset < 0 | count < 1 | count > 100 then ,
    raise syntax 93.900 array('Invalid bounded window; count must be 1..100')
  statement = 'SELECT * FROM ' || self~identifier(name) || ' ORDER BY ' || self~identifier(orderColumn) || -
    ' LIMIT ' || count || ' OFFSET ' || offset
  return self~result(.DatabaseOperationType~SELECT, session~execute(statement))

::method sqlValue private
  use strict arg value
  /* All current MiniNotes table columns are nonnullable. Rexx/SQL TEXT binds
   * turn empty strings into SQL NULL, so callers use COALESCE(?, '').
   * Future nullable columns require a separate explicit NULL binding contract. */
  if value == .nil then raise syntax 93.900 array('SQL NULL has no qualified MiniNotes column binding')
  return .array~of('TEXT',value~string)

::method insert
  expose session
  use strict arg name, values
  cols = ''; vals = ''; binds = .array~new
  do column over values~allIndexes
    if cols \= '' then do; cols = cols || ', '; vals = vals || ', '; end
    cols = cols || self~identifier(column)
    vals = vals || 'COALESCE(?, '''')'
    binds~append(self~sqlValue(values[column]))
  end
  statement = 'INSERT INTO ' || self~identifier(name) || ' (' || cols || ') VALUES (' || vals || ')'
  return self~result(.DatabaseOperationType~INSERT, session~executeBound(statement, binds))

::method updateWhereEquals
  expose session
  use strict arg name, keyColumn, wanted, assignments
  parts = ''; binds = .array~new
  do column over assignments~allIndexes
    if parts \= '' then parts = parts || ', '
    parts = parts || self~identifier(column) || ' = COALESCE(?, '''')'
    binds~append(self~sqlValue(assignments[column]))
  end
  if parts = '' then raise syntax 93.900 array('Empty UPDATE assignments')
  binds~append(self~sqlValue(wanted))
  statement = 'UPDATE ' || self~identifier(name) || ' SET ' || parts || ' WHERE ' || self~identifier(keyColumn) || ' = ?'
  return self~result(.DatabaseOperationType~UPDATE, session~executeBound(statement, binds))

::method beginSave
  expose session
  return self~result(.DatabaseOperationType~BEGIN, session~execute('BEGIN IMMEDIATE'))
::method finishSave
  expose session
  return self~result(.DatabaseOperationType~COMMIT, session~execute('COMMIT'))
::method rollbackSave
  expose session
  return self~result(.DatabaseOperationType~ROLLBACK, session~execute('ROLLBACK'))
::method close
  expose session
  return session~close

::requires 'vendor/nosql/NoSQLServer.cls'
