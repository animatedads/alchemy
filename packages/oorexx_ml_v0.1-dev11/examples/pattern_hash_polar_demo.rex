/* Polar pattern hashing demo.
 * Same curve with different numbers/sample density should hash the same.
 * Small deformation stays near.  A changed turning structure moves far.
 */
parse arg svgOut
if svgOut='' then svgOut='pattern_hash_polar_demo.svg'
base=.array~of(0,1,3,7,10,7,3,1)
scaled=.array~of(100,110,130,170,200,170,130,110)
stretched=.array~new
n=base~items
do j=0 to 2*n-1
  phase=j/2; lo=trunc(phase)+1; frac=phase-trunc(phase); hi=lo+1; if hi>n then hi=1
  stretched~append(base[lo]+frac*(base[hi]-base[lo]))
end
near=.array~of(0,.95,3.1,6.9,10,7.05,2.95,1.05)
different=.array~of(0,4,8,3,7,10,4,1)
policy=.MLPatternHashPolicy~new(36,48,1,4,10,.true,.false)
schema=.MLPatternHashSchema~new(policy,'POLAR-DEMO')
h0=schema~encode(base); hs=schema~encode(scaled); ht=schema~encode(stretched); hn=schema~encode(near); hd=schema~encode(different)
say 'POLICY' policy~canonicalText
say 'BASE source min/max='h0~sourceMinimum'/'h0~sourceMaximum 'rotation='h0~rotation
sameScaled=(h0~key==hs~key); say 'SCALED source min/max='||hs~sourceMinimum||'/'||hs~sourceMaximum||' sameHash='||sameScaled
sameStretched=(h0~key==ht~key); say 'STRETCHED sourceSamples='||ht~sourceCount||' sameHash='||sameStretched
call showDiff 'scaled/offset',schema~difference(h0,hs)
call showDiff 'sample-density',schema~difference(h0,ht)
call showDiff 'small deformation',schema~difference(h0,hn)
call showDiff 'different curve',schema~difference(h0,hd)
say
say 'ANGLE  RADIUS  BIN   (base polar grid)'
do p over h0~polarPoints
  say right(format(p~angleDegrees,3,1),6) right(format(p~radius,1,4),8) right(p~radialCoordinate,4)
end
call writeSvg svgOut,h0,hs,hn,hd
say 'SVG 'svgOut
say 'PASS pattern_hash_polar_demo'
exit 0

writeSvg: procedure
  use arg path,baseHash,scaledHash,nearHash,diffHash
  call RxFuncAdd 'RxCalcSin','rxmath','RxCalcSin'
  call RxFuncAdd 'RxCalcCos','rxmath','RxCalcCos'
  s=.stream~new(path); s~open('write replace')
  w=760; h=760; cx=380; cy=395; pr=280
  s~lineout('<svg xmlns="http://www.w3.org/2000/svg" width="760" height="760" viewBox="0 0 760 760">')
  s~lineout('<rect width="760" height="760" fill="white"/>')
  s~lineout('<text x="24" y="34" font-family="sans-serif" font-size="22" font-weight="bold">Polar pattern hash: numbers disappear, shape remains</text>')
  s~lineout('<text x="24" y="58" font-family="sans-serif" font-size="13">centre = source minimum; radius = normalized value; angle = normalized curve progress</text>')
  do ring=1 to 4
    rr=pr*ring/4
    s~lineout('<circle cx="'||cx||'" cy="'||cy||'" r="'||format(rr,,2)||'" fill="none" stroke="#d0d0d0" stroke-width="1"/>')
  end
  do angle=0 to 315 by 45
    x=cx+pr*RxCalcCos(angle,12,'D'); y=cy-pr*RxCalcSin(angle,12,'D')
    lx=cx+(pr+20)*RxCalcCos(angle,12,'D'); ly=cy-(pr+20)*RxCalcSin(angle,12,'D')
    s~lineout('<line x1="'||cx||'" y1="'||cy||'" x2="'||format(x,,2)||'" y2="'||format(y,,2)||'" stroke="#dddddd" stroke-width="1"/>')
    s~lineout('<text x="'||format(lx,,2)||'" y="'||format(ly,,2)||'" font-family="sans-serif" font-size="11" text-anchor="middle">'||angle||'°</text>')
  end
  s~lineout('<circle cx="'||cx||'" cy="'||cy||'" r="4" fill="#111"/>')
  s~lineout('<text x="'||(cx+8)||'" y="'||(cy-8)||'" font-family="sans-serif" font-size="11">minimum</text>')
  s~lineout('<path d="'||svgCurve(scaledHash,cx,cy,pr)||'" fill="none" stroke="#999" stroke-width="5" stroke-dasharray="2 8"/>')
  s~lineout('<path d="'||svgCurve(baseHash,cx,cy,pr)||'" fill="none" stroke="#111" stroke-width="2.5"/>')
  s~lineout('<path d="'||svgCurve(nearHash,cx,cy,pr)||'" fill="none" stroke="#666" stroke-width="2" stroke-dasharray="10 5"/>')
  s~lineout('<path d="'||svgCurve(diffHash,cx,cy,pr)||'" fill="none" stroke="#000" stroke-width="1.5" stroke-dasharray="18 5 3 5"/>')
  s~lineout('<text x="24" y="706" font-family="sans-serif" font-size="12">solid: base 0..10 | dotted: affine 100..200 (exactly same hash) | dashed: small deformation</text>')
  s~lineout('<text x="24" y="726" font-family="sans-serif" font-size="12">dash-dot: changed turn structure | centre: source minimum | ring angle: normalized curve progress</text>')
  s~lineout('<text x="24" y="746" font-family="sans-serif" font-size="12">The affine curve overlays the base: offset and amplitude are evidence, not pattern identity.</text>')
  s~lineout('</svg>'); s~close
  return

svgCurve: procedure
  use arg hash,cx,cy,pr
  pts=hash~polarPoints; d=''
  do i=1 to pts~items
    p=pts[i]; angle=p~angleDegrees; rr=pr*p~radius
    x=cx+rr*RxCalcCos(angle,12,'D'); y=cy-rr*RxCalcSin(angle,12,'D')
    if i=1 then d='M '||format(x,,2)||' '||format(y,,2)
    else d=d||' L '||format(x,,2)||' '||format(y,,2)
  end
  return d||' Z'
showDiff: procedure
  use arg label,d
  say left(label,20) 'dominant='d~dominantDelta 'total='d~totalDelta 'radialMax='d~radialMax 'slopeMax='d~slopeMax 'curvatureMax='d~curvatureMax
  return
::requires "OorexxML.cls"
