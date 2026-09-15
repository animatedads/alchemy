/*
 * CodeValueFlow v0.7
 *
 * Bounded, revision-preserving value/alias/ownership flow enrichment for the
 * native C/C++ semantic model.  This deliberately does not turn source into a
 * compiler IR or claim whole-program proof.  It records source-bound edges so
 * HardWorld rules can distinguish a guard on the value that reaches a write
 * from a merely nearby guard on some other value.
 */

::class CodeValueFlowEdge public
::attribute fromName get
::attribute toName get
::attribute flowKind get
::attribute expression get
::attribute sourceSpan get

::method init
  expose fromName toName flowKind expression sourceSpan
  use arg fromArg, toArg, kindArg, expressionArg, spanArg
  fromName = fromArg~string
  toName = toArg~string
  flowKind = kindArg~string~translate
  expression = expressionArg~string
  sourceSpan = spanArg

::method provenance
  expose fromName toName flowKind expression sourceSpan
  p = .table~new
  p["kind"] = "CODE_VALUE_FLOW_EDGE"
  p["from"] = fromName
  p["to"] = toName
  p["flowKind"] = flowKind
  p["expression"] = expression
  p["sourceSpan"] = sourceSpan
  p["fileRevision"] = sourceSpan~fileRevision
  return p

::method string
  expose fromName toName flowKind
  return fromName || " -[" || flowKind || "]-> " || toName


::class CodeGuardConstraint public
::attribute guard get
::attribute subject get
::attribute operator get
::attribute boundExpression get
::attribute maximumValue get
::attribute sourceSpan get

::method init
  expose guard subject operator boundExpression maximumValue sourceSpan
  use arg guardArg, subjectArg, operatorArg, boundArg, maximumArg = .nil
  guard = guardArg
  subject = subjectArg~string
  operator = operatorArg~string
  boundExpression = boundArg~string
  maximumValue = maximumArg
  sourceSpan = guard~sourceSpan

::method provenance
  expose guard subject operator boundExpression maximumValue sourceSpan
  p = .table~new
  p["kind"] = "CODE_GUARD_CONSTRAINT"
  p["guard"] = guard
  p["subject"] = subject
  p["operator"] = operator
  p["boundExpression"] = boundExpression
  p["maximumValue"] = maximumValue
  p["sourceSpan"] = sourceSpan
  return p

::method string
  expose subject operator boundExpression
  return subject || " " || operator || " " || boundExpression


::class CodeCallFlowFact public
::attribute callee get
::attribute arguments get
::attribute sourceSpan get

::method init
  expose callee arguments sourceSpan
  use arg calleeArg, argumentsArg, spanArg
  callee = calleeArg~string
  arguments = argumentsArg
  sourceSpan = spanArg

::method provenance
  expose callee arguments sourceSpan
  p = .table~new
  p["kind"] = "CODE_CALL_FLOW_FACT"
  p["callee"] = callee
  p["arguments"] = arguments
  p["sourceSpan"] = sourceSpan
  p["fileRevision"] = sourceSpan~fileRevision
  return p

::method string
  expose callee
  return "CALL_FLOW " || callee


::class CodeValueFlowGraph public
::attribute symbol get
::attribute edges get
::attribute constraints get
::attribute calls get
::attribute history get

::method init
  expose symbol edges constraints calls history
  use arg symbolArg
  symbol = symbolArg
  edges = .array~new
  constraints = .array~new
  calls = .array~new
  history = .array~new
  history~append(.RichProcessingEvent~new("ANALYZE", "OPEN_VALUE_FLOW", symbol~qualifiedName, symbol))

::method addEdge
  expose edges history
  use arg edge
  edges~append(edge)
  history~append(.RichProcessingEvent~new("ANALYZE", "ADD_VALUE_FLOW", edge~string, edge))
  return edge

::method addConstraint
  expose constraints history
  use arg constraint
  constraints~append(constraint)
  history~append(.RichProcessingEvent~new("ANALYZE", "ADD_GUARD_CONSTRAINT", constraint~string, constraint))
  return constraint

::method addCall
  expose calls
  use arg callFact
  calls~append(callFact)
  return callFact

/* Exact equivalence traverses only assignment edges whose RHS was exactly one
 * identifier.  A derived expression such as n = len + 1 deliberately does not
 * make n equivalent to len. */
