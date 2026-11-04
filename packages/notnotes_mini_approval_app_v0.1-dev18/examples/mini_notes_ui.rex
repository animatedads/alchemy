/* Full-screen-ish semantic ANSI UI without alternate-screen ownership. */
app = .MiniNotesApp~new
app~seedFive
ui = .MiniNotesCliUi~new(app)
renderer = .CliUiAnsiRenderer~new(0, 1, 24, 100)

do while ui~running
  ui~render(renderer, 24, 100)
  key = renderer~pollKey(250)
  if key \== .nil then ui~handleKey(key)
end
renderer~close
say
say "Mini NotNotes UI closed."
exit 0

::requires 'src/MiniNotesCliUi.cls'
::requires 'vendor/cliui/rexx/CliUiAnsiRenderer.cls'
