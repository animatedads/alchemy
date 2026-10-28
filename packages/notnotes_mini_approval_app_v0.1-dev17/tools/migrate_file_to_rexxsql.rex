/* Migrate a SNAPSHOT COPY of a legacy Mini NotNotes file engine into
 * a new SQLite file, using the existing Rexx/SQL adapter.
 *
 * Usage: MININOTES_DB_BACKEND=rexxsql-sqlite rexx tools/migrate_file_to_rexxsql.rex
 *          <snapshot-file-store-root> <new-destination.sqlite>
 *
 * Never invoke this directly on a live/authoritative file store: opening a
 * FileDatabaseEngine may perform journal recovery.
 */
parse arg sourceRoot destination extra
if sourceRoot = "" | destination = "" | extra \= "" then do
  say "Usage: rexx tools/migrate_file_to_rexxsql.rex snapshot-root new.sqlite"
  exit 64
end
if sourceRoot == destination then do
  say "MIGRATION_REFUSED: source and destination must differ"
  exit 64
end
if value("MININOTES_DB_BACKEND",, "ENVIRONMENT")~lower~strip \= "rexxsql-sqlite" then do
  say "MIGRATION_REFUSED: MININOTES_DB_BACKEND must explicitly equal rexxsql-sqlite"
  exit 64
end
if stream(sourceRoot || "/database.yaml", "c", "query exists") = "" then do
  say "MIGRATION_REFUSED: source snapshot lacks database.yaml"
  exit 66
end
if stream(destination, "c", "query exists") \= "" then do
  say "MIGRATION_REFUSED: target already exists; will never overwrite"
  exit 73
end
signal on syntax name failed
source = .FileDatabaseEngine~new(sourceRoot)
targetPersistence = .MiniNotesPersistence~new(destination)
destinationEngine = targetPersistence~database
if destinationEngine~backendId \= "rexxsql-sqlite" then -
  raise syntax 93.900 array("SQLite adapter was not selected")
tables = .Array~of("formats", "reports", "relationships", "subviews", -
                   "documents", "temporal_evidence")
/* Preserve every column/field value. Refuse SQL NULL from legacy input because
 * Rexx/SQL's current textual result API cannot round-trip NULL distinctly
 * from empty text; accepting would be silent loss. */
inTransaction = .false
r = destinationEngine~beginTransaction
call requireSql r, "BEGIN"
inTransaction = .true
total = 0
do tableName over tables
  result = source~selectAll(tableName)
  call requireSql result, "legacy read" tableName
  count = 0
  do sourceRow over result~rows
    copy = .Table~new
    do column over sourceRow~allIndexes
      value = sourceRow[column]
      if value == .nil then -
        raise syntax 93.900 array("Unsupported legacy NULL:" tableName column)
      copy[column] = value
    end
    inserted = destinationEngine~insert(tableName, copy)
    call requireSql inserted, "insert" tableName
    count += 1
  end
  /* Verify each exact column, not merely row counts or hashes. With an
   * insertion-only empty destination, SQLite rowid order is insertion order. */
  cursor = 0
  index = 1
  do while index <= count
    page = destinationEngine~selectPageAfter(tableName, cursor, 100)
    call requireSql page, "verification page" tableName
    if page~rows~items = 0 then -
      raise syntax 93.900 array("Missing SQLite records:" tableName index)
    do outputRow over page~rows
      if index > count then -
        raise syntax 93.900 array("Extra SQLite row:" tableName)
      sourceRow = result~rows[index]
      do column over sourceRow~allIndexes
        before = sourceRow[column]
        after = outputRow[column]
        if after == .nil then -
          raise syntax 93.900 array("Unexpected SQLite NULL:" tableName column)
        if before~string \== after~string then -
          raise syntax 93.900 array("Byte mismatch:" tableName column "row" index)
      end
      cursor = outputRow["NN_CURSOR"]
      index += 1
    end
  end
  finalPage = destinationEngine~selectPageAfter(tableName, cursor, 1)
  call requireSql finalPage, "extra-row check" tableName
  if finalPage~rows~items > 0 then -
    raise syntax 93.900 array("Extra rows in SQLite:" tableName)
  say "MIGRATION_VERIFIED" tableName count
  total += count
end
r = destinationEngine~commitTransaction
call requireSql r, "COMMIT"
inTransaction = .false
ignore = destinationEngine~close
say "MIGRATION_VERIFIED_PASS rows=" || total "destination=" || destination
exit 0
failed:
  error = condition("O")
  if symbol("INTRANSACTION") = "VAR" then do
    if inTransaction then ignore = destinationEngine~rollbackTransaction
  end
  say "MIGRATION_FAILED (target NOT accepted; source snapshot unchanged):" error["MESSAGE"]
  exit 1

requireSql:
  use arg result, context, tableName = ""
  if result~status \= "SUCCESS" then -
    raise syntax 93.900 array(context tableName result~status result~message)
  return
::requires 'src/MiniNotesPersistence.cls'
