/* SlamTask.cls - SLAM v0.1 Task: requirements become steps; turn advances one step by one action.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 *   t = .Task~new("make application for testing ga", store)
 *   t~requirement("reach the goal node", fromNode, toNode [, minTier [, maxDepth]])
 *   r = t~turn          -- one action, one SQLite transaction (BEGIN IMMEDIATE .. COMMIT), one report
 *   r = t~run(budget)   -- turn until DONE or BLOCKED or the budget is spent
 *   t~nodeMap           -- step number -> Array of node ids (the N -> Yn map)
 *
 * v0.1 scope: a requirement names its entry and goal nodes explicitly, and a step is a best-path
 * search over the weighted edge graph. A path's value is the product of its edge SCOREs (Wilson lower bounds, each <= 1),
 * so best-first search on that value is exact. PRODUCT favours short paths (every extra edge can only
 * lower it). BOTTLENECK scores a path by its weakest edge: length-neutral, and best-first stays exact
 * (the widest-path rule). Choose per requirement. minTier TESTED admits only edges with recorded
 * outcomes; PRIOR admits frequency-only edges too. Decomposing English requirements into steps and
 * GA branch selection on run are later increments.
 */

::requires 'SlamStore.cls'

::class SlamStep public
::attribute seq
::attribute text
::attribute fromNode
::attribute toNode
::attribute fromId
::attribute toId
::attribute minTier
::attribute maxDepth
::attribute state
::attribute search
::attribute path
::attribute value
::attribute tier
::attribute rowId
::attribute scoring
::method init
  expose seq text fromNode toNode minTier maxDepth state search path value tier fromId toId rowId scoring
  use strict arg seq, text, fromNode, toNode, minTier = 'PRIOR', maxDepth = 12, scoring = 'PRODUCT'
  state = 'NEW'
  search = .nil
  path = .nil
  value = ''
  tier = ''
  fromId = ''
  toId = ''
  rowId = 0

::class SlamTurnReport public
::attribute task
::attribute turn
::attribute step
::attribute action
::attribute node
::attribute frontier
::attribute detail
::method init
  expose task turn step action node frontier detail
  use strict arg task, turn, step, action, node = '', frontier = 0, detail = ''
::method canonicalText
  expose task turn step action node frontier detail
  n = ''
  if node \== '' then n = '#' || .SlamStore~displayId(node)
  return 'TURN task=' || task '#' || turn 'step=' || step action n 'frontier=' || frontier detail

/* Best-first search for the highest-product path; one expansion per advance. */
::class SlamPathSearch public
::attribute store
::attribute goal
::attribute minTier
::attribute maxDepth
::attribute frontier
::attribute best
::attribute expanded
::attribute scoring
::attribute rejected
::method init
  expose store goal minTier maxDepth frontier best expanded scoring rejected
  use strict arg store, fromId, goal, minTier, maxDepth, scoring = 'PRODUCT'
  if wordpos(scoring, 'PRODUCT BOTTLENECK') == 0 then raise syntax 93.900 array('path scoring must be PRODUCT or BOTTLENECK:' scoring)
  frontier = .array~new
  frontier~append(self~entry(fromId, 1, .array~of(fromId), 'TESTED'))
  /* best[node] = Array of labels .array(value, edges). A new route into a node is dropped only when a
     kept route there is at least as good AND no longer: with a depth limit, a shorter weaker route can
     be the only one that still fits (found by ChatGPT's review). */
  best = .directory~new
  best[fromId] = .array~of(.array~of(1, 0))
  expanded = 0
  rejected = .array~new
::method entry
  use strict arg node, value, path, tier
  e = .directory~new
  e['NODE'] = node
  e['VALUE'] = value
  e['PATH'] = path
  e['TIER'] = tier
  return e
::method weaker
  use strict arg a, b
  if wordpos(a, 'NONE PRIOR TESTED') < wordpos(b, 'NONE PRIOR TESTED') then return a
  return b
