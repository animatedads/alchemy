/* ooRexx Source / Code / Class Editor v0.1-dev3
 * Language-neutral editing core with first-tier ooRexx, C, C++, JSON and Python profiles.
 * The implementation language is ooRexx; source semantics stay language-neutral.
 */

::class SourceLanguageRegistry public
::method init
  expose extensions
  extensions = .directory~new
  do e over .array~of('.rex','.cls') ; extensions[e]='oorexx'; end
  do e over .array~of('.c') ; extensions[e]='c'; end
  do e over .array~of('.cc','.cpp','.cxx','.h','.hh','.hpp','.hxx','.ipp','.tpp','.inl','.inc') ; extensions[e]='cpp'; end
  do e over .array~of('.json','.jsonc') ; extensions[e]='json'; end
  do e over .array~of('.py','.pyi') ; extensions[e]='python'; end
  do e over .array~of('.md','.txt','.cfg','.conf','.ini') ; extensions[e]='text'; end

::method languageFor
  expose extensions
  use arg path, explicit=''
  if explicit <> '' then return explicit~lower
  name = path~string
  base = .SourceEditorUtil~baseName(name)
  if base~caselessEquals('Makefile') then return 'make'
  if base~caselessEquals('CMakeLists.txt') then return 'cmake'
  dot = name~lastPos('.')
  if dot = 0 then return 'text'
  ext = name~substr(dot)~lower
  if extensions~hasIndex(ext) then return extensions[ext]
  return 'text'

::class SourceSymbol public
::method init
  expose kind name startLine endLine owner detail
  use arg kind, name, startLine, endLine=0, owner='', detail=''
  self~kind=kind; self~name=name; self~startLine=startLine; self~endLine=endLine; self~owner=owner; self~detail=detail
::attribute kind
::attribute name
::attribute startLine
::attribute endLine
::attribute owner
::attribute detail
::method asString
  expose kind name startLine endLine owner
  s=kind name 'line' startLine
  if endLine>0 then s=s||'..'||endLine
  if owner<>'' then s=s 'owner='owner
  return s

::class SourceDocument public
::method init
  expose path language registry originalText lines newline trailingNewline
  use arg path, language=''
  registry=.SourceLanguageRegistry~new
  self~path=path~string
  self~language=registry~languageFor(self~path,language)
  originalText=.SourceEditorUtil~readAll(self~path)
  if originalText~pos(d2c(13)||d2c(10))>0 then newline=d2c(13)||d2c(10)
  else newline=d2c(10)
  trailingNewline=(originalText~right(newline~length)=newline)
  normalized=originalText~changeStr(d2c(13)||d2c(10),d2c(10))~changeStr(d2c(13),d2c(10))
  lines=normalized~makeArray(d2c(10))
  if lines=.nil then lines=.array~new
::attribute path
::attribute language

::method lineCount
  expose lines
  return lines~items

::method line
  expose lines
  use arg n
  if n<1 | n>lines~items then raise syntax 88.900 array('line out of range:' n)
  return lines[n]

::method text
  expose lines newline trailingNewline
  out=''
  do i=1 to lines~items
    if i>1 then out=out||newline
    out=out||lines[i]
  end
  if trailingNewline & lines~items>0 then out=out||newline
  return out

::method dirty
  expose originalText
  return self~text <> originalText

::method replaceLine
  expose lines
  use arg n, value
  if n<1 | n>lines~items then raise syntax 88.900 array('line out of range:' n)
  if value~pos(d2c(10))>0 | value~pos(d2c(13))>0 then raise syntax 88.900 array('replaceLine accepts exactly one logical line')
  lines[n]=value
  return self

::method insertBefore
  expose lines
  use arg n, value
  if n<1 | n>lines~items+1 then raise syntax 88.900 array('insert position out of range:' n)
  addition=.SourceEditorUtil~textLines(value)
  lines=.SourceEditorUtil~splice(lines,n,n-1,addition)
  return self

::method insertAfter
  use arg n, value
  return self~insertBefore(n+1,value)

::method deleteRange
  expose lines
  use arg first,last=.nil
  if last=.nil then last=first
  if first<1 | last<first | last>lines~items then raise syntax 88.900 array('delete range out of range:' first last)
  lines=.SourceEditorUtil~splice(lines,first,last,.array~new)
  return self

