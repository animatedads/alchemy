/* Dependency-free SVG engineering views. SVG is output, not geometric authority. */
::class SurveySvg public
::method topDown class
  use strict arg world,path,title='Photo Survey World - top down',scale=12,margin=40
  minX=-20; maxX=100; minY=-25; maxY=25
  w=(maxX-minX)*scale+2*margin; h=(maxY-minY)*scale+2*margin
  s=.array~new
  s~append('<svg xmlns="http://www.w3.org/2000/svg" width="'w'" height="'h'" viewBox="0 0 'w' 'h'">')
  s~append('<rect width="100%" height="100%" fill="white"/>')
  s~append('<text x="20" y="25" font-family="sans-serif" font-size="18">'title'</text>')
  /* street/pedestrian band */
  x0=margin+(0-minX)*scale; y0=margin+(maxY-10)*scale
  s~append('<rect x="'x0'" y="'y0'" width="'100*scale'" height="'20*scale'" fill="#e9e1d2" stroke="#777"/>')
  do id over world~objectIds
    o=world~object(id); p=o~pose~position
    x=margin+(p~x-o~size~width/2-minX)*scale
    y=margin+(maxY-(p~y+o~size~depth/2))*scale
    ww=o~size~width*scale; hh=o~size~depth*scale
    s~append('<rect x="'x'" y="'y'" width="'ww'" height="'hh'" fill="#c8b59c" stroke="#333"/>')
    s~append('<text x="'x+3'" y="'y+14'" font-family="sans-serif" font-size="11">'o~id'</text>')
  end
  do id over world~cameraIds
    c=world~camera(id); p=c~pose~position
    x=margin+(p~x-minX)*scale; y=margin+(maxY-p~y)*scale
    s~append('<circle cx="'x'" cy="'y'" r="5" fill="#111"/>')
    s~append('<text x="'x+7'" y="'y-7'" font-family="sans-serif" font-size="11">'c~id'</text>')
  end
  s~append('</svg>'); self~writeLines(path,s); return path
/* Synchronous file-output helper. Do not send as a Message activity. */
::method writeLines class private
  use strict arg path,lines
  call lineout path
  do l over lines; call lineout path,l; end
  call lineout path
  return
