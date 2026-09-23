/* LdapFilter.cls
 * RFC 4515-oriented filter parser/evaluator for the LDAP conversation edge.
 *
 * Implemented filter choices:
 *   and, or, not, equalityMatch, substrings, greaterOrEqual, lessOrEqual,
 *   present and approxMatch.
 * ExtensibleMatch remains deliberately outside the dev9 claim because a full
 * matching-rule/schema engine is not yet authoritative.
 */

::class LdapFilterBuild public
::constant API_VERSION "ldap.filter/0.1"

::class LdapFilterNode public
::attribute kind get
::attribute attributeName get
::attribute assertionValue get
::attribute children get
::attribute initial get
::attribute anyParts get
::attribute final get
::method init
  expose kind attributeName assertionValue children initial anyParts final
  use strict arg kindArg, attributeNameArg = "", assertionValueArg = "", childrenArg = .nil, initialArg = .nil, anyPartsArg = .nil, finalArg = .nil
  kind = kindArg~string~upper
  attributeName = attributeNameArg~string
  assertionValue = assertionValueArg~string
  children = .DirectoryCanonical~copyArray(childrenArg)
  initial = initialArg
  anyParts = .DirectoryCanonical~copyArray(anyPartsArg)
  final = finalArg

::class LdapFilterParser public
::method init
  expose source position
  use strict arg sourceArg
  source = sourceArg~string
  position = 1
::method parse
  expose source position
  node = self~parseNode
  if position <= source~length then raise syntax 88.900 array("trailing LDAP filter text")
  return node
::method parseNode private
  expose source position
  if position > source~length | source~substr(position,1) <> "(" then raise syntax 88.900 array("LDAP filter requires (")
  position += 1
  if position > source~length then raise syntax 88.900 array("truncated LDAP filter")
  lead = source~substr(position,1)
  if lead = "&" | lead = "|" then do
    position += 1
    children = .array~new
    do while position <= source~length & source~substr(position,1) = "("
      children~append(self~parseNode)
    end
    if children~items = 0 then raise syntax 88.900 array("empty LDAP filter set")
    if position > source~length | source~substr(position,1) <> ")" then raise syntax 88.900 array("unterminated LDAP filter set")
    position += 1
    if lead = "&" then return .LdapFilterNode~new("AND", "", "", children)
    return .LdapFilterNode~new("OR", "", "", children)
  end
  if lead = "!" then do
    position += 1
    child = self~parseNode
    if position > source~length | source~substr(position,1) <> ")" then raise syntax 88.900 array("unterminated LDAP not filter")
    position += 1
    return .LdapFilterNode~new("NOT", "", "", .array~of(child))
  end
  assertion = self~readAssertion
  if position > source~length | source~substr(position,1) <> ")" then raise syntax 88.900 array("unterminated LDAP assertion")
  position += 1
  return self~parseAssertion(assertion)
::method readAssertion private
  expose source position
  start = position
  escaped = .false
  do while position <= source~length
    c = source~substr(position,1)
    if escaped then escaped = .false
    else if c = "\" then escaped = .true
    else if c = ")" then leave
    position += 1
  end
  if escaped then raise syntax 88.900 array("trailing LDAP filter escape")
  return source~substr(start, position - start)
