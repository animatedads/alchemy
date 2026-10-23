/* PdfManagedFonts.cls -- PDF adapter consuming the renderer-neutral FontManager. */

::class PdfManagedFont public
::method init
  expose manager sourceFace subsetFace plan byBytes byCid maxCid subsetPath tag
  use strict arg manager, sourceFace, corpus, tempDir="/tmp", tag="AAAAAA"
  if sourceFace == .nil then raise syntax 93.900 array("PdfManagedFont requires a FontFace")
  subsetPath=tempDir||"/oorexx-pdf-font-"||translate(time("L"),"",":.")||"-"||random(10000,99999)||".ttf"
  request=.FontPackageRequest~new(sourceFace,subsetPath)
  request~text=corpus
  request~subset=.true
  result=manager~package(request)
  if \result~success then raise syntax 93.900 array("Unable to package PDF font: " || result~message)
  subsetFace=.FontFace~new(sourceFace~family,subsetPath,sourceFace~style,sourceFace~fullName,sourceFace~postscriptName,sourceFace~weight,sourceFace~slant,sourceFace~spacing,.true,"TrueType","PDF-SUBSET",0)
  plan=manager~glyphPlan(subsetFace,corpus)
  byBytes=.Directory~new; byCid=.Array~new; maxCid=0
  do glyph over plan~glyphs
    if \byBytes~hasIndex(glyph~utf8Bytes) then do
      maxCid=maxCid+1
      entry=.Array~of(maxCid,glyph)
      byBytes~put(entry,glyph~utf8Bytes)
      byCid~append(entry)
    end
  end

::attribute sourceFace get
::attribute subsetFace get
::attribute plan get
::attribute subsetPath get

::method measure
  expose plan
  use strict arg text,size
  return plan~measure(text,size)

::method encodeHex
  expose byBytes
  use strict arg text
  out=""; p=1
  do while p<=length(text)
    first=c2d(substr(text,p,1)); n=1
    if first>=240 then n=4
    else if first>=224 then n=3
    else if first>=192 then n=2
    bytes=substr(text,p,n)
    if byBytes~hasIndex(bytes) then cid=byBytes~at(bytes)[1]
    else do
      q='3f'x
      if byBytes~hasIndex(q) then cid=byBytes~at(q)[1]
      else cid=0
    end
    out=out||d2x(cid,4)
    p=p+n
  end
  return out

::method unicodeHex
  expose byBytes
  use strict arg text
  out=""; p=1
  do while p<=length(text)
    first=c2d(substr(text,p,1)); n=1
    if first>=240 then n=4
    else if first>=224 then n=3
    else if first>=192 then n=2
    bytes=substr(text,p,n)
    if byBytes~hasIndex(bytes) then out=out||byBytes~at(bytes)[2]~unicodeHex
    else out=out||"003F"
    p=p+n
  end
  return out

::method install
  expose plan byCid maxCid subsetPath tag
  use strict arg writer
  call stream subsetPath,'c','open read'
  size=stream(subsetPath,'c','query size')
  bytes=charin(subsetPath,1,size)
  call stream subsetPath,'c','close'
  fontFileId=writer~addStream("/Length1 "||length(bytes),bytes,.false)

  upm=plan~unitsPerEm
  xMin=self~scale1000(plan~xMin,upm); yMin=self~scale1000(plan~yMin,upm)
  xMax=self~scale1000(plan~xMax,upm); yMax=self~scale1000(plan~yMax,upm)
  ascent=self~scale1000(plan~ascender,upm); descent=self~scale1000(plan~descender,upm)
  ps=plan~postscriptName
  if strip(ps)=="" then ps=plan~face~postscriptName
  if strip(ps)=="" then ps=changestr(" ",plan~face~family,"-")
  ps=self~pdfName(ps)
  base=tag||"+"||ps
  flags=32
  if plan~face~isMonospace then flags=flags+1
  descriptor="<< /Type /FontDescriptor /FontName /"||base||" /Flags "||flags||" /FontBBox ["||xMin||" "||yMin||" "||xMax||" "||yMax||"] /ItalicAngle 0 /Ascent "||ascent||" /Descent "||descent||" /CapHeight "||ascent||" /StemV 80 /FontFile2 "||fontFileId||" 0 R >>"
  descriptorId=writer~addObject(descriptor)

  gidMap='0000'x
  widths=""
  do entry over byCid
    cid=entry[1]; glyph=entry[2]
    gidMap=gidMap||x2c(d2x(glyph~glyphId,4))
    widths=widths||" "||self~scale1000(glyph~advance,upm)
  end
  gidMapId=writer~addStream("",gidMap,.true)
  cidFont="<< /Type /Font /Subtype /CIDFontType2 /BaseFont /"||base||" /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor "||descriptorId||" 0 R /DW 1000"
  if maxCid>0 then cidFont=cidFont||" /W [1 ["||strip(widths)||"]]"
  cidFont=cidFont||" /CIDToGIDMap "||gidMapId||" 0 R >>"
  cidFontId=writer~addObject(cidFont)

  cmap=self~toUnicodeCMap
  cmapId=writer~addStream("",cmap,.true)
  type0="<< /Type /Font /Subtype /Type0 /BaseFont /"||base||" /Encoding /Identity-H /DescendantFonts ["||cidFontId||" 0 R] /ToUnicode "||cmapId||" 0 R >>"
  return writer~addObject(type0)

::method toUnicodeCMap private
  expose byCid
  eol='0a'x
  s="/CIDInit /ProcSet findresource begin"||eol||"12 dict begin"||eol||"begincmap"||eol||"/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def"||eol||"/CMapName /Adobe-Identity-UCS def"||eol||"/CMapType 2 def"||eol||"1 begincodespacerange"||eol||"<0000> <FFFF>"||eol||"endcodespacerange"||eol
  total=byCid~items; posn=1
  do while posn<=total
    count=min(100,total-posn+1)
    s=s||count||" beginbfchar"||eol
    do i=posn to posn+count-1
      entry=byCid[i]; s=s||"<"||d2x(entry[1],4)||"> <"||entry[2]~unicodeHex||">"||eol
    end
    s=s||"endbfchar"||eol
    posn=posn+count
  end
  s=s||"endcmap"||eol||"CMapName currentdict /CMap defineresource pop"||eol||"end"||eol||"end"||eol
  return s

::method cleanup
  expose subsetPath
  if subsetPath \== "" then call SysFileDelete subsetPath
  return self

::method scale1000 private
  use strict arg value,upm
  return ((value*1000/upm)~round)

::method pdfName private
  use strict arg value
  out=""
  do i=1 to length(value)
    ch=substr(value,i,1)
    if pos(ch,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")>0 then out=out||ch
    else if pos(ch,"-_+")>0 then out=out||ch
  end
  if out=="" then out="ManagedFont"
  return out

::requires "FontManager.cls"
::requires "FontProviders.cls"
