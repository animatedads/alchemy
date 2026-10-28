# builtin functions first part

this file is from the rules of the oorexx language about builtin functions: the first part of the list of functions.

## words i add here

fourth: the next after the third
fifth: the next after the fourth
raises: raise, for one thing
systems: more than one system
drive: a letter and a colon at the start of a file name on windows; it names a disk
day: a part of time; each day is the same count of time as each other day
days: more than one day
week: seven days, one after the other; each day of a week has a name
year: a part of time with many days; each year has a number
years: more than one year
month: a part of a year; a year has ten and two of them, and each month has a name
seconds: a way to count time; one day is a count of many seconds
milliseconds: a way to count time; one of the seconds is ten times ten times ten milliseconds
microseconds: a way to count time; one of the milliseconds is ten times ten times ten microseconds
english: the name of a language; the words of this file are english words
numeric: an instruction that says how a program does maths and how it writes numbers
notready: the name of an event; a function that reads or writes a stream can raise it when there is an error
persistent: a stream is persistent when you can read its data again after the program ends, as a file on a disk
transient: a stream is transient when it is not persistent, as the input that a program gets from you
syntax: the rules of the language about the order of words and marks in code; also the name of the condition that is raised for an error in code
trapped: an event is trapped when a trap for it is on and runs
places: more than one place

## the functions

```
ABBREV(information, info [,length])
```
abbrev: a builtin function that tests if a string is the start of an other string
this function tests if the second argument is the same as the first characters of the first argument.
the result is 1 if the second argument is equal to the start of the first argument, and the length of the second argument is not less than the length argument.
else the result is 0.
the length argument is the count of characters at the start that must be equal.
the length argument is optional.
the length argument must be a positive whole number or zero.
the default length is the count of characters in the second argument.
if the second argument is empty, the result is 1 when the length argument is 0 or when you omit it.
so a program can use this function to make one keyword the default keyword.
the code:
```rexx
say ABBREV("Print","Pri")
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
say ABBREV("PRINT","Pri")
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
say ABBREV("PRINT","PRI",4)
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
say ABBREV("PRINT","PRY")
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
say ABBREV("PRINT","")
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
say ABBREV("PRINT","",1)
```
the result:
```
0
```
the reference says:
```
0
```

```
ABS(number)
```
abs: a builtin function that gives the absolute value of a number
this function gives the absolute value of the number argument.
the result has no sign.
the function writes the result in the way that the numeric instruction says now.
the code:
```rexx
say ABS("12.3")
```
the result:
```
12.3
```
the reference says:
```
12.3
```

the code:
```rexx
say ABS(" -0.307")
```
the result:
```
0.307
```
the reference says:
```
0.307
```

```
ADDRESS()
```
address: a builtin function that gives the name of the environment that gets commands
this function has no arguments.
this function gives the name of the environment that gets each command now.
the function takes away the blanks at the end of the result.
the code:
```rexx
Say ADDRESS()
```
the result:
```
sh
```
the reference says:
```
"CMD"   // default for Windows
```

the code:
```rexx
Say ADDRESS()
```
the result:
```
sh
```
the reference says:
```
"sh"    // default for Unix-like systems
```

```
ARG([n [,option]])
```
arg: a builtin function that gives the arguments of a program, a routine, or a method, or facts about them
this function gives one or more arguments of the program, the routine, or the method that runs now, or facts about the arguments.
with no arguments, this function gives the count of arguments.
with only the first argument, this function gives the argument at that position.
if the argument at that position is not there, the result is an empty string.
the first argument must be a positive whole number.
the second argument is an option; the option says what the result is.
the function uses only the first character of the option, and ignores the characters after it.
```
ARG(n,'A')   Array
```
with this option, the result is an array of the arguments, from the argument at the position in the first argument.
that argument has the index 1 in the array, the next argument has the index 2, and so on.
an omitted argument has no item at its index in the array.
```
ARG(n,'E')   Exists
```
with this option, the result is 1 if the caller gives the argument at that position, else 0.
the count of arguments is the last position where this option gives 1.
```
ARG(n,'N')   Normal
```
with this option, the result is the argument at that position, or an empty string if it is not there.
```
ARG(n,'O')   Omitted
```
with this option, the result is 1 if the caller does not give the argument at that position, else 0.
if there are no arguments, the count is 0.
a program that you call as a command can have only 0 or 1 argument strings.
when you call a program as a command, all the text after its name, with blanks, is one argument string.
you can get the argument objects of a program with the use instruction.
you can get the argument strings and parse them with the arg instruction or the parse arg instruction.
the code:
```rexx
/* after: Call name; */
Say ARG()
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
Say ARG(1)
```
the result:
```

```
the reference says:
```

```

the code:
```rexx
Say ARG(2)
```
the result:
```

```
the reference says:
```

```

the code:
```rexx
Say ARG(1,"e")
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
Say ARG(1,"O")
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
Say ARG(1,"a")
```
the result:
```

```
the reference says:
```
.array~of()
```

the code:
```rexx
/* after: Call name 'a', ,'b'; */
Say ARG()
```
the result:
```
0
```
the reference says:
```
3
```

the code:
```rexx
Say ARG(1)
```
the result:
```

```
the reference says:
```
a
```

the code:
```rexx
Say ARG(2)
```
the result:
```

```
the reference says:
```

```

the code:
```rexx
Say ARG(3)
```
the result:
```

```
the reference says:
```
b
```

the code:
```rexx
Say ARG(n)  /* for n>=4 */
```
the result:
```
40.12
```
the reference says:
```

```

the code:
```rexx
Say ARG(1,"e")
```
the result:
```
0
```
the reference says:
```
1
```

the code:
```rexx
Say ARG(2,"E")
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
Say ARG(2,"O")
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
Say ARG(3,"o")
```
the result:
```
1
```
the reference says:
```
0
```

the code:
```rexx
Say ARG(4,"o")
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
Say ARG(1,"A")
```
the result:
```

```
the reference says:
```
.array~of(a, ,b)
```

the code:
```rexx
Say ARG(3,"a")
```
the result:
```

```
the reference says:
```
.array~of(b)
```

```
B2X(binary_string)
```
this function gives the hexadecimal value of a binary string.
the argument is a string of binary digits.
the argument can have any length.
the letters in the result are in upper.
the result has no blanks.
you can put blanks in the argument, so that you can read it.
the blanks can be only between two parts of four digits each, not at the start or at the end.
the function ignores the blanks.
if the argument is an empty string, the result is an empty string.
if the count of digits has a remainder when you divide it by four, the function adds one, two, or three 0 digits at the left before it changes the string.
the code:
```rexx
say B2X("11000011")
```
the result:
```
C3
```
the reference says:
```
C3
```

