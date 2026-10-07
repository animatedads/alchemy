/* LdapMatchingRules.cls
 * Native LDAP matching-rule registry for the LDAP conversation personality.
 *
 * The registry owns LDAP comparison semantics only.  Identity/resource truth
 * remains in IdentityDirectory and vendor personalities remain edge filters.
 * Rules are deliberately explicit and bounded to the native schema published
 * by LdapSchemaRegistry; unknown rule/attribute combinations fail closed.
 */

::class LdapMatchingBuild public
::constant API_VERSION "ldap.matching/0.1"
::constant DN_COMPARISON_PROFILE "oorexx-ldap-schema-matching/0.1"
::constant CASE_IGNORE_MATCH "caseIgnoreMatch"
::constant CASE_IGNORE_ORDERING_MATCH "caseIgnoreOrderingMatch"
::constant CASE_IGNORE_SUBSTRINGS_MATCH "caseIgnoreSubstringsMatch"
::constant CASE_EXACT_MATCH "caseExactMatch"
::constant CASE_EXACT_ORDERING_MATCH "caseExactOrderingMatch"
::constant CASE_EXACT_SUBSTRINGS_MATCH "caseExactSubstringsMatch"
::constant DISTINGUISHED_NAME_MATCH "distinguishedNameMatch"
::constant OBJECT_IDENTIFIER_MATCH "objectIdentifierMatch"
::constant UUID_MATCH "uuidMatch"
::constant UUID_ORDERING_MATCH "uuidOrderingMatch"
::constant INTEGER_MATCH "integerMatch"
::constant INTEGER_ORDERING_MATCH "integerOrderingMatch"

::class LdapMatchingRuleRegistry public
::method ruleName
  use strict arg rule
  text = rule~string~strip
  key = text~lower
  select
    when key = "caseignorematch" | key = "2.5.13.2" then return .LdapMatchingBuild~CASE_IGNORE_MATCH
    when key = "caseignoreorderingmatch" | key = "2.5.13.3" then return .LdapMatchingBuild~CASE_IGNORE_ORDERING_MATCH
    when key = "caseignoresubstringsmatch" | key = "2.5.13.4" then return .LdapMatchingBuild~CASE_IGNORE_SUBSTRINGS_MATCH
    when key = "caseexactmatch" | key = "2.5.13.5" then return .LdapMatchingBuild~CASE_EXACT_MATCH
    when key = "caseexactorderingmatch" | key = "2.5.13.6" then return .LdapMatchingBuild~CASE_EXACT_ORDERING_MATCH
    when key = "caseexactsubstringsmatch" | key = "2.5.13.7" then return .LdapMatchingBuild~CASE_EXACT_SUBSTRINGS_MATCH
    when key = "objectidentifiermatch" | key = "2.5.13.0" then return .LdapMatchingBuild~OBJECT_IDENTIFIER_MATCH
    when key = "distinguishednamematch" | key = "2.5.13.1" then return .LdapMatchingBuild~DISTINGUISHED_NAME_MATCH
    when key = "integermatch" | key = "2.5.13.14" then return .LdapMatchingBuild~INTEGER_MATCH
    when key = "integerorderingmatch" | key = "2.5.13.15" then return .LdapMatchingBuild~INTEGER_ORDERING_MATCH
    when key = "uuidmatch" | key = "1.3.6.1.1.16.2" then return .LdapMatchingBuild~UUID_MATCH
    when key = "uuidorderingmatch" | key = "1.3.6.1.1.16.3" then return .LdapMatchingBuild~UUID_ORDERING_MATCH
    otherwise return ""
  end
::method supportedRule
  use strict arg rule
  return self~ruleName(rule) <> ""
