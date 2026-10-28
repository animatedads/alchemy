# keyword instructions of rexx, the second part

these facts are from the oorexx language rules, about some of the keyword instructions.

```
NOP
```
nop: an instruction that does no thing
this instruction does no thing.
this instruction can be the instruction after then or else.
this instruction is a true instruction, so it can be the instruction after then.
an empty clause is not an instruction, so it can not be the instruction after then.
if you put a semicolon in place of this instruction, you put a null clause there, and the language ignores a null clause.
without this instruction after then, the next when clause is the first instruction after then, and that is an error.
in the code after, when the two variables of the first when are equal, the program does no thing.
the code:
```rexx
Select
  when a=c   then nop           /* Do nothing */
  when a > c then say "A > C"
  otherwise       say "A < C"
end
```
the result:
```
A < C
```

```
NUMERIC DIGITS [expression1]
NUMERIC FORM [SCIENTIFIC | ENGINEERING | [VALUE] expression2]
NUMERIC FUZZ [expression3]
```
numeric: an instruction that changes the way a program does maths
this instruction changes the way a program does maths.
this instruction has three keywords, and each keyword has a value.
the language keeps the values of this instruction for the caller when a program calls an internal subroutine or an internal function.
```
NUMERIC DIGITS
```
the value of digits is the precision of maths and of builtin functions.
if you omit the expression after digits, the precision is 9 digits.
a program file can change this default with an options directive.
the value of the expression after digits must be a positive whole number.
the precision has no maximum, other than the memory of the computer.
with more digits, maths can take more time.
use the default precision when you can.
the digits builtin function returns the value of digits now.
```
NUMERIC FORM
```
this keyword says how the computer writes the results of maths and of builtin functions with an exponent.
```
NUMERIC FORM SCIENTIFIC
```
with this keyword, only one digit that is not zero is before the point.
this keyword is the default.
a program file can change this default with an options directive.
```
NUMERIC FORM ENGINEERING
```
with this keyword, the exponent is always a whole number times three.
```
NUMERIC FORM VALUE expression2
```
if you do not give one of the two keywords before, the way is the value of the expression.
the value of the expression must be the name of one of the two keywords before.
you must write value before the expression only when the expression starts with a symbol.
you can omit value when the expression starts with a literal or with a special character, as an operator or one of the parentheses.
```
FORM()
```
the builtin function in the code before returns the value of this keyword now.
```
NUMERIC FUZZ
```
this keyword says how many digits the computer ignores when it compares two numbers.
if you omit the expression after this keyword, the value is 0.
a program file can change this default with an options directive.
the value of the expression after this keyword must be 0 or a positive whole number.
if it has to, the computer can round this value with the precision of digits.
the value of this keyword must be less than the value of digits.
when the computer compares two numbers, it gets the difference of the two numbers with a precision of digits less the value of this keyword, and then it compares that difference with 0.
```
FUZZ()
```
the builtin function in the code before returns the value of this keyword now.

```
OPTIONS expression
```
this instruction gives special options to the program that runs rexx code.
this instruction gets the value of the expression, and the program that runs rexx code does what each word of that value says, if the word is known to it.
the program that runs rexx code ignores each word that is not known to it, as the word can be for an other program that runs rexx code.
no option keyword is known to oorexx, so no word in the value changes what oorexx does.

```
PARSE [UPPER | LOWER] [CASELESS] ARG [template_list]
```
this instruction can parse the arguments that a caller gives to a program, a routine, or a method.
it uses the string value of each argument object.
with upper, the parse instruction changes each letter of the strings to upper before the parse.
with lower, the parse instruction changes each letter of the strings to lower before the parse.
without upper or lower, the parse instruction does not change the letters.
you can use caseless with upper, or with lower, in any order.
with caseless, each compare of strings in the parse is caseless: a letter in upper is equal to the same letter in lower.
a template list is one template, or more than one template with a comma between each template and the next template.
a template is one or more symbols, or patterns, or both, with blanks between them.
the parse instruction uses each template on one string.
more than one template is not an error, but only this instruction can give more than one string that is not null.
with no template, no variable gets a value.
```
USE ARG
ARG()
```
the instruction and the builtin function in the code before can get the argument objects, or test them.

