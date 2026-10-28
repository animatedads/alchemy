# rexx code: characters, clauses, expressions, operators, and symbols

these facts are from the oorexx language rules, the part about the characters, tokens, clauses, expressions, operators, assignment, and symbols of rexx code.

## words i add

example: code that is a test of a rule, with its result
examples: more than one example
comments: more than one comment
errors: more than one error
kinds: more than one kind
most: more than the other things; most times is many times, but not always
their: of them
quotes: more than one quote
sets: more than one set; also, set for one thing
comes: come, for one thing
finds: find, for one thing
show: put a thing where you can read it
shown: what you show
places: more than one place
period: the name of a mark; it is the point in a number
periods: more than one period
constants: more than one constant
lists: more than one list
pair: two things that are a set
pairs: more than one pair
form: the way a thing is made, or the order of its parts
longer: with a length that is more
even: a count is even when you can divide it by two with no remainder
follow: do what a rule says
block: a part of a file; a code block is a part of a file with code in it
parenthesis: one of the two parentheses
brackets: the name of two marks; like parentheses, they start and end a part of code
bracket: one of the two brackets
tilde: the name of a mark; it is the message operator
backslash: the name of a mark
plus: the name of a mark; it is the add operator
minus: the name of a mark; it is the subtract operator; it is the same mark as a dash
e: the name of a letter; in a number, it starts the exponent
x: the name of a letter
b: the name of a letter
encoding: the number that the computer stores for a character
ascii: the name of a character set
ebcdic: the name of an other character set
page: a code page is a list that says the encoding of each character in a set
pages: more than one page
tab: the name of a character that is like a blank; it is not a letter and not a digit
standard: of the kind that is used most
term: a part of an expression that gives a value; an operator can be between two of them
terms: more than one term
subexpression: an expression in parentheses that is a term in an other expression
subexpressions: more than one subexpression
concatenate: put the second string at the right end of the first string, to make one string
concatenation: what you get when you concatenate
abuttal: two terms next to each other, with no operator between them
act: do a thing; an operator does a thing with a term
acts: act, for one thing
prefix: a prefix operator has one operand, and it is before that operand
arithmetic: maths with numbers, as add, subtract, multiply, and divide
logical: about true and false values
strict: a strict compare uses each character as it is, in order, with no pad
normal: not strict
exclusive: an exclusive or is true when one operand is true and the other is false
precedence: an operator with more precedence runs first; a thing with more precedence is used first
level: one place in an order of things
subtracts: subtract, for one thing
multiplies: multiply, for one thing
divides: divide, for one thing
languages: more than one language
allowed: a thing is allowed when the rules say you can use it
nothing: no thing
simple: a simple symbol has no period in it and does not start with a digit
reference: a variable reference is a term that names a variable, so that code you call can change that variable
sequence: a list of things in order
namespace: a name for a package that this package gets with a directive; with it, you can say which class or routine of that package you want
namespaces: more than one namespace
assignments: more than one assignment
extended: made longer, or with more parts
environments: more than one environment
arg: a keyword; with it, an instruction gets the arguments of a routine or a method
numeric: about numbers; also the name of an instruction
templates: more than one template
subword: the name of a builtin function
select: the name of an instruction
otherwise: a keyword of the select instruction
continuation: a continuation character makes one clause go on to the next line
commas: more than one comma
size: the count of positions in an array, with an item in them or not
main: the main program is the part of a program file before the first directive
computed: made by a program when it runs
nop: the name of an instruction that does nothing
subkeyword: a keyword that is a keyword only in one kind of instruction
subkeywords: more than one subkeyword
control: the right to run the next step
rc: a special variable; it has the return code of the last command
failure: an event that a command can raise when the caller can not do a thing about it
failures: more than one failure
rs: the name of an environment symbol that rexx makes
least: not less than; at least two is two or more
address: the name of an instruction and of a builtin function about the environment of commands
subcommands: commands that a rexx program gives to an other program
cmd: the name of the shell on windows
sh: the name of a shell on unix
editor: a program you use to write and change files
exposes: expose, for one thing

## characters

```
'A'
C2D C2X D2C X2C XRANGE
```
a character is one of a set of things that the computer uses to keep or write data.
the encoding of a character is the number the computer stores for it.
a character is not the same as its encoding.
the encoding of a character is not the same in each character set.
in ascii, the encoding of the upper letter in the code block is 65; in ebcdic, it is 193.
the rules of rexx do not say what encoding a computer must use.
some builtin functions change characters to numbers or numbers to characters; their results are not the same with each character set.
the second line of the code block has these functions.
some code pages do not have some characters that rexx can use; the not mark is one of them.
some characters that rexx can use have an other encoding in an other code page; the exclamation mark is one of them.

## blank and tab

```
say 'a'	'b'
```
rexx uses two characters as blanks: the blank and the tab.
you can use a blank or a tab, and it is the same.
rexx changes each tab in the code of a program to a blank.
in ascii, the blank is the character with the hexadecimal encoding 20.
in ascii, the tab is the character with the hexadecimal encoding 9.
the parse instruction takes a blank or a tab as the end of a word.
the subword builtin function takes a blank or a tab as the end of a word.

## comments

