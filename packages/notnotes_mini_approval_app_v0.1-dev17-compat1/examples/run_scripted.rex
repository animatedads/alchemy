/* Feed line-oriented input to the same MiniNotesCliUi controller used by ANSI. */
parse arg scriptFile
if scriptFile = "" then scriptFile = "examples/codex_walkthrough.txt"
stream = .stream~new(scriptFile)
if stream~open("READ") <> "READY:" then do
  say "Cannot open" scriptFile
  exit 2
end
app = .MiniNotesApp~new
app~seedFive
ui = .MiniNotesTextUi~new(app)
ui~banner
do while stream~lines > 0 & ui~running
  line = stream~lineIn
  if line~strip = "" then iterate
  say ">" line
  ui~execute(line)
end
stream~close
exit 0

::requires 'src/MiniNotesApp.cls'
::requires 'src/MiniNotesTextUi.cls'