::method canonicalObjectClass
  use strict arg value
  oid = self~objectIdentifier(value)
  select
    when oid = "2.5.6.0" then return "top"
    when oid = "2.5.6.9" then return "groupOfNames"
    when oid = "2.5.20.1" then return "subschema"
    when oid = "1.3.6.1.4.1.32473.999.2.1" then return "oorexxPrincipal"
    when oid = "1.3.6.1.4.1.32473.999.2.2" then return "oorexxResource"
    when oid = "1.3.6.1.4.1.32473.999.2.3" then return "oorexxCredential"
    when oid = "1.3.6.1.4.1.32473.999.2.4" then return "oorexxKeySet"
    when oid = "1.3.6.1.4.1.32473.999.2.5" then return "oorexxKeyGeneration"
    when oid = "1.3.6.1.4.1.32473.999.2.6" then return "oorexxAclGrant"
    when oid = "1.3.6.1.4.1.32473.999.2.7" then return "oorexxGroup"
    when oid = "1.3.6.1.4.1.32473.999.2.8" then return "oorexxEntity"
    otherwise return ""
  end
::method findEntity
  use strict arg directory, dn
  do entity over directory~allEntries
    if self~distinguishedNameEquivalent(entity~dn, dn) then return entity
  end
  return .nil
::method canonicalAttributeName
  use strict arg attributeName
  key = attributeName~string~strip~lower
  select
    when key = "2.5.4.0" then return "objectclass"
    when key = "2.5.4.3" then return "cn"
    when key = "2.5.4.10" then return "o"
    when key = "2.5.4.11" then return "ou"
    when key = "2.5.4.13" then return "description"
    when key = "2.5.4.31" then return "member"
    when key = "0.9.2342.19200300.100.1.1" then return "uid"
    when key = "0.9.2342.19200300.100.1.25" then return "dc"
    when key = "1.3.6.1.1.16.4" then return "entryuuid"
    when key = "1.3.6.1.4.1.32473.999.1.1" then return "oorexxentityid"
    when key = "1.3.6.1.4.1.32473.999.1.2" then return "oorexxentrykind"
    when key = "1.3.6.1.4.1.32473.999.1.3" then return "oorexxentrystate"
    when key = "1.3.6.1.4.1.32473.999.1.4" then return "oorexxrevision"
    when key = "1.3.6.1.4.1.32473.999.1.5" then return "oorexxcreatedat"
    when key = "1.3.6.1.4.1.32473.999.1.6" then return "oorexxupdatedat"
    when key = "1.3.6.1.4.1.32473.999.1.7" then return "oorexxprincipaltype"
    when key = "1.3.6.1.4.1.32473.999.1.8" then return "oorexxresourcetype"
    when key = "1.3.6.1.4.1.32473.999.1.9" then return "oorexxresourceref"
    when key = "1.3.6.1.4.1.32473.999.1.10" then return "oorexxownerid"
    when key = "1.3.6.1.4.1.32473.999.1.11" then return "oorexxcredentialtype"
    when key = "1.3.6.1.4.1.32473.999.1.12" then return "oorexxsecretref"
    when key = "1.3.6.1.4.1.32473.999.1.13" then return "oorexxnotbefore"
    when key = "1.3.6.1.4.1.32473.999.1.14" then return "oorexxnotafter"
    when key = "1.3.6.1.4.1.32473.999.1.15" then return "oorexxkeyusage"
    when key = "1.3.6.1.4.1.32473.999.1.16" then return "oorexxactivekeygeneration"
    when key = "1.3.6.1.4.1.32473.999.1.17" then return "oorexxkeysetid"
    when key = "1.3.6.1.4.1.32473.999.1.18" then return "oorexxkeygeneration"
    when key = "1.3.6.1.4.1.32473.999.1.19" then return "oorexxkeyalgorithm"
    when key = "1.3.6.1.4.1.32473.999.1.20" then return "oorexxpublickey"
    when key = "1.3.6.1.4.1.32473.999.1.21" then return "oorexxrotateat"
    when key = "1.3.6.1.4.1.32473.999.1.22" then return "oorexxrevocationreason"
    when key = "1.3.6.1.4.1.32473.999.1.23" then return "oorexxaclsubject"
    when key = "1.3.6.1.4.1.32473.999.1.24" then return "oorexxaclresource"
    when key = "1.3.6.1.4.1.32473.999.1.25" then return "oorexxaclaction"
    when key = "1.3.6.1.4.1.32473.999.1.26" then return "oorexxacleffect"
    otherwise return key
  end
