/* MiniNotesTextUi.cls
 * Line-oriented projection over the SAME MiniNotesCliUi controller used by ANSI.
 * This prevents scripted/Codex entry points from diverging from the real UI.
 */
::class MiniNotesTextUi public

::method init
  expose controller
  use strict arg app
  controller = .MiniNotesCliUi~new(app)

::method running
  expose controller
  return controller~running

::method banner
  say "Mini NotNotes Approval Desk"
  say "Text projection of the same controller used by the ANSI UI."
  say

::method execute
  expose controller
  use strict arg line
  line = line~strip
  if line = "" then return ""
  controller~executeCommand(line)
  self~renderScreen
  return ""

::method renderScreen
  expose controller
  screen = controller~screen
  say "STATUS:" controller~status
  if screen~form \== .nil then self~renderForm(screen~form)
  else if screen~detail \== .nil then self~renderDetail(screen~detail)
  else if screen~table \== .nil then self~renderTable(screen~table)
  say
  return self

::method renderTable
  use strict arg table
  columns = table~columns
  say self~joinValues(columns, 1, "")
  self~renderTableRows(table, 1)
  return self

::method renderTableRows
  use strict arg table, rowIndex
  if rowIndex > table~count then return self
  row = table~row(rowIndex)
  marker = " "
  if rowIndex = table~selected then marker = ">"
  say marker || self~joinValues(row[2], 1, "")
  return self~renderTableRows(table, rowIndex + 1)

::method joinValues
  use strict arg values, index, result
  if index > values~items then return result
  value = values[index]
  if value == .nil then value = ""
  nextResult = result
  if nextResult <> "" then nextResult = nextResult || " | "
  nextResult = nextResult || value
  return self~joinValues(values, index + 1, nextResult)

::method renderDetail
  use strict arg detail
  say detail~title
  do pair over detail~fields
    value = pair[2]
    if value == .nil then value = ""
    say pair[1] || ":" value
  end
  do section over detail~sections
    say section[1]
    say section[2]
  end
  return self

::method renderForm
  use strict arg form
  say form~title
  self~renderFormFields(form, 1)
  return self

::method renderFormFields
  use strict arg form, index
  if index > form~count then return self
  field = form~field(index)
  value = field~value
  if value == .nil then value = ""
  say field~label || ":" value
  return self~renderFormFields(form, index + 1)

::requires 'src/MiniNotesCliUi.cls'
