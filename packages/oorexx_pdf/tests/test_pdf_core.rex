out = arg(1)
if out = "" then out = "test-core.pdf"
report = .PdfReport~new
report~title = "TPS Report"
report~subtitle = "TPS-2026-001"
report~addField("TPS Number", "TPS-2026-001")
report~addField("User", "codex")
report~addField("Escaping", "parentheses (yes), slash \\ yes")
report~addField("Approval Status", "DRAFT")
bytes = report~render(out)
if bytes < 300 then do
  say "FAIL suspicious PDF length" bytes
  exit 1
end
say "PASS core PDF bytes=" || bytes
::requires 'PdfCore.cls'
