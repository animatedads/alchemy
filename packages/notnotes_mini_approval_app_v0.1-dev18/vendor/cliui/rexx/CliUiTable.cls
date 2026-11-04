::class CliUiTableModel public
::method init
  expose columns rows selected viewportTop viewportRows
  use strict arg columns
  if columns == .nil then columns = .array~new
  rows=.array~new; selected=0; viewportTop=1; viewportRows=10
::method append; expose rows; use strict arg identity,cells; rows~append(.array~of(identity,cells)); return self
::method count; expose rows; return rows~items
::method row; expose rows; use strict arg n; return rows[n]
::method columns; expose columns; return columns
::method select
  expose rows selected
  use strict arg n
  if n<0 then n=0
  if n>rows~items then n=rows~items
  selected=n; self~ensureVisible; return selected
::method selected; expose selected; return selected
::method selectedIdentity
  expose rows selected
  if selected=0 then return .nil
  return rows[selected][1]
::method move
  expose selected rows
  use strict arg delta
  if rows~items=0 then return 0
  if selected=0 then selected=1
  else selected=selected+delta
  if selected<1 then selected=1
  if selected>rows~items then selected=rows~items
  self~ensureVisible
  return selected
::method viewport
  expose viewportTop viewportRows
  use strict arg top=.nil, rows=.nil
  if \top~isNil then viewportTop=top
  if \rows~isNil then viewportRows=rows
  self~ensureVisible
  return self
::method viewportTop; expose viewportTop; return viewportTop
::method viewportRows; expose viewportRows; return viewportRows
::method ensureVisible
  expose selected viewportTop viewportRows
  if selected=0 then return self
  if selected<viewportTop then viewportTop=selected
  bottom=viewportTop+viewportRows-1
  if selected>bottom then viewportTop=selected-viewportRows+1
  if viewportTop<1 then viewportTop=1
  return self
