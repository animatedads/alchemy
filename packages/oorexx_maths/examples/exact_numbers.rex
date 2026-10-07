numeric digits 50

third = .Maths~fraction(1, 3)
one = third + third + third
say '1/3 + 1/3 + 1/3 =' one
say 'class:' one~class~id
say 'unreduced final step:' one~evidence~checks['unreduced']
say 'canonical final value:' one~evidence~checks['canonical']

x = .Maths~fraction(2, 3)
say '(2/3) * 3 / 2 =' x * 3 / 2
say 'decimal presentation of 2/3:' x~format('DECIMAL', 24)
say 'exact value remains:' x

six = .Maths~integer(6)
a = six / 3
b = six / 4
say '6 / 3 =' a 'class=' a~class~id
say '6 / 4 =' b 'class=' b~class~id

say 'exact("0.1") =' .Maths~exact('0.1')
say 'exact("1.2e-3") =' .Maths~exact('1.2e-3')
say '7/3 mixed presentation =' .Maths~fraction(7,3)~format('MIXED')

::requires 'MathsBootstrap.cls'