::method replaceRange
  expose lines
  use arg first,last,value
  if first<1 | last<first | last>lines~items then raise syntax 88.900 array('replace range out of range:' first last)
  lines=.SourceEditorUtil~splice(lines,first,last,.SourceEditorUtil~textLines(value))
  return self

::method symbols
  expose language lines
  scanner=.SourceScannerFactory~new~scannerFor(language)
  return scanner~symbols(lines)

::method findSymbol
  use arg name, kind=''
  found=.array~new
  do s over self~symbols
    if s~name~caselessEquals(name) then do
      if kind='' | s~kind~caselessEquals(kind) then found~append(s)
    end
  end
  if found~items=0 then raise syntax 88.900 array('symbol not found:' name)
  if found~items>1 then raise syntax 88.900 array('symbol is ambiguous:' name 'matches' found~items)
  return found[1]

::method replaceSymbol
  use arg name, replacement, kind=''
  s=self~findSymbol(name,kind)
  if s~endLine=0 then raise syntax 88.900 array('symbol has no bounded editable range:' name)
  self~replaceRange(s~startLine,s~endLine,replacement)
  return self

::method insertIntoSymbol
  expose lines language
  use arg name, text, kind=''
  s=self~findSymbol(name,kind)
  if s~endLine=0 then raise syntax 88.900 array('symbol has no bounded editable range:' name)
  if language='cpp' | language='c' then do
    /* Insert immediately before the closing brace line of a bounded C/C++ scope. */
    self~insertBefore(s~endLine,text)
  end
  else if language='oorexx' then do
    self~insertBefore(s~endLine+1,text)
  end
  else self~insertBefore(s~endLine,text)
  return self

::method validate
  expose language
  if language='json' then return .JsonSourceValidator~new~validate(self~text)
  /* dev1: C/C++/ooRexx/Python structural validation is intentionally lexical only. */
  return .true

::method save
  expose path originalText
  use arg keepBackup=.true
  current=.SourceEditorUtil~readAll(path)
  if current<>originalText then raise syntax 88.900 array('source generation changed since load; refusing overwrite:' path)
  candidate=self~text
  tmp=path||'.newshell-new'
  bak=path||'.newshell-bak'
  dummy=.SourceEditorUtil~writeAll(tmp,candidate)
  if keepBackup then dummy=.SourceEditorUtil~writeAll(bak,current)
  /* RexxUtil SysFileMove does not replace an existing target.  Until oorexx_atomic_file
     is wired in, publish by direct replacement only after exact-generation check and
     retain a complete sibling backup.  This is recovery-oriented, not crash-durable. */
  dummy=.SourceEditorUtil~writeAll(path,candidate)
  call SysFileDelete tmp
  originalText=candidate
  return path

::method find
  use arg needle, mode='text', caseMode='sensitive'
  return .SourceFinder~new(self)~find(needle,mode,caseMode)
::method grep
  use arg pattern, mode='text', caseMode='sensitive'
  return .SourceFinder~new(self)~grep(pattern,mode,caseMode)
::class SourceMatch public
::method init
  use arg path,lineNumber,column,text,kind='text',symbol=''
  self~path=path; self~lineNumber=lineNumber; self~column=column; self~text=text; self~kind=kind; self~symbol=symbol
::attribute path
::attribute lineNumber
::attribute column
::attribute text
::attribute kind
::attribute symbol
::method asString
  expose path lineNumber column text kind symbol
  suffix=''
  if symbol<>'' then suffix=' symbol='symbol
  return path':'lineNumber':'column' ['kind'] 'text||suffix

::class SourceFinder public
::method init
  use arg document
  self~document=document
::attribute document

::method find
  expose document
  use arg needle, mode='text', caseMode='sensitive'
  if needle='' then raise syntax 88.900 array('find needle must not be empty')
  mode=mode~lower; caseMode=caseMode~lower
  if mode<>'text' & mode<>'code' then raise syntax 88.900 array('find mode must be text or code:' mode)
  if caseMode<>'sensitive' & caseMode<>'insensitive' then raise syntax 88.900 array('case mode must be sensitive or insensitive:' caseMode)
  lines=.array~new
  do i=1 to document~lineCount; lines~append(document~line(i)); end
  if mode='code' then hay=.SourceEditorUtil~codeProjection(lines,document~language); else hay=lines
  syms=document~symbols
  out=.array~new
  do i=1 to hay~items
    search=hay[i]; target=needle
    if caseMode='insensitive' then do; search=search~lower; target=target~lower; end
    start=1
    do while start<=search~length+1
      rel=search~substr(start)~pos(target)
      if rel=0 then leave
      col=start+rel-1
      sym=self~symbolAt(syms,i)
      out~append(.SourceMatch~new(document~path,i,col,document~line(i),mode,sym))
      start=col+max(1,target~length)
    end
  end
  return out

