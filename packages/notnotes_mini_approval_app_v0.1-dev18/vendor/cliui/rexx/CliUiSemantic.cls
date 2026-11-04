::class CliUiSemanticEvent public
::method init
  expose trigger source subject detailKey detailValue
  use strict arg trigger, source, subject="", detailKey="", detailValue=""
::attribute trigger get
::attribute source get
::attribute subject get
::attribute detailKey get
::attribute detailValue get
::method trace
  expose trigger source subject detailKey detailValue
  return trigger||"|"||source||"|"||subject||"|"||detailKey||"|"||detailValue

::class CliUiSemanticTrace public
::method init; expose entries; entries=.array~new
::method record
  expose entries
  use strict arg event, effect=""
  entries~append(event~trace||"|"||effect); return self
::method entries; expose entries; return entries
::method text
  expose entries
  out=""
  do e over entries
    if out<>"" then out=out||"0a"x
    out=out||e
  end
  return out
