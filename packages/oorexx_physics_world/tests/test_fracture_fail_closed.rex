fails=0
call expectFail 1
call expectFail 2
call expectFail 3
if fails<>3 then do; say 'FAIL expected three fracture boundary failures, got' fails; exit 1; end
say 'PHYSICS FRACTURE FAIL-CLOSED: OK'
exit 0
expectFail: procedure expose fails
  use arg which
  signal on syntax name caught
  select
    when which=1 then x=.BrittleFractureLaw~new('bad',.Units~q(-1,.Units~pascal))
    when which=2 then x=.BrittleFractureLaw~new('bad',.Units~q(1,.Units~metre))
    when which=3 then x=.BrittleFractureLaw~new('bad',.Units~q(1,.Units~pascal),,.Units~q(-1,.Units~joule/.Units~squareMetre))
    otherwise nop
  end
  say 'FAIL expected syntax for case' which
  exit 1
caught:
  fails=fails+1
  return
::requires 'Fracture.cls'
