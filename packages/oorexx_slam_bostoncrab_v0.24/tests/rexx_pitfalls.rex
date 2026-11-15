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
   Comments and the inside of strings are not checked for P3, nor is the
   text of a ::RESOURCE (v0.23).

   Since v0.23 the checks are the class RexxPitfallChecker (tests/PitfallChecker.cls),
   which an editor can ask too; this is its command, and prints as before.

   Architecture: Tom Dyer. Code: Claude (Opus 5.5). */
parse arg files
if files = '' then do
  say 'usage: rexx rexx_pitfalls.rex file ...'
  exit 2
end
found = 0
checker = .RexxPitfallChecker~new
do f over files~subWords
  s = .Stream~new(f)
  if s~open('read') \= 'READY:' then do
    say f': cannot open'
    found = found + 1
    iterate
  end
  lines = s~arrayIn
  s~close
  do l over checker~report(f, lines)
    say l
    found = found + 1
  end
end
if found > 0 then do
  say 'FAIL' found 'ooRexx pitfall(s)'
  exit 1
end
say 'PASS no ooRexx pitfalls in' words(files) 'file(s)'
exit 0

::requires "PitfallChecker.cls"
