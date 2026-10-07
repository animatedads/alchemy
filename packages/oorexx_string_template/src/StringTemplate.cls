/*
 * StringTemplate.cls
 * ooRexx String Template v0.1-dev1
 *
 * Safe, compiled string interpolation for ooRexx.
 * Template text is data.  It is never passed to INTERPRET and arbitrary
 * object methods are never derived from template text.
 */

::class TemplateResolution public

::method init
  expose _found _value
  use strict arg found, value=.nil
  _found = found
  _value = value

::method found
  expose _found
  return _found

::method value
  expose _value
  return _value


::class TemplateObjectView public

::method init
  expose _object _properties
  use strict arg object
  _object = object
  _properties = .Directory~new

::method allow
  expose _properties
  use strict arg propertyName, messageName
  propertyName = propertyName~strip
  messageName = messageName~strip
  if propertyName = "" then raise syntax 88.900 array("template property name is required")
  if messageName = "" then raise syntax 88.900 array("template property message is required")
  _properties[propertyName] = messageName
  return self

::method hasProperty
  expose _properties
  use strict arg propertyName
  return _properties~hasIndex(propertyName)

::method property
  expose _object _properties
  use strict arg propertyName
  if \_properties~hasIndex(propertyName) then return .TemplateResolution~new(.false)
  messageName = _properties[propertyName]
  return .TemplateResolution~new(.true, _object~send(messageName))


::class TemplateContext public

::method init
  expose _values
  _values = .Directory~new

::method put
  expose _values
  use strict arg name, value
  name = name~strip
  if name = "" then raise syntax 88.900 array("template context name is required")
  _values[name] = value
  return self

::method putObject
  expose _values
  use strict arg name, object, propertyMap
  if \propertyMap~isa(.Directory) then raise syntax 88.900 array("propertyMap must be a Directory")
  view = .TemplateObjectView~new(object)
  do propertyName over propertyMap
    view~allow(propertyName, propertyMap[propertyName])
  end
  _values[name] = view
  return self

::method resolve
  expose _values
  use strict arg path
  parts = self~splitPath(path)
  if parts~items = 0 then return .TemplateResolution~new(.false)
  root = parts[1]
  if \_values~hasIndex(root) then return .TemplateResolution~new(.false)
  current = _values[root]
  do i = 2 to parts~items
    part = parts[i]
    if current~isa(.Directory) then do
      if \current~hasIndex(part) then return .TemplateResolution~new(.false)
      current = current[parts[i]]
      iterate
    end
    if current~isa(.TemplateObjectView) then do
      resolved = current~property(part)
      if \resolved~found then return resolved
      current = resolved~value
      iterate
    end
    return .TemplateResolution~new(.false)
  end
  return .TemplateResolution~new(.true, current)

::method splitPath
  use strict arg path
  partsOut = .Array~new
  rest = path
  do while rest \= ""
    dot = rest~pos(".")
    if dot = 0 then do
      part = rest
      rest = ""
    end
    else do
      part = rest~left(dot - 1)
      rest = rest~substr(dot + 1)
    end
    part = part~strip
    if part = "" then raise syntax 88.900 array("template path contains an empty component: " || path)
    partsOut~append(part)
  end
  return partsOut


::class TemplateFormatter public

::method format abstract


::class TemplateIdentityFormatter subclass TemplateFormatter public

::method format
  use strict arg value, argument=""
  if value == .nil then return ""
  return value~string


::class TemplateUpperFormatter subclass TemplateFormatter public

::method format
  use strict arg value, argument=""
  if value == .nil then return ""
  return value~string~upper


::class TemplateLowerFormatter subclass TemplateFormatter public

::method format
  use strict arg value, argument=""
  if value == .nil then return ""
  return value~string~lower


::class TemplateTrimFormatter subclass TemplateFormatter public

::method format
  use strict arg value, argument=""
  if value == .nil then return ""
  return value~string~strip


::class TemplatePrefixFormatter subclass TemplateFormatter public

::method format
  use strict arg value, argument=""
  if value == .nil then value = ""
  return argument || value~string


::class TemplateSuffixFormatter subclass TemplateFormatter public

::method format
  use strict arg value, argument=""
  if value == .nil then value = ""
  return value~string || argument


::class TemplateFormatterRegistry public

::method init
  expose _formatters
  _formatters = .Directory~new

