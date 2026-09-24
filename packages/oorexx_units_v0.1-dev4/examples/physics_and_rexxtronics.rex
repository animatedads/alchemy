numeric digits 50
mass=.Units~q(2,.Units~kilogram)
accel=.Units~q(9.80665,.Units~metrePerSecondSquared)
weight=mass*accel
say 'weight:' weight~in(.Units~newton) 'N'

supply=.Units~q(5,.Units~volt)
resistor=.Units~q(4.7,.Units~kiloohm)
current=supply/resistor
say 'current:' current~in(.Units~milliampere) 'mA'

room=.Units~q(21,.Units~celsius,.Units~fahrenheit)
say 'room:' room
say 'canonical K:' room~canonicalValue
say 'source unit:' room~sourceUnit~name

::requires '../rexx/Units.cls'
