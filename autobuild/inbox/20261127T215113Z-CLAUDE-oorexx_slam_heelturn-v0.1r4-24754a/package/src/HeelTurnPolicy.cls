/* HeelTurnPolicy.cls - Heel Turn SLAM: the designer prompt read as settings.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Every directive is an act on an object, with a force (always, should, may),
   a polarity (not, never, avoid) and optional conditions (when they are
   weak) or a time (early, late). policy.src says which settings an act on
   an object moves. A sentence that moves nothing is listed as not read, so
   a choice that rests on it is never taken on trust. */
::requires 'HeelTurnLanguage.cls'

::class HeelTurnPolicy public
::attribute notRead get
::attribute readCount get
::attribute hits get
::method init
  expose knobs conditional notRead readCount hits
  knobs = .directory~new
  defaults = .array~of('aggression=0.5', 'defence=0.5', 'expand=0.6', 'stab=0.2', 'balance=0.4', 'bully=0.5', 'loyal=0.5', 'alliance=0.5', 'allyNear=0.5', 'allyFar=0.4', 'bandwagon=0.3', 'honesty=0.7', 'keepWord=0.6', 'promises=0.5', 'trust=0.5', 'suspicion=0.5', 'retaliate=0.5', 'fleetPref=0.5', 'talk=0.5', 'warmth=0.5', 'brevity=0.5', 'patience=0.5', 'flexibility=0.5', 'openness=0.5', 'memory=0.5')
  do pair over defaults
    parse var pair k '=' v
    knobs[k] = v
  end
  conditional = .directory~new
  notRead = .array~new
  readCount = 0
  hits = .array~new
::method knobNames
  expose knobs
  names = knobs~allIndexes
  return heelTurnSorted(names)
::method value
  -- A setting, with its conditional parts added when their condition holds.
  -- context: directory of condition names that hold now (early, weak, ...).
  expose knobs conditional
  use strict arg knob, context = (.directory~new)
  v = knobs[knob]
  if conditional~hasIndex(knob) then do pair over conditional[knob]
    cond = pair[1]
    wanted = .true
    if cond~left(1) == '!' then do
      wanted = .false
      cond = cond~substr(2)
    end
    holds = context~hasIndex(cond)
    if holds = wanted then v = v + pair[2]
  end
  return heelTurnClip(v)
::method base
  expose knobs
  use strict arg knob
  return knobs[knob]
::method conditionsFor
  expose conditional
  use strict arg knob
  out = .array~new
  if conditional~hasIndex(knob) then do pair over conditional[knob]
    out~append(pair[1]'='pair[2])
  end
  return out
::method adjust
  expose knobs conditional hits
  use strict arg knob, delta, cond, why
  if \knobs~hasIndex(knob) then raise syntax 93.900 array('policy.src names an unknown setting:' knob)
  if cond == '' then knobs[knob] = heelTurnClip(knobs[knob] + delta)
  else do
    if \conditional~hasIndex(knob) then conditional[knob] = .array~new
    conditional[knob]~append(.array~of(cond, delta))
  end
  hits~append(knob'|'format(delta,,2)'|'cond'|'why)
::method markRead
  expose readCount
  readCount += 1
::method markUnread
  expose notRead
  use strict arg sentence, unknown
  notRead~append(sentence'|'unknown)
::method summary
  expose knobs conditional
  out = .array~new
  do k over self~knobNames
    line = k'='format(knobs[k],,2)
    if conditional~hasIndex(k) then do pair over conditional[k]
      line = line'['pair[1]':'format(pair[2],,2)']'
    end
    out~append(line)
  end
  return out~makeString('L', ' ')
::method module_version class
  return '0.1r4'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::class HeelTurnPromptReader public
::method init
  expose reader vocab
  use strict arg reader
  vocab = reader~vocab
