/* SlamStore.cls - SLAM v0.1 node store: SQLite through Rexx/SQL, a separate database file.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Database access: RexxSqlSqliteSession from oorexx_rexxsql_backend_v0.1 (Rexx/SQL by Mark Hessling).
 *
 * Tables
 *   shape    one row per node: a segment shape, a word, or a START/END marker. canon is the identity.
 *   unit     one row per ingested code unit (or corpus word); sig is the duplicate filter.
 *   instance every occurrence of a node: unit, parent instance, position, line, repeat, role binding.
 *   edge     (from, to) adjacency in the source, with frequency: the PRIOR tier.
 *   weight   (from, to) recorded outcomes, trials and passes: the TESTED tier. The edge is the key, so
 *            the same node scores differently depending on which node it was entered from.
 *   anchor   word -> code shape (grounds a corpus word in something that runs).
 *   lesson   every composed run kept with its prediction and reason, passed or failed.
 *   contract what a code node needs (kinds per argument) and gives (kinds), from SlamContract. With it,
 *            canRun(from, to) decides whether an edge CAN do the work before any score is looked at,
 *            and makeEdges creates edges the code never had (freq 0: no prior, so only tests score
 *            them). Proposed by Claude (Opus 4.8) from the Reasoned Thought side; asked for by ChatGPT.
 *   task / step / turn  Task state, one transaction per turn.
 *
 * Rate of an edge: passes/trials when tested, else freq/out-frequency of the from node (prior).
 * SCORE is the Wilson lower bound (95%) of that rate over its count, so 1 of 1 (0.21) ranks below
 * 1000 of 1000 (0.996): the number of trials is evidence too (ChatGPT's review). Search and ranking
 * use SCORE; RATE stays visible.
 */

::requires 'RexxSqlBackend.cls'
::requires 'SlamContract.cls'

::class SlamStore public
::attribute session
::attribute path
::attribute shapeCache
::attribute edgeBuf
::attribute inTransaction
::method init
  expose session path shapeCache edgeBuf inTransaction
  use strict arg path
  session = .RexxSqlSqliteSession~open(path)
  shapeCache = .directory~new
  edgeBuf = .directory~new
  inTransaction = .false
  self~ensureSchema
::method close
  expose session
  self~flushEdges
  session~close
/* Bind list from values: every value travels as text (Rexx/SQL binds text; SQLite applies column affinity). */
::method binds
  out = .array~new
  do i = 1 to arg()
    out~append(.array~of('CHAR', arg(i)))
  end
  return out
::method q
  expose session
  use strict arg sql, binds = .nil
  if binds == .nil then r = session~execute(sql)
  else r = session~executeBound(sql, binds)
  if r~status \= 'SUCCESS' then raise syntax 98.900 array('SLAM store:' r~message '|' sql)
  return r
::method scalar
  use strict arg sql, binds = .nil
  r = self~q(sql, binds)
  if r~rows~items == 0 then return ''
  row = r~rows[1]
  return row[row~allIndexes[1]]
::method begin
  expose inTransaction
  self~q('BEGIN IMMEDIATE')
  inTransaction = .true
::method commit
  expose inTransaction
  self~flushEdges
  self~q('COMMIT')
  inTransaction = .false
::method rollback
  expose inTransaction edgeBuf shapeCache
  self~q('ROLLBACK')
  inTransaction = .false
  edgeBuf = .directory~new
  shapeCache = .directory~new
