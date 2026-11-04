/*
 * Semantic Source Control - lossless ooRexx structural source adapter.
 *
 * This is deliberately a source parser, not runtime introspection.  It turns a
 * .rex/.cls package source unit into independently addressable semantic source
 * objects while preserving an exact ordered projection back to the original
 * bytes.  No source file is treated as the semantic object merely because it
 * was the archive member used for intake.
 */

::class OorexxStructuralParseResult public
::method init
  self~sourceUnit = .directory~new
  self~objects = .array~new
  self~projectionMembers = .array~new
  self~relations = .array~new
::attribute sourceUnit
::attribute objects
::attribute projectionMembers
::attribute relations

::method reconstruct
  text = ""
  do member over self~projectionMembers
    text = text || member["prefix_text"] || member["source_text"] || member["suffix_text"]
  end
  return text

::class SemanticSourceOorexxStructuralAdapter public

::method adapterId
  return "oorexx-structural-v4"

::method parse
  use strict arg sourceText, projectionPath = "", moduleId = ""

  parsed = .OorexxStructuralParseResult~new
  sourceUnit = parsed~sourceUnit
  sourceUnit["language"] = "oorexx"
  sourceUnit["source_unit_kind"] = "PACKAGE_SOURCE"
  sourceUnit["projection_path"] = projectionPath
  sourceUnit["module_id"] = moduleId
  sourceUnit["adapter_id"] = self~adapterId
  sourceUnit["lossless"] = 1

  lines = self~lineSpans(sourceText)
  directiveLines = .array~new
  do i = 1 to lines~items
    span = lines[i]
    trimmed = strip(span["content"])
    if left(trimmed, 2) == "::" then directiveLines~append(i)
  end

  ordinal = 0
  currentClass = ""

  if directiveLines~items = 0 then do
    if sourceText \= "" then do
      object = self~makeObject("EXECUTABLE_SECTION", "<executable>", "PACKAGE:" || projectionPath || "/EXECUTABLE", "", sourceText, projectionPath)
      parsed~objects~append(object)
      ordinal += 1
      parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
      sourceUnit["executable_object_key"] = object["semantic_key"]
    end
    return parsed
  end

  firstSpan = lines[directiveLines[1]]
  if firstSpan["start"] > 1 then do
    executable = sourceText~substr(1, firstSpan["start"] - 1)
    if executable \= "" then do
      object = self~makeObject("EXECUTABLE_SECTION", "<executable>", "PACKAGE:" || projectionPath || "/EXECUTABLE", "", executable, projectionPath)
      parsed~objects~append(object)
      ordinal += 1
      parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
      sourceUnit["executable_object_key"] = object["semantic_key"]
    end
  end

  do d = 1 to directiveLines~items
    lineIndex = directiveLines[d]
    span = lines[lineIndex]
    startPos = span["start"]
    if d < directiveLines~items then do
      nextSpan = lines[directiveLines[d + 1]]
      endPos = nextSpan["start"] - 1
    end
    else endPos = sourceText~length

    segment = sourceText~substr(startPos, endPos - startPos + 1)
    header = strip(span["content"])
    parse var header "::" directive rest
    directive = translate(strip(directive))
    rest = strip(rest)

    select
      when directive = "CLASS" then do
        name = self~firstToken(rest)
        keyName = translate(name)
        semanticKey = "PACKAGE:" || projectionPath || "/CLASS:" || keyName
        object = self~makeObject("CLASS", name, semanticKey, "", segment, projectionPath)
        object["class_tree"] = self~classTree(rest)
        parsed~objects~append(object)
        ordinal += 1
        parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
        self~classRelations(parsed, object, rest)
        currentClass = name
      end
      when directive = "METHOD" then do
        name = self~firstToken(rest)
        side = "INSTANCE"
        if self~hasWord(rest, "CLASS") then side = "CLASS"
        owner = currentClass
        if owner = "" then owner = "<package>"
        semanticKey = self~ownedKey(projectionPath, owner, "METHOD", name) || "#" || side
        object = self~makeObject("METHOD", name, semanticKey, owner, segment, projectionPath)
        object["method_side"] = side
        object["exposes"] = self~exposedNames(segment)
        object["return_expression"] = self~returnExpression(segment)
        parsed~objects~append(object)
        ordinal += 1
        parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
      end
      when directive = "ATTRIBUTE" then do
        name = self~firstToken(rest)
        kind = "ATTRIBUTE"
        if self~hasWord(rest, "GET") then kind = "ATTRIBUTE_GETTER"
        if self~hasWord(rest, "SET") then kind = "ATTRIBUTE_SETTER"
        owner = currentClass
        if owner = "" then owner = "<package>"
        semanticKey = self~ownedKey(projectionPath, owner, kind, name)
        object = self~makeObject(kind, name, semanticKey, owner, segment, projectionPath)
        object["has_get"] = self~hasWord(rest, "GET") | \self~hasWord(rest, "SET")
        object["has_set"] = self~hasWord(rest, "SET") | \self~hasWord(rest, "GET")
        parsed~objects~append(object)
        ordinal += 1
        parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
      end
      when directive = "CONSTANT" then do
        name = self~firstToken(rest)
        owner = currentClass
        if owner = "" then owner = "<package>"
        semanticKey = self~ownedKey(projectionPath, owner, "CONSTANT", name)
        object = self~makeObject("CONSTANT", name, semanticKey, owner, segment, projectionPath)
        parsed~objects~append(object)
        ordinal += 1
        parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
      end
      when directive = "ROUTINE" then do
        name = self~firstToken(rest)
        semanticKey = "PACKAGE:" || projectionPath || "/ROUTINE:" || translate(name)
        object = self~makeObject("ROUTINE", name, semanticKey, "<package>", segment, projectionPath)
        parsed~objects~append(object)
        ordinal += 1
        parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
      end
      when directive = "REQUIRES" then do
        name = self~firstToken(rest)
        semanticKey = "PACKAGE:" || projectionPath || "/REQUIRES:" || translate(name)
        object = self~makeObject("REQUIRES", name, semanticKey, "<package>", segment, projectionPath)
        parsed~objects~append(object)
        ordinal += 1
        parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
        relation = .directory~new
        relation["from_object_key"] = "PACKAGE:" || projectionPath
        relation["relation_kind"] = "REQUIRES"
        relation["to_symbol"] = name
        relation["detail"] = rest
        parsed~relations~append(relation)
      end
      when directive = "RESOURCE" then do
        name = self~firstToken(rest)
        semanticKey = "PACKAGE:" || projectionPath || "/RESOURCE:" || translate(name)
        object = self~makeObject("RESOURCE", name, semanticKey, "<package>", segment, projectionPath)
        parsed~objects~append(object)
        ordinal += 1
        parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
      end
      when directive = "OPTIONS" then do
        semanticKey = "PACKAGE:" || projectionPath || "/OPTIONS:" || ordinal + 1
        object = self~makeObject("OPTIONS", "::OPTIONS", semanticKey, "<package>", segment, projectionPath)
        parsed~objects~append(object)
        ordinal += 1
        parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
      end
      otherwise do
        -- Unknown directives are still first-class projection fragments.  They
        -- must survive exact reconstruction even before a semantic adapter knows
        -- their meaning.
        name = "::" || directive
        semanticKey = "PACKAGE:" || projectionPath || "/DIRECTIVE:" || directive || ":" || ordinal + 1
        object = self~makeObject("PROJECTION_FRAGMENT", name, semanticKey, currentClass, segment, projectionPath)
        object["directive_name"] = directive
        parsed~objects~append(object)
        ordinal += 1
        parsed~projectionMembers~append(self~projectionMember(object, ordinal, projectionPath))
      end
    end
  end

  return parsed