::method read
  expose reader
  use strict arg promptText
  policy = .HeelTurnPolicy~new
  do sentence over reader~sentences(promptText)
    items = reader~fixNegverbs(reader~items(sentence))
    before = policy~hits~items
    self~readSentence(items, policy, sentence)
    if policy~hits~items > before then policy~markRead
    else do
      unknown = ''
      do it over items
        if it['K'] == 'UNKNOWN' then unknown = unknown it['T']
      end
      policy~markUnread(sentence, unknown~strip)
    end
  end
  return policy
::method readSentence private
  expose vocab
  use strict arg items, policy, sentence
  n = items~items
  -- condition region: from a condition word to the next comma when the
  -- word opens the sentence, or to the end of the sentence otherwise.
  inCond = .array~new(n)
  do idx = 1 to n
    inCond[idx] = .false
  end
  condNeg = .false
  firstReal = 1
  do while firstReal <= n
    if items[firstReal]['K'] \== 'PUNCT' then leave
    firstReal += 1
  end
  do idx = 1 to n
    if items[idx]['K'] \== 'CONDWORD' then iterate
    if items[idx]['F']~hasIndex('polar') then condNeg = .true
    if idx = firstReal then do
      stop = n
      do k = idx + 1 to n
        if items[k]['K'] == 'PUNCT' then if items[k]['C'] == ',' then do
          stop = k
          leave
        end
        if items[k]['K'] == 'FILLER' then if items[k]['T']~lower == 'then' then do
          stop = k
          leave
        end
      end
    end
    else do
      stop = n
      do k = idx + 1 to n
        if items[k]['K'] == 'JOIN' then if wordpos(items[k]['C'], 'BUT YET') > 0 then do
          stop = k - 1
          leave
        end
        if items[k]['K'] == 'PUNCT' then if items[k]['C'] == ';' then do
          stop = k - 1
          leave
        end
      end
    end
    do k = idx to stop
      inCond[k] = .true
    end
  end
  cond = self~regionTag(items, inCond, condNeg)
  -- time scope from the main part
  do idx = 1 to n
    if inCond[idx] then iterate
    if items[idx]['K'] == 'TIME' then if wordpos(items[idx]['C'], 'early late') > 0 then if cond == '' then cond = items[idx]['C']
  end
  -- a sentence of qualities with no act: "You are a patient, honest player."
  hasAct = .false
  do idx = 1 to n
    if items[idx]['K'] == 'ACT' then hasAct = .true
  end
  if \hasAct then do
    neg = 0
    do idx = 1 to n
      if inCond[idx] then iterate
      if items[idx]['K'] == 'NEGATOR' then neg += 1
      if items[idx]['K'] == 'QUAL' then do
        w = 0.8
        if neg // 2 = 1 then w = -0.8
        self~apply(policy, 'be', .array~of(items[idx]['C']), w, cond, sentence)
      end
    end
    return
  end
  -- main part: acts with their polarity, force and objects
  clauseNeg = 0
  pendingNeg = 0
  force = 0.8
  scale = 1
  others = .false
  speaker = .false
  relative = .false
  seenAct = .false
  do idx = 1 to n
    if inCond[idx] then iterate
    item = items[idx]
    k = item['K']
    select
      when k == 'PUNCT' then do
        if pos(item['C'], ',;:') > 0 then do
          relative = .false
          seenAct = .false
          clauseNeg = 0
          pendingNeg = 0
          force = 0.8
          scale = 1
          others = .false
          speaker = .false
        end
      end
      when k == 'JOIN' then do
        if item['C'] == 'BUT' | item['C'] == 'YET' then do
          relative = .false
          clauseNeg = 0
          force = 0.8
          others = .false
        end
        if item['C'] == 'AND' then clauseNeg = 0
        others = .false
      end
      when k == 'NEGATOR' then clauseNeg += 1
      when k == 'NEGVERB' then pendingNeg += 1
      when k == 'MODAL' then force = heelTurnModalForce(item['C'])
      when k == 'FORCE' then do
        if item['F']~hasIndex('force') then force = item['F']['force']
        if item['F']~hasIndex('scale') then scale = scale * item['F']['scale']
        if item['F']~hasIndex('polar') then clauseNeg += 1
      end
      when k == 'SUBJ' then if wordpos(item['T']~lower, 'they other') > 0 then others = .true
      when k == 'OBJ' & item['C'] == 'others' & \speaker then do
        nextAct = self~nextKind(items, idx, 'ACT MODAL FORCE')
        if nextAct > 0 then others = .true
      end
      when k == 'PRONOUN' then do
        -- after an act, a relative pronoun (a power THAT attacks you) or a
        -- new subject (a province YOU plan to attack) opens a clause that
        -- describes the object: its acts are not directives
        if seenAct then if wordpos(item['C'], 'THAT WHO WHICH WHOM YOU I WE THEY HE SHE IT') > 0 then relative = .true
        if \seenAct then do
          if wordpos(item['C'], 'YOU I WE') > 0 then do
            speaker = .true
            others = .false
          end
          if item['C'] == 'THEY' then others = .true
        end
      end
      when k == 'ACT' & relative then nop
      when k == 'ACT' then do
        seenAct = .true
        -- be followed by a negating verb or another act is only a helper
        if item['C'] == 'be' then do
          nxt = self~nextKind(items, idx, 'ACT NEGVERB QUAL OBJ')
          if nxt > 0 then if wordpos(items[nxt]['K'], 'ACT NEGVERB') > 0 then iterate
        end
        polarity = 1
        if (clauseNeg + pendingNeg) // 2 = 1 then polarity = -1
        -- a negative quantity on the object turns the act down: send FEW messages
        do q = idx + 1 to n
          if inCond[q] then leave
          if wordpos(items[q]['K'], 'ACT PUNCT') > 0 then leave
          if items[q]['K'] == 'FORCE' then if items[q]['F']~hasIndex('polar') then polarity = -polarity
        end
        pendingNeg = 0
        objs = self~objectsAfter(items, idx, inCond)
        if others then do
          self~aboutOthers(policy, item['C'], polarity, force * scale, sentence)
          iterate
        end
        self~apply(policy, item['C'], objs, polarity * force * scale, cond, sentence)
        -- expect frames what follows: "assume every promise is a trap"
        if vocab~isa(item['C'], 'expect') then others = .true
        -- an adverb on another act: expand aggressively
        if item['C'] \== 'be' then do o over objs
          if vocab~isa(o, 'quality') then self~apply(policy, 'be', .array~of(o), 0.5 * polarity * force * scale, cond, sentence)
        end
      end
      otherwise nop
    end
  end
