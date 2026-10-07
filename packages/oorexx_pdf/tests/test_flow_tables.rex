/* Force multiple pages, multiple tables, wrapped cells, row continuation and Array-fed rows. */
parse arg root out
call directory root
headers = .Array~of("Sequence", "Owner", "Work item", "Status")
widths = .Array~of(55, 92, 285, 70)
rows = .Array~new

do i = 1 to 67
  owner = "User " || ((i - 1) // 7 + 1)
  text = "TPS processing row " || i || " carries deliberately verbose material so the table must wrap text and flow correctly over page boundaries."
  if i = 23 then text = text || " This one is intentionally enormous. " || copies("Overflow-content-without-a-shortcut ", 115)
  status = "READY"
  if i // 3 = 0 then status = "REVIEW"
  rows~append(.Array~of(i, owner, text, status))
end

report = .PdfFlowReport~new
report~title = "TPS Collection Register"
report~subtitle = "Multi-page / multi-table Array qualification"
report~footer = "Native ooRexx PDF flow-layout qualification"
report~addParagraph("This document deliberately overflows several pages. Tables below are supplied by ooRexx Array objects; headers repeat when a table crosses a page boundary.", 9, .false, 10)

t1 = .PdfTable~new(headers, widths)
t1~title = "Uncollected TPS Reports"
t1~addRows(rows)
report~addTable(t1)
report~addParagraph("Intervening narrative proves tables and ordinary flowed content can be interleaved without resetting pagination.", 9, .true, 10)

rows2 = .Array~new
do i = 1 to 19
  rows2~append(.Array~of("C-" || i, "Archive", "Collected report " || i || " has now been filed with supporting notes.", "DONE"))
end

t2 = .PdfTable~new(headers, widths)
t2~title = "Collected TPS Reports"
t2~addRows(rows2)
report~addTable(t2)
bytes = report~render(out)
say "PASS flow tables bytes="bytes
::requires 'PdfCore.cls'
