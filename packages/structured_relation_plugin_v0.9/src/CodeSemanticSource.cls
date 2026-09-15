/*
 * CodeSemanticSource v0.6
 *
 * Information-preserving, deliberately bounded native ooRexx semantic model
 * for C/C++ source revisions.  This is not a complete C++ compiler.  Its job
 * is to retain revision-bound symbols, syntax operations, guards, control-flow
 * and simple value-origin facts so HardWorld rules can reason about changes
 * without flattening source into scanner messages.
 */

::class CodeSemanticDocument public
::attribute fileRevision get
::attribute symbols get
::attribute history get
::attribute findings get

::method init
  expose fileRevision symbols history findings
  use arg fileRevisionArg
  fileRevision = fileRevisionArg
  symbols = .array~new
  history = .array~new
  findings = .array~new
  history~append(.RichProcessingEvent~new("ANALYZE", "OPEN_CODE_REVISION", fileRevision~path, self))

::method addSymbol
  expose symbols history
  use arg symbol
  symbols~append(symbol)
  history~append(.RichProcessingEvent~new("ANALYZE", "ADD_SYMBOL", symbol~qualifiedName, symbol))
  return symbol

::method symbol
  expose symbols
  use arg wanted
  do s over symbols
    if s~qualifiedName~caselessEquals(wanted~string) then return s
  end
  return .nil

::method document
  expose fileRevision
  return fileRevision~repository

::method path
  expose fileRevision
  return fileRevision~path || "/SEMANTIC"

::method provenance
  expose fileRevision symbols history findings
  p = .table~new
  p["kind"] = "CODE_SEMANTIC_DOCUMENT"
  p["document"] = fileRevision~repository
  p["path"] = self~path
  p["fileRevision"] = fileRevision
  p["symbols"] = symbols
  p["history"] = history
  p["findings"] = findings
  return p


::class CodeSymbolRevision public
::attribute semanticDocument get
::attribute kind get
::attribute qualifiedName get
::attribute signature get
::attribute sourceSpan get
::attribute bodyNodes get
::attribute parameters get
::attribute localExtents get
::attribute cfg get
::attribute flowFacts get

::method init
  expose semanticDocument kind qualifiedName signature sourceSpan bodyNodes parameters localExtents cfg flowFacts
  use arg documentArg, kindArg, nameArg, signatureArg, sourceSpanArg
  semanticDocument = documentArg
  kind = kindArg~string~translate
  qualifiedName = nameArg~string
  signature = signatureArg~string
  sourceSpan = sourceSpanArg
  bodyNodes = .array~new
  parameters = .array~new
  localExtents = .table~new
  cfg = .CodeControlFlowGraph~new(self)
  flowFacts = .array~new

::method addNode
  expose bodyNodes cfg
  use arg node
  if bodyNodes~items > 0 then cfg~addEdge(bodyNodes[bodyNodes~items], node, "NEXT")
  bodyNodes~append(node)
  cfg~addNode(node)
  return node

::method addParameter
  expose parameters flowFacts
  use arg name, declaration = ""
  if name~string = "" then return .nil
  p = .CodeValueOrigin~new(name, "PARAMETER", self, declaration)
  parameters~append(p)
  flowFacts~append(p)
  return p

::method setLocalExtent
  expose localExtents flowFacts
  use arg name, extent, source
  localExtents[name~string] = extent
  f = .CodeValueOrigin~new(name, "LOCAL_ARRAY", source, extent)
  flowFacts~append(f)
  return f

::method localExtent
  expose localExtents
  use arg name
  v = localExtents[name~string]
  if v == .nil then return .nil
  return v

::method operations
  expose bodyNodes
  use arg operationKind = ""
  out = .array~new
  do n over bodyNodes
    if n~nodeKind = "CALL" then do
      if operationKind = "" | n~operationKind~caselessEquals(operationKind~string) then out~append(n)
    end
  end
  return out

::method guards
  expose bodyNodes
  out = .array~new
  do n over bodyNodes
    if n~nodeKind = "GUARD" then out~append(n)
  end
  return out