the code:
```rexx
say B2X("10111")
```
the result:
```
17
```
the reference says:
```
17
```

the code:
```rexx
say B2X("101")
```
the result:
```
5
```
the reference says:
```
5
```

the code:
```rexx
say B2X("1 1111 0000")
```
the result:
```
1F0
```
the reference says:
```
1F0
```

the code:
```rexx
say X2D(B2X("10111"))  /* decimal 23 */
```
the result:
```
23
```
the reference says:
```
23
```

```
BEEP(frequency, duration)
```
sound: a thing the computer can make; it has a frequency, and it is there for some time
hertz: a way to count a frequency; one hertz is one time in each of the seconds
beep: a builtin function that makes the computer give a sound
this function makes the computer give a sound.
the first argument is the frequency of the sound in hertz.
the frequency must be a whole number from 37 to 32767.
the second argument is the time of the sound in milliseconds.
the second argument must be a whole number from 0 to 60000.
the result is an empty string.
the way to use this function is to call it as a subroutine.
on some systems the function can not make a sound at a frequency.
on windows, the sound can be off.

```
BITAND(string1 [,[string2] [,pad]])
```
bitand: a builtin function that gives the and of the bits of two strings
this function gives a string from the bits of the two strings.
each bit of the result is 1 when the bit of the first string and the bit of the second string are both 1; else it is 0.
the function uses the bytes of the strings.
the second string is optional; the default is an empty string.
the pad argument is optional.
the length of the result is the maximum of the length of the two strings.
if you omit the pad argument, the function stops at the end of the short string, and puts the rest of the other string at the end of the result.
if you give the pad argument, the function first puts pad characters at the right of the short string.
the code:
```rexx
say c2x(BITAND("12"x))
```
the result:
```
12
```
the reference says:
```
12
```

the code:
```rexx
say c2x(BITAND("73"x,"27"x))
```
the result:
```
23
```
the reference says:
```
23
```

the code:
```rexx
say c2x(BITAND("13"x,"5555"x))
```
the result:
```
1155
```
the reference says:
```
1155
```

the code:
```rexx
say c2x(BITAND("13"x,"5555"x,"74"x))
```
the result:
```
1154
```
the reference says:
```
1154
```

the code:
```rexx
say BITAND("pQrS", ,"DF"x)  /* ASCII   */
```
the result:
```
PQRS
```
the reference says:
```
PQRS
```

```
BITOR(string1 [,[string2] [,pad]])
```
bitor: a builtin function that gives the or of the bits of two strings
this function gives a string from the bits of the two strings.
each bit of the result is 1 when one or both of the two bits are 1; else it is 0.
the function uses the bytes of the strings.
the second string is optional; the default is an empty string.
the pad argument is optional.
the length of the result is the maximum of the length of the two strings.
if you omit the pad argument, the function stops at the end of the short string, and puts the rest of the other string at the end of the result.
if you give the pad argument, the function first puts pad characters at the right of the short string.
the code:
```rexx
say c2x(BITOR("12"x))
```
the result:
```
12
```
the reference says:
```
12
```

the code:
```rexx
say c2x(BITOR("15"x,"24"x))
```
the result:
```
35
```
the reference says:
```
35
```

the code:
```rexx
say c2x(BITOR("15"x,"2456"x))
```
the result:
```
3556
```
the reference says:
```
3556
```

the code:
```rexx
say c2x(BITOR("15"x,"2456"x,"F0"x))
```
the result:
```
35F6
```
the reference says:
```
35F6
```

the code:
```rexx
say c2x(BITOR("1111"x, ,"4D"x))
```
the result:
```
5D5D
```
the reference says:
```
5D5D
```

the code:
```rexx
say BITOR("pQrS", ,"20"x)  /* ASCII   */
```
the result:
```
pqrs
```
the reference says:
```
pqrs
```

```
BITXOR(string1 [,[string2] [,pad]])
```
bitxor: a builtin function that gives a string with a bit one where only one of the bits of two strings is one
this function gives a string from the bits of the two strings.
each bit of the result is 1 when only one of the two bits is 1; else it is 0.
the function uses the bytes of the strings.
the second string is optional; the default is an empty string.
the pad argument is optional.
the length of the result is the maximum of the length of the two strings.
if you omit the pad argument, the function stops at the end of the short string, and puts the rest of the other string at the end of the result.
if you give the pad argument, the function first puts pad characters at the right of the short string.
the code:
```rexx
say c2x(BITXOR("12"x))
```
the result:
```
12
```
the reference says:
```
12
```

the code:
```rexx
say c2x(BITXOR("12"x,"22"x))
```
the result:
```
30
```
the reference says:
```
30
```

the code:
```rexx
say c2x(BITXOR("1211"x,"22"x))
```
the result:
```
3011
```
the reference says:
```
3011
```

the code:
```rexx
say c2x(BITXOR("1111"x,"444444"x))
```
the result:
```
555544
```
the reference says:
```
555544
```

the code:
```rexx
say c2x(BITXOR("1111"x,"444444"x,"40"x))
```
the result:
```
555504
```
the reference says:
```
555504
```

the code:
```rexx
say c2x(BITXOR("1111"x, ,"4D"x))
```
the result:
```
5C5C
```
the reference says:
```
5C5C
```

the code:
```rexx
say c2x(BITXOR("C711"x,"222222"x," "))  /* ASCII  */
```
the result:
```
E53302
```
the reference says:
```
E53302
```

```
C2D(string [,n])
```
this function gives the decimal value of the bytes of the string.
if the string is empty, the result is 0.
if you omit the second argument, the function reads the string as a binary number with no sign.
the second argument is the count of characters of the string that the function reads as a number with a sign.
with the second argument, if the first bit is 0 the number is positive, and if the first bit is 1 the number is negative.
with the second argument, the result is a whole number, and it can be negative.
with the second argument, if the string is short, the function puts bytes with the value 0 at the left of it.
with the second argument, if the string has more characters than the second argument, the function takes away characters at the left of it.
if the second argument is 0, the result is always 0.
it is an error if the result has more digits than the precision now.
the code:
```rexx
say C2D("09"X)
```
the result:
```
9
```
the reference says:
```
9
```

the code:
```rexx
say C2D("81"X)
```
the result:
```
129
```
the reference says:
```
129
```

the code:
```rexx
say C2D("FF81"X)
```
the result:
```
65409
```
the reference says:
```
65409
```

the code:
```rexx
say C2D("")
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
say C2D("a")  /*  ASCII   */
```
the result:
```
97
```
the reference says:
```
97
```