::method nextKind private
  use strict arg items, idx, kinds
  do k = idx + 1 to items~items
    if items[k]['K'] == 'PUNCT' then return 0
    if wordpos(items[k]['K'], kinds) > 0 then return k
  end
  return 0
::method objectsAfter private
  use strict arg items, idx, inCond
  objs = .array~new
  do k = idx + 1 to items~items
    if inCond[k] then leave
    it = items[k]
    if it['K'] == 'ACT' then leave
    if it['K'] == 'PUNCT' then leave
    if it['K'] == 'JOIN' then if self~nextKind(items, k, 'ACT') = k + 1 then leave
    if it['K'] == 'PREP' then if it['C'] == 'OF' then leave
    if it['K'] == 'PRONOUN' then if wordpos(it['C'], 'THAT WHO WHICH WHOM YOU I WE THEY') > 0 then leave
    if wordpos(it['K'], 'OBJ QUAL') > 0 then objs~append(it['C'])
    -- weak players, strong powers: the condition word names the kind of power
    if it['K'] == 'COND' then do
      if it['C'] == 'weak' then objs~append('weakest')
      if it['C'] == 'strong' then objs~append('leader')
    end
    if it['K'] == 'POWER' then objs~append('power')
    if it['K'] == 'PROV' then objs~append('centre')
  end
  return objs
