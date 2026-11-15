/* MailNudger.cls -- tell a chat it has mail, so Tom no longer types "you have mail".
 *
 * Architecture: Tom Dyer (15 Nov 2026: "get messages to notify the appropriate chat using a nudge on ChatGPT and
 * Claude so that chats clear their messages").  Coding: Claude (Opus 5.5), 15 November 2026.
 *
 * Classes
 *   MailJournal    the mailbox's append-only journal (state/mailbox-journal.jsonl), read directly and read-only on
 *                  the machine that runs the mailbox, incrementally.  Never writes, never marks anything read.
 *   ChatBindings   which chat reads which lane: etc/nudge.conf (and var/nudge.local.conf), one line per chat:
 *                    LANE|ADAPTER|CHAT                (principal from the adapter: claude=CLAUDE, chatgpt=CHATGPT)
 *                    LANE|PRINCIPAL|ADAPTER|CHAT      (e.g. the coordinator chat: *|COORDINATOR|chatgpt|/c/...)
 *                  LANE * : every lane not bound by name for that principal (the coordinator's chat reads them all)
 *                  CHAT is the conversation's path (/c/<id>, /chat/<uuid>: preferred, titles change) or its title.
 *   NudgeState     what was nudged when, kept in var/mail-nudge-state.tsv so a restart nudges nothing twice
 *   MailNudger     one pass: for every bound chat, the requests waiting for it; decide; nudge; record
 *   CommandNudger  the real nudges: browser-ui.rex mailbatch ADAPTER --for MAILNUDGE --jobs FILE, one browser run
 *                  per adapter per pass for all of its chats (opened once, closed once)
 *
 * What waits for a chat (lane L, principal P): a request in lane L addressed to P (or to the lane's mailbox,
 * component:L, sent by someone else), not marked read by P and not answered by P.  Missives (recipient *) are
 * not nudged.  Every Claude chat is CLAUDE and every ChatGPT chat CHATGPT, so the lane is what picks the chat.
 *
 * The nudge is fixed text naming the lane and the request ids only.  No subject or body from the mailbox is
 * ever typed into a chat: message text is data, and a nudge must not carry instructions written by a sender.
 *
 * Rules (etc/mail-nudge.conf):
 *   min_interval_minutes  a chat is nudged at most this often (new mail is batched into one nudge)
 *   renudge_minutes       the same unread set is nudged again after this long ...
 *   max_renudges          ... this many times; then the chat is STALLED (logged once, Tom looks)
 *   max_thread_hops       loop guard: a thread with this many requests since Tom last wrote in it is HELD (two
 *                         agents answering each other for ever).  Tom writing in the thread, or
 *                         "mailnudge.rex release REQ-ID", lets it go on
 *   lane_hourly_cap, daily_cap   hard ceilings on nudges
 *   busy chat (a reply is streaming): not typed into; tried again on the next pass
 */

/* ------------------------------------------------------------------------------------------------------------ */
::class MailJournal public
::method module_version class
  return "0.4.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.4.0"
::method module_lastChanged
  return "2026-11-15"
::attribute requests get        /* requestId -> .directory (the REQUEST_CREATED event) */
::attribute order get           /* request ids, journal order */
::attribute readers get         /* requestId -> blank-separated principals that marked it read */
::attribute answeredBy get      /* requestId -> blank-separated principals that replied to it */
::attribute thread get          /* root requestId -> .array of request ids in the thread, journal order */
::attribute bad get             /* unreadable lines seen */
::method init
  expose path pos requests order readers answeredBy thread bad
  use strict arg path
  pos=1
  requests=.directory~new; order=.array~new; readers=.directory~new; answeredBy=.directory~new
  thread=.directory~new; bad=0

/* Read what was appended since the last call.  A journal that got shorter (replaced) is read again from the
 * start.  A last line without its newline is left for the next call. */