the code:
```rexx
say C2D("81"X,1)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
say C2D("81"X,2)
```
the result:
```
129
```
the reference says:
```
129
```

the code:
```rexx
say C2D("FF81"X,2)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
say C2D("FF81"X,1)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
say C2D("FF7F"X,1)
```
the result:
```
127
```
the reference says:
```
127
```

the code:
```rexx
say C2D("F081"X,2)
```
the result:
```
-3967
```
the reference says:
```
-3967
```

the code:
```rexx
say C2D("F081"X,1)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
say C2D("0031"X,0)
```
the result:
```
0
```
the reference says:
```
0
```

```
C2X(string)
```
this function gives the hexadecimal value of the bytes of the string, as a string of characters.
the result has two characters for each byte of the string.
the letters in the result are in upper.
the result has no blanks.
the string can have any length.
if the string is empty, the result is an empty string.
the code:
```rexx
say C2X("0123"X)  /* "30313233"X in ASCII     */
```
the result:
```
0123
```
the reference says:
```
0123
```

the code:
```rexx
say C2X("ZD8")  /* "354134343338"X in ASCII */
```
the result:
```
5A4438
```
the reference says:
```
5A4438
```

the code:
```rexx
say C2X(1)  /* on an ASCII system       */
```
the result:
```
31
```
the reference says:
```
31
```

```
CENTER(string, length [,pad])
CENTRE(string, length [,pad])
```
center: a builtin function that puts a string in the middle of a new string
centre: an other name of the builtin function center
this function gives a string with the length in the length argument, and the string argument in the middle of it.
the function adds pad characters at the left and the right as it needs.
the length argument must be a positive whole number or zero.
the default pad character is a blank.
if the string is more than the length argument, the function takes away characters at the left and the right of it.
when the count of characters to add has a remainder when you divide it by two, the right end gets one more character than the left end.
when the count of characters to take away has a remainder when you divide it by two, the function takes one more character from the right end than from the left end.
you can call this function with the name center or with the name centre.
the code:
```rexx
say CENTER(abc,7)
```
the result:
```
  ABC  
```
the reference says:
```
  ABC  
```

the code:
```rexx
say CENTER(abc,8,"-")
```
the result:
```
--ABC---
```
the reference says:
```
--ABC---
```

the code:
```rexx
say CENTRE("The blue sky",8)
```
the result:
```
e blue s
```
the reference says:
```
e blue s
```

the code:
```rexx
say CENTRE("The blue sky",7)
```
the result:
```
e blue 
```
the reference says:
```
e blue 
```

```
CHANGESTR(needle, haystack, newneedle [,count])
```
changestr: a builtin function that puts a string in place of each place where an other string is in a third string
this function gives a new string from the second argument.
in the new string, the third argument is in place of each place where the first argument is in the second argument.
the second argument does not change.
the count argument is optional.
the count argument is the maximum count of changes that the function makes.
the count argument must be a positive whole number or zero.
if you omit the count argument, the function changes each place.
the code:
```rexx
say CHANGESTR("1","101100","")
```
the result:
```
000
```
the reference says:
```
000
```

the code:
```rexx
say CHANGESTR("1","101100","X")
```
the result:
```
X0XX00
```
the reference says:
```
X0XX00
```

the code:
```rexx
say CHANGESTR("1","101100","X", 1)
```
the result:
```
X01100
```
the reference says:
```
X01100
```

```
CHARIN([name] [,[start] [,length]])
```
charin: a builtin function that reads characters from a stream
this function reads characters from a stream and gives them as the result.
the name argument is the name of the stream.
if you omit the name argument, this function reads from the default input stream.
the length argument is the count of characters to read.
the default length is 1.
the result has no more characters than the length argument.
the language keeps a read position for each persistent stream.
by default, this function starts to read at the read position.
after the read, the function adds the count of characters it reads to the read position.
the start argument is a position in the stream where the read starts.
the start argument must be a positive whole number, and the stream must have that position.
the position 1 is the first character of the stream.
you must not give the start argument for a transient stream.
if the start argument is not a positive whole number, it is an error.
if the read position is after the end of the stream, the result is an empty string, and the notready event is raised.
if the length is 0, the function makes the start argument the read position, reads no characters, and gives an empty string.
with a transient stream, if there are less characters than the length, the program waits until the characters are there.
if an error makes the characters never come, the notready event is raised, and the function gives less characters.
this function gives each character of the stream, also the characters at the end of each line and at the end of the file.
the code:
```rexx
say CHARIN(myfile,1,3)  /* the first 3        */
```
the result:
```

```
the reference says:
```
MFC
```

the code:
```rexx
                                 /* characters         */
say CHARIN(myfile,1,0)  /* now at start       */
```
the result:
```

```
the reference says:
```

```

the code:
```rexx
say CHARIN(myfile)  /* after last call    */
```
the result:
```

```
the reference says:
```
M
```

the code:
```rexx
say CHARIN(myfile, ,2)  /* after last call    */
```
the result:
```

```
the reference says:
```
FC
```

the code:
```rexx
/* Reading from the default input (here, the keyboard)   */
/* User types "abcd efg"                                 */
say CHARIN()  /* default is         */
```
the result:
```

```
the reference says:
```
a
```

the code:
```rexx
                                 /* 1 character        */
say CHARIN(, ,5)
```
the result:
```

```
the reference says:
```
bcd e
```

```
CHAROUT([name] [,[string] [,start]])
```
charout: a builtin function that writes characters to a stream
this function writes the string argument to the stream with the name in the name argument.
the result is the count of characters that the function can not write.
the result is 0 when the function writes all the characters.
if you omit the name argument, this function writes to the default output stream.
the string can be an empty string; then the function writes no characters, and the result is always 0.
the language keeps a write position for each persistent stream.
by default, this function starts to write at the write position.
after the write, the function adds the count of characters it writes to the write position.
when a program uses a persistent stream the first time, the write position is at the end of the stream, so the function adds the string at the end.
the start argument is a position in the stream where the write starts.
for a persistent stream, the start argument must be a positive whole number.
the position 1 is the first character of the stream.
if you omit the string, the function makes the start argument the write position, writes no characters, and gives 0.
if you omit the string and the start argument, the function ends the use of the stream, and gives 0.
the program waits until the write is at an end.
if the function can not write all the characters, the notready event is raised, and the result is the count of characters that it can not write.
you can call this function as a subroutine; then the count is in the variable result.
the code:
```rexx
say CHAROUT(myfile,"Hi")  /* typically        */
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
say CHAROUT(myfile,"Hi",5)  /* typically        */
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
say CHAROUT(myfile, ,6)  /* now at char 6    */
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
say CHAROUT(myfile)  /* at end of stream */
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
say CHAROUT(,"Hi")  /* typically        */
```
the result:
```
Hi0
```
the reference says:
```
0
```