::method returns
  expose bodyNodes
  out = .array~new
  do n over bodyNodes
    if n~nodeKind = "RETURN" then out~append(n)
  end
  return out

::method path
  expose sourceSpan qualifiedName
  return sourceSpan~fileRevision~path || "/SYMBOL/" || qualifiedName

::method document
  expose semanticDocument
  return semanticDocument~document

::method provenance
  expose semanticDocument kind qualifiedName signature sourceSpan bodyNodes parameters localExtents cfg flowFacts
  p = .table~new
  p["kind"] = "CODE_SYMBOL_REVISION"
  p["document"] = self~document
  p["path"] = self~path
  p["fileRevision"] = sourceSpan~fileRevision
  p["symbolKind"] = kind
  p["qualifiedName"] = qualifiedName
  p["signature"] = signature
  p["sourceSpan"] = sourceSpan
  p["bodyNodes"] = bodyNodes
  p["parameters"] = parameters
  p["localExtents"] = localExtents
  p["cfg"] = cfg
  p["flowFacts"] = flowFacts
  return p

::method string
  expose qualifiedName sourceSpan
  return qualifiedName || " @ " || sourceSpan~path


::class CodeSyntaxNode public
::attribute symbol get
::attribute nodeKind get
::attribute lexicalValue get
::attribute sourceSpan get
::attribute properties get
::attribute parentGuard
::attribute children get

::method init
  expose symbol nodeKind lexicalValue sourceSpan properties parentGuard children
  use arg symbolArg, kindArg, lexicalArg, sourceSpanArg, propertiesArg = .nil, guardArg = .nil
  symbol = symbolArg
  nodeKind = kindArg~string~translate
  lexicalValue = lexicalArg
  sourceSpan = sourceSpanArg
  if propertiesArg == .nil then properties = .table~new
  else properties = propertiesArg
  parentGuard = guardArg
  children = .array~new

::method property
  expose properties
  use arg key, defaultValue = .nil
  v = properties[key~string]
  if v == .nil then return defaultValue
  return v

::method setProperty
  expose properties
  use arg key, value
  properties[key~string] = value
  return self

::method addChild
  expose children
  use arg child
  children~append(child)
  return child

::method path
  expose sourceSpan nodeKind
  return sourceSpan~path || "/" || nodeKind

::method document
  expose symbol
  return symbol~document

::method provenance
  expose symbol nodeKind lexicalValue sourceSpan properties parentGuard children
  p = .table~new
  p["kind"] = "CODE_SYNTAX_NODE"
  p["document"] = self~document
  p["path"] = self~path
  p["symbol"] = symbol
  p["nodeKind"] = nodeKind
  p["lexicalValue"] = lexicalValue
  p["sourceSpan"] = sourceSpan
  p["properties"] = properties
  p["parentGuard"] = parentGuard
  p["children"] = children
  return p

::method string
  expose nodeKind lexicalValue
  return nodeKind || ": " || lexicalValue


::class CodeGuardNode subclass CodeSyntaxNode public
::attribute condition get
::attribute depth get

::method init
  expose condition depth
  use arg symbolArg, conditionArg, sourceSpanArg, depthArg = 0
  condition = conditionArg~string~strip
  depth = depthArg
  props = .table~new
  props["condition"] = condition
  self~init:super(symbolArg, "GUARD", condition, sourceSpanArg, props, .nil)

::method dominates
  expose depth
  use arg node
  g = node~parentGuard
  do while g \== .nil
    if g == self then return .true
    g = g~parentGuard
  end
  return .false

::method provenance
  expose condition depth
  p = self~provenance:super
  p["kind"] = "CODE_GUARD_NODE"
  p["condition"] = condition
  p["depth"] = depth
  return p


::class CodeCallNode subclass CodeSyntaxNode public
::attribute callee get
::attribute arguments get
::attribute operationKind get
::attribute destination
::attribute lengthExpression
::attribute destinationExtent
::attribute valueOrigins get