::method refresh
  expose path pos requests order readers answeredBy thread bad
  if \SysFileExists(path) then return .false
  size=stream(path, 'c', 'query size')
  if size<pos-1 then do
    pos=1
    requests=.directory~new; order=.array~new; readers=.directory~new; answeredBy=.directory~new
    thread=.directory~new; bad=0
  end
  if size<pos then return .true
  s=.stream~new(path)
  s~open('read shared')
  chunk=s~charin(pos, size-pos+1)
  s~close
  last=chunk~lastPos('0a'x)
  if last==0 then return .true
  pos=pos+last
  do line over chunk~left(last-1)~makeArray('0a'x)
    if line~strip=='' then iterate
    e=mnParse(line)
    if e==.nil then do
      bad=bad+1
      iterate
    end
    self~apply(e)
  end
  return .true

::method apply
  expose requests order readers answeredBy thread
  use strict arg e
  type=mnField(e, 'eventType')
  if type=='REQUEST_CREATED' then do
    id=mnField(e, 'requestId')
    if id=='' then return
    requests[id]=e
    order~append(id)
    root=mnField(e, 'rootRequestId')
    if root=='' then root=mnField(e, 'parentRequestId')
    if root=='' then root=id
    if \thread~hasIndex(root) then thread[root]=.array~new
    thread[root]~append(id)
    parent=mnField(e, 'parentRequestId')
    if parent<>'' then do
      sender=mnField(e, 'senderId')~upper
      have=mnField(answeredBy, parent)
      if wordpos(sender, have)==0 then answeredBy[parent]=(have sender)~strip
    end
  end
  else if type=='REQUEST_READ' then do
    id=mnField(e, 'requestId')
    who=mnField(e, 'readerId')~upper
    have=mnField(readers, id)
    if wordpos(who, have)==0 then readers[id]=(have who)~strip
  end

/* The thread a request belongs to. */
::method rootOf
  expose requests
  use strict arg id
  e=requests[id]
  if e==.nil then return id
  root=mnField(e, 'rootRequestId')
  if root=='' then root=mnField(e, 'parentRequestId')
  if root=='' then root=id
  return root

/* Requests in the thread after the last one TOM sent (all of them if TOM never wrote in it). */
::method hopsSinceTom
  expose thread requests
  use strict arg root
  ids=thread[root]
  if ids==.nil then return 0
  n=0
  do id over ids
    if mnField(requests[id], 'senderId')~upper=='TOM' then n=0
    else n=n+1
  end
  return n

/* Ids waiting for principal P in lane L, journal order. */
::method waiting
  expose order requests readers answeredBy
  use strict arg lane, principal, since='', except=''
  out=.array~new
  do id over order
    e=requests[id]
    l=mnField(e, 'componentId')~lower
    if lane=='*' then do
      if wordpos(l, except)>0 then iterate
    end
    else if l<>lane~lower then iterate
    to=mnField(e, 'recipientId')~upper
    from=mnField(e, 'senderId')~upper
    if to=='*' then iterate
    /* the lane's own mailbox: the service stores "component:<lane>" (an owned lane's posts go to its owner) */
    if to=='' | to~left(10)=='COMPONENT:' then do
      if lane=='*' then iterate                /* a lane's own mailbox is for the chat of that lane */
      if from==principal then iterate
    end
    else if to<>principal then iterate
    if wordpos(principal, mnField(readers, id))>0 then iterate
    if wordpos(principal, mnField(answeredBy, id))>0 then iterate
    if since<>'' then if mnField(e, 'occurredAt')<<since then iterate
    out~append(id)
  end
  return out

/* The lanes of these requests, blank-separated, first-seen order. */
::method lanesOf
  expose requests
  use strict arg ids
  out=''
  do id over ids
    l=mnField(requests[id], 'componentId')~lower
    if wordpos(l, out)==0 then out=(out l)~strip
  end
  return out

/* Every (lane, principal) with something waiting, for the principals given: .directory "lane|P" -> count. */
::method waitingEverywhere
  expose order requests readers answeredBy
  use strict arg principals, since=''
  out=.directory~new
  do id over order
    e=requests[id]
    to=mnField(e, 'recipientId')~upper
    if to=='' | to=='*' then iterate
    if wordpos(to, principals)==0 then iterate
    if wordpos(to, mnField(readers, id))>0 then iterate
    if wordpos(to, mnField(answeredBy, id))>0 then iterate
    if since<>'' then if mnField(e, 'occurredAt')<<since then iterate
    k=mnField(e, 'componentId')~lower'|'to
    if out~hasIndex(k) then out[k]=out[k]+1
    else out[k]=1
  end
  return out

