/*
 * XmlNativeSource v0.2
 *
 * ooRexx-native XML object model, parser, XPath subset and transformation core.
 *
 * Design invariant: XML is never reduced to a string list in order to move it
 * between layers.  Nodes, attributes, selections, source spans, diagnostics and
 * processing history remain objects until an explicit projection boundary.
 */


::class XmlValidationFinding subclass RichSourceFinding public

::class XmlBusinessFact subclass RichBusinessFact public
::method provenance
  p = .table~new
  p["source"] = self~source
  p["row"] = self~row
  p["createdAt"] = self~createdAt
  row = self~row
  if row \== .nil then do
    p["origin"] = row~originNode
    p["document"] = row~document
    p["projection"] = row~projection
  end
  return p

::class XmlSourceSpan public
::attribute source get
::attribute startOffset get
::attribute endOffset get
::attribute startLine get
::attribute startColumn get
::attribute endLine get
::attribute endColumn get

::method init
  expose source startOffset endOffset startLine startColumn endLine endColumn
  use arg sourceArg, startOffsetArg, endOffsetArg, startLineArg, startColumnArg, endLineArg, endColumnArg
  source = sourceArg~string
  startOffset = startOffsetArg
  endOffset = endOffsetArg
  startLine = startLineArg
  startColumn = startColumnArg
  endLine = endLineArg
  endColumn = endColumnArg

::method string
  expose source startLine startColumn endLine endColumn
  return source || ":" || startLine || ":" || startColumn || "-" || endLine || ":" || endColumn


::class XmlAttributeRef public
::attribute owner get
::attribute qName get
::attribute prefix get
::attribute localName get
::attribute namespaceUri get
::attribute lexicalValue get
::attribute value get
::attribute span get

::method init
  expose owner qName prefix localName namespaceUri lexicalValue value span
  use arg ownerArg, qNameArg, prefixArg, localNameArg, namespaceUriArg, lexicalValueArg, valueArg, spanArg
  owner = ownerArg
  qName = qNameArg~string
  prefix = prefixArg~string
  localName = localNameArg~string
  namespaceUri = namespaceUriArg~string
  lexicalValue = lexicalValueArg
  value = valueArg
  span = spanArg

::method document
  expose owner
  return owner~document

::method text
  expose value
  return value

::method path
  expose owner qName
  return owner~path || "/@" || qName

::method line
  expose span
  return span~startLine

::method provenance
  expose owner span lexicalValue qName namespaceUri
  p = .table~new
  p["kind"] = "ATTRIBUTE"
  p["source"] = owner~document~source
  p["document"] = owner~document
  p["owner"] = owner
  p["path"] = self~path
  p["line"] = self~line
  p["span"] = span
  p["qName"] = qName
  p["namespaceUri"] = namespaceUri
  p["lexicalValue"] = lexicalValue
  return p

::method string
  expose value
  return value


::class XmlNodeRef public
::attribute document get
::attribute nodeId get
::attribute kind get
::attribute qName get
::attribute prefix get
::attribute localName get
::attribute namespaceUri get
::attribute lexicalValue get
::attribute value get
::attribute span get
::attribute startTagSpan
::attribute endTagSpan
::attribute parent
::attribute children get
::attribute attributes get
::attribute attributeOrder get
::attribute namespaceBindings
::attribute derivedFrom get
::attribute annotations get

::method init
  expose document nodeId kind qName prefix localName namespaceUri lexicalValue value span startTagSpan endTagSpan parent children attributes attributeOrder namespaceBindings derivedFrom annotations
  use arg documentArg, nodeIdArg, kindArg, qNameArg = "", prefixArg = "", localNameArg = "", namespaceUriArg = "", lexicalValueArg = "", valueArg = "", spanArg = .nil
  document = documentArg
  nodeId = nodeIdArg
  kind = kindArg~string~translate
  qName = qNameArg~string
  prefix = prefixArg~string
  localName = localNameArg~string
  namespaceUri = namespaceUriArg~string
  lexicalValue = lexicalValueArg
  value = valueArg
  span = spanArg
  startTagSpan = .nil
  endTagSpan = .nil
  parent = .nil
  children = .array~new
  attributes = .table~new
  attributeOrder = .array~new
  namespaceBindings = .table~new
  derivedFrom = .array~new
  annotations = .table~new

::method addChild
  expose children
  use arg child
  child~parent = self
  children~append(child)
  return child

::method addAttribute
  expose attributes attributeOrder
  use arg attribute
  attributes[attribute~qName] = attribute
  attributeOrder~append(attribute)
  return attribute

::method attribute
  expose attributes attributeOrder
  use arg name
  found = attributes[name~string]
  if found \== .nil then return found
  do a over attributeOrder
    if a~localName == name~string then return a
  end
  return .nil

::method text
  expose kind value children
  if kind = "TEXT" | kind = "CDATA" | kind = "ATTRIBUTE" then return value
  if kind = "COMMENT" | kind = "PI" | kind = "DOCTYPE" then return value
  out = ""
  do child over children
    if child~kind = "TEXT" | child~kind = "CDATA" | child~kind = "ELEMENT" then out = out || child~text
  end
  return out

::method elementChildren
  expose children
  out = .array~new
  do child over children
    if child~kind = "ELEMENT" then out~append(child)
  end
  return out

::method childElementsNamed
  expose children
  use arg wanted
  out = .array~new
  do child over children
    if child~kind = "ELEMENT" then do
      if child~qName == wanted | child~localName == wanted then out~append(child)
    end
  end
  return out

::method line
  expose span
  if span == .nil then return 0
  return span~startLine

::method path
  expose kind parent qName
  if kind = "DOCUMENT" then return "/"
  if parent == .nil then do
    if qName = "" then return "/"
    return "/" || qName || "[1]"
  end
  if kind = "ATTRIBUTE" then return parent~path || "/@" || qName
  if kind = "TEXT" then do
    index = 0
    do sibling over parent~children
      if sibling~kind = "TEXT" then index = index + 1
      if sibling == self then leave
    end
    return parent~path || "/text()[" || index || "]"
  end
  if kind = "CDATA" then do
    index = 0
    do sibling over parent~children
      if sibling~kind = "CDATA" then index = index + 1
      if sibling == self then leave
    end
    return parent~path || "/cdata()[" || index || "]"
  end
  if kind = "COMMENT" then return parent~path || "/comment()"
  if kind = "PI" then return parent~path || "/processing-instruction()"
  if kind = "DOCTYPE" then return "/doctype()"

  index = 0
  do sibling over parent~children
    if sibling~kind = "ELEMENT" then do
      if sibling~qName == qName then index = index + 1
    end
    if sibling == self then leave
  end
  if parent~kind = "DOCUMENT" then return "/" || qName || "[" || index || "]"
  return parent~path || "/" || qName || "[" || index || "]"

