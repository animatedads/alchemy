call assert .Aid3270~PF1=="F1"x,'PF1'
call assert .Aid3270~PF9=="F9"x,'PF9'
call assert .Aid3270~PF10=="7A"x,'PF10'
call assert .Aid3270~PF12=="7C"x,'PF12'
call assert .Aid3270~PF13=="C1"x,'PF13'
call assert .Aid3270~PF21=="C9"x,'PF21'
call assert .Aid3270~PF22=="4A"x,'PF22'
call assert .Aid3270~PF24=="4C"x,'PF24'
call assert .Aid3270~PA1=="6C"x,'PA1'
call assert .Aid3270~PA2=="6E"x,'PA2'
call assert .Aid3270~PA3=="6B"x,'PA3'
say 'PASS 3270 AIDS'
exit 0
assert: procedure; use arg ok,msg; if \ok then do; say 'FAIL' msg; exit 1; end; return
::requires "DataStream3270.cls"