/* ------------------------------------------------------------------------------------------------------------ */
::class ChatBinding public
::method module_version class
  return "0.4.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.4.0"
::method module_lastChanged
  return "2026-11-15"
::attribute lane get
::attribute principal get
::attribute adapter get
::attribute chat get
::attribute key get
::method init
  expose lane principal adapter chat key
  use strict arg lane, principal, adapter, chat
  key=lane'|'principal
::method string
  expose lane principal adapter chat
  return lane'|'principal'|'adapter'|'chat

::class ChatBindings public
::method module_version class
  return "0.4.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.4.0"
::method module_lastChanged
  return "2026-11-15"
::attribute bindings get        /* .array of ChatBinding, file order */
::attribute problems get        /* .array of text: lines that were refused */
::method init
  expose bindings problems
  use strict arg files
  bindings=.array~new
  problems=.array~new
  seen=.directory~new
  do file over files
    if \SysFileExists(file) then iterate
    s=.stream~new(file)
    s~open('read')
    n=0
    do while s~lines>0
      l=s~linein~strip
      n=n+1
      if l=='' then iterate
      if l~left(1)=='#' then iterate
      parts=l~makeArray('|')
      if parts~items==3 then do
        adapter=parts[2]~strip~lower
        principal=mnPrincipalFor(adapter)
        chat=parts[3]~strip
      end
      else if parts~items==4 then do
        principal=parts[2]~strip~upper
        adapter=parts[3]~strip~lower
        chat=parts[4]~strip
      end
      else do
        problems~append(file':'n': needs LANE|ADAPTER|CHAT or LANE|PRINCIPAL|ADAPTER|CHAT:' l)
        iterate
      end
      lane=parts[1]~strip~lower
      why=mnBindingProblem(lane, principal, adapter, chat)
      if why<>'' then do
        problems~append(file':'n':' why':' l)
        iterate
      end
      b=.ChatBinding~new(lane, principal, adapter, chat)
      /* a later file (var/nudge.local.conf) replaces an earlier line for the same lane and principal */
      if seen~hasIndex(b~key) then bindings~removeItem(seen[b~key])
      seen[b~key]=b
      bindings~append(b)
    end
    s~close
  end
  bindings=bindings~makeArray             /* no holes after removeItem */
::method find
  expose bindings
  use strict arg lane, principal
  do b over bindings
    if b~lane==lane~lower then if b~principal==principal~upper then return b
  end
  /* a chat bound to every lane for this principal (e.g. the coordinator: *|COORDINATOR|chatgpt|/c/...) */
  do b over bindings
    if b~lane=='*' then if b~principal==principal~upper then return b
  end
  return .nil
/* The lanes bound to this principal by name (not *), blank-separated. */
::method lanesBoundTo
  expose bindings
  use strict arg principal
  out=''
  do b over bindings
    if b~principal==principal~upper then if b~lane<>'*' then out=out b~lane
  end
  return out~strip

/* ------------------------------------------------------------------------------------------------------------ */
/* var/mail-nudge-state.tsv:
 *   CHAT  key  lastNudge(epoch s)  ids(comma)  renudges  stalled(0/1)  hourStart  hourCount  backoffUntil
 *   DAY   yyyymmdd  count
 *   RELEASE  root  baseline
 *   HELD  requestId                       (logged once)                                                      */
::class NudgeState public
::method module_version class
  return "0.4.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.4.0"
::method module_lastChanged
  return "2026-11-15"
::attribute chats get
::attribute releases get
::attribute held get
::attribute day get
::attribute dayCount get
::method init
  expose file chats releases held day dayCount
  use strict arg file
  chats=.directory~new; releases=.directory~new; held=.directory~new; day=''; dayCount=0
  if \SysFileExists(file) then return
  s=.stream~new(file)
  s~open('read')
  do while s~lines>0
    c=s~linein~makeArray('09'x)
    if c~items==0 then iterate
    select
      when c[1]=='CHAT' & c~items>=10 then do
        d=.directory~new
        d['last']=c[3]; d['ids']=c[4]; d['renudges']=c[5]; d['stalled']=c[6]
        d['hourStart']=c[7]; d['hourCount']=c[8]; d['backoff']=c[9]; d['adapter']=c[10]
        chats[c[2]]=d
      end
      when c[1]=='DAY' & c~items>=3 then do
        day=c[2]; dayCount=c[3]
      end
      when c[1]=='RELEASE' & c~items>=3 then releases[c[2]]=c[3]
      when c[1]=='HELD' & c~items>=2 then held[c[2]]=1
      otherwise nop
    end
  end
  s~close