::method xpath
  expose document
  use arg expression
  return document~xpath(expression, self)

::method addDerivedFrom
  expose derivedFrom
  use arg sourceObject
  derivedFrom~append(sourceObject)
  return self

::method annotate
  expose annotations
  use arg key, object
  annotations[key~string] = object
  return self

::method provenance
  expose document nodeId kind qName namespaceUri span lexicalValue derivedFrom
  p = .table~new
  p["kind"] = kind
  p["source"] = document~source
  p["document"] = document
  p["nodeId"] = nodeId
  p["path"] = self~path
  p["line"] = self~line
  p["span"] = span
  p["qName"] = qName
  p["namespaceUri"] = namespaceUri
  p["lexicalValue"] = lexicalValue
  p["derivedFrom"] = derivedFrom
  return p

::method string
  expose kind qName nodeId
  if kind = "ELEMENT" then return "XML-NODE(" || nodeId || "," || qName || ")"
  return "XML-" || kind || "(" || nodeId || ")"


::class XmlSelection public
::attribute document get
::attribute expression get
::attribute contextNode get
::attribute kind get
::attribute nodes get
::attribute value get
::attribute evaluatedAt get
::attribute plan get

::method init
  expose document expression contextNode kind nodes value evaluatedAt plan
  use arg documentArg, expressionArg, contextNodeArg, kindArg, dataArg, planArg = .nil
  document = documentArg
  expression = expressionArg~string
  contextNode = contextNodeArg
  kind = kindArg~string~translate
  nodes = .array~new
  value = .nil
  if kind = "NODESET" then nodes = dataArg
  else value = dataArg
  plan = planArg
  evaluatedAt = .DateTime~new~utcIsoDate

::method count
  expose kind nodes
  if kind = "NODESET" then return nodes~items
  return 1

::method firstNode
  expose kind nodes
  if kind \= "NODESET" then return .nil
  if nodes~items = 0 then return .nil
  return nodes[1]

::method isEmpty
  expose kind nodes value
  if kind = "NODESET" then return nodes~items = 0
  return value == .nil

::method scalar
  expose kind nodes value expression
  if kind \= "NODESET" then return value
  if nodes~items = 0 then return .nil
  if nodes~items > 1 then raise syntax 93.900 additional("XPath selection is multi-valued; refusing to flatten node set:" expression)
  return nodes[1]~text

::method provenance
  expose document expression contextNode kind evaluatedAt plan
  p = .table~new
  p["document"] = document
  p["expression"] = expression
  p["contextNode"] = contextNode
  p["kind"] = kind
  p["evaluatedAt"] = evaluatedAt
  p["plan"] = plan
  return p

::method string
  expose kind nodes value
  if kind = "NODESET" then return "XML-NODESET(" || nodes~items || ")"
  if value == .nil then return "XML-SCALAR(NIL)"
  return "XML-SCALAR(" || value~string || ")"


::class XmlDocumentContext public
::attribute source get
::attribute sourceText get
::attribute root get
::attribute documentNode get
::attribute openedAt get
::attribute namespaces get
::attribute history get
::attribute validationFindings get
::attribute validationReports get
::attribute allNodes get
::attribute parserName get
::attribute parentDocument get
::attribute transformName get
::attribute transformParameters get
::attribute metadata get
::attribute closed get

::method init
  expose source sourceText root documentNode openedAt namespaces history validationFindings validationReports allNodes parserName parentDocument transformName transformParameters metadata closed nextNodeId
  use arg sourceArg, textArg = .nil, parentDocumentArg = .nil, transformNameArg = "", transformParametersArg = .nil
  source = sourceArg~string
  sourceText = textArg
  parentDocument = parentDocumentArg
  transformName = transformNameArg~string
  if transformParametersArg == .nil then transformParameters = .table~new
  else transformParameters = transformParametersArg
  namespaces = .table~new
  history = .array~new
  validationFindings = .array~new
  validationReports = .array~new
  allNodes = .array~new
  metadata = .table~new
  openedAt = .DateTime~new~utcIsoDate
  parserName = "OOREXX_NATIVE_XML_V0.2"
  closed = .false
  nextNodeId = 1
  documentNode = self~newNode("DOCUMENT", "", "", "", "", "", "", .nil)
  root = .nil

  if sourceText == .nil then do
    sourceText = self~readSource(source)
  end
  if sourceText \== .nil then do
    parser = .XmlNativeParser~new(self, sourceText)
    parser~parse
    history~append(.RichProcessingEvent~new("PARSE", "OOREXX_NATIVE", source, self))
  end

::method fromText class
  use arg text, source = "memory:xml"
  return self~new(source, text)

::method emptyDerived class
  use arg source, parentDocument, transformName, parameters = .nil
  doc = self~new(source, "", parentDocument, transformName, parameters)
  /* Empty source parsed as no-op by parser. */
  doc~history~append(.RichProcessingEvent~new("TRANSFORM", "CREATE_DERIVED_DOCUMENT", transformName, parentDocument))
  return doc

::method readSource private
  use arg sourcePath
  s = .stream~new(sourcePath)
  openStatus = s~open("READ")
  if \openStatus~caselessEquals("READY:") then raise syntax 93.900 additional("Unable to open XML source:" sourcePath || " status=" || openStatus)
  available = s~chars
  data = s~charin(1, available)
  closeStatus = s~close
  return data

::method allocateNodeId
  expose nextNodeId
  id = nextNodeId
  nextNodeId = nextNodeId + 1
  return id

::method newNode
  expose allNodes
  use arg kind, qName = "", prefix = "", localName = "", namespaceUri = "", lexicalValue = "", value = "", span = .nil
  node = .XmlNodeRef~new(self, self~allocateNodeId, kind, qName, prefix, localName, namespaceUri, lexicalValue, value, span)
  allNodes~append(node)
  return node

::method setRoot
  expose root documentNode
  use arg node
  root = node
  found = .false
  do child over documentNode~children
    if child == node then found = .true
  end
  if \found then documentNode~addChild(node)
  return node

::method registerNamespace
  expose namespaces
  use arg prefix, uri
  prefix = prefix~string
  uri = uri~string
  if prefix = "" then raise syntax 93.900 additional("XPath namespace requires an explicit prefix")
  namespaces[prefix] = uri
  return self

