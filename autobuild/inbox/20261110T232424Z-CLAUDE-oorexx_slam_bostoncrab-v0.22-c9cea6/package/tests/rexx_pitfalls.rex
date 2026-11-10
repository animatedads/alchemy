/* rexx_pitfalls.rex - fail on ooRexx traps that have already cost runs.
   Usage: rexx rexx_pitfalls.rex file ...   (exit 0 clean, 1 if any found)

   P1  a string literal followed at once by "(":  '"'(x)  is a call to a
       routine named ", not a string beside a value. Write '"' || (x).
   P2  a string literal followed at once by x or b and then no letter or
       digit:  'text'x  is a hexadecimal (or binary) literal. Write
       'text' || x. A real hex or binary literal ('D0'x) is let through.
   P3  two names in one file that differ only in case: ooRexx names are
       case-insensitive, so uNp and unP are one variable.
   P4  in a ::method, ::routine or procedure label, a "use arg" name that is
       also a "do ... over" or "do ... =" control variable: the loop
       overwrites the argument (compile.rex lost its English table so).
   Comments and the inside of strings are not checked for P3.

   Architecture: Tom Dyer. Code: Claude (Opus 5.5). */
parse arg files
if files = '' then do
  say 'usage: rexx rexx_pitfalls.rex file ...'
  exit 2
end
found = 0
do f over files~subWords
  found = found + checkFile(f)
end
if found > 0 then do
  say 'FAIL' found 'ooRexx pitfall(s)'
  exit 1
end
say 'PASS no ooRexx pitfalls in' words(files) 'file(s)'
exit 0

checkFile: procedure
  use arg file
  s = .Stream~new(file)
  if s~open('read') \= 'READY:' then do
    say file': cannot open'
    return 1
  end
  lines = s~arrayIn
  s~close
  found = 0
  inComment = 0
  names = .StringTable~new         /* lower-case name -> first spelling */
  argNames = ''                    /* "use arg" names of the current unit */
  unitStart = 0
  do n = 1 to lines~items
    raw = lines[n]
    code = ''                      /* the line with strings blanked, comments removed */
    i = 1
    len = raw~length
    do while i <= len
      c = raw~substr(i, 1)
      if inComment then do
        if raw~substr(i, 2) == '*/' then do
          inComment = 0
          i = i + 2
        end
        else i = i + 1
        iterate
      end
      if raw~substr(i, 2) == '/*' then do
        inComment = 1
        i = i + 2
        iterate
      end
      if raw~substr(i, 2) == '--' then leave
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
        if nx == '(' then do
          say file':'n': P1 string followed by "(" is a routine call:' raw~strip
          found = found + 1
        end
        if pos(nx, 'xXbB') > 0 then if \datatype(nx2, 'A') & nx2 \== '_' & nx2 \== '.' then do
          ok = 0
          if pos(nx, 'xX') > 0 then if lit \== '' then if verify(lit, '0123456789abcdefABCDEF ') = 0 then ok = 1
          if pos(nx, 'bB') > 0 then if lit \== '' then if verify(lit, '01 ') = 0 then ok = 1
          if \ok then do
            say file':'n': P2 string followed by' nx 'is a hex/binary literal:' raw~strip
            found = found + 1
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
    if t~left(2) == '::' then do
      argNames = ''
      unitStart = n
    end
    if t~right(1) == ':' then if words(t) = 1 then do
      argNames = ''
      unitStart = n
    end
    lt = t~lower
    if lt~word(1) == 'use' then if lt~word(2) == 'arg' then do
      do a over lt~subWord(3)~translate('  ', ',=')~subWords
        if datatype(a~left(1), 'A') then if a \== '.nil' then argNames = argNames a
      end
    end
    /* do X over / do X = */
    if lt~word(1) == 'do' | lt~word(1) == 'loop' then do
      cv = lt~word(2)
      if wordpos(lt~word(3), 'over =') > 0 | (cv~pos('=') > 0) then do
        cv = cv~translate(' ', '=')~word(1)
        if wordpos(cv, argNames) > 0 then do
          say file':'n': P4 loop variable "'cv'" overwrites a "use arg" name of this routine:' raw~strip
          found = found + 1
        end
      end
    end
    /* names, for P3 */
    w = code~translate(' ', '~()[],;+-*/\=<>|&%.:''"!?')
    do nm over w~subWords
      if \datatype(nm~left(1), 'M') then iterate
      if \datatype(nm, 'A') & nm~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_') > 0 then iterate
      k = nm~lower
      if \names~hasIndex(k) then names[k] = nm
      /* both spellings carry capitals, differently: one variable to ooRexx */
      else if names[k] \== nm then if names[k] \== k then if nm \== k then do
        say file':'n': P3 "'nm'" and "'names[k]'" differ only in case, and are one name to ooRexx'
        found = found + 1
        names[k] = nm
      end
    end
  end
  return found