::method ensureSchema
  self~q('CREATE TABLE IF NOT EXISTS shape (id INTEGER PRIMARY KEY, kind TEXT NOT NULL, family TEXT NOT NULL, canon TEXT NOT NULL UNIQUE)')
  self~q('CREATE TABLE IF NOT EXISTS unit (id INTEGER PRIMARY KEY, path TEXT, kind TEXT, owner TEXT, selector TEXT, line INTEGER, sig TEXT NOT NULL UNIQUE)')
  self~q('CREATE TABLE IF NOT EXISTS instance (id INTEGER PRIMARY KEY, unit_id INTEGER NOT NULL, parent_id INTEGER NOT NULL, seq INTEGER NOT NULL, shape_id INTEGER NOT NULL, line INTEGER, repeat INTEGER NOT NULL, binding TEXT, consts TEXT)')
  /* a store made before consts existed gets the column (empty for its old rows) */
  if self~scalar("SELECT count(*) AS n FROM pragma_table_info('instance') WHERE name = 'consts'") = 0 then self~q('ALTER TABLE instance ADD COLUMN consts TEXT')
  self~q('CREATE TABLE IF NOT EXISTS edge (from_id INTEGER NOT NULL, to_id INTEGER NOT NULL, freq INTEGER NOT NULL, PRIMARY KEY (from_id, to_id))')
  self~q('CREATE TABLE IF NOT EXISTS weight (from_id INTEGER NOT NULL, to_id INTEGER NOT NULL, trials INTEGER NOT NULL, passes INTEGER NOT NULL, PRIMARY KEY (from_id, to_id))')
  self~q('CREATE TABLE IF NOT EXISTS anchor (word_id INTEGER NOT NULL, shape_id INTEGER NOT NULL, note TEXT, PRIMARY KEY (word_id, shape_id))')
  self~q('CREATE TABLE IF NOT EXISTS task (id INTEGER PRIMARY KEY, title TEXT NOT NULL, state TEXT NOT NULL, turns INTEGER NOT NULL)')
  self~q('CREATE TABLE IF NOT EXISTS step (id INTEGER PRIMARY KEY, task_id INTEGER NOT NULL, seq INTEGER NOT NULL, text TEXT, from_id INTEGER, to_id INTEGER, min_tier TEXT, state TEXT NOT NULL, path TEXT, value TEXT)')
  self~q('CREATE TABLE IF NOT EXISTS turn (task_id INTEGER NOT NULL, n INTEGER NOT NULL, step_seq INTEGER, action TEXT NOT NULL, node_id INTEGER, frontier INTEGER, detail TEXT, PRIMARY KEY (task_id, n))')
  self~q('CREATE TABLE IF NOT EXISTS lesson (id INTEGER PRIMARY KEY, from_id INTEGER NOT NULL, to_id INTEGER NOT NULL, passed INTEGER NOT NULL, predicted TEXT, reason TEXT, data TEXT)')
  self~q('CREATE TABLE IF NOT EXISTS contract (node_id INTEGER PRIMARY KEY, needs TEXT NOT NULL, gives TEXT NOT NULL, effects TEXT, standalone INTEGER NOT NULL, canon TEXT)')
  /* translation edges: a node in one language -> the node it becomes in another (from compiler pairs);
     freq is the prior, trials / passes the tested tier, kept apart from the edges Task searches */
  self~q('CREATE TABLE IF NOT EXISTS translate (from_id INTEGER NOT NULL, to_id INTEGER NOT NULL, freq INTEGER NOT NULL, trials INTEGER NOT NULL, passes INTEGER NOT NULL, PRIMARY KEY (from_id, to_id))')
  /* proofs: a claim about one result, PROVED / DISPROVED / INDETERMINATE by a certificate checked in exact
     rationals (SlamProof.cls).  Kept apart from lesson: a lesson says two ways agreed; a proof says a claim holds. */
  self~q('CREATE TABLE IF NOT EXISTS proof (id INTEGER PRIMARY KEY, node_id INTEGER NOT NULL, claim TEXT NOT NULL, outcome TEXT NOT NULL, strength TEXT NOT NULL, data TEXT, detail TEXT)')
  self~q('CREATE INDEX IF NOT EXISTS slam_instance_shape ON instance (shape_id)')
  self~q('CREATE INDEX IF NOT EXISTS slam_instance_unit ON instance (unit_id)')
  self~q('CREATE INDEX IF NOT EXISTS slam_edge_to ON edge (to_id)')
  self~q('CREATE INDEX IF NOT EXISTS slam_weight_to ON weight (to_id)')
  self~q('CREATE INDEX IF NOT EXISTS slam_shape_family ON shape (family)')

/* ---- nodes ---- */
::method shapeId
  expose shapeCache
  use strict arg kind, family, canon
  if shapeCache~hasIndex(canon) then return shapeCache[canon]
  self~q('INSERT OR IGNORE INTO shape (kind, family, canon) VALUES (?, ?, ?)', self~binds(kind, family, canon))
  id = self~scalar('SELECT id AS id FROM shape WHERE canon = ?', self~binds(canon))
  shapeCache[canon] = id
  return id