::method grep
  expose document
  use arg pattern, mode='text', caseMode='sensitive'
  if pattern='' then raise syntax 88.900 array('grep pattern must not be empty')
  mode=mode~lower; caseMode=caseMode~lower
  if mode<>'text' & mode<>'code' then raise syntax 88.900 array('grep mode must be text or code:' mode)
  if caseMode<>'sensitive' & caseMode<>'insensitive' then raise syntax 88.900 array('case mode must be sensitive or insensitive:' caseMode)
  lines=.array~new
  do i=1 to document~lineCount; lines~append(document~line(i)); end
  if mode='code' then hay=.SourceEditorUtil~codeProjection(lines,document~language); else hay=lines
  syms=document~symbols
  out=.array~new
  regexPattern=pattern
  if caseMode='insensitive' then regexPattern=regexPattern~lower
  signal on syntax name badPattern
  re=.RegularExpression~new(regexPattern)
  signal off syntax
  do i=1 to hay~items
    search=hay[i]
    if caseMode='insensitive' then search=search~lower
    start=1
    do while start<=search~length+1
      rel=re~pos(search~substr(start))
      if rel=0 then leave
      col=start+rel-1
      matchEnd=start+re~position-1
      sym=self~symbolAt(syms,i)
      out~append(.SourceMatch~new(document~path,i,col,document~line(i),mode,sym))
      if matchEnd<col then start=col+1
      else start=matchEnd+1
    end
  end
  return out
badPattern:
  raise syntax 88.900 array('invalid regular expression:' pattern condition('D'))

::method symbolAt private
  use arg syms,lineNumber
  do s over syms
    if lineNumber>=s~startLine & (s~endLine=0 | lineNumber<=s~endLine) then return s~name
  end
  return ''
::class SourceScannerFactory public
::method scannerFor
  use arg language
  select
    when language='oorexx' then return .RexxSourceScanner~new
    when language='c' then return .CppSourceScanner~new('c')
    when language='cpp' then return .CppSourceScanner~new('cpp')
    when language='python' then return .PythonSourceScanner~new
    when language='json' then return .JsonSourceScanner~new
    otherwise return .TextSourceScanner~new
  end

::class TextSourceScanner public
::method symbols
  use arg lines
  return .array~new

::class RexxSourceScanner subclass TextSourceScanner public
::method symbols
  use arg lines
  out=.array~new
  currentClass=''
  currentMethod=.nil
  do i=1 to lines~items
    t=lines[i]~strip
    u=t~upper
    if u~left(8)='::CLASS ' then do
      if currentMethod<>.nil then do; currentMethod~endLine=i-1; currentMethod=.nil; end
      words=t~words
      if words>=2 then do
        currentClass=t~word(2)
        out~append(.SourceSymbol~new('class',currentClass,i,0))
      end
    end
    else if u~left(9)='::METHOD ' then do
      if currentMethod<>.nil then currentMethod~endLine=i-1
      name=t~word(2)
      currentMethod=.SourceSymbol~new('method',name,i,0,currentClass)
      out~append(currentMethod)
    end
    else if u~left(11)='::ATTRIBUTE ' then do
      name=t~word(2); out~append(.SourceSymbol~new('attribute',name,i,i,currentClass))
    end
    else if u~left(10)='::ROUTINE ' then do
      if currentMethod<>.nil then currentMethod~endLine=i-1
      name=t~word(2); currentMethod=.SourceSymbol~new('routine',name,i,0,'')
      out~append(currentMethod)
    end
    else if u~left(11)='::REQUIRES ' then out~append(.SourceSymbol~new('requires',t~substr(12)~strip,i,i))
  end
  if currentMethod<>.nil then currentMethod~endLine=lines~items
  /* A class scope is the remainder of the package or until the next class. */
  do j=1 to out~items
    if out[j]~kind='class' & out[j]~endLine=0 then do
      stop=lines~items
      do k=j+1 to out~items
        if out[k]~kind='class' then do; stop=out[k]~startLine-1; leave; end
      end
      out[j]~endLine=stop
    end
  end
  return out