::method makeObject private
  use strict arg kind, sourceSpelling, semanticKey, owner, sourceText, projectionPath
  object = .directory~new
  object["object_kind"] = kind
  object["logical_name"] = sourceSpelling
  object["source_spelling"] = sourceSpelling
  object["runtime_spelling"] = sourceSpelling
  object["lookup_key"] = translate(sourceSpelling)
  object["semantic_key"] = semanticKey
  object["semantic_owner"] = owner
  object["projection_path"] = projectionPath
  object["source_text"] = sourceText
  return object

::method projectionMember private
  use strict arg object, ordinal, path
  member = .directory~new
  member["object_key"] = object["semantic_key"]
  member["relative_path"] = path
  member["ordinal"] = ordinal
  member["prefix_text"] = ""
  member["source_text"] = object["source_text"]
  member["suffix_text"] = ""
  return member

::method ownedKey private
  use strict arg path, owner, kind, name
  return "PACKAGE:" || path || "/CLASS:" || translate(owner) || "/" || kind || ":" || translate(name)

::method firstToken private
  use strict arg text
  text = strip(text)
  if text = "" then return ""
  first = text~word(1)
  if left(first, 1) = '"' & right(first, 1) = '"' & first~length >= 2 then return first~substr(2, first~length - 2)
  return first