```
/* a standard comment */
-- a line comment
```
rexx has two kinds of comment: line comments and standard comments.
rexx ignores a comment.
a comment is like a blank between two tokens: a token with a comment in it is two tokens.
a line comment starts with two dash marks and ends at the end of the line.
a standard comment starts with a slash and a star, and ends with a star and a slash.
a standard comment can be on one line or on more than one line.
a standard comment can have any characters in it.
a standard comment can be at any place in the code, and it can have any length.
a standard comment can be nested in an other standard comment, when each comment has a start and an end.
you can have the two kinds of comment nested in each other.
when the two kinds are nested, the comment that starts first has precedence.
rexx takes the start marks and the end marks of a standard comment as marks of a comment, also when they are in a literal string.
so if you make code a comment, and that code has a literal string with these marks in it, the comment does not end where you want.
to not have this error, make the string with two literal strings and the concatenate operator, so the two marks are not next to each other.
if the start marks of a standard comment are in a line comment, rexx ignores them; then the end marks have no start, and that is an error.
if the start marks are in a string and no end marks come after them, rexx reads the rest of the program as a comment.
the code:
```rexx
/* This is an example of a valid Rexx comment */
'You shouldn''t'        -- Same as "You shouldn't"
if substr(input,1,5) = "/" || "*123" then ...
'You shouldn''t'        /* Same as "You shouldn't"
""                      -- The null string         */
'You shouldn''t'        -- Same as /* "You shouldn't"
""                      The null string         */
```
the result:
```
35.1
```
the reference says:
```
error
```

## tokens

```
"REPEAT"   A + 3;
```
a clause is made of tokens.
a token can have any length, but the language can have a maximum.
blanks or comments are between tokens; also, the kind of two tokens can say where one ends and the next starts.
the kinds of token are: literal strings, hexadecimal strings, binary strings, symbols, numbers, operator characters, and special characters.
the example clause has six tokens: a literal string, a blank operator, a symbol, an add operator, a symbol that is also a number, and the semicolon.
rexx takes away the blanks next to the add operator in the example.
rexx does not take away the blank between the literal string and the symbol; it is an operator.
the code:
```rexx
"REPEAT"   A + 3;
```
the result:
```
41.1
```
the reference says:
```
"REPEAT" A+3;
```

## literal strings

```
"Fred"
```
a literal string can have any characters, but not the end of a line or the end of a file.
a literal string starts and ends with a quote mark: one quote or two quotes.
in a literal string between two quotes, two quotes next to each other are one quote character.
in a literal string between two of the other quote, two of that quote next to each other are one quote character of that kind.
a literal string is a constant; rexx never changes it.
a literal string must start and end on the same line.
a literal string with no characters is the null string.
the length of a literal string has no maximum but the memory of the computer.
a literal string with a left parenthesis next after it is the name of a function.
a literal string with the symbol x next after it is a hexadecimal string.
a literal string with the symbol b next after it is a binary string.
the code:
```rexx
"Fred"
"Don't Panic!"
'You shouldn''t'      /* Same as "You shouldn't" */
""                    /* The null string         */
```
the result:
```
```

## hexadecimal strings

```
"ABCD"x
```
a hexadecimal string is a literal string that has the hexadecimal digits of the encoding of its characters.
it has no hexadecimal digits or more, in pairs.
its digits are the digits zero to nine and the first six letters, in upper or in lower.
if the count of digits is not even, rexx puts a zero digit at the start.
you can put blanks between two pairs of digits, but not at the start or at the end.
rexx ignores the blanks; they are there so you can read the string.
the quote marks of a hexadecimal string have an x or an upper x next after them.
that letter can not be a part of a longer symbol.
rexx makes each pair of digits the character with that encoding.
with a hexadecimal string, you can write characters that you can not put in code in an other way.
a hexadecimal string is not a number; its value is not the same on each kind of computer.
in ascii, the hexadecimal string with the digits 20 is a blank.
in ascii, the hexadecimal string with the digits 41 and the string with the upper letter a are the same, and rexx uses them in the same way.
the length of a hexadecimal string has no maximum.
the code:
```rexx
"ABCD"x
"1d ec f8"X
'1 d8'x
```
the result:
```
```

## binary strings

```
"11110000"b
```
a binary string is a literal string that has the binary digits of the encoding of its characters.
it has no binary digits or more; each digit is zero or one.
the digits are in sets of eight or in sets of four.
the first set can have less than four digits; then rexx puts zero digits at its start, so it has four.
you can put blanks between two sets, but not at the start or at the end.
rexx ignores the blanks; they are there so you can read the string.
the quote marks of a binary string have a b or an upper b next after them.
that letter can not be a part of a longer symbol.
if the count of digits can not divide by eight with no remainder, rexx puts zero digits at the left until it can.
rexx makes each eight digits one character.
with a binary string, you can say each bit of a character.
the length of a binary string has no maximum.
the code:
```rexx
"11110000"b         == "f0"x
"101 1101"b         == "5d"x
'1'b                == '00000001'b   /* or '01'x */
"10000 10101010"b   == "0001 0000 1010 1010"b
""b                 == ""
```
the result:
```
```

## symbols

```
Albert.Hall
```
a symbol is made of letters in upper or lower, the digits, and the marks period, exclamation, question, and underscore.
rexx changes each lower letter in a symbol to upper before it uses the symbol.
a symbol that does not start with a digit or a period can be a variable, and you can assign a value to it.
if no value is assigned to this kind of symbol, its value is its characters in upper.
a symbol that starts with a digit or a period is a constant symbol; you can not assign a value to it.
a symbol can also be a number with an exponent; it starts with a digit or a period.
this kind of number ends with the letter e in upper or lower, then an optional plus or minus sign, then one digit or more, with no blanks between them.
no other symbol characters can come after these digits.
the sign in this kind of number is a part of the symbol; it is not an operator.
the part before the letter e must be a number of only digits and a period.
that part must have one digit or more, and not more than one period.
code that does not follow these rules is not this kind of number; it is more than one token, with an operator between them.
the code:
```rexx
Fred
Albert.Hall
WHERE?
17.3E-12
.03e+9
.E-12       /* no digits             */
```
the result:
```
41.1
```
the reference says:
```
not a number
```

