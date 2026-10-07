numeric digits 50
ctx=.MathContext~decimal(50)

say 'pi:' .Maths~pi(ctx)
say 'sqrt(2):' .Maths~sqrt(2,ctx)

curve=.Maths~linearInterpolator(.array~of(0,10,20),.array~of(0,100,400),ctx)
say 'linear interpolation at 15:' curve~evaluate(15)

surface=.Maths~bilinearInterpolator(.array~of(0,1),.array~of(0,1), -
    .array~of(.array~of(0,10),.array~of(20,30)),ctx)
say 'bilinear interpolation at (.5,.5):' surface~evaluate('.5','.5')

series=.Maths~sampledSeries(ctx); pi=.Maths~pi(ctx)
do i=0 to 15
  t=i/16
  series~append(t,.Maths~sin(2*pi*t,ctx))
end
component=series~component(1)
say '1 Hz Fourier amplitude:' component~amplitude

roots=.Maths~quadratic(1,-5,6,.MathContext~rational)~solve
say 'quadratic x^2-5x+6 roots:' roots~root1 roots~root2

system=.Maths~linearSystem(.array~of(.array~of(2,1),.array~of(1,-1)), -
                           .array~of(5,1),.MathContext~rational)
solution=system~solve
say 'linear system solution:' solution

::requires 'MathsBootstrap.cls'
