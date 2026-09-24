/* Qualification: independent current source DC stamping and sign convention. */
numeric digits 50

c = .Circuit~new
i = c~add(.DCCurrentSource~new('I1', 0.002))
r = c~add(.Resistor~new('R1', 1000))

/* 2 mA flows from GND into NODE; R1 returns it to GND. */
c~connectGround(i~fromPin)
c~connect('NODE', .array~of(i~toPin, r~pin('A')))
c~connectGround(r~pin('B'))

solution = c~solveDC

if abs(solution~voltage('NODE') - 2) > 0.0000001 then do
  say 'FAIL: NODE expected 2 V, got' solution~voltage('NODE')
  exit 1
end
if abs(solution~current(r) - 0.002) > 0.000000001 then do
  say 'FAIL: resistor expected 2 mA, got' solution~current(r)
  exit 1
end

say 'REXX-TRONICS DC CURRENT SOURCE: OK'
say 'NODE:' solution~voltage('NODE') 'V'
say 'R1 current:' solution~current(r) 'A'
exit 0

::requires 'RexxTronicsDC.cls'
