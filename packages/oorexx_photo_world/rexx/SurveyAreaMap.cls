/* Deterministic survey-area engineering map.  No image synthesis/pixel stitching. */
::class SurveyMapNode public
::method init
  expose _id _x _y _kind _label _evidence _uncertainty
  use strict arg id,x,y,kind='ANCHOR',label='',evidence='OBSERVED',uncertainty='5.0'
  _id=id; _x=x; _y=y; _kind=kind~upper; _label=label; _evidence=evidence~upper; _uncertainty=uncertainty
::method id
  expose _id
  return _id
::method x
  expose _x
  return _x
::method y
  expose _y
  return _y
::method kind
  expose _kind
  return _kind
::method label
  expose _label
  return _label
::method evidence
  expose _evidence
  return _evidence
::method uncertainty
  expose _uncertainty
  return _uncertainty

::class SurveyMapPath public
::method init
  expose _id _label _kind _evidence _uncertainty _points
  use strict arg id,label='',kind='ROAD',evidence='CARTOGRAPHIC',uncertainty='8.0'
  _id=id; _label=label; _kind=kind~upper; _evidence=evidence~upper; _uncertainty=uncertainty; _points=.array~new
::method add
  expose _points
  use strict arg x,y
  _points~append(x','y); return self
::method id
  expose _id
  return _id
::method label
  expose _label
  return _label
::method kind
  expose _kind
  return _kind
::method evidence
  expose _evidence
  return _evidence
::method uncertainty
  expose _uncertainty
  return _uncertainty
::method points
  expose _points
  return _points~copy

::class SurveyAreaMap public
::method init
  expose _title _nodes _paths
  use strict arg title='Survey area'
  _title=title; _nodes=.array~new; _paths=.array~new
::method addNode
  expose _nodes
  use strict arg n
  _nodes~append(n); return n
::method addPath
  expose _paths
  use strict arg p
  _paths~append(p); return p
::method nodes
  expose _nodes
  return _nodes~copy
::method paths
  expose _paths
  return _paths~copy
::method title
  expose _title
  return _title

::class SurveyAreaSvg public
::method render class
  use strict arg map,path,minX,maxX,minY,maxY,scale='2.0',margin=55
  w=(maxX-minX)*scale+2*margin; h=(maxY-minY)*scale+2*margin
  s=.array~new
  s~append('<svg xmlns="http://www.w3.org/2000/svg" width="'w'" height="'h'" viewBox="0 0 'w' 'h'">')
  s~append('<rect width="100%" height="100%" fill="white"/>')
  s~append('<text x="18" y="26" font-family="sans-serif" font-size="18" font-weight="bold">'self~esc(map~title)'</text>')
  s~append('<text x="18" y="44" font-family="sans-serif" font-size="11">ooRexx Photo Survey World — local engineering frame; provisional, non-survey coordinates</text>')
  /* grid: 50 m */
  gx=(minX%50)*50; if gx<minX then gx=gx+50
  do x=gx to maxX by 50
    px=margin+(x-minX)*scale
    s~append('<line x1="'px'" y1="'margin'" x2="'px'" y2="'h-margin'" stroke="#e5e5e5"/>')
  end
  gy=(minY%50)*50; if gy<minY then gy=gy+50
  do y=gy to maxY by 50
    py=margin+(maxY-y)*scale
    s~append('<line x1="'margin'" y1="'py'" x2="'w-margin'" y2="'py'" stroke="#e5e5e5"/>')
  end
  do p over map~paths
    pts=''
    do q over p~points
      parse var q x ',' y
      px=margin+(x-minX)*scale; py=margin+(maxY-y)*scale
      pts=pts px','py
    end
    style=self~pathStyle(p~kind,p~evidence)
    s~append('<polyline points="'pts'" fill="none" 'style'/>')
  end
  do n over map~nodes
    px=margin+(n~x-minX)*scale; py=margin+(maxY-n~y)*scale
    fill=self~nodeFill(n~evidence)
    s~append('<circle cx="'px'" cy="'py'" r="5" fill="'fill'" stroke="#111"/>')
    if n~label<>'' then s~append('<text x="'px+7'" y="'py-7'" font-family="sans-serif" font-size="11">'self~esc(n~label)' ±'n~uncertainty'm</text>')
  end
  /* north arrow and 100 m scale */
  s~append('<line x1="'w-40'" y1="70" x2="'w-40'" y2="35" stroke="#111" stroke-width="2"/>')
  s~append('<polygon points="'w-40',28 'w-46',40 'w-34',40" fill="#111"/><text x="'w-47'" y="22" font-family="sans-serif" font-size="12">N</text>')
  sx=margin; sy=h-25; sw=100*scale
  s~append('<line x1="'sx'" y1="'sy'" x2="'sx+sw'" y2="'sy'" stroke="#111" stroke-width="4"/><text x="'sx'" y="'sy-7'" font-family="sans-serif" font-size="11">100 m</text>')
  s~append('<text x="'sx+sw+25'" y="'sy'" font-family="sans-serif" font-size="11">observed=#1f6f3f  cartographic=#355c9a  derived=#a16b17</text>')
  s~append('</svg>')
  call lineout path
  do l over s; call lineout path,l; end
  call lineout path
  return path
/* Synchronous renderer helper. Do not send as a Message activity. */
::method pathStyle class private
  use strict arg kind,evidence
  if kind='WATER' then return 'stroke="#4f8fc9" stroke-width="9" opacity="0.75"'
  if kind='RAIL' then return 'stroke="#444" stroke-width="4" stroke-dasharray="9 5"'
  if evidence='OBSERVED' then c='#1f6f3f'
  else if evidence='DERIVED' then c='#a16b17'
  else c='#355c9a'
  return 'stroke="'c'" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" opacity="0.72"'
/* Synchronous renderer helper. Do not send as a Message activity. */
::method nodeFill class private
  use strict arg evidence
  if evidence='OBSERVED' then return '#1f6f3f'
  if evidence='DERIVED' then return '#a16b17'
  return '#355c9a'
/* Synchronous renderer helper. Do not send as a Message activity. */
::method esc class private
  use strict arg t
  t=t~changestr('&','&amp;'); t=t~changestr('<','&lt;'); t=t~changestr('>','&gt;'); return t
