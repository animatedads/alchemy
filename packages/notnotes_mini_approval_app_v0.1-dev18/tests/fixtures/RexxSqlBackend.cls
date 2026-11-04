/* Intentionally fake SQL provider for adapter contract checks only.
 * NEVER include this fixture on the product REXX_PATH. */
::class RexxSqlSqliteSession public
::method open class
  use arg path
  return self~new
::attribute lastSql
::attribute lastBinds
::method execute
  use arg sql
  self~lastSql = sql
  self~lastBinds = .array~new
  return .MockSqlResult~new
::method executeBound
  use arg sql, binds
  self~lastSql = sql
  self~lastBinds = binds
  return .MockSqlResult~new
::class MockSqlResult public
::method status
  return "SUCCESS"
::method rows
  return .array~new