::method default class
  registry = self~new
  registry~register("identity", .TemplateIdentityFormatter~new)
  registry~register("upper", .TemplateUpperFormatter~new)
  registry~register("lower", .TemplateLowerFormatter~new)
  registry~register("trim", .TemplateTrimFormatter~new)
  registry~register("prefix", .TemplatePrefixFormatter~new)
  registry~register("suffix", .TemplateSuffixFormatter~new)
  return registry

::method register
  expose _formatters
  use strict arg name, formatter
  name = name~strip~lower
  if name = "" then raise syntax 88.900 array("formatter name is required")
  if \formatter~isa(.TemplateFormatter) then raise syntax 88.900 array("formatter must subclass TemplateFormatter")
  _formatters[name] = formatter
  return self

::method has
  expose _formatters
  use strict arg name
  return _formatters~hasIndex(name~lower)

::method formatter
  expose _formatters
  use strict arg name
  key = name~lower
  if \_formatters~hasIndex(key) then raise syntax 88.900 array("unknown template formatter: " || name)
  return _formatters[key]


::class TemplateRenderPolicy public

::method init
  expose _missingMode _escapeMode
  use strict arg missingMode="ERROR", escapeMode="PLAIN"
  missingMode = missingMode~upper
  escapeMode = escapeMode~upper
  if wordpos(missingMode, "ERROR KEEP") = 0 then raise syntax 88.900 array("missingMode must be ERROR or KEEP")
  if wordpos(escapeMode, "PLAIN HTML JSON") = 0 then raise syntax 88.900 array("escapeMode must be PLAIN, HTML or JSON")
  _missingMode = missingMode
  _escapeMode = escapeMode

::method strictPlain class
  return self~new("ERROR", "PLAIN")

::method permissivePlain class
  return self~new("KEEP", "PLAIN")

::method strictHtml class
  return self~new("ERROR", "HTML")

::method strictJson class
  return self~new("ERROR", "JSON")

::method keepMissing
  expose _missingMode
  return _missingMode = "KEEP"

::method escape
  expose _escapeMode
  use strict arg text
  select
    when _escapeMode = "PLAIN" then return text
    when _escapeMode = "HTML" then return self~escapeHtml(text)
    when _escapeMode = "JSON" then return self~escapeJson(text)
  end
  return text

::method escapeHtml
  use strict arg text
  text = text~changestr("&", "&amp;")
  text = text~changestr("<", "&lt;")
  text = text~changestr(">", "&gt;")
  text = text~changestr('"', "&quot;")
  text = text~changestr("'", "&#39;")
  return text

::method escapeJson
  use strict arg text
  text = text~changestr("\\", "\\\\")
  text = text~changestr('"', '\\"')
  text = text~changestr("08"x, "\\b")
  text = text~changestr("0c"x, "\\f")
  text = text~changestr("0a"x, "\\n")
  text = text~changestr("0d"x, "\\r")
  text = text~changestr("09"x, "\\t")
  return text


::class TemplateSegment public

::method render abstract

::method variableName
  return .nil


::class LiteralTemplateSegment subclass TemplateSegment public

::method init
  expose _text
  use strict arg text
  _text = text

::method render
  expose _text
  use strict arg context, formatters, policy
  return _text


::class ValueTemplateSegment subclass TemplateSegment public

::method init
  expose _raw _path _formatterName _formatterArgument
  use strict arg raw, path, formatterName="identity", formatterArgument=""
  _raw = raw
  _path = path
  _formatterName = formatterName
  _formatterArgument = formatterArgument

::method variableName
  expose _path
  return _path

::method render
  expose _raw _path _formatterName _formatterArgument
  use strict arg context, formatters, policy
  resolved = context~resolve(_path)
  if \resolved~found then do
    if policy~keepMissing then return _raw
    raise syntax 88.900 array("missing template value: " || _path)
  end
  formatter = formatters~formatter(_formatterName)
  formatted = formatter~format(resolved~value, _formatterArgument)
  return policy~escape(formatted)


::class TemplateParser public