the code:
```rexx
say CHAROUT(,"Hello")  /* maybe            */
```
the result:
```
Hello0
```
the reference says:
```
2
```

```
CHARS([name])
```
chars: a builtin function that counts the characters of a stream that a program has not read yet
this function gives the count of characters in the stream that the program has not read yet.
the name argument is the name of the stream.
if you omit the name argument, this function counts the characters of the default input stream.
the count has the characters at the end of each line, if the stream has them.
for a persistent stream, the count starts at the read position.
for some streams, as the default input stream, the function can not get the count.
for these streams, the result is 1 if the stream has data, and 0 if it has no data.
the code:
```rexx
say CHARS(myfile)  /* perhaps */
```
the result:
```
0
```
the reference says:
```
42
```

the code:
```rexx
say CHARS(nonfile)
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
say CHARS()  /* perhaps */
```
the result:
```
0
```
the reference says:
```
1
```

```
COMPARE(string1, string2 [,pad])
```
this function compares two strings.
the result is 0 if the two strings are the same.
else the result is the position of the first character that is not the same in the two strings.
if a string is short, the function first puts pad characters at the right of it.
the default pad character is a blank.
the code:
```rexx
say COMPARE("abc","abc")
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
say COMPARE("abc","ak")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say COMPARE("ab ","ab")
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
say COMPARE("ab ","ab"," ")
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
say COMPARE("ab ","ab","x")
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
say COMPARE("ab-- ","ab","-")
```
the result:
```
5
```
the reference says:
```
5
```

```
CONDITION([option])
```
user: a word for a condition that a program makes; the name of a user condition starts with the word user
subcode: a number that says more about an error
delay: make a thing wait
additional: more; the additional object of an event has more data about it
this function gives facts about the trapped condition now.
the argument is an option.
the function uses only the first character of the option, and ignores the characters after it.
if you omit the option, the result is the same as with the option for the instruction.
```
CONDITION('A')   Additional
```
with this option, the result is the additional object of the trapped condition.
if there is no additional object, or no condition is trapped, the result is nil.
```
CONDITION('C')   Condition name
```
with this option, the result is the name of the trapped condition.
for a user condition, the result is the word user, a blank, and the name of the condition.
```
CONDITION('D')   Description
```
with this option, the result is the string that says what the trapped condition is.
if the condition has no string that says what it is, or no condition is trapped, the result is an empty string.
```
CONDITION('E')   Extra
```
with this option, the result is the rexx error subcode of a trapped syntax condition.
if no syntax condition is trapped, the result is an empty string.
```
CONDITION('I')   Instruction
```
with this option, the result is the keyword of the instruction of the trap: call or signal.
if no condition is trapped, the result is an empty string.
```
CONDITION('O')   Object
```
with this option, the result is an object with all the data about the trapped condition.
if no condition is trapped, the result is nil.
```
CONDITION('R')   Reset
```
with this option, the function makes the program have no trapped condition, and the result is an empty string.
after this, each option gives the value it gives when no condition is trapped.
```
CONDITION('S')   Status
```
with this option, the result says what the trap of the condition is now; it can change while the program runs.
the result is on when the condition is on.
the result is off when the condition is off.
the result is delay when the program does not use a new event of the condition now: it makes the event wait, or it ignores the event.
if no condition is trapped, the result is an empty string.
the language keeps the facts about the trapped condition when you call a subroutine, and gets them back when the subroutine returns.
this is also so for a subroutine that a call on trap calls.
when that subroutine returns, the trapped condition is again the one before the call, or no condition.
then this function gives the same results as before the call.
the code:
```rexx
say CONDITION()  /* perhaps */
```
the result:
```

```
the reference says:
```
CALL
```

the code:
```rexx
say CONDITION("C")
```
the result:
```

```
the reference says:
```
FAILURE
```

the code:
```rexx
say CONDITION("I")
```
the result:
```

```
the reference says:
```
CALL
```

the code:
```rexx
say CONDITION("D")
```
the result:
```

```
the reference says:
```
FailureTest
```

the code:
```rexx
say CONDITION("S")  /* perhaps */
```
the result:
```

```
the reference says:
```
OFF
```

```
COPIES(string, n)
```
copies: a builtin function that gives a string many times, one after the other
this function gives the string again and again, one after the other.
the second argument is the count of times the string is in the result.
the second argument must be a positive whole number or zero.
if the second argument is 0, the result is an empty string.
the code:
```rexx
say COPIES("abc",3)
```
the result:
```
abcabcabc
```
the reference says:
```
abcabcabc
```

the code:
```rexx
say COPIES("abc",0)
```
the result:
```

```
the reference says:
```

```

```
COUNTSTR(needle, haystack)
```
countstr: a builtin function that counts the times a string is in an other string
this function gives the count of places where the first argument is in the second argument.
the function counts only places that do not use the same characters as an other place it counts.
the result is a whole number.
the code:
```rexx
say COUNTSTR("1","101101")
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
say COUNTSTR("KK","J0KKK0")
```
the result:
```
1
```
the reference says:
```
1
```

```
D2C(wholenumber [,n])
```
this function gives the character string of the decimal number in the first argument.
the first argument must not have more digits than the precision now.
the second argument is optional.
the second argument is the length of the result.
the second argument must be a positive whole number or zero.
with the second argument, the function puts bytes at the left of the result as it needs to get that length.
for a positive number these bytes have the value 0, and for a negative number all the bits of these bytes are 1.
if you omit the second argument, the first argument must be a positive whole number or zero.
if you omit the second argument, the result has the length it needs, so it has no bytes with the value 0 at the left.
the code:
```rexx
say D2C(65)  /* "41"x is an ASCII "A"               */
```
the result:
```
A
```
the reference says:
```
A
```

the code:
```rexx
say D2C(65,1)
```
the result:
```
A
```
the reference says:
```
A
```

the code:
```rexx
say c2x(D2C(65,2))  /* the leading character is a "00"x    */
```
the result:
```
0041
```
the reference says:
```
0041
```

the code:
```rexx
say c2x(D2C(65,5))  /* the leading characters are "00"x    */
```
the result:
```
0000000041
```
the reference says:
```
0000000041
```

the code:
```rexx
say D2C(109)  /* "6D"x  is an ASCII "m"              */
```
the result:
```
m
```
the reference says:
```
m
```

