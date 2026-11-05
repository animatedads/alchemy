/* compile.rex - turn the authoring files into id-only files.            */
/* concepts.src -> concepts.words  (id | gloss | parent-id | defs-by-id)  */
/* lexicon.src  -> lexicon.words   (every ^gloss replaced by its id)      */
/* rules.src    -> rules.words     (every ^gloss replaced by its id)      */
/* Usage: rexx compile.rex [dir]                                          */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                       */
parse arg dir
dir = dir~strip
if dir = '' then dir = '.'

ids   = .StringTable~new
lines = .Array~new
n = 0
do cf over .array~of(dir'/concepts.src', dir'/wordnet/concepts_wn.src')
  if \SysFileExists(cf) then iterate
  s = .Stream~new(cf)~~open('read')
  do while s~lines > 0
    ln = s~linein
    if ln~strip = '' then iterate
    if ln~left(1) = '#' then iterate
    parse var ln gloss '|' parent '|' defs
    n = n + 1
    id = 'C.'||n~right(4, '0')
    ids[gloss~strip] = id
    lines~append(gloss~strip||'|'||parent~strip||'|'||defs~strip)
  end
  s~close
end

out = .Stream~new(dir'/concepts.words')~~open('write replace')
i = 0
do ln over lines
  i = i + 1
  parse var ln gloss '|' parent '|' defs
  pid = ''
  if parent \= '' then do
    if \ids~hasIndex(parent) then call fail 'unknown parent' parent 'for' gloss
    pid = ids[parent]
  end
  out~lineout('C.'||i~right(4, '0')||'|'||gloss||'|'||pid||'|'||refs(defs, ids))
end
out~close

call convert dir'/lexicon.src', dir'/lexicon.words', ids
if SysFileExists(dir'/wordnet/lexicon_wn.src') then call convert dir'/wordnet/lexicon_wn.src', dir'/lexicon.words', ids, 'append'
call convert dir'/rules.src',   dir'/rules.words',   ids
say 'compiled' n 'concepts'
exit 0

convert: procedure
  use arg src, dst, ids, mode
  s = .Stream~new(src)~~open('read')
  if mode == 'append' then o = .Stream~new(dst)~~open('write append')
  else o = .Stream~new(dst)~~open('write replace')
  do while s~lines > 0
    ln = s~linein
    if ln~strip = '' then iterate
    if ln~left(1) = '#' then iterate
    o~lineout(refs(ln, ids))
  end
  s~close
  o~close
  return

/* replace every ^gloss in a line with its concept id */
refs: procedure
  use arg text, ids
  outText = ''
  p = 1
  do forever
    q = text~pos('^', p)
    if q = 0 then leave
    outText = outText||text~substr(p, q - p)
    e = q + 1
    do while e <= text~length
      ch = text~substr(e, 1)
      /* a gloss may carry a WordNet id after a tilde: climb~01925957-v */
      if verify(ch, 'abcdefghijklmnopqrstuvwxyz0123456789-~') \= 0 then leave
      e = e + 1
    end
    g = text~substr(q + 1, e - q - 1)
    if \ids~hasIndex(g) then call fail 'unknown concept ^'g 'in:' text
    outText = outText||ids[g]
    p = e
  end
  return outText||text~substr(p)

fail:
  parse arg msg
  say 'compile error:' msg
  exit 1
