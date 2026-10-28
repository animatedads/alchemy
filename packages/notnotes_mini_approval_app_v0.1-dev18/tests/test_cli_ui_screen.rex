app = .MiniNotesApp~new
app~seedFive
ui = .MiniNotesCliUi~new(app)
renderer = .CliUiHeadlessRenderer~new(24,100)
ui~render(renderer,24,100)
if renderer~cell(1,1) == .nil then raise syntax 93.900 array("screen title missing")
if ui~mode <> "LIST" then raise syntax 93.900 array("initial mode not LIST")
ui~semanticCommand("TABLE_NEXT")
if app~selected~DocKey <> "PR-1002" then raise syntax 93.900 array("stable table navigation failed")
ui~semanticCommand("ENTER")
if ui~mode <> "DETAIL" then raise syntax 93.900 array("open selected did not enter detail mode")
ui~render(renderer,24,100)
if renderer~cell(4,1) == .nil then raise syntax 93.900 array("detail title missing")
ui~semanticCommand("APPROVE")
if app~selected~ApprovalStatus <> "APPROVED" then raise syntax 93.900 array("detail approve action failed")
ui~semanticCommand("RETURN")
if ui~mode <> "LIST" then raise syntax 93.900 array("return did not restore list")
ui~executeCommand("query gpu")
if ui~screen~table~count <> 2 then raise syntax 93.900 array("query gpu did not produce two rows")
ui~executeCommand("query nonexistent")
if ui~screen~table~count <> 0 then raise syntax 93.900 array("nonsense query must not expose all documents")
ui~executeCommand("view security pending")
if ui~screen~table~count <> 1 then raise syntax 93.900 array("security pending view mismatch")
say "PASS Mini NotNotes CLI UI screen/list/detail/action/query"

::requires 'src/MiniNotesCliUi.cls'
::requires 'vendor/cliui/rexx/CliUiHeadlessRenderer.cls'