::method init
  expose callee arguments operationKind destination lengthExpression destinationExtent valueOrigins
  use arg symbolArg, calleeArg, argumentsArg, operationKindArg, sourceSpanArg, guardArg = .nil
  callee = calleeArg~string
  arguments = argumentsArg
  operationKind = operationKindArg~string~translate
  destination = ""
  lengthExpression = ""
  destinationExtent = .nil
  valueOrigins = .array~new
  props = .table~new
  props["callee"] = callee
  props["operationKind"] = operationKind
  self~init:super(symbolArg, "CALL", sourceSpanArg~lexicalValue, sourceSpanArg, props, guardArg)

::method addValueOrigin
  expose valueOrigins
  use arg origin
  valueOrigins~append(origin)
  return origin

::method provenance
  expose callee arguments operationKind destination lengthExpression destinationExtent valueOrigins
  p = self~provenance:super
  p["kind"] = "CODE_CALL_NODE"
  p["callee"] = callee
  p["arguments"] = arguments
  p["operationKind"] = operationKind
  p["destination"] = destination
  p["lengthExpression"] = lengthExpression
  p["destinationExtent"] = destinationExtent
  p["valueOrigins"] = valueOrigins
  return p


::class CodeReturnNode subclass CodeSyntaxNode public
::attribute expression get
::attribute valueOrigins get

::method init
  expose expression valueOrigins
  use arg symbolArg, expressionArg, sourceSpanArg, guardArg = .nil
  expression = expressionArg~string~strip
  valueOrigins = .array~new
  props = .table~new
  props["expression"] = expression
  self~init:super(symbolArg, "RETURN", sourceSpanArg~lexicalValue, sourceSpanArg, props, guardArg)

::method addValueOrigin
  expose valueOrigins
  use arg origin
  valueOrigins~append(origin)
  return origin

::method provenance
  expose expression valueOrigins
  p = self~provenance:super
  p["kind"] = "CODE_RETURN_NODE"
  p["expression"] = expression
  p["valueOrigins"] = valueOrigins
  return p


::class CodeValueOrigin public
::attribute name get
::attribute originKind get
::attribute source get
::attribute detail get

::method init
  expose name originKind source detail
  use arg nameArg, kindArg, sourceArg, detailArg = ""
  name = nameArg~string
  originKind = kindArg~string~translate
  source = sourceArg
  detail = detailArg

::method provenance
  expose name originKind source detail
  p = .table~new
  p["kind"] = "CODE_VALUE_ORIGIN"
  p["name"] = name
  p["originKind"] = originKind
  p["source"] = source
  p["detail"] = detail
  return p

::method string
  expose name originKind
  return originKind || " " || name


::class CodeControlFlowEdge public
::attribute fromNode get
::attribute toNode get
::attribute edgeKind get
::attribute condition get

::method init
  expose fromNode toNode edgeKind condition
  use arg fromArg, toArg, kindArg = "NEXT", conditionArg = ""
  fromNode = fromArg
  toNode = toArg
  edgeKind = kindArg~string~translate
  condition = conditionArg~string

::method provenance
  expose fromNode toNode edgeKind condition
  p = .table~new
  p["kind"] = "CODE_CONTROL_FLOW_EDGE"
  p["from"] = fromNode
  p["to"] = toNode
  p["edgeKind"] = edgeKind
  p["condition"] = condition
  return p


::class CodeControlFlowGraph public
::attribute symbol get
::attribute nodes get
::attribute edges get

::method init
  expose symbol nodes edges
  use arg symbolArg
  symbol = symbolArg
  nodes = .array~new
  edges = .array~new

::method addNode
  expose nodes
  use arg node
  nodes~append(node)
  return node

::method addEdge
  expose edges
  use arg fromNode, toNode, edgeKind = "NEXT", condition = ""
  edge = .CodeControlFlowEdge~new(fromNode, toNode, edgeKind, condition)
  edges~append(edge)
  return edge

