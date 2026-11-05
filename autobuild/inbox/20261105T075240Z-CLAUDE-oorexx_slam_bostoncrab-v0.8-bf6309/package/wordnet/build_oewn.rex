/* build_oewn.rex - one-off: Open English WordNet JSON -> two .words files */
/* oewn_lemmas.words  : lemma | pos | synset ids in sense order | forms    */
/* oewn_synsets.words : id | pos | members | hypernyms | similar |         */
/*                      attribute | parts (mero_part) | first definition   */
/* JSON is read with json.cls only.                                        */
/* Usage: rexx build_oewn.rex jsondir outdir                               */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                        */
/* Data: Open English WordNet 2025 (CC BY 4.0).                            */
parse arg jdir odir
if odir == '' then odir = '.'
files = .Array~new
address system 'ls' jdir with output using (files)
lem = .Stream~new(odir'/oewn_lemmas.words')~~open('write replace')
syn = .Stream~new(odir'/oewn_synsets.words')~~open('write replace')
nl = 0
ns = 0
do f over files
  if f~right(5) \== '.json' then iterate
  if f == 'frames.json' then iterate
  d = .json~fromJsonFile(jdir'/'f)
  if f~left(8) == 'entries-' then do
    do lemma over d~allIndexes
      byPos = d[lemma]
      do pos over byPos~allIndexes
        e = byPos[pos]
        ids = ''
        if e~hasIndex('sense') then do s over e['sense']
          ids = ids s['synset']
        end
        forms = ''
        if e~hasIndex('form') then do x over e['form']
          forms = forms x~changeStr(' ', '_')
        end
        lem~lineout(lemma'|'pos'|'ids~strip'|'forms~strip)
        nl = nl + 1
      end
    end
  end
  else do
    do id over d~allIndexes
      s = d[id]
      mem = ''
      if s~hasIndex('members') then do x over s['members']
        mem = mem||x~changeStr('|', ' ')||';'
      end
      def = ''
      if s~hasIndex('definition') then def = s['definition'][1]~changeStr('|', '/')
      syn~lineout(id'|'s['partOfSpeech']'|'mem'|'ids(s, 'hypernym') ids(s, 'instance_hypernym')'|'ids(s, 'similar')'|'ids(s, 'attribute')'|'ids(s, 'mero_part')'|'def)
      ns = ns + 1
    end
  end
  say f 'done'
end
lem~close
syn~close
say 'lemma lines' nl ' synsets' ns
exit 0

ids: procedure
  use arg s, key
  out = ''
  if s~hasIndex(key) then do x over s[key]
    out = out x
  end
  return out~strip

::requires 'json.cls'
