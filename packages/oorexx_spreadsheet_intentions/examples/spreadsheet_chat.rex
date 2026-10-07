/* spreadsheet_chat.rex - conversational read-only spreadsheet probe. */
parse arg workbookPath request
if strip(workbookPath) == "" then do
  say "usage: rexx spreadsheet_chat.rex WORKBOOK.xlsx|WORKBOOK.ods [request]"
  exit 2
end

workbook = .SpreadsheetReader~open(workbookPath)
environment = .SpreadsheetIntentEnvironment~new(workbook)

if strip(request) \== "" then do
  response = environment~input(request)
  call render response
  exit 0
end

say "Workbook:" workbookPath
say "Format:" workbook~format
say "Discovered relations:" environment~catalog~relations~items
say "Enter a spreadsheet request. Empty line exits."
do forever
  call charout , "> "
  request = linein()
  if strip(request) == "" then leave
  response = environment~input(request)
  call render response
end
exit 0

render: procedure
  use arg response
  decision = response~decision
  say "STATUS:" decision~status
  if decision~registration \== .nil then say "INTENTION:" decision~registration~id
  if response~summary \== "" then say "SUMMARY:" response~summary
  if decision~status \== "READY" then do
    if decision~question \== "" then say "QUESTION:" decision~question
    return
  end
  call renderData response~data
  return

renderData: procedure
  use arg data
  if data == .nil then do
    say "DATA: NIL"
    return
  end
  if data~isA(.Array) then do
    say "ROWS:" data~items
    do i = 1 to data~items
      call renderItem data~at(i)
    end
    return
  end
  if data~isA(.Directory) then do
    supplier = data~supplier
    do while supplier~available
      say " " supplier~index "=" supplier~item
      supplier~next
    end
    return
  end
  say "VALUE:" data
  return

renderItem: procedure
  use arg item
  if item~isA(.Directory) then do
    line = ""
    supplier = item~supplier
    do while supplier~available
      if line \== "" then line = line || " | "
      line = line || supplier~index || "=" || supplier~item
      supplier~next
    end
    say "  " line
    return
  end
  if item~isA(.SpreadsheetDiagnostic) then do
    say "  " item~severity item~code item~sheet item~address "-" item~message
    return
  end
  say "  " item
  return

::requires "SpreadsheetIntentions.cls"