::method provenance
  expose symbol nodes edges
  p = .table~new
  p["kind"] = "CODE_CONTROL_FLOW_GRAPH"
  p["symbol"] = symbol
  p["nodes"] = nodes
  p["edges"] = edges
  return p


::class CodeSemanticChange public
::attribute beforeSymbol get
::attribute afterSymbol get
::attribute beforeOperation get
::attribute afterOperation get
::attribute changeEvidence get
::attribute observations get

::method init
  expose beforeSymbol afterSymbol beforeOperation afterOperation changeEvidence observations
  use arg beforeSymbolArg, afterSymbolArg, beforeOperationArg = .nil, afterOperationArg = .nil, changeEvidenceArg = .nil
  beforeSymbol = beforeSymbolArg
  afterSymbol = afterSymbolArg
  beforeOperation = beforeOperationArg
  afterOperation = afterOperationArg
  changeEvidence = changeEvidenceArg
  observations = .array~new

::method addObservation
  expose observations
  use arg observation
  observations~append(observation)
  return observation

::method guardPreserved
  expose beforeOperation afterOperation
  if beforeOperation == .nil | afterOperation == .nil then return .false
  bg = beforeOperation~parentGuard
  ag = afterOperation~parentGuard
  if bg == .nil | ag == .nil then return .false
  return bg~condition~space(0)~caselessEquals(ag~condition~space(0))

::method guardRemoved
  expose beforeOperation afterOperation
  if beforeOperation == .nil | afterOperation == .nil then return .false
  return beforeOperation~parentGuard \== .nil & afterOperation~parentGuard == .nil

::method provenance
  expose beforeSymbol afterSymbol beforeOperation afterOperation changeEvidence observations
  p = .table~new
  p["kind"] = "CODE_SEMANTIC_CHANGE"
  p["beforeSymbol"] = beforeSymbol
  p["afterSymbol"] = afterSymbol
  p["beforeOperation"] = beforeOperation
  p["afterOperation"] = afterOperation
  p["changeEvidence"] = changeEvidence
  p["observations"] = observations
  p["guardPreserved"] = self~guardPreserved
  p["guardRemoved"] = self~guardRemoved
  return p


::class CxxSemanticAnalyzer public

::method analyze class
  use arg fileRevision
  if fileRevision~binary then raise syntax 93.900 array("Cannot semantically analyze binary Git blob")
  doc = .CodeSemanticDocument~new(fileRevision)
  lines = fileRevision~content~makeArray
  i = 1
  do while i <= lines~items
    line = lines[i]
    isStart = self~looksLikeFunctionStart(line)
    if \isStart then do
      if self~looksLikeFunctionSignature(line) then do
        j = i + 1
        do while j <= lines~items & lines[j]~strip = ""
          j += 1
        end
        if j <= lines~items then do
          if lines[j]~strip~left(1) = "{" then isStart = .true
        end
      end
    end
    if isStart then do
      endLine = self~findFunctionEnd(lines, i)
      if endLine >= i then do
        symbol = self~parseFunction(doc, fileRevision, lines, i, endLine)
        if symbol \== .nil then doc~addSymbol(symbol)
        i = endLine + 1
        iterate
      end
    end
    i += 1
  end
  return doc

::method compareMemoryOperation class
  use arg beforeSymbol, afterSymbol, changeEvidence = .nil
  beforeOp = self~firstMemoryOperation(beforeSymbol)
  afterOp = self~firstMemoryOperation(afterSymbol)
  return .CodeSemanticChange~new(beforeSymbol, afterSymbol, beforeOp, afterOp, changeEvidence)

::method firstMemoryOperation class private
  use arg symbol
  if symbol == .nil then return .nil
  do op over symbol~operations
    if op~operationKind = "BYTE_COPY" | op~operationKind = "RANGE_COPY" | op~operationKind = "BYTE_MOVE" then return op
  end
  return .nil