::method chat
  expose chats
  use strict arg key, adapter=''
  if \chats~hasIndex(key) then do
    d=.directory~new
    d['last']=0; d['ids']=''; d['renudges']=0; d['stalled']=0; d['hourStart']=0; d['hourCount']=0
    d['backoff']=0; d['adapter']=adapter
    chats[key]=d
  end
  return chats[key]
::method countToday
  expose day dayCount
  use strict arg today
  if day<>today then do
    day=today; dayCount=0
  end
  return dayCount
::method addToday
  expose day dayCount
  use strict arg today
  if day<>today then do
    day=today; dayCount=0
  end
  dayCount=dayCount+1
::method unaddToday
  expose day dayCount
  use strict arg today
  if day==today then if dayCount>0 then dayCount=dayCount-1
::method release
  expose releases
  use strict arg root, baseline
  releases[root]=baseline
::method save
  expose file chats releases held day dayCount
  tmp=file'.tmp'
  s=.stream~new(tmp)
  s~open('write replace')
  s~lineout('# mail nudge state: written by MailNudger.cls; delete it to start afresh')
  do k over chats~allIndexes~sort
    d=chats[k]
    s~lineout('CHAT'||'09'x||k||'09'x||d['last']||'09'x||d['ids']||'09'x||d['renudges']||'09'x||d['stalled']||'09'x||d['hourStart']||'09'x||d['hourCount']||'09'x||d['backoff']||'09'x||d['adapter'])
  end
  if day<>'' then s~lineout('DAY'||'09'x||day||'09'x||dayCount)
  do k over releases~allIndexes~sort
    s~lineout('RELEASE'||'09'x||k||'09'x||releases[k])
  end
  do k over held~allIndexes~sort
    s~lineout('HELD'||'09'x||k)
  end
  s~close
  address system 'mv -f' mnQ(tmp) mnQ(file)

/* ------------------------------------------------------------------------------------------------------------ */
/* Notices when binding files change (Tom, 15 Nov 2026: "check for changes in the file and reload"): the size and
 * modification time of each file, compared with the last look.  A file that appears or disappears is a change. */
::class BindingWatch public
::method module_version class
  return "0.4.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.4.0"
::method module_lastChanged
  return "2026-11-15"
::method init
  expose files last
  use strict arg files
  last=self~signature
::method signature
  expose files
  sig=''
  do f over files
    if SysFileExists(f) then sig=sig||f'='stream(f, 'c', 'query timestamp')'/'stream(f, 'c', 'query size')';'
    else sig=sig||f'=none;'
  end
  return sig
/* .true once after each change */
::method changed
  expose last
  now=self~signature
  if now==last then return .false
  last=now
  return .true

/* ------------------------------------------------------------------------------------------------------------ */
::class MailNudger public
::method module_version class
  return "0.4.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.4.0"
::method module_lastChanged
  return "2026-11-15"
::attribute journal get
::attribute bindings           /* settable: bin/mailnudge.rex swaps in reloaded bindings between passes */
::attribute state get
::method init
  expose journal bindings state rules sender log
  use strict arg journal, bindings, state, rules, sender, log
  /* rules: .directory of numbers and words; defaults where absent */
  do kv over .array~of('min_interval_minutes 10', 'renudge_minutes 60', 'max_renudges 2', 'max_thread_hops 12', -
                       'lane_hourly_cap 6', 'daily_cap 200', 'max_ids_in_nudge 8', 'backoff_minutes 5')
    parse var kv k v
    if \rules~hasIndex(k) then rules[k]=v
    else if \datatype(rules[k], 'W') then rules[k]=v
  end
  if \rules~hasIndex('since') then rules['since']=''

/* One pass at time now (epoch seconds).  Returns .array of decision lines, also logged.
 * Two steps (Tom, 15 Nov 2026: do not open and close the browser for each of several nudges): first every chat is
 * decided; then the nudges are made, one browser run per adapter for all of that adapter's chats, closed once
 * they are done; then each result is recorded. */
