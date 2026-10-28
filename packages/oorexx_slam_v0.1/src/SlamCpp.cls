/* SlamCpp.cls - SLAM's third language: read C++ into the same nodes and edges as ooRexx and Java.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 * C++ statements are Java's statements (braces, if / for / while / do / switch / try, ';'), so the Java
 * statement parser and segmenter are used unchanged. New here:
 *   lexer     C++ keywords; preprocessor lines (and their '\' continuations) are dropped, as comments
 *             are; raw strings R"d(...)d" are one STRING; 'constexpr' after 'if' is dropped
 *   splitter  functions at file, namespace and class level; Class::name( ... ) { } defined outside its
 *             class takes that class as owner (and its fields); namespace and extern "C" bodies are read
 *             through; template < ... > is skipped; a macro-made definition NAME(X) { } with one bare
 *             argument is unit X of owner NAME (the interpreter's BUILTIN(SUBSTR) is SUBSTR)
 *   shaper    member access is '.', '->' or '::'; a name before '::' or before another name is a type
 *             (.c in FINE, .C in FAMILY), as is T in 'T *x =' / 'T &x;'; nullptr and NULL are .nil;
 *             goto is a stop, as return / throw / break / continue are
 * Kinds: a unit is FUNCTION (no class), METHOD, or CTOR. C++ has no initializer blocks: a { } after a
 * member with no parameter list is a brace initializer, part of the field.
 *
 * Alchemy rules kept: no private methods, expose first, no variable named result, nested IF instead of
 * relying on & short-circuit, no labels inside loops.
 */

::requires 'SlamJava.cls'

/* ------------------------------------------------------------------------------------------------ */
::class SlamCppLexer public subclass SlamJavaLexer
::constant KEYWORDS 'alignas alignof asm auto bool break case catch char char8_t char16_t char32_t class const consteval constexpr constinit const_cast continue co_await co_return co_yield decltype default delete do double dynamic_cast else enum explicit export extern false float for friend goto if inline int long mutable namespace new noexcept nullptr operator private protected public register reinterpret_cast requires return short signed sizeof static static_assert static_cast struct switch template this thread_local throw true try typedef typeid typename union unsigned using virtual void volatile wchar_t while'
::method scan
  self~src = self~prepare(self~src)
  toks = self~scan:super
  /* if constexpr ( ... ) reads as if ( ... ) */
  out = .array~new
  do k = 1 to toks~items
    t = toks[k]
    if t~kind == 'KEYWORD' then if t~text == 'constexpr' then if out~items > 0 then if out[out~items]~text == 'if' then iterate
    out~append(t)
  end
  return out
/* Preprocessor lines become empty lines; raw strings become "R" with their line breaks kept, so line
 * numbers stay right. Strings, chars and comments are copied whole, so a '#' or R" inside one is not
 * read. The scan jumps between the characters that matter. */
