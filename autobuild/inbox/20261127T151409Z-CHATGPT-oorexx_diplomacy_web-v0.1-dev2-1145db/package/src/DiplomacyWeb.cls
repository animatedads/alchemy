/* Architecture: Tom Dyer. UI consumer, not a referee. No raw API keys,
   raw journals or opponent task submissions are projected across Wire. */
::class DiplomacyWeb public
::method init
  expose people keys games seq powers profiles
  profiles=.directory~new
  people=.directory~new
  keys=.directory~new
  games=.directory~new
  seq=0
  powers=.array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
::method register
  expose people
  use strict arg principal,display
  /* principal has already been verified by the identity authority */
  if principal='' | display~strip='' | display~length>80 then return 'INVALID_IDENTITY'
  if people~hasIndex(principal) then return 'ALREADY_REGISTERED'
  people[principal]=display
  return 'REGISTERED'
::method addCredential
  expose people keys seq
  use strict arg principal,provider,model,label,vaultRef
  /* trusted credential broker only: vaultRef is an opaque server-side handle */
  if \people~hasIndex(principal) then return 'AUTH_REQUIRED'
  if \ .array~of('ANTHROPIC','OPENAI')~hasItem(provider) then return 'BAD_PROVIDER'
  if model~strip='' | model~length>120 | label~strip='' | label~length>80 | vaultRef='' then return 'BAD_CREDENTIAL'
  seq+=1
  id='K'||seq
  entry=.directory~new
  entry['OWNER']=principal; entry['PROVIDER']=provider; entry['MODEL']=model; entry['LABEL']=label; entry['VAULT']=vaultRef
  keys[id]=entry
  return id
::method installSealedProfile
  expose profiles seq
  use strict arg author,label,body
  /* Trusted host admission only, never a player intention. Immutable bytes. */
  if author='' | label~strip='' | body~strip='' | body~length>65536 then return 'BAD_PROFILE'
  seq+=1
  id='P'||seq
  p=.directory~new
  p['AUTHOR']=author; p['LABEL']=label; p['BODY']=body
  p['SEAL']=.SHA512~new(author~length':'author||label~length':'label||body~length':'body)~digest
  profiles[id]=p
  return id
::method createGame
  expose people games powers seq
  use strict arg principal,title,mode
  if \people~hasIndex(principal) then return 'AUTH_REQUIRED'
  if title~strip='' | title~length>100 then return 'BAD_TITLE'
  if \ .array~of('LAB','MIXED','HUMAN')~hasItem(mode) then return 'BAD_MODE'
  seq+=1
  id='G'||seq
  g=.DiplomacyWebGame~new(id,principal,title,mode,powers)
  games[id]=g
  return id
::method game
  expose games
  use strict arg id
  return games[id]
::method seat
  expose people games keys profiles
  use strict arg principal,id,power,kind,keyId='',prompt='',profileId=''
  if \people~hasIndex(principal) then return 'AUTH_REQUIRED'
  g=games[id]
  if g==.nil then return 'NO_GAME'
  if kind='LLM' | kind='BOT' then do
    k=keys[keyId]
    if k==.nil then return 'NO_CREDENTIAL'
    if k['OWNER']\==principal then return 'NO_CREDENTIAL'
    if kind=='BOT' then do
      if prompt\=='' then return 'SEALED_OPPONENT_PROFILE_REQUIRED'
      profile=profiles[profileId]
      if profile==.nil then return 'SEALED_OPPONENT_PROFILE_REQUIRED'
      if profile['AUTHOR']==principal then return 'SELF_AUTHORED_OPPONENT_DENIED'
      return g~assign(principal,power,kind,keyId,k['PROVIDER'],k['MODEL'],profile['BODY'],profileId)
    end
    return g~assign(principal,power,kind,keyId,k['PROVIDER'],k['MODEL'],prompt)
  end
  return g~assign(principal,power,kind,'','','',prompt)
::method prompt
  expose games
  use strict arg principal,id,power,body
  g=games[id]
  if g==.nil then return 'NO_GAME'
  return g~setPrompt(principal,power,body)
::method design
  expose games keys
  use strict arg principal,id,power,keyId
  g=games[id]; k=keys[keyId]
  if g==.nil then return 'NO_GAME'
  if k==.nil then return 'NO_CREDENTIAL'
  if k['OWNER']\==principal then return 'NO_CREDENTIAL'
  if \g~canEdit(principal,power) then return 'DENIED'
  /* Production job broker must send the same sealed source+rules bundle
     to every designer, separately from the runner credential. */
  return 'DESIGN_PROVIDER_NOT_ADMITTED'