::method markerId
  use strict arg ctx, side
  canon = '<' || side || ':' || ctx || '>'
  return self~shapeId('MARK', canon, canon)
::method findShape
  use strict arg canon
  return self~scalar('SELECT id AS id FROM shape WHERE canon = ?', self~binds(canon))
::method canonOf
  use strict arg id
  return self~scalar('SELECT canon AS canon FROM shape WHERE id = ?', self~binds(id))
::method displayId class
  use strict arg id
  return d2x(id)~right(4, '0')
/* A node given as an id, a display id (#00EF), or a canonical text. */
::method resolve
  use strict arg node
  if datatype(node, 'W') then return node
  if node~left(1) == '#' then return x2d(node~substr(2))
  return self~findShape(node)

/* ---- ingest ---- */
::method unitInsert
  use strict arg path, kind, owner, selector, line, sig
  if self~scalar('SELECT id AS id FROM unit WHERE sig = ?', self~binds(sig)) \== '' then return 0
  self~q('INSERT INTO unit (path, kind, owner, selector, line, sig) VALUES (?, ?, ?, ?, ?, ?)', self~binds(path, kind, owner, selector, line, sig))
  return self~scalar('SELECT last_insert_rowid() AS id')
::method instanceInsert
  use strict arg unitId, parentId, seq, shapeId, line, repeat, binding, consts = ''
  self~q('INSERT INTO instance (unit_id, parent_id, seq, shape_id, line, repeat, binding, consts) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', self~binds(unitId, parentId, seq, shapeId, line, repeat, binding, consts))
  return self~scalar('SELECT last_insert_rowid() AS id')
::method edgeAdd
  expose edgeBuf
  use strict arg fromId, toId, n = 1
  key = fromId || '/' || toId
  if edgeBuf~hasIndex(key) then edgeBuf[key] = edgeBuf[key] + n
  else edgeBuf[key] = n
::method flushEdges
  expose edgeBuf
  do key over edgeBuf~allIndexes
    parse var key f '/' t
    self~q('INSERT INTO edge (from_id, to_id, freq) VALUES (?, ?, ?) ON CONFLICT (from_id, to_id) DO UPDATE SET freq = freq + excluded.freq', self~binds(f, t, edgeBuf[key]))
  end
  edgeBuf = .directory~new
/* One unit's segment tree. Returns the unit id, or 0 when an identical unit was already ingested. */
::method ingestUnit
  use strict arg path, unit, segs
  uid = self~unitInsert(path, unit~kind, unit~owner, unit~selector, unit~line, unit~signature)
  if uid == 0 then return 0
  self~ingestSeq(uid, 0, 'UNIT', segs)
  return uid
::method ingestSeq
  use strict arg uid, parentId, ctx, segs
  prev = self~markerId(ctx, 'START')
  seq = 0
  do s over segs
    seq += 1
    sid = self~shapeId(s~kind, s~family, s~fine)
    iid = self~instanceInsert(uid, parentId, seq, sid, s~line, s~repeat, s~binding, s~consts)
    self~edgeAdd(prev, sid)
    prev = sid
    do sq over s~sequences
      self~ingestSeq(uid, iid, sq[1], sq[2])
    end
  end
  self~edgeAdd(prev, self~markerId(ctx, 'END'))

/* ---- translation edges (between languages) ---- */
::method translateAdd
  use strict arg fromId, toId, n = 1
  self~q('INSERT INTO translate (from_id, to_id, freq, trials, passes) VALUES (?, ?, ?, 0, 0) ON CONFLICT (from_id, to_id) DO UPDATE SET freq = freq + excluded.freq', self~binds(fromId, toId, n))
/* What a node becomes in the other language: rows TO, FREQ, TRIALS, PASSES, most frequent first. */
::method translations
  use strict arg fromId
  return self~q('SELECT to_id AS "TO", freq AS "FREQ", trials AS "TRIALS", passes AS "PASSES" FROM translate WHERE from_id = ? ORDER BY freq DESC, to_id', self~binds(fromId))~rows
