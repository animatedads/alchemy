a = .SentenceStructure~new
x = a~split('Dr. Fox saw 3.14 nuts. Pip ran! Did Barnaby bark?')
call assert x~items = 3, 'sentence boundaries'
call assert x[1]['TEXT'] == 'Dr. Fox saw 3.14 nuts.', 'decimal/title'
call assert x[3]['KIND'] == 'question', 'question'
y = a~split('If Pip runs, Barnaby follows because he is kind.')
call assert y~items = 1, 'subordinate sentence'
call assert y[1]['CUES']~pos('if') > 0, 'if cue'
call assert y[1]['CUES']~pos('because') > 0, 'because cue'
say 'PASS: sentence structure 5 assertions'
exit 0
assert: procedure
  parse arg ok, label
  if \ok then do
    say 'FAIL:' label
    exit 1
  end
return
::requires 'sentence_structure.cls'