::method parseFunction class private
  use arg doc, fileRevision, lines, startLine, endLine
  signatureText = ""
  do x = startLine to endLine
    signatureText ||= " " || lines[x]~strip
    if lines[x]~pos("{") > 0 then leave
  end
  name = self~functionName(signatureText)
  if name = "" then return .nil
  span = fileRevision~lineSpan(startLine, endLine)
  symbol = .CodeSymbolRevision~new(doc, "FUNCTION", name, signatureText~strip, span)
  self~parseParameters(symbol, signatureText)

  braceDepth = 0
  guardStack = .array~new
  do lineNo = startLine to endLine
    raw = lines[lineNo]
    stripped = raw~strip
    openCount = self~countChar(raw, "{")
    closeCount = self~countChar(raw, "}")

    if self~looksLikeGuard(stripped) then do
      cond = self~extractGuard(stripped)
      g = .CodeGuardNode~new(symbol, cond, fileRevision~lineSpan(lineNo), braceDepth)
      if guardStack~items > 0 then g~parentGuard = guardStack[guardStack~items]
      symbol~addNode(g)
      if stripped~pos("{") > 0 then guardStack~append(g)
      else do
        /* Single-line guard remains active for calls on the same source line only. */
      end
    end

    self~detectLocalExtent(symbol, stripped, fileRevision~lineSpan(lineNo))
    calls = self~callsOnLine(symbol, stripped, fileRevision~lineSpan(lineNo), guardStack)
    do callNode over calls
      symbol~addNode(callNode)
    end
    returnNode = self~returnOnLine(symbol, stripped, fileRevision~lineSpan(lineNo), guardStack)
    if returnNode \== .nil then symbol~addNode(returnNode)

    braceDepth += openCount
    braceDepth -= closeCount
    do while guardStack~items > 0
      top = guardStack[guardStack~items]
      if braceDepth <= top~depth then do
        guardStack~remove(guardStack~items)
      end
      else leave
    end
  end
  return symbol

::method parseParameters class private
  use arg symbol, signature
  lp = signature~pos("(")
  if lp = 0 then return
  rp = self~matchingParen(signature, lp)
  if rp = 0 then return
  argsText = signature~substr(lp + 1, rp - lp - 1)
  args = self~splitArguments(argsText)
  do declaration over args
    d = declaration~strip
    if d = "" | d = "void" then iterate
    name = self~lastIdentifier(d)
    if name \= "" then symbol~addParameter(name, d)
  end

::method detectLocalExtent class private
  use arg symbol, stripped, sourceSpan
  lb = stripped~pos("[")
  rb = stripped~pos("]", lb + 1)
  if lb = 0 | rb = 0 then return
  semi = stripped~pos(";")
  if semi = 0 then return
  before = stripped~left(lb - 1)~strip
  extent = stripped~substr(lb + 1, rb - lb - 1)~strip
  if \extent~datatype("W") then return
  name = self~lastIdentifier(before)
  if name = "" then return
  symbol~setLocalExtent(name, extent, sourceSpan)

::method callsOnLine class private
  use arg symbol, stripped, sourceSpan, guardStack
  out = .array~new
  candidates = .array~of("std::memcpy", "memcpy", "std::memmove", "memmove", "std::copy", "malloc", "calloc", "realloc", "free")
  do callee over candidates
    marker = callee || "("
    p = stripped~pos(marker)
    if p = 0 then iterate
    if (callee = "memcpy" | callee = "memmove") & p > 1 then do
      if stripped~substr(p - 1, 1) = ":" then iterate
    end
    lp = p + callee~length
    rp = self~matchingParen(stripped, lp)
    if rp = 0 then iterate
    argsText = stripped~substr(lp + 1, rp - lp - 1)
    args = self~splitArguments(argsText)
    opKind = self~operationKind(callee)
    guard = .nil
    if guardStack~items > 0 then guard = guardStack[guardStack~items]
    else if self~looksLikeGuard(stripped) then do
      cond = self~extractGuard(stripped)
      /* Reuse the guard node already added on this line where possible. */
      gs = symbol~guards
      if gs~items > 0 then guard = gs[gs~items]
    end
    node = .CodeCallNode~new(symbol, callee, args, opKind, sourceSpan, guard)
    if opKind = "ALLOCATE" then do
      left = stripped~left(p - 1)
      eq = left~lastPos("=")
      if eq > 0 then node~destination = self~lastIdentifier(left~left(eq - 1))
    end
    self~decorateMemoryCall(symbol, node)
    out~append(node)
  end
  return out

