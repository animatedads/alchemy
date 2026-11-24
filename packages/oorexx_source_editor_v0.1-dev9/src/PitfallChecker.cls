/* PitfallChecker.cls -- the ooRexx traps that have already cost runs, as a
   class an editor or a tool can ask: P1 to P4, each with its line and column,
   and a fix where one is certain.  tests/rexx_pitfalls.rex is its command.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   P1  a string literal followed at once by "(":  '"'(x)  is a call to a
       routine named ", not a string beside a value.  Fix: '"' || (x).
   P2  a string literal followed at once by x or b and then no letter or
       digit:  'text'x  is a hexadecimal (or binary) literal.  A real one
       ('D0'x) is let through.  Fix: 'text' || x.
   P3  two names in one file that differ only in case: ooRexx names are
       case-insensitive, so uNp and unP are one variable.  No fix: the
       right spelling is the writer's choice.
   P4  in a ::method, ::routine or procedure label, a "use arg" name that is
       also a "do ... over" or "do ... =" control variable: the loop
       overwrites the argument.  No fix: it needs a new name.
   Comments and the inside of strings are not checked for P3, nor is the
   text of a ::RESOURCE (it is data, not code).

   checker = .RexxPitfallChecker~new
   findings = checker~check(lines)        an array of RexxPitfall
   lines = checker~fix(lines, finding)    the lines with that finding fixed
   checker~report(file, lines)            the command's lines, "file:n: P1 ..." */

::class RexxPitfallChecker public

::method module_version class
  return "0.24"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.24"
::method module_lastChanged
  return "2026-11-15"

::method check
  use strict arg lines
  found = .array~new
  inComment = 0
  inResource = .false
  resourceEnd = ""
  names = .StringTable~new        /* lower-case name -> first spelling */
  argNames = ""                    /* "use arg" names of the current unit */
  do n = 1 to lines~items
    raw = lines[n]
    -- the text of a ::RESOURCE is data, up to its end line
    if inResource then do
      if raw~strip~caselessEquals(resourceEnd) then inResource = .false
      iterate
    end
    if \inComment then if raw~strip~left(10)~caselessEquals("::resource") then do
      parse value raw~strip with . . kw endText .
      resourceEnd = "::END"
      if kw~caselessEquals("END") then resourceEnd = endText~strip("B", '"')~strip("B", "'")
      inResource = .true
      iterate
    end
    code = ""                       /* the line with strings blanked, comments removed */
    i = 1
    len = raw~length
    do while i <= len
      c = raw~substr(i, 1)
      if inComment then do
        if raw~substr(i, 2) == "*/" then do
          inComment = 0
          i = i + 2
        end
        else i = i + 1
        iterate
      end
      if raw~substr(i, 2) == "/*" then do
        inComment = 1
        i = i + 2
        iterate
      end
      if raw~substr(i, 2) == "--" then leave
      if c == "'" | c == '"' then do
        /* a string: find its end (a doubled quote stays inside) */
        j = i + 1
        do forever
          if j > len then leave
          if raw~substr(j, 1) == c then do
            if raw~substr(j + 1, 1) == c then do
              j = j + 2
              iterate
            end
            leave
          end
          j = j + 1
        end
        lit = raw~substr(i + 1, j - i - 1)
        nx = raw~substr(j + 1, 1)
        nx2 = raw~substr(j + 2, 1)
        if nx == "(" then found~append(.RexxPitfall~new("P1", n, j + 1, raw~strip, j + 1))
        if pos(nx, "xXbB") > 0 then if \datatype(nx2, "A") & nx2 \== "_" & nx2 \== "." then do
          ok = 0
          if pos(nx, "xX") > 0 then if lit \== "" then if verify(lit, "0123456789abcdefABCDEF ") = 0 then ok = 1
          if pos(nx, "bB") > 0 then if lit \== "" then if verify(lit, "01 ") = 0 then ok = 1
          if \ok then do
            p = .RexxPitfall~new("P2", n, j + 1, raw~strip, j + 1)
            p~after = nx
            found~append(p)
          end
        end
        code = code '""'
        i = j + 1
        iterate
      end
      code = code || c
      i = i + 1
    end
    t = code~strip
    /* a new unit: ::method, ::routine, or a label with "procedure" after it */
    if t~left(2) == "::" then argNames = ""
    if t~right(1) == ":" then if words(t) = 1 then argNames = ""
    lt = t~lower
    if lt~word(1) == "use" then if lt~word(2) == "arg" then do
      do a over lt~subWord(3)~translate("  ", ",=")~subWords
        if datatype(a~left(1), "A") then if a \== ".nil" then argNames = argNames a
      end
    end
    /* do X over / do X = */
    if lt~word(1) == "do" | lt~word(1) == "loop" then do
      cv = lt~word(2)
      if wordpos(lt~word(3), "over =") > 0 | (cv~pos("=") > 0) then do
        cv = cv~translate(" ", "=")~word(1)
        if wordpos(cv, argNames) > 0 then do
          p = .RexxPitfall~new("P4", n, raw~caselessPos(cv), raw~strip, 0)
          p~names = .array~of(cv)
          found~append(p)
        end
      end
    end
    /* names, for P3 */
    w = code~translate(" ", "~()[],;+-*/\=<>|&%.:'""!?")
    do nm over w~subWords
      if \datatype(nm~left(1), "M") then iterate
      if \datatype(nm, "A") & nm~verify("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_") > 0 then iterate
      k = nm~lower
      if \names~hasIndex(k) then names[k] = nm
      /* both spellings carry capitals, differently: one variable to ooRexx */
      else if names[k] \== nm then if names[k] \== k then if nm \== k then do
        p = .RexxPitfall~new("P3", n, max(1, raw~pos(nm)), raw~strip, 0)
        p~names = .array~of(nm, names[k])
        found~append(p)
        names[k] = nm
      end
    end
  end
  return found

-- the lines with one finding fixed (P1 and P2: " || " put in); a finding
-- with no fix leaves the lines as they are
::method fix
  use strict arg lines, finding
  if finding~fixAt = 0 then return lines
  out = lines~copy
  l = out[finding~line]
  out[finding~line] = l~left(finding~fixAt - 1) || " || " || l~substr(finding~fixAt)
  return out

-- what the command prints: one line per finding, as rexx_pitfalls.rex always has
::method report
  use strict arg file, lines
  out = .array~new
  do p over self~check(lines)
    select
      when p~rule == "P1" then out~append(file":"p~line": P1 string followed by ""("" is a routine call:" p~text)
      when p~rule == "P2" then out~append(file":"p~line": P2 string followed by" p~after "is a hex/binary literal:" p~text)
      when p~rule == "P3" then out~append(file":"p~line": P3 """p~names[1]""" and """p~names[2]""" differ only in case, and are one name to ooRexx")
      otherwise out~append(file":"p~line": P4 loop variable """p~names[1]""" overwrites a ""use arg"" name of this routine:" p~text)
    end
  end
  return out

/* One finding: the rule, where, the line's text, and where a fix goes. */
::class RexxPitfall public
::attribute rule
::attribute line
::attribute column
::attribute text
::attribute fixAt        -- the column " || " goes in at, 0 when there is no fix
::attribute names        -- P3: the two spellings; P4: the loop variable
::attribute after        -- P2: the x or b after the string
::method init
  expose rule line column text fixAt names after
  use strict arg rule, line, column, text, fixAt
  names = .array~new
  after = ""
::method module_version class
  return "0.24"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.24"
::method module_lastChanged
  return "2026-11-15"