::method parseAssertion private
  use strict arg assertion
  opPos = 0; op = ""
  escaped = .false
  i = 1
  do while i <= assertion~length
    c = assertion~substr(i,1)
    if escaped then escaped = .false
    else if c = "\" then escaped = .true
    else do
      if i + 1 <= assertion~length then do
        pair = assertion~substr(i,2)
        if pair = ">=" | pair = "<=" | pair = "~=" then do; opPos=i; op=pair; leave; end
        if pair = ":=" then raise syntax 88.900 array("LDAP extensibleMatch not implemented")
      end
      if c = "=" then do; opPos=i; op="="; leave; end
    end
    i += 1
  end
  if opPos <= 1 then raise syntax 88.900 array("LDAP filter assertion operator required")
  name = assertion~left(opPos - 1)~strip
  if name = "" then raise syntax 88.900 array("LDAP filter attribute required")
  raw = assertion~substr(opPos + op~length)
  if op = "=" then do
    stars = self~splitStars(raw)
    if stars["count"] = 1 & raw = "*" then return .LdapFilterNode~new("PRESENT", name)
    if stars["count"] > 0 then return self~substringNode(name, raw, stars)
    return .LdapFilterNode~new("EQUALITY", name, .LdapFilter~decodeAssertionValue(raw))
  end
  value = .LdapFilter~decodeAssertionValue(raw)
  if op = ">=" then return .LdapFilterNode~new("GE", name, value)
  if op = "<=" then return .LdapFilterNode~new("LE", name, value)
  return .LdapFilterNode~new("APPROX", name, value)
::method splitStars private
  use strict arg raw
  info = .directory~new
  parts = .array~new
  start = 1; count = 0; escaped = .false
  do i = 1 to raw~length
    c = raw~substr(i,1)
    if escaped then escaped = .false
    else if c = "\" then escaped = .true
    else if c = "*" then do
      parts~append(raw~substr(start, i - start))
      start = i + 1
      count += 1
    end
  end
  if escaped then raise syntax 88.900 array("trailing LDAP filter escape")
  parts~append(raw~substr(start))
  info["parts"] = parts
  info["count"] = count
  info["leading"] = raw~left(1) = "*"
  info["trailing"] = raw~right(1) = "*"
  return info
::method substringNode private
  use strict arg name, raw, stars
  parts = stars["parts"]
  initial = .nil; final = .nil; anys = .array~new
  firstIndex = 1; lastIndex = parts~items
  if \stars["leading"] then do
    initial = .LdapFilter~decodeAssertionValue(parts[1])
    firstIndex = 2
  end
  if \stars["trailing"] then do
    final = .LdapFilter~decodeAssertionValue(parts[parts~items])
    lastIndex = parts~items - 1
  end
  do i = firstIndex to lastIndex
    if parts[i] <> "" then anys~append(.LdapFilter~decodeAssertionValue(parts[i]))
  end
  return .LdapFilterNode~new("SUBSTRING", name, "", .nil, initial, anys, final)

::class LdapFilter public
::method parse class
  use strict arg filterText
  text = filterText~string~strip
  signal on syntax name invalid
  node = .LdapFilterParser~new(text)~parse
  signal off syntax
  return .DirectoryResult~success(node)
invalid:
  signal off syntax
  return .DirectoryResult~failure("LDAP_INVALID_FILTER", text)
::method matches class
  use strict arg filterText, ldapEntry
  parsed = self~parse(filterText)
  if \parsed~ok then return .false
  return self~matchesNode(parsed~value, ldapEntry~attributes)
::method matchesNode class
  use strict arg node, attrs
  kind = node~kind
  select
    when kind = "AND" then do
      do child over node~children
        if \self~matchesNode(child, attrs) then return .false
      end
      return .true
    end
    when kind = "OR" then do
      do child over node~children
        if self~matchesNode(child, attrs) then return .true
      end
      return .false
    end
    when kind = "NOT" then return \self~matchesNode(node~children[1], attrs)
    when kind = "PRESENT" then return attrs~get(node~attributeName)~items > 0
    when kind = "EQUALITY" then do
      do value over attrs~get(node~attributeName)
        if value~string~caselessEquals(node~assertionValue) then return .true
      end
      return .false
    end
    when kind = "GE" then do
      expected = node~assertionValue~lower
      do value over attrs~get(node~attributeName)
        if value~string~lower >= expected then return .true
      end
      return .false
    end
    when kind = "LE" then do
      expected = node~assertionValue~lower
      do value over attrs~get(node~attributeName)
        if value~string~lower <= expected then return .true
      end
      return .false
    end
    when kind = "APPROX" then do
      expected = self~approx(node~assertionValue)
      do value over attrs~get(node~attributeName)
        if self~approx(value) = expected then return .true
      end
      return .false
    end
    when kind = "SUBSTRING" then do
      do value over attrs~get(node~attributeName)
        if self~substringMatches(value~string, node) then return .true
      end
      return .false
    end
    otherwise return .false
  end