::method prepare
  use strict arg text
  out = .mutablebuffer~new
  n = text~length
  stops = '"' || "'" || '/R#' || '0a'x
  idChars = xrange('a', 'z') || xrange('A', 'Z') || '0123456789_'
  i = 1
  atLineStart = .true
  do while i <= n
    k = verify(text, stops, 'M', i)
    if k == 0 then do
      out~append(text~substr(i))
      leave
    end
    if k > i then do
      chunk = text~substr(i, k - i)
      out~append(chunk)
      if chunk~strip('B', ' ')~strip('B', '09'x)~strip('B', '0d'x) \== '' then atLineStart = .false
      i = k
    end
    ch = text~subchar(i)
    select
      when ch == '0a'x then do
        out~append(ch)
        atLineStart = .true
        i += 1
      end
      when ch == '#' then do
        if \atLineStart then do
          out~append(ch)
          i += 1
          iterate
        end
        /* a directive: drop it and its '\' continuation lines, keep the line breaks */
        do forever
          e = text~pos('0a'x, i)
          if e == 0 then do
            i = n + 1
            leave
          end
          lineText = text~substr(i, e - i)~strip('T', '0d'x)
          out~append('0a'x)
          i = e + 1
          if lineText~right(1) \== '\' then leave
        end
        atLineStart = .true
      end
      when ch == 'R' then do
        prevOk = .true
        if i > 1 then if idChars~pos(text~subchar(i - 1)) > 0 then prevOk = .false
        done = .false
        if prevOk then if text~subchar(i + 1) == '"' then do
          p = text~pos('(', i + 2)
          if p > 0 then if p - i - 2 <= 16 then do
            delim = text~substr(i + 2, p - i - 2)
            e = text~pos(')' || delim || '"', p + 1)
            if e > 0 then do
              body = text~substr(i, e + delim~length + 2 - i)
              out~append('"R"')
              out~append(copies('0a'x, body~countStr('0a'x)))
              i = e + delim~length + 2
              done = .true
            end
          end
        end
        if \done then do
          out~append(ch)
          i += 1
        end
        atLineStart = .false
      end
      when ch == '"' | ch == "'" then do
        k = self~quoteEndIn(text, i, ch)
        out~append(text~substr(i, k + 1 - i))
        i = k + 1
        atLineStart = .false
      end
      otherwise do
        /* '/' : a comment is copied whole; anything else is one character */
        nx = text~subchar(i + 1)
        if nx == '*' then do
          k = text~pos('*/', i + 2)
          if k == 0 then k = n - 1
          out~append(text~substr(i, k + 2 - i))
          i = k + 2
        end
        else if nx == '/' then do
          k = text~pos('0a'x, i)
          if k == 0 then k = n + 1
          out~append(text~substr(i, k - i))
          i = k
        end
        else do
          out~append(ch)
          i += 1
          atLineStart = .false
        end
      end
    end
  end
  return out~string
