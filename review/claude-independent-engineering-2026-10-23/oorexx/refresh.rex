/* refresh.rex - verify Alchemy ooRexx house rules against r13196 */
signal on syntax name onSyntax

say "1. & does not short-circuit:"
calls = .Directory~new
calls~n = 0
if .false & sideEffect(calls) then nop
say "   sideEffect ran" calls~n "time(s) (expect 1)"

say "2. trailing comma = continuation, even in arg lists:"
s = joinArgs("a",
  "b")
say "   joinArgs gave:" s "(two args joined)"

say "3. .Queue~items:"
q = .Queue~new
q~queue("x"); q~queue("y")
say "   items =" q~items

say "4. unassigned use arg test with symbol():"
call probe
call probe "given"

say "5. .Directory iteration order not guaranteed; use .StringTable/.Array if order matters"
d = .Directory~new
do i = 1 to 6; d["k"i] = i; end
say "   allIndexes:" d~allIndexes~makeString("L", " ")

say "6. private method across Message boundary (start):"
o = .Probe~new
m = o~start("callsPrivate")
say "   async public->private:" m~result
m2 = .Message~new(o, "secret")
m2~start
m2~wait
if m2~hasError then say "   direct async send to private: ERROR" m2~errorCondition~code
else say "   direct async send to private:" m2~result

say "7. unguarded attribute set from outside:"
o~_name = "set externally"
say "  " o~_name

say "8. reply + unguarded background loop:"
w = .Worker~new
w~run
call syssleep 0.3
w~stop = .true
call syssleep 0.3
say "   worker ticks > 0:" (w~ticks > 0)

say "done"
exit 0

onSyntax:
  say "SYNTAX rc="rc "sigl="sigl "C="condition("C") "D="condition("D")
  exit 1

sideEffect: procedure
  use arg c
  c~n = c~n + 1
  return .true

joinArgs: procedure
  return "arg()="arg() "arg1=["arg(1)"]"

probe: procedure
  use arg x
  if symbol("x") = "LIT" then say "   x unassigned (LIT)"
  else say "   x =" x
  return

::class Probe
::attribute _name unguarded
::method callsPrivate
  return self~secret
::method secret private
  return "private reached"

::class Worker
::attribute stop unguarded
::attribute ticks unguarded
::method init
  expose stop ticks
  stop = .false
  ticks = 0
::method run unguarded
  expose stop ticks
  reply
  do while \stop
    ticks = ticks + 1
    call syssleep 0.05
  end