the code:
```rexx
3ae+6       /* non-digit character   */
```
the result:
```
41.1
```
the reference says:
```
not a number
```

the code:
```rexx
3..0e+9     /* more than one '.'     */
```
the result:
```
41.1
```
the reference says:
```
not a number
```

## numbers

```
" + 7.9E5 "
```
a number is a string of one decimal digit or more.
a number can have an optional plus or minus sign before it.
a number can have one period in it as the decimal point.
a number can end with an exponent: the letter e in upper or lower, an optional sign, and one decimal digit or more.
the exponent can have nine digits or less.
when you use a string as a number, rexx can round it to the precision of the numeric digits instruction.
the default precision is nine digits.
a symbol or a literal string can be a number.
a number can not be the name of a variable.
you can write a number with quote marks or without them.
a whole number has no fractional part, has no exponent most times, and has no more digits before the point than the numeric digits precision.
in an expression, a minus mark before a number with no quotes is not a part of the number; it is the subtract operator.
there can be blanks at the start, before and after the sign, and blanks at the end.
there can not be blanks between the digits of a number or in its exponent.
rexx can write the result of maths with an exponent; the length of the result and the precision say if it does.
numbers are strings; rexx can round them when it uses them as numbers.
the code:
```rexx
12
"-17.9"
127.0650
73e+128
" + 7.9E5 "
```
the result:
```
```

## operator characters

```
+  -  \  /  %  *  |  &  =  ¬  >  <
>=  <=  \>  \<  \=  ><  <>  ==  \==  //  &&  ||  **
¬>  ¬<  ¬=  ¬==  >>  <<  >>=  \<<  ¬<<  \>>  ¬>>  <<=
```
the first line of the code block has the operator characters; the next lines have the operators of more than one character.
some operator characters are also used in parse templates.
the equal mark and the extended assignment operators make an assignment.
rexx ignores blanks and standard comments next to operator characters or between the characters of one operator.
some operator characters are not in each character set; you can use an other character in their place.
the or mark is also shown as an other mark that is like it.
rexx uses the ascii character 124 for the concatenate operator and for the or operator.
if you get error 13 on an instruction with the or mark, test that the character is the ascii character 124.
in all of the language, the not mark and the backslash mark are the same, and you can use one in the place of the other.
rexx takes the ascii characters 170 and 172 as the not operator.
if the computer has no not mark, use the backslash mark.
the code:
```rexx
345>=123
345 >=123
345 >= 123
345 > = 123
345 >/*not smaller*/ = 123
```
the result:
```
```

## special characters

```
,  ;  :  (  )  [  ]  ~
```
the special characters, with the operator characters, have a special use when they are not in a literal string.
the special characters are the comma, the semicolon, the colon, the two parentheses, the two brackets, and the tilde.
each special character is the end of a token.
rexx takes away each blank and each tab next to a special character.
but rexx takes away a blank outside a parenthesis or a bracket only when it is also next to an other special character.
so rexx does not take away the blank in the first example: it is a concatenate, not a call of a function.
rexx takes away the blanks in the second example.
the code:
```rexx
A (Z)          /* concatenation, not the function call A(Z) */
(A) + (Z)
```
the result:
```
41.1
```
the reference says:
```
(A)+(Z)
```

## the semicolon at the end of a line

```
say 'a'; say 'b'
```
a semicolon ends a clause.
rexx takes the end of a line as a semicolon, most times.
rexx also puts a semicolon after some keywords, and after a colon that comes after one symbol.
you need to write a semicolon only when a line has more than one clause, or when an instruction ends with a comma.
the end of a line is not the end of a clause when the line ends in a standard comment of more than one line.
the end of a line is not the end of a clause when the last token is a comma or a minus mark, and the line does not end in a comment.
a comment is not a token.
rexx takes a semicolon after a colon that comes after one symbol, a literal string, or a label.
the keywords else, otherwise, and then have a semicolon after them, in the right place.
these rules make less errors in code.

## lines of one clause

```
say "You can use a comma",
"to continue this clause."
```
you can put the rest of a clause on the next line: end the line with a comma or a minus mark.
the comma or the minus mark at the end of the line is the continuation character.
rexx changes the continuation character to a blank, so there is no semicolon there.
there can be comments after the continuation character, before the end of the line.
the code:
```rexx
say "You can use a comma",       -- this line is continued
"to continue this clause."
say "You can use a minus"-       -- this line is continued
"to continue this clause."
```
the result:
```
You can use a comma to continue this clause.
You can use a minus to continue this clause.
```

## terms and expressions

```
(a + 1) * 3
```
a term can be a literal string, a symbol, a message term, a message sequence, an array term, a variable reference term, a function call, or a subexpression.
an expression can have operators between its terms; they say what to do with the terms.
a literal string starts and ends with quote marks, and it is a constant.
rexx changes a symbol with no quotes to upper.
if a symbol does not start with a digit or a period, it can be the name of a variable; then rexx uses the value of that variable.
if a symbol starts with a period, it can name an object of the environment; then rexx uses that object.
else, a symbol is a constant string.
a symbol can be a compound symbol.
the name of a function in a function call is a literal string or a symbol; rexx takes it as a constant.
when the name of a function is a symbol, a namespace and a colon can come before it.
an expression has one term or more.
expressions run from left to right, but parentheses and the precedence of the operators can change the order.
rexx gets the value of each term when the expression uses it.
rexx gets the value of all of an expression, if there is no error.
the result of a term or an expression is an object, as a string.

## operators

