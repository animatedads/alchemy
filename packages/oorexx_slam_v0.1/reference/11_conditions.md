# events and traps

this file is from the part of the rexx language rules about events and the traps for them.

state: what a thing is at one time, as on or off
delayed: a trap is delayed when its event is raised and the trap does not run for that event again yet
trapped: an event is trapped when a trap for it is on and runs
failure: a kind of error that a command can say it has
description: a string that says what a thing is
additional: more; the additional object of an event has more data about it
raises: raise, for one thing
comes: come, for one thing
level: a routine is at one level, and a routine it calls is at the next level
rc: the name of a special variable; it gets a return code or an error number
sigl: the name of a special variable; it gets the number of a line

```
CALL ON condition [NAME trapname]
CALL ON USER usercondition [NAME trapname]
CALL OFF condition
SIGNAL ON condition [NAME trapname]
SIGNAL ON USER usercondition [NAME trapname]
SIGNAL OFF condition
```
these instructions set a trap on or off.
the name of the event and the name of the trap are each one symbol; the instruction uses it as a constant.
each trap is on, off, or delayed.
at the start, each trap is off.
when the event of a trap that is on is raised, the program goes to the name of the trap, if you give it.
if you do not give the name of the trap, the program goes to a label or a routine with the name of the event.
the program uses call or signal: the same instruction as the last one that set the trap on.
a call trap can be an internal label, a builtin function, or an external routine.
a call trap gets the condition object as an argument.
a signal trap must be an internal label.
each on or off instruction changes the state and the name of the trap; the state before goes away.
so a call on instruction changes a signal on trap of the same event, and a signal on instruction changes a call on trap.
an off instruction makes the trap off for both call and signal.
the code:
```rexx
call on error
call on error name commanderror
```
the result:
```
```

```
ANY
```
this trap runs for any event that has no other trap on.
if an uninitialized variable is used, there is no trap for that event, and this trap is on with signal, this trap runs.
with call, this trap does not run when an uninitialized variable is used; you can not use call on for that event.

```
ERROR
::OPTIONS ERROR SYNTAX
```
this event is raised when a command gives back an error.
it is also raised when a command gives back a failure and no trap is on for the failure event or for any event.
it is raised at the end of the clause that gives the command.
if the trap for this event is delayed, the program ignores this event.
if the package has the directive in the code before and no trap is on for this event or for any event, the event of a language error is raised in its place.
the description of this event is the string of the command that gives the error.
when this event is trapped, the special variable rc gets the return code of the command, before the program goes to the label.
you can use call on or signal on for this event.

```
FAILURE
::OPTIONS FAILURE SYNTAX
```
this event is raised when a command gives back a failure.
it is raised at the end of the clause that gives the command.
if the trap for this event is delayed, the program ignores this event.
a command to an environment that is not known also raises this event.
if the package has the directive in the code before and no trap is on for this event or for any event, the event of a language error is raised in its place.
the description of this event is the string of the command that gives the failure.
when this event is trapped, the special variable rc gets the return code of the command, before the program goes to the label.
you can use call on or signal on for this event.

```
HALT
Ctrl+Break      -- in a full-screen or command prompt session, raises HALT
RXHLT exit, RexxStart interface
```
this event is raised when a thing outside the program has a need to stop and end it.
it is raised at the end of the clause that runs at that time, as a rule.
in a shell, the input in the second line of the code raises this event.
if that input comes while a command or an external function that is not rexx runs, that command or function ends, not the program.
a program can use the names in the third line of the code to halt a rexx program.
only a trap for this event can trap error 4.
the description of this event is any string that comes with the halt; it can be empty.
if no trap is on for this event, the program raises the event of a language error, with the rexx error number.
you can use call on or signal on for this event.

```
LOSTDIGITS
NUMERIC DIGITS
::OPTIONS LOSTDIGITS SYNTAX
```
this event is raised when a number in maths has more digits than the precision that the instruction in the second line of the code gives.
you do not count zero digits at the start of the number.
you can trap it only with signal on.
if the package has the directive in the code before and no trap is on for this event, the event of a language error is raised in its place.
the description of this event is the number that has too many digits.