```
PARSE [UPPER | LOWER] [CASELESS] LINEIN [template_list]
```
this instruction can parse the next line of the default input stream.
this instruction is a short way to write an other instruction.
if no line is there yet, the program can wait until a whole line is there.
this instruction does not read from the external data queue.
use the lines builtin function to test if there are lines to read.
```
PULL
PARSE PULL
```
to read each line you give to a program, one at a time, use the code before.

```
PARSE [UPPER | LOWER] [CASELESS] PULL [template_list]
```
this instruction can parse the next string of the external data queue.
if the queue is empty, this instruction reads a line from the default input stream, and the program waits if it has to.
```
PUSH
```
the instruction before puts a line at the start of the queue.
the queue instruction puts a line at the end of the queue.
the queue is there while the program that runs rexx code is running, and other programs can change it.
```
QUEUED()
```
the builtin function in the code before returns the count of lines in the queue.

```
PARSE [UPPER | LOWER] [CASELESS] SOURCE [template_list]
```
this instruction can parse data about the program, the routine, or the method that is running.
the first word of the data is the name of the program that runs the computer.
the second word of the data says how the code runs.
the second word is command when the code runs as a command.
the second word is function when an expression calls the code as a function.
the second word is subroutine when a call instruction calls the code.
the second word is method when the code runs as a method of an object.
```
REQUIRES
::REQUIRES
```
the second word is the word in the first line of the code before when the directive in the second line of the code before makes the code run.
the third part of the data is the path of the program file, or the name of a package, routine, or method instance.
```
INSTORE
rexx -e
```
the third part is the word in the first line of the code before when the code runs with the command in the second line of the code before.
the code after has two strings that this instruction can parse.
the code:
```rexx
WindowsNT COMMAND C:\Program Files\ooRexx\rexxtry.rex
LINUX COMMAND /usr/local/bin/rexxtry.rex
```
the result:
```
20.923
```

```
PARSE [UPPER | LOWER] [CASELESS] VALUE [expression] WITH [template_list]
```
this instruction can parse the string that is the value of the expression.
if you omit the expression, this instruction uses the null string.
with is a keyword here, so outside a part between parentheses, with can not be a symbol in the expression.
the code after gets the time now and puts three parts of it in three variables.
the code:
```rexx
PARSE VALUE time() WITH  hours ":" mins ":" secs
```
the result:
```
```

```
PARSE [UPPER | LOWER] [CASELESS] VAR name [template_list]
```
this instruction can parse the string value of the variable with that name.
the name must be a variable symbol, and it can not start with a point or a digit.
the variable changes only if its name is in the template.
```
NOVALUE
```
if the variable is uninitialized, the condition in the code before is raised, when its trap is on.
the first line of the code after puts the first word of the variable string in an other variable, and puts the rest back in string.
the second line of the code after does the same, but it changes the letters to upper before the parse.
the code:
```rexx
PARSE VAR string word1 string
PARSE UPPER VAR string word1 string
```
the result:
```
```

```
PARSE [UPPER | LOWER] [CASELESS] VERSION [template_list]
```
this instruction can parse a string of five words, with a blank between two words.
```
REXX-ooRexx_5.0.0(MT)_64-bit
```
the first word is a string like the code before, for oorexx five for a computer with 64 bits.
the second word is a number for the language, as 6.05 for oorexx 5.0, or 6.04 for oorexx 4.2.
```
1 Sep 2016
DATE()
```
the last three words say the time when this oorexx is made, as in the first line of the code before.
these three words are in the same way as the default value of the builtin function in the second line of the code before.

