n=0
owners=.directory~new; owners['ENG']='alice'; owners['FRA']='bob'
t=.DiplomacyHumanTasks~new(owners)
v=.directory~new; v['POWER']='ENG'; v['KIND']='MOVEMENT'; v['TASK']=.array~of('F LON'); v['INBOX']=.array~of('own message'); v['INSTRUCTIONS']='SECRET SHOULD NEVER CROSS'; v['CURRENT_OPPONENT_ORDERS']='SECRET'
id=t~issue(v)
call eq id,'T1'
call eq t~project('bob'),.nil
call eq t~project('alice')['id'],id
call eq t~project('alice')['view']~hasIndex('INSTRUCTIONS'),.false
call eq t~project('alice')['view']~hasIndex('CURRENT_OPPONENT_ORDERS'),.false
call eq t~submit('bob',id,'F LON - NTH'),'TASK_DENIED'
call eq t~submit('alice','T0','F LON - NTH'),'TASK_DENIED'
call eq t~submit('alice',id,'F LON - NTH'||'0a'x||'A LVP H'),'SUBMITTED'
call eq t~project('alice'),.nil
call eq t~submit('alice',id,'F LON H'),'TASK_CLOSED'
call eq t~take('FRA',id),.nil
call eq t~take('ENG',id)[2][1],'F LON - NTH'
call eq t~take('ENG',id),.nil
v['KIND']='PRESS'; id=t~issue(v)
call eq id,'T2'
call eq t~expire('ENG','T1'),.false
call eq t~expire('ENG',id),.true
call eq t~submit('alice',id,'late'),'TASK_DENIED'
clock=.TestTaskClock~new
timed=.DiplomacyHumanTasks~new(owners,clock,5,'G2-')
v['KIND']='PRESS'; v['PLAYER_LIST']=.array~of('ENG','FRA')
v['HISTORY']=.array~of(.array~of('1901','ENG','3'))
id=timed~issue(v)
call eq id,'G2-T1'
call eq timed~project('alice')['remaining'],5
projection=timed~project('alice')
call eq projection['view']['PLAYER_LIST']~items,2
call eq projection['view']['HISTORY'][1][2],'ENG'
projection['view']['PLAYER_LIST'][1]='BAD'
call eq timed~project('alice')['view']['PLAYER_LIST'][1],'ENG'
call eq timed~submit('alice','G1-T1','irrelevant'),'TASK_DENIED'
clock~advance(5)
call eq timed~project('alice'),.nil
call eq timed~submit('alice',id,'too late'),'TASK_EXPIRED'
call eq timed~expire('ENG',id),.true
say 'PASS' n 'human task assertions'
exit 0
eq:
 use arg actual,expected
 n+=1
 if actual\==expected then do
   say 'FAIL' n actual 'expected' expected
   exit 1
 end
return
::requires 'DiplomacyHumanTasks.cls'

::class TestTaskClock
::method init
  expose current
  current=100
::method now
  expose current
  return current
::method advance
  expose current
  use strict arg amount
  current+=amount
