prompt=.CliUiPromptModel~new('Command: ')
prompt~insert('V')~insert('IEW')
if prompt~buffer<>'VIEW' then raise syntax 93.900 array ('prompt edit failed')
if prompt~submit<>'VIEW' then raise syntax 93.900 array ('prompt submit failed')
if prompt~history~items<>1 then raise syntax 93.900 array ('prompt history failed')
say 'PASS prompt edit submit history'
::requires 'CliUiModels.cls'