```
PROCEDURE [EXPOSE name | (name) ...]
```
this instruction is optional in an internal routine.
if you use this instruction, it must be the first instruction that runs after the call: the first instruction after the label.
this instruction makes the variables of the caller not known to the next instructions of the routine.
after the return, the caller has its variables back, and the language makes the variables that the routine used have no value, other than the exposed variables.
without this instruction, the routine uses the variables of the caller.
with expose, each name you give is a variable of the caller.
when the routine reads an exposed variable, assigns it, or makes it have no value, it does that to the variable of the caller, and the change is there after the return.
the routine can make new exposed variables, and the caller can use them after the return.
each name must be a symbol that can be the name of a variable, with blanks between the names.
for a name between parentheses, this instruction first makes that variable exposed, then it uses its value as a list of more names.
you can omit blanks in and outside the parentheses.
the list of names in that value has the same rules, but it can not have parentheses.
this instruction makes the names exposed in order, from left to right.
a name you give two times is not an error.
a name of a variable that the caller never used is not an error.
the variables of the caller that are not exposed keep the values they have.
if you expose a stem, you expose the stem and each compound variable whose name starts with it, also compound variables that are not there yet.
in the first part of the code after, the compound symbol must be after the symbol of its tail in the list.
if the compound symbol is before the symbol of its tail, the tail is not a variable of the caller yet, so the compound variable with the tail 1 is not exposed.
to expose a variable to a routine that an other routine calls, each procedure instruction between them must expose it too.
the code:
```rexx
/* This is the main Rexx program */
j=1; z.1="a"
call toft
say j k m       /* Displays "1 7 M"          */
exit

/* This is a subroutine     */
toft: procedure expose j k z.j
  say j k z.j   /* Displays "1 K a"          */
  k=7; m=3      /* Note: M is not exposed    */
  return

/* This is the main Rexx program */
j=1;k=6;m=9
a ="j k m"
call test
exit

/* This is a subroutine     */
test: procedure expose (a)   /* Exposes A, J, K, and M     */
  say a j k m                /* Displays "j k m 1 6 9"     */
  return

/* This is the main Rexx program */
c=11; d=12; e=13
Showlist="c d"     /* but not E              */
call Playvars
say c d e f        /* Displays "11 New 13 9" */
exit

/* This is a subroutine     */
Playvars: procedure expose (showlist) f
  say word(showlist,2)              /* Displays "d"                     */
  say value(word(showlist,2),"New") /* Displays "12" and sets new value */
  say value(word(showlist,2))       /* Displays "New"                   */
  e=8                               /* E is not exposed                 */
  f=9                               /* F was explicitly exposed         */
  return

/* This is the main Rexx program */
a.=11; i=13; j=15
i = i + 1
C.5 = "FRED"
call lucky7
say a. a.1 i j c. c.5
say "You should see 11 7 14 15 C. FRED"
exit

lucky7:Procedure Expose i j a. c.
  /* This exposes I, J, and all variables whose     */
  /* names start with A. or C.                      */
  A.1="7"  /* This sets A.1 in the caller's         */
           /* environment, even if it did not       */
           /* previously exist.                     */
  return
```
the result:
```
1 K a
1 7 M
```

```
PULL [template_list]
```
pull: an instruction that reads a line from the start of the queue
this instruction reads the line at the start of the external data queue.
if the queue is empty, this instruction reads from the default input stream.
this instruction reads the line as one string.
with no template, this instruction does no more with the string.
this instruction can parse only one string, also with more than one template.
with more than one template, each variable in each template after the first template gets the null string.
before the parse, this instruction changes each letter of the string to upper.
to keep the letters as they are, use parse pull.
if the queue is empty, the program waits until the line from the input stream is whole.
```
PARSE UPPER LINEIN
```
when the queue is empty, this instruction does what the code before does.
when this instruction reads from the input stream, it says no text before it waits.
```
QUEUED()
```
the builtin function in the code before returns the count of lines in the external data queue.
in the code after, the point in the template is a placeholder, so no variable gets the rest of the line.
in the code after, the if test is true for no in upper and in lower, as this instruction changes each letter to upper.
the code:
```rexx
Say "Do you want to erase the file?  Answer Yes or No:"
Pull answer .
if answer="NO" then say "The file will not be erased."
```
the result:
```
Do you want to erase the file?  Answer Yes or No:
```

