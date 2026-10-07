/* LdapFilter.cls
 * RFC 4515-oriented filter parser/evaluator for the LDAP conversation edge.
 *
 * dev10 adds extensibleMatch and routes qualified attribute comparisons through
 * ldap.matching/0.1.  Matching rules are LDAP personality semantics; they do
 * not become IdentityDirectory policy.
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
::attribute matchingRule get
::attribute dnAttributes get
::method init
  expose kind attributeName assertionValue children initial anyParts final matchingRule dnAttributes
  use strict arg kindArg, attributeNameArg = "", assertionValueArg = "", childrenArg = .nil, initialArg = .nil, anyPartsArg = .nil, finalArg = .nil, matchingRuleArg = "", dnAttributesArg = .false
  kind = kindArg~string~upper
  attributeName = attributeNameArg~string
  assertionValue = assertionValueArg~string
  children = .DirectoryCanonical~copyArray(childrenArg)
  initial = initialArg
  anyParts = .DirectoryCanonical~copyArray(anyPartsArg)
  final = finalArg
  matchingRule = matchingRuleArg~string
  dnAttributes = dnAttributesArg

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
        if pair = ">=" | pair = "<=" | pair = "~=" | pair = ":=" then do; opPos=i; op=pair; leave; end
      end
      if c = "=" then do; opPos=i; op="="; leave; end
    end
    i += 1
  end
  if opPos = 0 then raise syntax 88.900 array("LDAP filter assertion operator required")
  if op = ":=" then return self~parseExtensible(assertion, opPos)
  if opPos <= 1 then raise syntax 88.900 array("LDAP filter attribute required")
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
::method parseExtensible private
  use strict arg assertion, opPos
  lhs = assertion~left(opPos - 1)~strip
  raw = assertion~substr(opPos + 2)
  parts = self~splitColon(lhs)
  if parts~items = 0 then raise syntax 88.900 array("LDAP extensibleMatch assertion invalid")
  attr = parts[1]~strip
  if attr <> "" then do
    if \.LdapDn~validAttributeType(attr) then raise syntax 88.900 array("invalid LDAP extensibleMatch attribute")
  end
  dnFlag = .false
  rule = ""
  do i = 2 to parts~items
    token = parts[i]~strip
    if token = "" then raise syntax 88.900 array("empty LDAP extensibleMatch token")
    if token~caselessEquals("dn") then do
      if dnFlag then raise syntax 88.900 array("duplicate LDAP extensibleMatch dn flag")
      dnFlag = .true
    end
    else do
      if rule <> "" then raise syntax 88.900 array("multiple LDAP extensibleMatch rules")
      if \.LdapDn~validAttributeType(token) then raise syntax 88.900 array("invalid LDAP matching-rule id")
      rule = token
    end
  end
  if attr = "" & rule = "" then raise syntax 88.900 array("LDAP extensibleMatch requires attribute or matching rule")
  return .LdapFilterNode~new("EXTENSIBLE", attr, .LdapFilter~decodeAssertionValue(raw), .nil, .nil, .nil, .nil, rule, dnFlag)
::method splitColon private
  use strict arg text
  out = .array~new
  start = 1
  do i = 1 to text~length
    if text~substr(i,1) = ":" then do
      out~append(text~substr(start, i - start))
      start = i + 1
    end
  end
  out~append(text~substr(start))
  return out
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
::method validate class
  use strict arg node, matchingRegistry = .nil
  if matchingRegistry == .nil then matchingRegistry = .LdapMatchingRuleRegistry~new
  kind = node~kind
  if kind = "AND" | kind = "OR" | kind = "NOT" then do
    do child over node~children
      r = self~validate(child, matchingRegistry)
      if \r~ok then return r
    end
    return .DirectoryResult~success(.true)
  end
  if kind = "EXTENSIBLE" then do
    rule = node~matchingRule
    attr = node~attributeName
    if rule <> "" then do
      if \matchingRegistry~supportedRule(rule) then return .DirectoryResult~failure("LDAP_INAPPROPRIATE_MATCHING", rule)
      if attr <> "" then do
        if \matchingRegistry~ruleAppliesToAttribute(rule, attr) then return .DirectoryResult~failure("LDAP_INAPPROPRIATE_MATCHING", attr || ":" || rule)
      end
    end
    else do
      if attr = "" | matchingRegistry~equalityRuleFor(attr) = "" then return .DirectoryResult~failure("LDAP_INAPPROPRIATE_MATCHING", attr)
    end
  end
  return .DirectoryResult~success(.true)
::method matches class
  use strict arg filterText, ldapEntry, matchingRegistry = .nil
  parsed = self~parse(filterText)
  if \parsed~ok then return .false
  if matchingRegistry == .nil then matchingRegistry = .LdapMatchingRuleRegistry~new
  valid = self~validate(parsed~value, matchingRegistry)
  if \valid~ok then return .false
  return self~matchesNode(parsed~value, ldapEntry~attributes, ldapEntry~dn, matchingRegistry)
::method matchesNode class
  use strict arg node, attrs, dn = "", matchingRegistry = .nil
  if matchingRegistry == .nil then matchingRegistry = .LdapMatchingRuleRegistry~new
  kind = node~kind
  select
    when kind = "AND" then do
      do child over node~children
        if \self~matchesNode(child, attrs, dn, matchingRegistry) then return .false
      end
      return .true
    end
    when kind = "OR" then do
      do child over node~children
        if self~matchesNode(child, attrs, dn, matchingRegistry) then return .true
      end
      return .false
    end
    when kind = "NOT" then return \self~matchesNode(node~children[1], attrs, dn, matchingRegistry)
    when kind = "PRESENT" then return attrs~get(matchingRegistry~canonicalAttributeName(node~attributeName))~items > 0
    when kind = "EQUALITY" then do
      attrName = matchingRegistry~canonicalAttributeName(node~attributeName)
      rule = matchingRegistry~equalityRuleFor(attrName)
      do value over attrs~get(attrName)
        if rule = "" then do
          if value~string~caselessEquals(node~assertionValue) then return .true
        end
        else if matchingRegistry~equality(rule, value, node~assertionValue) then return .true
      end
      return .false
    end
    when kind = "GE" | kind = "LE" then do
      attrName = matchingRegistry~canonicalAttributeName(node~attributeName)
      rule = matchingRegistry~orderingRuleFor(attrName)
      expected = node~assertionValue~lower
      do value over attrs~get(attrName)
        if rule = "" then do
          if kind = "GE" & value~string~lower >= expected then return .true
          if kind = "LE" & value~string~lower <= expected then return .true
        end
        else do
          cmp = matchingRegistry~orderingCompare(rule, value, node~assertionValue)
          if cmp <> .nil then do
            if kind = "GE" & cmp >= 0 then return .true
            if kind = "LE" & cmp <= 0 then return .true
          end
        end
      end
      return .false
    end
    when kind = "APPROX" then do
      attrName = matchingRegistry~canonicalAttributeName(node~attributeName)
      do value over attrs~get(attrName)
        if matchingRegistry~approximate(value, node~assertionValue) then return .true
      end
      return .false
    end
    when kind = "SUBSTRING" then do
      attrName = matchingRegistry~canonicalAttributeName(node~attributeName)
      rule = matchingRegistry~substringRuleFor(attrName)
      do value over attrs~get(attrName)
        if rule = "" then do
          if self~substringMatches(value~string, node) then return .true
        end
        else if matchingRegistry~substringMatches(rule, value, node~initial, node~anyParts, node~final) then return .true
      end
      return .false
    end
    when kind = "EXTENSIBLE" then return self~extensibleMatches(node, attrs, dn, matchingRegistry)
    otherwise return .false
  end
::method extensibleMatches class private
  use strict arg node, attrs, dn, matchingRegistry
  names = .array~new
  if node~attributeName <> "" then names~append(matchingRegistry~canonicalAttributeName(node~attributeName))
  else do name over attrs~names; names~append(name); end
  do name over names
    if node~matchingRule <> "" then do
      if \matchingRegistry~ruleAppliesToAttribute(node~matchingRule, name) then iterate
      rule = matchingRegistry~ruleName(node~matchingRule)
    end
    else rule = matchingRegistry~equalityRuleFor(name)
    if rule = "" then iterate
    do value over attrs~get(name)
      if matchingRegistry~equality(rule, value, node~assertionValue) then return .true
    end
  end
  if \node~dnAttributes | dn = "" then return .false
  parsedDn = .LdapDn~parse(dn)
  if \parsedDn~ok then return .false
  do rdn over parsedDn~value~rdns
    do ava over rdn~avas
      name = matchingRegistry~canonicalAttributeName(ava~attributeType)
      if node~attributeName <> "" then if \name~caselessEquals(matchingRegistry~canonicalAttributeName(node~attributeName)) then iterate
      if node~matchingRule <> "" then do
        if \matchingRegistry~ruleAppliesToAttribute(node~matchingRule, name) then iterate
        rule = matchingRegistry~ruleName(node~matchingRule)
      end
      else rule = matchingRegistry~equalityRuleFor(name)
      if rule = "" then iterate
      if matchingRegistry~equality(rule, ava~value, node~assertionValue) then return .true
    end
  end
  return .false
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
  return .LdapMatchingRuleRegistry~new~approximate(value, "")
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
    when kind = "EXTENSIBLE" then do
      out = "(" || node~attributeName
      if node~dnAttributes then out ||= ":dn"
      if node~matchingRule <> "" then out ||= ":" || node~matchingRule
      return out || ":=" || self~escapeAssertionValue(node~assertionValue) || ")"
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

::requires "src/LdapMatchingRules.cls"
::requires "src/IdentityDirectory.cls"
