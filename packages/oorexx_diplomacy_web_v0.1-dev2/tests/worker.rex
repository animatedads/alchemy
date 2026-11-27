/* Seven separate immutable authenticated sessions complete a real year.
   Test participants are scripted clients, not simulated referee output. */
parse arg root filename
n=0
powers=.array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
d=.DiplomacyWeb~new
call eq d~register('observer','Observer'),'REGISTERED'
do p over powers
  call eq d~register(p,p),'REGISTERED'
end
s=.directory~new
g=d~createGame('ENG','Human championship','HUMAN')
game=d~game(g)
do p over powers
  s[p]=.DiplomacySession~new(d,p,g)
  x=.table~new; x['power']=p; x['kind']='HUMAN'; x['principal']='ENG'
  call eq s[p]~dispatch('DIP.SEAT',x),'SEAT_SAVED'
end
observer=.DiplomacySession~new(d,'observer',g)
call eq observer~dispatch('DIP.REGISTER',.table~new),'DENIED'
call eq observer~dispatch('DIP.START',.table~new),'DENIED'
call eq observer~dispatch('DIP.CREDENTIAL.FIXTURE',.table~new),'DENIED'
call eq game~bindWorker(.DiplomacyHumanWorker~new(root,filename,.DiplomacyGameConfig~new(1901,1901,18,3),123,10)),.true
call eq s['ENG']~dispatch('DIP.START',.table~new),'STARTED'
call eq s['ENG']~dispatch('DIP.START',.table~new),'LOCKED'
call eq game~assign('ENG','ENG','HUMAN','','','',''),'LOCKED'
call eq game~summary['state'],'RUNNING'
submitted=.set~new
press=0; movement=0; other=0; secret='PRIVATE_ENG_FRA_1901'; old=''
call time 'R'
do while game~summary['state']=='RUNNING'
  if time('E')>45 then do
    say 'FAIL worker did not finish'; exit 1
  end
  do p over powers
    proj=s[p]~project['game']
    t=proj['task']
    if t==.nil then iterate
    if submitted~hasIndex(t['id']) then iterate
    submitted~put(t['id'])
    v=t['view']
    call eq v['POWER'],p
    call eq v~hasIndex('INSTRUCTIONS'),.false
    call eq v~hasIndex('CURRENT_OPPONENT_ORDERS'),.false
    call eq observer~project['game']['task'],.nil
    do q over powers
      if q==p then iterate
      call eq s[q]~project['game']['task'],.nil
    end
    x=.table~new; x['task']=t['id']; x['principal']=p; x['raw']='forged'
    call eq observer~dispatch('DIP.SUBMIT',x),'TASK_DENIED'
    if p=='ENG' then attacker='FRA'
    else attacker='ENG'
    call eq s[attacker]~dispatch('DIP.SUBMIT',x),'TASK_DENIED'
    if old\=='' then do
      y=.table~new; y['task']=old; y['raw']='stale'
      call eq s[p]~dispatch('DIP.SUBMIT',y),'TASK_DENIED'
    end
    old=t['id']
    raw=''
    if v['KIND']=='PRESS' then do
      press+=1
      call eq v['PLAYER_LIST']~items,7
      if p=='ENG' & v['PHASE']=='SPRING_MOVEMENT' & v['ROUND']==1 then do
        target=0
        do i=1 to v['PLAYER_LIST']~items
          if v['PLAYER_LIST'][i]=='FRA' then target=i
        end
        call eq target>0,.true
        raw='SEND TO: 'target||'0a'x||'MESSAGE:'||'0a'x||secret||'0a'x||'END MESSAGE'
      end
      if v['PHASE']=='SPRING_MOVEMENT' & v['ROUND']==1 then do
        call eq s['FRA']~project['game']['review']['mail']~items,0
        call eq s['ENG']~project['game']['review']['mail']~items,0
      end
      if v['PHASE']=='SPRING_MOVEMENT' & v['ROUND']==2 then do
        if p=='FRA' then do
          call eq v['INBOX']~items,1
          call eq v['INBOX'][1]~pos(secret)>0,.true
        end
        else call eq v['INBOX']~items,0
      end
    end
    else if v['KIND']=='MOVEMENT' then do
      movement+=1
      do unit over v['TASK']
        raw||=unit' H'||'0a'x
      end
    end
    else other+=1
    x['raw']=raw
    call eq s[p]~dispatch('DIP.SUBMIT',x),'SUBMITTED'
  end
  call sysSleep 0.01
end
call eq game~summary['state'],'FINISHED'
call eq press,42
call eq movement,14
call eq other,0
call eq observer~project['game']['review']['mail']~items,0
call eq s['ENG']~project['game']['review']['mail'][1]['body'],secret
call eq s['FRA']~project['game']['review']['mail'][1]['body'],secret
do p over powers
  if p=='ENG' | p=='FRA' then iterate
  call eq s[p]~project['game']['review']['mail']~items,0
end
call eq observer~project['game']['review']['finished'],.true
call eq observer~project['game']['review']['phases']~items,5
call eq observer~project['game']['review']['units']~items,22
call eq observer~project['game']['review']['centres']~items,34
last=''
lines=0
f=.stream~new(filename)
call eq f~open('READ'),'READY:'
call eq f~linein,'DIPLOG|3'
do while f~lines>0
  last=f~linein; lines+=1
end
f~close
call eq last~left(21),'END|YEAR_LIMIT|-|1901'
say 'PASS' n 'real-controller seven-session assertions;' press 'press and' movement 'movement tasks;' lines+1 'journal lines'
exit 0
eq:
  use arg actual,expected
  n+=1
  if actual\==expected then do
    say 'FAIL' n actual 'expected' expected
    exit 1
  end
return
::requires 'DiplomacySession.cls'
::requires 'DiplomacyHumanWorker.cls'