```
PUSH [expression]
```
push: an instruction that puts a line at the start of the queue
this instruction puts the string value of the expression in the external data queue.
this instruction puts the string at the start of the queue, so the last line you push is the first line you take out.
if you omit the expression, this instruction puts a null string in the queue.
```
QUEUED()
```
the builtin function in the code before returns the count of lines in the external data queue.
the code:
```rexx
a="Fred"
push       /* Puts a null line onto the queue */
push a 2   /* Puts "Fred 2"    onto the queue */
```
the result:
```
```

```
QUEUE [expression]
```
this instruction puts the string value of the expression at the end of the external data queue.
so the first line you put in the queue is the first line you take out.
if you omit the expression, this instruction puts a null string at the end of the queue.
```
QUEUED()
```
the builtin function in the code before returns the count of lines in the external data queue.
the code:
```rexx
a="Toft"
queue a 2  /* Enqueues "Toft 2" */
queue      /* Enqueues a null line behind the last */
```
the result:
```
```

```
RAISE condition [options]
RAISE ERROR errorcode [options]
RAISE FAILURE failurecode [options]
RAISE SYNTAX number [options]
RAISE USER usercondition [options]
RAISE PROPAGATE [options]

options:
  [ADDITIONAL expra | ARRAY (expri [, expri]...)]
  [DESCRIPTION exprd]
  [EXIT [expre] | RETURN [exprr]]
```
this instruction does a return or an exit from the routine or the method that runs now.
then a condition is raised in the caller of the routine or the method.
this instruction can raise any condition that a trap can get.
```
ADDITIONAL
ARRAY
DESCRIPTION
RETURN
EXIT
```
you can write the keywords in the code before in any order.
but an exit or a return without an expression must be the last keyword.
```
RAISE ERROR errorcode
RAISE FAILURE failurecode
```
for each condition in the code before, you must give the return code.
the return code can be a literal, a constant symbol, an environment symbol, or an expression between parentheses.
```
RAISE SYNTAX number
```
for this condition, you must give a rexx error number.
the error number can be a whole number, or a number with a point and a part after the point.
the error number can be a literal, a constant symbol, or an expression between parentheses.
```
RAISE USER usercondition
```
for this condition, you must give the name of the condition, as a symbol that is a constant.
```
ADDITIONAL expra
ARRAY (expri, ...)
```
these two keywords give more data about the condition.
the value of the first keyword is an object with more data about the condition.
the first keyword can have a literal, a constant symbol, an environment symbol, or an expression between parentheses.
after the second keyword, you give a list of expressions, with a comma between two expressions.
the second keyword makes an array of the values of the expressions, and the caller gets it in the same way as the value of the first keyword.
you can not use both keywords in one instruction; that is an error.
the data of these keywords is the text of the second error message.
without these keywords, the condition has no more data.
```
RAISE SYNTAX number ADDITIONAL expra
```
for this condition, the value of the first keyword must be an array where each index is one whole number.
```
CONDITION('A')
```
the caller can get the data of these two keywords from the condition object, or with the code before.
```
DESCRIPTION exprd
```
the value after this keyword is a text that says what the condition is.
the value can be a literal, a constant symbol, an environment symbol, or an expression between parentheses.
if you omit this keyword, the text is a null string.
```
CONDITION('D')
```
the caller can get this text from the condition object, or with the code before.
```
RETURN exprr
EXIT expre
```
with return or exit, the value of the expression is a result object that the caller gets as the result of the return or the exit.
the expression can be a literal, a constant symbol, an environment symbol, or an expression between parentheses.
without the expression, the caller gets no result, the same as with a return or exit instruction with no expression.
exit is the default.
the caller can get the result from the condition object.
```
RAISE PROPAGATE
```
with this keyword, the condition that a trap has now is raised again in the caller.
the other keywords of this instruction, if you give them, change the values of that condition.
if no trap has a condition now, that is an error.
after the return or the exit, the caller does what the rules for that condition say, when no trap in the caller gets it.
the code:
```rexx
raise syntax 40                      /* Raises syntax error 40                */
raise syntax 40.12 array (1, number) /* Raises syntax error 40, subcode 12    */
                                     /* Passing two substitution values       */
raise syntax (errnum)                /* Uses the value of the variable ERRNUM */
                                     /* as the syntax error number            */
raise user badvalue                  /* Raises user condition BADVALUE        */

signal on syntax
a = "xyz"
c = a+2                /* Raises the SYNTAX condition             */
.
.
.
exit
syntax:
  raise propagate      /* Propagates SYNTAX information to caller */
```
the result:
```
40
```