```
say 1+2
```
an operator acts on two terms, but a prefix operator acts on one term.
the terms can be symbols, strings, function calls, message terms, results of other operators, or subexpressions.
a prefix operator acts on the term or the subexpression next after it.
rexx ignores blanks or comments next to the characters of an operator; an operator of more than one character can have blanks or comments in it.
blanks that are not next to an other operator can be an operator: the blank concatenate operator.
rexx makes each operator a message: it sends the operator to the left term, with the right term as the argument.
the blank concatenate operator sends the message that is one blank.
the abuttal operator sends the message that is the null string.
with a prefix operator, rexx sends the message with no arguments.
when an operator has the not mark, rexx changes that mark to the backslash mark.
the kinds of operator are: concatenate, arithmetic, compare, and logical.
the code:
```rexx
say 1+2          /* the same as: say 1~"+"(2) */
-z               /* the same as: z~"-"        */
¬=               /* sends the message \=      */
```
the result:
```
13.1
```

## concatenate

```
a b
a || b
a"b"
```
concatenation puts the second string at the right end of the first string.
there can be a blank between the two strings or no blank.
rexx takes the abuttal operator between two terms when there is no other operator between them.
abuttal can be when two terms are not the same kind of token, as a literal string and a symbol.
abuttal can also be when only a comment is between two terms.
when an operator is between two terms, there is no abuttal, and the expression can be an error.
the code:
```rexx
/* Fred has the value 37.4, PETER has the value 1 */
Fred"%"
```
the result:
```
```
the reference says:
```
37.4%
```

the code:
```rexx
(Fred)(Peter)
```
the result:
```
```
the reference says:
```
37.41
```

the code:
```rexx
"4a 4b"x"LMN"
```
the result:
```
```
the reference says:
```
JKLMN
```

the code:
```rexx
Fred/* The NOT operator precedes Peter. */\Peter
```
the result:
```
35.1
```
the reference says:
```
error: no abuttal
```

the code:
```rexx
(Fred)/* The NOT operator precedes Peter. */(\Peter)
```
the result:
```
34.901
```
the reference says:
```
37.40
```

```
a b
```
this is the blank concatenate operator.
it puts the two terms in one string, with one blank between them.

```
a || b
```
this operator puts the two terms in one string, with no blank between them.
it makes a concatenation with no blank.

```
a"b"
```
this is the abuttal operator; it has no mark.
it puts the two terms in one string, with no blank between them.
rexx takes it when two terms have no other operator between them.

## arithmetic operators

```
a + b
```
the arithmetic operators act on strings that are numbers.
the part about numbers and arithmetic has the rules of precision, of numbers, and of each operator.
if the result of arithmetic has an exponent, it is most times a rounded result.

```
a + b
```
this operator adds two numbers.

```
a - b
```
this operator subtracts the second number from the first number.

```
a * b
```
this operator multiplies two numbers.

```
a / b
```
this operator divides the first number by the second number.

```
a % b
```
this operator is the integer divide.
it divides, and gives only the integer part of the result.

```
a // b
```
this operator is the remainder operator.
it divides, and gives the remainder.
the result can be negative.

```
a ** b
```
this operator is the power operator.
it gives the first number to the power of the second number; the second number must be a whole number.

```
-a
```
this is the prefix minus operator.
it is the same as zero subtract the number.

```
+a
```
this is the prefix plus operator.
it is the same as zero add the number.

## compare operators

```
a = b
```
a compare operator compares two terms; it gives 1 if the compare is true, and 0 if not.
a strict compare operator has one of its characters two times.
a compare of characters is not caseless, and a strict compare is not caseless.
the order of the characters can be not the same with each character set.
in ascii, the digits are less than the letters, and lower letters are more than upper letters.
the not mark is the same as the backslash mark in each operator.
the strict equal operator and the strict not equal operator test if two strings are the same in each character and have the same length.
the other strict operators compare each character, from left to right, with no pad.
in a strict compare, if one string is the start of the other string, the short string is less.
a strict compare is never a compare of numbers.
in a normal compare, if both terms are numbers, rexx compares them as numbers.
else, rexx compares the two terms as strings: it ignores blanks at the start and at the end, and puts blanks at the right of the short string until the two have the same length.

```
a = b
```
this operator is equal.
it is a normal compare: equal as numbers, or equal as strings after the pad.

```
a \= b
a ¬= b
```
this operator is not equal.
it is the same as not the equal operator.
it is a normal compare.

```
a > b
```
this operator is more than.
it is a normal compare.

```
a < b
```
this operator is less than.
it is a normal compare.

```
a >< b
```
this operator is more than or less than.
it is the same as not equal.
it is a normal compare.

```
a <> b
```
this operator is more than or less than.
it is the same as not equal.
it is a normal compare.

```
a >= b
```
this operator is more than or equal to.
it is a normal compare.

```
a \< b
a ¬< b
```
this operator is not less than.
it is a normal compare.

```
a <= b
```
this operator is less than or equal to.
it is a normal compare.

```
a \> b
a ¬> b
```
this operator is not more than.
it is a normal compare.

```
a == b
```
this operator is strict equal.
the two strings must be the same in each character.

```
a \== b
a ¬== b
```
this operator is strict not equal.
it is the same as not the strict equal operator.

```
a >> b
```
this operator is strict more than.

```
a << b
```
this operator is strict less than.

```
a >>= b
```
this operator is strict more than or equal to.

```
a \<< b
a ¬<< b
```
this operator is strict not less than.

```
a <<= b
```
this operator is strict less than or equal to.

```
a \>> b
a ¬>> b
```
this operator is strict not more than.

## logical operators

