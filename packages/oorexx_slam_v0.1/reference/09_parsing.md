# parse a string

this file is from the part of the rexx language rules about how to parse a string.

cuts: cut, for one thing
finds: find, for one thing
templates: more than one template
positional: a positional pattern is a number that says a position in the string
relative: a relative pattern says a position as a count from an other position

```
ARG template
PARSE [UPPER | LOWER | CASELESS] origin template
PULL template
```
these three instructions parse a string.
the instruction cuts the string in parts and puts each part in a variable of the template.
the template says how to cut the string.
a template can be only a list of variables; it cuts the string in words.
a template can also have patterns, with the variables.
a string pattern is a string; the instruction finds where the same characters are in the string, and cuts the string there.
a positional pattern is a number; it is the position where the instruction cuts the string.
the parse has two steps: first the patterns cut the string in parts, then the instruction cuts each part in words.

```
PARSE VALUE expression WITH var1 var2 var3
```
this instruction cuts the value of the expression in words.
each word goes to the next variable of the template, in order.
the instruction does not change lower letters to upper.
each variable in the template gets a new value.
if there are more variables than words, each variable after the last word gets a null string.
if there are more words than variables, the last variable gets the rest of the string.
the instruction takes away the blanks at the start and at the end of each word.
the last variable is not the same: it keeps the blanks of the rest of the string, but not the one blank after the word before it.
if the template has only one variable, the instruction takes away no blanks.
the code:
```rexx
parse value "time and tide" with var1 var2 var3
```
the result:
```
```
the reference says:
```
var1="time" var2="and" var3="tide"
```

the code:
```rexx
string="time and tide"; parse value string with var1 var2 var3
```
the result:
```
```
the reference says:
```
var1="time" var2="and" var3="tide"
```

the code:
```rexx
parse value "   Pluto   " with var1
```
the result:
```
```
the reference says:
```
var1="   Pluto   "
```

```
PARSE VAR name template
```
this instruction is the same as the parse instruction with the value keyword, but the string is the value of a variable.
the name of the variable is the first word after the keyword.
the code:
```rexx
stars="Sirius Polaris Rigil"; parse var stars star1 star2 star3
```
the result:
```
```
the reference says:
```
star1="Sirius" star2="Polaris" star3="Rigil"
```

the code:
```rexx
satellite="moon"; parse var satellite Earth Mercury
```
the result:
```
```
the reference says:
```
Earth="moon" Mercury=""
```

the code:
```rexx
satellites="moon Io Europa Callisto..."; parse var satellites Earth Jupiter
```
the result:
```
```
the reference says:
```
Earth="moon" Jupiter="Io Europa Callisto..."
```

the code:
```rexx
solar5="Mercury Venus  Earth   Mars     Jupiter  "; parse var solar5 var1 var2 var3 var4
```
the result:
```
```
the reference says:
```
var1="Mercury" var2="Venus" var3="Earth" var4="  Mars     Jupiter  "
```

```
PARSE VAR string n a[n] a[n + 1] d~three d~four
```
a part of a template can be a message to an object, not only a variable.
any thing you can put at the left of an assignment can get a part of the string.
the code:
```rexx
string = "1 one two 3 4"
a = .Array~new
d = .Directory~new
parse var string n a[n] a[n + 1] d~three d~four
-- a[1] = one
-- a[2] = two
-- d~three = 3
-- d~four = 4
```
the result:
```
```

```
PARSE VAR stars . . brightest .
```
a point in a template is a placeholder.
it is in the place of a variable, but it gets no data.
you can use it for a word you do not want, or for the rest of the string at the end.
with it, you do not have to use a variable that you do not need.
put a blank between two point marks that are next to each other; if not, it is an error.
the code:
```rexx
stars="Arcturus Betelgeuse Sirius Rigil"
parse var stars . . brightest .            /* brightest="Sirius" */
parse var stars drop junk brightest rest   /* brightest="Sirius" */
```
the result:
```
```

```
PARSE VAR name var1 ", " var2
```
this template has a literal string pattern: one or more characters between two quote marks.
the instruction finds where the pattern is in the string.
the variable before the pattern gets the data from the start of the string to the character before the pattern.
the variable after the pattern gets the data from the character after the pattern to the end of the string.
the characters of the pattern go to no variable.
in one special kind of template they do go to a variable: a string pattern, then a variable, then a relative positional pattern.
if the pattern is not in the string, the variables before the pattern get all the data, and the variables after it get a null string.
a null string pattern is never in the string; it always is at the end of the string.
the code:
```rexx
name="Smith, John"; parse var name ln fn
```
the result:
```
```
the reference says:
```
ln="Smith,"  fn="John"
```