::method project
  expose people keys games profiles
  use strict arg principal,id=''
  p=.table~new
  p['profiles']=.array~new; p['account']=''; p['games']=.array~new; p['credentials']=.array~new; p['game']=.nil
  if \people~hasIndex(principal) then return p
  p['account']=people[principal]
  do pid over profiles~allIndexes~sort
    profile=profiles[pid]
    if profile['AUTHOR']==principal then iterate
    row=.table~new; row['id']=pid; row['label']=profile['LABEL']; row['seal']=profile['SEAL']
    p['profiles']~append(row)
  end
  do gid over games~allIndexes~sort
    g=games[gid]
    p['games']~append(g~summary)
  end
  do kid over keys~allIndexes~sort
    k=keys[kid]
    if k['OWNER']\==principal then iterate
    row=.table~new; row['id']=kid; row['provider']=k['PROVIDER']; row['model']=k['MODEL']; row['label']=k['LABEL']
    p['credentials']~append(row)
  end
  if games~hasIndex(id) then p['game']=games[id]~project(principal)
  return p
::class DiplomacyWebGame public
::attribute id get
::attribute owner get
::attribute mode get
::method init
  expose id owner title mode seats state journal broker worker
  use strict arg id,owner,title,mode,powers
  state='LOBBY'; journal=.array~new; broker=.nil; worker=.nil
  seats=.directory~new
  do p over powers
    s=.directory~new
    s['KIND']='OPEN'; s['OWNER']=''; s['KEY']=''; s['PROVIDER']=''; s['MODEL']=''; s['PROMPT']=''
    seats[p]=s
  end
::method canEdit
  expose seats state
  use strict arg principal,power
  if state\=='LOBBY' then return .false
  if \seats~hasIndex(power) then return .false
  return seats[power]['OWNER']==principal & seats[power]['KIND']=='LLM'
::method assign
  expose owner mode seats state
  use strict arg principal,power,kind,keyId,provider,model,prompt,profileId=''
  if state\=='LOBBY' then return 'LOCKED'
  if \seats~hasIndex(power) then return 'BAD_POWER'
  if \ .array~of('HUMAN','LLM','BOT')~hasItem(kind) then return 'BAD_KIND'
  if mode='LAB' & (kind\=='LLM' | principal\==owner) then return 'LAB_OWNER_ONLY'
  if mode='HUMAN' & kind\=='HUMAN' then return 'HUMANS_ONLY'
  if kind='BOT' & (mode\=='MIXED' | principal\==owner) then return 'SPONSOR_ONLY'
  /* Sponsored opponent chooses only a sealed profile; no supplied instruction bytes. */
  if kind='BOT' & profileId=='' then return 'SEALED_OPPONENT_PROFILE_REQUIRED'
  if prompt~length>65536 then return 'PROMPT_TOO_LONG'
  if kind=='HUMAN' & prompt\=='' then return 'HUMAN_PROMPT_DENIED'
  s=seats[power]
  if s['OWNER']\=='' & s['OWNER']\==principal then return 'SEAT_TAKEN'
  if mode\=='LAB' & kind\=='BOT' then do other over seats
    if other==power then iterate
    if seats[other]['OWNER']==principal & seats[other]['KIND']\=='BOT' then return 'ONE_SEAT_PER_PLAYER'
  end
  s['KIND']=kind; s['OWNER']=principal; s['KEY']=keyId; s['PROVIDER']=provider; s['MODEL']=model; s['PROMPT']=prompt
  return 'SEAT_SAVED'
::method setPrompt
  expose seats
  use strict arg principal,power,body
  if \self~canEdit(principal,power) then return 'DENIED'
  if seats[power]['KIND']\=='LLM' then return 'PRIVATE_INSTRUCTIONS_DENIED'
  if body~strip='' | body~length>65536 then return 'BAD_PROMPT'
  seats[power]['PROMPT']=body
  return 'PROMPT_SAVED'
::method ready
  expose seats
  do s over seats~allItems
    if s['KIND']=='OPEN' then return .false
    if s['KIND']\=='HUMAN' & s['PROMPT']~strip='' then return .false
  end
  return .true
::method bindWorker
  expose worker state
  use strict arg candidate
  /* Trusted host-only per-game admission. */
  if state\=='LOBBY' | worker\==.nil then return .false
  worker=candidate
  return .true
::method start
  expose id owner state seats worker broker mode
  use strict arg principal
  if principal\==owner then return 'DENIED'
  if state\=='LOBBY' then return 'LOCKED'
  if \self~ready then return 'SEATS_OR_PROMPTS_INCOMPLETE'
  if worker==.nil | mode\=='HUMAN' then return 'RUNNER_NOT_ADMITTED'
  owners=.directory~new
  do p over seats
    if seats[p]['KIND']\=='HUMAN' then return 'RUNNER_NOT_ADMITTED'
    owners[p]=seats[p]['OWNER']
  end
  signal on syntax name launchFailed
  broker=worker~makeTasks(owners,id)
  state='RUNNING'
  worker~launch(self,broker)
  return 'STARTED'