```
a & b
```
a string is false when it is 0, and true when it is 1.
a logical operator takes one or two of these values, and gives 0 or 1.
values that are not 0 or 1 are not allowed.

```
a & b
```
this operator is and.
it gives 1 only when both terms are true.

```
a | b
```
this operator is or.
it gives 1 when one term is true or when both terms are true.

```
a && b
```
this operator is exclusive or.
it gives 1 when one term is true, but not both.

```
\a
¬a
```
this is the prefix not operator.
it changes the value: 1 to 0, and 0 to 1.

## operator precedence

```
~  ~~                                        (message send)
+  -  ¬  \                                   (prefix operators)
**                                           (power)
*  /  %  //                                  (multiply and divide)
+  -                                         (add and subtract)
(blank)  ||  (abuttal)                       (concatenation with or without blank)
=  >  <  ==  >>  <<  \=  ¬=  ><  <>  \>  ¬>  \<  ¬<  \==  ¬==  \>>  ¬>>  \<<  ¬<<  >=  >>=  <=  <<=   (comparison operators)
&                                            (and)
|  &&                                        (or, exclusive or)
```
level 1, the first precedence: the message operators, that send a message.
level 2: the prefix operators: prefix plus, prefix minus, and prefix not.
level 3: the power operator.
level 4: multiply, divide, integer divide, and remainder.
level 5: add and subtract.
level 6: concatenate, with a blank, with no blank, and abuttal.
level 7: all the compare operators; they have the same precedence.
level 8: and.
level 9, the last precedence: or, and exclusive or.
expressions run from left to right, but precedence and parentheses can change the order.
rexx gets the value of a subexpression in parentheses when it needs the value.
parentheses with the arguments of a function or of a message in them do not make a subexpression.
when an operator with more precedence comes after an operator with less precedence, the operator with more precedence and its terms run first.
rexx reads the terms from left to right, in the order they are in the code.
the prefix minus has more precedence than the power operator, so the result of the first power example is 9, not -9.
power operators run from left to right; in many other languages, they run from right to left.
the code:
```rexx
/* A is 3, DAY is Monday, all other variables are uninitialized */
3+2*5
```
the result:
```
```
the reference says:
```
13
```

the code:
```rexx
Say A+5
```
the result:
```
41.1
```
the reference says:
```
8
```

the code:
```rexx
Say A-4*2
```
the result:
```
41.1
```
the reference says:
```
-5
```

the code:
```rexx
Say A/2
```
the result:
```
41.1
```
the reference says:
```
1.5
```

the code:
```rexx
Say 0.5**2
```
the result:
```
0.25
```
the reference says:
```
0.25
```

the code:
```rexx
Say (A+1)>7  /* that is, .false */
```
the result:
```
41.1
```
the reference says:
```
0
```

the code:
```rexx
Say " "=""  /* that is, .true  */
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
Say " "==""  /* that is, .false */
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
Say " "\==""  /* that is, .true  */
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
Say (A+1)*3=12  /* that is, .true  */
```
the result:
```
41.1
```
the reference says:
```
1
```

the code:
```rexx
Say "077">"11"  /* that is, .true  */
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
Say "077" >> "11"  /* that is, .false */
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
Say "abc" >> "ab"  /* that is, .true  */
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
Say "abc" << "abd"  /* that is, .true  */
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
Say "ab " << "abd"  /* that is, .true  */
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
Say Today is Day
```
the result:
```
TODAY IS DAY
```
the reference says:
```
TODAY IS Monday
```

the code:
```rexx
Say "If it is" day
```
the result:
```
If it is DAY
```
the reference says:
```
If it is Monday
```

the code:
```rexx
Say Substr(Day,2,3)  /* Substr is a function */
```
the result:
```
AY 
```
the reference says:
```
ond
```

the code:
```rexx
Say "!"xxx"!"
```
the result:
```
!XXX!
```
the reference says:
```
!XXX!
```

the code:
```rexx
-3**2  /* not -9  */
```
the result:
```
```
the reference says:
```
9
```

the code:
```rexx
-(2+1)**2  /* not -9  */
```
the result:
```
```
the reference says:
```
9
```

the code:
```rexx
2**2**3  /* not 256 */
```
the result:
```
```
the reference says:
```
64
```

## message terms

```
receiver~messagename(arguments)
```
a message term sends a message to a receiver.
the receiver is a term; after it come the tilde or two tilde marks, then the name of the message.
the name of the message is a literal string, or a symbol that rexx takes as a constant.
the arguments are in parentheses or in brackets, with a comma between two arguments.
if there are no arguments, you can omit the parentheses.
the left parenthesis must be next after the name of the message, with no blank; only a comment can be between them.
the receiver and the arguments can have message terms in them.
the expressions run from left to right; to omit an argument, put one more comma.
a message can have a count of arguments that is not always the same; you give only the arguments that you need.
first rexx gets the value of the receiver, then the values of the arguments.
rexx sends the name of the message in upper, with the arguments, to the receiver.
the receiver finds a method with that name, and runs it.
in that method, the arg instruction, the parse arg instruction, the use arg instruction, and the arg builtin function get the arguments.
after the name of the message, there can be a colon and a symbol; this changes which method runs.
that symbol must be a variable, most times super, or an environment symbol.
the code:
```rexx
c="escape"
a="Position of 'e' is:" c~pos("e",3)
```
the result:
```
```
the reference says:
```
A is "Position of 'e' is: 6"
```

the code:
```rexx
"ESCAPE"~POS("E")
```
the result:
```
```
the reference says:
```
1
```

