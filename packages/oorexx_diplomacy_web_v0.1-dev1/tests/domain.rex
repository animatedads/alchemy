n=0
d=.DiplomacyWeb~new
call eq d~register('owner','Architect'),'REGISTERED'
call eq d~register('guest','Guest'),'REGISTERED'
call eq d~register('third','Third'),'REGISTERED'
k=d~addCredential('owner','OPENAI','pinned-runner','Runner','SECRET_VAULT_HANDLE')
call eq k,'K1'
call eq d~addCredential('owner','INVALID','x','x','x'),'BAD_PROVIDER'
g=d~createGame('owner','Human play','HUMAN')
call eq d~seat('owner',g,'ENG','HUMAN'),'SEAT_SAVED'
call eq d~seat('guest',g,'ENG','HUMAN'),'SEAT_TAKEN'
call eq d~seat('owner',g,'FRA','HUMAN'),'ONE_SEAT_PER_PLAYER'
call eq d~seat('guest',g,'FRA','LLM',k),'NO_CREDENTIAL'
call eq d~seat('guest',g,'FRA','HUMAN'),'SEAT_SAVED'
call eq d~seat('third',g,'ITA','HUMAN'),'SEAT_SAVED'
do i=4 to 7
  u='person' i
  call eq d~register(u,u),'REGISTERED'
  p=.array~of('AUS','GER','RUS','TUR')[i-3]
  call eq d~seat(u,g,p,'HUMAN'),'SEAT_SAVED'
end
call eq d~game(g)~ready,.true
call eq d~game(g)~start('owner'),'RUNNER_NOT_ADMITTED'
m=d~createGame('owner','Mixed','MIXED')
profile=d~installSealedProfile('independent-orchestrator','Sealed independent','SECRET_BOT_INSTRUCTIONS')
selfProfile=d~installSealedProfile('owner','Self-authored','known strategy')
call eq d~seat('owner',m,'ENG','HUMAN'),'SEAT_SAVED'
call eq d~seat('owner',m,'FRA','BOT',k,'prompt'),'SEALED_OPPONENT_PROFILE_REQUIRED'
call eq d~seat('owner',m,'FRA','BOT',k,'',profile),'SEAT_SAVED'
call eq d~seat('owner',m,'ITA','BOT',k,'',profile),'SEAT_SAVED'
call eq d~seat('guest',m,'GER','BOT',k,'prompt'),'NO_CREDENTIAL'
call eq d~game(m)~powerFor('owner'),'ENG'
call eq d~seat('owner',m,'GER','BOT',k,'',selfProfile),'SELF_AUTHORED_OPPONENT_DENIED'
call eq d~prompt('guest',m,'FRA','steal'),'DENIED'
call eq d~prompt('owner',m,'FRA','steal'),'DENIED'
call eq d~game(m)~project('owner')['seats'][3]['prompt'],''
call eq d~design('guest',m,'FRA',k),'NO_CREDENTIAL'
call eq d~design('owner',m,'FRA',k),'DENIED'
l=d~createGame('owner','Lab','LAB')
do p over .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
  call eq d~seat('owner',l,p,'LLM',k,'prompt'),'SEAT_SAVED'
end
call eq d~game(l)~ready,.true
call eq d~game(l)~project('owner')['role'],'LAB_REVIEWER'
call eq d~game(l)~project('guest')['role'],'PUBLIC'
lines=.array~of('UNIT|ENG|F|LON','PHASE|1901|SPRING_MOVEMENT','PRESS_ROUND|1901|SPRING_MOVEMENT|1','PRESS_CALL|SECRET RAW','PLAYER_LIST|SECRET LIST','ORDER|SECRET ORDER','MAIL|1|FRA|GER|0|'||'secret'~c2x,'MAIL|2|ENG|FRA|0|'||'own'~c2x)
do line over lines
  d~game(m)~record(line)
  d~game(l)~record(line)
end
call eq d~game(l)~project('owner')['review']['mail']~items,0
d~game(m)~record('PRESS_END|1901|SPRING_MOVEMENT|1|2')
d~game(l)~record('PRESS_END|1901|SPRING_MOVEMENT|1|2')
call eq d~game(m)~project('owner')['review']['mail']~items,1
call eq d~game(m)~project('owner')['review']['mail'][1]['body'],'own'
call eq d~game(l)~project('guest')['review']['mail']~items,0
call eq d~game(l)~project('owner')['review']['mail']~items,2
call eq d~game(m)~project('owner')['review']['units']~items,1
d~game(m)~record('UNIT|ENG|F|NTH')
d~game(m)~record('RESULT|ENG|'||'F LON - NTH'~c2x||'|SUCCEEDS')
call eq d~game(m)~project('owner')['review']['units'][1],'ENG|F|LON'
d~game(m)~record('PHASE_END')
call eq d~game(m)~project('owner')['review']['units'][1],'ENG|F|NTH'
call eq d~game(m)~project('owner')['review']['results']~items,1
p=d~project('guest',m)
call eq p['credentials']~items,0
call eq p['game']['seats'][3]['prompt'],''
p=d~project('owner',m)
call eq p['credentials'][1]~hasIndex('vault'),.false
say 'PASS' n 'native domain assertions'
exit 0
eq:
  use arg actual,expected
  n+=1
  if actual\==expected then do
    say 'FAIL' n actual 'expected' expected
    exit 1
  end
return
::requires 'DiplomacyWeb.cls'
