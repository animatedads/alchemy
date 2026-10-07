report = .PdfReport~new
report~title = "TPS Report"
report~subtitle = "TPS-2026-001"
report~footer = "Collected TPS Report"
report~addField("TPS Number", "TPS-2026-001")
report~addField("User", "codex")
report~addField("Approval Status", "DRAFT")
report~addField("Notes", "PC LOAD LETTER? What does that mean?")
bytes = report~render("tps-report.pdf")
say "WROTE tps-report.pdf bytes=" || bytes
::requires 'PdfCore.cls'