the code:
```rexx
account = .object~subclass("Account")~~inherit(.persistent)
```
the result:
```
98.942
```
the reference says:
```
ACCOUNT is the object returned by SUBCLASS, after it gets the message INHERIT
```

```
receiver~messagename
```
with one tilde, the method must give a result object.
that result takes the place of the message term.
with one tilde, the message term gives the result of the method.
use one tilde when you want the result to be the receiver of the next message.

```
receiver~~messagename
```
with two tilde marks, the method does not have to give a result.
rexx does not use any result; the receiver takes the place of the message term.
with two tilde marks, the message term gives the receiver.
the two ways, with one tilde and with two tilde marks, are not the same only in what they do with the result.
so in a sequence of messages with two tilde marks, each message goes to the same object.

```
receiver[arguments]
```
the bracket form is the same as a message with the name of the two bracket marks.
it does the same as the form with one tilde.
the code:
```rexx
a = .array~of(10,20)
say "Second item is" a[2]   /* Same as: a~at(2) */
```
the result:
```
Second item is 20
```
the reference says:
```
Second item is 20
```

## array terms

```
"mon", "tue", "wed"
```
an array term is a short way to make an array.
the examples show an array term as expressions with a comma between them.
an array term makes a new array, as the of method of the rexx array class does, if there is no comma at the end.
it always gives an instance of the array class of rexx, also when there is a class that you make with the name array.
with commas at the end, an array term gives a longer array than the of method gives for the same items.
where commas have an other use, put the array term in parentheses.
an array term can not give an array whose size is zero or one; it can give an array with zero items or one item, but its size is two or more.
the code:
```rexx
week = "mon", "tue", "wed", "thu", "fri", "sat", "sun"
say week~items "days"
```
the result:
```
7 days
```
the reference says:
```
7 days
```

the code:
```rexx
say ("here", "we", "go")~makeString(, " ")
```
the result:
```
here we go
```
the reference says:
```
here we go
```

the code:
```rexx
say 0~sendWith("MAX", (2, 3, 5, 7, 11, 13))
```
the result:
```
13
```
the reference says:
```
13
```

the code:
```rexx
sparse = ,,,0
say "size" sparse~size"," sparse~items "items"
```
the result:
```
size 4, 1 items
```
the reference says:
```
size 4, 1 items
```

the code:
```rexx
say (1, , 3, ,)~size .Array~of(1, , 3, ,)~size
```
the result:
```
5 3
```
the reference says:
```
5 3
```

the code:
```rexx
say (,)~size .Array~of(,)~size
```
the result:
```
2 0
```
the reference says:
```
2 0
```

the code:
```rexx
call func "uno", 2, "tre"      -- no Array term: three parms
call func ("uno", 2, "tre")    -- Array term: one Array as parm
say (,)~items
```
the result:
```
43.1
```
the reference says:
```
0
```

the code:
```rexx
say (,)~size
```
the result:
```
2
```
the reference says:
```
2
```

## variable reference terms

```
>variable
<stem.
```
a variable reference term starts with one of the two reference operators: the more than mark or the less than mark.
after the operator comes the name of a simple variable or of a stem variable.
a reference to a compound variable is not allowed.
with a variable reference, the code you call can change the variable or make it.
the use arg instruction can change an argument object without a variable reference, but to make the argument a new object, you need a variable reference term.
you can give a variable reference as an argument to a subroutine, a function, a method, or a routine.
the routine you call must get it with the use arg instruction, and the names must be the same.
the variable reference and the name in the use arg instruction must both be simple or both be stems.
in the use arg instruction, a variable reference can never be optional.
in the use arg instruction, a variable reference can not have a default value.
the code:
```rexx
call dir >files, ".txt"
say files~items "files with extension .txt"
use strict arg >array, extension = ""
```
the result:
```
13.1
```

## null clauses

```
;
```
a clause that has only blanks or comments, or both, is a null clause.
rexx ignores a null clause.
a null clause is not an instruction.
a semicolon after then or else in an if instruction is not a step that does nothing.
use the nop instruction for a step that does nothing.

## directives

```
::CLASS
::METHOD
```
a directive is a clause that starts with two colon marks.
a directive is not a step that runs.
a directive can start at any place on a line.
directives cut a program in parts that can run: methods and routines.
directives also give facts about the program and about its parts.
the class directive makes a new rexx class.
the method directive makes a method.

## labels

```
name:
```
a label is a clause of one symbol or one string with a colon after it.
rexx takes a label as a null clause; a trace can show it so you can debug.
the colon is the end of the clause, so a label needs no semicolon.
the name of a label is its symbol or its string.
the name of a label with a symbol is in upper.
the name of a label with a string can have upper and lower letters.
two labels can have the same name.
then the call instruction, the signal instruction, and a function call go only to the first of them in the main program, a method, or a routine.
a trace can show the other labels with that name, but a call can not go to them.
a label is where a call instruction, a signal instruction, or a call of an internal function goes.
when rexx finds a label for these, it is not caseless.
a symbol can not find a label that has lower letters.
a literal string or a computed name can find a label that has lower letters.
a label can have any count of clauses after it.
more than one label can come before an other clause.
labels are not allowed in a do, loop, if, or select instruction.

## instructions

```
say 'hello'
```
an instruction is one clause or more that says what rexx must do.
an instruction can be an assignment, a message instruction, a keyword instruction, or a command.

## assignments

```
symbol=expression
```
a clause of the form in the code block is an assignment.
an assignment gives a new value to a variable.

## message instructions

```
receiver~messagename
messageterm = expression
```
a message instruction is one clause: a message term.
a message instruction can also be a message term, the equal mark, and an expression.
in that form, the message term does not have to give a result.
rexx sends a message to an object, and the object does a thing.

