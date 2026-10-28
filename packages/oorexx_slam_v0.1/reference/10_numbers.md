# rexx numbers, arithmetic, keywords, and special variables

these facts are from the oorexx language rules, the parts about numbers and arithmetic, the keywords of the language, and the special variables.

## words i add

operation: one use of an operator, as one add or one divide
fuzz: the name of a numeric option; it says how many digits a numeric compare does not use
strip: the name of a method and of a builtin function
lostdigits: the name of a condition
twice: two times
scientific: the scientific form of a number has one digit that is not zero before the point
engineering: the engineering form of a number has an exponent that you can divide by three with no remainder
overflow: an error when the exponent of a result is more than the language can use
underflow: an error when the exponent of a result is less than the language can use
syntax: the rules of how to write code in a language
source: the source file of a program is the file with its code
small: with a value that is less
big: with a value that is more
rounds: round, for one thing
truncates: truncate, for one thing
raises: raise, for one thing
drops: drop, for one thing
format: the name of a builtin function
limit: the maximum or the minimum that a thing can have
limits: more than one limit
enough: as many as you need
largest: the one that is more than each other one
exponents: more than one exponent
reserved: a reserved word has a special use for the language in some places
version: the number of one form of a program or a language
sigl: a special variable; it has the number of the line of the last instruction that made the program go to a label

## numbers

```
" +  0.003 "
```
a number can have blanks or a tab at the start and at the end.
a number can have a sign: a plus or a minus.
a number has one decimal digit or more, from zero to nine.
a number can have a period in its digits, as the decimal point.
a period with no digits is not a number.
a number can have an exponent.
the code:
```rexx
12             /* a whole number                      */
"-76"          /* a signed whole number               */
12.76          /* decimal places                      */
" +  0.003 "   /* blanks around the sign and so forth */
17.            /* same as 17                          */
.5             /* same as 0.5                         */
4E9            /* exponential notation                */
0.73e-7        /* exponential notation                */
```
the result:
```
```

## results of arithmetic

```
2.40 + 2
```
the arithmetic operators are add, subtract, multiply, power, divide, prefix plus, prefix minus, integer divide, and remainder.
the integer divide operator gives the integer part of the divide.
the remainder operator gives the remainder of the divide.
rexx gets the result of arithmetic to a maximum count of digits; the default is 9.
if a result needs more digits, rexx rounds it.
you can change the default for a source file with the options directive, or when the program runs with the numeric digits instruction.
rexx keeps the zero digits at the end of a result, but not for divide and power.
to take away zero digits at the end, use the strip method, the strip builtin function, or divide by 1.
a result that is zero is always the one digit 0.
a result has an exponent when it has more digits before the point than the numeric digits precision, or more than twice that count of digits after the point.
the code:
```rexx
say 2 / 3
```
the result:
```
0.666666667
```
the reference says:
```
0.666666667
```

the code:
```rexx
say 2.40 + 2
```
the result:
```
4.40
```
the reference says:
```
4.40
```

the code:
```rexx
say 2.40 - 2
```
the result:
```
0.40
```
the reference says:
```
0.40
```

the code:
```rexx
say 2.40 * 2
```
the result:
```
4.80
```
the reference says:
```
4.80
```

the code:
```rexx
say 2.40 / 2
```
the result:
```
1.2
```
the reference says:
```
1.2
```

the code:
```rexx
say 1e6 * 1e6  /* not 1000000000000 */
```
the result:
```
1E+12
```
the reference says:
```
1E+12
```

the code:
```rexx
say 1 / 3E10  /* not 0.0000000000333333333 */
```
the result:
```
3.33333333E-11
```
the reference says:
```
3.33333333E-11
```

## precision

```
NUMERIC DIGITS expression
```
precision is the maximum count of digits that the result of an operation can have.
the numeric digits instruction sets the precision.
its expression must give a positive whole number.
that number is the precision of maths.
rexx rounds results to that precision when it needs to.
if you omit the expression, or the program has run no numeric digits instruction, rexx uses the default precision.
the default precision is 9.
you can change the default for each source file with the options directive.
you can set the numeric digits precision to less than nine.
with a small precision, rexx keeps less digits and rounds more; this changes all the maths of rexx, also the values of the control variable of a do loop.