/* maxDepth counts edges: a path of maxDepth edges has maxDepth + 1 nodes and is never expanded. */
::method dominated
  expose best
  use strict arg node, value, edges
  if \best~hasIndex(node) then return .false
  do lab over best[node]
    if lab[1] >= value then if lab[2] <= edges then return .true
  end
  return .false
::method keep
  expose best
  use strict arg node, value, edges
  kept = .array~new
  if best~hasIndex(node) then do
    do lab over best[node]
      dropIt = .false
      if value >= lab[1] then if edges <= lab[2] then dropIt = .true
      if \dropIt then kept~append(lab)
    end
  end
  kept~append(.array~of(value, edges))
  best[node] = kept
::method advance
  expose store goal minTier maxDepth frontier best expanded scoring rejected
  out = .directory~new
  out['FRONTIER'] = frontier~items
  if frontier~items == 0 then do
    out['ACTION'] = 'NO_PATH'
    out['NODE'] = ''
    if rejected~items > 0 then out['WHY'] = rejected[1]
    return out
  end
  k = 1
  do i = 2 to frontier~items
    if frontier[i]['VALUE'] > frontier[k]['VALUE'] then k = i
  end
  e = frontier[k]
  frontier~delete(k)
  node = e['NODE']
  out['NODE'] = node
  if node = goal then do
    out['ACTION'] = 'PATH_FOUND'
    out['PATH'] = e['PATH']
    out['VALUE'] = e['VALUE']
    out['TIER'] = e['TIER']
    out['FRONTIER'] = frontier~items
    return out
  end
  if e['PATH']~items > maxDepth then do
    out['ACTION'] = 'DEPTH_LIMIT'
    out['FRONTIER'] = frontier~items
    return out
  end
  expanded += 1
  pushed = 0
  refusedHere = 0
  do d over store~edges('OUT', node)
    /* Ability before score: an edge that cannot do the work is refused before its score is read. */
    can = store~canRun(node, d['NODE'])
    if \can['OK'] then do
      refusedHere += 1
      rejected~append(can['REASON'])
      iterate
    end
    if minTier == 'TESTED' then if d['TIER'] \== 'TESTED' then iterate
    if d['SCORE'] <= 0 then iterate
    if scoring == 'BOTTLENECK' then v = min(e['VALUE'], d['SCORE'])
    else v = e['VALUE'] * d['SCORE']
    n = d['NODE']
    edges = e['PATH']~items
    if self~dominated(n, v, edges) then iterate
    self~keep(n, v, edges)
    p = e['PATH']~copy
    p~append(n)
    frontier~append(self~entry(n, v, p, self~weaker(e['TIER'], d['TIER'])))
    pushed += 1
  end
  out['ACTION'] = 'EXPANDED'
  out['PUSHED'] = pushed
  out['REFUSED'] = refusedHere
  out['FRONTIER'] = frontier~items
  return out

::class Task public
::attribute title get
::attribute id get
::attribute store get
::attribute steps get
::attribute turns get
::attribute state get
::attribute history get
::method init
  expose title id store steps turns state history
  use strict arg title, aStore = .nil
  id = 0
  store = .nil
  steps = .array~new
  turns = 0
  state = 'OPEN'
  history = .array~new
  if aStore \== .nil then self~bind(aStore)
::method bind
  expose title id store steps
  use strict arg aStore
  store = aStore
  store~q('INSERT INTO task (title, state, turns) VALUES (?, ?, 0)', store~binds(title, 'OPEN'))
  id = store~scalar('SELECT last_insert_rowid() AS id')
  do s over steps
    self~persistStep(s)
  end
  return self
::method requirement
  expose steps store
  use strict arg text, fromNode, toNode, minTier = 'PRIOR', maxDepth = 12, scoring = 'PRODUCT'
  s = .SlamStep~new(steps~items + 1, text, fromNode, toNode, minTier~upper, maxDepth, scoring~upper)
  steps~append(s)
  if store \== .nil then self~persistStep(s)
  return s~seq
::method requirements
  forward message('REQUIREMENT')
