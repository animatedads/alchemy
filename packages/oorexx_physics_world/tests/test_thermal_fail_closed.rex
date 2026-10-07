numeric digits 30
fails=0
call expectFail 'delta temperature cannot initialize absolute state',1
call expectFail 'wrong power dimension rejected',2
call expectFail 'bad emissivity rejected',3
if fails<>3 then do; say 'FAIL: expected 3 fail-closed cases, got' fails; exit 1; end
say 'PHYSICS THERMAL FAIL-CLOSED: OK'
exit 0
expectFail: procedure expose fails
  use arg label,which
  signal on syntax name caught
  select
    when which=1 then n=.ThermalNode~new('bad',.Units~q(5,.Units~deltaCelsius),.Units~q(10,(.Units~joule/.Units~deltaKelvin)))
    when which=2 then p=.ThermalPowerObservation~new(.Units~q(0,.Units~second),.Units~q(2,.Units~metre))
    when which=3 then r=.ThermalRadiationBoundary~new('bad',.ThermalNode~new('n',.Units~q(300,.Units~kelvin),.Units~q(10,(.Units~joule/.Units~deltaKelvin))),.Units~q(300,.Units~kelvin),.Units~q(1.2,.Units~one),.Units~q(1,.Units~squareMetre))
    otherwise nop
  end
  say 'FAIL: expected failure:' label
  exit 1
caught:
  fails=fails+1
  return
::requires 'Thermal.cls'