## how rexx does arithmetic

```
a + b
```
rexx has seven arithmetic operators: add, subtract, multiply, divide, integer divide, remainder, and power.
before each operation, rexx takes away the zero digits at the start of each operand, and keeps the position of the point.
if all the digits of an operand are zero, rexx keeps one zero.
then rexx truncates each operand, if it needs to, to the numeric digits precision add one digit.
rexx uses that one more digit at the end, when it rounds the result to the precision.
when rexx truncates an operand and a signal trap for the lostdigits condition is on, rexx raises the lostdigits condition.
then the operation runs with a precision that is not more than twice the precision.
then rexx rounds the result, if it needs to, to the numeric digits precision.
when rexx rounds, a digit from 5 to 9 makes the digit before it one more, and a digit from 0 to 4 does not.

## multiply

```
xxx.xxx * yy.yyyyy
```
rexx multiplies the two operands.
the result can have as many digits as the two operands have.
rexx rounds the result to the numeric digits precision; it counts the digits from the first digit of the result that is not zero.
the code:
```rexx
say xxx.xxx * yy.yyyyy
```
the result:
```
41.1
```
the reference says:
```
zzzzz.zzzzzzzz
```

## power

```
a ** b
```
the power operator gives a number to a power.
the power can be positive, negative, or 0.
the power must be a whole number.
rexx rounds the power to the numeric digits precision, if it needs to.
for a negative power, rexx uses the absolute value of the power, then divides 1 by the result.
rexx does not get the power with one multiply for each count of the power; it uses squares, so it needs less multiply steps.
for a negative power, rexx rounds the result of the divide to the numeric digits precision, if it needs to.
then rexx takes away the zero digits at the end, as if it divides the result by 1.

## integer divide

```
a % b
```
the integer divide operator divides two numbers and gives the integer part of the result.
rexx gets the result as it subtracts the second number from the first number while the first number is more than the second number.
rexx uses the absolute value of the two numbers for this.
the sign of the result is the same sign that a divide gives.
if the result can not be a whole number, it is an error.
the result must not have more digits than the numeric digits precision; if it has, it is an error.
the code:
```rexx
say 10000000000%3  /* an error with NUMERIC DIGITS 9 */
```
the result:
```
26.11
```
the reference says:
```
3333333333
```

## remainder

```
a // b
```
the remainder operator gives the remainder of an integer divide.
the remainder is the part of the first number that is there after the integer divide.
if the remainder is not zero, its sign is the sign of the first number.
the remainder is an error when the integer divide of the same two numbers is an error.

## arithmetic examples

```
NUMERIC DIGITS 5
```
these examples run with a precision of 5.
the code:
```rexx
say 12+7.00
```
the result:
```
19.00
```
the reference says:
```
19.00
```

the code:
```rexx
say 1.3-1.07
```
the result:
```
0.23
```
the reference says:
```
0.23
```

the code:
```rexx
say 1.3-2.07
```
the result:
```
-0.77
```
the reference says:
```
-0.77
```

the code:
```rexx
say 1.20*3
```
the result:
```
3.60
```
the reference says:
```
3.60
```

the code:
```rexx
say 7*3
```
the result:
```
21
```
the reference says:
```
21
```

the code:
```rexx
say 0.9*0.8
```
the result:
```
0.72
```
the reference says:
```
0.72
```

the code:
```rexx
say 1/3
```
the result:
```
0.333333333
```
the reference says:
```
0.33333
```

the code:
```rexx
say 2/3
```
the result:
```
0.666666667
```
the reference says:
```
0.66667
```

the code:
```rexx
say 5/2
```
the result:
```
2.5
```
the reference says:
```
2.5
```

the code:
```rexx
say 1/10
```
the result:
```
0.1
```
the reference says:
```
0.1
```

the code:
```rexx
say 12/12
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say 8.0/2
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say 2**3
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
say 2**-3
```
the result:
```
0.125
```
the reference says:
```
0.125
```

the code:
```rexx
say 1.7**8
```
the result:
```
69.7575744
```
the reference says:
```
69.758
```

the code:
```rexx
say 2%3
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say 2.1//3
```
the result:
```
2.1
```
the reference says:
```
2.1
```