::method hasWord private
  use strict arg text, wanted
  return text~wordpos(translate(wanted)) > 0 | translate(text)~wordpos(translate(wanted)) > 0

::method classTree private
  use strict arg rest
  tree = .array~new
  words = rest~makeArray(" ")
  upper = translate(rest)
  tokens = upper~space
  -- Preserve declared order after SUBCLASS / INHERIT keywords.
  pos = tokens~wordpos("SUBCLASS")
  if pos > 0 & pos < tokens~words then tree~append(rest~word(pos + 1))
  pos = tokens~wordpos("INHERIT")
  if pos > 0 then do i = pos + 1 to rest~words
    word = rest~word(i)
    uw = translate(word)
    if uw = "PUBLIC" | uw = "PRIVATE" | uw = "MIXINCLASS" then leave
    tree~append(word)
  end
  return tree

::method classRelations private
  use strict arg parsed, object, rest
  tree = object["class_tree"]
  do parent over tree
    relation = .directory~new
    relation["from_object_key"] = object["semantic_key"]
    relation["relation_kind"] = "INHERITS"
    relation["to_symbol"] = parent
    relation["detail"] = "declared class ancestry"
    parsed~relations~append(relation)
  end
  return

::method exposedNames private
  use strict arg segment
  names = .array~new
  spans = self~lineSpans(segment)
  do span over spans
    line = strip(span["content"])
    upper = translate(line)
    p = upper~wordpos("EXPOSE")
    if p = 1 then do i = 2 to line~words
      name = line~word(i)
      if name \= "" then names~append(name)
    end
  end
  return names

::method returnExpression private
  use strict arg segment
  spans = self~lineSpans(segment)
  expression = ""
  do span over spans
    line = strip(span["content"])
    upper = translate(line)
    if upper~word(1) = "RETURN" then do
      if line~words > 1 then expression = line~subword(2)
      else expression = ""
    end
  end
  return expression

/* Return line spans while preserving CRLF/LF/CR bytes in the span range. */
::method lineSpans private
  use strict arg source
  spans = .array~new
  length = source~length
  if length = 0 then return spans
  start = 1
  i = 1
  do while i <= length
    c = source~substr(i, 1)
    if c = '0d'x | c = '0a'x then do
      contentEnd = i - 1
      endPos = i
      if c = '0d'x & i < length then do
        if source~substr(i + 1, 1) = '0a'x then do
          endPos = i + 1
          i += 1
        end
      end
      span = .directory~new
      span["start"] = start
      span["end"] = endPos
      if contentEnd >= start then span["content"] = source~substr(start, contentEnd - start + 1)
      else span["content"] = ""
      spans~append(span)
      start = endPos + 1
    end
    i += 1
  end
  if start <= length then do
    span = .directory~new
    span["start"] = start
    span["end"] = length
    span["content"] = source~substr(start)
    spans~append(span)
  end
  return spans