```
NOMETHOD
UNKNOWN
```
this event is raised when an object gets a message, has no method for it, and has no method with the name in the second line of the code.
you can trap it only with signal on.
the description of this event is the name of the method that the object does not have.
the additional data of this event is the object that raised it.
if no trap is on for this event, the program raises the event of a language error, with the rexx error number.

```
NOSTRING
::OPTIONS NOSTRING SYNTAX
```
this event is raised when the language needs a string value from an object that does not give one.
you can trap it only with signal on.
if the package has the directive in the code before and no trap is on for this event, the event of a language error is raised in its place.
the description of this event is a string that you can read, made from the object that raised it.
the additional data of this event is the object that raised it.

```
NOTREADY
::OPTIONS NOTREADY SYNTAX
```
this event is raised when there is an error in input or output.
if the trap for this event is delayed, the program ignores this event.
if the package has the directive in the code before and no trap is on for this event, the event of a language error is raised in its place.
the description of this event is the name of the stream that the program uses when the event is raised.
for a default stream that has no name, the description can be empty.
the additional data of this event is the stream object that raised it.
you can use call on or signal on for this event.

```
NOVALUE
::OPTIONS NOVALUE SYNTAX
PARSE VAR name template
```
this event is raised when the program uses an uninitialized variable.
it is raised when the variable is a part of an expression.
it is raised when the variable is the name after the keyword in the third line of the code.
it is raised when the variable is in an expose, a procedure, or a drop instruction.
it is not raised for an uninitialized variable in the tail of a compound symbol.
you can trap it only with signal on; you can not use call on for this event.
if the package has the directive in the code before and no trap is on for this event, the event of a language error is raised in its place.
the description of this event is the name of the variable.
the code:
```rexx
/* The following does not raise NOVALUE. */
signal on novalue
a.=0
say a.z
say "NOVALUE is not raised."
exit

novalue:
say "NOVALUE is raised."
```
the result:
```
0
NOVALUE is not raised.
```

```
SYNTAX
INTERPRET string
```
this event is raised for any error of the language when the program runs.
it is raised for an error in the rules of the code.
it is raised for an error at run time, as maths with a value that is not a number.
it is raised for a language error that comes from a call or a method at an other level.
it is raised for a halt event, or for an event of a message with no method, when the event has no trap.
you can trap it only with signal on.
it can not trap error 3 or error 5.
it can trap error 6 and error 30 only when they come in the instruction in the second line of the code.
the description of this event is any string that the language gives with the error; it can be empty.
the special variables rc and sigl say what the error is and where it is.
when this event is trapped, the special variable rc gets the error number, before the program goes to the label.
the additional data of this event is an array of the objects that are put in the second error message; with no objects, the array has no items.
if the label of the trap is not there, the program ends with a language error, as with no trap.

```
USER usercondition
RAISE USER usercondition
```
this event is raised when the event you name after the keyword in the first line of the code comes, with call on or signal on.
the raise instruction with the same name after the same keyword raises it.
the name of the event can be any symbol, also the name of an other event.
the description of this event is the string you give with the description option of the raise instruction; if you do not give it, it is empty.
the additional data of this event is any object you give with the additional option or the array option of the raise instruction.
you can use call on or signal on for this event.

```
not trapped
INTERPRET string
```
when the trap of an event is off and the event is raised, the program does a default thing for each kind of event.
for a halt event, or an event of a message with no method, the program raises the event of a language error, with the rexx error number.
for the event of a language error, the clause with the error ends.
then the event goes back to each call instruction, each message, and each instruction in the second line of the code, that is running, and to each clause with a function or message that is running.
each of these ends, if there is no trap on for the event at its level.
if no level traps the event, the program stops.
a message that says what the error is comes, as a rule.
for each other event, the program ignores it, and the trap is off as before.