::method attributeProfile
  use strict arg attributeName
  name = self~canonicalAttributeName(attributeName)
  p = .directory~new
  p["known"] = .true
  p["equality"] = .LdapMatchingBuild~CASE_IGNORE_MATCH
  p["ordering"] = .LdapMatchingBuild~CASE_IGNORE_ORDERING_MATCH
  p["substr"] = .LdapMatchingBuild~CASE_IGNORE_SUBSTRINGS_MATCH
  p["syntax"] = "1.3.6.1.4.1.1466.115.121.1.15"
  select
    when name = "objectclass" then do
      p["equality"] = .LdapMatchingBuild~OBJECT_IDENTIFIER_MATCH
      p["ordering"] = ""; p["substr"] = ""
      p["syntax"] = "1.3.6.1.4.1.1466.115.121.1.38"
    end
    when name = "member" then do
      p["equality"] = .LdapMatchingBuild~DISTINGUISHED_NAME_MATCH
      p["ordering"] = ""; p["substr"] = ""
      p["syntax"] = "1.3.6.1.4.1.1466.115.121.1.12"
    end
    when name = "entryuuid" then do
      p["equality"] = .LdapMatchingBuild~UUID_MATCH
      p["ordering"] = .LdapMatchingBuild~UUID_ORDERING_MATCH
      p["substr"] = ""
      p["syntax"] = "1.3.6.1.1.16.1"
    end
    when name = "oorexxrevision" | name = "oorexxkeygeneration" then do
      p["equality"] = .LdapMatchingBuild~INTEGER_MATCH
      p["ordering"] = .LdapMatchingBuild~INTEGER_ORDERING_MATCH
      p["substr"] = ""
      p["syntax"] = "1.3.6.1.4.1.1466.115.121.1.27"
    end
    when name = "cn" | name = "uid" | name = "description" | name = "dc" | name = "ou" | name = "o" then nop
    when name = "oorexxentityid" | name = "oorexxentrykind" | name = "oorexxentrystate" | name = "oorexxcreatedat" | name = "oorexxupdatedat" | name = "oorexxprincipaltype" | name = "oorexxresourcetype" | name = "oorexxresourceref" | name = "oorexxownerid" | name = "oorexxcredentialtype" | name = "oorexxsecretref" | name = "oorexxnotbefore" | name = "oorexxnotafter" | name = "oorexxkeyusage" | name = "oorexxactivekeygeneration" | name = "oorexxkeysetid" | name = "oorexxkeyalgorithm" | name = "oorexxpublickey" | name = "oorexxrotateat" | name = "oorexxrevocationreason" | name = "oorexxaclsubject" | name = "oorexxaclresource" | name = "oorexxaclaction" | name = "oorexxacleffect" then nop
    otherwise do
      p["known"] = .false
      p["equality"] = ""; p["ordering"] = ""; p["substr"] = ""; p["syntax"] = ""
    end
  end
  return p
::method equalityRuleFor
  use strict arg attributeName
  return self~attributeProfile(attributeName)["equality"]
::method orderingRuleFor
  use strict arg attributeName
  return self~attributeProfile(attributeName)["ordering"]
::method substringRuleFor
  use strict arg attributeName
  return self~attributeProfile(attributeName)["substr"]