::method namespaceUriForPrefix
  expose namespaces
  use arg prefix
  return namespaces[prefix~string]

::method xpath
  expose history
  use arg expression, contextNode = .nil
  if contextNode == .nil then contextNode = self~documentNode
  selection = .XmlXPathEngine~evaluate(self, expression~string, contextNode)
  history~append(.RichProcessingEvent~new("XPATH", "EVALUATE", expression~string, selection))
  return selection

::method transform
  expose history
  use arg stylesheetDocument, parameters = .nil
  if stylesheetDocument~isA(.String) then stylesheetDocument = .XmlDocumentContext~new(stylesheetDocument)
  transformed = .XmlTransformEngine~transform(self, stylesheetDocument, parameters)
  history~append(.RichProcessingEvent~new("XSLT", "OOREXX_NATIVE_SUBSET", stylesheetDocument~source, transformed))
  return transformed

::method addFinding
  expose validationFindings
  use arg finding
  validationFindings~append(finding)
  return finding

::method validate
  expose validationReports history
  use arg ruleSet
  report = ruleSet~validate(self)
  validationReports~append(report)
  history~append(.RichProcessingEvent~new("VALIDATE", ruleSet~name, report~status, report))
  return report

::method close
  expose closed history
  if closed then return .true
  closed = .true
  history~append(.RichProcessingEvent~new("LIFECYCLE", "CLOSE", source, self))
  return .true

::method string
  expose source parserName
  return "XML-DOCUMENT(" || parserName || "," || source || ")"


::class XmlNativeParser public
::attribute document get
::attribute text get
::attribute position get
::attribute line get
::attribute column get

::method init
  expose document text position line column length stack
  use arg documentArg, textArg
  document = documentArg
  text = textArg
  position = 1
  line = 1
  column = 1
  length = text~length
  stack = .array~new

::method parse
  expose document text position length stack
  if length = 0 then return document

  do while position <= length
    if self~peek("<!--") then self~parseComment
    else if self~peek("<![CDATA[") then self~parseCdata
    else if self~peek("<?") then self~parsePi
    else if self~peek("<!DOCTYPE") | self~peek("<!doctype") then self~parseDoctype
    else if self~peek("</") then self~parseEndTag
    else if self~peek("<") then self~parseStartTag
    else self~parseText
  end

  if stack~items > 0 then do
    node = stack[stack~items]
    raise syntax 93.900 additional("Unclosed XML element:" node~qName || " at " || node~path)
  end
  return document

::method currentParent private
  expose stack document
  if stack~items = 0 then return document~documentNode
  return stack[stack~items]

::method peek private
  expose text position
  use arg token
  return text~substr(position, token~length) == token

::method mark private
  expose position line column
  m = .array~new
  m[1] = position
  m[2] = line
  m[3] = column
  return m

::method spanFrom private
  expose document position line column
  use arg mark
  return .XmlSourceSpan~new(document~source, mark[1], position - 1, mark[2], mark[3], line, column)

::method advance private
  expose text position line column length
  use arg count = 1
  do i = 1 to count
    if position > length then leave
    ch = text~substr(position, 1)
    position = position + 1
    if ch == d2c(10) then do
      line = line + 1
      column = 1
    end
    else column = column + 1
  end
  return position

::method skipWhitespace private
  expose text position length
  do while position <= length
    ch = text~substr(position, 1)
    if ch \= " " & ch \= d2c(9) & ch \= d2c(10) & ch \= d2c(13) then leave
    next = self~advance(1)
  end

::method readName private
  expose text position length
  start = position
  do while position <= length
    ch = text~substr(position, 1)
    if self~isNameChar(ch) then next = self~advance(1)
    else leave
  end
  if position = start then return ""
  return text~substr(start, position - start)

::method isNameChar private
  use arg ch
  if ch = "" then return .false
  if datatype(ch, "M") then return .true
  if ch >= "0" & ch <= "9" then return .true
  if ch = "_" | ch = "-" | ch = "." | ch = ":" then return .true
  return .false

::method splitQName private
  use arg qName
  pair = .array~new
  colon = pos(":", qName)
  if colon = 0 then do
    pair[1] = ""
    pair[2] = qName
  end
  else do
    pair[1] = qName~substr(1, colon - 1)
    pair[2] = qName~substr(colon + 1)
  end
  return pair

::method inheritedNamespaces private
  parent = self~currentParent
  ns = .table~new
  if parent~kind = "ELEMENT" then do key over parent~namespaceBindings~allIndexes
    ns[key] = parent~namespaceBindings[key]
  end
  return ns

::method parseStartTag private
  expose document text position line column stack length
  startMark = self~mark
  next = self~advance(1)
  qName = self~readName
  if qName = "" then raise syntax 93.900 additional("Malformed XML start tag at line" line)

  namespaceBindings = self~inheritedNamespaces
  rawAttrs = .array~new
  selfClosing = .false

  do forever
    self~skipWhitespace
    if position > length then raise syntax 93.900 additional("Unexpected end of XML inside start tag:" qName)
    if self~peek("/>") then do
      next = self~advance(2)
      selfClosing = .true
      leave
    end
    if self~peek(">") then do
      next = self~advance(1)
      leave
    end

    attrMark = self~mark
    attrName = self~readName
    if attrName = "" then raise syntax 93.900 additional("Malformed XML attribute in element:" qName)
    self~skipWhitespace
    if \self~peek("=") then raise syntax 93.900 additional("XML attribute missing '=':" attrName)
    next = self~advance(1)
    self~skipWhitespace
    quote = text~substr(position, 1)
    if quote \= '"' & quote \= "'" then raise syntax 93.900 additional("XML attribute value must be quoted:" attrName)
    next = self~advance(1)
    valueStart = position
    do while position <= length
      if text~substr(position, 1) == quote then leave
      next = self~advance(1)
    end
    if position > length then raise syntax 93.900 additional("Unterminated XML attribute:" attrName)
    lexical = text~substr(valueStart, position - valueStart)
    next = self~advance(1)
    attrSpan = self~spanFrom(attrMark)
    entry = .table~new
    entry["name"] = attrName
    entry["lexical"] = lexical
    entry["value"] = self~decodeEntities(lexical)
    entry["span"] = attrSpan
    rawAttrs~append(entry)

    if attrName = "xmlns" then namespaceBindings[""] = entry["value"]
    else if attrName~substr(1, 6) = "xmlns:" then namespaceBindings[attrName~substr(7)] = entry["value"]
  end

  qParts = self~splitQName(qName)
  prefix = qParts[1]
  localName = qParts[2]
  namespaceUri = ""
  nsFound = namespaceBindings[prefix]
  if nsFound \== .nil then namespaceUri = nsFound
  node = document~newNode("ELEMENT", qName, prefix, localName, namespaceUri, "", "", self~spanFrom(startMark))
  node~namespaceBindings = namespaceBindings
  node~startTagSpan = self~spanFrom(startMark)

  do entry over rawAttrs
    attrName = entry["name"]
    attrParts = self~splitQName(attrName)
    attrPrefix = attrParts[1]
    attrLocal = attrParts[2]
    attrUri = ""
    if attrPrefix \= "" & attrPrefix \= "xmlns" then do
      found = namespaceBindings[attrPrefix]
      if found \== .nil then attrUri = found
    end
    a = .XmlAttributeRef~new(node, attrName, attrPrefix, attrLocal, attrUri, entry["lexical"], entry["value"], entry["span"])
    node~addAttribute(a)
  end

  parent = self~currentParent
  parent~addChild(node)
  if document~root == .nil then document~setRoot(node)

  if \selfClosing then stack~append(node)
  return node

