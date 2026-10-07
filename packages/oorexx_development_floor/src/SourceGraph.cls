/* SourceGraph.cls
   Deterministic ooRexx source inventory used by the development floor.

   This is intentionally a source-structure tool, not a semantic language model.
   It records files, ::class, ::method, ::attribute and ::requires directives and
   can emit a machine-readable JSON graph plus a simple class hierarchy sketch.
*/

::class DFSourceMethod public
::method init
  expose name className file lineNumber options documentation
  use strict arg name, className, file, lineNumber, options="", documentation=""
  self~name = name
  self~className = className
  self~file = file
  self~lineNumber = lineNumber
  self~options = options
  self~documentation = documentation
::attribute name
::attribute className
::attribute file
::attribute lineNumber
::attribute options
::attribute documentation
::method toDirectory
  d = .Directory~new
  d["name"] = self~name
  d["class"] = self~className
  d["file"] = self~file
  d["line"] = self~lineNumber
  d["options"] = self~options
  d["documentation"] = self~documentation
  return d

::class DFSourceClass public
::method init
  expose name superclass file lineNumber options documentation methods attributes
  use strict arg name, superclass, file, lineNumber, options="", documentation=""
  self~name = name
  self~superclass = superclass
  self~file = file
  self~lineNumber = lineNumber
  self~options = options
  self~documentation = documentation
  methods = .Array~new
  attributes = .Array~new
::attribute name
::attribute superclass
::attribute file
::attribute lineNumber
::attribute options
::attribute documentation
::attribute methods get
::attribute attributes get
::method addMethod
  expose methods
  use strict arg method
  methods~append(method)
  return method
::method addAttribute
  expose attributes
  use strict arg name
  attributes~append(name)
  return name
::method methodNamed
  expose methods
  use strict arg name
  wanted = translate(name)
  do method over methods
    if translate(method~name) = wanted then return method
  end
  return .nil
::method toDirectory
  expose methods attributes
  d = .Directory~new
  d["name"] = self~name
  d["superclass"] = self~superclass
  d["file"] = self~file
  d["line"] = self~lineNumber
  d["options"] = self~options
  d["documentation"] = self~documentation
  ma = .Array~new
  do method over methods
    ma~append(method~toDirectory)
  end
  d["methods"] = ma
  d["attributes"] = attributes
  return d

::class DFSourceFile public
::method init
  expose path classes requires
  use strict arg path
  self~path = path
  classes = .Array~new
  requires = .Array~new
::attribute path
::attribute classes get
::attribute requires get
::method addClass
  expose classes
  use strict arg classRecord
  classes~append(classRecord)
  return classRecord
::method addRequire
  expose requires
  use strict arg requirement
  requires~append(requirement)
  return requirement
::method toDirectory
  expose classes requires
  d = .Directory~new
  d["path"] = self~path
  ca = .Array~new
  do classRecord over classes
    ca~append(classRecord~toDirectory)
  end
  d["classes"] = ca
  d["requires"] = requires
  return d

::class DFSourceGraph public
::method init
  expose files classes
  files = .Array~new
  classes = .Directory~new
::attribute files get
::method classNamed
  expose classes
  use strict arg name
  return classes~at(translate(name))
::method scanDirectory
  use strict arg directory
  paths = .Array~new
  call SysFileTree directory || "/*.cls", paths, "FO"
  do path over paths
    self~scanFile(path)
  end
  return self
::method scanFile
  expose files classes
  use strict arg path
  f = .stream~new(path)
  if f~open("READ") <> "READY:" then raise syntax 93.900 array("Cannot read source file", path)
  lines = f~arrayIn
  f~close
  fileRecord = .DFSourceFile~new(path)
  files~append(fileRecord)
  currentClass = .nil
  comment = ""
  inComment = .false
  do i = 1 to lines~items
    line = lines[i]
    stripped = line~strip
    if inComment then do
      comment = comment || self~cleanCommentLine(stripped) || "0a"x
      if stripped~pos("*/") > 0 then inComment = .false
      iterate
    end
    if stripped~left(2) = "/*" then do
      comment = self~cleanCommentLine(stripped) || "0a"x
      if stripped~pos("*/") = 0 then inComment = .true
      iterate
    end
    if stripped = "" then iterate
    upper = translate(stripped)
    if upper~left(7) = "::CLASS" then do
      name = word(stripped, 2)
      superclass = ""
      do w = 3 to words(stripped) - 1
        if translate(word(stripped,w)) = "SUBCLASS" then superclass = word(stripped,w+1)
      end
      options = self~tailAfterWords(stripped, 2)
      currentClass = .DFSourceClass~new(name, superclass, path, i, options, comment~strip)
      fileRecord~addClass(currentClass)
      classes[translate(name)] = currentClass
      comment = ""
      iterate
    end
    if upper~left(8) = "::METHOD" then do
      name = word(stripped, 2)
      if currentClass == .nil then className = ""
      else className = currentClass~name
      method = .DFSourceMethod~new(name, className, path, i, self~tailAfterWords(stripped,2), comment~strip)
      if currentClass <> .nil then currentClass~addMethod(method)
      comment = ""
      iterate
    end
    if upper~left(11) = "::ATTRIBUTE" then do
      if currentClass <> .nil then currentClass~addAttribute(word(stripped,2))
      comment = ""
      iterate
    end
    if upper~left(10) = "::REQUIRES" then do
      req = stripped~substr(11)~strip
      if req~left(1) = '"' then do
        if req~right(1) = '"' then req = req~substr(2, req~length-2)
      end
      else if req~left(1) = "'" then do
        if req~right(1) = "'" then req = req~substr(2, req~length-2)
      end
      fileRecord~addRequire(req)
      comment = ""
      iterate
    end
    comment = ""
  end
  return fileRecord
::method writeJson
  expose files
  use strict arg path
  root = .Directory~new
  root["schema"] = "development.floor.source-graph/0.1"
  fa = .Array~new
  do fileRecord over files
    fa~append(fileRecord~toDirectory)
  end
  root["files"] = fa
  text = .json~toJson(root)
  call lineout path, text
  call lineout path
  return path
::method writeHierarchy
  expose classes
  use strict arg path
  call lineout path, "ooRexx class hierarchy sketch"
  call lineout path, "============================"
  names = classes~allIndexes
  do name over names
    c = classes[name]
    if c~superclass = "" then parent = "Object"
    else parent = c~superclass
    call lineout path, parent || " -> " || c~name
  end
  call lineout path
  return path
::method cleanCommentLine private
  use strict arg line
  t = line
  if t~left(2) = "/*" then t = t~substr(3)
  if t~right(2) = "*/" then t = t~left(t~length - 2)
  if t~left(1) = "*" then t = t~substr(2)
  return t~strip
::method tailAfterWords private
  use strict arg line, count
  rest = line~strip
  do i = 1 to count
    p = rest~pos(" ")
    if p = 0 then return ""
    rest = rest~substr(p+1)~strip
  end
  return rest

::requires "json.cls"
