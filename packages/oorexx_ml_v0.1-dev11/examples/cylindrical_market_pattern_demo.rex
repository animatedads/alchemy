/* Cylindrical temporal pattern hashing demo.
 *
 * The trap:
 *   A and B have almost the same nominal PRICE line, but the benchmark-relative,
 *   FX and volatility behaviour underneath is different.
 *
 * The reveal:
 *   A and C use completely different numerical levels and a shifted/stretched
 *   clock, but every channel follows the same relative trajectory.  Under an
 *   explicitly time-scale-invariant policy they become the same cylindrical
 *   temporal pattern.
 */
parse arg svgOut
if svgOut='' then svgOut='cylindrical_market_pattern_demo.svg'

names=.array~of('PRICE','RELATIVE','FX','VOL')
weights=.array~of(1,4,4,2)

tA=.array~of(0,1,2,4,5,7,8,10,13,15)
priceA=.array~of(100,102,105,104,108,111,110,114,117,121)
relA=.array~of(0,.3,.8,.4,1.1,1.7,1.4,2.1,2.5,3.0)
fxA=.array~of(0,-.2,-.4,-.6,-.5,-.2,.1,.3,.2,0)
volA=.array~of(18,18,19,20,19,18,19,18,17,18)
A=.MLTemporalPatternSeries~new(tA,names,.array~of(priceA,relA,fxA,volA),weights,'A_BASE_MARKET')

/* Nominal price looks almost the same, but the economics do not. */
priceB=.array~of(100,102.1,105.1,104.2,108.2,111.2,110.1,114.1,117.1,121.1)
relB=.array~of(0,-.3,-.8,-1.0,-.7,-.2,.2,.7,1.0,1.2)
fxB=.array~of(0,.4,.9,1.2,1.6,2.0,2.4,2.8,3.0,3.4)
volB=.array~of(18,20,23,26,25,28,30,32,31,33)
B=.MLTemporalPatternSeries~new(tA,names,.array~of(priceB,relB,fxB,volB),weights,'B_PRICE_LOOKALIKE')

/* Same underlying behaviour at new levels and on a globally stretched clock. */
tC=.array~new; do x over tA; tC~append(100+2*x); end
priceC=.array~new; do x over priceA; priceC~append(250+2.5*(x-100)); end
relC=.array~new; do x over relA; relC~append(50+7*x); end
fxC=.array~new; do x over fxA; fxC~append(-20+3*x); end
volC=.array~new; do x over volA; volC~append(200+4*(x-17)); end
C=.MLTemporalPatternSeries~new(tC,names,.array~of(priceC,relC,fxC,volC),weights,'C_ECONOMIC_TWIN')

/* Same economics and total duration, but one local event arrives late. */
tD=.array~of(0,1,2,4,5,9,10,11,13,15)
D=.MLTemporalPatternSeries~new(tD,names,.array~of(priceA,relA,fxA,volA),weights,'D_LOCAL_TIMING_SHOCK')

