/* ShellObject.cls - common contract for NewShell objects
   Architecture: Tom Dyer.
   Coding: ChatGPT (ShellObject v0: ordered fields, table/json); Claude (Opus 5.5)
   (merge: abstract contract, identity/generation, ShellCollection, ScratchPad).

   Contract every shell object meets:
     fields          ordered Array of field names              (must override)
     field(name)     value of one field; default sends the name
     identity        what underlying resource this is           (default: object hash)
     isCurrent       is that resource still the same one?       (default: .true)
     generation      observation number, bumps on refresh
     source          where the data came from                   (default: 'local')
     capabilities    operations allowed; read-only by default   ('READ')
     asTable/asJson  return strings; table/json print them, so ~~table~~json chains
     keep(name)      put a reference on the scratch pad
*/
::requires 'json.cls'

::class ShellObject public mixinclass Object

::method fields
  raise syntax 93.900 array (self~class~id 'does not define fields')

::method field
  use strict arg key
  return self~send(key)

::method identity
  return self~class~id':'self~identityHash

::method isCurrent
  return .true

::method generation
  expose shellGeneration
  if \var('shellGeneration') then shellGeneration = 1
  return shellGeneration

::method refresh
  expose shellGeneration
  if \var('shellGeneration') then shellGeneration = 1
  shellGeneration += 1
  return self

::method source
  return 'local'

::method capabilities
  return .Array~of('READ')

::method asTable
  width = 0
  do key over self~fields; width = max(width, key~length); end
  out = .MutableBuffer~new
  do key over self~fields
    v = self~field(key)
    if v~isA(.Array) then v = shellJoin(v)
    out~append(key~left(width + 2), v~string, .endOfLine)
  end
  return out~string~strip('T', .endOfLine)

::method table
  say self~asTable

::method asJson
  out = .MutableBuffer~new('{')
  sep = ''
  do key over self~fields
    out~append(sep, .JSON~toJSON(key), ':', .JSON~toJSON(self~field(key)))
    sep = ','
  end
  return out~append('}')~string

::method json
  say self~asJson

::method keep
  use strict arg name
  .ScratchPad~current~keep(name, self)
  return self

/* What an LLM (or a person) is told about this object: its class, its
   fields, its public methods, and the class's SHELL_HELP text if it has
   one. Built from the class itself, so it cannot drift from the code. */
::method describe
  use strict arg name
  cls = self~class
  out = .MutableBuffer~new
  out~append(name || ': a' cls~id 'object', .endOfLine)
  out~append('  fields:' shellJoin(self~fields), .endOfLine)
  out~append('  methods:' shellJoin(shellPublicMethods(cls)), .endOfLine)
  prot = shellProtectedMethods(cls)
  if prot~items > 0 then out~append('  protected (the security manager decides at run time from the path; a refusal stops the run):' shellJoin(prot), .endOfLine)
  out~append('  capabilities:' shellJoin(self~capabilities), .endOfLine)
  if self~hasMethod('SHELL_HELP') then out~append('  notes:' self~shell_help, .endOfLine)
  return out~string

::routine shellJoin public
  use strict arg items
  text = ''
  do item over items; text = text item; end
  return text~strip

/* Public methods a class defines itself or inherits from non-base classes. */
::routine shellPublicMethods public
  use strict arg cls
  hidden = .Set~of('INIT', 'UNINIT', 'UNKNOWN', 'SHELL_HELP', 'DESCRIBE', 'KEEP', -
                   'TABLE', 'JSON', 'ASTABLE', 'ASJSON', 'MAKEARRAY', 'SUPPLIER', -
                   'AUTHORITYPATH', 'RELATEDSAMPLES')
  names = .Array~new
  s = cls~methods(.nil)
  do while s~available
    m = s~item; n = s~index
    if m \== .nil, \m~isPrivate, \m~isProtected, \m~isConstant, m~scope \== .Object, \hidden~hasIndex(n), n~right(1) \== '=' then
      if names~index(n~lower) == .nil then names~append(n~lower)
    s~next
  end
  return names~sortWith(.CaselessComparator~new)


/* A list of shell objects shown as one row each. Iterable with DO OVER. */
::class ShellCollection public inherit ShellObject

::method init
  expose items
  use strict arg items = (.Array~new)
  if \items~isA(.Array) then raise syntax 93.900 array ('ShellCollection~new needs an Array, not' items~string~left(40))

::method items
  expose items
  return items

::method makeArray
  expose items
  return items

::method supplier
  expose items
  return items~supplier

::method fields
  expose items
  if items~items = 0 then return .Array~new
  return items[1]~fields