/* A test of a translation edge: the prediction from -> to was right or wrong. */
::method translateRecord
  use strict arg fromId, toId, passed
  p = 0
  if passed then p = 1
  self~q('INSERT INTO translate (from_id, to_id, freq, trials, passes) VALUES (?, ?, 0, 1, ?) ON CONFLICT (from_id, to_id) DO UPDATE SET trials = trials + 1, passes = passes + excluded.passes', self~binds(fromId, toId, p))

/* ---- weights ---- */
::method record
  use strict arg fromNode, toNode, passed
  f = self~resolve(fromNode)
  t = self~resolve(toNode)
  p = 0
  if passed then p = 1
  self~q('INSERT INTO weight (from_id, to_id, trials, passes) VALUES (?, ?, 1, ?) ON CONFLICT (from_id, to_id) DO UPDATE SET trials = trials + 1, passes = passes + excluded.passes', self~binds(f, t, p))
/* Edges out of (column FROM) or into (column TO) one node, each with tier and rate. */
::method edges
  use strict arg direction, node
  id = self~resolve(node)
  if direction == 'OUT' then do
    sql = 'SELECT e.to_id AS other, e.freq AS freq, w.trials AS trials, w.passes AS passes,' ,
          '(SELECT sum(x.freq) FROM edge x WHERE x.from_id = e.from_id) AS outfreq' ,
          'FROM edge e LEFT JOIN weight w ON w.from_id = e.from_id AND w.to_id = e.to_id WHERE e.from_id = ?' ,
          'UNION ALL SELECT w.to_id AS other, 0 AS freq, w.trials AS trials, w.passes AS passes, 0 AS outfreq FROM weight w' ,
          'WHERE w.from_id = ? AND NOT EXISTS (SELECT 1 FROM edge e WHERE e.from_id = w.from_id AND e.to_id = w.to_id)'
  end
  else do
    sql = 'SELECT e.from_id AS other, e.freq AS freq, w.trials AS trials, w.passes AS passes,' ,
          '(SELECT sum(x.freq) FROM edge x WHERE x.from_id = e.from_id) AS outfreq' ,
          'FROM edge e LEFT JOIN weight w ON w.from_id = e.from_id AND w.to_id = e.to_id WHERE e.to_id = ?' ,
          'UNION ALL SELECT w.from_id AS other, 0 AS freq, w.trials AS trials, w.passes AS passes, 0 AS outfreq FROM weight w' ,
          'WHERE w.to_id = ? AND NOT EXISTS (SELECT 1 FROM edge e WHERE e.from_id = w.from_id AND e.to_id = w.to_id)'
  end
  r = self~q(sql, self~binds(id, id))
  out = .array~new
  do row over r~rows
    out~append(self~scored(row['OTHER'], row['FREQ'], row['OUTFREQ'], row['TRIALS'], row['PASSES']))
  end
  return out
::method scored
  use strict arg other, freq, outfreq, trials, passes
  if trials == '' then trials = 0
  if passes == '' then passes = 0
  if freq == '' then freq = 0
  if outfreq == '' then outfreq = 0
  d = .directory~new
  d['NODE'] = other
  d['FREQ'] = freq
  d['OUTFREQ'] = outfreq
  d['TRIALS'] = trials
  d['PASSES'] = passes
  select
    when trials > 0 then do
      d['TIER'] = 'TESTED'
      d['RATE'] = passes / trials
      d['SCORE'] = .SlamStore~wilson(passes, trials)
    end
    when outfreq > 0 then do
      d['TIER'] = 'PRIOR'
      d['RATE'] = freq / outfreq
      d['SCORE'] = .SlamStore~wilson(freq, outfreq)
    end
    otherwise do
      d['TIER'] = 'NONE'
      d['RATE'] = 0
      d['SCORE'] = 0
    end
  end
  return d
/* Wilson score interval, lower bound, z = 1.96. */
::method wilson class
  use strict arg k, n
  numeric digits 20
  if n <= 0 then return 0
  z = 1.96
  p = k / n
  z2 = z * z
  centre = p + z2 / (2 * n)
  margin = z * self~sqrt(p * (1 - p) / n + z2 / (4 * n * n))
  lb = (centre - margin) / (1 + z2 / n)
  if lb < 0 then lb = 0
  numeric digits 9
  return format(lb)