::method apply private
  expose vocab
  use strict arg policy, act, objs, weight, cond, why
  if objs~items = 0 then objs = .array~of('')
  tempo = 'aggression expand bully defence stab balance'
  seen = .directory~new
  do o over objs
    rules = vocab~rulesFor(act, o)
    do rule over rules
      key = rule[1]'|'o
      if seen~hasIndex(key) then iterate
      seen[key] = 1
      useCond = cond
      if wordpos(cond, 'early late') > 0 then if wordpos(rule[1], tempo) = 0 then useCond = ''
      policy~adjust(rule[1], rule[2] * weight, useCond, act'/'o)
    end
  end
::method aboutOthers private
  -- What others will do is not a directive. "Others will lie" or "expect to
  -- be stabbed" raises suspicion; "others can be trusted" lowers it.
  expose vocab
  use strict arg policy, act, polarity, force, why
  if vocab~isa(act, 'lie') | vocab~isa(act, 'betray') | vocab~isa(act, 'attack') | vocab~isa(act, 'break') then do
    policy~adjust('suspicion', 0.4 * polarity * force, '', 'others/'act)
    return
  end
  if vocab~isa(act, 'keep') | vocab~isa(act, 'truth') | vocab~isa(act, 'support') | vocab~isa(act, 'ally') then do
    policy~adjust('suspicion', -0.3 * polarity * force, '', 'others/'act)
    return
  end
  if vocab~isa(act, 'trust') then do
    policy~adjust('trust', 0.2 * polarity * force, '', 'others/'act)
    return
  end
::method regionTag private
  -- One condition for the region, by priority: a condition word (weak,
  -- betrayed), then gain (it gains a centre), attacked, betrayed, leader, a
  -- time. A not inside the region, or unless, makes it the opposite.
  expose vocab
  use strict arg items, inCond, condNeg
  n = items~items
  any = .false
  neg = 0
  found = .directory~new
  do idx = 1 to n
    if \inCond[idx] then iterate
    any = .true
    it = items[idx]
    if it['K'] == 'NEGATOR' then neg += 1
    if it['K'] == 'CONDWORD' then if it['F']~hasIndex('order') then found['ORDER'] = 1
    if it['K'] == 'COND' then if \found~hasIndex('C1') then found['C1'] = it['C']
    if it['K'] == 'TIME' then if wordpos(it['C'], 'early late') > 0 then found['C6'] = it['C']
    if it['K'] == 'OBJ' then if it['C'] == 'leader' then found['C5'] = 'leader'
    if it['K'] == 'ACT' then do
      c = it['C']
      if vocab~isa(c, 'keep') | vocab~isa(c, 'truth') then found['C4K'] = 'kept'
      if vocab~isa(c, 'expand') | vocab~isa(c, 'win') then found['C2'] = 'gain'
      else if vocab~isa(c, 'betray') | vocab~isa(c, 'lie') | vocab~isa(c, 'break') then found['C4'] = 'betrayed'
      else if vocab~isa(c, 'attack') then do
        tag = 'attacked'
        do k = idx + 1 to n
          if \inCond[k] then leave
          if items[k]['K'] == 'OBJ' then if vocab~isa(items[k]['C'], 'centre') then tag = 'gain'
        end
        if tag == 'gain' then found['C2'] = tag
        else found['C3'] = tag
      end
    end
  end
  if \any then return ''
  -- before / after order the steps; they set no condition
  if found~hasIndex('ORDER') then return ''
  tag = 'needed'
  do key over .array~of('C1', 'C2', 'C3', 'C4', 'C4K', 'C5', 'C6')
    if found~hasIndex(key) then do
      tag = found[key]
      leave
    end
  end
  flip = condNeg
  if neg // 2 = 1 then flip = \flip
  if flip then return '!'tag
  return tag
::method module_version class
  return '0.1r4'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine heelTurnModalForce public
  use strict arg modal
  select
    when wordpos(modal, 'MUST SHALL WILL') > 0 then return 1.0
    when modal == 'SHOULD' then return 0.7
    when modal == 'WOULD' then return 0.6
    otherwise return 0.4
  end