the code:
```rexx
say c2x(D2C(-109,1))  /* "93"x is an ASCII "ô"   */
```
the result:
```
93
```
the reference says:
```
93
```

the code:
```rexx
say c2x(D2C(76,2))  /* "4C"x  is an ASCII "L"              */
```
the result:
```
004C
```
the reference says:
```
004C
```

the code:
```rexx
say c2x(D2C(-180,2))  /* the leading character is a "FF"x    */
```
the result:
```
FF4C
```
the reference says:
```
FF4C
```

```
D2X(wholenumber [,n])
```
this function gives the hexadecimal value of the decimal number in the first argument, as a string of characters.
the letters in the result are in upper.
the result has no blanks.
the first argument must not have more digits than the precision now.
the second argument is optional.
the second argument is the length of the result.
the second argument must be a positive whole number or zero.
with the second argument, a negative number gets hexadecimal digits with all bits 1 at the left, until the result has that length.
if the number has more digits than the second argument, the function takes away digits at the left.
if you omit the second argument, the first argument must be a positive whole number or zero.
if you omit the second argument, the result has no zero digits at the left.
the code:
```rexx
say D2X(9)
```
the result:
```
9
```
the reference says:
```
9
```

the code:
```rexx
say D2X(129)
```
the result:
```
81
```
the reference says:
```
81
```

the code:
```rexx
say D2X(129,1)
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
say D2X(129,2)
```
the result:
```
81
```
the reference says:
```
81
```

the code:
```rexx
say D2X(129,4)
```
the result:
```
0081
```
the reference says:
```
0081
```

the code:
```rexx
say D2X(257,2)
```
the result:
```
01
```
the reference says:
```
01
```

the code:
```rexx
say D2X(-127,2)
```
the result:
```
81
```
the reference says:
```
81
```

the code:
```rexx
say D2X(-127,4)
```
the result:
```
FF81
```
the reference says:
```
FF81
```

the code:
```rexx
say D2X(12,0)
```
the result:
```

```
the reference says:
```

```

```
DATATYPE(string [,type])
```
datatype: a builtin function that tests what kind of data a string is
num: the word that datatype gives when a string is a number
char: the word that datatype gives when a string is not a number
with only the string argument, the result is num if the string is a rexx number that you can add to 0 without an error.
with only the string argument, else the result is char.
the second argument is an option; with it, the result is 1 if the string is of the kind that the option says, else 0.
the function uses only the first character of the option, and ignores the characters after it.
the first character of the option must be the letter in upper in the name of the option.
```
DATATYPE(string,'A')   Alphanumeric
```
with this option, the result is 1 if the string has only letters from the first letter to the last letter, in upper or in lower, and the digits from 0 to 9.
```
DATATYPE(string,'B')   Binary
```
with this option, the result is 1 if the string has only the digits 0 and 1, and blanks.
the blanks can be only between two parts of four digits each.
with this option, an empty string gives 1.
```
DATATYPE(string,'I')   Internal whole number
```
with this option, the result is 1 if the string is a rexx whole number that builtin functions can use.
the builtin functions use a precision of 9 on a 32 bit system, and a precision of 18 on a 64 bit system.
```
DATATYPE(string,'L')   Lowercase
```
with this option, the result is 1 if the string has only letters in lower.
```
DATATYPE(string,'M')   Mixed case
```
with this option, the result is 1 if the string has only letters, in upper or in lower.
```
DATATYPE(string,'N')   Number
```
with this option, the result is 1 if this function with only the string argument gives num.
```
DATATYPE(string,'O')   lOgical
```
with this option, the result is 1 if the string is only the character 0 or only the character 1, else 0.
```
DATATYPE(string,'S')   Symbol      /* 1 if SYMBOL(string) does not return 'BAD' */
```
with this option, the result is 1 if the string can be a symbol, as the code before this line says.
the string can have letters in upper and in lower.
```
DATATYPE(string,'U')   Uppercase
```
with this option, the result is 1 if the string has only letters in upper.
```
DATATYPE(string,'V')   Variable
```
with this option, the result is 1 if the string can be the variable at the left of an assignment, and the assignment does not raise the syntax condition.
```
DATATYPE(string,'W')   Whole number
```
with this option, the result is 1 if the string is a rexx whole number with the precision now.
```
DATATYPE(string,'X')   heXadecimal
```
with this option, the result is 1 if the string has only hexadecimal digits, in upper or in lower, and blanks.
the blanks can be only between two parts of two hexadecimal digits each.
with this option, an empty string gives 1.
```
DATATYPE(string,'9')   9 digits
```
with this option, the result is 1 if the option for a whole number gives 1 when the precision is 9.
with an option, an empty string gives 0, but not with the option for binary or the option for hexadecimal.
the tests use what each character is, not the bytes of it.
the code:
```rexx
say DATATYPE(" 12 ")
```
the result:
```
NUM
```
the reference says:
```
NUM
```

the code:
```rexx
say DATATYPE("")
```
the result:
```
CHAR
```
the reference says:
```
CHAR
```

the code:
```rexx
say DATATYPE("123*")
```
the result:
```
CHAR
```
the reference says:
```
CHAR
```

the code:
```rexx
say DATATYPE("12.3","N")
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
say DATATYPE("12.3","W")
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
say DATATYPE("Fred","M")
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
say DATATYPE("Fred","U")
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
say DATATYPE("Fred","L")
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
say DATATYPE("?20K","s")
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
say DATATYPE("BCd3","X")
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
say DATATYPE("BC d3","X")
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
say DATATYPE("1","O")
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
say DATATYPE("11","O")
```
the result:
```
0
```
the reference says:
```
0
```