::method sqrt class
  use strict arg x
  numeric digits 30
  if x <= 0 then return 0
  g = x
  if g < 1 then g = 1
  do 300
    n = (g + x / g) / 2
    if n = g then leave
    g = n
  end
  numeric digits 20
  return format(g)
::method rate
  use strict arg fromNode, toNode
  t = self~resolve(toNode)
  do d over self~edges('OUT', fromNode)
    if d['NODE'] = t then return d
  end
  return self~scored(t, 0, 0, 0, 0)
/* Best ways into a node: TESTED before PRIOR, then by rate. */
::method entriesInto
  use strict arg node, k = 10
  return self~ranked(self~edges('IN', node), k)
::method successors
  use strict arg node, k = 10
  return self~ranked(self~edges('OUT', node), k)
::method ranked
  use strict arg list, k
  out = .array~new
  do d over list
    out~append(d)
  end
  out~sortWith(.SlamEdgeOrder~new)
  if out~items > k then out = out~section(1, k)
  return out

/* A result kept with its reason: a failed run teaches as much as a passed one. Also scores the edge. */
::method lesson
  use strict arg fromNode, toNode, passed, predicted, reason, data
  f = self~resolve(fromNode)
  t = self~resolve(toNode)
  p = 0
  if passed then p = 1
  self~q('INSERT INTO lesson (from_id, to_id, passed, predicted, reason, data) VALUES (?, ?, ?, ?, ?, ?)', self~binds(f, t, p, predicted, reason, data))
  self~record(f, t, passed)
/* Keep one proof (a .MathProof from SlamCertify, SlamProof.cls) about a node's result on DATA.  Returns its outcome. */
::method proof
  use strict arg node, mathProof, data
  n = self~resolve(node)
  c = mathProof~claim
  claimText = c~kind
  if c~parameter \== .nil then claimText = claimText c~parameter~string
  detail = mathProof~outcome mathProof~status c~kind   /* the store needs no Maths: it only reads the proof */
  if c~expected \== .nil then detail = detail 'expected=' || c~expected~string
  do note over mathProof~notes
    detail = detail '|' note
  end
  self~q('INSERT INTO proof (node_id, claim, outcome, strength, data, detail) VALUES (?, ?, ?, ?, ?, ?)', self~binds(n, claimText, mathProof~outcome, mathProof~status, data, detail))
  return mathProof~outcome
::method codeNode
  use strict arg label
  return self~shapeId('CODE', 'CODE', 'CODE: ' || label)

/* ---- contracts: ability before score ---- */
::method putContract
  use strict arg node, k
  id = self~resolve(node)
  needs = .array~new
  do a over k~args
    needs~append(a['POS'] || ':' || .SlamContract~keys(a['KINDS']))
  end
  sa = 0
  if k~standalone then sa = 1
  /* Rexx/SQL binds an empty string as NULL: "no needs" is stored as '-' */
  needText = needs~makeString('L', ' ')
  if needText == '' then needText = '-'
  self~q('INSERT OR REPLACE INTO contract (node_id, needs, gives, effects, standalone, canon) VALUES (?, ?, ?, ?, ?, ?)', self~binds(id, needText, .SlamContract~keys(k~gives), .SlamContract~keys(k~effects), sa, k~canonicalText))
::method contractOf
  use strict arg node
  id = self~resolve(node)
  r = self~q('SELECT needs AS needs, gives AS gives FROM contract WHERE node_id = ?', self~binds(id))
  if r~rows~items == 0 then return .nil
  d = .directory~new
  needs = .directory~new
  text = r~rows[1]['NEEDS']
  if text == '-' then text = ''
  do i = 1 to text~words
    parse value text~word(i) with pos ':' kinds
    kd = .directory~new
    do k over kinds~makeArray(',')
      if k \== '' then kd[k] = .true
    end
    needs[pos] = kd
  end
  gives = .directory~new
  do k over r~rows[1]['GIVES']~makeArray(',')
    if k \== '' then gives[k] = .true
  end
  d['NEEDS'] = needs
  d['GIVES'] = gives
  return d
