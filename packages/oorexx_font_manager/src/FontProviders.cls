/* FontProviders.cls -- concrete discovery and transformation providers. */

::class FontManifestProvider public
::method init
  expose faces
  faces=.Array~new
::method add
  expose faces
  use strict arg face
  faces~append(face); return self
::method discover
  expose faces
  use arg refresh=.false
  return faces~copy
::method find
  expose faces
  use strict arg query
  if faces~items==0 then return .nil
  /* Manager performs authoritative scoring. Return candidates only when a family is exact. */
  fams=query~families
  do wanted over fams
    do face over faces
      if translate(strip(face~family))==translate(strip(wanted)) then return face
    end
  end
  return faces[1]
::method name
  return "MANIFEST"

::class FontconfigProvider public
::method init
  expose fcList fcMatch tempDir
  use arg fcList="fc-list", fcMatch="fc-match", tempDir="/tmp"
::method name
  return "FONTCONFIG"
::method discover
  expose fcList tempDir
  use arg refresh=.false
  out=self~tempFile("list")
  fmt="%{file}\t%{family[0]}\t%{style[0]}\t%{fullname[0]}\t%{postscriptname}\t%{weight}\t%{slant}\t%{spacing}\t%{scalable}\t%{fontformat}\n"
  command=fcList||" --format='"||fmt||"' > "||self~quote(out)||" 2>/dev/null"
  address system command
  if rc \== 0 then return .Array~new
  foundFaces=self~readFaces(out)
  call SysFileDelete out
  return foundFaces
::method find
  expose fcMatch tempDir
  use strict arg query
  pattern=""
  fams=query~families; if fams~items>0 then pattern=fams[1]
  if query~monospace then do; if pattern \== "" then pattern=pattern||":"; pattern=pattern||"spacing=100"; end
  if query~weight>0 then do; if pattern \== "" then pattern=pattern||":"; pattern=pattern||"weight="||query~weight; end
  out=self~tempFile("match")
  fmt="%{file}\t%{family[0]}\t%{style[0]}\t%{fullname[0]}\t%{postscriptname}\t%{weight}\t%{slant}\t%{spacing}\t%{scalable}\t%{fontformat}\n"
  command=fcMatch||" --format='"||fmt||"' "||self~quote(pattern)||" > "||self~quote(out)||" 2>/dev/null"
  address system command
  if rc \== 0 then return .nil
  a=self~readFaces(out); call SysFileDelete out
  if a~items==0 then return .nil
  return a[1]
::method findCovering
  expose fcMatch tempDir
  use strict arg query, codepoint, language=""
  pattern=":charset="||d2x(codepoint)
  if language<>"" then pattern=pattern||":lang="||language
  if query~monospace then pattern=pattern||":spacing=100"
  out=self~tempFile("cover")
  fmt="%{file}\t%{family[0]}\t%{style[0]}\t%{fullname[0]}\t%{postscriptname}\t%{weight}\t%{slant}\t%{spacing}\t%{scalable}\t%{fontformat}\n"
  command=fcMatch||" --format='"||fmt||"' "||self~quote(pattern)||" > "||self~quote(out)||" 2>/dev/null"
  address system command
  if rc \== 0 then return .nil
  a=self~readFaces(out); call SysFileDelete out
  if a~items==0 then return .nil
  return a[1]
::method readFaces private
  use strict arg file
  a=.Array~new
  do while lines(file)>0
    line=linein(file); parts=line~makeArray('09'x)
    if parts~items>=2 then do
      path=parts[1]; family=parts[2]
      style=self~part(parts,3,"Regular"); full=self~part(parts,4,""); ps=self~part(parts,5,"")
      weight=self~number(self~part(parts,6,"80"),80); slant=self~number(self~part(parts,7,"0"),0); spacing=self~number(self~part(parts,8,"0"),0)
      scalable=translate(self~part(parts,9,"True")) \== "FALSE"; format=self~part(parts,10,"")
      if strip(family) \== "" then a~append(.FontFace~new(family,path,style,full,ps,weight,slant,spacing,scalable,format,"FONTCONFIG"))
    end
  end
  call lineout file
  return a
::method part private
  use strict arg a,n,defaultValue=""
  if a~items>=n then return strip(a[n])
  return defaultValue
::method number private
  use strict arg value,defaultValue
  if datatype(strip(value),"N") then return strip(value)+0
  return defaultValue
::method tempFile private
  expose tempDir
  use strict arg suffix
  return tempDir||"/oorexx-font-"||translate(time("L"),"",":.")||"-"||suffix||"-"||random(1000,9999)||".txt"
::method quote private
  use strict arg value
  return "'"||changestr("'",value,"'\\''")||"'"

::class PyftsubsetTransformer public
::method init
  expose executable
  use arg executable="pyftsubset"
::method name
  return "PYFTSUBSET"
::method supports
  use strict arg request
  if request~face~path == "" then return .false
  return .true