the code:
```rexx
say 10%3
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
say 10//3
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say -10//3
```
the result:
```
-1
```
the reference says:
```
-1
```

the code:
```rexx
say 10.2//1
```
the result:
```
0.2
```
the reference says:
```
0.2
```

the code:
```rexx
say 10//0.3
```
the result:
```
0.1
```
the reference says:
```
0.1
```

the code:
```rexx
say 3.6//1.3
```
the result:
```
1.0
```
the reference says:
```
1.0
```

## exponent form

```
2.9508E+9
```
an exponent is of use for numbers that are big and for numbers that are small.
with a precision of 5, the result of the first example without an exponent is 2950800000, and its last digits are not true; so rexx gives the result with an exponent.
a number can have an optional exponent: the integer after the letter e is the power of ten to multiply the number by.
the letter e can be upper or lower.
some strings that are not like numbers are numbers, as the two in the code block after this line.
```
0E123  1E342
```
as two numbers like these can be equal, a compare of strings that are not numbers can give a false result; the strict compare operators do not have this error.
a result of maths has an exponent or not, from the numeric digits precision.
rexx uses an exponent when the result has more digits before the point than the precision, or more than twice that count of digits after the point.
when rexx makes an exponent, there is always a sign after the letter e, so you can read it.
if the exponent is 0, rexx does not write the exponent part.
the format builtin function can change a number to the exponent form, or to the form with no exponent.
in the scientific form, rexx changes the power of ten so there is one digit that is not zero before the point.
the scientific form is the default.
in the engineering form, there can be three digits or less before the point, and the power of ten can always divide by three with no remainder.
in the engineering form, the integer part is from 1 to 999.
the numeric form instruction sets the scientific form or the engineering form.
the code:
```rexx
say 54321*54321  /* with NUMERIC DIGITS 5 */
```
the result:
```
2.95077104E+9
```
the reference says:
```
2.9508E+9
```

the code:
```rexx
Say 12E7   =    120000000           /* Displays "1" */
Say 12E-5  =    0.00012             /* Displays "1" */
Say -12e4  =    -120000             /* Displays "1" */
Say 0e123  =    0e456               /* Displays "1" */
Say 0e123  ==   0e456               /* Displays "0" */
Numeric form scientific
say 123.45 * 1e11
```
the result:
```
1
1
1
1
0
1.2345E+13
```
the reference says:
```
1.2345E+13
```

the code:
```rexx
Numeric form engineering
say 123.45  * 1e11
```
the result:
```
12.345E+12
```
the reference says:
```
12.345E+12
```

## numeric compare

```
NUMERIC FUZZ expression
```
you can use the compare operators on strings that are numbers.
do not use the strict compare operators to compare numbers: with them, blanks at the start and the end, and zero digits at the start, count.
rexx compares two numbers as it subtracts them and compares the difference with 0.
two numbers are equal when their difference is zero, with the rules of subtract in rexx.
fuzz says how many digits rexx does not use when it compares two numbers, so two numbers that are not the same can be equal in a compare.
the numeric fuzz instruction sets fuzz.
its expression must give a positive whole number or zero.
the default fuzz is 0.
fuzz makes the precision less for a time: the subtract of a compare runs with a precision of the numeric digits precision subtract fuzz.
fuzz must always be less than the numeric digits precision.
with a precision of 9 and a fuzz of 1, the compare runs to 8 digits, as with a numeric digits instruction of 8 for that operation.
the code:
```rexx
Numeric digits 5
Numeric fuzz 0
say  4.9999 = 5     /* Displays "0"    */
say  4.9999 < 5     /* Displays "1"    */
Numeric fuzz 1
say  4.9999 = 5     /* Displays "1"    */
say  4.9999 < 5     /* Displays "0"    */
```
the result:
```
0
1
1
0
```

## whole numbers

```
17
```
a whole number has no fractional part, or a fractional part of only zero digits.
rexx does not write a whole number with an exponent, most times.
a whole number has no more digits before the point than the numeric digits precision.

## limits of whole numbers