::method returnOnLine class private
  use arg symbol, stripped, sourceSpan, guardStack
  p = stripped~wordPos("return")
  if p = 0 then return .nil
  charPos = stripped~pos("return")
  rest = stripped~substr(charPos + 6)~strip
  semi = rest~lastPos(";")
  if semi > 0 then rest = rest~left(semi - 1)~strip
  guard = .nil
  if guardStack~items > 0 then guard = guardStack[guardStack~items]
  else if self~looksLikeGuard(stripped) then do
    gs = symbol~guards
    if gs~items > 0 then guard = gs[gs~items]
  end
  node = .CodeReturnNode~new(symbol, rest, sourceSpan, guard)
  do origin over symbol~flowFacts
    if origin~hasMethod("NAME") then do
      if self~containsIdentifier(rest, origin~name) then node~addValueOrigin(origin)
    end
  end
  return node

::method decorateMemoryCall class private
  use arg symbol, node
  args = node~arguments
  select
    when node~operationKind = "BYTE_COPY" | node~operationKind = "BYTE_MOVE" then do
      if args~items >= 1 then node~destination = args[1]~strip
      if args~items >= 3 then node~lengthExpression = args[3]~strip
    end
    when node~operationKind = "RANGE_COPY" then do
      if args~items >= 3 then node~destination = args[3]~strip
      if args~items >= 2 then node~lengthExpression = args[2]~strip
    end
    when node~operationKind = "RELEASE" then do
      if args~items >= 1 then node~destination = args[1]~strip
    end
    when node~operationKind = "ALLOCATE" then do
      if args~items >= 1 then node~lengthExpression = args[1]~strip
    end
    otherwise nop
  end
  if node~destination \= "" then node~destinationExtent = symbol~localExtent(node~destination)
  do origin over symbol~parameters
    do arg over args
      if self~containsIdentifier(arg, origin~name) then node~addValueOrigin(origin)
    end
  end

::method operationKind class private
  use arg callee
  c = callee~lower
  if c~pos("memcpy") > 0 then return "BYTE_COPY"
  if c~pos("memmove") > 0 then return "BYTE_MOVE"
  if c~pos("std::copy") > 0 then return "RANGE_COPY"
  if c = "malloc" | c = "calloc" | c = "realloc" then return "ALLOCATE"
  if c = "free" then return "RELEASE"
  return "CALL"

::method looksLikeFunctionSignature class private
  use arg line
  s = line~strip
  if s = "" then return .false
  if s~left(1) = "#" | s~left(2) = "//" then return .false
  if s~pos("(") = 0 | s~pos(")") = 0 then return .false
  if s~right(1) = ";" then return .false
  first = s~word(1)~lower
  if first = "if" | first = "for" | first = "while" | first = "switch" | first = "catch" then return .false
  return .true

::method looksLikeFunctionStart class private
  use arg line
  s = line~strip
  if s = "" then return .false
  if s~left(1) = "#" then return .false
  if s~left(2) = "//" then return .false
  if s~pos("(") = 0 | s~pos(")") = 0 | s~pos("{") = 0 then return .false
  first = s~word(1)~lower
  if first = "if" | first = "for" | first = "while" | first = "switch" | first = "catch" then return .false
  if s~pos("=") > 0 & s~pos("operator=") = 0 then do
    if s~pos("{") > s~pos("=") then return .false
  end
  return .true

::method findFunctionEnd class private
  use arg lines, startLine
  depth = 0
  started = .false
  do i = startLine to lines~items
    raw = lines[i]
    opens = self~countChar(raw, "{")
    closes = self~countChar(raw, "}")
    if opens > 0 then started = .true
    depth += opens
    depth -= closes
    if started & depth = 0 then return i
  end
  return 0

