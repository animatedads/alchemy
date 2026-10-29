actions=.CliUiActionMap~new
actions~bind('UP','TABLE_PREVIOUS')
actions~bind('DOWN','TABLE_NEXT')
actions~bind('ENTER','OPEN_SELECTED')
actions~bind('A','APPROVE')
actions~bind('R','REJECT')
actions~bind('/','QUERY')
actions~bind('V','VIEW')
actions~bind('Q','QUIT')
if actions~resolve('a')<>'APPROVE' then raise syntax 93.900 array ('action mapping failed')
if actions~resolve('ENTER')<>'OPEN_SELECTED' then raise syntax 93.900 array ('open mapping failed')
say 'PASS application-owned semantic action map'
::requires 'CliUiModels.cls'