::method substringMatches class private
  use strict arg value, node
  hay = value~lower
  position = 1
  if node~initial <> .nil then do
    initial = node~initial~string~lower
    if hay~left(initial~length) <> initial then return .false
    position = initial~length + 1
  end
  do part over node~anyParts
    needle = part~string~lower
    rel = hay~substr(position)~pos(needle)
    if rel = 0 then return .false
    position += rel - 1 + needle~length
  end
  if node~final <> .nil then do
    final = node~final~string~lower
    if hay~right(final~length) <> final then return .false
    if hay~length - final~length + 1 < position then return .false
  end
  return .true
::method approx class private
  use strict arg value
  text = value~string~strip~lower
  out = ""; inSpace = .false
  do i = 1 to text~length
    c = text~substr(i,1)
    if c = " " | c = '09'x | c = '0a'x | c = '0d'x then do
      if \inSpace & out <> "" then out ||= " "
      inSpace = .true
    end
    else do
      out ||= c
      inSpace = .false
    end
  end
  return out~strip
::method decodeAssertionValue class
  use strict arg raw
  out = ""; i = 1
  do while i <= raw~length
    c = raw~substr(i,1)
    if c <> "\" then do; out ||= c; i += 1; iterate; end
    if i + 2 > raw~length then raise syntax 88.900 array("LDAP filter escape must be two hex digits")
    pair = raw~substr(i + 1,2)
    if \self~allHex(pair) then raise syntax 88.900 array("LDAP filter escape must be two hex digits")
    out ||= x2c(pair)
    i += 3
  end
  return out
::method escapeAssertionValue class
  use strict arg value
  value = value~string
  out = ""
  do i = 1 to value~length
    c = value~substr(i,1); n = c2d(c)
    if c = "*" | c = "(" | c = ")" | c = "\" | n = 0 | n < 32 | n >= 127 then out ||= "\" || d2x(n,2)~lower
    else out ||= c
  end
  return out
::method textFromNode class
  use strict arg node
  kind = node~kind
  select
    when kind = "AND" | kind = "OR" then do
      out = "("
      if kind = "AND" then out ||= "&"; else out ||= "|"
      do child over node~children; out ||= self~textFromNode(child); end
      return out || ")"
    end
    when kind = "NOT" then return "(!" || self~textFromNode(node~children[1]) || ")"
    when kind = "PRESENT" then return "(" || node~attributeName || "=*)"
    when kind = "EQUALITY" then return "(" || node~attributeName || "=" || self~escapeAssertionValue(node~assertionValue) || ")"
    when kind = "GE" then return "(" || node~attributeName || ">=" || self~escapeAssertionValue(node~assertionValue) || ")"
    when kind = "LE" then return "(" || node~attributeName || "<=" || self~escapeAssertionValue(node~assertionValue) || ")"
    when kind = "APPROX" then return "(" || node~attributeName || "~=" || self~escapeAssertionValue(node~assertionValue) || ")"
    when kind = "SUBSTRING" then do
      out = "(" || node~attributeName || "="
      if node~initial <> .nil then out ||= self~escapeAssertionValue(node~initial)
      out ||= "*"
      do part over node~anyParts; out ||= self~escapeAssertionValue(part) || "*"; end
      if node~final <> .nil then out ||= self~escapeAssertionValue(node~final)
      return out || ")"
    end
    otherwise return ""
  end
::method allHex class private
  use strict arg text
  if text = "" then return .false
  do i = 1 to text~length
    if "0123456789abcdefABCDEF"~pos(text~substr(i,1)) = 0 then return .false
  end
  return .true

::requires "src/IdentityDirectory.cls"
