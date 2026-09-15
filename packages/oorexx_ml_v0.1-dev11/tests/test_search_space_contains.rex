space=.MLSearchSpace~new('C',.array~of(,
  .MLParameterDomain~new('gain_db',.array~of(18,20,22)),,
  .MLParameterDomain~new('highpass',.array~of(40,50,70))))
valid=.directory~new; valid['gain_db']=20; valid['highpass']=50
invalid=.directory~new; invalid['gain_db']=999; invalid['highpass']=50
missing=.directory~new; missing['gain_db']=20
call true space~containsConfiguration(valid),'declared valid configuration is contained'
call true \space~containsConfiguration(invalid),'out-of-domain value is rejected'
call true \space~containsConfiguration(missing),'missing parameter is rejected'
say 'PASS test_search_space_contains'
exit 0
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
