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

::method advanceFor
  expose plan
  use strict arg bytes,size
  glyph=plan~glyphForBytes(bytes)
  if glyph==.nil then return 0
  return glyph~advance*size/plan~unitsPerEm

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


::class PdfManagedFontSet public
::method init
  expose manager purpose corpus tempDir prefix fonts byFaceId byBytes runPlan
  use strict arg manager, purpose, corpus, tempDir="/tmp", prefix="FB"
  runPlan=manager~planRunsForPurpose(purpose,corpus,24,"","TrueType")
  if \runPlan~fullyCovered then raise syntax 93.900 array("FontManager could not cover PDF corpus for purpose "||purpose)
  fonts=.Array~new; byFaceId=.Directory~new; byBytes=.Directory~new
  textByFace=.Directory~new; faceById=.Directory~new
  do run over runPlan~runs
    id=run~face~id; faceById~put(run~face,id)
    existing=""; if textByFace~hasIndex(id) then existing=textByFace~at(id)
    textByFace~put(existing||run~text,id)
    p=1
    do while p<=length(run~text)
      n=self~utf8Length(substr(run~text,p,1)); bytes=substr(run~text,p,n)
      byBytes~put(id,bytes); p=p+n
    end
  end
  seq=0
  do id over textByFace~allIndexes
    seq+=1; face=faceById~at(id); tag=self~subsetTag(prefix,seq)
    managed=.PdfManagedFont~new(manager,face,textByFace~at(id),tempDir,tag)
    entry=.Directory~new; entry["FACE_ID"]=id; entry["FONT"]=managed; entry["RESOURCE"]=""; entry["OBJECT_ID"]=0
    fonts~append(entry); byFaceId~put(entry,id)
  end
::attribute purpose get
::attribute runPlan get
::method install
  expose fonts
  use strict arg writer, resourcePrefix="FB"
  out=""; seq=0
  do entry over fonts
    seq+=1; resource=resourcePrefix||seq
    entry["RESOURCE"]=resource; entry["OBJECT_ID"]=entry["FONT"]~install(writer)
    out=out||" /"||resource||" "||entry["OBJECT_ID"]||" 0 R"
  end
  return out
::method measure
  expose byBytes byFaceId
  use strict arg text,size
  total=0; p=1
  do while p<=length(text)
    n=self~utf8Length(substr(text,p,1)); bytes=substr(text,p,n)
    if \byBytes~hasIndex(bytes) then raise syntax 93.900 array("PDF managed font set has no planned face for character")
    entry=byFaceId~at(byBytes~at(bytes)); total=total+entry["FONT"]~advanceFor(bytes,size); p=p+n
  end
  return total
::method draw
  use strict arg canvas,x,y,size,text
  cursor=x
  do seg over self~segments(text)
    entry=seg[1]; part=seg[2]
    canvas~textHex(cursor,y,size,entry["FONT"]~encodeHex(part),entry["RESOURCE"])
    cursor=cursor+entry["FONT"]~measure(part,size)~width
  end
  return canvas
::method segments
  expose byBytes byFaceId
  use strict arg text
  out=.Array~new; current=.nil; part=""; p=1
  do while p<=length(text)
    n=self~utf8Length(substr(text,p,1)); bytes=substr(text,p,n)
    if \byBytes~hasIndex(bytes) then raise syntax 93.900 array("PDF managed font set has no planned face for character")
    id=byBytes~at(bytes); entry=byFaceId~at(id)
    if current==.nil then do; current=entry; part=bytes; end
    else if current["FACE_ID"]==id then part=part||bytes
    else do; out~append(.Array~of(current,part)); current=entry; part=bytes; end
    p=p+n
  end
  if current<>.nil then out~append(.Array~of(current,part))
  return out
::method cleanup
  expose fonts
  do entry over fonts; entry["FONT"]~cleanup; end
  return self
::method utf8Length private
  use strict arg firstByte
  first=c2d(firstByte)
  if first>=240 then return 4
  if first>=224 then return 3
  if first>=192 then return 2
  return 1
::method subsetTag private
  use strict arg prefix,seq
  p=translate(prefix); p=changestr("-",p,""); p=changestr("_",p,"")
  if length(p)>2 then p=left(p,2)
  if length(p)<2 then p=p||copies("X",2-length(p))
  return p||right("0000"||seq,4)

::class PdfUnicode public
::method utf16Hex class
  use strict arg text
  out=""; p=1
  do while p<=length(text)
    first=c2d(substr(text,p,1)); n=1
    if first>=240 then n=4
    else if first>=224 then n=3
    else if first>=192 then n=2
    bytes=substr(text,p,n); cp=self~codepoint(bytes)
    if cp<=65535 then out=out||d2x(cp,4)
    else do
      v=cp-65536; hi=55296+(v%1024); lo=56320+(v//1024); out=out||d2x(hi,4)||d2x(lo,4)
    end
    p=p+n
  end
  return out
::method codepoint class private
  use strict arg bytes
  n=length(bytes); b1=c2d(substr(bytes,1,1))
  if n=1 then return b1
  b2=c2d(substr(bytes,2,1)); if n=2 then return (b1-192)*64+(b2-128)
  b3=c2d(substr(bytes,3,1)); if n=3 then return (b1-224)*4096+(b2-128)*64+(b3-128)
  b4=c2d(substr(bytes,4,1)); return (b1-240)*262144+(b2-128)*4096+(b3-128)*64+(b4-128)