::method persistStep
  expose store id
  use strict arg s
  s~fromId = store~resolve(s~fromNode)
  s~toId = store~resolve(s~toNode)
  if s~fromId == '' then raise syntax 93.900 array('Task requirement: unknown entry node' s~fromNode)
  if s~toId == '' then raise syntax 93.900 array('Task requirement: unknown goal node' s~toNode)
  store~q('INSERT INTO step (task_id, seq, text, from_id, to_id, min_tier, state) VALUES (?, ?, ?, ?, ?, ?, ?)', store~binds(id, s~seq, s~text, s~fromId, s~toId, s~minTier, s~state))
  s~rowId = store~scalar('SELECT last_insert_rowid() AS id')
::method nodeMap
  expose steps
  d = .directory~new
  do s over steps
    if s~path \== .nil then d[s~seq] = s~path
  end
  return d
::method openStep
  expose steps
  do s over steps
    if s~state == 'NEW' | s~state == 'SEARCHING' then return s
  end
  return .nil
/* One turn: one action on the first open step, persisted in one transaction. */
::method turn
  expose store steps turns state history id
  if store == .nil then raise syntax 93.900 array('Task has no store: bind(store) first')
  if state \== 'OPEN' then return .SlamTurnReport~new(id, turns, 0, state)
  signal on syntax name turnFailed
  store~begin
  n = turns + 1
  step = self~openStep
  if step == .nil then do
    state = 'DONE'
    do s over steps
      if s~state == 'BLOCKED' then state = 'BLOCKED'
    end
    rep = .SlamTurnReport~new(id, n, 0, state)
  end
  else if step~state == 'NEW' then do
    step~search = .SlamPathSearch~new(store, step~fromId, step~toId, step~minTier, step~maxDepth, step~scoring)
    step~state = 'SEARCHING'
    rep = .SlamTurnReport~new(id, n, step~seq, 'STEP_STARTED', step~fromId, 1, 'goal=#' || .SlamStore~displayId(step~toId) 'minTier=' || step~minTier 'scoring=' || step~scoring)
  end
  else do
    r = step~search~advance
    detail = ''
    select
      when r['ACTION'] == 'PATH_FOUND' then do
        step~path = r['PATH']
        step~value = r['VALUE']
        step~tier = r['TIER']
        step~state = 'DONE'
        detail = 'value=' || format(r['VALUE'], , 4) 'tier=' || r['TIER'] 'path=' || self~pathText(r['PATH'])
      end
      when r['ACTION'] == 'NO_PATH' then do
        step~state = 'BLOCKED'
        if r~hasIndex('WHY') then detail = 'cannot run:' r['WHY']
      end
      when r['ACTION'] == 'EXPANDED' then do
        detail = 'pushed=' || r['PUSHED']
        if r['REFUSED'] > 0 then detail = detail 'refused=' || r['REFUSED'] '(' || step~search~rejected[step~search~rejected~items] || ')'
      end
      otherwise nop
    end
    rep = .SlamTurnReport~new(id, n, step~seq, r['ACTION'], r['NODE'], r['FRONTIER'], detail)
    pathIds = ''
    if step~path \== .nil then pathIds = step~path~makeString('L', ' ')
    store~q('UPDATE step SET state = ?, path = ?, value = ? WHERE id = ?', store~binds(step~state, pathIds, step~value, step~rowId))
  end
  store~q('INSERT INTO turn (task_id, n, step_seq, action, node_id, frontier, detail) VALUES (?, ?, ?, ?, ?, ?, ?)', store~binds(id, n, rep~step, rep~action, rep~node, rep~frontier, rep~detail))
  store~q('UPDATE task SET turns = ?, state = ? WHERE id = ?', store~binds(n, state, id))
  store~commit
  turns = n
  history~append(rep)
  return rep
turnFailed:
  if store~inTransaction then store~rollback
  if self~openStep == .nil then state = 'OPEN'
  raise propagate
::method pathText
  use strict arg path
  out = .array~new
  do n over path
    out~append('#' || .SlamStore~displayId(n))
  end
  return out~makeString('L', '>')
::method run
  expose state
  use strict arg budget = 1000
  rep = .nil
  do budget
    rep = self~turn
    if state \== 'OPEN' then leave
  end
  return rep
