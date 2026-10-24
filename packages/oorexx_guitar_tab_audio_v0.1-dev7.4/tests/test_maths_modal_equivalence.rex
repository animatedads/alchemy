numeric digits 30
sr=8000; pi=4*RxCalcArcTan(1,30,'R')
amps=.array~of(-.9,-.5,-.33,-.22,-.16,-.12)
freqs=.array~of(82.4068892,164.8137784,247.2206676,329.6275568,412.034446,494.4413352)
decays=.array~of(2.8,2.9,3.0,3.1,3.2,3.3)
phases=.array~of(0,0,0,0,0,0)
ctx=.MathContext~binary64('PURE')
wave=.Maths~oscillatorBank(amps,freqs,decays,phases,sr,ctx)~render(16)
c=.array~new; s=.array~new; ed=.array~new; cd=.array~new; sd=.array~new
do n=1 to amps~items
  c[n]=1; s[n]=0
  omega=2*pi*freqs[n]
  ed[n]=RxCalcExp(-decays[n]/sr,30)
  cd[n]=RxCalcCos(omega/sr,30,'R'); sd[n]=RxCalcSin(omega/sr,30,'R')
end
maxerr=0
do j=1 to 16
  old=0
  do n=1 to amps~items
    old=old+amps[n]*s[n]
    nc=ed[n]*(c[n]*cd[n]-s[n]*sd[n]); ns=ed[n]*(s[n]*cd[n]+c[n]*sd[n]); c[n]=nc; s[n]=ns
  end
  e=abs(wave[j]-old); if e>maxerr then maxerr=e
end
if maxerr>2E-12 then do; say 'FAIL maxerr='maxerr; exit 1; end
say 'MATHS MODAL EQUIVALENCE: OK maxerr='maxerr
::requires 'MathsBootstrap.cls'
::requires 'rxmath' LIBRARY
