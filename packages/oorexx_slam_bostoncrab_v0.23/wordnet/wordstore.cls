/* wordstore.cls - the only place that talks SQL to the WordNet store.     */
/* Opens the store through the estate's DatabaseBackendSelector with       */
/* provider REXXSQL-SQLITE (Rexx/SQL over SQLite, indexed) and requires     */
/* KEYED_LOOKUP_INDEXED, so selection fails closed if lookups would scan.   */
/* Every query binds its values: words are never spliced into SQL text.    */
/* Needs on REXX_PATH: oorexx_native_database_backends_v0.1/src and        */
/* oorexx_rexxsql_backend_v0.1/src; librexxsql.so on LD_LIBRARY_PATH        */
/* (wordnet/env.sh sets both from ALCHEMY_REPO_ROOT).                        */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                        */

::class WordStore public
::attribute session unguarded

::method init
  expose session
  use arg file, writable
  opts = .Directory~new
  opts['provider'] = 'REXXSQL-SQLITE'
  opts['databaseFile'] = file
  opts['requiredCapabilities'] = .array~of('KEYED_LOOKUP_INDEXED')
  session = .DatabaseBackendSelector~new~open(opts)
  if \session~hasMethod('EXECUTEBOUND') then raise syntax 98.900 array('WordStore: database selection failed:' session~string)

/* run a statement with bound text values; return rows as Arrays of text */
::method run
  expose session
  use arg sql, values
  binds = .Array~new
  if arg(2, 'E') then do v over values
    binds~append(.array~of('TEXT', v))
  end
  if binds~items = 0 then r = session~execute(sql)
  else r = session~executeBound(sql, binds)
  if r~status \= 'SUCCESS' then raise syntax 98.900 array('WordStore SQL failed:' r~message '-' sql)
  return r~rows

::method exec
  use arg sql, values
  if arg(2, 'E') then return self~run(sql, values)
  return self~run(sql)

::method one
  use arg rows, col
  if rows~items = 0 then return ''
  v = rows[1][col]
  if v == .nil then return ''
  return v

/* the synset of a sense: lemma, pos, rank */
::method senseOf
  use arg lemma, pos, rank
  return self~one(self~run('select synset from sense where lemma = ? and pos = ? and rank = ?', .array~of(lemma, pos, rank)), 'SYNSET')

::method hasLemma
  use arg lemma, pos
  return self~senseOf(lemma, pos, 1) \== ''

/* irregular forms: flew -> fly (v); rows as Arrays [lemma, pos] */
::method formsOf
  use arg form
  out = .Array~new
  do r over self~run('select lemma, pos from form where form = ?', .array~of(form))
    out~append(.array~of(r['LEMMA'], r['POS']))
  end
  return out

::method first
  use arg id, kind
  return self~one(self~run('select dst from link where src = ? and kind = ? order by rowid limit 1', .array~of(id, kind)), 'DST')

/* the whole a part belongs to: branch -> tree */
::method wholeOf
  use arg id
  return self~one(self~run("select src from link where dst = ? and kind = 'part' order by rowid limit 1", .array~of(id)), 'SRC')

::method members
  use arg id
  rows = self~run('select members, gloss from synset where id = ?', .array~of(id))
  if rows~items = 0 then return ''
  return .array~of(rows[1]['MEMBERS'], rows[1]['GLOSS'])

::method close
  expose session
  session~close

::requires 'DatabaseBackendSelector.cls'