::method ruleKind
  use strict arg rule
  canonical = self~ruleName(rule)
  select
    when canonical = .LdapMatchingBuild~CASE_IGNORE_MATCH | canonical = .LdapMatchingBuild~CASE_EXACT_MATCH | canonical = .LdapMatchingBuild~OBJECT_IDENTIFIER_MATCH | canonical = .LdapMatchingBuild~DISTINGUISHED_NAME_MATCH | canonical = .LdapMatchingBuild~UUID_MATCH | canonical = .LdapMatchingBuild~INTEGER_MATCH then return "EQUALITY"
    when canonical = .LdapMatchingBuild~CASE_IGNORE_ORDERING_MATCH | canonical = .LdapMatchingBuild~CASE_EXACT_ORDERING_MATCH | canonical = .LdapMatchingBuild~UUID_ORDERING_MATCH | canonical = .LdapMatchingBuild~INTEGER_ORDERING_MATCH then return "ORDERING"
    when canonical = .LdapMatchingBuild~CASE_IGNORE_SUBSTRINGS_MATCH | canonical = .LdapMatchingBuild~CASE_EXACT_SUBSTRINGS_MATCH then return "SUBSTRING"
    otherwise return ""
  end
::method ruleSyntax
  use strict arg rule
  canonical = self~ruleName(rule)
  select
    when canonical = .LdapMatchingBuild~OBJECT_IDENTIFIER_MATCH then return "1.3.6.1.4.1.1466.115.121.1.38"
    when canonical = .LdapMatchingBuild~DISTINGUISHED_NAME_MATCH then return "1.3.6.1.4.1.1466.115.121.1.12"
    when canonical = .LdapMatchingBuild~UUID_MATCH | canonical = .LdapMatchingBuild~UUID_ORDERING_MATCH then return "1.3.6.1.1.16.1"
    when canonical = .LdapMatchingBuild~INTEGER_MATCH | canonical = .LdapMatchingBuild~INTEGER_ORDERING_MATCH then return "1.3.6.1.4.1.1466.115.121.1.27"
    when canonical = .LdapMatchingBuild~CASE_IGNORE_MATCH | canonical = .LdapMatchingBuild~CASE_IGNORE_ORDERING_MATCH | canonical = .LdapMatchingBuild~CASE_IGNORE_SUBSTRINGS_MATCH | canonical = .LdapMatchingBuild~CASE_EXACT_MATCH | canonical = .LdapMatchingBuild~CASE_EXACT_ORDERING_MATCH | canonical = .LdapMatchingBuild~CASE_EXACT_SUBSTRINGS_MATCH then return "1.3.6.1.4.1.1466.115.121.1.15"
    otherwise return ""
  end
::method ruleAppliesToAttribute
  use strict arg rule, attributeName
  canonical = self~ruleName(rule)
  if canonical = "" then return .false
  /* ExtensibleMatch is a boolean match assertion.  Do not silently accept an
   * ordering or substring rule and then treat it as equality. */
  if self~ruleKind(canonical) <> "EQUALITY" then return .false
  p = self~attributeProfile(attributeName)
  if \p["known"] then return .false
  return self~ruleSyntax(canonical) = p["syntax"]
::method equality
  use strict arg rule, candidate, assertion
  canonical = self~ruleName(rule)
  select
    when canonical = .LdapMatchingBuild~CASE_IGNORE_MATCH then return self~caseIgnore(candidate) = self~caseIgnore(assertion)
    when canonical = .LdapMatchingBuild~CASE_EXACT_MATCH then return self~caseExact(candidate) = self~caseExact(assertion)
    when canonical = .LdapMatchingBuild~OBJECT_IDENTIFIER_MATCH then return self~objectIdentifier(candidate) = self~objectIdentifier(assertion)
    when canonical = .LdapMatchingBuild~DISTINGUISHED_NAME_MATCH then return self~distinguishedNameEquivalent(candidate, assertion)
    when canonical = .LdapMatchingBuild~UUID_MATCH then do
      left = self~uuid(candidate); right = self~uuid(assertion)
      if left = "" | right = "" then return .false
      return left = right
    end
    when canonical = .LdapMatchingBuild~INTEGER_MATCH then do
      left = self~integer(candidate); right = self~integer(assertion)
      if left == .nil | right == .nil then return .false
      return left = right
    end
    otherwise return .false
  end
