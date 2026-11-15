/* scramble_test.rex - prove the reasoning never reads a gloss.           */
/* Shuffles every gloss in concepts.words into a copy of the data, reads  */
/* a story with both, and requires the graph, entities, realised English, */
/* findings and unread lists to be identical.                             */
/* It fails, rather than passing, if any run fails or any required output */
/* is missing or empty (a test that passes on no output proves nothing).  */
/* Usage: rexx scramble_test.rex [seed] [storydir]                         */
/*   storydir is relative to this script's folder; default "." (story 1).  */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                       */
/* v0.4: own location, exit codes and empty-output checks after review by  */
/* ChatGPT (reader_sentence_structure_handoff, 4 Nov 2026).               */
parse arg seed story .
if seed == '' then seed = 42
if story == '' then story = '.'
parse source . . me
here = filespec('L', me)~strip('T', '/')
data = here'/'story
if \SysFileExists(data'/story.txt') then call fail 'no story.txt in' data
scr = '/tmp/reader_scramble_'seed
call run 'rm -rf' scr '&& mkdir -p' scr
call run 'cp' here'/concepts.words' here'/lexicon.words' here'/rules.words' data'/story.txt' scr
if SysFileExists(data'/cast.words') then call run 'cp' data'/cast.words' scr
if SysFileExists(data'/questions.txt') then call run 'cp' data'/questions.txt' scr
if SysFileExists(data'/sight.words') then call run 'cp' data'/sight.words' data'/bind.words' scr
/* shuffle glosses */
ids = .Array~new
gl = .Array~new
rest = .Array~new
s = .Stream~new(scr'/concepts.words')~~open('read')
do while s~lines > 0
  parse value s~linein with id '|' g '|' tail
  ids~append(id)
  gl~append(g)
  rest~append(tail)
end
s~close
if ids~items < 10 then call fail 'concepts.words has only' ids~items 'lines'
original = gl~copy
call random , , seed
n = gl~items
do k = n to 2 by -1
  j = random(1, k)
  tmp = gl[k]
  gl[k] = gl[j]
  gl[j] = tmp
end
moved = 0
do k = 1 to n
  if gl[k] \== original[k] then moved = moved + 1
end
o = .Stream~new(scr'/concepts.words')~~open('write replace')
do k = 1 to n
  o~lineout(ids[k]'|'gl[k]'|'rest[k])
end
o~close
ref = scr'/ref'
call run 'mkdir -p' ref '&& cp' here'/concepts.words' here'/lexicon.words' here'/rules.words' data'/story.txt' ref
if SysFileExists(data'/cast.words') then call run 'cp' data'/cast.words' ref
if SysFileExists(data'/questions.txt') then call run 'cp' data'/questions.txt' ref
if SysFileExists(data'/sight.words') then call run 'cp' data'/sight.words' data'/bind.words' ref
call run 'cd' here '&& rexx read_story.rex' ref ref'/out > /dev/null'
call run 'cd' here '&& rexx read_story.rex' scr scr'/out > /dev/null'
/* the testimony assessor decides from the same graph: its verdicts must not move either */
call run 'cd' here '&& rexx testimony.rex' ref '> /dev/null'
call run 'cd' here '&& rexx testimony.rex' scr '> /dev/null'
call run 'cd' here '&& rexx order_check.rex' ref '> /dev/null'
call run 'cd' here '&& rexx order_check.rex' scr '> /dev/null'
/* and so must the answers */
if SysFileExists(data'/questions.txt') then do
  call run 'cd' here '&& rexx qa.rex' ref '> /dev/null'
  call run 'cd' here '&& rexx qa.rex' scr '> /dev/null'
end
say 'story' story': gloss moved for' moved 'of' n 'concepts; e.g.' ids[7] 'was "'original[7]'", is now "'gl[7]'"'
fails = 0
do f over .array~of('graph.words', 'entities.words', 'realised.txt', 'findings.txt', 'unread.txt', 'testimony.txt', 'answers.txt', 'orders.txt')
  must = wordpos(f, 'graph.words entities.words realised.txt testimony.txt orders.txt') > 0
  a = readAll(ref'/out/'f, must)
  b = readAll(scr'/out/'f, must)
  if a == b then say 'IDENTICAL ' f '('lines(a)' lines)'
  else do
    say 'DIFFERENT ' f
    fails = fails + 1
  end
end
if moved < n % 2 then do
  say 'FAIL: the shuffle moved too few glosses to be a test'
  exit 2
end
if fails = 0 then say 'PASS: scrambling every gloss changed no reasoning and no output.'
else say 'FAIL:' fails 'file(s) changed - a string leaked into the reasoning.'
exit fails

run: procedure
  parse arg cmd
  address system cmd
  if rc \= 0 then call fail 'command failed (rc' rc'):' cmd
  return

readAll: procedure
  use arg file, must
  if \SysFileExists(file) then do
    if must then call fail 'missing output' file
    return ''
  end
  s = .Stream~new(file)~~open('read')
  t = s~charin(1, s~chars)
  s~close
  if must then if t~strip == '' then call fail 'empty output' file
  return t

lines: procedure
  use arg t
  return t~countStr('0a'x)

fail:
  parse arg msg
  say 'FAIL:' msg
  exit 3