```
REPLY [expression]
```
this instruction sends a reply from a method to its caller before the end of the method.
the method goes back to the place where the caller sent the message, with a result if there is one.
then the method goes on to run in a new activity.
with an expression, this instruction gives the value of the expression back to the caller.
without an expression, no object goes back to the caller.
after this instruction, the method runs until it runs an exit or a return instruction.
that exit or return must not have a result expression.
you can use this instruction only in a method.
a method can run this instruction only one time.
if the method is the only method on the activity that can use the variable pool of its object, it keeps that use on the new activity.
if other methods on the activity can also use that pool, the method gives that use back, and gets it again on the new activity.
to get that use again, the method may have to wait until the first activity gives its use back.
in the code after, the reply gives the result 42 to the caller, and the call can run at the same time as the caller.
the code:
```rexx
reply 42           /* Returns control and a result    */
call tidyup        /* Can run in parallel with sender */
return
```
the result:
```
99.919
```

```
RETURN [expression]
```
this instruction goes back from a program, a method, or a routine to the place where its caller calls it, with a result if you give one.
if no internal routine runs now, return and exit do the same thing to the program.
in a subroutine, this instruction gets the value of the expression, if there is one, and goes back to the caller.
then the special variable result has the value of the expression.
if you omit the expression, the language makes the variable result have no value.
the values that the language keeps at the call, as the trace option, come back.
in a function, this instruction does the same as in a subroutine, but you must give an expression.
the caller uses the result in the expression where it calls the function.
in a method, this instruction gets the value of the expression, if there is one, and goes back to the place where the caller sent the message.
if the message is a part of an expression, you must give an expression.
if the message is all of the instruction, the expression is optional, and the variable result gets its value.
if the method runs a reply instruction before this return, this instruction must not have a result expression.
after a procedure instruction in an internal routine, the language makes the variables of the routine have no value after the expression gets its value, and before the caller uses the result.
then the variables of the caller are back.
```
Unix-like systems
```
on a computer of the kind in the code before, the number that a program returns to the computer can only be from 0 to 255.
on that kind of computer, with no expression, the number is 0.

```
SAY [expression]
```
this instruction writes a line to the default output stream.
this instruction writes the string value of the expression.
the string can have any length.
if you omit the expression, this instruction writes the null string.
```
CALL LINEOUT
NOTREADY
```
this instruction is a short way to write the call in the first line of the code before, but there are some changes.
this instruction does not change the special variable result.
this instruction writes a null string when you omit the expression.
the call can raise the condition in the second line of the code before, but this instruction can not.
this instruction does not change the data in any way.
if a line has to go on the next line, the computer does that, and the output is one line.
the code:
```rexx
data=100
Say data "divided by 4 =>" data/4
```
the result:
```
100 divided by 4 => 25
```
the reference says:
```
100 divided by 4 => 25
```