::method parse
  use strict arg source
  segments = .Array~new
  literal = ""
  i = 1
  n = source~length
  do while i <= n
    escapedMarker = .false
    if i + 2 <= n then do
      if source~substr(i, 3) = "$${" then escapedMarker = .true
    end
    if escapedMarker then do
      literal ||= "${"
      i += 3
      iterate
    end

    valueMarker = .false
    if i + 1 <= n then do
      if source~substr(i, 2) = "${" then valueMarker = .true
    end
    if valueMarker then do
      if literal \= "" then do
        segments~append(.LiteralTemplateSegment~new(literal))
        literal = ""
      end
      close = source~pos("}", i + 2)
      if close = 0 then raise syntax 88.900 array("unclosed template expression at character " || i)
      raw = source~substr(i, close - i + 1)
      expression = source~substr(i + 2, close - i - 2)~strip
      if expression = "" then raise syntax 88.900 array("empty template expression at character " || i)
      spec = self~parseExpression(expression)
      segments~append(.ValueTemplateSegment~new(raw, spec[1], spec[2], spec[3]))
      i = close + 1
      iterate
    end
    literal ||= source~substr(i, 1)
    i += 1
  end
  if literal \= "" then segments~append(.LiteralTemplateSegment~new(literal))
  return segments

::method parseExpression
  use strict arg expression
  parsed = .Array~new(3)
  pipe = expression~pos("|")
  if pipe = 0 then do
    path = expression~strip
    formatterName = "identity"
    formatterArgument = ""
  end
  else do
    path = expression~left(pipe - 1)~strip
    formatterSpec = expression~substr(pipe + 1)~strip
    if formatterSpec = "" then raise syntax 88.900 array("template formatter name is empty: " || expression)
    colon = formatterSpec~pos(":")
    if colon = 0 then do
      formatterName = formatterSpec
      formatterArgument = ""
    end
    else do
      formatterName = formatterSpec~left(colon - 1)~strip
      formatterArgument = formatterSpec~substr(colon + 1)
    end
  end
  if path = "" then raise syntax 88.900 array("template path is empty: " || expression)
  self~validatePath(path)
  parsed[1] = path
  parsed[2] = formatterName
  parsed[3] = formatterArgument
  return parsed

::method validatePath
  use strict arg path
  rest = path
  do while rest \= ""
    dot = rest~pos(".")
    if dot = 0 then do
      part = rest
      rest = ""
    end
    else do
      part = rest~left(dot - 1)
      rest = rest~substr(dot + 1)
    end
    if part = "" then raise syntax 88.900 array("template path contains empty component: " || path)
    first = part~left(1)
    if \self~identifierStart(first) then raise syntax 88.900 array("invalid template path component: " || part)
    do j = 2 to part~length
      ch = part~substr(j, 1)
      if \self~identifierContinue(ch) then raise syntax 88.900 array("invalid template path component: " || part)
    end
  end

::method identifierStart
  use strict arg ch
  return (ch >= "A" & ch <= "Z") | (ch >= "a" & ch <= "z") | ch = "_"

::method identifierContinue
  use strict arg ch
  return self~identifierStart(ch) | (ch >= "0" & ch <= "9") | ch = "-"


::class StringTemplate public

::method init
  expose _source _segments _variables _formatters
  use strict arg source, formatters=.nil
  _source = source
  if formatters == .nil then formatters = .TemplateFormatterRegistry~default
  if \formatters~isa(.TemplateFormatterRegistry) then raise syntax 88.900 array("formatters must be a TemplateFormatterRegistry")
  _formatters = formatters
  _segments = .TemplateParser~new~parse(source)
  _variables = self~collectVariables(_segments)

::method source
  expose _source
  return _source

::method segments
  expose _segments
  return _segments~copy

::method variables
  expose _variables
  return _variables~copy

::method formatters
  expose _formatters
  return _formatters

::method render
  expose _segments _formatters
  use strict arg context, policy=.nil
  if context~isa(.Directory) then do
    converted = .TemplateContext~new
    do key over context
      converted~put(key, context[key])
    end
    context = converted
  end
  if \context~isa(.TemplateContext) then raise syntax 88.900 array("render context must be TemplateContext or Directory")
  if policy == .nil then policy = .TemplateRenderPolicy~strictPlain
  if \policy~isa(.TemplateRenderPolicy) then raise syntax 88.900 array("render policy must be TemplateRenderPolicy")
  output = ""
  do segment over _segments
    output ||= segment~render(context, _formatters, policy)
  end
  return output

::method collectVariables
  use strict arg segments
  variables = .Array~new
  seen = .Directory~new
  do segment over segments
    name = segment~variableName
    if name == .nil then iterate
    if \seen~hasIndex(name) then do
      seen[name] = .true
      variables~append(name)
    end
  end
  return variables