::method pass
  expose journal bindings state rules sender log
  use strict arg now, dry=.false
  numeric digits 18
  out=.array~new
  ok=journal~refresh
  if \ok then do
    out~append('STOP journal not found')
    log~error('the mailbox journal was not found')
    return out
  end
  today=mnDay(now)
  decided=.array~new
  jobs=.array~new
  do b over bindings~bindings
    d=self~consider(b, now, today, dry)
    decided~append(d)
    if d~isA(.Directory) then jobs~append(d)
  end
  results=.directory~new
  if jobs~items>0 then results=sender~nudgeAll(jobs)
  do d over decided
    line=d
    if d~isA(.Directory) then do
      r=results[d['binding']~key]
      if r==.nil then r='no result'
      line=self~commit(d, r, now, today)
    end
    if line<>'' then do
      out~append(line)
      if line~word(1)=='NUDGED' | line~word(1)=='WOULD' then log~info(line)
      else if wordpos(line~word(1), 'STALLED HELD FAILED CAPPED')>0 then log~warn(line)
      else log~trace(line)
    end
  end
  if \dry then state~save
  return out

/* Record what happened to one nudge job. */
::method commit
  expose state rules
  use strict arg job, r, now, today
  numeric digits 18
  b=job['binding']; c=job['chat']; shown=job['shown']; more=job['more']; isNew=job['isNew']
  select
    when r=='sent' then do
      if isNew then c['renudges']=0
      else c['renudges']=c['renudges']+1
      c['last']=now; c['ids']=job['set']; c['stalled']=0; c['backoff']=0
      kind='NUDGED'
      if \isNew then kind='NUDGED (again,' c['renudges'] 'of' rules['max_renudges']')'
      return (kind b~key 'in' b~adapter b~chat':' shown~makeString('L', ' ') mnMore(more))~strip
    end
    when r=='busy' then do
      call uncount c, state, today
      return 'BUSY' b~key 'a reply is streaming; next pass'
    end
    otherwise do
      call uncount c, state, today
      c['backoff']=now+rules['backoff_minutes']*60
      return 'FAILED' b~key 'nudge failed ('r'); backing off' rules['backoff_minutes'] 'min'
    end
  end

/* A decision line, or a .directory nudge job (binding, chat state, shown ids, more, isNew, set). */
::method consider
  expose journal state rules sender log
  use strict arg b, now, today, dry
  numeric digits 18
  c=state~chat(b~key, b~adapter)
  except=''
  if b~lane=='*' then except=self~bindings~lanesBoundTo(b~principal)
  waiting=journal~waiting(b~lane, b~principal, rules['since'], except)
  /* loop guard: hold requests in threads that ran too long without Tom */
  ids=.array~new
  held=.array~new
  do id over waiting
    root=journal~rootOf(id)
    hops=journal~hopsSinceTom(root)
    base=state~releases[root]
    if base<>.nil then hops=hops-base
    if hops>=rules['max_thread_hops'] then do
      held~append(id)
      if \state~held~hasIndex(id) then do
        state~held[id]=1
        log~warn(id 'in thread' root 'is HELD:' hops 'requests since Tom last wrote in it (max_thread_hops' rules['max_thread_hops']'); release with: mailnudge.rex release' id)
      end
    end
    else ids~append(id)
  end
  if ids~items==0 then do
    if c['ids']<>'' then do
      c['ids']=''; c['renudges']=0; c['stalled']=0
      return 'CLEARED' b~key '(nothing waiting)'
    end
    if held~items>0 then return 'HELD' b~key held~items 'request(s) held by the loop guard'
    return ''
  end
  set=ids~makeString('L', ',')
  isNew=.false
  do id over ids
    if wordpos(id, c['ids']~translate(' ', ','))==0 then isNew=.true
  end
  since=now-c['last']
  if c['backoff']>now then return 'WAIT' b~key 'backing off after a failed nudge'
  if isNew then do
    if since<rules['min_interval_minutes']*60 then return 'WAIT' b~key ids~items 'waiting; nudged' format(since/60,,0) 'min ago'
  end
  else do
    if c['stalled']==1 then return ''
    if since<rules['renudge_minutes']*60 then return ''
    if c['renudges']>=rules['max_renudges'] then do
      c['stalled']=1
      return 'STALLED' b~key ids~items 'request(s) still unread after' c['renudges']+1 'nudges:' set
    end
  end
  /* caps */
  if now-c['hourStart']>=3600 then do
    c['hourStart']=now; c['hourCount']=0
  end
  if c['hourCount']>=rules['lane_hourly_cap'] then return 'CAPPED' b~key 'lane_hourly_cap' rules['lane_hourly_cap'] 'reached'
  if state~countToday(today)>=rules['daily_cap'] then return 'CAPPED' b~key 'daily_cap' rules['daily_cap'] 'reached'
  shown=.array~new
  do id over ids
    if shown~items<rules['max_ids_in_nudge'] then shown~append(id)
  end
  more=ids~items-shown~items
  if dry then return ('WOULD nudge' b~key 'in' b~adapter b~chat':' shown~makeString('L', ' ') mnMore(more))~strip
  /* caps count this nudge now, so the jobs of one pass stay inside them */
  state~addToday(today)
  c['hourCount']=c['hourCount']+1
  job=.directory~new
  job['binding']=b; job['chat']=c; job['shown']=shown; job['more']=more; job['isNew']=isNew; job['set']=set
  return job

