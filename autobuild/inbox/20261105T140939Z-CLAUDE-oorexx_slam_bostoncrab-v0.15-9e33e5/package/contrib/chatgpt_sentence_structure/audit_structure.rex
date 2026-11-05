/* Audit sentence segmentation independently of concept import. */
parse arg input output
if input == '' then do
  say 'usage: rexx audit_structure.rex story.txt [audit.tsv]'
  exit 2
end
s = .Stream~new(input)~~open('read')
if output == '' then output = 'sentence_audit.tsv'
o = .Stream~new(output)~~open('write replace')
o~lineout('line' || '09'x || 'sentence' || '09'x || 'kind' || '09'x || 'cues' || '09'x || 'text')
a = .SentenceStructure~new
lineNo = 0
count = 0
do while s~lines > 0
  lineNo = lineNo + 1
  line = s~linein
  do rec over a~split(line)
    count = count + 1
    clean = rec['TEXT']~changeStr('09'x,' ')
    o~lineout(lineNo || '09'x || count || '09'x || rec['KIND'] || '09'x || rec['CUES'] || '09'x || clean)
  end
end
s~close
o~close
say 'sentence audit:' count 'sentences, output:' output
::requires 'sentence_structure.cls'