::method exactEquivalent
  expose edges
  use arg leftArg, rightArg
  left = leftArg~string~strip
  right = rightArg~string~strip
  if left = "" then return .false
  if right = "" then return .false
  if left~caselessEquals(right) then return .true
  visited = .table~new
  queue = .array~new
  queue~append(left)
  q = 1
  do while q <= queue~items
    current = queue[q]
    q += 1
    key = current~translate
    if visited[key] \== .nil then iterate
    visited[key] = .true
    do edge over edges
      if edge~flowKind \= "EXACT_ALIAS" then iterate
      next = ""
      if edge~fromName~caselessEquals(current) then next = edge~toName
      else if edge~toName~caselessEquals(current) then next = edge~fromName
      if next = "" then iterate
      if next~caselessEquals(right) then return .true
      if visited[next~translate] == .nil then queue~append(next)
    end
  end
  return .false

/* Directed lineage includes derived expressions. */
::method derivesFrom
  expose edges
  use arg valueArg, originArg
  value = valueArg~string~strip
  origin = originArg~string~strip
  if value = "" then return .false
  if origin = "" then return .false
  if value~caselessEquals(origin) then return .true
  visited = .table~new
  queue = .array~new
  queue~append(value)
  q = 1
  do while q <= queue~items
    current = queue[q]
    q += 1
    key = current~translate
    if visited[key] \== .nil then iterate
    visited[key] = .true
    do edge over edges
      if \edge~toName~caselessEquals(current) then iterate
      previous = edge~fromName
      if previous~caselessEquals(origin) then return .true
      if visited[previous~translate] == .nil then queue~append(previous)
    end
  end
  return .false

::method lineageEdges
  expose edges
  use arg valueArg
  value = valueArg~string~strip
  out = .array~new
  visited = .table~new
  queue = .array~new
  queue~append(value)
  q = 1
  do while q <= queue~items
    current = queue[q]
    q += 1
    key = current~translate
    if visited[key] \== .nil then iterate
    visited[key] = .true
    do edge over edges
      if edge~toName~caselessEquals(current) then do
        out~append(edge)
        if visited[edge~fromName~translate] == .nil then queue~append(edge~fromName)
      end
    end
  end
  return out

::method constraintForGuard
  expose constraints
  use arg guardArg
  do c over constraints
    if c~guard == guardArg then return c
  end
  return .nil

::method memoryLengthSubject
  use arg operation
  if operation == .nil then return ""
  kind = operation~operationKind
  if kind = "BYTE_COPY" | kind = "BYTE_MOVE" then do
    expr = operation~lengthExpression~strip
    if self~isIdentifier(expr) then return expr
    return ""
  end
  if kind = "RANGE_COPY" then do
    args = operation~arguments
    if args~items < 2 then return ""
    first = args[1]~strip
    last = args[2]~strip
    return self~rangeLengthIdentifier(first, last)
  end
  return ""

::method protectingConstraint
  expose constraints
  use arg operation
  if operation == .nil then return .nil
  subject = self~memoryLengthSubject(operation)
  if subject = "" then return .nil
  do c over constraints
    guard = c~guard
    if \guard~dominates(operation) then iterate
    if \self~exactEquivalent(c~subject, subject) then iterate
    extent = operation~destinationExtent
    if extent == .nil then return c
    maximum = c~maximumValue
    if maximum == .nil then iterate
    if \extent~string~datatype("N") then iterate
    if maximum <= extent then return c
  end
  return .nil

::method hasDominatingConstraint
  expose constraints
  use arg operation
  if operation == .nil then return .false
  do c over constraints
    if c~guard~dominates(operation) then return .true
  end
  return .false

::method aliasesOf
  expose edges
  use arg nameArg
  name = nameArg~string
  out = .array~new
  candidates = .table~new
  candidates[name~translate] = name
  changed = .true
  do while changed
    changed = .false
    do edge over edges
      if edge~flowKind \= "EXACT_ALIAS" then iterate
      fk = edge~fromName~translate
      tk = edge~toName~translate
      if candidates[fk] \== .nil then do
        if candidates[tk] == .nil then do
          candidates[tk] = edge~toName
          changed = .true
        end
      end
      if candidates[tk] \== .nil then do
        if candidates[fk] == .nil then do
          candidates[fk] = edge~fromName
          changed = .true
        end
      end
    end
  end
  do k over candidates
    out~append(candidates[k])
  end
  return out

::method callReceivesAlias
  use arg callFact, nameArg
  do arg over callFact~arguments
    id = self~singleIdentifier(arg)
    if id = "" then iterate
    if self~exactEquivalent(id, nameArg) then return .true
  end
  return .false

