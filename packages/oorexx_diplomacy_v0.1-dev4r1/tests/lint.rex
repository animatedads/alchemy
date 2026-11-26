/* Uses the estate SourceLinter via REXX_PATH. Fails if not present. */
parse arg path
input = .stream~new(path)
if input~open('READ') \== 'READY:' then exit 2
lines = .array~new
do while input~lines > 0
  lines~append(input~linein)
end
input~close
findings = .SourceLinter~new~lint(lines)
do finding over findings
  say finding~string
end
say path 'findings:' findings~items
exit (findings~items > 0)
::requires 'SourceLint.cls'
