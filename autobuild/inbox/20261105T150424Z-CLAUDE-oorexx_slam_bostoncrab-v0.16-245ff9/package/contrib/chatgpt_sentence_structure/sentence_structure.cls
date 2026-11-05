/* Conservative sentence-structure front end for ooRexx 5.3.
   Preserve source spans. Do not create semantic concepts or guess roles.
   Output records: TEXT, START, END, KIND, CUES, STATUS.
*/
::class SentenceStructure public

::method split
  use arg source
  output = .Array~new
  start = 1
  quote = .false
  n = source~length
  do i = 1 to n
    ch = source~substr(i,1)
    if ch == '"' | ch == '“' | ch == '”' then quote = \quote
    if ch \== '.' & ch \== '!' & ch \== '?' then iterate
    if ch == '.' then do
      /* No split for a decimal, initials, or selected titles. */
      prev = ''
      nxt = ''
      if i > 1 then prev = source~substr(i-1,1)
      if i < n then nxt = source~substr(i+1,1)
      if prev~datatype('N') & nxt~datatype('N') then iterate
      left = source~substr(start,i-start)
      last = left~word(left~words)~lower
      if wordpos(last, 'mr mrs ms dr prof st vs e.g i.e') > 0 then iterate
      if prev~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ') == 0 & prev \== '' then do
        if i < n then if nxt~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ') == 0 then iterate
      end
    end
    finish = i
    /* Closing quote belongs to this sentence. */
    do while finish < n
      after = source~substr(finish+1,1)
      if after \== '"' & after \== '”' & after \== "'" then leave
      finish = finish + 1
    end
    self~emit(output,source,start,finish)
    start = finish+1
    i = finish
  end
  if start <= n then self~emit(output,source,start,n)
  return output

::method emit private
  use arg output, source, first, last
  raw = source~substr(first,last-first+1)
  if raw~strip == '' then return
  x = .Directory~new
  x['TEXT'] = raw~strip
  x['START'] = first
  x['END'] = last
  x['CUES'] = self~cues(raw)
  x['KIND'] = 'declarative'
  if raw~pos('?') > 0 then x['KIND'] = 'question'
  else if raw~pos('!') > 0 then x['KIND'] = 'exclamation'
  x['STATUS'] = 'NOT_PARSED'
  output~append(x)

::method cues
  use arg sentence
  s = ' 'sentence~lower' '
  s = s~changeStr(',', ' ')~changeStr('.', ' ')~changeStr('?', ' ')~changeStr('!', ' ')
  s = s~changeStr('—',' ')~changeStr(';',' ')~changeStr(':',' ')
  out = ''
  do cue over 'because if when while although before after until so that who which where but and or'~makeArray(' ')
    if s~pos(' 'cue' ') > 0 then do
      if out \== '' then out = out||','
      out = out||cue
    end
  end
  return out