```
DATE([option1 [,string [,option2 [,osep [,isep]]]]])
```
date: a builtin function that gives the day, the month, and the year of a day; also, the day, the month, and the year of a day
this function gives a date in the way that the first argument says.
the first argument is an option.
the function uses only the first character of the option, and ignores the characters after it.
with no arguments, the function gives the date of this day: the day, the first three letters of the english name of the month, and the year.
the day in this result has no zero and no blank at the left.
the second argument is optional; it is a date to give in the way that the first argument says.
the third argument is the option that says the way of the second argument.
the third argument must be an option with a day, a month, and a year in it.
the fourth argument is the character to put between the parts of the result.
the fourth argument can be any character that is not a letter or a digit, or it can be an empty string.
you can give the fourth argument only with some options.
the fifth argument is the character between the parts of the second argument.
you must give the fifth argument when the second argument has a character between its parts that is not the default character of the third argument.
the second argument can be any date in the way of the third argument, with the character of the fifth argument between its parts.
if the second argument has only the last two digits of the year, and the result has all the digits of the year, the function takes a year from the 50 years before this year to the 49 years after this year.
the first call to date or to time in a clause gives the time that each call to date and to time in that clause uses.
```
DATE('B')   Base
DATE('B')//7   /* 0 = Monday ... 6 = Sunday */
```
with this option, the result is the count of whole days from the first day of the year 1 to this day, with that first day but not with this day.
the result has no zero digits at the left.
the remainder when you divide this result by 7 is a number from 0 to 6 that says the day of the week, as the code before this line says.
```
DATE('D')   Days
```
with this option, the result is the number of this day in the year, with this day.
the result has no zero digits at the left.
this option can not be the third argument.
```
DATE('E')   European   dd/mm/yy
```
with this option, the result is two digits of the day, two digits of the month, and the last two digits of the year.
the default character between the parts is a slash.
you can give the fourth argument with this option.
```
DATE('F')   Full
```
with this option, the result is the count of microseconds from the start of the first day of the year 1.
the result has no zero digits at the left.
this result has more digits than the default precision, so for maths with it, make the precision 18 or more.
with this option and a second argument, the time in that day is 00:00:00.000000.
to have a time in it, add a value from the builtin function time.
you can use these values to get the time between two days.
```
DATE('I')   ISO   yyyy-mm-dd
```
with this option, the result is the four digits of the year, two digits of the month, and two digits of the day, with zero digits at the left as it needs.
the default character between the parts is a dash.
you can give the fourth argument with this option.
```
DATE('L')   Language   dd month yyyy
```
with this option, the result is the day, the name of the month in the language of the system, and the year.
if the system has no way for this, the result is in the default way.
a program must not use a rule about the way or the words of this result.
this option can not be the third argument.
```
DATE('M')   Month
```
with this option, the result is the whole english name of the month.
this option can not be the third argument.
```
DATE('N')   Normal   dd mon yyyy
```
with this option, the result is the day, the first three letters of the english name of the month, and the year.
this is the default option of the first argument and of the third argument.
so you must give the third argument when the second argument is not in this way.
the default character between the parts is a blank.
you can give the fourth argument with this option.
```
DATE('O')   Ordered   yy/mm/dd
```
with this option, the result is the last two digits of the year, two digits of the month, and two digits of the day.
you can put these results in order, and the order is the order of the days.
the default character between the parts is a slash.
you can give the fourth argument with this option.
```
DATE('S')   Standard   yyyymmdd
```
with this option, the result is the four digits of the year, two digits of the month, and two digits of the day.
you can put these results in order, and the order is the order of the days.
the default is no character between the parts.
you can give the fourth argument with this option.
```
DATE('T')   Ticks
```
with this option, the result is the count of seconds from the start of the first day of the year 1970.
the result has no zero digits at the left.
the result is negative for a day before the year 1970.
for maths with this result, make the precision 12 or more.
with this option and a second argument, the time in that day is 00:00:00.000000.
to have a time in it, add a value from the builtin function time.
you can use these values to get the time between two days.
```
DATE('U')   Usa   mm/dd/yy
```
with this option, the result is two digits of the month, two digits of the day, and the last two digits of the year.
the default character between the parts is a slash.
you can give the fourth argument with this option.
```
DATE('W')   Weekday
```
with this option, the result is the english name of the day of the week, with letters in upper and in lower.
this option can not be the third argument.
the code:
```rexx
/* this day is 24 Nov 2016 */
DATE()
```
the result:
```
```
the reference says:
```
24 Nov 2016
```

the code:
```rexx
say DATE("B")
```
the result:
```
739916
```
the reference says:
```
736291
```

the code:
```rexx
say DATE("D")
```
the result:
```
301
```
the reference says:
```
329
```

the code:
```rexx
say DATE("E")
```
the result:
```
28/10/26
```
the reference says:
```
24/11/16
```

the code:
```rexx
say DATE("F")
```
the result:
```
63928806811479041
```
the reference says:
```
63615600688459000
```

the code:
```rexx
say DATE("I")
```
the result:
```
2026-10-28
```
the reference says:
```
2016-11-24
```

the code:
```rexx
DATE("L")
```
the result:
```
```
the reference says:
```
24 November 2016
```

the code:
```rexx
say DATE("M")
```
the result:
```
October
```
the reference says:
```
November
```

the code:
```rexx
DATE("N")
```
the result:
```
```
the reference says:
```
24 Nov 2016
```

the code:
```rexx
say DATE("O")
```
the result:
```
26/10/28
```
the reference says:
```
16/11/24
```

the code:
```rexx
say DATE("S")
```
the result:
```
20261028
```
the reference says:
```
20161124
```

the code:
```rexx
say DATE("T")
```
the result:
```
1793210011
```
the reference says:
```
1480003888
```

the code:
```rexx
say DATE("U")
```
the result:
```
10/28/26
```
the reference says:
```
11/24/16
```

the code:
```rexx
say DATE("W")
```
the result:
```
Wednesday
```
the reference says:
```
Thursday
```

the code:
```rexx
say DATE("O", "13 Feb 1923")
```
the result:
```
23/02/13
```
the reference says:
```
23/02/13
```

the code:
```rexx
say DATE("O", "06/01/50", "U")
```
the result:
```
50/06/01
```
the reference says:
```
50/06/01
```

the code:
```rexx
say DATE("N", "63630372300000000", "f")
```
the result:
```
14 May 2017
```
the reference says:
```
14 May 2017
```

the code:
```rexx
say DATE("S", "13 Feb 2017", "N", "-")
```
the result:
```
2017-02-13
```
the reference says:
```
2017-02-13
```

the code:
```rexx
say DATE("N", "13 Feb 2017", "N", "")
```
the result:
```
13Feb2017
```
the reference says:
```
13Feb2017
```

the code:
```rexx
say DATE("N", "13 Feb 2017", "N", "-")
```
the result:
```
13-Feb-2017
```
the reference says:
```
13-Feb-2017
```

the code:
```rexx
say DATE("O", "06/01/50", "U","")
```
the result:
```
500601
```
the reference says:
```
500601
```

the code:
```rexx
say DATE("E", "02/13/17", "U",".")
```
the result:
```
13.02.17
```
the reference says:
```
13.02.17
```

the code:
```rexx
DATE("N", , ,"_")
```
the result:
```
```
the reference says:
```
"14_May_2017"  (today)
```

the code:
```rexx
say DATE("S", "2017-11-13", "S", "", "-")
```
the result:
```
20171113
```
the reference says:
```
20171113
```