::method parseEndTag private
  expose text position line stack
  startMark = self~mark
  next = self~advance(2)
  qName = self~readName
  self~skipWhitespace
  if \self~peek(">") then raise syntax 93.900 additional("Malformed XML end tag:" qName)
  next = self~advance(1)
  if stack~items = 0 then raise syntax 93.900 additional("Unexpected XML end tag:" qName)
  node = stack[stack~items]
  if node~qName \= qName then raise syntax 93.900 additional("Mismatched XML end tag:" qName || "; expected " || node~qName)
  node~endTagSpan = self~spanFrom(startMark)
  stack~delete(stack~items)
  return node

::method parseText private
  expose document text position length
  startMark = self~mark
  start = position
  do while position <= length
    if self~peek("<") then leave
    next = self~advance(1)
  end
  lexical = text~substr(start, position - start)
  if lexical = "" then return .nil
  node = document~newNode("TEXT", "", "", "", "", lexical, self~decodeEntities(lexical), self~spanFrom(startMark))
  parent = self~currentParent
  parent~addChild(node)
  return node

::method parseComment private
  expose document text position length
  startMark = self~mark
  next = self~advance(4)
  start = position
  endPos = pos("-->", text, position)
  if endPos = 0 then raise syntax 93.900 additional("Unterminated XML comment")
  do while position < endPos
    next = self~advance(1)
  end
  value = text~substr(start, endPos - start)
  next = self~advance(3)
  node = document~newNode("COMMENT", "", "", "", "", value, value, self~spanFrom(startMark))
  parent = self~currentParent
  parent~addChild(node)
  return node

::method parseCdata private
  expose document text position
  startMark = self~mark
  next = self~advance(9)
  start = position
  endPos = pos("]]>", text, position)
  if endPos = 0 then raise syntax 93.900 additional("Unterminated XML CDATA section")
  do while position < endPos
    next = self~advance(1)
  end
  value = text~substr(start, endPos - start)
  next = self~advance(3)
  node = document~newNode("CDATA", "", "", "", "", value, value, self~spanFrom(startMark))
  parent = self~currentParent
  parent~addChild(node)
  return node

::method parsePi private
  expose document text position
  startMark = self~mark
  next = self~advance(2)
  start = position
  endPos = pos("?>", text, position)
  if endPos = 0 then raise syntax 93.900 additional("Unterminated XML processing instruction")
  do while position < endPos
    next = self~advance(1)
  end
  value = text~substr(start, endPos - start)
  next = self~advance(2)
  node = document~newNode("PI", "", "", "", "", value, value, self~spanFrom(startMark))
  parent = self~currentParent
  parent~addChild(node)
  return node

::method parseDoctype private
  expose document text position length
  startMark = self~mark
  start = position
  bracketDepth = 0
  quote = ""
  do while position <= length
    ch = text~substr(position, 1)
    if quote \= "" then do
      if ch == quote then quote = ""
    end
    else do
      if ch = '"' | ch = "'" then quote = ch
      else if ch = "[" then bracketDepth = bracketDepth + 1
      else if ch = "]" & bracketDepth > 0 then bracketDepth = bracketDepth - 1
      else if ch = ">" & bracketDepth = 0 then do
        next = self~advance(1)
        leave
      end
    end
    next = self~advance(1)
  end
  lexical = text~substr(start, position - start)
  node = document~newNode("DOCTYPE", "", "", "", "", lexical, lexical, self~spanFrom(startMark))
  document~documentNode~addChild(node)
  detail = .table~new
  detail["doctype"] = lexical
  finding = .RichSourceFinding~new("INFO", "XML.DOCTYPE.PRESERVED", "DOCTYPE preserved; external entity resolution is not performed", node, "OOREXX_NATIVE_XML", detail)
  document~addFinding(finding)
  return node

::method decodeEntities private
  use arg lexical
  out = ""
  i = 1
  do while i <= lexical~length
    ch = lexical~substr(i, 1)
    if ch \= "&" then do
      out = out || ch
      i = i + 1
      iterate
    end
    semi = pos(";", lexical, i + 1)
    if semi = 0 then do
      out = out || ch
      i = i + 1
      iterate
    end
    entity = lexical~substr(i + 1, semi - i - 1)
    replacement = .nil
    select
      when entity = "lt" then replacement = "<"
      when entity = "gt" then replacement = ">"
      when entity = "amp" then replacement = "&"
      when entity = "quot" then replacement = '"'
      when entity = "apos" then replacement = "'"
      otherwise do
        if entity~substr(1, 2) = "#x" | entity~substr(1, 2) = "#X" then do
          hex = entity~substr(3)
          if datatype(hex, "X") then replacement = self~codepointToUtf8(x2d(hex))
        end
        else if entity~substr(1, 1) = "#" then do
          dec = entity~substr(2)
          if datatype(dec, "W") then replacement = self~codepointToUtf8(dec)
        end
      end
    end
    if replacement == .nil then out = out || "&" || entity || ";"
    else out = out || replacement
    i = semi + 1
  end
  return out