::method functionName class private
  use arg signature
  lp = signature~pos("(")
  if lp = 0 then return ""
  before = signature~left(lp - 1)~strip
  return self~lastIdentifier(before, .true)

::method lastIdentifier class private
  use arg text, allowQualified = .false
  s = text~strip
  if s = "" then return ""
  /* Walk backwards over identifier-ish characters. */
  endPos = s~length
  do while endPos > 0
    ch = s~substr(endPos, 1)
    if self~isIdentifierChar(ch) | (allowQualified & ch = ":") then leave
    endPos -= 1
  end
  if endPos = 0 then return ""
  start = endPos
  do while start > 1
    ch = s~substr(start - 1, 1)
    if self~isIdentifierChar(ch) | (allowQualified & ch = ":") then start -= 1
    else leave
  end
  return s~substr(start, endPos - start + 1)

::method isIdentifierChar class private
  use arg ch
  if ch~datatype("A") then return .true
  if ch~datatype("N") then return .true
  return ch = "_" | ch = "~"

::method looksLikeGuard class private
  use arg s
  t = s~strip
  return t~left(3) = "if " | t~left(3) = "if(" | t~left(4) = "if ("

::method extractGuard class private
  use arg s
  lp = s~pos("(")
  if lp = 0 then return ""
  rp = self~matchingParen(s, lp)
  if rp = 0 then return ""
  return s~substr(lp + 1, rp - lp - 1)~strip

::method matchingParen class private
  use arg text, openPos
  depth = 0
  quote = ""
  escape = .false
  do i = openPos to text~length
    ch = text~substr(i, 1)
    if escape then do
      escape = .false
      iterate
    end
    if ch = "\\" then do
      escape = .true
      iterate
    end
    if quote \= "" then do
      if ch = quote then quote = ""
      iterate
    end
    if ch = '"' | ch = "'" then do
      quote = ch
      iterate
    end
    if ch = "(" then depth += 1
    else if ch = ")" then do
      depth -= 1
      if depth = 0 then return i
    end
  end
  return 0

::method splitArguments class private
  use arg text
  out = .array~new
  current = .mutablebuffer~new
  paren = 0; bracket = 0; brace = 0; angle = 0
  quote = ""; escape = .false
  do i = 1 to text~length
    ch = text~substr(i, 1)
    if escape then do
      current~append(ch); escape = .false; iterate
    end
    if ch = "\\" then do
      current~append(ch); escape = .true; iterate
    end
    if quote \= "" then do
      current~append(ch)
      if ch = quote then quote = ""
      iterate
    end
    if ch = '"' | ch = "'" then do quote = ch; current~append(ch); iterate; end
    select
      when ch = "(" then paren += 1
      when ch = ")" then paren -= 1
      when ch = "[" then bracket += 1
      when ch = "]" then bracket -= 1
      when ch = "{" then brace += 1
      when ch = "}" then brace -= 1
      when ch = "<" then angle += 1
      when ch = ">" & angle > 0 then angle -= 1
      when ch = "," & paren = 0 & bracket = 0 & brace = 0 & angle = 0 then do
        out~append(current~string~strip)
        current = .mutablebuffer~new
        iterate
      end
      otherwise nop
    end
    current~append(ch)
  end
  if current~length > 0 | text~strip = "" then out~append(current~string~strip)
  return out

::method containsIdentifier class private
  use arg text, wanted
  p = text~pos(wanted)
  do while p > 0
    leftOk = p = 1
    if \leftOk then leftOk = \self~isIdentifierChar(text~substr(p - 1, 1))
    rightPos = p + wanted~length
    rightOk = rightPos > text~length
    if \rightOk then rightOk = \self~isIdentifierChar(text~substr(rightPos, 1))
    if leftOk & rightOk then return .true
    p = text~pos(wanted, p + 1)
  end
  return .false

::method countChar class private
  use arg text, wanted
  count = 0
  do i = 1 to text~length
    if text~substr(i, 1) = wanted then count += 1
  end
  return count

::requires "GitNativeSource.cls"