::method provenance
  expose symbol edges constraints calls history
  p = .table~new
  p["kind"] = "CODE_VALUE_FLOW_GRAPH"
  p["symbol"] = symbol
  p["fileRevision"] = symbol~sourceSpan~fileRevision
  p["edges"] = edges
  p["constraints"] = constraints
  p["calls"] = calls
  p["history"] = history
  return p

::method isIdentifier private
  use arg text
  s = text~string~strip
  if s = "" then return .false
  first = s~left(1)
  if \self~isIdentifierStart(first) then return .false
  do i = 2 to s~length
    if \self~isIdentifierChar(s~substr(i, 1)) then return .false
  end
  return .true

::method singleIdentifier private
  use arg text
  s = text~string~strip
  if self~isIdentifier(s) then return s
  return ""

::method rangeLengthIdentifier private
  use arg firstArg, lastArg
  first = firstArg~space(0)
  last = lastArg~space(0)
  marker = first || "+"
  if last~left(marker~length) = marker then do
    rest = last~substr(marker~length + 1)
    if self~isIdentifier(rest) then return rest
  end
  marker = "+" || first
  if last~right(marker~length) = marker then do
    rest = last~left(last~length - marker~length)
    if self~isIdentifier(rest) then return rest
  end
  return ""

::method isIdentifierStart private
  use arg c
  if c = "_" then return .true
  return c~datatype("A")

::method isIdentifierChar private
  use arg c
  if c = "_" then return .true
  return c~datatype("A") | c~datatype("N")


::class CxxValueFlowAnalyzer public

::method analyze class
  use arg symbol
  if symbol == .nil then raise syntax 93.900 array("Cannot value-flow analyze NIL symbol")
  graph = .CodeValueFlowGraph~new(symbol)
  fileRevision = symbol~sourceSpan~fileRevision
  lines = fileRevision~content~makeArray
  startLine = symbol~sourceSpan~startLine
  endLine = symbol~sourceSpan~endLine

  do lineNo = startLine to endLine
    stripped = lines[lineNo]~strip
    span = fileRevision~lineSpan(lineNo)
    self~assignmentOnLine(graph, stripped, span)
    self~genericCallOnLine(graph, stripped, span)
  end

  do guard over symbol~guards
    constraint = self~constraintFromGuard(symbol, guard)
    if constraint \== .nil then graph~addConstraint(constraint)
  end
  return graph

::method assignmentOnLine class private
  use arg graph, stripped, span
  eq = self~assignmentEquals(stripped)
  if eq = 0 then return
  left = stripped~left(eq - 1)~strip
  right = stripped~substr(eq + 1)~strip
  semi = right~lastPos(";")
  if semi > 0 then right = right~left(semi - 1)~strip
  if right = "" then return
  target = self~lastIdentifier(left)
  if target = "" then return

  /* Calls create values too, but they are not aliases to their arguments. */
  if right~pos("(") > 0 then return

  if self~isIdentifier(right) then do
    graph~addEdge(.CodeValueFlowEdge~new(right, target, "EXACT_ALIAS", right, span))
    return
  end

  ids = self~identifierTokens(right)
  do id over ids
    if id~caselessEquals(target) then iterate
    graph~addEdge(.CodeValueFlowEdge~new(id, target, "DERIVED_EXPRESSION", right, span))
  end

::method genericCallOnLine class private
  use arg graph, stripped, span
  if stripped = "" then return
  firstWord = stripped~word(1)~lower
  if firstWord = "if" | firstWord = "for" | firstWord = "while" | firstWord = "switch" | firstWord = "return" then do
    /* A one-line guard can still contain a call.  The semantic parser already
     * owns that memory call; this generic layer is only for escape evidence. */
    return
  end
  lp = stripped~pos("(")
  if lp = 0 then return
  before = stripped~left(lp - 1)~strip
  callee = self~lastIdentifier(before)
  if callee = "" then return
  low = callee~lower
  if low = "memcpy" | low = "memmove" | low = "copy" | low = "malloc" | low = "calloc" | low = "realloc" | low = "free" then return
  if low = "sizeof" then return
  rp = self~matchingParen(stripped, lp)
  if rp = 0 then return
  args = self~splitArguments(stripped~substr(lp + 1, rp - lp - 1))
  graph~addCall(.CodeCallFlowFact~new(callee, args, span))