```
SELECT [CASE case_expression];
  WHEN expression [, expression]... THEN instruction
  WHEN ...
  [OTHERWISE [instructions]]
END
```
select: an instruction that runs one of a list of instructions, after a test
if there is no expression after select, this instruction gets the value of each expression in the list of a when, from left to right.
each of these expressions must be true or false.
the instruction stops at the first false value, and that is the result of the when.
if each value is true, the result of the when is true.
```
CASE case_expression
==
```
with the keyword in the first line of the code before, the instruction gets the value of the expression after it one time, before the first when.
then it compares the value of each expression of a when to that value, with the operator in the second line of the code before.
it stops at the first true compare, and that is the result of the when.
if each compare is false, the result of the when is false.
if the result of a when is true, the instruction after then runs, and then the program goes to the end.
if the result of a when is false, the program goes to the next when.
```
OTHERWISE
```
if no when is true, the program runs the instructions after this keyword, if there are any.
if no when is true and there is no keyword as in the code before, that is an error.
you can omit the instructions after this keyword.
the instruction after then can be any assignment, command, message, or keyword instruction, also a do, a loop, an if, or a select.
a null clause is not an instruction.
a semicolon or a label after then is not an instruction that does no thing; for that, use nop.
outside a part between parentheses, then can not be in an expression, so then can end the expression of a when without a semicolon.
in the second part of the code after, the list of a when stops at the first false value.
so when the value is not a whole number, the program does not get the value of the second expression of the when.
```
&
```
with the operator before in place of the comma, the program gets the value of both expressions, and that can be an error when the value is not a number.
the code:
```rexx
balance=100
check=50
balance = balance - check
Select
  when balance > 0 then
    say "Congratulations! You still have" balance "dollars left."
  when balance = 0 then do
    say "Warning, Balance is now zero!  STOP all spending."
    say "You cut it close this month! Hope you do not have any"
    say "checks left outstanding."
    end
  Otherwise do
    say "You have just overdrawn your account."
    say "Your balance now shows" balance "dollars."
    say "Oops!  Hope the bank does not close your account."
    end
end  /* Select */

select
  when answer~datatype('w'), answer//2 = 0 Then
     say answer "is even"
  when answer~datatype('w'), answer//2 = 1 Then
     say answer "is odd"
  otherwise
     say answer "is not a number"
end

select case random(6)
  when 1 then say "bad luck!"
  when 5, 6 then say "great!"
  otherwise say "try again"
end
```
the result:
```
Congratulations! You still have 50 dollars left.
ANSWER is not a number
great!
```

```
SIGNAL labelname
SIGNAL [VALUE] expression
```
this instruction goes to a label and does not come back.
the name of the label is the symbol or the literal after this instruction, or the string value of the expression after value.
the name must be a literal string or a symbol that is a constant.
with a symbol, the instruction goes to a label whose letters are upper.
with a literal, the instruction uses the string the way you write it.
the instruction can go to a label with letters in lower only when you give a literal with the same letters in lower.
with value, each letter of the string must be the same as in the label, in upper or in lower.
you can omit value when the expression starts with a special character, as an operator or one of the parentheses, and not with a symbol or a literal.
the instruction gets the label as if it starts at the start of the program.
if two labels have the same name, the program goes to the first of them in the program.
```
DO
IF
SELECT
INTERPRET
```
each instruction of the kind in the code before that runs now in this routine ends, and it can not go on again.
```
SIGL
```
when the program gets to the label, the special variable in the code before gets the number of the line of this instruction.
with it you can debug, as you can know the line where the program goes from.
the code:
```rexx
Signal fred;  /* Transfer control to label FRED below */
....
....
Fred: say "Hi!"
```
the result:
```
Hi!
```

```
SIGNAL ON condition [NAME trapname]
SIGNAL ON USER usercondition [NAME trapname]
SIGNAL OFF condition
SIGNAL OFF USER usercondition
```
with on or off, this instruction is about the trap of a condition.
you give on or off, and the condition that you want a trap for.
with off, this instruction makes the trap of the condition off.
with on, this instruction makes the trap of the condition on.
```
USER usercondition
```
the name after this keyword is one symbol, and it is a constant.
```
NAME trapname
```
the name after this keyword is a string or a symbol, and it is a constant.

