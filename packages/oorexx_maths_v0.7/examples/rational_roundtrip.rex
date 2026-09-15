/* Why exact fractions matter: native decimal materialization versus Maths. */
numeric digits 50
ctx=.MathContext~rational

do i=1 to 25
  j=i*3
  native=(i/j)*j
  f=.Maths~fraction(i,j,ctx)
  exact=f*j
  say i '/' j ' nativeRoundTrip='native ' exactFraction='f ' exactRoundTrip='exact
end
say
x=.Maths~fraction(2,3,ctx)
say '2/3 rounded to 24 decimal digits:' x~format('DECIMAL',24)
say '2/3 exact base-10 expansion:      ' x~format('EXPANSION')
say '(2/3) * 3 / 2 remains:            ' x*3/2
::requires 'MathsBootstrap.cls'
