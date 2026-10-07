parse arg output
if output == "" then output = "TPS-Report.odt"
doc = .OdtAccess~create("TPS Report Review Report", "NotNotes")
doc~addHeading("TPS Report Review Report", 1)
doc~addParagraph("Mini NotNotes document export through the OpenDocument Text COTS access class.")
doc~addHeading("TPS reports", 2)
t = .OdtTable~new("TPS Reports")
t~addValues(.Array~of("TPS Number", "User", "Cost", "Status"))
t~addValues(.Array~of("TPS-2026-101", "Angela Martin", "1250.50", "DRAFT"))
t~addValues(.Array~of("TPS-2026-102", "Oscar Martinez", "800.00", "APPROVED"))
t~addValues(.Array~of("TPS-2026-103", "Kevin Malone", "3.00", "REVIEW"))
doc~addTable(t)
doc~addHeading("Interchange note", 2)
doc~addParagraph("The ODT package is the interchange projection. NotNotes remains authoritative for the TPS objects.")
.OdtAccess~save(doc, output)
say output
::requires "OdtAccess.cls"