::method asTable
  expose items
  cols = self~fields
  if cols~items = 0 then return '(empty)'
  widths = .Array~new
  do i = 1 to cols~items
    w = cols[i]~length
    do row over items; w = max(w, cellOf(row, cols[i])~length); end
    widths[i] = min(w, 72)
  end
  out = .MutableBuffer~new
  head = ''
  do i = 1 to cols~items; head ||= cols[i]~left(widths[i] + 2); end
  out~append(head~strip('T'), .endOfLine)
  do row over items
    line = ''
    do i = 1 to cols~items
      v = cellOf(row, cols[i])
      -- too long: a path keeps its tail (it ends in what matters), anything else
      -- keeps its start (a firewall rule or a verdict reads from the left)
      if v~length > widths[i] then do
        if v~left(1) == '/' then v = '...'v~right(widths[i] - 3)
        else v = v~left(widths[i] - 3)'...'
      end
      line ||= v~left(widths[i] + 2)
    end
    out~append(line~strip('T'), .endOfLine)
  end
  return out~string~strip('T', .endOfLine)

::method asJson
  expose items
  out = .MutableBuffer~new('[')
  sep = ''
  do row over items
    out~append(sep, row~asJson)
    sep = ','
  end
  return out~append(']')~string

/* A new collection sorted on one field: order 'A' ascending, 'D' descending.
   Numbers compare as numbers, anything else caselessly. */
::method sortedBy
  expose items
  use strict arg name, order = 'A'
  if wordpos(order~upper, 'A D') = 0 then raise syntax 93.900 array ('sortedBy order is A or D, not' order)
  sorted = items~copy~stableSortWith(.ShellFieldComparator~new(name, order~upper))
  return .ShellCollection~new(sorted)

/* A new collection of the first n items. */
::method first
  expose items
  use strict arg n
  if \n~datatype('W') | n < 0 then raise syntax 93.900 array ('first needs a whole number, not' n)
  if n >= items~items then return .ShellCollection~new(items~copy)
  return .ShellCollection~new(items~section(1, n))

::method select
  use strict arg test    -- a routine or method object taking the item, returning a boolean
  kept = .Array~new
  do row over self~items
    if test~callWith(.Array~of(row)) then kept~append(row)
  end
  return .ShellCollection~new(kept)


/* Scratch pad: named references between stages. Each entry remembers the
   identity and generation it was kept at, so a later stage can tell whether
   the resource behind it is still the same one (PIDs get reused). */
::class ScratchPad public inherit ShellObject

::method current class
  if \.local~hasIndex('SHELL.PAD') then .local['SHELL.PAD'] = self~new
  return .local['SHELL.PAD']

::method init
  expose entries order
  entries = .Directory~new
  order = .Array~new

::method keep
  expose entries order
  use strict arg name, obj
  key = name~upper
  if \entries~hasIndex(key) then order~append(key)
  entries[key] = .ScratchEntry~new(name, obj)
  return obj

::method get
  expose entries
  use strict arg name
  entry = entries[name~upper]
  if entry == .nil then raise syntax 93.900 array ('Nothing kept as' name)
  return entry~object

::method entry
  expose entries
  use strict arg name
  return entries[name~upper]

::method drop
  expose entries order
  use strict arg name
  key = name~upper
  entries~remove(key)
  at = order~index(key)
  if at \== .nil then order~delete(at)

::method unknown
  use arg name, args
  return self~get(name)

::method fields
  return .Array~of('name', 'kind', 'identity', 'keptGeneration', 'current')

::method asTable
  expose entries order
  rows = .Array~new
  do key over order; rows~append(entries[key]); end
  return .ShellCollection~new(rows)~asTable

::method asJson
  expose entries order
  rows = .Array~new
  do key over order; rows~append(entries[key]); end
  return .ShellCollection~new(rows)~asJson


::class ScratchEntry public inherit ShellObject
::attribute name get
::attribute object get
::attribute identity get
::attribute keptGeneration get

::method init
  expose name object identity keptGeneration
  use strict arg name, object
  identity = object~identity
  keptGeneration = object~generation

::method kind
  expose object
  return object~class~id

::method current
  expose object identity
  return object~isCurrent & (object~identity == identity)

::method fields
  return .Array~of('name', 'kind', 'identity', 'keptGeneration', 'current')


::class ShellFieldComparator public
::method init
  expose name order
  use strict arg name, order
::method compare
  expose name order
  use strict arg a, b
  x = a~field(name); y = b~field(name)
  if x~datatype('N') & y~datatype('N') then do
    if x < y then c = -1; else if x > y then c = 1; else c = 0
  end
  else c = x~caselessCompareTo(y)
  if order == 'D' then return -c
  return c

/* Protected methods: callable, but each call goes to the security manager. */
::routine shellProtectedMethods public
  use strict arg cls
  names = .Array~new
  s = cls~methods(.nil)
  do while s~available
    m = s~item; n = s~index
    if m \== .nil, m~isProtected, \m~isPrivate, names~index(n~lower) == .nil then names~append(n~lower)
    s~next
  end
  return names~sortWith(.CaselessComparator~new)

/* One table cell: blank when this row's class has no such field (a list of
   plans and watches together, say). */
::routine cellOf
  use strict arg row, col
  if \row~fields~hasItem(col) then return ''
  v = row~field(col)
  if v~isA(.Array) then return shellJoin(v)
  return v~string