```
trapped
SIGNAL trapname
CALL trapname
```
when the trap of an event is on and the event is raised, the program runs a call or a signal to the name of the trap.
with signal, the instruction that runs now stops then, the trap goes off, and the signal goes on as a signal does.
so to trap that event again, the program must run a new call on or signal on after the label.
with call, the routine runs when the clause that runs now ends.
the call does not change the special variable result, and the program ignores any data the routine gives back.
when the routine returns, the program goes on as before.
when the event is raised, the trap is delayed, before the call.
the trap is delayed until the program runs a call on or a signal on for that event; then the call or the signal is done then.
or it is delayed until the program runs a call off or a signal off for that event; then the trap is off, and the default thing is done at the end of that instruction.
or it is delayed until the routine returns; then the trap is not delayed, and the program calls the routine again then.
while the trap is delayed, the program ignores an error or failure event that is raised again.
for other events, what the program does waits until the trap is not delayed.
an event is raised when the program finds it, and not after.
with signal, the instruction that runs ends, so it can be only a part done.
so if the event of a language error is raised in the expression of an assignment, the assignment is not done.
a call trap runs only at the end of a clause.
the program stores the state and the name of each trap when a subroutine starts, and they come back when it returns.
so a change to a trap in a subroutine does not change the trap of the caller.
a call to an external routine does not change the state of the traps, also when it is a rexx program.
when any rexx program starts, all traps are off.
while you trace and the program is interactive, all traps are off while the program reads the input you give.
an error of the language at that time does not end the program: the program traps it, says a message, and then ignores it.
a signal on trap can not trap some error that the computer finds before the program starts or after it ends.

```
CONDITION(option)
```
when a trapped event makes a signal or a call, it is the trapped event now, and the program stores data about it.
the data has the name of the event.
the data has the name of the instruction that runs for the trap: call or signal.
the data has the state of the trapped event.
the data has a description: a string about the event.
the data can have an additional object.
you get this data with this function.
the data changes when the program goes to a label for a trap, with call on or signal on.
the program stores the data when a routine, a function, or a method starts, and the data comes back when it returns.
a routine that a call on trap calls can get the data of its event.
the data from before is there again after that routine returns.

```
RC
```
this is a special variable.
when an error or failure event is trapped, this variable gets the return code of the command, before the program goes to the label.
this is so with call and with signal.
when a signal on trap traps a language error, this variable gets the error number, before the program goes to the label.

```
SIGL
PARSE SOURCE template
```
this is a special variable.
after a call or a signal, this variable has the number of the line of the clause that made the program go there.
when a trap makes the call or the signal, this variable has the number of the line of the last clause that runs at the level of that routine, before the call or signal.
it is of use after a signal on trap of a language error: it says the line with the error.
the code after the label can use the parse instruction in the second line of the code to find the file, and then call a program to change the line with the error.
you can use it to find what makes an error.
the code:
```rexx
signal on syntax
a = a + 1      /* This is to create a syntax error */
say "SYNTAX error not raised"
exit

/* Standard handler for SIGNAL ON SYNTAX */
syntax:
say "Rexx error" rc "in line" sigl":" "ERRORTEXT"(rc)
say "SOURCELINE"(sigl)
trace ?r; nop
```
the result:
```
Rexx error 41 in line 2: Bad arithmetic conversion.
a = a + 1      /* This is to create a syntax error */
```

```
CONDITION('O')
ADDITIONAL     the additional object; set by the ADDITIONAL or ARRAY option of RAISE
DESCRIPTION    a string about the event
INSTRUCTION    CALL or SIGNAL
CONDITION      the name of the trapped event
RESULT         a result given on the RETURN or EXIT option of RAISE
RC             the major Rexx error number (SYNTAX)
CODE           nn.nnn error code (SYNTAX)
ERRORTEXT      the primary error message (SYNTAX)
MESSAGE        the secondary error message (SYNTAX)
PACKAGE        the Package object of the program
POSITION       the line number where the event was raised
PROGRAM        the name of the program
STACKFRAMES    a list of StackFrame objects
TRACEBACK      a list of formatted traceback lines
PROPAGATED     .false, or .true if raised again with RAISE PROPAGATE
```
the condition object is a directory.
this function gives it when you give the object option.
it has all the data there is now about the trapped event.
the data is not the same for each kind of event.
for an index that has no data for the event, it gives nil.
it has the additional object, the description, the instruction, and the name of the event, the same as the other options of this function.
it has the result that the raise instruction gives with its return or exit option.
for a language error, it has the error number, the same as the special variable rc.
for a language error, it has a code: the integer part is the error number, and the fractional part says which error it is, with more data.
for a language error, it has the first error message and the second error message.
it has the package object and the name of the program where the event is raised.
it has the number of the line where the event is raised.
it has a list of the lines of the trace back from the event.
it says false if the event is raised at the level of the trap, and true if the raise instruction raises it again with the option in the last line of the code.
