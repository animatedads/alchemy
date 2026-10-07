/* dev3 qualification: typed columns, alignment, spanning cells, page break, landscape. */
parse arg root out
call directory root

headers = .Array~of("Line", "Cost centre", "Units", "Unit cost", "Variance %", "Total")
widths = .Array~of(52, 170, 70, 92, 92, 104)

table = .PdfTable~new(headers, widths)
table~title = "Quarterly TPS Processing Costs"
table~setColumnTypes(.Array~of("integer", "text", "integer", "decimal2", "percent2", "money2"))
table~setAlignments(.Array~of("right", "left", "right", "right", "right", "right"))

rows = .Array~new
line = 0
do region over .Array~of("North", "Central", "South")
  rows~append(.Array~of(.PdfTable~cell(region || " region", 6, "left", .true)))
  do j = 1 to 24
    line = line + 1
    units = 10 + (line // 17)
    unitCost = 7.25 + ((line // 9) / 4)
    variance = (line // 11) - 5
    total = units * unitCost
    rows~append(.Array~of(line, region || "-TPS-" || right(line, 3, "0"), units, unitCost, variance, total))
  end
end

table~addRows(rows)

report = .PdfFlowReport~new~landscape
report~title = "TPS Financial Register"
report~subtitle = "dev3 typed/aligned/spanning Array qualification"
report~footer = "Alchemy ooRexx PDF dev3 qualification"
report~addParagraph("This landscape report proves typed numeric columns, explicit alignment, full-width group rows, automatic multi-page continuation and repeated headers.", 9, .false, 10)
report~addTable(table)
report~addPageBreak
report~addParagraph("Management Notes", 13, .true, 10)
report~addParagraph("The explicit page-break block starts this section on a clean page after the flowing table. The PDF page geometry remains A4 landscape.", 9, .false, 10)

summaryHeaders = .Array~of("Measure", "Value", "Comment")
summary = .PdfTable~new(summaryHeaders, .Array~of(150, 105, 325))
summary~setAlignments(.Array~of("left", "right", "left"))
summary~addRow(.Array~of("Rows", line, "Ordinary detail rows supplied from an ooRexx Array."))
summary~addRow(.Array~of("Region separators", 3, "Each separator is one PdfCell spanning all three table columns."))
summary~addRow(.Array~of(.PdfTable~cell("A final spanning note proves colspans work in tables of a different shape as well.", 3, "center", .true)))
report~addTable(summary)

bytes = report~render(out)
say "PASS advanced tables bytes="bytes
::requires 'PdfCore.cls'