the code:
```rexx
name="Smith, John"; parse var name ln ", " fn
```
the result:
```
```
the reference says:
```
ln="Smith"   fn="John"
```

```
PARSE VAR string 2 var1 4 1 var2 2 4 var3 5 11 var4
```
this template has absolute positional patterns.
an absolute positional pattern is a whole number.
the number is the position in the string where the instruction cuts it.
you can put an equal mark before the number; it does not change what the pattern does.
the pattern with the number one goes back to the first character of the string.
one template can give the same data to more than one variable.
the code:
```rexx
/* Backing up to an earlier position (with absolute positional)  */
string="astronomers"
parse var string 2 var1 4 1 var2 2 4 var3 5 11 var4
say string "study" var1||var2||var3||var4
/* Displays: "astronomers study stars"                           */
/* Making several assignments                                    */
books="Silas Marner, Felix Holt, Daniel Deronda, Middlemarch"
parse var books 1 Eliot 1 Evans
/* Assigns the (entire) value of books to Eliot and to Evans.    */
```
the result:
```
astronomers study stars
```

plus: the name of a mark; you can put it before a number
minus: the name of a mark; it is the sign of a negative number
match: a place in the string where the instruction finds a pattern
```
PARSE VAR string 2 var1 +2 -3 var2 +1 +2 var3 +1 +6 var4
```
this template has relative positional patterns.
a relative positional pattern is a number with the plus mark or the minus mark before it.
for the first pattern, the instruction counts the number from the start of the string.
for a pattern after the first, it counts from the first character of the last match.
blanks between the mark and the number do not change what the pattern does.
you can use zero in a relative pattern.
a number with the minus mark goes back to a position before.
absolute and relative patterns can do the same things, but not in one special kind of template.
that special template is a string pattern, then a variable, then a relative positional pattern.
the code:
```rexx
/* Backing up to an earlier position (with relative positional)  */
string="astronomers"
parse var string 2 var1 +2 -3 var2 +1 +2 var3 +1 +6 var4
say string "study" var1||var2||var3||var4      /* same results   */
```
the result:
```
astronomers study stars
```

```
PARSE VAR line len +2 first >(len) len +2 middle >(len) len +2 last >(len)
```
this template has length positional patterns.
a length pattern is a number with the mark for more than or the mark for less than before it.
the instruction counts the number from the position where it is now.
blanks between the mark and the number do not change what the pattern does.
you can use zero in a length pattern.
the mark for more than and the plus mark do the same thing, but not with zero.
the more than pattern with zero cuts a null string, and the position does not change.
the mark for less than goes to the left.
the instruction cuts the string between the position before and the new position, then it goes back to the position before.
a less than pattern is the same as a negative relative pattern, then a positive relative pattern with the same number.
the code:
```rexx
/* Parsing with length patterns in template         */
line = "04Mark0005Twain"
parse var line len +2 first >(len) len +2 middle >(len) len +2 last >(len)
say '"'first'" "'middle'" "'last'"'  -- displays "Mark" "" "Twain"
/* parsing with relative patterns only */
parse var line len +2 first +(len) len +2 middle +(len) len +2 last +(len)
say '"'first'" "'middle'" "'last'"'  -- displays "Mark" "05Twain" "Twain"
/* Parsing with length patterns in template         */
parse value '12345.6789' with '.' digit <1    -- digit
```
the result:
```
"Mark" "" "Twain"
"Mark" "05Twain" "Twain"
```
the reference says:
```
5
```

the code:
```rexx
/* parsing with relative patterns only */
parse value '12345.6789' with '.' -1 digit +1    -- digit
```
the result:
```
```
the reference says:
```
5
```

```
PARSE VAR name fn init "." ln
```
the patterns cut the template in parts, and cut the string in parts.
the instruction cuts each part of the string in words, with the rules for words, and with the variables of the same part of the template.
it takes away the blanks at the start and at the end of each word, but not for the last variable of a part.
for the last variable of a part, it takes away one blank between words, and keeps the other blanks.
if a variable is the only variable in its part, it gets the whole part of the string, and no blanks go away.
the code:
```rexx
name="    John      Q.   Public"; parse var name fn init "." ln
```
the result:
```
```
the reference says:
```
fn="John" init="     Q" ln="   Public"
```