policy=.MLTemporalPatternPolicy~new(36,48,48,72,48,48,1,12,5,10,14,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(policy,'MARKET-CYLINDER/1')
hA=schema~encode(A); hB=schema~encode(B); hC=schema~encode(C); hD=schema~encode(D)
dAB=schema~difference(hA,hB); dAC=schema~difference(hA,hC); dAD=schema~difference(hA,hD)

say 'CYLINDRICAL MARKET PATTERN DEMO'
say 'policy:' policy~canonicalText
call showDiff 'A vs B price-lookalike',dAB
call showDiff 'A vs C economic twin',dAC
call showDiff 'A vs D timing shock',dAD
say 'A/C exact temporal-pattern hash='||(hA~key==hC~key)
say 'A/B nominal price endpoints='priceA[1]'..'priceA[priceA~items] 'vs' priceB[1]'..'priceB[priceB~items]
call writeSvg svgOut,schema,hA,hB,hC,hD,dAB,dAC,dAD,priceA,priceB
say 'SVG 'svgOut
say 'PASS cylindrical_market_pattern_demo'
exit 0

showDiff: procedure
  use arg label,d
  say left(label,28) 'dominant='d~dominantDelta 'kind='d~dominantKind 'channel='d~dominantChannel 'total='d~totalDelta 'timeMax='d~timeMax 'turnMax='d~turnMax
  return

writeSvg: procedure
  use arg path,schema,hA,hB,hC,hD,dAB,dAC,dAD,priceA,priceB
  call RxFuncAdd 'RxCalcSin','rxmath','RxCalcSin'; call RxFuncAdd 'RxCalcCos','rxmath','RxCalcCos'
  s=.stream~new(path); s~open('write replace')
  s~lineout('<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="860" viewBox="0 0 1200 860">')
  s~lineout('<rect width="1200" height="860" fill="#ffffff"/>')
  s~lineout('<text x="30" y="38" font-family="sans-serif" font-size="21" font-weight="bold">Cylindrical temporal pattern hash: price is the trap</text>')
  s~lineout('<text x="30" y="63" font-family="sans-serif" font-size="14">Illustrative synthetic market data. Angle = event progress; radius = normalized channel state; height = event time.</text>')

  /* Panel 1: ordinary price chart. */
  call panel s,30,90,540,300,'1. Ordinary nominal-price view'
  s~lineout('<text x="50" y="127" font-family="sans-serif" font-size="12">A and B look almost identical here.</text>')
  x0=65; y0=355; pw=470; ph=190
  s~lineout('<line x1="'||x0||'" y1="'||y0||'" x2="'||(x0+pw)||'" y2="'||y0||'" stroke="#bbb"/>')
  s~lineout('<line x1="'||x0||'" y1="'||(y0-ph)||'" x2="'||x0||'" y2="'||y0||'" stroke="#bbb"/>')
  min=99; max=122
  s~lineout('<path d="'||linePath(priceA,x0,y0,pw,ph,min,max)||'" fill="none" stroke="#111" stroke-width="3"/>')
  s~lineout('<path d="'||linePath(priceB,x0,y0,pw,ph,min,max)||'" fill="none" stroke="#888" stroke-width="5" stroke-dasharray="2 7"/>')
  s~lineout('<text x="70" y="378" font-family="sans-serif" font-size="12">solid A: nominal price | dotted B: nominal price lookalike</text>')

  /* Panel 2: A vs B cylinder. */
  call panel s,600,90,570,300,'2. Same-looking price, different economic trajectory'
  call cylinder s,880,350,185,215
  call drawHash s,hA,880,350,185,215,'solid'
  call drawHash s,hB,880,350,185,215,'dash'
  s~lineout('<text x="620" y="373" font-family="sans-serif" font-size="11">A solid / B dashed. PRICE overlaps; RELATIVE, FX and VOL peel away in 3-D.</text>')

  /* Panel 3: A vs C cylinder. */
  call panel s,30,420,540,350,'3. Different numbers, same behaviour-through-time'
  call cylinder s,300,735,185,245
  call drawHash s,hA,300,735,185,245,'solid'
  call drawHash s,hC,300,735,185,245,'dot'
  s~lineout('<text x="50" y="468" font-family="sans-serif" font-size="12">C changes every absolute level and doubles the clock scale.</text>')
  s~lineout('<text x="50" y="488" font-family="sans-serif" font-size="12">After declared offset/scale invariance, its cylindrical hash overlays A exactly.</text>')
  s~lineout('<text x="50" y="748" font-family="sans-serif" font-size="11">A solid / C dotted (the dotted paths disappear beneath the identical solid paths).</text>')

  /* Panel 4: what the index sees. */
  call panel s,600,420,570,350,'4. What the temporal-pattern index sees'
  tx=625; ty=470
  s~lineout('<text x="'||tx||'" y="'||ty||'" font-family="monospace" font-size="14">comparison                 dominant   kind/channel             total</text>')
  ty=ty+28; call row s,tx,ty,'A vs C economic twin',dAC
  ty=ty+28; call row s,tx,ty,'A vs D timing shock',dAD
  ty=ty+28; call row s,tx,ty,'A vs B price lookalike',dAB
  ty=ty+45
  s~lineout('<text x="'||tx||'" y="'||ty||'" font-family="sans-serif" font-size="13" font-weight="bold">The cognitive moment:</text>')
  ty=ty+24
  s~lineout('<text x="'||tx||'" y="'||ty||'" font-family="sans-serif" font-size="12">B looked like A on price, but its FX/relative/volatility vector turns elsewhere.</text>')
  ty=ty+21
  s~lineout('<text x="'||tx||'" y="'||ty||'" font-family="sans-serif" font-size="12">C looked numerically unrelated, but it is the same declared economic-time pattern.</text>')
  ty=ty+21
  s~lineout('<text x="'||tx||'" y="'||ty||'" font-family="sans-serif" font-size="12">D preserves market shape but moves one event in time, so elevation/time evidence changes.</text>')
  ty=ty+32
  s~lineout('<text x="'||tx||'" y="'||ty||'" font-family="sans-serif" font-size="12">Pattern matching asks: “where else did behaviour like this occur?” — not “where was price similar?”</text>')

  s~lineout('<text x="30" y="826" font-family="sans-serif" font-size="11">Channels: PRICE black (weight 1), RELATIVE blue (4), FX green (4), VOL orange (2). Significance weights are explicit policy, not hidden scalar economics.</text>')
  s~lineout('</svg>'); s~close
  return

panel: procedure
  use arg s,x,y,w,h,title
  s~lineout('<rect x="'||x||'" y="'||y||'" width="'||w||'" height="'||h||'" rx="10" fill="#fafafa" stroke="#d0d0d0"/>')
  s~lineout('<text x="'||(x+18)||'" y="'||(y+27)||'" font-family="sans-serif" font-size="16" font-weight="bold">'||title||'</text>')
  return

linePath: procedure
  use arg a,x0,y0,w,h,min,max
  d=''; n=a~items
  do i=1 to n
    x=x0+(i-1)*w/(n-1); y=y0-(a[i]-min)/(max-min)*h
    if i=1 then d='M '||format(x,,2)||' '||format(y,,2); else d=d||' L '||format(x,,2)||' '||format(y,,2)
  end
  return d

cylinder: procedure
  use arg s,cx,baseY,r,h
  s~lineout('<ellipse cx="'||cx||'" cy="'||baseY||'" rx="'||r||'" ry="'||format(r*.28,,2)||'" fill="none" stroke="#c8c8c8"/>')
  s~lineout('<ellipse cx="'||cx||'" cy="'||(baseY-h)||'" rx="'||r||'" ry="'||format(r*.28,,2)||'" fill="none" stroke="#c8c8c8"/>')
  s~lineout('<line x1="'||(cx-r)||'" y1="'||baseY||'" x2="'||(cx-r)||'" y2="'||(baseY-h)||'" stroke="#d8d8d8"/>')
  s~lineout('<line x1="'||(cx+r)||'" y1="'||baseY||'" x2="'||(cx+r)||'" y2="'||(baseY-h)||'" stroke="#d8d8d8"/>')
  s~lineout('<text x="'||(cx+r+8)||'" y="'||(baseY-h+4)||'" font-family="sans-serif" font-size="10">later</text>')
  s~lineout('<text x="'||(cx+r+8)||'" y="'||baseY||'" font-family="sans-serif" font-size="10">earlier</text>')
  return

drawHash: procedure
  use arg s,h,cx,baseY,r,height,mode
  strokes=.array~of('#111111','#2c5f9e','#327a4b','#a35d1d')
  widths=.array~of(2.5,2.2,2.2,1.8)
  if mode='solid' then dash=''
  else if mode='dash' then dash=' stroke-dasharray="10 5"'
  else dash=' stroke-dasharray="2 7"'
  z=h~heights; n=z~items
  do c=1 to h~channelCount
    rv=h~radii(c); d=''
    do i=1 to n
      theta=360*(i-1)/n; rr=r*rv[i]
      px=cx+rr*RxCalcCos(theta,12,'D')
      py=baseY-z[i]*height+rr*.28*RxCalcSin(theta,12,'D')
      if i=1 then d='M '||format(px,,2)||' '||format(py,,2); else d=d||' L '||format(px,,2)||' '||format(py,,2)
    end
    s~lineout('<path d="'||d||'" fill="none" stroke="'||strokes[c]||'" stroke-width="'||widths[c]||'"'||dash||'/>')
  end
  return

row: procedure
  use arg s,x,y,label,d
  text=left(label,26)||right(d~dominantDelta,8)||'   '||left(d~dominantKind||'/'||d~dominantChannel,23)||right(d~totalDelta,8)
  s~lineout('<text x="'||x||'" y="'||y||'" font-family="monospace" font-size="13">'||text||'</text>')
  return

::requires "OorexxML.cls"