/* Can the edge from -> to do the work (to's argument POS takes what from gives)? Nodes without a
   contract are not judged (OK, reason 'no contract'): the gate only refuses what it can explain. */
::method canRun
  use strict arg fromNode, toNode, pos = 1
  out = .directory~new
  out['OK'] = .true
  f = self~contractOf(fromNode)
  t = self~contractOf(toNode)
  if f == .nil | t == .nil then do
    out['REASON'] = 'no contract'
    return out
  end
  if \t['NEEDS']~hasIndex(pos) then do
    out['OK'] = .false
    out['REASON'] = self~canonOf(self~resolve(toNode)) 'takes no argument' pos
    return out
  end
  need = t['NEEDS'][pos]
  do g over f['GIVES']~allIndexes
    if \.SlamContract~satisfies(g, need) then do
      out['OK'] = .false
      out['REASON'] = self~canonOf(self~resolve(toNode)) 'needs' .SlamContract~keys(need) 'at argument' pos || ';' self~canonOf(self~resolve(fromNode)) 'gives' g
      return out
    end
  end
  out['REASON'] = 'gives what is needed'
  return out
/* Edges the code never had: from -> to wherever from gives what to needs at argument 1. Returns the
   number made. freq 0 means no prior: such an edge scores nothing until a test is recorded on it. */
::method makeEdges
  use strict arg nodes
  made = 0
  do a over nodes
    do b over nodes
      if a = b then iterate
      if \self~canRun(a, b, 1)['OK'] then iterate
      if self~scalar('SELECT count(*) AS n FROM edge WHERE from_id = ? AND to_id = ?', self~binds(a, b)) > 0 then iterate
      self~q('INSERT INTO edge (from_id, to_id, freq) VALUES (?, ?, 0)', self~binds(a, b))
      made += 1
    end
  end
  return made

/* ---- corpus ---- */
::method wordId
  use strict arg word
  return self~shapeId('WORD', 'WORD', 'WORD: ' || word~lower)
::method anchor
  use strict arg word, shapeNode, note = ''
  self~q('INSERT OR REPLACE INTO anchor (word_id, shape_id, note) VALUES (?, ?, ?)', self~binds(self~wordId(word), self~resolve(shapeNode), note))

/* ---- reporting ---- */
::method count
  use strict arg sql
  return self~scalar(sql)
::method stats
  d = .directory~new
  d['SHAPES'] = self~count("SELECT count(*) AS n FROM shape WHERE kind NOT IN ('MARK', 'WORD')")
  d['FAMILIES'] = self~count("SELECT count(DISTINCT family) AS n FROM shape WHERE kind NOT IN ('MARK', 'WORD')")
  d['WORDS'] = self~count("SELECT count(*) AS n FROM shape WHERE kind = 'WORD'")
  d['UNITS'] = self~count('SELECT count(*) AS n FROM unit')
  d['INSTANCES'] = self~count('SELECT count(*) AS n FROM instance')
  d['EDGES'] = self~count('SELECT count(*) AS n FROM edge')
  d['WEIGHTS'] = self~count('SELECT count(*) AS n FROM weight')
  return d
::method topShapes
  use strict arg k = 10
  r = self~q("SELECT s.id AS id, s.canon AS canon, count(i.id) AS n FROM shape s JOIN instance i ON i.shape_id = s.id WHERE s.kind NOT IN ('MARK', 'WORD') GROUP BY s.id ORDER BY n DESC LIMIT ?", self~binds(k))
  return r~rows

/* Tier first (TESTED > PRIOR > NONE), then SCORE (Wilson lower bound), then frequency. */
::class SlamEdgeOrder public
::method compare
  use strict arg a, b
  ra = wordpos(a['TIER'], 'NONE PRIOR TESTED')
  rb = wordpos(b['TIER'], 'NONE PRIOR TESTED')
  if ra \= rb then return rb - ra
  if a['SCORE'] > b['SCORE'] then return -1
  if a['SCORE'] < b['SCORE'] then return 1
  if a['FREQ'] > b['FREQ'] then return -1
  if a['FREQ'] < b['FREQ'] then return 1
  return 0