/* Lanes with mail waiting for a nudgeable principal and no chat bound: what Tom should bind. */
::method unbound
  expose journal bindings rules
  use strict arg principals
  ok=journal~refresh
  out=.array~new
  w=journal~waitingEverywhere(principals, rules['since'])
  do k over w~allIndexes~sort
    parse var k lane '|' p
    if bindings~find(lane, p)==.nil then out~append(left(lane, 28) left(p, 12) w[k] 'waiting')
  end
  return out

/* Release a held thread: its hop count starts again from now. */
::method release
  expose journal state
  use strict arg id
  ok=journal~refresh
  root=journal~rootOf(id)
  state~release(root, journal~hopsSinceTom(root))
  do x over state~held~allIndexes
    if journal~rootOf(x)==root then state~held~remove(x)
  end
  state~save
  return root

/* ------------------------------------------------------------------------------------------------------------ */
/* The real nudge: one browser-ui.rex run.  Exit 0 = sent, 3 = busy (nothing typed), anything else = failed. */
::class CommandNudger public
::method module_version class
  return "0.4.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.4.0"
::method module_lastChanged
  return "2026-11-15"
::method init
  expose cmd log jobDir
  use strict arg cmd, log, jobDir
/* All of one pass's nudges: one browser-ui.rex mailbatch run per adapter (one browser, every chat of that adapter
 * nudged in turn, closed once at the end).  Returns .directory binding key -> sent | busy | failed text. */
::method nudgeAll
  expose cmd log jobDir
  use strict arg jobs
  results=.directory~new
  adapters=''
  do job over jobs
    if wordpos(job['binding']~adapter, adapters)==0 then adapters=adapters job['binding']~adapter
  end
  do adapter over adapters~strip~makeArray(' ')
    file=jobDir'/mail-batch-'adapter'.tsv'
    s=.stream~new(file)
    s~open('write replace')
    n=0
    do job over jobs
      b=job['binding']
      if b~adapter<>adapter then iterate
      lane=b~lane
      if lane=='*' then lane='ALL'           /* never a bare * on a command line */
      line=b~key||'09'x||b~chat||'09'x||lane||'09'x||job['shown']~makeString('L', ' ')
      if job['more']>0 then line=line '+'job['more']
      s~lineout(line)
      n=n+1
    end
    s~close
    log~info('nudging' n 'chat(s) in one' adapter 'browser run')
    address system cmd adapter '--for MAILNUDGE --jobs' mnQ(file) with output stem o.
    runRc=rc
    do i=1 to o.0
      if o.i~left(7)=='RESULT'||'09'x then do
        parse var o.i . '09'x key '09'x what
        results[key]=what
      end
      else log~trace(adapter':' o.i)
    end
    do job over jobs
      k=job['binding']~key
      if job['binding']~adapter==adapter then if \results~hasIndex(k) then results[k]='rc' runRc
    end
  end
  return results

