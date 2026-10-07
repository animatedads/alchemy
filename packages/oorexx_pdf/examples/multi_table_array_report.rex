/* multi_table_array_report.rex - flowed multi-table PDF sourced from ooRexx Arrays. */
parse arg out
if out = "" then out = "multi-table-report.pdf"

headers = .Array~of("TPS", "Owner", "Description", "State")
widths = .Array~of(70, 90, 270, 70)
rows = .Array~new
rows~append(.Array~of("TPS-001", "Alice", "Quarterly cover-sheet processing and collection.", "READY"))
rows~append(.Array~of("TPS-002", "Bob", "A longer description wraps automatically inside the table cell without requiring the caller to calculate line breaks.", "REVIEW"))

report = .PdfFlowReport~new
report~title = "TPS Register"
report~subtitle = "Array-fed flowed report"
report~addParagraph("Ordinary narrative and tables may be interleaved in one flowing document.")

table = .PdfTable~new(headers, widths)
table~title = "Outstanding reports"
table~addRows(rows)
report~addTable(table)
report~render(out)
say out

::requires 'PdfCore.cls'