::method quoteEndIn
  use strict arg text, i, q
  k = i + 1
  do forever
    e = text~pos(q, k)
    if e == 0 then return text~length
    b = text~pos('\', k)
    if b == 0 then return e
    if b > e then return e
    k = b + 2
  end

/* ------------------------------------------------------------------------------------------------ */
::class SlamCppSplitter public subclass SlamJavaSplitter
::attribute classFields
::method lexer
  use strict arg text
  return .SlamCppLexer~new(text)
::method split
  expose classFields
  use strict arg text
  classFields = .directory~new
  units = self~split:super(text)
  /* a method defined outside its class still sees that class's fields */
  do u over units
    if classFields~hasIndex(u~owner) then u~fields = classFields[u~owner]
  end
  return units
::method members
  expose classFields
  use strict arg owner, from, upto, isEnum, fields
  toks = self~toks
  match = self~match
  mine = .array~new
  i = from
  if isEnum then do
    /* an enum body is its constants: nothing to read */
    return
  end
  do while i < upto
    t = toks[i]
    if t~kind == 'OP' then if t~text == ';' then do
      i += 1
      iterate
    end
    /* public: private: protected: */
    if t~kind == 'KEYWORD' then if wordpos(t~text, 'public private protected') > 0 then if i + 1 < upto then if toks[i + 1]~text == ':' then do
      i += 2
      iterate
    end
    header = .array~new
    j = i
    stop = ''
    hasAssign = .false
    hasParen = .false
    angle = 0
    do while j < upto
      tj = toks[j]
      /* template < ... > is not part of the declaration */
      if tj~kind == 'KEYWORD' then if tj~text == 'template' then if j + 1 < upto then if toks[j + 1]~text == '<' then do
        angle = 1
        j += 2
        do while j < upto
          if toks[j]~text == '<' then angle += 1
          if toks[j]~text == '>' then angle -= 1
          j += 1
          if angle == 0 then leave
        end
        iterate
      end
      if tj~kind == 'OP' then do
        if tj~text == ';' then do
          stop = ';'
          leave
        end
        if tj~text == '{' then do
          if \hasAssign then do
            stop = '{'
            leave
          end
          do k = j to match[j]
            header~append(toks[k])
          end
          j = match[j] + 1
          iterate
        end
        if tj~text == '(' | tj~text == '[' then do
          if tj~text == '(' then if \hasAssign then hasParen = .true
          do k = j to match[j]
            header~append(toks[k])
          end
          j = match[j] + 1
          iterate
        end
        if tj~text == '=' then if \hasParen then hasAssign = .true
      end
      header~append(tj)
      j += 1
    end
    if stop == '' then leave
    if stop == ';' then do
      if header~items > 0 then if \hasParen then if wordpos(header[1]~text, 'using typedef friend static_assert namespace') == 0 then self~fieldNames(header, fields)
      i = j + 1
      iterate
    end
    close = match[j]
    kind = self~declKind(header, hasParen)
    select
      when kind == 'NAMESPACE' then self~members(owner, j + 1, close, .false, fields)
      when kind == 'TYPE' then do
        name = self~typeName(header)
        inner = name
        if name == '' then inner = owner
        innerFields = .directory~new
        if name \== '' then classFields[name] = innerFields
        isEnumBody = .false
        do x over header
          if x~kind == 'KEYWORD' then if x~text == 'enum' then isEnumBody = .true
        end
        self~members(inner, j + 1, close, isEnumBody, innerFields)
      end
      when kind == 'FUNCTION' then do
        u = self~functionUnit(owner, header, j, close)
        if u \== .nil then do
          mine~append(u)
          self~units~append(u)
        end
      end
      otherwise do
        /* a brace initializer: int x{5}; the name is the last identifier before it */
        do k = header~items to 1 by -1
          if header[k]~kind == 'IDENT' then do
            fields[header[k]~text] = .true
            leave
          end
        end
      end
    end
    i = close + 1
  end
  do u over mine
    u~fields = fields
  end
/* NAMESPACE (namespace x, extern "C"), TYPE (class, struct, union, enum), FUNCTION, or FIELD. */
::method declKind
  use strict arg header, hasParen
  if header~items == 0 then return 'FIELD'
  first = header[1]
  if first~kind == 'KEYWORD' then do
    if first~text == 'namespace' then return 'NAMESPACE'
    if first~text == 'extern' then if header~items == 2 then if header[2]~kind == 'STRING' then return 'NAMESPACE'
  end
  if first~kind == 'KEYWORD' then if first~text == 'inline' then if header~items >= 2 then if header[2]~text == 'namespace' then return 'NAMESPACE'
  if hasParen then return 'FUNCTION'
  do x over header
    if x~kind == 'KEYWORD' then if wordpos(x~text, 'class struct union enum') > 0 then return 'TYPE'
  end
  return 'FIELD'
/* The name after class / struct / union / enum [class], before ':' or 'final'. */
::method typeName
  use strict arg header
  do k = 1 to header~items
    x = header[k]
    if x~kind \== 'KEYWORD' then iterate
    if wordpos(x~text, 'class struct union enum') == 0 then iterate
    do m = k + 1 to header~items
      y = header[m]
      if y~kind == 'KEYWORD' then if wordpos(y~text, 'class struct') > 0 then iterate
      if y~kind == 'IDENT' then do
        /* Outer::Inner and alignas(...) names: take the last identifier of a qualified name */
        nm = y~text
        do while m + 2 <= header~items
          if header[m + 1]~text \== '::' then leave
          m += 2
          nm = header[m]~text
        end
        return nm
      end
      if y~kind == 'OP' then if y~text == '[' then iterate
      return ''
    end
    return ''
  end
  return ''
::method functionUnit
  use strict arg owner, header, j, close
  toks = self~toks
  open = 0
  do k = 1 to header~items
    if header[k]~kind == 'OP' then if header[k]~text == '(' then do
      open = k
      leave
    end
  end
  if open < 2 then return .nil
  nameTok = header[open - 1]
  name = nameTok~text
  at = open - 1
  /* operator==, operator(), operator>> (the lexer gives > > as two tokens) */
  if nameTok~kind == 'OP' then do
    k = open - 1
    sym = ''
    do while k >= 2
      if header[k]~kind \== 'OP' then leave
      sym = header[k]~text || sym
      k -= 1
    end
    if k >= 1 then if header[k]~text == 'operator' then do
      name = 'operator' || sym
      at = k
    end
  end
  /* a name with template arguments, __do_strtod<float>(: the name is the whole of it, not ">" */
  if name == '>' then do
    depth = 0
    k = open - 1
    do while k >= 2
      if header[k]~text == '>' then depth += 1
      if header[k]~text == '<' then depth -= 1
      if depth == 0 then leave
      k -= 1
    end
    if depth == 0 then if header[k - 1]~kind == 'IDENT' then do
      name = self~joinText(header, k - 1, open - 1)
      at = k - 1
    end
  end
  /* a conversion operator, operator T( or operator ranges::result<I>(: named "operator T" */
  if name~left(8) \== 'operator' then do
    k = at - 1
    do while k >= 1
      if header[k]~text == 'operator' then leave
      if header[k]~text \== '::' then if header[k]~kind \== 'IDENT' then leave
      k -= 1
    end
    if k >= 1 then if header[k]~text == 'operator' then do
      name = 'operator' self~joinText(header, k + 1, open - 1)
      at = k
    end
  end
  /* ~Destructor */
  if at >= 2 then if header[at - 1]~text == '~' then do
    name = '~' || name
    at -= 1
  end
  unitOwner = owner
  if at >= 3 then if header[at - 1]~text == '::' then do
    unitOwner = header[at - 2]~text
    /* X<V>::name: the owner is X */
    if unitOwner == '>' then do
      depth = 0
      k = at - 2
      do while k >= 2
        if header[k]~text == '>' then depth += 1
        if header[k]~text == '<' then depth -= 1
        if depth == 0 then leave
        k -= 1
      end
      if depth == 0 then if header[k - 1]~kind == 'IDENT' then unitOwner = header[k - 1]~text
    end
  end
  kind = 'FUNCTION'
  if unitOwner \== '' then kind = 'METHOD'
  if name == unitOwner then kind = 'CTOR'
  /* a macro-made definition: NAME(X) { } with one bare argument is unit X of owner NAME */
  close1 = 0
  depth = 0
  do k = open to header~items
    if header[k]~text == '(' then depth += 1
    if header[k]~text == ')' then do
      depth -= 1
      if depth == 0 then do
        close1 = k
        leave
      end
    end
  end
  isMacro = .false
  if close1 == open + 2 then if header[open + 1]~kind == 'IDENT' then if name == name~upper then if name~verify(xrange('A', 'Z') || '_0123456789') == 0 then isMacro = .true
  if isMacro then do
    unitOwner = name
    name = header[open + 1]~text
    kind = 'FUNCTION'
  end
  /* a macro-made definition NAME(type, name, (params)) { }, as LLVM libc's LLVM_LIBC_FUNCTION:
     unit name of owner NAME, with those parameters and that return type */
  macroArgs = .nil
  if \isMacro then if close1 > 0 then if name == name~upper then if name~verify(xrange('A', 'Z') || '_0123456789') == 0 then macroArgs = self~macroArgs(header, open, close1)
  if macroArgs \== .nil then do
    unitOwner = name
    name = macroArgs[2]
    kind = 'FUNCTION'
  end
  u = .SlamJavaUnit~new(kind, unitOwner, name, nameTok~line)
  if macroArgs \== .nil then do
    do t over macroArgs[3]; u~params~append(t); end
  end
  else if \isMacro then if close1 > 0 then do
    do k = open + 1 to close1 - 1
      u~params~append(header[k])
    end
  end
  if u~params~items == 1 then if u~params[1]~text == 'void' then u~params = .array~new
  ret = .array~new
  do k = 1 to at - 1
    t = header[k]
    if t~kind == 'KEYWORD' then if wordpos(t~text, 'static inline virtual explicit constexpr consteval friend extern') > 0 then iterate
    ret~append(t~text)
  end
  u~returns = ret~makeString('L', ' ')
  if macroArgs \== .nil then u~returns = macroArgs[1]
  do k = j + 1 to close - 1
    u~tokens~append(toks[k])
  end
  return u
/* Header tokens from .. to as text, a blank only between two words (X<typename Y::T>). */
::method joinText
  use strict arg header, first, last
  out = ''
  prevWord = .false
  do m = first to last
    t = header[m]
    word = (t~kind == 'IDENT' | t~kind == 'KEYWORD')
    if word then if prevWord then out = out || ' '
    out = out || t~text
    prevWord = word
  end
  return out
/* The arguments of NAME(type, name, (params)): .array~of(type text, name, param tokens), else .nil. */
::method macroArgs
  use strict arg header, open, close1
  args = .array~new
  cur = .array~new
  depth = 0
  do k = open + 1 to close1 - 1
    t = header[k]
    if t~text == '(' | t~text == '<' then depth += 1
    if t~text == ')' | t~text == '>' then depth -= 1
    if depth == 0 then if t~text == ',' then do
      args~append(cur)
      cur = .array~new
      iterate
    end
    cur~append(t)
  end
  args~append(cur)
  if args~items \= 3 then return .nil
  if args[2]~items \= 1 then return .nil
  if args[2][1]~kind \== 'IDENT' then return .nil
  p = args[3]
  if p~items < 2 then return .nil
  if p[1]~text \== '(' then return .nil
  if p[p~items]~text \== ')' then return .nil
  inner = .array~new
  do k = 2 to p~items - 1; inner~append(p[k]); end
  if inner~items == 1 then if inner[1]~text == 'void' then inner = .array~new
  type = .array~new
  do t over args[1]; type~append(t~text); end
  return .array~of(type~makeString('L', ' '), args[2][1]~text, inner)

/* ------------------------------------------------------------------------------------------------ */
::class SlamCppShaper public subclass SlamJavaShaper
::constant TERMS 'return throw break continue goto co_return'
/* C++ qualifies with '::', read by tokenRole: no '.' package chains */
::method qualified
  use strict arg c, ctx
  return .array~new(c~items)
::method tokenRole
  use strict arg c, i, ctx
  t = c[i]
  k = t~kind
  if k == 'STRING' then return 'STRING'
  if k == 'NUMBER' then return 'NUMBER'
  if k == 'OP' then return 'OP'
  if k == 'KEYWORD' then do
    if wordpos(t~text, 'true false nullptr') > 0 then return 'LITERAL'
    if t~text == 'this' then return 'SELF'
    return 'KEYWORD'
  end
  if k \== 'IDENT' then return 'OP'
  name = t~text
  if name == 'NULL' then return 'LITERAL'
  nx = .nil
  if i < c~items then nx = c[i + 1]
  if i > 1 then do
    p = c[i - 1]
    if p~kind == 'OP' then if wordpos(p~text, '. -> ::') > 0 then return 'MESSAGE'
    if p~kind == 'KEYWORD' then if p~text == 'new' then return 'CLASS'
  end
  if nx \== .nil then if nx~kind == 'OP' then do
    if nx~text == '::' then return 'CLASS'
    if nx~text == '(' then return 'FUNCTION'
  end
  if ctx['ARGS']~hasIndex(name) then return 'VAR'
  if ctx['FIELDS']~hasIndex(name) then return 'VAR'
  if nx \== .nil then if nx~kind == 'IDENT' then return 'CLASS'
  /* T *x = ... / T &x; at the start of a declaration */
  if nx \== .nil then if nx~kind == 'OP' then if wordpos(nx~text, '* & &&') > 0 then if i + 2 <= c~items then if c[i + 2]~kind == 'IDENT' then do
    lead = .true
    do m = 1 to i - 1
      if c[m]~kind \== 'KEYWORD' then lead = .false
    end
    after = ''
    if i + 3 <= c~items then after = c[i + 3]~text
    if lead then if wordpos(after, '= ; , ) [ ( {') > 0 | i + 3 > c~items then return 'CLASS'
  end
  return 'VAR'

/* ------------------------------------------------------------------------------------------------ */
::class SlamCppSegmenter public subclass SlamJavaSegmenter
::method newShaper
  return .SlamCppShaper~new