launchFailed:
  state='FAILED'
  return 'WORKER_FAILED'
::method workerFinished
  expose state
  use strict arg result
  /* Host-only. A worker can never reopen or alter the frozen roster. */
  if state\=='RUNNING' then return .false
  if result=='FINISHED' then state='FINISHED'
  else state='FAILED'
  return .true
::method summary
  expose id title mode state
  r=.table~new; r['id']=id; r['title']=title; r['mode']=mode; r['state']=state; r['ready']=self~ready
  return r
::method record
  expose journal
  use strict arg line
  /* Trusted host-only canonical journal ingress, never a Wire intention. */
  journal~append(line)
::method bindHumanTasks
  expose broker state
  use strict arg candidate
  /* Fixture-only binding before game admission; never exposed as an action. */
  if state\=='LOBBY' | broker\==.nil then return .false
  broker=candidate
  return .true
::method submitTask
  expose broker seats state
  use strict arg principal,taskId,raw
  power=self~powerFor(principal)
  if state\=='RUNNING' | power=='' | broker==.nil then return 'TASK_DENIED'
  if seats[power]['KIND']\=='HUMAN' then return 'TASK_DENIED'
  return broker~submit(principal,taskId,raw)
::method powerFor
  expose seats mode
  use strict arg principal
  if mode=='LAB' then return ''
  do p over seats
    if seats[p]['OWNER']==principal & seats[p]['KIND']\=='BOT' then return p
  end
  return ''
::method project
  expose seats owner mode journal broker state
  use strict arg principal
  r=self~summary
  r['owner']=owner==principal
  r['seats']=.array~new
  do p over seats~allIndexes~sort
    s=seats[p]; row=.table~new
    row['power']=p; row['kind']=s['KIND']; row['provider']=s['PROVIDER']; row['model']=s['MODEL']; row['mine']=s['OWNER']==principal
    row['promptReady']=s['PROMPT']~strip\==''
    if row['mine'] & s['KIND']=='LLM' & state=='LOBBY' then row['prompt']=s['PROMPT']
    else row['prompt']=''
    r['seats']~append(row)
  end
  role='PUBLIC'; power=self~powerFor(principal)
  /* LAB ownership is an experiment-review role, not a human player seat. */
  if mode='LAB' & owner==principal then role='LAB_REVIEWER'
  else if power\=='' then role='PLAYER'
  r['role']=role; r['power']=power
  r['review']=diplomacyReview(journal,role,power)
  r['task']=.nil
  if role=='PLAYER' & broker\==.nil & state=='RUNNING' then if seats[power]['KIND']=='HUMAN' then r['task']=broker~project(principal)
  return r
::routine diplomacyReview public
  use strict arg journal,role,power
  r=.table~new; r['phases']=.array~new; r['mail']=.array~new; r['units']=.array~new; r['centres']=.array~new; r['results']=.array~new
  r['phase']='Initial deployment'; r['round']=''; r['finished']=.false
  stage=.nil; round=''; mailBuffer=.array~new
  do line over journal
    parse var line type '|' tail
    select
      when type='PHASE' then do
        stage=.table~new; stage['units']=.array~new; stage['centres']=.array~new; stage['results']=.array~new
        stage['phase']=tail; round=''
      end
      when type='PRESS_ROUND' then do
        parse var tail . '|' . '|' round
        mailBuffer=.array~new
      end
      when type='PRESS_END' then do
        do m over mailBuffer
          r['mail']~append(m)
        end
        mailBuffer=.array~new; round=''
      end
      when type='MAIL' then do
        parse var tail mid '|' sender '|' recipients '|' injection '|' hex
        if role=='LAB_REVIEWER' | (role=='PLAYER' & (sender==power | wordpos(power,recipients)>0)) then do
          if hex~datatype('X') & hex~length//2=0 then do
            m=.table~new; m['id']=mid; m['sender']=sender; m['to']=recipients; m['body']=hex~x2c; m['round']=round
            if round\=='' then mailBuffer~append(m)
          end
        end
      end
      when type='UNIT' | type='CENTRE' then do
        if type='UNIT' then key='units'
        else key='centres'
        if stage==.nil then r[key]~append(tail)
        else stage[key]~append(tail)
      end
      when type='RESULT' then do
        if stage==.nil then iterate
        parse var tail p '|' raw '|' result
        if raw~datatype('X') & raw~length//2=0 then stage['results']~append(p' | 'raw~x2c' | 'result)
      end
      when type='PHASE_END' then do
        if stage==.nil then iterate
        r['phases']~append(stage)
        do key over .array~of('phase','units','centres','results')
          r[key]=stage[key]
        end
        stage=.nil
      end
      when type='END' then r['finished']=.true
      otherwise nop /* CALL, ORDER, PRESS_CALL, PLAYER_LIST, etc. never projected */
    end
  end
  return r

::requires 'crypto.cls'