## keyword instructions

```
DO
  instruction
  instruction
  instruction
END
```
a keyword instruction is one clause or more; the first clause starts with the keyword that names the instruction.
keyword instructions do things as the use of external programs and the order of the steps.
some keyword instructions can have nested instructions in them.
a do instruction is one keyword instruction: the do keyword, the instructions in it, and the end keyword.
to and while are subkeywords of the do instruction.

## commands

```
"TYPE" fname"."exten
```
a command is a clause that is only an expression.
rexx gets the value of the expression, and gives that string as a command to an external environment.
the expression must not be a message instruction.
the value of the expression is a string; it can be the null string.
the environment runs the command, sets a return code, and gives control back to rexx.
a return code is a string; most times it is a number.
most times it says that the command is done with no error, but it can also have other data.
rexx puts the return code in the special variable rc.
the system can also raise an error or a failure.
an error is an event of a command that the caller can do a thing about; as when a command can not find a string.
a failure is an event of a command that the caller can not do a thing about; as when the command can not run, or the system can not find it.
errors and failures change what the program does when an error trap or a failure trap is on.
errors and failures can make a trace of the command, when the trace option for errors or the trace option for failures is set.
the trace option normal is the same as the trace option for failures, and it is the default.
the environment symbol rs is -1 when there is a failure, 1 when there is an error, and 0 when there is no error and no failure.
rexx gets the value of the expression before it gives it to the environment.
write the parts of a command that do not change as literal strings.
if you put a whole message instruction in parentheses, the result of the message is the command.
a clause that is a message instruction is not a command.
the code:
```rexx
fname = "CHESHIRE"
exten = "CAT"
"TYPE" fname"."exten
```
the result:
```
```
the reference says:
```
the string TYPE CHESHIRE.CAT goes to the command processor, CMD.EXE
```

the code:
```rexx
"TYPE CHESHIRE.CAT"
```
the result:
```
```
the reference says:
```
the same as the example before
```

the code:
```rexx
delete "*".lst           /* not "multiplied by" */
var.003 = anyvalue
type "var.003"           /* not a compound symbol */
w = any
dir"/w"                  /* not "divided by ANY" */
rm "*".lst               /* not "multiplied by" */
var.003 = anyvalue
cat "var.003"            /* not a compound symbol */
w = any
ls "/w"                  /* not "divided by ANY" */
myfile~linein
```
the result:
```
97.1
```
the reference says:
```
the line goes to the variable RESULT
```

the code:
```rexx
(myfile~linein)
```
the result:
```
97.1
```
the reference says:
```
the line goes as a command to the external environment
```

## environments

```
ADDRESS
""  COMMAND  SYSTEM
bsh  bash  csh  ksh  tcsh  zsh
PATH
```
the system has at least one environment that runs commands.
rexx takes a default environment when a program starts.
the address instruction changes the environment.
the address builtin function gives the name of the environment.
the system says what environments are outside the rexx program; the environments that a program can use are not the same with each caller.
a rexx program can give commands to other programs; these commands are subcommands.
a program that uses rexx as a language in it must give rexx the name of its environment.
the default environment is cmd on windows and sh on unix.
the names in the second line of the code block are three other names of the default environment: the null string, command, and system.
the default environment runs commands with the shell: cmd on windows and sh on unix.
if an editor that takes subcommands calls the program, the default environment can be that editor.
on unix, the environments in the third line of the code block are there too; each one runs commands with the shell of that name, if that shell is on the computer.
the path environment is on windows and on unix.
the path environment runs a command with no shell; it finds the command with the path variable of the system.
the path environment does not do the things that only a shell does.

## extended assignments

```
a += 1
+=  -=  *=  /=  %=  //=  ||=  &=  |=  &&=  **=
```
the extended assignment operators are in the second line of the code block.
an extended assignment is an operator that is not a prefix operator, with an assignment.
the variable at the left of the assignment is also the left operand of the operator.
rexx runs an extended assignment the same way as the longer form of the instruction.
the code:
```rexx
a += 1
```
the result:
```
41.1
```
the reference says:
```
the same as: a = a + 1
```

## constant symbols

```
77
```
a constant symbol starts with a digit, or is one period, or is a number.
its value is its characters, with each lower letter in upper.
you can not change the value of a constant symbol.
the code:
```rexx
77
827.53
.12345
12e5        /* Same as 12E5 */
3D
17E-3
```
the result:
```
```

## simple symbols

```
FRED
```
a simple symbol has no period and does not start with a digit.
its default value is its characters in upper.
when a value is assigned to it, it is a variable, and its value is the value of that variable.
the code:
```rexx
FRED
Whatagoodidea?    /* Same as WHATAGOODIDEA? */
?12
```
the result:
```
```

## stems

```
FRED.
```
a stem is a symbol whose last character is the only period in it.
a stem can not start with a digit.
the value of a stem is always a stem object.
rexx makes the stem object the first time you use the stem variable or a compound variable with that stem.
the name of the stem object is the name of the stem variable in upper.
if a value is assigned to the stem, or the stem object has a default value, that value is used in the place of the name.
a reference to a stem variable gives its stem object.
when you assign a stem object to a stem, it takes the place of the stem object before; so more than one stem can use the same object.
when you assign a value that is not a stem object, rexx makes a new stem object in its place.
the new value is the default value of the new stem object.
then each compound variable of that stem gives the new value, until you assign an other value to the stem, to the stem object, or to that compound variable.
so you can give all the compound variables of a stem the same value.
you can give a stem as an argument to a function, a subroutine, or a method.
the use arg instruction is like an assignment.
to use a stem argument as a collection, you must use the use arg instruction.
the parse instruction and the parse arg instruction make the stem a string value.
a function, a subroutine, or a method can give a stem as its result; the result is the stem object.
in an expression, a stem variable gives its stem object; it sends many messages to its default value.
the string method of a stem object gives its default value as a string.
the bracket method with no arguments gives the default value.
that default value is not the same as a compound variable whose tail is the null string.
the drop instruction on a stem gives the stem a new stem object.
the expose instruction on a stem exposes all the variables of that stem.
the do instruction and the loop instruction can use all the values of a stem in order.
the code:
```rexx
FRED.
A.
hole.   = "empty"
hole.19 = "full"
say  hole.1  hole.mouse  hole.19
```
the result:
```
empty empty full
```
the reference says:
```
empty empty full
```