/* ------------------------------------------------------------------------------------------------------------ */
/* The nudge text: lane and request ids only (validated), never mailbox text. */
::routine mnNudgeText public
  use strict arg lane, ids, more=0
  if lane=='ALL' then t='You have mail on Rasen Falcon:' ids~makeString('L', ', ')
  else t='You have mail on Rasen Falcon, lane' lane':' ids~makeString('L', ', ')
  if more>0 then t=t 'and' more 'more'
  if lane=='ALL' then return t'. Read them with project.requests.list (unreadOnly true), act on each, reply, and mark each read.'
  return t'. Read them with project.requests.list (componentId' lane', unreadOnly true), act on each, reply, and mark each read.'

/* a decided nudge that was not sent does not count against the caps */
::routine uncount
  use strict arg c, state, today
  if c['hourCount']>0 then c['hourCount']=c['hourCount']-1
  state~unaddToday(today)
  return

::routine mnMore public
  use strict arg more
  if more>0 then return '(+'more 'more)'
  return ''

::routine mnPrincipalFor public
  use strict arg adapter
  select
    when adapter=='claude' then return 'CLAUDE'
    when adapter=='chatgpt' then return 'CHATGPT'
    otherwise return ''
  end

/* '' if the binding is acceptable, else why not */
::routine mnBindingProblem public
  use strict arg lane, principal, adapter, chat
  if lane<>'*' then if \mnIsLane(lane) then return 'lane' lane 'is not a lane id (a-z 0-9 - _, starting with a letter, 2-40), nor * (every lane)'
  if principal=='' | principal~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-')>0 then return 'principal' principal 'is not a principal name'
  if adapter~verify('abcdefghijklmnopqrstuvwxyz0123456789-_')>0 | adapter=='' then return 'adapter' adapter 'is not an adapter name'
  if chat=='' then return 'no chat given'
  if chat~left(1)=='/' then do
    if \mnIsChatPath(chat) then return 'chat path' chat 'may hold only letters, digits, / - _'
  end
  else if chat~verify(' 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_.,:()') >0 then return 'chat title' chat 'has characters a command line could misread'
  return ''

/* https://chatgpt.com/c/<id> or https://claude.ai/chat/<uuid> -> .array(adapter, path); .nil if neither */
::routine mnChatFromUrl public
  use strict arg url
  parse var url scheme '://' host '/' rest
  parse var rest rest '?' .
  parse var rest rest '#' .
  host=host~lower
  if scheme~lower<>'https' then return .nil
  if host=='chatgpt.com' | host=='www.chatgpt.com' then adapter='chatgpt'
  else if host=='claude.ai' then adapter='claude'
  else return .nil
  path='/'rest~strip('T', '/')
  if \mnIsChatPath(path) then return .nil
  return .array~of(adapter, path)

::routine mnIsLane public
  use strict arg lane
  if lane~length<2 | lane~length>40 then return .false
  if lane~left(1)~verify('abcdefghijklmnopqrstuvwxyz')>0 then return .false
  return lane~verify('abcdefghijklmnopqrstuvwxyz0123456789-_')==0

::routine mnIsChatPath public
  use strict arg path
  if path~left(1)<>'/' | path~length>120 then return .false
  if path~pos('//')>0 | path~pos('..')>0 then return .false
  return path~verify('/abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_')==0

::routine mnIsRequestId public
  use strict arg id
  if id~left(4)<>'REQ-' then return .false
  return id~substr(5)~verify('0123456789')==0 & id~length>4 & id~length<=20

::routine mnDay public
  use strict arg epoch
  numeric digits 18
  return date('S', trunc(epoch), 'T')

::routine mnNow public
  numeric digits 18
  return time('T')

::routine mnField public
  use strict arg collection, name
  if collection==.nil then return ''
  if \collection~hasIndex(name) then return ''
  v=collection[name]
  if v==.nil then return ''
  return v~string

::routine mnParse public
  use strict arg line
  signal on syntax name unreadable
  v=.json~new~fromJson(line)
  if \v~isA(.Directory) then return .nil
  return v
unreadable:
  return .nil

::routine mnQ public
  use strict arg s
  return "'"s~changeStr("'", "'\''")"'"

::requires 'json.cls'