::method transform
  expose executable
  use strict arg request
  input=request~face~path; output=request~outputPath
  if strip(output)=="" then return .FontPackageResult~new(.false,"",self~name,"Output path is required")
  command=executable||" "||self~quote(input)||" --output-file="||self~quote(output)
  textFile=""
  if request~subset then do
    if request~text \== "" then do
      textFile=output||".subset-text"
      call charout textFile, request~text
      call stream textFile,'c','close'
      command=command||" --text-file="||self~quote(textFile)
    end
    else if request~characters \== "" then command=command||" --unicodes="||self~quote(request~characters)
  end
  if request~retainGlyphNames then command=command||" --glyph-names"
  flavor=lower(strip(request~flavor))
  if flavor=="woff" | flavor=="woff2" then command=command||" --flavor="||flavor
  command=command||" --layout-features='*' --no-hinting"
  address system command
  commandRc=rc
  if textFile \== "" then call SysFileDelete textFile
  if commandRc \== 0 then return .FontPackageResult~new(.false,"",self~name,"Transformer returned rc="||commandRc,command)
  if stream(output,"c","query exists") == "" then return .FontPackageResult~new(.false,"",self~name,"Transformer did not create output",command)
  return .FontPackageResult~new(.true,output,self~name,"OK",command)
::method quote private
  use strict arg value
  return "'"||changestr("'",value,"'\\''")||"'"

::requires "FontManager.cls"

::class FontToolsMetricsProvider public
::method init
  expose python helper tempDir
  use arg helper="fonttools_service.py", python="python3", tempDir="/tmp"
::method name
  return "FONTTOOLS"
::method supports
  use strict arg face
  return face~path \== ""
::method measure
  expose python helper tempDir
  use strict arg face, text, size
  textFile=self~tempFile("text"); outFile=self~tempFile("metrics")
  call lineout textFile, text
  call lineout textFile
  command=python||" "||self~quote(helper)||" measure --font "||self~quote(face~path)||" --index "||face~index||" --size "||size||" --text-file "||self~quote(textFile)||" > "||self~quote(outFile)||" 2>/dev/null"
  address system command
  commandRc=rc
  if commandRc \== 0 | lines(outFile)==0 then do
    call SysFileDelete textFile; call SysFileDelete outFile
    return .FontMeasurement~new(length(text)*size*0.52,size*0.8,-size*0.2,1000,"APPROXIMATE")
  end
  line=linein(outFile); call lineout outFile
  parts=line~makeArray('09'x)
  call SysFileDelete textFile; call SysFileDelete outFile
  if parts~items<4 then return .FontMeasurement~new(length(text)*size*0.52,size*0.8,-size*0.2,1000,"APPROXIMATE")
  return .FontMeasurement~new(parts[1]+0,parts[2]+0,parts[3]+0,parts[4]+0,self~name)
::method tempFile private
  expose tempDir
  use strict arg suffix
  return tempDir||"/oorexx-font-"||translate(time("L"),"",":.")||"-"||suffix||"-"||random(1000,9999)||".txt"
::method quote private
  use strict arg value
  return "'"||changestr("'",value,"'\\''")||"'"

::class FontToolsGlyphProvider public
::method init
  expose python helper tempDir
  use arg helper="fonttools_service.py", python="python3", tempDir="/tmp"
::method name
  return "FONTTOOLS-GLYPHS"
::method supports
  use strict arg face
  return face~path \== ""
::method plan
  expose python helper tempDir
  use strict arg face, text
  textFile=self~tempFile("glyph-text"); outFile=self~tempFile("glyph-plan")
  call charout textFile, text
  call stream textFile, 'c', 'close'
  command=python||" "||self~quote(helper)||" glyphs --font "||self~quote(face~path)||" --index "||face~index||" --text-file "||self~quote(textFile)||" > "||self~quote(outFile)||" 2>/dev/null"
  address system command
  commandRc=rc
  call SysFileDelete textFile
  if commandRc \== 0 | lines(outFile)==0 then do
    call SysFileDelete outFile
    raise syntax 93.900 array("Font glyph backend failed rc=" || commandRc)
  end
  meta=linein(outFile)~makeArray('09'x)
  if meta~items < 10 | meta[1] \== "META" then do
    call lineout outFile; call SysFileDelete outFile
    raise syntax 93.900 array("Font glyph backend returned malformed metadata")
  end
  plan=.FontGlyphPlan~new(face,meta[2]+0,meta[3]+0,meta[4]+0,meta[5]+0,meta[6]+0,meta[7]+0,meta[8]+0,meta[9],self~name)
  do while lines(outFile)>0
    parts=linein(outFile)~makeArray('09'x)
    if parts~items >= 6 & parts[1] == "G" then do
      bytes=x2c(parts[2])
      plan~addGlyph(.FontGlyph~new(bytes,parts[3],parts[4]+0,parts[5]+0,parts[6]+0))
    end
  end
  call lineout outFile
  call SysFileDelete outFile
  return plan
::method tempFile private
  expose tempDir
  use strict arg suffix
  return tempDir||"/oorexx-font-"||translate(time("L"),"",":.")||"-"||suffix||"-"||random(1000,9999)||".txt"
::method quote private
  use strict arg value
  return "'"||changestr("'",value,"'\\''")||"'"