the code:
```rexx
string="R E X X"; parse var string var1 var2 4 var3 6 var4
```
the result:
```
```
the reference says:
```
var1="R" var2="E" var3=" X" var4=" X"
```

```
PARSE VAR date month 3 delim +1 day +2 (delim) year
```
a pattern can be a variable or an expression between parentheses.
if there is no mark before the parentheses, the value of the expression is a string pattern.
the expression can use variables that get a value before it in the same template.
if there is an equal mark, a plus mark, a minus mark, or a mark for more than or less than before the parentheses, the value is a positional pattern.
then the value must be a positive whole number or zero.
the instruction cuts the string with the patterns, and after that it cuts the parts in words.
the code:
```rexx
date="11/15/98"; parse var date month 3 delim +1 day +2 (delim) year
```
the result:
```
```
the reference says:
```
month="11" delim="/" day="15" year="98"
```

the code:
```rexx
dataline = "12 26 .....Samuel ClemensMark Twain"; parse var dataline pos1 pos2 6 =(pos1) realname =(pos2) pseudonym
```
the result:
```
```
the reference says:
```
realname="Samuel Clemens" pseudonym="Mark Twain"
```

```
PARSE UPPER origin template
ARG template          -- same as PARSE UPPER ARG template
PULL template         -- same as PARSE UPPER PULL template
```
with this option, the instruction changes each lower letter to upper before it cuts the string.
the second line and the third line are short ways to write the parse instruction with this option.
to keep the lower letters, write the parse instruction without this option.
the code:
```rexx
arg var1 var2  /* program called as: palette red blue */
```
the result:
```
```
the reference says:
```
var1="RED" var2="BLUE"
```

```
PARSE LOWER origin template
```
with this option, the instruction changes each upper letter to lower before it cuts the string.

```
PARSE CASELESS origin template
```
with this option, each compare that the instruction does to find a pattern is caseless.
a letter in upper is equal to the same letter in lower.

```
PARSE ARG template
```
this instruction cuts the arguments you give when you call the program, a subroutine, or a function.
it does not change lower letters to upper.

```
PARSE LINEIN template
```
this instruction cuts the next line of the default input stream.

```
PARSE PULL template
```
this instruction cuts the string at the start of the external data queue.
if the queue is empty, it reads a line from the default input.
the code:
```rexx
PUSH "80 7"                /* Puts data on queue                 */
parse pull fourscore seven
```
the result:
```
```
the reference says:
```
fourscore="80" seven="7"
```

the code:
```rexx
SAY fourscore+seven
```
the result:
```
41.1
```
the reference says:
```
87
```

```
PARSE SOURCE template
```
this instruction cuts a string that the computer gives; the string says what program runs.
the code:
```rexx
parse source sysname .
say sysname  /* Possibly Displays */
```
the result:
```
LINUX
```
the reference says:
```
Windows
```

```
PARSE VERSION template
```
this instruction cuts a string that the computer gives about the language.
the code:
```rexx
parse version . level .
say level                /* Displays: "6.02" */
```
the result:
```
6.06
```

```
PARSE ARG template1, template2
ARG template1, template2
```
only these two instructions can parse more than one string.
you write more than one template, with a comma between each two templates.
each comma says: go to the next string.
the strings are the arguments of the program, or of a routine or function you call.
a rexx program you run as a command gets only one string.
a rexx program gets more than one string when an other rexx program calls it, or when a program in an other language starts it.
if there are more templates than strings, each variable in the templates after the last string gets a null string.
if there are more strings than templates, the instruction ignores the strings after the last template.
if a template is empty, or has no variable, the instruction goes to the next template and the next string.
the code:
```rexx
num="3"
musketeers="Porthos Athos Aramis D'Artagnan"
CALL Sub num,musketeers  /* Passes num and musketeers to sub     */
SAY total; say fourth /* Displays: "4" and " D'Artagnan"         */
Sub:
  parse arg subtotal, . . . fourth
  total=subtotal+1
  RETURN
```
the result:
```
41.1
```

```
PARSE VAR string var1 3 junk "X" var2 +1 junk "X" var3 +1 junk
```
this is the special kind of template: a string pattern, then a variable, then a relative positional pattern.
here the instruction does not take away the characters of the string pattern.
it counts the relative pattern from the first character of the match of the string pattern.
so the variable gets the characters of the match.
the code:
```rexx
string="REstructured eXtended eXecutor"
parse var string var1 3 junk "X" var2 +1 junk "X" var3 +1 junk
say var1||var2||var3
```
the result:
```
REXX
```
the reference says:
```
REXX
```