```
TRACE [number | [?][option]]
TRACE [VALUE] expression
```
this instruction says what the trace writes to you while the program runs.
the trace writes about some clauses or all clauses as they run.
you use this instruction to debug.
the options of this instruction are short, as you can write it while you debug in an interactive way.
```
macrospace
```
you can not use this instruction in the rexx place in the code before.
a number option must be a whole number.
the string or the value of the expression can be a number option, a question mark option, a letter option, or null.
a symbol that is a constant must be a number option, a question mark option, or a letter option.
the option after this instruction, or the string value of the expression, says what the trace does.
you can omit value when the expression starts with a special character, as an operator or one of the parentheses, and not with a symbol or a literal.
for a letter option, you only have to write the first letter; the instruction ignores the other letters.
```
TRACE A
```
with this option, the trace writes each clause before it runs.
failure: the name of a condition that a command can raise
```
TRACE C
```
with this option, the trace writes each command before it runs.
if the command gives an error or a failure, the trace also writes its return code.
```
TRACE E
```
with this option, the trace writes each command that gives an error or a failure, after it runs, with its return code.
```
TRACE F
TRACE N
```
with these two options, the trace writes each command that gives a failure, after it runs, with its return code.
the option in the second line of the code before is the default, if an options directive does not change it.
```
Windows CMD
```
with the command program in the code before, a command that it does not know gives a failure, and the return code is 1.
a command for an environment that is not known gives a failure, and the return code is 30.
```
TRACE I
```
with this option, the trace writes each clause before it runs, and also each result in the middle of an expression.
```
TRACE L
```
with this option, the trace writes each call of a method or a routine, each call of an internal subroutine, each go to a label by signal, and each label the program gets to.
this option is of use when you debug in an interactive way, as the program waits after each call.
```
TRACE O
```
with this option, the trace writes no thing, and the question mark option is off.
```
TRACE R
```
with this option, the trace writes each clause before it runs, and the last result of each expression.
```
PULL
ARG
PARSE
USE
```
with this option, the trace also writes each value that the instructions in the code before assign.
use this option to debug.
```
TRACE ?
```
this option can be the only option, or it can be before a letter option.
you can write this option more than one time; each one changes back what the one before it does.
you can not put a blank between this option and the letter option.
with this option, you make an interactive debug on or off.
when the program runs and is not in an interactive debug, a trace option with this mark makes an interactive debug on.
while the interactive debug is on, the program waits after each clause that the trace writes, but some clauses.
in an interactive debug, the program ignores each trace instruction in it.
```
TRACE ?E
```
with the code before, the program waits after each command that gives an error: a return code that is not zero, or an error condition from the command environment.
```
TRACE O
```
the code before makes all trace off.
```
TRACE
```
the code before makes the default trace again: the interactive debug is off, and the trace is as with the default letter option.
```
TRACE ?
```
the code before makes the interactive debug off, and keeps the trace option it has now.
a trace instruction with this mark before its option makes the interactive debug off, and uses the new option.
```
CALL TRACE "?"
```
as the program ignores its trace instructions in an interactive debug, use the code before to make the interactive debug off from the program.
```
TRACE number
```
the program uses a number option only in an interactive debug.
with a positive whole number, the number is the count of times the debug does not wait.
with a negative whole number, there is no trace and no debug wait for that count of clauses.
```
TRACE -100
```
with the code before, the trace does not write the next 100 clauses it can write; then the trace goes on as before.