::method orderingCompare
  use strict arg rule, candidate, assertion
  canonical = self~ruleName(rule)
  select
    when canonical = .LdapMatchingBuild~CASE_IGNORE_ORDERING_MATCH then do
      left = self~caseIgnore(candidate); right = self~caseIgnore(assertion)
    end
    when canonical = .LdapMatchingBuild~CASE_EXACT_ORDERING_MATCH then do
      left = self~caseExact(candidate); right = self~caseExact(assertion)
    end
    when canonical = .LdapMatchingBuild~UUID_ORDERING_MATCH then do
      left = self~uuid(candidate); right = self~uuid(assertion)
      if left = "" | right = "" then return .nil
    end
    when canonical = .LdapMatchingBuild~INTEGER_ORDERING_MATCH then do
      left = self~integer(candidate); right = self~integer(assertion)
      if left == .nil | right == .nil then return .nil
      if left < right then return -1
      if left > right then return 1
      return 0
    end
    otherwise return .nil
  end
  if left < right then return -1
  if left > right then return 1
  return 0
::method substringMatches
  use strict arg rule, candidate, initial = .nil, anyParts = .nil, final = .nil
  canonical = self~ruleName(rule)
  if canonical = .LdapMatchingBuild~CASE_IGNORE_SUBSTRINGS_MATCH then do
    hay = self~caseIgnore(candidate)
    return self~substringNormalized(hay, initial, anyParts, final, .true)
  end
  if canonical = .LdapMatchingBuild~CASE_EXACT_SUBSTRINGS_MATCH then do
    hay = self~caseExact(candidate)
    return self~substringNormalized(hay, initial, anyParts, final, .false)
  end
  return .false
::method substringNormalized private
  use strict arg hay, initial, anyParts, final, foldCase
  position = 1
  if initial <> .nil then do
    if foldCase then needle = self~caseIgnore(initial); else needle = self~caseExact(initial)
    if hay~left(needle~length) <> needle then return .false
    position = needle~length + 1
  end
  parts = .DirectoryCanonical~copyArray(anyParts)
  do part over parts
    if foldCase then needle = self~caseIgnore(part); else needle = self~caseExact(part)
    rel = hay~substr(position)~pos(needle)
    if rel = 0 then return .false
    position += rel - 1 + needle~length
  end
  if final <> .nil then do
    if foldCase then needle = self~caseIgnore(final); else needle = self~caseExact(final)
    if hay~right(needle~length) <> needle then return .false
    if hay~length - needle~length + 1 < position then return .false
  end
  return .true
::method approximate
  use strict arg candidate, assertion
  return self~caseIgnore(candidate) = self~caseIgnore(assertion)
::method caseIgnore private
  use strict arg value
  return self~collapseSpaces(value~string~strip)~lower
::method caseExact private
  use strict arg value
  return self~collapseSpaces(value~string~strip)
::method collapseSpaces private
  use strict arg value
  out = ""; inSpace = .false
  do i = 1 to value~length
    c = value~substr(i,1)
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
::method objectIdentifier private
  use strict arg value
  key = value~string~strip~lower
  select
    when key = "top" then return "2.5.6.0"
    when key = "groupofnames" then return "2.5.6.9"
    when key = "subschema" then return "2.5.20.1"
    when key = "oorexxprincipal" then return "1.3.6.1.4.1.32473.999.2.1"
    when key = "oorexxresource" then return "1.3.6.1.4.1.32473.999.2.2"
    when key = "oorexxcredential" then return "1.3.6.1.4.1.32473.999.2.3"
    when key = "oorexxkeyset" then return "1.3.6.1.4.1.32473.999.2.4"
    when key = "oorexxkeygeneration" then return "1.3.6.1.4.1.32473.999.2.5"
    when key = "oorexxaclgrant" then return "1.3.6.1.4.1.32473.999.2.6"
    when key = "oorexxgroup" then return "1.3.6.1.4.1.32473.999.2.7"
    when key = "oorexxentity" then return "1.3.6.1.4.1.32473.999.2.8"
    otherwise return key
  end