the code:
```rexx
say DATE("S", "13-Nov-2017", "N", "", "-")
```
the result:
```
20171113
```
the reference says:
```
20171113
```

the code:
```rexx
say DATE("O", "06*01*50","U", "", "*")
```
the result:
```
500601
```
the reference says:
```
500601
```

the code:
```rexx
say DATE("U", "13.Feb.2017", "N", , ".")
```
the result:
```
02/13/17
```
the reference says:
```
02/13/17
```

```
DELSTR(string [,n [,length]])
```
delstr: a builtin function that takes away a part of a string
this function gives the string after it takes away a part of it.
the part starts at the character at the position in the second argument, and the length argument is the count of characters in the part.
the second argument must be a positive whole number.
if you omit the second argument, the default is 1.
the length argument must be a positive whole number or zero.
if you omit the length argument, or the part goes after the end of the string, the function takes away all the characters from that position to the end.
if the second argument is more than the length of the string, the result is the string with no change.
the code:
```rexx
say DELSTR("abcd",3)
```
the result:
```
ab
```
the reference says:
```
ab
```

the code:
```rexx
say DELSTR("abcde",3,2)
```
the result:
```
abe
```
the reference says:
```
abe
```

the code:
```rexx
say DELSTR("abcde",6)
```
the result:
```
abcde
```
the reference says:
```
abcde
```

```
DELWORD(string, n [,length])
```
delword: a builtin function that takes away words from a string
this function gives the string after it takes away a part of it.
the part starts at the word with the number in the second argument, and the length argument is the count of words in the part.
the words in the string are the parts between blanks.
the second argument must be a positive whole number.
the length argument is optional.
the length argument must be a positive whole number or zero.
if you omit the length argument, or it is more than the count of words from that word to the end, the function takes away all the words from that word to the end.
if the second argument is more than the count of words in the string, the result is the string with no change.
the part that the function takes away has the blanks after its last word, but not the blanks before its first word.
the code:
```rexx
say DELWORD("Now is the  time",2,2)
```
the result:
```
Now time
```
the reference says:
```
Now time
```

the code:
```rexx
say DELWORD("Now is the time ",3)
```
the result:
```
Now is 
```
the reference says:
```
Now is 
```

the code:
```rexx
say DELWORD("Now is the  time",5)
```
the result:
```
Now is the  time
```
the reference says:
```
Now is the  time
```

the code:
```rexx
say DELWORD("Now is   the time",3,1)
```
the result:
```
Now is   time
```
the reference says:
```
Now is   time
```

the code:
```rexx
say DELWORD("Now is the  time",2,2)
```
the result:
```
Now time
```
the reference says:
```
Now time
```

```
DIGITS()
```
this function has no arguments.
this function gives the value of numeric digits now: the precision now.
the default is 9.
the code:
```rexx
say DIGITS()  /* by default */
```
the result:
```
9
```
the reference says:
```
9
```

```
DIRECTORY([newdirectory])
```
this function gives the name of the directory that the program uses now, and it can change that directory.
the argument is optional; it is the name of a new directory.
if you omit the argument, the result is the name of the directory now, and the function makes no change.
with the argument, the function changes to the new directory only if that directory is there.
if the change is done, the result is the name of the new directory.
if there is an error, the result is an empty string.
on windows, the first two characters of the result are the drive letter and a colon.
if the argument has a drive letter, that drive is the drive the program uses now.
if the argument has no drive letter, the drive does not change.

```
ENDLOCAL()
```
setlocal: a builtin function that stores the directory and the environment variables that a program uses now
endlocal: a builtin function that gets back the directory and the environment variables that setlocal stores
this function is only on linux.
this function has no arguments.
this function makes the directory and the environment variables the same as before the last call to setlocal.
if a procedure does not call this function, the language gets back the values that setlocal stores when the procedure ends.
the result is 1 if the function gets back the values.
the result is 0 if there is no call to setlocal before, or if the function can not do it.
on windows, this function can not do it, and the result is always 0.

```
ERRORTEXT(n)
```
errortext: a builtin function that gives the text of a rexx error
this function gives the text of the rexx error with the number in the argument.
the argument must be a number from 0 to 99.
if no rexx error has that number, the result is an empty string.
the code:
```rexx
say ERRORTEXT(16)
```
the result:
```
Label not found.
```
the reference says:
```
Label not found.
```

the code:
```rexx
say ERRORTEXT(60)
```
the result:
```

```
the reference says:
```

```

```
FILESPEC(option, filespec)
```
extension: the part of a file name after its last point
filespec: a builtin function that gives one part of a file name
this function gives one part of the file name in the second argument.
the first argument is an option that says which part.
the function uses only the first character of the option, and ignores the characters after it.
if the file name does not have that part, the result is an empty string.
```
FILESPEC('D',filespec)   Drive
```
with this option, the result is the drive on windows.
with this option, the result is an empty string on a system like unix.
```
FILESPEC('P',filespec)   Path
```
with this option, the result is the directory part of the file name.
```
FILESPEC('L',filespec)   Location
```
with this option, the result on windows is the drive and the directory part.
on other systems, the result is the same as with the option for the directory part.
```
FILESPEC('N',filespec)   Name
```
with this option, the result is the name of the file.
```
FILESPEC('E',filespec)   Extension
```
with this option, the result is the extension of the file name.
the code:
```rexx
thisfile = "C:\WINDOWS\UTIL\SYSTEM.INI"
say FILESPEC("drive",thisfile)
```
the result:
```

```
the reference says:
```
C:
```

the code:
```rexx
say FILESPEC("path",thisfile)
```
the result:
```

```
the reference says:
```
\WINDOWS\UTIL\
```

the code:
```rexx
say FILESPEC("location",thisfile)
```
the result:
```

```
the reference says:
```
C:\WINDOWS\UTIL\
```

the code:
```rexx
say FILESPEC("name",thisfile)
```
the result:
```
THISFILE
```
the reference says:
```
SYSTEM.INI
```

the code:
```rexx
say FILESPEC("extension",thisfile)
```
the result:
```

```
the reference says:
```
INI
```

the code:
```rexx
part = "name"
say FILESPEC(part,thisfile)
```
the result:
```
THISFILE
```
the reference says:
```
SYSTEM.INI
```

```
FORM()
```
form: a builtin function; also the way rexx puts a number with an exponent in a string
this function has no arguments.
this function gives the value of numeric form now.
the code:
```rexx
say FORM()  /* by default */
```
the result:
```
SCIENTIFIC
```
the reference says:
```
SCIENTIFIC
```