```
USE ARG [name [= expr]] [, [name [= expr]]]...
```
this instruction gets the argument objects of a program, a routine, or a method.
each name can be a variable, or any other code that can be at the left of an assignment, as in the last part of the code after.
this instruction assigns the names in order, from left to right.
each name gets the argument at the same position.
if there is no argument for a name, and the name has no default, the variable of that name has no value.
with an expression after the equal mark, the value of that expression is the default when the argument is not there.
the default must be a literal, a constant symbol, an environment symbol, or an expression between parentheses.
```
variable reference term
```
for a name of the kind in the code before, you must never omit the argument, and the name can not have a default.
for a name that is a message, this instruction does no thing when the argument is omitted.
you can run this instruction more than one time, and it always gets the same arguments.
```
ARG
PARSE ARG
```
the instructions in the code before get the string values of the arguments, and make them strings before the parse.
this instruction assigns each argument object to one name, with no change and no parse.
this instruction can get arguments that are not strings.
use this instruction when you want the argument objects.
```
ARG()
```
the builtin function in the code before can also get the arguments, or test them.
in the second part of the code after, the routine changes an item of the stem and an item of the array, and the caller can use the changes.
the code:
```rexx
/* USE Example                       */
/* FRED("Ogof X",1,5) calls function */
Fred: use arg string, num1, num2

/* Now: STRING contains "Ogof X"     */
/*      NUM1 contains "1"            */
/*      NUM2 contains "5"            */

/* Another example, shows how to pass non-string arguments with USE ARG */
/* Pass a stem and an array to a routine to modify one element of each  */
stem.1 = "Value"
array = .array~of("Item")
say "Before subroutine:" stem.1 array[1]  /* Shows "Value Item"         */
Call Change_First stem. , array
say "After subroutine:" stem.1 array[1]   /* Shows "NewValue NewItem"   */
Exit

Change_First: Procedure
  Use Arg substem., subarray
  substem.1 = "NewValue"
  subarray[1] = "NewItem"
  Return

::method myMethod
expose myArray myDirectory
use arg myArray[1], myDirectory~name
/* is the same as: */
myArray[1] = arg(1)
myDirectory~name = arg(2)
```
the result:
```
Before subroutine: Value Item
After subroutine: NewValue NewItem
```

```
USE STRICT ARG [name [= expr]] [, [name [= expr]]]... [, ...]
```
```
USE ARG
```
this instruction is like the instruction in the code before, but it tests the count of the arguments.
the count of the arguments must be the same as the count of the names, or that is an error.
a name with a default is optional.
```
...
```
with the three point marks of the code before after the last name, more arguments can come after the names.
then the names with no default give the minimum count of arguments, and the caller can give more arguments after them.
in the first part of the code after, two or three arguments are what the routine can take, and an other count is an error.
in the second part of the code after, the routine must get one argument or more.
the code:
```rexx
/* USE STRICT Example                */
/* FRED("Ogof X",1) calls function  */
Fred: use strict arg string, num1, num2=4

/* Now: STRING contains "Ogof X"     */
/*      NUM1 contains "1"            */
/*      NUM2 contains "4"            */

call test "one"
call test "one", "two"
call test "one", "two", "three"
call test "one", , "three", "four", "five"
exit

test: procedure /* a minimum of one argument must be supplied */
  use strict arg v1, v2="zwei", ...
  say "There are ["arg()"] argument(s); v1,v2=["v1","v2"]"
  do i=3 to arg()
    say " arg #" i"=["arg(i)"]"
  end
  say "--"
  return

/* output: */
There are [1] argument(s); v1,v2=[one,zwei]
--
There are [2] argument(s); v1,v2=[one,two]
--
There are [3] argument(s); v1,v2=[one,two]
 arg # 3=[three]
--
There are [5] argument(s); v1,v2=[one,zwei]
 arg # 3=[three]
 arg # 4=[four]
 arg # 5=[five]
--
```
the result:
```
35.1
```

```
USE LOCAL [name ...]
```
this instruction says which variables of a method are local.
without this instruction, each variable of a method is local, and a method must expose a variable of its object.
with this instruction, each name you give is local, and each other variable is a variable of the object.
each name must be a variable that is not compound, or a stem.
a compound variable can not be a name in this instruction.
with no name, each variable is a variable of the object.
if this instruction is in a method, it must be the first instruction of the method.
```
RC
RESULT
SIGL
SELF
SUPER
```
the special variables in the code before are always local, also when you do not give the names of them.
the code:
```rexx
::method init
use local x y z   -- only x, y, and z are local
                  -- all other become object variables

::method init2
use local         -- any variable is an object variable
```
the result:
```
```
