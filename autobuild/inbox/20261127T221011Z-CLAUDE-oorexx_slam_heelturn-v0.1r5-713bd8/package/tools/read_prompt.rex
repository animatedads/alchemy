/* read_prompt.rex - show what Heel Turn reads from a designer prompt.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   The same reader the engine uses, sentence by sentence: READ with the
   settings each sentence moved (setting, change, condition, act/object),
   or NOT READ with the words the lexicon does not know. Then the settings.
   Usage: rexx tools/read_prompt.rex PROMPT_FILE [DATA_DIR] */
parse arg file dataDir
if file == '' then do
  say 'usage: rexx tools/read_prompt.rex PROMPT_FILE [DATA_DIR]'
  exit 2
end
if dataDir == '' then dataDir = 'data'
src = .stream~new(file)
if src~open('READ') \== 'READY:' then do
  say 'cannot read' file
  exit 2
end
text = src~charin(1, src~chars)
src~close
reader = .HeelTurnReader~new(.HeelTurnVocabulary~new(dataDir))
pr = .HeelTurnPromptReader~new(reader)
total = .HeelTurnPolicy~new
n = 0
readCount = 0
do sentence over reader~sentences(text)
  n += 1
  one = pr~read(sentence)
  if one~readCount > 0 then do
    readCount += 1
    say 'READ    ' n':' sentence
    do h over one~hits
      parse var h knob '|' delta '|' cond '|' why
      if cond \== '' then cond = 'when' cond
      say '            ' knob delta cond '('why')'
    end
  end
  else do
    parse value one~notRead[1] with . '|' unknown
    say 'NOT READ' n':' sentence
    if unknown \== '' then say '             unknown words:' unknown
    else say '             every word known; no act moves a setting'
  end
end
policy = pr~read(text)
say ''
say 'Sentences:' n '  read:' readCount '  not read:' n - readCount '  characters:' text~length
say 'Settings (0 to 1, from 0.5; [condition:change]):'
say policy~summary
exit 0
::requires 'HeelTurnPolicy.cls'