```
FORMAT(number [,[before] [,[after] [,[expp] [,expt]]]])
```
format: a builtin function that gives a number in the way you say
this function gives the number argument, rounded and in the way that the other arguments say.
the function makes the number rounded by the rules of rexx, as when you add 0 to it.
with only the number argument, the result is the same as the sum of the number and 0.
with other arguments, the function changes the way the number is.
the before argument is the count of characters of the part before the point, with the sign of a negative number.
if you omit the before argument, the function uses as many characters as it needs.
if the before argument is less than the part before the point needs, it is an error.
if the before argument is more than it needs, the function puts blanks at the left.
the after argument is the count of digits of the part after the point.
if you omit the after argument, the function uses as many digits as it needs.
if the after argument is not the count of digits that the number has after the point, the function makes the number rounded or puts the digit 0 at the right.
an after argument of 0 gives the number rounded to a whole number.
the fourth argument is the count of digits of the exponent.
if you omit the fourth argument, the function uses as many digits as it needs; that can be zero.
if the fourth argument is less than the exponent needs, it is an error.
if the fourth argument is 0, the result never has an exponent.
if the exponent is 0 and the fourth argument is not 0, the function puts blanks in place of the exponent; the count of blanks is the fourth argument and two more.
if the exponent is 0 and you omit the fourth argument, the result has no exponent.
the fifth argument says when the result has an exponent.
the default of the fifth argument is the precision now.
the result has an exponent when the part before the point needs more digits than the fifth argument, or the part after the point needs more digits than two times the fifth argument.
if the fifth argument is 0, the result always has an exponent, but not when the exponent is 0.
if the fourth argument is 0, the result has no exponent, also when the fifth argument is 0.
by default, the way of the exponent is from numeric digits and numeric form now.
the code:
```rexx
say FORMAT("3",4)
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
say FORMAT("1.73",4,0)
```
the result:
```
   2
```
the reference says:
```
   2
```

the code:
```rexx
say FORMAT("1.73",4,3)
```
the result:
```
   1.730
```
the reference says:
```
   1.730
```

the code:
```rexx
say FORMAT("-.76",4,1)
```
the result:
```
  -0.8
```
the reference says:
```
  -0.8
```

the code:
```rexx
say FORMAT("3.03",4)
```
the result:
```
   3.03
```
the reference says:
```
   3.03
```

the code:
```rexx
say FORMAT(" - 12.73", ,4)
```
the result:
```
-12.7300
```
the reference says:
```
-12.7300
```

the code:
```rexx
say FORMAT(" - 12.73")
```
the result:
```
-12.73
```
the reference says:
```
-12.73
```

the code:
```rexx
say FORMAT("0.000")
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
say FORMAT("12345.73", , ,2,2)
```
the result:
```
1.234573E+04
```
the reference says:
```
1.234573E+04
```

the code:
```rexx
say FORMAT("12345.73", ,3, ,0)
```
the result:
```
1.235E+4
```
the reference says:
```
1.235E+4
```

the code:
```rexx
say FORMAT("1.234573", ,3, ,0)
```
the result:
```
1.235
```
the reference says:
```
1.235
```

the code:
```rexx
say FORMAT("12345.73", , ,3,6)
```
the result:
```
12345.73
```
the reference says:
```
12345.73
```

the code:
```rexx
say FORMAT("1234567e5", ,3,0)
```
the result:
```
123456700000.000
```
the reference says:
```
123456700000.000
```

```
FUZZ()
```
fuzz: a builtin function; also the count of digits at the right of a number that a compare of numbers ignores
this function has no arguments.
this function gives the value of numeric fuzz now.
the default is 0.
the code:
```rexx
say FUZZ()  /* by default */
```
the result:
```
0
```
the reference says:
```
0
```

```
GC([force])
```
garbage: objects in memory that no part of a program can use now
collector: the part of the language that gets back the memory of garbage
gc: a builtin function that can call the garbage collector
this function can call the garbage collector.
the result is true if the function calls the garbage collector, else false.
the argument is optional.
a call to the garbage collector can change the way all the programs on a running system run.
so do not use this function if you do not have to; the language calls the garbage collector when it needs to.
if the language is made for debug, this function always calls the garbage collector.
if the language is not made for debug, this function calls the garbage collector only when you give the argument.

```
INSERT(new, target [,[n] [,[length] [,pad]]])
```
insert: a builtin function that puts a string in an other string
this function puts the first argument in the second argument, after the character at the position in the third argument, and gives the result.
the default of the third argument is 0: the first argument goes before the start of the second argument.
the length argument is the length that the first argument has in the result.
the default length is the length of the first argument.
the default pad character is a blank.
the third argument and the length argument must be positive whole numbers or zero.
if the third argument is more than the length of the second argument, the function puts pad characters before the first argument.
if the length argument is less than the length of the first argument, the function makes the first argument short, so it has that length.
before the function puts the first argument in, it makes it have the length argument as its length, with pad characters, or it makes it short.
the code:
```rexx
say INSERT(" ","abcdef",3)
```
the result:
```
abc def
```
the reference says:
```
abc def
```

the code:
```rexx
say INSERT("123","abc",5,6)
```
the result:
```
abc  123   
```
the reference says:
```
abc  123   
```

the code:
```rexx
say INSERT("123","abc",5,6,"+")
```
the result:
```
abc++123+++
```
the reference says:
```
abc++123+++
```

the code:
```rexx
say INSERT("123","abc")
```
the result:
```
123abc
```
the reference says:
```
123abc
```

the code:
```rexx
say INSERT("123","abc", ,5,"-")
```
the result:
```
123--abc
```
the reference says:
```
123--abc
```

```
LASTPOS(needle, haystack [,[start] [,length]])
```
lastpos: a builtin function that gives the position of the last place where a string is in an other string
this function gives the position of the last place where the first argument is in the second argument.
the result is 0 if the first argument is an empty string, or if it is not in the second argument.
by default, the function starts at the last character of the second argument, and goes back to the start of it.
the start argument is the position where the function starts to go back.
the start argument must be a positive whole number.
if you omit the start argument, or it is more than the length of the second argument, the start is the length of the second argument.
the length argument is the count of characters that the function reads.
the length argument must be a positive whole number or zero.
the default length is the value of the start argument.
pos: a builtin function that gives the position of one string in an other string
the builtin function pos is like this function.
the code:
```rexx
say LASTPOS(" ","abc def ghi")
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
say LASTPOS(" ","abcdefghi")
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
say LASTPOS("xy","efgxyz")
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
say LASTPOS(" ","abc def ghi",7)
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
say LASTPOS(" ","abc def ghi",7,3)
```
the result:
```
0
```
the reference says:
```
0
```