::method codepointToUtf8 private
  use arg cp
  if cp < 0 then return ""
  if cp <= 127 then return d2c(cp)
  if cp <= 2047 then return d2c(192 + (cp % 64)) || d2c(128 + (cp // 64))
  if cp <= 65535 then do
    b1 = 224 + (cp % 4096)
    b2 = 128 + ((cp // 4096) % 64)
    b3 = 128 + (cp // 64)
    return d2c(b1) || d2c(b2) || d2c(b3)
  end
  /* Keep unsupported high code points lexically visible rather than inventing data. */
  return "&#" || cp || ";"


::class XmlValidationReport public
::attribute ruleSetName get
::attribute document get
::attribute valid get
::attribute status get
::attribute findings get
::attribute startedAt get
::attribute completedAt get

::method init
  expose ruleSetName document valid status findings startedAt completedAt
  use arg ruleSetNameArg, documentArg
  ruleSetName = ruleSetNameArg~string
  document = documentArg
  valid = .true
  status = "VALID"
  findings = .array~new
  startedAt = .DateTime~new~utcIsoDate
  completedAt = .nil

::method addFinding
  expose findings valid status
  use arg finding
  findings~append(finding)
  if finding~severity = "ERROR" | finding~severity = "FATAL" then do
    valid = .false
    status = "INVALID"
  end
  return finding

::method complete
  expose completedAt
  completedAt = .DateTime~new~utcIsoDate
  return self

::method string
  expose ruleSetName status findings
  return "XML-VALIDATION(" || ruleSetName || "," || status || "," || findings~items || ")"


::class XmlValidationRule public
::attribute kind get
::attribute contextXPath get
::attribute targetXPath get
::attribute semanticType get
::attribute minimum get
::attribute maximum get
::attribute code get
::attribute message get

::method init
  expose kind contextXPath targetXPath semanticType minimum maximum code message
  use arg kindArg, contextXPathArg, targetXPathArg, semanticTypeArg = "", minimumArg = .nil, maximumArg = .nil, codeArg = "XML.RULE", messageArg = "XML validation rule failed"
  kind = kindArg~string~translate
  contextXPath = contextXPathArg~string
  targetXPath = targetXPathArg~string
  semanticType = semanticTypeArg~string~translate
  minimum = minimumArg
  maximum = maximumArg
  code = codeArg~string
  message = messageArg~string


::class XmlRuleSet public
::attribute name get
::attribute rules get

::method init
  expose name rules
  use arg nameArg = "XML_RULESET"
  name = nameArg~string
  rules = .array~new

::method require
  expose rules
  use arg contextXPath, targetXPath, code = "XML.REQUIRED", message = "Required XML value is absent"
  rules~append(.XmlValidationRule~new("REQUIRED", contextXPath, targetXPath, "", 1, .nil, code, message))
  return self

::method notEmpty
  expose rules
  use arg contextXPath, targetXPath, code = "XML.NOT_EMPTY", message = "XML value must not be empty"
  rules~append(.XmlValidationRule~new("NOT_EMPTY", contextXPath, targetXPath, "", 1, .nil, code, message))
  return self

::method type
  expose rules
  use arg contextXPath, targetXPath, semanticType, code = "XML.TYPE", message = "XML value has invalid type"
  rules~append(.XmlValidationRule~new("TYPE", contextXPath, targetXPath, semanticType, .nil, .nil, code, message))
  return self

::method cardinality
  expose rules
  use arg contextXPath, targetXPath, minimum, maximum, code = "XML.CARDINALITY", message = "XML selection has invalid cardinality"
  rules~append(.XmlValidationRule~new("CARDINALITY", contextXPath, targetXPath, "", minimum, maximum, code, message))
  return self

::method validate
  expose name rules
  use arg document
  report = .XmlValidationReport~new(name, document)
  do rule over rules
    contexts = document~xpath(rule~contextXPath)
    if contexts~kind \= "NODESET" then iterate
    if contexts~nodes~items = 0 then do
      details = .table~new
      details["contextXPath"] = rule~contextXPath
      details["targetXPath"] = rule~targetXPath
      finding = .XmlValidationFinding~new("ERROR", rule~code, rule~message || " (context absent)", document~root, name, details)
      report~addFinding(finding)
      document~addFinding(finding)
      iterate
    end
    do contextNode over contexts~nodes
      selection = document~xpath(rule~targetXPath, contextNode)
      count = 0
      if selection~kind = "NODESET" then count = selection~nodes~items
      else if selection~value \== .nil then count = 1

      select
        when rule~kind = "REQUIRED" then do
          if count = 0 then self~finding(document, report, rule, contextNode, selection, "ABSENT")
        end
        when rule~kind = "NOT_EMPTY" then do
          if count = 0 then self~finding(document, report, rule, contextNode, selection, "ABSENT")
          else if selection~kind = "NODESET" then do selectedNode over selection~nodes
            if selectedNode~text = "" then self~finding(document, report, rule, selectedNode, selection, "PRESENT_EMPTY")
          end
        end
        when rule~kind = "TYPE" then do
          if selection~kind = "NODESET" then do selectedNode over selection~nodes
            value = selectedNode~text
            valid = .true
            if rule~semanticType = "INTEGER" then valid = datatype(value, "W")
            else if rule~semanticType = "DECIMAL" then valid = datatype(value, "N")
            if \valid then self~finding(document, report, rule, selectedNode, selection, "TYPE_ERROR")
          end
        end
        when rule~kind = "CARDINALITY" then do
          invalid = .false
          if rule~minimum \== .nil then if count < rule~minimum then invalid = .true
          if rule~maximum \== .nil then if count > rule~maximum then invalid = .true
          if invalid then do
            sourceObject = contextNode
            if count > 0 then sourceObject = selection
            self~finding(document, report, rule, sourceObject, selection, "CARDINALITY_ERROR")
          end
        end
        otherwise nop
      end
    end
  end
  report~complete
  return report

::method finding private
  use arg document, report, rule, sourceObject, selection, state
  details = .table~new
  details["contextXPath"] = rule~contextXPath
  details["targetXPath"] = rule~targetXPath
  details["semanticType"] = rule~semanticType
  details["state"] = state
  details["selection"] = selection
  finding = .XmlValidationFinding~new("ERROR", rule~code, rule~message, sourceObject, report~ruleSetName, details)
  report~addFinding(finding)
  document~addFinding(finding)
  return finding


::class XmlXPathStep public
::attribute axis get
::attribute test get
::attribute predicates get

::method init
  expose axis test predicates
  use arg axisArg, testArg, predicatesArg = .nil
  axis = axisArg~string~translate
  test = testArg~string
  if predicatesArg == .nil then predicates = .array~new
  else predicates = predicatesArg

::method string
  expose axis test
  return axis || "::" || test


::class XmlXPathEngine public

::method evaluate class
  use arg document, expression, contextNode
  expression = expression~strip
  if expression = "" then raise syntax 93.900 additional("XPath expression is required")

  if expression~substr(1, 6)~caselessEquals("count(") & expression~substr(expression~length, 1) = ")" then do
    inner = expression~substr(7, expression~length - 7)
    selected = self~evaluate(document, inner, contextNode)
    if selected~kind \= "NODESET" then return .XmlSelection~new(document, expression, contextNode, "SCALAR", 1)
    return .XmlSelection~new(document, expression, contextNode, "SCALAR", selected~nodes~items)
  end

  if expression~substr(1, 7)~caselessEquals("string(") & expression~substr(expression~length, 1) = ")" then do
    inner = expression~substr(8, expression~length - 8)
    selected = self~evaluate(document, inner, contextNode)
    return .XmlSelection~new(document, expression, contextNode, "SCALAR", self~selectionString(selected))
  end

  if expression~substr(1, 8)~caselessEquals("boolean(") & expression~substr(expression~length, 1) = ")" then do
    inner = expression~substr(9, expression~length - 9)
    selected = self~evaluate(document, inner, contextNode)
    return .XmlSelection~new(document, expression, contextNode, "SCALAR", self~selectionBoolean(selected))
  end

  if expression~substr(1, 1) = "$" then do
    /* Variables are resolved by the transform engine and do not belong to a bare document XPath. */
    return .XmlSelection~new(document, expression, contextNode, "SCALAR", .nil)
  end

  plan = self~compile(expression)
  if plan["absolute"] then current = self~singleArray(document~documentNode)
  else current = self~singleArray(contextNode)

  steps = plan["steps"]
  do step over steps
    current = self~applyStep(document, current, step)
  end
  return .XmlSelection~new(document, expression, contextNode, "NODESET", current, plan)

::method compile class
  use arg expression
  plan = .table~new
  steps = .array~new
  absolute = .false
  i = 1
  axis = "CHILD"
  if expression~substr(1, 2) = "//" then do
    absolute = .true
    axis = "DESCENDANT"
    i = 3
  end
  else if expression~substr(1, 1) = "/" then do
    absolute = .true
    axis = "CHILD"
    i = 2
  end

  token = ""
  bracketDepth = 0
  quote = ""
  do while i <= expression~length + 1
    if i > expression~length then ch = "/"
    else ch = expression~substr(i, 1)

    if quote \= "" then do
      token = token || ch
      if ch == quote then quote = ""
      i = i + 1
      iterate
    end
    if ch = '"' | ch = "'" then do
      quote = ch
      token = token || ch
      i = i + 1
      iterate
    end
    if ch = "[" then do
      bracketDepth = bracketDepth + 1
      token = token || ch
      i = i + 1
      iterate
    end
    if ch = "]" then do
      bracketDepth = bracketDepth - 1
      token = token || ch
      i = i + 1
      iterate
    end

    if ch = "/" & bracketDepth = 0 then do
      if token \= "" then steps~append(self~parseStep(axis, token))
      token = ""
      if i < expression~length & expression~substr(i + 1, 1) = "/" then do
        axis = "DESCENDANT"
        i = i + 2
      end
      else do
        axis = "CHILD"
        i = i + 1
      end
      iterate
    end
    token = token || ch
    i = i + 1
  end
  plan["absolute"] = absolute
  plan["steps"] = steps
  return plan

::method parseStep class private
  use arg axis, token
  test = token
  predicates = .array~new
  bracket = pos("[", token)
  if bracket > 0 then do
    test = token~substr(1, bracket - 1)
    rest = token~substr(bracket)
    do while rest \= ""
      if rest~substr(1, 1) \= "[" then leave
      close = self~findPredicateClose(rest)
      if close = 0 then raise syntax 93.900 additional("Unclosed XPath predicate:" token)
      predicates~append(rest~substr(2, close - 2)~strip)
      rest = rest~substr(close + 1)~strip
    end
  end
  return .XmlXPathStep~new(axis, test~strip, predicates)

::method findPredicateClose class private
  use arg text
  depth = 0
  quote = ""
  do i = 1 to text~length
    ch = text~substr(i, 1)
    if quote \= "" then do
      if ch == quote then quote = ""
      iterate
    end
    if ch = '"' | ch = "'" then do
      quote = ch
      iterate
    end
    if ch = "[" then depth = depth + 1
    else if ch = "]" then do
      depth = depth - 1
      if depth = 0 then return i
    end
  end
  return 0

::method applyStep class private
  use arg document, current, step
  candidates = .array~new

  if step~test = "." then return current
  if step~test = ".." then do
    do item over current
      parent = .nil
      if item~isA(.XmlAttributeRef) then parent = item~owner
      else parent = item~parent
      if parent \== .nil then self~appendUnique(candidates, parent)
    end
    return self~applyPredicates(document, candidates, step~predicates)
  end

  do item over current
    if step~axis = "DESCENDANT" then pool = self~descendants(item)
    else pool = self~childrenForStep(item, step~test)

    do candidate over pool
      if self~matches(document, candidate, step~test) then candidates~append(candidate)
    end
  end

  return self~applyPredicates(document, candidates, step~predicates)

::method childrenForStep class private
  use arg item, test
  out = .array~new
  if item~isA(.XmlAttributeRef) then return out
  if test~substr(1, 1) = "@" then do
    if item~kind \= "ELEMENT" then return out
    do a over item~attributeOrder
      out~append(a)
    end
    return out
  end
  do child over item~children
    out~append(child)
  end
  return out

::method descendants class private
  use arg item
  out = .array~new
  if item~isA(.XmlAttributeRef) then return out
  do child over item~children
    out~append(child)
    nested = self~descendants(child)
    do n over nested
      out~append(n)
    end
  end
  if item~kind = "ELEMENT" then do a over item~attributeOrder
    out~append(a)
  end
  return out

::method matches class private
  use arg document, candidate, test
  if test = "*" then do
    if candidate~isA(.XmlAttributeRef) then return .false
    return candidate~kind = "ELEMENT"
  end
  if test = "node()" then return .true
  if test = "text()" then do
    if candidate~isA(.XmlAttributeRef) then return .false
    return candidate~kind = "TEXT" | candidate~kind = "CDATA"
  end
  if test = "comment()" then do
    if candidate~isA(.XmlAttributeRef) then return .false
    return candidate~kind = "COMMENT"
  end
  if test~substr(1, 1) = "@" then do
    if \candidate~isA(.XmlAttributeRef) then return .false
    wanted = test~substr(2)
    if wanted = "*" then return .true
    return self~nameMatches(document, candidate, wanted)
  end
  if candidate~isA(.XmlAttributeRef) then return .false
  if candidate~kind \= "ELEMENT" then return .false
  return self~nameMatches(document, candidate, test)

::method nameMatches class private
  use arg document, candidate, wanted
  colon = pos(":", wanted)
  if colon = 0 then do
    /* XPath 1.0: unprefixed names match no-namespace names only. */
    return candidate~localName == wanted & candidate~namespaceUri = ""
  end
  prefix = wanted~substr(1, colon - 1)
  local = wanted~substr(colon + 1)
  uri = document~namespaceUriForPrefix(prefix)
  if uri == .nil then return .false
  return candidate~localName == local & candidate~namespaceUri == uri

::method applyPredicates class private
  use arg document, candidates, predicates
  out = candidates
  do predicate over predicates
    p = predicate~strip
    if datatype(p, "W") then do
      nextOut = .array~new
      index = p
      if index >= 1 & index <= out~items then nextOut~append(out[index])
      out = nextOut
      iterate
    end

    eq = self~findTopLevelEquals(p)
    if eq > 0 then do
      leftExpr = p~substr(1, eq - 1)~strip
      rightText = p~substr(eq + 1)~strip
      rightValue = self~unquote(rightText)
      nextOut = .array~new
      do candidate over out
        if candidate~isA(.XmlAttributeRef) then iterate
        selected = self~evaluate(document, leftExpr, candidate)
        if selected~kind = "NODESET" then do
          matched = .false
          do selectedNode over selected~nodes
            if selectedNode~text == rightValue then matched = .true
          end
          if matched then nextOut~append(candidate)
        end
        else if selected~value == rightValue then nextOut~append(candidate)
      end
      out = nextOut
      iterate
    end

    /* Existence predicate: retain candidate if relative expression selects anything. */
    nextOut = .array~new
    do candidate over out
      if candidate~isA(.XmlAttributeRef) then iterate
      selected = self~evaluate(document, p, candidate)
      if self~selectionBoolean(selected) then nextOut~append(candidate)
    end
    out = nextOut
  end
  return out

::method findTopLevelEquals class private
  use arg text
  quote = ""
  do i = 1 to text~length
    ch = text~substr(i, 1)
    if quote \= "" then do
      if ch == quote then quote = ""
      iterate
    end
    if ch = '"' | ch = "'" then quote = ch
    else if ch = "=" then return i
  end
  return 0

::method unquote class private
  use arg text
  if text~length >= 2 then do
    first = text~substr(1, 1)
    last = text~substr(text~length, 1)
    if (first = '"' & last = '"') | (first = "'" & last = "'") then return text~substr(2, text~length - 2)
  end
  return text

::method selectionString class private
  use arg selection
  if selection~kind \= "NODESET" then do
    if selection~value == .nil then return ""
    return selection~value~string
  end
  if selection~nodes~items = 0 then return ""
  return selection~nodes[1]~text

::method selectionBoolean class private
  use arg selection
  if selection~kind = "NODESET" then return selection~nodes~items > 0
  if selection~value == .nil then return .false
  if selection~value == .false then return .false
  if selection~value~string = "" then return .false
  return .true

::method singleArray class private
  use arg object
  a = .array~new
  a~append(object)
  return a

::method appendUnique class private
  use arg array, object
  do existing over array
    if existing == object then return array
  end
  array~append(object)
  return array


::class XmlTransformValue public
::attribute value get
::attribute expression get
::attribute sources get
::attribute parameterName get

::method init
  expose value expression sources parameterName
  use arg valueArg, expressionArg, sourcesArg = .nil, parameterNameArg = ""
  value = valueArg
  expression = expressionArg~string
  if sourcesArg == .nil then sources = .array~new
  else sources = sourcesArg
  parameterName = parameterNameArg~string

::method string
  expose value
  if value == .nil then return ""
  return value~string


/*
 * Deliberately small XSLT-compatible transform kernel.
 * It operates on the same rich XML objects and preserves derived-from links.
 * Supported instructions in this cut:
 *   xsl:stylesheet / xsl:transform
 *   xsl:param (top-level default + caller override)
 *   xsl:template match="/"
 *   xsl:value-of select="..."
 *   xsl:for-each select="..."
 *   xsl:if test="..."
 *   xsl:text
 *   literal result elements and attributes
 * This is intentionally not advertised as a complete XSLT 1.0 implementation.
 */
::class XmlTransformEngine public

::method transform class
  use arg inputDocument, stylesheetDocument, parameterArg = .nil
  parameters = .table~new
  if parameterArg \== .nil then do key over parameterArg~allIndexes
    parameters[key] = parameterArg[key]
  end

  xslUri = "http://www.w3.org/1999/XSL/Transform"
  stylesheetRoot = stylesheetDocument~root
  if stylesheetRoot == .nil then raise syntax 93.900 additional("XSLT stylesheet has no root element")
  if stylesheetRoot~namespaceUri \= xslUri then raise syntax 93.900 additional("Stylesheet root is not in the XSLT namespace")

  do child over stylesheetRoot~elementChildren
    if child~namespaceUri == xslUri & child~localName = "param" then do
      nameAttr = child~attribute("name")
      if nameAttr \== .nil then do
        key = nameAttr~value
        if parameters[key] == .nil then do
          selectAttr = child~attribute("select")
          if selectAttr \== .nil then parameters[key] = self~literalSelect(selectAttr~value)
          else parameters[key] = child~text
        end
      end
    end
  end

  template = .nil
  do child over stylesheetRoot~elementChildren
    if child~namespaceUri == xslUri & child~localName = "template" then do
      matchAttr = child~attribute("match")
      if matchAttr \== .nil then if matchAttr~value = "/" then template = child
    end
  end
  if template == .nil then raise syntax 93.900 additional("Native XSLT subset requires xsl:template match='/'")

  out = .XmlDocumentContext~emptyDerived("xslt-native:" || stylesheetDocument~source, inputDocument, stylesheetDocument~source, parameters)
  /* Remove the parser-created empty document state and build directly. */
  context = inputDocument~documentNode
  do child over template~children
    built = self~executeNode(out, inputDocument, child, context, parameters, .nil)
    if built \== .nil then do
      if built~isA(.Array) then do b over built
        out~documentNode~addChild(b)
        if out~root == .nil & b~kind = "ELEMENT" then out~setRoot(b)
      end
      else do
        out~documentNode~addChild(built)
        if out~root == .nil & built~kind = "ELEMENT" then out~setRoot(built)
      end
    end
  end
  return out

::method executeNode class private
  use arg outDoc, inputDoc, styleNode, contextNode, parameters, outputParent
  xslUri = "http://www.w3.org/1999/XSL/Transform"

  if styleNode~kind = "TEXT" | styleNode~kind = "CDATA" then do
    /* Ignore stylesheet indentation-only text, preserve intentional text. */
    if styleNode~text~strip = "" then return .nil
    n = outDoc~newNode("TEXT", "", "", "", "", styleNode~lexicalValue, styleNode~text, styleNode~span)
    n~addDerivedFrom(styleNode)
    return n
  end
  if styleNode~kind \= "ELEMENT" then return .nil

  if styleNode~namespaceUri == xslUri then do
    instruction = styleNode~localName
    select
      when instruction = "value-of" then do
        selectAttr = styleNode~attribute("select")
        if selectAttr == .nil then return .nil
        transformValue = self~evaluateSelectRich(inputDoc, selectAttr~value, contextNode, parameters)
        value = transformValue~value
        if value == .nil then value = ""
        n = outDoc~newNode("TEXT", "", "", "", "", value, value, styleNode~span)
        n~addDerivedFrom(styleNode)
        do sourceObject over transformValue~sources
          n~addDerivedFrom(sourceObject)
        end
        n~annotate("transformValue", transformValue)
        return n
      end
      when instruction = "text" then do
        value = styleNode~text
        n = outDoc~newNode("TEXT", "", "", "", "", value, value, styleNode~span)
        n~addDerivedFrom(styleNode)
        return n
      end
      when instruction = "for-each" then do
        selectAttr = styleNode~attribute("select")
        if selectAttr == .nil then return .nil
        selection = inputDoc~xpath(selectAttr~value, contextNode)
        result = .array~new
        if selection~kind = "NODESET" then do sourceNode over selection~nodes
          do child over styleNode~children
            built = self~executeNode(outDoc, inputDoc, child, sourceNode, parameters, .nil)
            self~appendBuilt(result, built)
          end
        end
        return result
      end
      when instruction = "if" then do
        testAttr = styleNode~attribute("test")
        if testAttr == .nil then return .nil
        truth = self~evaluateBoolean(inputDoc, testAttr~value, contextNode, parameters)
        if \truth then return .nil
        result = .array~new
        do child over styleNode~children
          built = self~executeNode(outDoc, inputDoc, child, contextNode, parameters, .nil)
          self~appendBuilt(result, built)
        end
        return result
      end
      when instruction = "param" | instruction = "output" then return .nil
      otherwise raise syntax 93.900 additional("Unsupported native XSLT instruction:" instruction)
    end
  end

  /* Literal result element. */
  outNode = outDoc~newNode("ELEMENT", styleNode~qName, styleNode~prefix, styleNode~localName, styleNode~namespaceUri, "", "", styleNode~span)
  outNode~namespaceBindings = styleNode~namespaceBindings~copy
  outNode~addDerivedFrom(styleNode)
  if contextNode \== .nil then outNode~addDerivedFrom(contextNode)
  do a over styleNode~attributeOrder
    if a~qName = "xmlns" | a~prefix = "xmlns" then iterate
    copyAttr = .XmlAttributeRef~new(outNode, a~qName, a~prefix, a~localName, a~namespaceUri, a~lexicalValue, a~value, a~span)
    outNode~addAttribute(copyAttr)
  end
  do child over styleNode~children
    built = self~executeNode(outDoc, inputDoc, child, contextNode, parameters, outNode)
    if built \== .nil then do
      if built~isA(.Array) then do b over built
        outNode~addChild(b)
      end
      else outNode~addChild(built)
    end
  end
  return outNode

::method evaluateSelect class private
  use arg inputDoc, expression, contextNode, parameters
  return self~evaluateSelectRich(inputDoc, expression, contextNode, parameters)~value

::method evaluateSelectRich class private
  use arg inputDoc, expression, contextNode, parameters
  expr = expression~strip
  compact = expr~space(0)~translate
  if pos("DOCUMENT(", compact) > 0 then raise syntax 93.900 additional("Native XSLT forbids external document() access")

  if expr~substr(1, 1) = "$" then do
    parameterName = expr~substr(2)
    value = parameters[parameterName]
    if value == .nil then value = ""
    return .XmlTransformValue~new(value, expr, .array~new, parameterName)
  end

  if expr~substr(1, 6)~caselessEquals("count(") & expr~substr(expr~length, 1) = ")" then do
    inner = expr~substr(7, expr~length - 7)
    selected = inputDoc~xpath(inner, contextNode)
    sources = .array~new
    if selected~kind = "NODESET" then do sourceObject over selected~nodes
      sources~append(sourceObject)
    end
    if selected~kind = "NODESET" then value = selected~nodes~items
    else value = 1
    return .XmlTransformValue~new(value, expr, sources)
  end

  selection = inputDoc~xpath(expr, contextNode)
  sources = .array~new
  if selection~kind = "NODESET" then do
    if selection~nodes~items = 0 then value = ""
    else do
      sourceObject = selection~nodes[1]
      sources~append(sourceObject)
      value = sourceObject~text
    end
  end
  else do
    value = selection~value
    if value == .nil then value = ""
  end
  return .XmlTransformValue~new(value, expr, sources)

::method evaluateBoolean class private
  use arg inputDoc, expression, contextNode, parameters
  expr = expression~strip
  compact = expr~space(0)~translate
  if pos("DOCUMENT(", compact) > 0 then raise syntax 93.900 additional("Native XSLT forbids external document() access")
  if expr~substr(1, 1) = "$" then do
    value = parameters[expr~substr(2)]
    if value == .nil then return .false
    if value~string = "" then return .false
    return .true
  end
  selection = inputDoc~xpath(expr, contextNode)
  if selection~kind = "NODESET" then return selection~nodes~items > 0
  if selection~value == .nil then return .false
  if selection~value == .false then return .false
  if selection~value~string = "" then return .false
  return .true

::method literalSelect class private
  use arg value
  v = value~strip
  if v~length >= 2 then do
    first = v~substr(1, 1)
    last = v~substr(v~length, 1)
    if (first = "'" & last = "'") | (first = '"' & last = '"') then return v~substr(2, v~length - 2)
  end
  return v

::method appendBuilt class private
  use arg array, built
  if built == .nil then return array
  if built~isA(.Array) then do b over built
    array~append(b)
  end
  else array~append(built)
  return array


::requires "RichSourceCore.cls"