the code:
```rexx
hole.   = "empty"  /* setup from the example before */
hole2. = hole.       /* copies reference to hole. stem to hole2. */
say  hole2.1  hole2.mouse  hole2.19
```
the result:
```
empty empty empty
```
the reference says:
```
empty empty full
```

the code:
```rexx
total. = 0
say total.
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
total. = 0
null = ""
total.null = total.null + 5
say total.[] total.null
```
the result:
```
0 5
```
the reference says:
```
0 5
```

## compound symbols

```
Array.I.J
```
a compound symbol has at least one period and at least two other characters.
it can not start with a digit or a period.
if it has only one period, that period can not be its last character.
the stem is the part of the symbol to the first period, with that period.
after the stem comes the tail: one name or more, with a period between two names.
each part of the tail is a constant symbol, a simple symbol, or null.
a constant symbol with a sign in it can not come after a stem; then the whole symbol is an error.
when rexx uses a compound symbol, it changes each simple symbol in the tail to its value; this makes a new tail.
the default value of a compound symbol is the name of the stem object, with the new tail after it.
when you assign a value to a compound symbol, rexx stores the value in the stem object, with the new tail as the index.
so many variables with the same stem can have any index.
the values in the new tail can have any characters, also periods and blanks.
rexx does this change only one time.
any part of the tail can be null, and any value in the new tail can be null.
rexx does not change lower letters in the new tail to upper.
rexx does not take away blanks in the new tail.
periods in the new tail have no special use.
the length of the new name has no maximum.
with compound symbols, you can make lists of variables whose index is not a number.
the code:
```rexx
FRED.3
Array.I.J
AMESSY..One.2.
a=3       /* assigns "3" to the variable A    */
z=4                 /*   "4"      to Z        */
c="Fred"            /*   "Fred"   to C        */
a.z="Fred"          /*   "Fred"   to A.4      */
a.fred=5            /*   "5"      to A.FRED   */
a.c="Bill"          /*   "Bill"   to A.Fred   */
c.c=a.fred          /*   "5"      to C.Fred   */
y.a.z="Annie"       /*   "Annie"  to Y.3.4    */
say  a  z  c  a.a  a.z  a.c  c.a  a.fred y.a.4
```
the result:
```
3 4 Fred A.3 Fred Bill C.3 5 Annie
```
the reference says:
```
3 4 Fred A.3 Fred Bill C.3 5 Annie
```

## environment symbols

```
.true
.RS  .LINE  .METHODS  .ROUTINES  .RESOURCES  .CONTEXT
```
an environment symbol starts with a period and has at least one other character.
it can not be a number.
its default value is its characters in upper.
if the symbol names an object in the environment, its value is that object.
rexx tests these places in order to find the object.
place 1: the constants true, false, and nil.
place 2: the classes that class directives make in this package, or that a method of the package adds.
place 3: the public classes of the files that this package gets with a directive, or that a method of the package adds.
place 4: the public classes that rexx gives in the rexx package, as the object, string, and array classes.
place 5: the local directory of the package.
place 6: the local directory of this run of rexx; it has the input stream and the output stream.
place 7: the global environment directory.
place 8: the symbols that rexx makes; they are in the second line of the code block.
if rexx finds no object, the symbol has its default value.
you can put items in the local directory of the package, in the local directory, and in the environment directory, for programs to use.
the local directory of the package has more precedence than the local directory, and the local directory has more precedence than the environment directory.
put at least one period in the name of each item you add, so it is not the same as a name that rexx can add.
the code:
```rexx
.method    -- A reference to the Rexx Method class
.true      -- The Rexx "true" object.  Has the value "1"
.xyz       -- Normally the value .XYZ
.3DGlasses -- Normally the value .3DGLASSES
.local~setEntry("MyProgram.settings", .directory~new)
```
the result:
```
```

## namespaces

```
natural:number
```
with a namespace, you can say which class or routine you want when two packages that you get with a directive have the same name for them.
a namespace name, a colon, and the name of a class or a routine name one class or routine.
the directive that gets a package can give that package a namespace name, with the namespace option.
the namespace rexx always gives the classes that rexx makes, as the array class.
a name with a namespace can also be the receiver of a message.
a class can be a subclass of a class with a namespace name.
the code:
```rexx
say .number~id
```
the result:
```
97.1
```
the reference says:
```
The Real Number class
```

the code:
```rexx
say natural:number~id
```
the result:
```
98.987
```
the reference says:
```
The Natural Number class
```

the code:
```rexx
say rexx:array~of(2, 3, 5, 7)~items
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
call natural:verify(17)                 /* call ::routine verify, not built-in function */
say natural:number~subclass("Integer")
```
the result:
```
98.987
```
the reference says:
```
The Integer class
```

the code:
```rexx
::class rationalNumber subclass natural:number
::requires 'number.cls' namespace natural
```
the result:
```
43.901
```
