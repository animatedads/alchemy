/* Interactive line projection over the same MiniNotesCliUi controller as ANSI. */
app = .MiniNotesApp~new
app~seedFive
ui = .MiniNotesTextUi~new(app)
ui~banner
ui~execute("documents")
do while ui~running
  call charout , "> "
  parse pull line
  ui~execute(line)
end
exit 0

::requires 'src/MiniNotesApp.cls'
::requires 'src/MiniNotesTextUi.cls'