::class PythonSourceScanner subclass TextSourceScanner public
::method symbols
  use arg lines
  out=.array~new
  do i=1 to lines~items
    t=lines[i]~strip
    if t~left(6)='class ' then do
      p=t~pos('('); c=t~pos(':')
      if p=0 | (c>0 & c<p) then p=c
      if p=0 then p=t~length+1
      name=t~substr(7,p-7)~strip
      out~append(.SourceSymbol~new('class',name,i,.SourceEditorUtil~pythonBlockEnd(lines,i)))
    end
    else if t~left(4)='def ' then do
      p=t~pos('(')
      if p>4 then do
        name=t~substr(5,p-5)~strip
        out~append(.SourceSymbol~new('function',name,i,.SourceEditorUtil~pythonBlockEnd(lines,i)))
      end
    end
  end
  return out

::class CppSourceScanner subclass TextSourceScanner public
::method init
  expose language
  use arg language='cpp'
  self~language=language
::attribute language

::method symbols
  expose language
  use arg lines
  projected=.SourceEditorUtil~codeProjection(lines,language)
  out=.array~new
  do i=1 to projected~items
    t=projected[i]~strip
    if t='' then iterate
    if t~left(1)='#' then do
      directive=t~word(1)~lower
      if directive='#define' & t~words>=2 then out~append(.SourceSymbol~new('macro',t~word(2),i,i))
      else if directive='#include' & t~words>=2 then out~append(.SourceSymbol~new('include',t~subword(2),i,i))
      iterate
    end
    first=t~word(1)~lower
    if first='class' | first='struct' | first='enum' | first='namespace' then do
      if t~words>=2 then do
        name=t~word(2)
        do while name~right(1)='{' | name~right(1)=':' | name~right(1)=';'; name=name~left(name~length-1); end
        fin=.SourceEditorUtil~braceBlockEnd(projected,i)
        kind=first
        out~append(.SourceSymbol~new(kind,name,i,fin))
      end
      iterate
    end
    open=t~pos('(')
    if open>1 then do
      before=t~left(open-1)~strip
      candidate=before~word(before~words)
      low=candidate~lower
      if low<>'' & low<> 'if' & low<>'for' & low<>'while' & low<>'switch' & low<>'catch' & low<>'sizeof' then do
        /* Trim pointer/reference markers; preserve namespace and destructor spelling. */
        do while candidate~left(1)='*' | candidate~left(1)='&'; candidate=candidate~substr(2); end
        if candidate<>'' then do
          fin=.SourceEditorUtil~braceBlockEnd(projected,i)
          if fin>0 then out~append(.SourceSymbol~new('function',candidate,i,fin))
        end
      end
    end
  end
  return out

::class JsonSourceScanner subclass TextSourceScanner public
::method symbols
  use arg lines
  out=.array~new
  /* Lightweight key projection. Exact object semantics/validation come from json.cls. */
  do i=1 to lines~items
    t=lines[i]~strip
    if t~left(1)='"' then do
      p=t~pos('"',2)
      if p>2 then do
        rest=t~substr(p+1)~strip
        if rest~left(1)=':' then out~append(.SourceSymbol~new('json-key',t~substr(2,p-2),i,i))
      end
    end
  end
  return out

::class JsonSourceValidator public
::method validate
  use arg text
  signal on syntax name badJson
  v=.json~fromJSON(text)
  return .true
badJson:
  raise syntax 88.900 array('invalid JSON source')

::class RexxClassEditor public
::method init
  expose document searchPaths
  use arg path, searchPaths=.nil
  if searchPaths=.nil then searchPaths=.array~new
  document=.SourceDocument~new(path,'oorexx')
  self~searchPaths=searchPaths
::attribute document
::attribute searchPaths

::method addRequires
  expose document searchPaths
  use arg package
  resolved=.SourceEditorUtil~resolvePackage(package,searchPaths)
  /* Do not emit ::requires until the target is demonstrably resolvable. */
  do s over document~symbols
    if s~kind='requires' then do
      existing=s~name~strip('B','"')~strip('B',"'")
      if existing~caselessEquals(package) then return resolved
    end
  end
  document~insertBefore(1,'::requires "'||package||'"')
  return resolved

::method addMethod
  expose document
  use arg className, methodName, body='return'
  c=document~findSymbol(className,'class')
  methodText='::method '||methodName||d2c(10)||body
  /* Append inside the class region, after existing declarations. */
  document~insertBefore(c~endLine+1,methodText||d2c(10))
  return document