::method constraintFromGuard class private
  use arg symbol, guard
  cond = guard~condition~strip
  ops = .array~of("<=", ">=", "<", ">")
  do op over ops
    p = cond~pos(op)
    if p = 0 then iterate
    left = cond~left(p - 1)~strip
    right = cond~substr(p + op~length)~strip
    if self~isIdentifier(left) then do
      maximum = self~maximumFor(op, right, symbol)
      return .CodeGuardConstraint~new(guard, left, op, right, maximum)
    end
    if self~isIdentifier(right) then do
      reversed = self~reverseOperator(op)
      maximum = self~maximumFor(reversed, left, symbol)
      return .CodeGuardConstraint~new(guard, right, reversed, left, maximum)
    end
  end
  return .nil

::method maximumFor class private
  use arg operator, boundExpr, symbol
  bound = self~numericBound(boundExpr, symbol)
  if bound == .nil then return .nil
  if operator = "<=" then return bound
  if operator = "<" then return bound - 1
  return .nil

::method numericBound class private
  use arg exprArg, symbol
  expr = exprArg~string~strip
  if expr~datatype("W") then return expr
  if expr~left(7)~caselessEquals("sizeof(") then do
    rp = expr~lastPos(")")
    if rp > 7 then do
      name = expr~substr(8, rp - 8)~strip
      if self~isIdentifier(name) then return symbol~localExtent(name)
    end
  end
  return .nil

::method reverseOperator class private
  use arg operator
  if operator = "<=" then return ">="
  if operator = ">=" then return "<="
  if operator = "<" then return ">"
  if operator = ">" then return "<"
  return operator

::method assignmentEquals class private
  use arg text
  do i = 1 to text~length
    if text~substr(i, 1) \= "=" then iterate
    prev = ""
    next = ""
    if i > 1 then prev = text~substr(i - 1, 1)
    if i < text~length then next = text~substr(i + 1, 1)
    if prev = "=" | prev = "<" | prev = ">" | prev = "!" | prev = "+" | prev = "-" | prev = "*" | prev = "/" | prev = "%" | prev = "&" | prev = "|" | prev = "^" then iterate
    if next = "=" then iterate
    return i
  end
  return 0

::method identifierTokens class private
  use arg text
  out = .array~new
  seen = .table~new
  token = ""
  do i = 1 to text~length + 1
    if i <= text~length then c = text~substr(i, 1)
    else c = " "
    if self~isIdentifierChar(c) then do
      token ||= c
      iterate
    end
    if token \= "" then do
      if self~isIdentifier(token) then do
        low = token~lower
        if low \= "sizeof" & low \= "true" & low \= "false" & low \= "nullptr" & low \= "null" then do
          if seen[token~translate] == .nil then do
            out~append(token)
            seen[token~translate] = .true
          end
        end
      end
      token = ""
    end
  end
  return out

::method splitArguments class private
  use arg text
  out = .array~new
  buf = ""
  paren = 0
  bracket = 0
  angle = 0
  do i = 1 to text~length
    c = text~substr(i, 1)
    if c = "(" then paren += 1
    else if c = ")" then paren -= 1
    else if c = "[" then bracket += 1
    else if c = "]" then bracket -= 1
    else if c = "<" then angle += 1
    else if c = ">" then do
      if angle > 0 then angle -= 1
    end
    if c = "," then do
      if paren = 0 & bracket = 0 & angle = 0 then do
        out~append(buf~strip)
        buf = ""
        iterate
      end
    end
    buf ||= c
  end
  if buf~strip \= "" | text~strip = "" then out~append(buf~strip)
  return out

::method matchingParen class private
  use arg text, lp
  depth = 0
  do i = lp to text~length
    c = text~substr(i, 1)
    if c = "(" then depth += 1
    else if c = ")" then do
      depth -= 1
      if depth = 0 then return i
    end
  end
  return 0

::method lastIdentifier class private
  use arg text
  s = text~string
  i = s~length
  do while i > 0
    c = s~substr(i, 1)
    if self~isIdentifierChar(c) then leave
    i -= 1
  end
  if i = 0 then return ""
  e = i
  do while i > 0
    c = s~substr(i, 1)
    if \self~isIdentifierChar(c) then leave
    i -= 1
  end
  token = s~substr(i + 1, e - i)
  if self~isIdentifier(token) then return token
  return ""

::method isIdentifier class private
  use arg text
  s = text~string~strip
  if s = "" then return .false
  if \self~isIdentifierStart(s~left(1)) then return .false
  do i = 2 to s~length
    if \self~isIdentifierChar(s~substr(i, 1)) then return .false
  end
  return .true

::method isIdentifierStart class private
  use arg c
  if c = "_" then return .true
  return c~datatype("A")

::method isIdentifierChar class private
  use arg c
  if c = "_" then return .true
  return c~datatype("A") | c~datatype("N")

::requires "CodeSemanticSource.cls"