```
DO exprr ... FOR exprf
NUMERIC DIGITS
NUMERIC FUZZ
```
on a 32 bit system, a whole number can have 9 digits or less.
on a 64 bit system, a whole number can have 18 digits or less.
this limit is used when a whole number is a length, an index, a count, or a size argument of a builtin function or a method.
this limit is used for the number at the right of the power operator.
this limit is used for the two expressions of the do and loop instructions in the first line of the code block.
this limit is used for the values of the numeric digits instruction and the numeric fuzz instruction.
this limit is used for the position patterns of the parse instruction.
this limit is used for the input you give in an interactive trace.

## errors in arithmetic

```
/* errors in arithmetic */
```
there are two kinds of arithmetic error: overflow or underflow, and not enough memory.
overflow or underflow is when the exponent of a result is more or less than the language can use, after rexx makes the form of the result with the numeric digits precision and the numeric form.
the language must be able to use exponents that are as big as the largest whole number at the default precision.
the default precision is 9.
so you can use exponents from -999999999 to 999999999.
overflow and underflow are syntax errors.
not enough memory is when rexx can not get the memory it needs for maths, so an arithmetic operation can not run.
not enough memory is an error that ends the program.

## reserved keywords

```
do i = 1 while (i < until)
   say i
end
```
in many places where a symbol can only be one thing, you can use a keyword as a symbol.
the syntax of rexx has few rules, so some symbols are reserved for the language in some places.
in an instruction as if, do, or select, some reserved symbols are between the parts of the instruction; these are the keywords.
while is a keyword in the do instruction, and then is a keyword after an if or a when clause; it ends that clause.
reserved keywords most times end an expression.
a keyword does not end an expression when it is the name of a message in a message term, when it is in a variable reference term, or when it is in parentheses.
in the example, the variable with the name until is in parentheses in a do while expression.
else, rexx tests if a symbol is the keyword of an instruction only when all of these are true:
it is the first token in a clause.
it is not a label.
it is not an assignment or an extended assignment.
it is not a message instruction.
you can use symbols in other places in a clause, and they are not keywords.

## special variables

```
RC  RESULT  SELF  SIGL  SUPER
```
rexx has five special variables.
you can change them as any variable, but rexx also sets rc, result, and sigl when it needs to.
the expose, procedure, use, and drop instructions act on these variables.
some instructions and builtin functions change how a program runs, but they are not special variables: the parse source and parse version instructions, and the address, digits, fuzz, form, and trace builtin functions.

```
RC
```
rexx sets this variable to the return code of each command that runs, also commands of the address instruction.
when rexx traps an error condition or a failure condition, this variable is the return code of the command.
when rexx traps a syntax condition, this variable is the number of the syntax error, from 1 to 99.
when rexx traps an other condition, this variable does not change.
commands that you run in an interactive trace do not change this variable.

```
RESULT
```
a return instruction with an expression sets this variable, in a subroutine you call or in a method that a message instruction runs.
if the return instruction has no expression, rexx drops this variable; then it is uninitialized.
the exit instruction and the reply instruction also set this variable.

```
SELF
```
rexx sets this variable when a method starts to run.
its value is the receiver object of the message that runs the method.
with it, a method can run a method on the object that runs it now.
with it, a method can give a reference to this object to a method of an other object.
the code:
```rexx
self~Read_Last_Page
Singer2~Duet(self)
```
the result:
```
97.1
```

```
SIGL
```
rexx sets this variable to the number of the line of the last instruction that made the program go to a label.
the signal instruction, the call instruction, a call of an internal function, and a condition that a trap gets can make the program go to a label.

```
SUPER
```
rexx sets this variable when a method starts to run.
its value is the class object where rexx starts to find a method of the superclass for self.
this is the first superclass of the class that makes the method that runs.
if the method that runs is from a mixin class, this variable is the superclass of the mixin.
with it, a method can call the method of the same name in the superclass.
the code:
```rexx
::class Account
::method INIT
expose balance
use arg balance
self~init:super          /* Forwards to the Object INIT method  */
::method TYPE
return "an account"
::method name attribute
::class Savings subclass Account
::method INIT
expose interest_rate
use arg balance, interest_rate
self~init:super(balance) /* Forwards to the Account INIT method */
::method type
return "a savings account"
```
the result:
```
```
