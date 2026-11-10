/* load_sql.rex - load the WordNet .words staging files into SQLite.       */
/* Goes through WordStore (DatabaseBackendSelector -> REXXSQL-SQLITE):     */
/* one transaction of bound inserts, then the indexes.                     */
/* Tables:                                                                */
/*   sense(lemma, pos, rank, synset)    senses in WordNet order           */
/*   form(form, lemma, pos)             irregular forms (flew -> fly)     */
/*   synset(id, pos, members, gloss)    first definition only             */
/*   link(src, kind, dst)               kind: hyper similar attr part     */
/* Usage: rexx load_sql.rex dir    (run under wordnet/env.sh)             */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                       */
parse arg dir
if dir == '' then dir = '.'
address system 'rm -f' dir'/oewn.db' dir'/oewn.db-wal' dir'/oewn.db-shm'
ws = .WordStore~new(dir'/oewn.db')
ws~exec('create table sense(lemma text, pos text, rank integer, synset text)')
ws~exec('create table form(form text, lemma text, pos text)')
ws~exec('create table synset(id text primary key, pos text, members text, gloss text)')
ws~exec('create table link(src text, kind text, dst text)')
ws~exec('begin')
nS = 0
nF = 0
nY = 0
nL = 0
/* homographs are split by pronunciation ("n-1", "n-2" for wind): fold them
   into one part of speech and number their senses on from the first group */
rankBase = .StringTable~new
s = .Stream~new(dir'/oewn_lemmas.words')~~open('read')
do while s~lines > 0
  parse value s~linein with lemma '|' pos '|' ids '|' forms
  pos = pos~left(1)~translate('a', 's')
  key = lemma~lower'|'pos
  r = 0
  if rankBase~hasIndex(key) then r = rankBase[key]
  rankBase[key] = r + words(ids)
  do id over ids~subWords
    r = r + 1
    ws~exec('insert into sense values (?, ?, ?, ?)', .array~of(lemma~lower, pos, r, id))
    nS = nS + 1
  end
  do f over forms~subWords
    ws~exec('insert into form values (?, ?, ?)', .array~of(f~changeStr('_', ' ')~lower, lemma~lower, pos))
    nF = nF + 1
  end
end
s~close
s = .Stream~new(dir'/oewn_synsets.words')~~open('read')
do while s~lines > 0
  parse value s~linein with id '|' pos '|' mem '|' hyp '|' sim '|' att '|' part '|' def
  ws~exec('insert into synset values (?, ?, ?, ?)', .array~of(id, pos~translate('a', 's'), mem, def))
  nY = nY + 1
  do kv over .array~of('hyper' hyp, 'similar' sim, 'attr' att, 'part' part)
    parse var kv kind list
    do x over list~subWords
      ws~exec('insert into link values (?, ?, ?)', .array~of(id, kind, x))
      nL = nL + 1
    end
  end
end
s~close
ws~exec('commit')
ws~exec('create index i_sense on sense(lemma, pos, rank)')
ws~exec('create index i_form on form(form)')
ws~exec('create index i_link on link(src, kind)')
ws~exec('create index i_link_dst on link(dst, kind)')
ws~close
say 'rows: sense' nS ' form' nF ' synset' nY ' link' nL
exit 0

::requires 'wordstore.cls'
