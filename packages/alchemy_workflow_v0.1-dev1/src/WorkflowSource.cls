/* WorkflowSource.cls - Alchemy Workflow v0.1-dev1: one ooRexx source file, read once, for every step.
 *
 * Architecture: Tom Dyer (the workflow planner; steps registered into it; house rules applied by rule).
 * Code: Claude (Opus 5.5), 2026-11-11.
 *
 * Steps never scan raw text for rules. They ask this object, which has already:
 *   - kept the raw lines (raw[n]);
 *   - made a "code" copy of each line (code[n]) of the same length, with comments (nested block comments
 *     and -- line comments) and the inside of every string blanked, the quotes kept. A rule that looks for
 *     "result =" or "+ 0" in code[] can never be fooled by a comment or a string;
 *   - listed every directive (::class, ::method, ::attribute, ::constant, ::routine, ::requires) with its
 *     line, name, options and owning class, and the line range of each method body;
 *   - noted the two literal traps of the house rules (Nov 2026): a string followed at once by "(" is a call
 *     of a routine named by the string ('"'(x)), and a string followed at once by x or b is a hex or binary
 *     literal ('|'b). A trap is noted only when the string is not a real hex or binary string, so '0d0a'x
 *     is not one.
 */

::class WorkflowSource public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute path get
::attribute raw get
::attribute code get
::attribute directives get
::attribute traps get

::method init
  expose path raw code directives traps
  use strict arg path
  raw = .array~new
  s = .stream~new(path)
  if s~open('read shareread') \= 'READY:' then raise syntax 98.900 array('Workflow: cannot read' path)
  do while s~lines > 0
    raw~append(s~lineIn)
  end
  s~close
  traps = .array~new
  code = self~clean(raw)
  directives = self~findDirectives

/* comments and string contents blanked; quotes kept; same length as the raw line */
::method clean
  expose traps
  use strict arg lines
  out = .array~new
  opened = .array~new
  n = 0
  do line over lines
    n += 1
    s = ''
    q = ''
    body = ''
    len = line~length
    j = 1
    do while j <= len
      c = line~subchar(j)
      two = line~substr(j, 2)
      if opened~items > 0 then do
        if two == '*/' then do
          opened~delete(opened~last)
          s = s || '  '
          j += 2
          iterate
        end
        if two == '/*' then do
          opened~append(n)
          s = s || '  '
          j += 2
          iterate
        end
        s = s || ' '
        j += 1
        iterate
      end
      if q \== '' then do
        if c == q then do
          if line~subchar(j + 1) == q then do
            body = body || q
            s = s || '  '
            j += 2
            iterate
          end
          q = ''
          s = s || c
          self~noteTrap(n, body, line~subchar(j + 1), line~subchar(j + 2))
          j += 1
          iterate
        end
        body = body || c
        s = s || ' '
        j += 1
        iterate
      end
      if two == '/*' then do
        opened~append(n)
        s = s || '  '
        j += 2
        iterate
      end
      if two == '--' then do
        s = s || ' '~copies(len - j + 1)
        leave
      end
      if c == '"' | c == "'" then do
        q = c
        body = ''
      end
      s = s || c
      j += 1
    end
    out~append(s)
  end
  /* a comment still open at the end: ooRexx refuses the file (Error 6.1). The culprit is nearly always the
     last opener, a slash and asterisk written inside a comment (a path or a glob), which opens a nested one */
  if opened~items > 0 then do
    t = .directory~new
    t['LINE'] = opened[opened~last]
    t['KIND'] = 'COMMENT'
    t['TEXT'] = 'the comment opened on line' opened[1] 'is never closed'
    traps~append(t)
  end
  return out

/* after a string ends: the character straight after it, and the one after that */
::method noteTrap
  expose traps
  use strict arg n, body, after, next
  if after == '(' then do
    t = .directory~new
    t['LINE'] = n; t['KIND'] = 'CALL'; t['TEXT'] = body
    traps~append(t)
    return
  end
  if after~upper \== 'X' & after~upper \== 'B' then return
  /* x or b followed by a name character is a name, not a literal suffix: 'a'xyz is abuttal of 'a' and xyz */
  if next \== '' then if verify(next, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.!?') = 0 then return
  if after~upper == 'X' then ok = verify(body, '0123456789abcdefABCDEF ') = 0 & body~space(0) \== ''
  else ok = verify(body, '01 ') = 0 & body~space(0) \== ''
  if ok then return
  t = .directory~new
  t['LINE'] = n
  if after~upper == 'X' then t['KIND'] = 'HEX'
  else t['KIND'] = 'BINARY'
  t['TEXT'] = body
  traps~append(t)

/* every directive, with its owning class and its body's line range */
::method findDirectives
  expose raw code
  out = .array~new
  owner = ''
  n = 0
  do line over code
    n += 1
    t = line~strip
    if t~left(2) \== '::' then iterate
    /* the name may be quoted, so it is read from the raw line, at the same columns */
    rawT = raw[n]~strip
    parse var rawT '::' kind name .
    parse var t '::' . . opts
    d = .directory~new
    d['KIND'] = kind~upper
    d['NAME'] = name~strip('B', "'")~strip('B', '"')
    d['OPTIONS'] = opts~upper~space
    d['LINE'] = n
    d['LAST'] = code~items
    if d['KIND'] == 'CLASS' then owner = d['NAME']
    d['OWNER'] = owner
    if out~items > 0 then out[out~items]['LAST'] = n - 1
    out~append(d)
  end
  return out

/* the directives of one kind (CLASS, METHOD, ...) */
::method ofKind
  expose directives
  use strict arg kind
  out = .array~new
  do d over directives
    if d['KIND'] == kind~upper then out~append(d)
  end
  return out

/* the members (METHOD, ATTRIBUTE, CONSTANT) of a class, by upper-case name */
::method members
  expose directives
  use strict arg className
  out = .directory~new
  do d over directives
    if d['OWNER'] \== className then iterate
    if d['KIND'] == 'CLASS' then iterate
    if d['KIND'] == 'REQUIRES' then iterate
    if d['KIND'] == 'ROUTINE' then iterate
    out[d['NAME']~upper] = d
  end
  return out

/* the raw value of a ::constant line: ::constant NAME 'value' */
::method constantValue
  expose raw
  use strict arg d
  parse value raw[d['LINE']]~strip with '::' . . v
  v = v~strip
  if v~left(1) == "'" | v~left(1) == '"' then v = v~substr(2, v~length - 2)
  return v