::method uuid private
  use strict arg value
  text = value~string~strip~lower
  if text~length <> 36 then return ""
  if text~substr(9,1) <> "-" | text~substr(14,1) <> "-" | text~substr(19,1) <> "-" | text~substr(24,1) <> "-" then return ""
  hex = text~changestr("-", "")
  if hex~length <> 32 | \self~allHex(hex) then return ""
  return text
::method integer private
  use strict arg value
  text = value~string~strip
  if text = "" then return .nil
  sign = ""
  if text~left(1) = "-" | text~left(1) = "+" then do
    sign = text~left(1)
    text = text~substr(2)
  end
  if text = "" | text~verify("0123456789") <> 0 then return .nil
  do while text~length > 1 & text~left(1) = "0"
    text = text~substr(2)
  end
  if text = "0" then sign = ""
  if sign = "-" then return -text
  return text + 0
::method distinguishedNameEquivalent
  use strict arg left, right
  lp = .LdapDn~parse(left)
  rp = .LdapDn~parse(right)
  if \lp~ok | \rp~ok then return .false
  l = lp~value; r = rp~value
  if l~depth <> r~depth then return .false
  do i = 1 to l~depth
    if self~rdnKey(l~rdns[i]) <> self~rdnKey(r~rdns[i]) then return .false
  end
  return .true
::method dnInScope
  use strict arg entryDn, baseDn, scope
  ep = .LdapDn~parse(entryDn)
  bp = .LdapDn~parse(baseDn)
  if \ep~ok | \bp~ok then return .false
  e = ep~value; b = bp~value
  s = scope~string~upper
  if s = "BASE" then return self~distinguishedNameEquivalent(entryDn, baseDn)
  if s <> "ONE" & s <> "SUB" then return .false
  if e~depth < b~depth then return .false
  delta = e~depth - b~depth
  do i = 1 to b~depth
    if self~rdnKey(e~rdns[i + delta]) <> self~rdnKey(b~rdns[i]) then return .false
  end
  if s = "ONE" then return delta = 1
  return .true
::method rdnKey private
  use strict arg rdn
  keys = .array~new
  do ava over rdn~avas
    attr = self~canonicalAttributeName(ava~attributeType)
    if ava~hexString then normalized = "#" || c2x(ava~value)~lower
    else do
      rule = self~equalityRuleFor(attr)
      if rule = "" then rule = .LdapMatchingBuild~CASE_IGNORE_MATCH
      normalized = self~normalizeForEquality(rule, ava~value)
    end
    keys~append(attr || "=" || normalized)
  end
  keys = .DirectoryCanonical~sortedStrings(keys)
  out = ""
  do i = 1 to keys~items
    if i > 1 then out ||= "+"
    out ||= keys[i]
  end
  return out
::method normalizeForEquality private
  use strict arg rule, value
  canonical = self~ruleName(rule)
  select
    when canonical = .LdapMatchingBuild~CASE_IGNORE_MATCH then return self~caseIgnore(value)
    when canonical = .LdapMatchingBuild~CASE_EXACT_MATCH then return self~caseExact(value)
    when canonical = .LdapMatchingBuild~OBJECT_IDENTIFIER_MATCH then return self~objectIdentifier(value)
    when canonical = .LdapMatchingBuild~UUID_MATCH then return self~uuid(value)
    when canonical = .LdapMatchingBuild~INTEGER_MATCH then do
      n = self~integer(value); if n == .nil then return ""; return n~string
    end
    otherwise return value~string~lower
  end
::method allHex private
  use strict arg text
  do i = 1 to text~length
    if "0123456789abcdefABCDEF"~pos(text~substr(i,1)) = 0 then return .false
  end
  return .true

::requires "src/LdapDn.cls"
