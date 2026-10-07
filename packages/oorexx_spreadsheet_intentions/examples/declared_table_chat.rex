/* declared_table_chat.rex - open one authoritative OOXML table by name. */
parse arg workbookPath tableName request
if strip(workbookPath) == "" | strip(tableName) == "" then do
  say "usage: rexx declared_table_chat.rex WORKBOOK.xlsx TABLE_NAME [request]"
  exit 2
end
workbook = .SpreadsheetReader~openDeclaredTable(workbookPath, tableName)
environment = .SpreadsheetIntentEnvironment~new(workbook)
if strip(request) == "" then request = "what tables"
response = environment~input(request)
say "STATUS:" response~decision~status
if response~decision~registration \== .nil then say "INTENTION:" response~decision~registration~id
say "SUMMARY:" response~summary
if response~data~isA(.Array) then say "ROWS:" response~data~items
exit 0
::requires "SpreadsheetIntentions.cls"
