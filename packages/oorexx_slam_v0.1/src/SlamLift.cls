/* SlamLift.cls - lift a standalone ooRexx routine, or a method that uses nothing of its object, out of
 * its file as a Routine that runs alone.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * The body is the lines after the unit's directive, up to the next directive. A method is found by its
 * class and its name (method names repeat across classes). A method can be lifted when it does not use
 * SELF, SUPER or EXPOSE (asked for by the rx2cpp lane: "take ::METHOD bodies of classes whose methods
 * are pure", so the compiler's own code gets tests, not only its fixtures).
 * The ooTest groups SlamTestWriter writes carry the same procedure as text (slamLift), so a group needs
 * nothing of SLAM to run.
 */

/* The body lines of routine NAME (owner '') or method NAME of class OWNER, or .nil. */
::routine slamLiftBody public
  use strict arg lines, name, owner = ''
  body = .array~new
  inside = .false
  cls = ''
  do ln over lines
    s = ln~strip
    if s~left(2) == '::' then do
      if inside then return body
      parse upper value s with d nm .
      nm = nm~strip('B', ';')~strip('B', "'")~strip('B', '"')
      if d == '::CLASS' then cls = nm
      if owner == '' then do
        if d == '::ROUTINE' then if nm == name~upper then inside = .true
      end
      else if d == '::METHOD' then if nm == name~upper then if cls == owner~upper then inside = .true
      if inside then do
        semi = s~pos(';')
        if semi > 0 then body~append(s~substr(semi + 1))
      end
      iterate
    end
    if inside then body~append(ln)
  end
  if inside then return body
  return .nil

/* The unit as a Routine from a file, or .nil when it is not there or does not compile. */
::routine slamLiftFile public
  use strict arg file, name, owner = ''
  lines = .array~new
  call stream file, 'C', 'OPEN READ'
  do while lines(file) > 0; lines~append(linein(file)); end
  call stream file, 'C', 'CLOSE'
  body = slamLiftBody(lines, name, owner)
  if body == .nil then return .nil
  /* a pure unit sends no commands; a mutant can (x[i] = v changed to x[i] \= v is a command), and a
     command must go nowhere, not to the shell */
  body~insert("address 'SLAMNOCMD'", .nil)
  signal on syntax name noCompile
  return .Routine~new(name, body)
noCompile:
  return .nil

/* Can a method be lifted? Its tokens use no SELF, SUPER or EXPOSE, and its directive is not an
   attribute or abstract method. */
::routine slamLiftableMethod public
  use strict arg unit, directiveLine
  d = directiveLine~upper
  if wordpos('ATTRIBUTE', d) > 0 | wordpos('ABSTRACT', d) > 0 then return .false
  do t over unit~tokens
    if t~kind == 'IDENT' then if wordpos(t~text~upper, 'SELF SUPER EXPOSE') > 0 then return .false
  end
  return .true

/* The ooTest group (class and file) name for a unit: SLAM_NAME or RAND_CLASS_METHOD. A character that
   cannot be in a symbol (an operator method, []= or =) is written as X and its hex. */
::routine slamGroupName public
  use strict arg kind, name
  n = name~upper~changeStr('~', '_')
  out = ''
  do i = 1 to n~length
    ch = n~subchar(i)
    if ch~verify(xrange('A', 'Z') || xrange('0', '9') || '_') == 0 then out = out || ch
    else out = out || 'X' || ch~c2x
  end
  return kind || '_' || out || '.testGroup'
