/* Deliberately fail closed when no accepted Rexx/SQL provider is loaded. */
root = value('MININOTES_TEST_ROOT',, 'ENVIRONMENT')
if root = '' then exit 2
x = .MiniNotesDatabaseSelector~open(root)
say 'FAIL default opened without Rexx/SQL'
exit 0
::requires 'src/MiniNotesIndexedSqliteEngine.cls'