::class CppClassEditor public
::method init
  expose document
  use arg path
  document=.SourceDocument~new(path,'cpp')
::attribute document

::method addInclude
  expose document
  use arg includeText
  needle='#include '||includeText
  do i=1 to document~lineCount
    if document~line(i)~strip~caselessEquals(needle) then return document
  end
  pos=1
  do i=1 to document~lineCount
    t=document~line(i)~strip
    if t~left(8)='#include' then pos=i+1
  end
  document~insertBefore(pos,needle)
  return document

::method addMember
  expose document
  use arg className, declaration
  c=document~findSymbol(className,'class')
  document~insertBefore(c~endLine,'    '||declaration)
  return document

::class SourceEditorUtil public
::method baseName class
  use arg path
  p1=path~lastPos('/'); p2=path~lastPos('\\'); p=p1
  if p2>p then p=p2
  if p=0 then return path
  return path~substr(p+1)

::method readAll class
  use arg path
  state=stream(path,'c','open read')
  if state~left(6)<>'READY:' then raise syntax 88.900 array('cannot open source for read:' path state)
  n=chars(path)
  if n>0 then data=charin(path,1,n); else data=''
  call stream path,'c','close'
  return data

::method writeAll class
  use arg path,data
  state=stream(path,'c','open write replace')
  if state~left(6)<>'READY:' then raise syntax 88.900 array('cannot open source for write:' path state)
  if data<>'' then call charout path,data
  call stream path,'c','close'
  return path

::method textLines class
  use arg text
  n=text~changeStr(d2c(13)||d2c(10),d2c(10))~changeStr(d2c(13),d2c(10))
  a=n~makeArray(d2c(10))
  if a=.nil then a=.array~new
  return a

::method splice class
  use arg source,first,last,replacement
  out=.array~new
  do i=1 to first-1; out~append(source[i]); end
  do x over replacement; out~append(x); end
  do i=last+1 to source~items; out~append(source[i]); end
  return out

::method codeProjection class
  use arg lines,language
  out=.array~new; depth=0
  do line over lines
    i=1; result=''; quote=''
    do while i<=line~length
      ch=line~substr(i,1)
      if i<line~length then pair=line~substr(i,2); else pair=ch
      if depth>0 then do
        if pair='*/' then do; depth=depth-1; result=result||'  '; i=i+2; iterate; end
        result=result||' '; i=i+1; iterate
      end
      if quote<>'' then do
        result=result||ch
        if ch='\\' & i<line~length then do; result=result||line~substr(i+1,1); i=i+2; iterate; end
        if ch=quote then quote=''
        i=i+1; iterate
      end
      if ch='"' | ch="'" then do; quote=ch; result=result||ch; i=i+1; iterate; end
      if pair='/*' then do; depth=depth+1; result=result||'  '; i=i+2; iterate; end
      if pair='//' then do; result=result||copies(' ',line~length-i+1); leave; end
      result=result||ch; i=i+1
    end
    out~append(result)
  end
  return out

::method braceBlockEnd class
  use arg lines,start
  depth=0; seen=.false
  do i=start to lines~items
    line=lines[i]
    do j=1 to line~length
      ch=line~substr(j,1)
      if ch='{' then do; depth=depth+1; seen=.true; end
      else if ch='}' & seen then do
        depth=depth-1
        if depth=0 then return i
      end
    end
  end
  return 0

::method pythonBlockEnd class
  use arg lines,start
  base=.SourceEditorUtil~indentOf(lines[start])
  stop=lines~items
  do i=start+1 to lines~items
    t=lines[i]
    if t~strip='' then iterate
    if .SourceEditorUtil~indentOf(t)<=base then return i-1
  end
  return stop

::method indentOf class
  use arg line
  n=0
  do i=1 to line~length
    ch=line~substr(i,1)
    if ch=' ' then n=n+1
    else if ch=d2c(9) then n=n+4
    else leave
  end
  return n

::method resolvePackage class
  use arg package,paths
  /* explicit absolute/relative path first */
  if stream(package,'c','query exists')<>'' then return stream(package,'c','query exists')
  do root over paths
    sep='/'
    candidate=root
    if candidate~right(1)<>'/' & candidate~right(1)<>'\\' then candidate=candidate||sep
    candidate=candidate||package
    exists=stream(candidate,'c','query exists')
    if exists<>'' then return exists
  end
  raise syntax 88.900 array('required package not found:' package)

::requires "rxregexp.cls"
::requires "json.cls"
