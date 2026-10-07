parse arg out
if out = "" then out = "financial-landscape.pdf"

report = .PdfFlowReport~new~landscape
report~title = "TPS Financial Register"
report~subtitle = "Typed columns and spanning group rows"

table = .PdfTable~new(.Array~of("TPS", "Owner", "Units", "Rate", "Total"), .Array~of(90,180,70,90,100))
table~setColumnTypes(.Array~of("text", "text", "integer", "decimal2", "money2"))
table~addRow(.Array~of(.PdfTable~cell("Operations", 5, "left", .true)))
table~addRow(.Array~of("TPS-001", "Alice", 14, 8.5, 119))
table~addRow(.Array~of("TPS-002", "Bob", 9, 11.25, 101.25))
report~addTable(table)
report~render(out)
say out
::requires 'PdfCore.cls'
