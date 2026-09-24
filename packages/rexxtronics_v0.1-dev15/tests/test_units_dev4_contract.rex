numeric digits 50
if .Units~version <> '0.1-dev4' then do
  say 'FAIL Units version' .Units~version
  exit 1
end
if abs(.Units~q(10,.Units~centimetre)~in(.Units~metre)-'0.1') > '1e-30' then do
  say 'FAIL centimetre conversion'
  exit 1
end
if abs(.Units~q(250,.Units~millilitre)~in(.Units~litre)-'0.25') > '1e-30' then do
  say 'FAIL millilitre conversion'
  exit 1
end
if \(.Units~pascal~dimension~compatible((.Units~newton/.Units~squareMetre)~dimension)) then do
  say 'FAIL pascal dimension'
  exit 1
end
say 'REXX-TRONICS UNITS DEV4 CONTRACT: OK'
exit 0
::requires 'RexxTronicsUnits.cls'
