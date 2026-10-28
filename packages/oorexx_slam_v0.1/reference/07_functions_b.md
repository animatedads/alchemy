# builtin functions second part

this file is from the rules of the oorexx language about builtin functions: the second part of the list of functions.

notready: the name of an event; a function that reads or writes a stream can raise it when there is an error
persistent: a stream is persistent when you can read its data again after the program ends, as a file on a disk
transient: a stream is transient when it is not persistent, as the input that a program gets from you
numeric: an instruction that says how a program does maths and how it writes numbers

```
LEFT(string, length [,pad])
```
this function gives the left part of the string argument.
the result has the first characters of the string.
the length of the result is the length argument.
the length argument must be a positive whole number or zero.
the pad argument is optional.
the default pad character is a blank.
if the string is short, the function puts pad characters at the right of the result.
if the length of the string is more than the length argument, the function takes away characters at the right.
the code:
```rexx
say LEFT("abc d",8)
```
the result:
```
abc d   
```
the reference says:
```
abc d   
```

the code:
```rexx
say LEFT("abc d",8,".")
```
the result:
```
abc d...
```
the reference says:
```
abc d...
```

the code:
```rexx
say LEFT("abc  def",7)
```
the result:
```
abc  de
```
the reference says:
```
abc  de
```

```
LENGTH(string)
```
this function gives the length of the string argument.
the code:
```rexx
say LENGTH("abcdefgh")
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
say LENGTH("abc defg")
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
say LENGTH("")
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
LINEIN([name] [,[line] [,count]])
```
linein: a builtin function that reads lines from a stream
this function reads lines from a stream and gives them as the result.
the name argument is the name of the stream.
if you omit the name argument, this function reads from the default input stream.
the line argument is optional.
the line argument puts the read position at the start of that line.
the line argument must be positive, and it must be a line in the stream.
you cannot use the line argument with a transient stream.
a line argument of 1 puts the read position at the start of the stream.
the count argument must be 1 or 0.
the default count is 1.
with a count of 0, this function reads no characters and gives a null string.
each persistent stream keeps its read position.
by default, this function starts to read at the read position.
when a function that reads characters read the first part of a line before, this function can give only the rest of that line.
after the read, the read position is at the start of the next line.
with a transient stream, if a whole line is not there yet, the program waits until the line is whole.
if an error makes the line never whole, the notready event is raised, and this function gives the characters that are there.
with no arguments, this function reads one line from the default input stream.
if the name argument is the word queue with a colon after it, this function reads a line from the queue.
the code:
```rexx
myfile = "ANYFILE.TXT"
say LINEIN(myfile)
```
the result:
```

```
the reference says:
```
Current line
```

the code:
```rexx
say LINEIN(myfile,1,1)
```
the result:
```

```
the reference says:
```
first line
```

the code:
```rexx
say LINEIN(myfile,1,0)
```
the result:
```

```
the reference says:
```

```

the code:
```rexx
say LINEIN(myfile, ,0)
```
the result:
```

```
the reference says:
```

```

the code:
```rexx
say LINEIN("QUEUE:")
```
the result:
```
not run: it did not end in ten seconds
```
the reference says:
```
Queue line
```

```
LINEOUT([name] [,[string] [,line]])
```
lineout: a builtin function that writes a line to a stream
this function writes the string argument to a stream as a line.
this function puts the characters that end a line on that computer after the string.
this function gives 0 when the write is done, and 1 when there is an error.
the name argument is the name of the stream.
if you omit the name argument, this function writes to the default output stream.
the line argument puts the write position at the start of that line, before the write.
the line argument must be positive, and it must be a line in the stream, if the stream is not binary.
a line argument of 1 is the first line.
the line argument can say the position next after the end of the stream.
for a stream that is not binary, you cannot put the write position after the end of the stream.
if you omit the string argument and the line argument, this function ends the use of the stream and gives 0.
if you omit the string argument with a persistent stream and you give the line argument, this function puts the write position at the start of that line, writes no characters, and gives 0.
each persistent stream keeps its write position.
by default, this function starts to write at the write position.
after a write, the write position is at the start of the next line.
when the use of a stream starts, the write position is at the end of the stream, so this function adds lines at the end.
a function that writes characters can write the first part of a line, and this function can write the rest of that line.
this function always ends its line at the end of each call.
the program waits until the write is done.
if this function cannot write a line, the notready event is raised, and this function gives 1.
if you call this function with the call instruction, the result is in the variable whose name is result.
to write to the default output with no chance of an error, use the say instruction.
the code:
```rexx
LINEOUT(,"Display this")          /* Writes string to the default   */
                                  /* output stream (usually, the    */
                                  /* display); returns 0 if         */
                                  /* successful                     */
myfile = "ANYFILE.TXT"
LINEOUT(myfile,"A new line")      /* Opens the file ANYFILE.TXT and */
                                  /* appends the string to the end. */
                                  /* If the file is already open,   */
                                  /* the string is written at the   */
                                  /* current write position.        */
                                  /* Returns 0 if successful.       */
LINEOUT(myfile,"A new start",1)   /* Opens the file (if not already */
                                  /* open); overwrites first line   */
                                  /* with a new line.               */
                                  /* Returns 0 if successful.       */
LINEOUT(myfile, ,1)               /* Opens the file (if not already */
                                  /* open). No write; sets write    */
                                  /* position at first character.   */
LINEOUT(myfile)                   /* Closes ANYFILE.TXT             */
Call LINEOUT "A:rexx.bat","Shell",1
Call LINEOUT ,"Hello"
```
the result:
```
Display this
Hello
```

```
LINES([name] [,option])
```
this function says if there is data to read in a stream.
the name argument is the name of the stream.
if you omit the name argument, this function uses the default input stream.
there are two options: the count option, and an other option that is the default.
with the default option, this function gives 1 if there is data between the read position and the end of the stream.
with the default option, this function gives 0 if there is no data there.
with the count option, this function gives the count of lines after the read position.
with the count option, this function gets that count also when it takes more time to do so.
```
Normal
Count
```
the first option in the code before this line is the default option.
the second option in the code before this line is the count option.
the code:
```rexx
say LINES(myfile)  /* at end of the file   */
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
say LINES()  /* data remains in the  */
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
                         /* default input stream */
                         /* STDIN:               */
```
the result:
```
```

```
LOWER(string [,n [,length]])
```
this function gives a new string with the letters of the string argument in lower.
this function does not change the string argument.
the second argument is the position where the change starts.
the second argument must be a positive whole number.
if you omit the second argument, the change starts at the first character.
the length argument is the count of characters to change.
the length argument must be a positive whole number or zero.
if you omit the length argument, the change goes to the end of the string.
characters outside that part do not change.
the code:
```rexx
say lower("Albert Einstein")
```
the result:
```
albert einstein
```
the reference says:
```
albert einstein
```

the code:
```rexx
say lower("ABCDEF", 4)
```
the result:
```
ABCdef
```
the reference says:
```
ABCdef
```

the code:
```rexx
say lower("ABCDEF", 3, 2)
```
the result:
```
ABcdEF
```
the reference says:
```
ABcdEF
```

```
MAX(number [,number]...)
```
max: a builtin function that gives the maximum of a list of numbers
this function gives the maximum of the numbers you give as arguments.
you can give any count of numbers.
the result is in the way that the numeric instruction says now.
the code:
```rexx
say MAX(12,6,7,9)
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
say MAX(17.3,19,17.03)
```
the result:
```
19
```
the reference says:
```
19
```

the code:
```rexx
say MAX(-7,-3,-4.3)
```
the result:
```
-3
```
the reference says:
```
-3
```

the code:
```rexx
say MAX(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)
```
the result:
```
21
```
the reference says:
```
21
```

```
MIN(number [,number]...)
```
min: a builtin function that gives the minimum of a list of numbers
this function gives the minimum of the numbers you give as arguments.
you can give any count of numbers.
the result is in the way that the numeric instruction says now.
the code:
```rexx
say MIN(12,6,7,9)
```
the result:
```
6
```
the reference says:
```
6
```

the code:
```rexx
say MIN(17.3,19,17.03)
```
the result:
```
17.03
```
the reference says:
```
17.03
```

the code:
```rexx
say MIN(-7,-3,-4.3)
```
the result:
```
-7
```
the reference says:
```
-7
```

the code:
```rexx
say MIN(21,20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1)
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
OVERLAY(new, target [,n [,length [,pad]]])
```
overlay: a builtin function that puts one string in place of a part of an other string
the first argument is the new string.
the second argument is the string to change.
this function gives the second argument, with the first argument in place of its characters from the position that the third argument says.
the third argument must be a positive whole number.
the default of the third argument is 1.
the length argument must be a positive whole number or zero.
the default length is the length of the first argument.
the function adds pad characters at the end of the first argument, or takes away characters at its end, so that its length is the length argument.
the new part can go after the end of the second argument.
if the third argument is more than the length of the second argument, the function puts pad characters before the first argument.
the last argument is the pad character.
the default pad character is a blank.
the code:
```rexx
say OVERLAY(" ","abcdef",3)
```
the result:
```
ab def
```
the reference says:
```
ab def
```

the code:
```rexx
say OVERLAY(".","abcdef",3,2)
```
the result:
```
ab. ef
```
the reference says:
```
ab. ef
```

the code:
```rexx
say OVERLAY("qq","abcd")
```
the result:
```
qqcd
```
the reference says:
```
qqcd
```

the code:
```rexx
say OVERLAY("qq","abcd",4)
```
the result:
```
abcqq
```
the reference says:
```
abcqq
```

the code:
```rexx
say OVERLAY("123","abc",5,6,"+")
```
the result:
```
abc+123+++
```
the reference says:
```
abc+123+++
```

```
POS(needle, haystack [,start [,length]])
```
pos: a builtin function that gives the position of one string in an other string
the first argument is the string to find.
the second argument is the string to test.
this function gives the position of the first argument in the second argument.
the start argument is the position in the second argument where the function starts.
the start argument must be a positive whole number.
the default start is 1, the first character.
the length argument is the count of characters, from the start position, that the function tests.
the length argument must be a positive whole number or zero.
if you omit the length argument, the function tests to the end of the string.
this function gives 0 if the first argument is a null string.
this function gives 0 if it does not find the first argument.
this function gives 0 if the start argument is more than the length of the second argument.
the code:
```rexx
say POS("day","Saturday")
```
the result:
```
6
```
the reference says:
```
6
```

the code:
```rexx
say POS("x","abc def ghi")
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
say POS(" ","abc def ghi")
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
say POS(" ","abc def ghi",5)
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
say POS(" ","abc def ghi",5,3)
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
QUALIFY(name)
```
qualify: a builtin function that gives the whole name of a file, with its directory names
this function gives the whole name of the file that the name argument says, with the absolute name of each directory before it.
the file does not have to be there: the function makes the whole name also when there is no file with that name.

```
QUEUED()
```
queued: a builtin function that counts the lines in the queue
this function gives the count of lines in the external data queue at the time of the call.
the code:
```rexx
say QUEUED()  /* Perhaps */
```
the result:
```
0
```
the reference says:
```
5
```

```
RANDOM(max)
RANDOM([min] [,[max] [,seed]])
```
seed: a number that a function for random numbers uses to start; with the same seed it gives the same numbers in the same order
this function gives a random whole number from the minimum to the maximum.
the minimum and the maximum can also be the result.
the numbers come from a rule of maths; they are not random, but they are like random numbers.
the first argument is the minimum.
the default minimum is 0.
the second argument is the maximum.
the default maximum is 999.
if you give only one argument, it is the maximum, and the minimum is 0.
the maximum subtract the minimum must not be more than 999999999.
the third argument is the seed.
the seed must be a whole number from 0 to 999999999.
you can omit the first and the second argument and give only the seed, with two comma marks before it.
with no seed, the first call makes a seed, and two runs of the program can give numbers that are not the same.
to get the same numbers again, give a seed only on the first call, and omit it on the next calls.
the same seed gives the same numbers in the same order each time the program runs.
with an other seed, the numbers are not the same, but it is not always so.
the rule that makes the random numbers is global to the whole program.
the seed is not local to an internal routine.
the code:
```rexx
say RANDOM()  /* 0 to 999     */
```
the result:
```
186
```
the reference says:
```
305
```

the code:
```rexx
say RANDOM(5, 8)  /* 5 to 8       */
```
the result:
```
8
```
the reference says:
```
7
```

the code:
```rexx
say RANDOM(2)  /* 0 to 2       */
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
say RANDOM(, , 3257)  /* reproducible */
```
the result:
```
123
```
the reference says:
```
123
```

the code:
```rexx
say RANDOM(-5, 5)
```
the result:
```
4
```
the reference says:
```
-3
```

the code:
```rexx
sequence = RANDOM(1,6,12345)  /* any number would */
                              /* do for a seed    */
do 39
  sequence = sequence RANDOM(1,6)
end
say sequence
```
the result:
```
2 5 6 2 2 3 4 6 1 1 2 4 3 1 3 1 5 1 5 3 4 3 1 6 6 6 3 1 4 3 5 1 5 4 4 6 3 1 1 2
```

```
REVERSE(string)
```
reverse: a builtin function that gives the characters of a string in the other order
this function gives the string argument with its characters in the other order.
the last character is first in the result, and the first character is last.
the code:
```rexx
say REVERSE("ABc.")
```
the result:
```
.cBA
```
the reference says:
```
.cBA
```

the code:
```rexx
say REVERSE("XYZ ")
```
the result:
```
 ZYX
```
the reference says:
```
 ZYX
```

```
RIGHT(string, length [,pad])
```
this function gives the right part of the string argument.
the result has the last characters of the string.
the length of the result is the length argument.
the length argument must be a positive whole number or zero.
the pad argument is optional.
the default pad character is a blank.
if the string is short, the function puts pad characters at the left of the result.
if the length of the string is more than the length argument, the function takes away characters at the left.
the code:
```rexx
say RIGHT("abc  d",8)
```
the result:
```
  abc  d
```
the reference says:
```
  abc  d
```

the code:
```rexx
say RIGHT("abc def",5)
```
the result:
```
c def
```
the reference says:
```
c def
```

the code:
```rexx
say RIGHT("12",5,"0")
```
the result:
```
00012
```
the reference says:
```
00012
```

```
RXFUNCADD(name, module [,procedure])
```
rxfuncadd: a builtin function that adds an external function to the list of functions that rexx code can call
this function adds the name of an external function to the list of functions that rexx code can call.
the name argument is the name of the function to add.
the second argument is the name of the external file of code that has the function.
the name of that file may not be caseless.
the third argument is the name of the routine in that file.
if you omit the third argument, its default is the name argument.
this function first tests the name of the routine as you give it.
if that name is not in the file, this function tests the name again with all its letters in upper.
this function gives 0 when it can find the function in the file and add it.
this function gives 1 when it cannot find the function.
the code:
```rexx
-- 0 if rxcalcsqrt can be located, else 1
rxfuncadd("rxcalcsqrt", "rxmath", "rxcalcsqrt")
```
the result:
```
```

```
RXFUNCDROP(name)
```
rxfuncdrop: a builtin function that takes a name away from the list of functions that rexx code can call
this function takes the name of a function away from the list of functions that rexx code can call.
this function gives 0 when it takes the name away.
the code:
```rexx
say rxfuncdrop("SysLoadFuncs")  /* if successfully removed   */
```
the result:
```
1
```
the reference says:
```
0
```

```
RXFUNCQUERY(name)
```
rxfuncquery: a builtin function that tests if a name is in the list of functions that rexx code can call
this function tests if the function name you give is in the list of functions that rexx code can call.
this function gives 0 if the name is in the list.
this function gives 1 if the name is not in the list.
the code:
```rexx
say rxfuncquery("SysLoadFuncs")  /* if registered             */
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
RXQUEUE(function [,queuename])
```
queues: more than one queue
rxqueue: a builtin function that makes external data queues and takes them away, and can set and give the name of a queue
this function makes external data queues and takes them away.
this function can set the queue to use, and it can give the name of a queue.
the first argument is an option that says what to do.
this function uses only the first character of the first argument.
the compare of the first argument is caseless.
the second argument is the name of a queue.
the rules for a queue name are the rules for a rexx symbol.
with the option to make, the option to take away, and the option to set, the rules for the second argument are the rules for the name of a variable.
the length of a queue name must not be more than 250 characters.
a queue and a variable with the same name are not the same thing.
the name of a queue is the name you give, with its letters in upper.
two programs can use a queue with a name to give data to each other.
a call to linein with the stream name queue and a colon is of use: the caller waits until an other program puts a line in the queue.
the name of the default queue is in the code after this line.
```
SESSION
```
```
Create
```
the option in the code before this line makes a queue with the name you give, if no queue has that name.
with that option, if you give no name, rexx makes a name for the queue.
with that option, this function gives the name of the new queue.
with that option, many queues can be there at the same time.
with that option, if a queue with that name is there, this function makes a new queue with a name that rexx makes, and gives that name.
with that option, you cannot use the name of the default queue.
```
Delete
```
the option in the code before this line takes away the queue with the name you give.
with that option, this function gives 0 when it takes the queue away, or an error number.
with that option, this function gives 5 when the queue name is not a name you can use, or when you try to take away the default queue.
with that option, this function gives 9 when there is no queue with that name.
with that option, this function gives 10 when a program waits for that queue.
with that option, this function gives 12 or 1002 when there is an error of memory.
```
0     Queue deleted.
5     Invalid queue name, or an attempt to delete SESSION.
9     Queue does not exist.
10    Queue is busy; a wait is active.
12    Memory failure.
1002  Memory manager failure.
```
```
Get
```
the option in the code before this line gives the name of the queue in use now.
```
Exist
```
the option in the code before this line gives true if there is a queue with the name you give, and false if not.
```
Open
```
the option in the code before this line tests if there is a queue with the name you give, and makes it if there is not.
```
Set
```
the option in the code before this line makes the queue with the name you give the queue in use now.
with that option, this function gives the name of the queue in use before.
the code:
```rexx
/* default queue                                    */
say rxqueue("Get")
```
the result:
```
SESSION
```
the reference says:
```
SESSION
```

the code:
```rexx
/* assuming FRED does not already exist             */
say rxqueue("Create", "Fred")
```
the result:
```
Fred
```
the reference says:
```
FRED
```

the code:
```rexx
/* assuming SESSION had been active                 */
say rxqueue("Set", "Fred")
```
the result:
```
SESSION
```
the reference says:
```
SESSION
```

the code:
```rexx
/* assuming FRED exists                             */
say rxqueue("delete", "Fred")
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
SETLOCAL()
```
setlocal: a builtin function that stores the directory and the environment variables that a program uses now
endlocal: a builtin function that gets back the directory and the environment variables that setlocal stores
this function stores the directory that the program uses now.
this function stores the values of the environment variables that are local to the program now.
you can use this function to store the environment before you change it with the value function.
the endlocal function gets back the directory and the environment that this function stores.
if you call this function in a procedure and do not call endlocal, the directory and the environment come back when the procedure ends.
this function gives 1 when it stores them, and 0 when it cannot.
this function is only for the first kind of computer in the code after this line.
on the second kind of computer in the code after this line, this function always gives 0.
```
Linux
Windows
```
the code:
```rexx
/* Current path is "user/bin" */
n = SETLOCAL()           /* saves all environment settings */
/* Now use the VALUE function to change the PATH variable */
p = VALUE("Path","home/user/bin","ENVIRONMENT")
/* Programs in directory home/user/bin can now be run */
n = ENDLOCAL()           /* restores initial environment including */
                         /* the changed PATH variable, which is    */
                         /* "user/bin"                             */
```
the result:
```
```

```
SIGN(number)
```
this function gives a number that says the sign of the number argument.
this function gives -1 if the number is less than 0.
this function gives 0 if the number is equal to 0.
this function gives 1 if the number is more than 0.
this function uses the number rounded by the rules of rexx, as if the code adds 0 to it.
the code:
```rexx
say SIGN("12.3")
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
say SIGN(" -0.307")
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
say SIGN(0.0)
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
SOURCELINE([n])
```
sourceline: a builtin function that gives a line of the program, or the count of its lines
if you omit the argument, this function gives the line number of the last line of the program.
if you give the argument, this function gives the line of the program at that line number, if that line is there when the program runs.
if that line is not there, this function gives a null string.
the argument must be a positive whole number.
the argument must not be more than the result of this function with no argument.
if the program file is not rexx code but a file that rexx made from the code, this function with no argument gives 0.
if the program file is not rexx code but a file that rexx made from the code, any try to get a line of the program is an error.
the code:
```rexx
say SOURCELINE()
```
the result:
```
1
```
the reference says:
```
10
```

the code:
```rexx
say SOURCELINE(1)
```
the result:
```
say SOURCELINE(1)
```
the reference says:
```
/* This is a 10-line Rexx program */
```

```
SPACE(string [,n [,pad]])
```
space: a builtin function that puts a set count of pad characters between the words of a string
this function gives the words of the string argument with pad characters between each two words.
the second argument is the count of pad characters between two words.
the second argument must be a positive whole number or zero.
the default of the second argument is 1.
the pad argument is optional.
the default pad character is a blank.
if the second argument is 0, the function takes away all blanks.
the function always takes away the blanks at the start and at the end of the string.
the code:
```rexx
say SPACE("abc  def  ")
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
say SPACE("  abc def",3)
```
the result:
```
abc   def
```
the reference says:
```
abc   def
```

the code:
```rexx
say SPACE("abc  def  ",1)
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
say SPACE("abc  def  ",0)
```
the result:
```
abcdef
```
the reference says:
```
abcdef
```

the code:
```rexx
say SPACE("abc  def  ",2,"+")
```
the result:
```
abc++def
```
the reference says:
```
abc++def
```

```
STREAM(name [,operation [,stream_command]])
```
state: what is true about a thing at one time
operation: a thing to do
handle: a value that the computer uses as a name for an open stream
this function gives the state of a stream, or a string about its state, or it runs a command on the stream.
the name argument is the name of the stream.
the second argument is the operation.
this function uses only the first letter of the second argument, and ignores the characters after it.
the third argument is a command for the stream.
you use the third argument only with the command operation.
```
Command
```
with the operation in the code before this line, this function runs the command in the third argument on the stream.
with that operation, this function gives the result of the command, and that can be a null string.
```
Description
```
with the operation in the code before this line, this function gives the same string as with the state operation, and after it a colon.
with that operation, when there is more to know about an error or about the notready state, this function also gives more facts about it after the colon.
```
State
```
with the operation in the code before this line, this function gives a string that says the state of the stream.
the state operation is the default operation.
the strings that the state operation can give are in the rules of the state method of the stream class.
the state of a stream is global to a rexx program.
the program does not store the state of a stream before a call to an internal function or subroutine, and does not get it back after the call, also when a trap makes the call.
you use stream commands to make a stream open to read, to write, or both.
you use stream commands to end the use of a stream.
you use stream commands to set the read position or the write position in a persistent stream.
you use stream commands to get facts about a stream: if it is there, how many bytes it has, and the time of its last change.
if there is an error in a command, this function gives an error string, as the operation that gives more facts about the state does.
the command can be any expression whose value is a command string.
```
OPEN
```
the command in the code before this line makes the stream open.
by default, the stream is open to read and to write.
the options of that command are in the code after this line, one at a time.
```
READ
```
with the option in the code before this line, the stream is open to read only.
```
WRITE
```
with the option in the code before this line, the stream is open to write only.
```
BOTH
```
with the option in the code before this line, the stream is open to read and to write.
that option is the default.
with that option, the stream keeps a read position and an other write position.
```
APPEND
```
the option in the code before this line puts the write position at the end of the stream.
that option is the default.
with that option, you cannot put the write position in the data that the file has at the time you make it open.
```
REPLACE
```
the option in the code before this line puts the write position at the start of the stream.
with that option, the command takes away all the data that the stream has at the time you make it open.
```
BINARY
```
with the option in the code before this line, line end characters are not special: they are data.
if a stream is not there and you make it open to write with that option, you must also give the option in the code after this line.
if you do not give that next option there, an error is raised.
```
RECLENGTH length
```
the option in the code before this line gives each line in the stream the same length.
the length must be 1 or more.
with that option, the line functions use each line of that length in a binary stream as one line.
without that option, the line functions use the whole binary file as one line.
```
CLOSE
READY:
```
the command in the first line of the code before this line ends the use of the stream.
it gives the string in the second line of that code when there is no error, and an error string when there is an error.
if the stream is not open, this function gives a null string.
```
FLUSH
```
the command in the code before this line makes the stream write now all the data that waits in memory to go to the stream.
```
SEEK
POSITION
```
the two commands in the code before this line are the same.
these commands set the read position or the write position in a persistent stream.
if the stream is open to read and to write and you give no option, these commands set both positions.
the stream must be open before you use these commands: by the open command, or by a read or a write.
these commands give the new position when there is no error, or an error string when there is an error.
these commands can have a mark before the number of the position.
```
=
<
+
-
```
the first mark in the code before this line says that the position is from the start of the stream.
that mark is the default.
with that mark, a line position of 1 is the start of the stream.
the second mark in the code before this line says that the position is from the end of the stream.
the third mark in the code before this line says that the position is that count after the read or write position now.
the last mark in the code before this line says that the position is that count before the read or write position now.
```
READ
WRITE
CHAR
LINE
```
with the first option in the code before this line, the command can set the read position.
with the second option in the code before this line, the command can set the write position.
with the third option in the code before this line, the position is a count of characters.
the third option is the default.
with the last option in the code before this line, the position is a count of lines.
for a stream that is not binary, a position in lines can take more time: rexx may have to read the file.
for a binary stream with a length for each line, rexx gets the position in lines with a multiply, then a position in characters.
if the file is open only to write, a position in lines is an error.
```
QUERY
```
the command in the code before this line gives facts about a stream.
this command can also get facts when the stream is not open, but not the handle and the position.
if the stream is not there, the command for the kind of stream gives the string in the code after this line, and the other commands of this kind give a null string.
```
UNKNOWN
```
a directory is persistent, but it is not a stream.
for a directory, the commands for the time give the time of the directory.
for a directory, the command for the count of bytes gives 0.
for a directory, the command for the kind of stream gives the string in the code before the line that says a directory is persistent.
for a directory, the other commands of this kind give a null string.
```
QUERY DATETIME
```
the command in the code before this line gives the time of the stream; the code at the end of this part has a result of it.
```
QUERY EXISTS
```
the command in the code before this line gives the whole name of the stream, with its directory, if the stream is there.
that command gives a null string if the stream is not there.
```
QUERY HANDLE
```
the command in the code before this line gives the handle of the open stream.
that command cannot get the handle of a stream that is not open.
```
QUERY POSITION
```
the command in the code before this line gives the read position or the write position now.
```
READ
WRITE
CHAR
LINE
SYS
```
the first option in the code before this line gives the read position.
the second option in the code before this line gives the write position.
if you give no option of the first two, and the stream is open to read and to write, the command gives the read position.
if you give no option of the first two, and the stream is open only to read or only to write, the command gives the position for that use.
the third option gives the position as a count of characters, and it is the default.
the next option gives the position as a count of lines.
for a stream that is not binary, a position in lines can take more time: rexx may have to count the line end characters from the start of the stream.
the last option gives the position in characters that the computer has for the stream.
```
QUERY SIZE
```
the command in the code before this line gives the count of bytes in a persistent stream.
```
QUERY STREAMTYPE
PERSISTENT
TRANSIENT
UNKNOWN
```
the command in the first line of the code before this line gives one of the three strings in the next lines of that code.
```
QUERY TIMESTAMP
```
the command in the code before this line gives the time of the stream in an other way; the code at the end of this part has a result of it.
the code:
```rexx
stream(strout,"c","open")
stream(strout,"c","open write")
stream(strinp,"c","open read")
stream(strinp,"c","open read shared")
stream("STRM.TXT","c","close")
stream(name,"c","seek =2 read")
stream(name,"c","seek +15 read")
stream(name,"c","seek -7 write line")
fromend  = 125
stream(name,"c","seek <"fromend read)
stream("..\file.txt","c","query datetime")
```
the result:
```
```
the reference says:
```
11-12-98 03:29:12
```

the code:
```rexx
say stream("..\file.txt","c","query exists")
```
the result:
```

```
the reference says:
```
c:\data\file.txt
```

the code:
```rexx
say stream("..\file.txt","c","query handle")
```
the result:
```

```
the reference says:
```
3
```

the code:
```rexx
say stream("myfile","c","query position write")
```
the result:
```

```
the reference says:
```
247
```

the code:
```rexx
say stream("..\file.txt","c","query size")
```
the result:
```

```
the reference says:
```
1305
```

the code:
```rexx
stream("..\file.txt","c","query timestamp")
```
the result:
```
```
the reference says:
```
2016-11-12 03:29:12
```

```
STRIP(string [,option [,chars]])
```
strip: a builtin function that takes away characters at the start or at the end of a string
tab: a character like a blank
this function takes away characters at the start of the string argument, at its end, or at both, and gives the result.
the option argument says where to take away characters.
this function uses only the first letter of the option, and ignores the characters after it.
```
Both
Leading
Trailing
```
the first option in the code before this line takes away characters at the start and at the end of the string.
the first option is the default.
the second option in the code before this line takes away characters at the start only.
the third option in the code before this line takes away characters at the end only.
the third argument is the set of characters to take away.
if you omit the third argument, this function takes away blanks and tab characters.
if the third argument is a null string, this function takes away no characters.
this function takes away each character that is in the third argument, at the start or at the end that the option says.
the code:
```rexx
say STRIP("  ab c  ")
```
the result:
```
ab c
```
the reference says:
```
ab c
```

the code:
```rexx
say STRIP("  ab c  ","L")
```
the result:
```
ab c  
```
the reference says:
```
ab c  
```

the code:
```rexx
say STRIP("  ab c  ","t")
```
the result:
```
  ab c
```
the reference says:
```
  ab c
```

the code:
```rexx
say STRIP("12.7000", ,0)
```
the result:
```
12.7
```
the reference says:
```
12.7
```

the code:
```rexx
say STRIP("0012.700", ,0)
```
the result:
```
12.7
```
the reference says:
```
12.7
```

the code:
```rexx
say STRIP("12.0000", "T", '.0')
```
the result:
```
12
```
the reference says:
```
12
```

```
SUBSTR(string, n [,length [,pad]])
```
substr: a builtin function that gives a part of a string
this function gives a part of the string argument.
the second argument is the position where the part starts.
the second argument must be a positive whole number.
the length argument is the length of the result.
if you omit the length argument, the result is the rest of the string.
if the string is too short, the function puts pad characters at the end of the result.
the default pad character is a blank.
if the second argument is more than the length of the string, the result has only pad characters.
the code:
```rexx
say SUBSTR("abc",2)
```
the result:
```
bc
```
the reference says:
```
bc
```

the code:
```rexx
say SUBSTR("abc",2,4)
```
the result:
```
bc  
```
the reference says:
```
bc  
```

the code:
```rexx
say SUBSTR("abc",2,6,".")
```
the result:
```
bc....
```
the reference says:
```
bc....
```

```
SUBWORD(string, n [,length])
```
subword: a builtin function that gives some words of a string
this function gives the part of the string argument that starts at a word.
the second argument is the position of the first word of the result, as a count of words.
the second argument must be a positive whole number.
the length argument is the count of words in the result.
if you omit the length argument, the result has all the words from that word to the end of the string.
the result has no blanks at the start or at the end.
the blanks between the words of the result do not change.
the code:
```rexx
say SUBWORD("Now is the  time",2,2)
```
the result:
```
is the
```
the reference says:
```
is the
```

the code:
```rexx
say SUBWORD("Now is the  time",3)
```
the result:
```
the  time
```
the reference says:
```
the  time
```

the code:
```rexx
say SUBWORD("Now is the  time",5)
```
the result:
```

```
the reference says:
```

```

```
SYMBOL(name)
```
this function tests the symbol whose name is the name argument, and gives a string that says what kind of symbol it is.
give the name as a literal string or from an expression, so that rexx does not put the value of a variable in its place before this function gets it.
this function changes the letters of the name to upper, as rexx does with symbols in expressions.
if the name is a compound symbol, this function puts the values of the variables of its tail in it, if it can.
```
BAD
VAR
LIT
```
this function gives the first string in the code before this line if the name cannot be a rexx symbol.
this function gives the second string in the code before this line if the name is a variable: a symbol with a value.
this function gives the third string in the code before this line if the name is a constant symbol, an environment symbol, or a symbol with no value yet.
the code:
```rexx
/* following: Drop A.3;  J=3 */
say SYMBOL("J")
```
the result:
```
LIT
```
the reference says:
```
VAR
```

the code:
```rexx
say SYMBOL(J)  /* has tested "3"        */
```
the result:
```
LIT
```
the reference says:
```
LIT
```

the code:
```rexx
say SYMBOL("a.j")  /* has tested A.3        */
```
the result:
```
LIT
```
the reference says:
```
LIT
```

the code:
```rexx
say SYMBOL(2)  /* a constant symbol     */
```
the result:
```
LIT
```
the reference says:
```
LIT
```

the code:
```rexx
say SYMBOL(".TRUE")  /* an environment symbol */
```
the result:
```
LIT
```
the reference says:
```
LIT
```

the code:
```rexx
say SYMBOL("*")  /* not a valid symbol    */
```
the result:
```
BAD
```
the reference says:
```
BAD
```

```
TIME([option [,string [,option2]]])
```
sixty: six times ten
seconds: a count of time; one of them is a short time
minute: the time of sixty seconds
minutes: more than one minute
hour: the time of sixty minutes
hours: more than one hour
day: the time of ten and ten and four hours
midnight: the time at the start of a day
microseconds: a count of time; one of them is one of the seconds divide by ten to the power six
clock: a part of a computer that counts time
utc: a global time; it is the same at each place, but a local time is not
this function gives the local time now.
with no option, the result is the local time as hours, minutes, and seconds, as in the code after this line.
```
hh:mm:ss
```
with no option, the clock has ten and ten and four hours.
this function uses only the first letter of the option, and ignores the characters after it.
each option is in code, and the facts about it are after that code.
```
Civil      hh:mmam  hh:mmpm
```
with the option in the code before this line, the result is hours and minutes, then two letters, as in that code.
with that option, the hours go from 1 to 12, with no zero at the start.
with that option, the minutes are the minutes now, and this function does not round them.
```
12:00am to 11:59am    morning
12:00pm to 11:59pm    noon and afternoon
```
the first line of the code before this line is the first part of the day, and the second line is the rest of the day.
```
Elapsed    sssssssss.uuuuuu
```
the option in the code before this line gives the seconds and microseconds from the start of the clock, or from the last time the clock goes back to zero.
with that option, the result has no zero digits and no blanks at the start.
the precision of the numeric instruction does not change the result of that option.
```
Full
00:00:00.000000 on 1 January 0001
```
the option in the first line of the code before this line gives the microseconds from the time in the second line of that code.
with that option, the result has no zero digits and no blanks at the start.
for maths with the result of that option, the precision must be 18 or more.
```
Hours      hh
```
the option in the code before this line gives the hours from midnight, with no more than two characters.
with that option, the result has no zero digits and no blanks at the start, but a result of zero is 0.
```
Long       hh:mm:ss.uuuuuu
```
the option in the code before this line gives hours, minutes, seconds, and microseconds, as in that code.
```
Minutes    mmmm
```
the option in the code before this line gives the minutes from midnight, with no more than four characters.
with that option, the result has no zero digits and no blanks at the start, but a result of zero is 0.
```
Normal     hh:mm:ss
```
the option in the code before this line is the default option.
with that option, each part of the result has two digits.
with that option, this function takes away the fractional part of the seconds, and does not round it.
```
Offset
TIME("F") - TIME("O")      /* local time to UTC */
/* negative: west of the Prime Meridian; positive: east */
```
the option in the first line of the code before this line gives the difference between the local time and utc, in microseconds.
the code in the second line of that code gives the utc time from the local time.
the comment in the last line of that code says when the result is negative and when it is positive.
```
Reset
```
the option in the code before this line gives the same value as the option that counts from the start of the clock, and then it puts the clock back to zero.
```
Seconds    sssss
```
the option in the code before this line gives the seconds from midnight, with no more than five characters.
with that option, the result has no zero digits and no blanks at the start, but a result of zero is 0.
```
Ticks
00:00:00.000000 on 1 January 1970
```
the option in the first line of the code before this line gives the seconds from the time in the second line of that code.
with that option, the result has no zero digits and no blanks at the start.
with that option, the result is negative for a time before the time in that code.
for maths with the result of that option, the precision must be 12 or more.
if you give the string argument, this function gives the time that the string says, in the way of the first option.
the string must be in the way of the third argument.
the default of the third argument is the default option.
so you need the third argument only when the string is not in the way of the default option.
the third argument must say a time of day: you cannot use there the option that counts from the start of the clock, or the option that puts the clock back to zero.
the result is the first time that has the parts in the string.
if the result needs a part that the string does not have, that part is zero.
if the string has a part that the result does not need, this function ignores it.
```
TIME("F", string, option2)
TIME("T", string, option2)
```
with the calls in the code before this line, the day of the time is the day in the code after this line.
```
1 January 0001
```
the first call that uses the clock starts the clock and gives 0.
after that, the option that counts from the start of the clock gives the time from the start of the clock.
after that, the option that puts the clock back to zero gives the time from its last call, and then puts the clock back to zero.
an internal routine gets the clock of its caller.
when an internal routine puts the clock back to zero, the clock of the caller does not change.
if a clause has more than one call of this function, each call gives the same time.
if the time of the computer goes back to before the start of the clock, an error is raised, and the clock stops.
a trap of the code after this line can start the clock again.
```
SIGNAL ON SYNTAX
```
a change to the clock of the computer can make the results of the clock not true.
if the seconds of the clock have more than nine digits, there is an error.
the code:
```rexx
say TIME()
```
the result:
```
17:44:03
```
the reference says:
```
16:54:22
```

the code:
```rexx
say TIME("C")
```
the result:
```
5:44pm
```
the reference says:
```
4:54pm
```

the code:
```rexx
say TIME("H")
```
the result:
```
17
```
the reference says:
```
16
```

the code:
```rexx
say TIME("L")  /* Perhaps */
```
the result:
```
17:44:03.416623
```
the reference says:
```
16:54:22.120000
```

the code:
```rexx
say TIME("M")  /* 54 + 60*16 */
```
the result:
```
1064
```
the reference says:
```
1014
```

the code:
```rexx
say TIME("N")
```
the result:
```
17:44:03
```
the reference says:
```
16:54:22
```

the code:
```rexx
say TIME("S")  /* 22 + 60*(54+60*16) */
```
the result:
```
63843
```
the reference says:
```
60862
```

the code:
```rexx
say time("E")  /* The first call */
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
                  /* pause of one second here */
say time("E")  /* or thereabouts */
```
the result:
```
0
```
the reference says:
```
1.020000
```

the code:
```rexx
                  /* pause of one second here */
say time("R")  /* or thereabouts */
```
the result:
```
0
```
the reference says:
```
2.030000
```

the code:
```rexx
                  /* pause of one second here */
say time("R")  /* or thereabouts */
```
the result:
```
0
```
the reference says:
```
1.050000
```

the code:
```rexx
say time("C","11:27:21")
```
the result:
```
11:27am
```
the reference says:
```
11:27am
```

the code:
```rexx
say time("N","11:27am","C")
```
the result:
```
11:27:00
```
the reference says:
```
11:27:00
```

the code:
```rexx
say time("N", "63326132161828000", "F")
```
the result:
```
08:16:01
```
the reference says:
```
08:16:01
```

the code:
```rexx
If TIME("M","5:00pm","C")-TIME("M")<=0
then say "Time to go home"
else say "Keep working"
numeric digits 18  -- needed to add the timestamps
timestamp = date("f", "20170123", "S") + time("f", "08:14:22", "N")
```
the result:
```
Time to go home
```

```
TRACE([option])
```
this function gives the trace option in use now, and it can change the trace option.
this function can change the trace option also when the program is in interactive debug.
the trace instruction cannot do that.
the option argument is optional.
the option can be a question mark, one letter of the trace instruction options in the code after this line, or both.
```
?
A C E F I L N O R
```
the option cannot be a number, but the trace instruction can have a number.
the code:
```rexx
Say TRACE()  /* maybe */
```
the result:
```
N
```
the reference says:
```
?R
```

the code:
```rexx
Say TRACE("O")  /* also sets tracing off */
```
the result:
```
N
```
the reference says:
```
?R
```

the code:
```rexx
Say TRACE("?I")  /* now in interactive debugging */
```
the result:
```
N
```
the reference says:
```
O
```

```
TRANSLATE(string [,tableo] [,tablei] [,pad] [,pos] [,length])
```
translate: a builtin function that changes each character of a string to an other character, or puts the characters in an other order
this function gives the string argument, and it can change each character to an other character, or not change it.
this function can also put the characters of the string in an other order.
the second argument is the output table.
the third argument is the input table.
if a character of the string is in the input table, the function puts in its place the character at the same position in the output table.
if the input table has that character more than one time, the function uses the first of them.
if a character is not in the input table, it does not change.
the result always has the length of the string argument.
the input table and the output table can have any length.
the default input table is the code after this line.
```
XRANGE("00"x,"FF"x)
```
the default output table is a null string.
the function adds pad characters to the output table, or takes away its last characters, so that it has the length it needs.
the default pad character is a blank.
the pos argument is the position where the change starts.
the default of the pos argument is 1.
the length argument is the count of characters to change.
if you omit the length argument, the change goes to the end of the string.
with no output table, no input table, and no pad, this function changes the letters of the string to upper.
if you give the pad, but no output table and no input table, this function changes all the characters of the string to the pad character.
the code:
```rexx
say TRANSLATE("abcdef")
```
the result:
```
ABCDEF
```
the reference says:
```
ABCDEF
```

the code:
```rexx
say TRANSLATE("abcdef", , , , 2, 3)
```
the result:
```
aBCDef
```
the reference says:
```
aBCDef
```

the code:
```rexx
say TRANSLATE("abcdef", "12", "ec")
```
the result:
```
ab2d1f
```
the reference says:
```
ab2d1f
```

the code:
```rexx
say TRANSLATE("abcdef", "12", "abcd", ".")
```
the result:
```
12..ef
```
the reference says:
```
12..ef
```

the code:
```rexx
say TRANSLATE("APQRV", , "PR")
```
the result:
```
A Q V
```
the reference says:
```
A Q V
```

the code:
```rexx
say TRANSLATE("APQRV", XRANGE("00"X, "Q"))
```
the result:
```
APQ  
```
the reference says:
```
APQ  
```

the code:
```rexx
say TRANSLATE("4123", "abcd", "1234", , 2, 2)
```
the result:
```
4ab3
```
the reference says:
```
4ab3
```

the code:
```rexx
say TRANSLATE("4123", "abcd", "1234")
```
the result:
```
dabc
```
the reference says:
```
dabc
```

```
TRUNC(number [,n])
```
trunc: a builtin function that gives a number with a set count of digits after the point, and does not round it
this function gives the integer part of the number argument, and the count of digits after the point that the second argument says.
the second argument must be a positive whole number or zero.
the default of the second argument is 0, and then the result is an integer with no point.
this function uses the number rounded by the rules of rexx, as if the code adds 0 to it.
then the function takes away the digits after that count, and does not round them.
if the result has less digits after the point than the second argument, the function adds zero digits at the end.
the result never has an exponent.
if the result has no digit that is not zero, the function takes away its sign.
before all this, the number is rounded with the precision of the numeric instruction, if it has to be.
the code:
```rexx
say TRUNC(12.3)
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
say TRUNC(127.09782,3)
```
the result:
```
127.097
```
the reference says:
```
127.097
```

the code:
```rexx
say TRUNC(127.1,3)
```
the result:
```
127.100
```
the reference says:
```
127.100
```

the code:
```rexx
say TRUNC(127,2)
```
the result:
```
127.00
```
the reference says:
```
127.00
```

```
UPPER(string [,n [,length]])
```
this function gives a new string with the letters of the string argument in upper.
the second argument is the position where the change starts.
the second argument must be a positive whole number.
if you omit the second argument, the change starts at the first character.
the length argument is the count of characters to change.
the length argument must be a positive whole number or zero.
if you omit the length argument, the change goes to the end of the string.
the code:
```rexx
say upper("Albert Einstein")
```
the result:
```
ALBERT EINSTEIN
```
the reference says:
```
ALBERT EINSTEIN
```

the code:
```rexx
say upper("abcdef", 4)
```
the result:
```
abcDEF
```
the reference says:
```
abcDEF
```

the code:
```rexx
say upper("abcdef", 3, 2)
```
the result:
```
abCDef
```
the reference says:
```
abCDef
```

```
USERID()
```
user: one that uses a computer
userid: a builtin function that gives the name of the user of the program
this function gives the name of the user now.

```
VALUE(name [,newvalue [,selector]])
```
this function gives the value of the symbol that the name argument says.
you can make the name when the program runs.
for a rexx variable, the name must be a rexx symbol, and the symbol function can test that.
the second argument is optional.
if you give the second argument, this function assigns it to the variable.
the result is the value of the variable before that assignment.
the third argument is optional, and it says an external set of variables.
by default, this function uses the rexx variables of the program now.
for these variables, this function changes the letters of the name to upper.
for the global environment, this function does not change the letters, as names there can have letters in upper and in lower.
if the name is a compound symbol, this function puts in the values of the variables of its tail, if it can.
```
NOVALUE
```
if the variable is uninitialized, this function gives its default value, and the event in the code before this line is not raised.
you use this function when a variable has the name of an other variable, or when the program makes a name when it runs.
with one literal name and no other arguments, the call is a constant, and you can put the string in place of the call.
```
fred=VALUE("k");
fred=k;
```
the two lines in the code before this line do the same thing, if the program has no trap for that event.
```
ENVIRONMENT
```
with the third argument in the code before this line, this function uses the environment variables of the computer.
with that third argument, the name does not have to be a rexx symbol.
with that third argument, the names may not be caseless.
with that third argument, if there is no variable with that name, this function gives a null string.
so you cannot know if the variable is not there or has a null string.
a value you assign there must not have the character whose hexadecimal value is zero.
if it has that character, the variable gets only the part of the value before that character.
to set a variable there, give the new value as the second argument.
to drop a variable there, give the nil object as the second argument.
a null string as the second argument does not drop the variable, and the variable then has a null string.
after the program ends, the environment variables do not have the values that this function gives them.
```
""
```
with the null string in the code before this line as the third argument, this function uses the global environment directory of rexx.
with that third argument and no second argument, rexx sends a message with the name and no arguments to the environment object.
then the environment gives the object with that name.
if there is no object with that name, this function gives the name with a point at the start: it is an environment symbol.
with that third argument and a second argument, rexx sends a message whose name is the name with an equal mark at the end, and whose one argument is the second argument.
then the environment has that object for that name.
the code:
```rexx
/* After: Drop A3; A33=7; K=3; fred="K"; list.5="Hi" */
say VALUE("a"k)  /* looks up A3                */
```
the result:
```
AK
```
the reference says:
```
A3
```

the code:
```rexx
say VALUE("a"k||k)
```
the result:
```
AKK
```
the reference says:
```
7
```

the code:
```rexx
say VALUE("fred")  /* looks up FRED              */
```
the result:
```
FRED
```
the reference says:
```
K
```

the code:
```rexx
say VALUE(fred)  /* looks up K                 */
```
the result:
```
FRED
```
the reference says:
```
3
```

the code:
```rexx
say VALUE(fred,5)  /* looks up K and             */
```
the result:
```
FRED
```
the reference says:
```
3
```

the code:
```rexx
                        /* then sets K=5              */
say VALUE(fred)  /* looks up K                 */
```
the result:
```
FRED
```
the reference says:
```
5
```

the code:
```rexx
say VALUE("LIST."k)  /* looks up LIST.5            */
```
the result:
```
LIST.K
```
the reference says:
```
Hi
```

the code:
```rexx
/* Given that an external variable FRED has a value of 4         */
share = "ENVIRONMENT"
say VALUE("fred",7,share)      /* says "4" and assigns           */
                               /* FRED a new value of 7          */
say VALUE("fred", ,share)      /* says "7"                       */
/* Accessing and changing Windows environment entries            */
env = "ENVIRONMENT"
new = "C:\EDIT\DOCS;"
say value("PATH",new,env)   /* says "C:\WINDOWS" (perhaps)       */
                            /* and sets PATH = "C:\EDIT\DOCS;"   */
say value("PATH", ,env)     /* says "C:\EDIT\DOCS;"              */
Call VALUE "MYVAR", "FIRST" || "00"X || "SECOND", "ENVIRONMENT"
value("MYVAR", .NIL, "ENVIRONMENT")
value("MYVAR", "", "ENVIRONMENT")
-- assume the environment name MYNAME identifies the string "Simon"
name = value("MYNAME", , "")       -- sends MYNAME message to the environment
say "Hello," name                  -- "Hello, Simon"
-- Assume the environment name NONAME does not exist
name = value("NONAME", , "")       -- sends NONAME message to the environment
say "Hello," name                  -- "Hello, .NONAME"
call value "MYNAME", "David", ""   -- sends MYNAME=("David") message to the environment
say "Hello," value("MYNAME", , "") -- "Hello, David"
```
the result:
```

7
/home/claude/oorexx/usr/local/bin:/usr/bin:/bin
C:\EDIT\DOCS;
Hello, .MYNAME
Hello, .NONAME
Hello, David
```

```
VAR(name)
```
var: a builtin function that tests if a name is the name of a variable
this function gives 1 if the name argument is the name of a variable: a symbol with a value.
this function gives 0 if not.
the code:
```rexx
/* Following: DROP A.3; J=3  */
say VAR("J")
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
say VAR(J)  /* has tested "3"    */
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
say VAR("a.j")  /* has tested "A.3"  */
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
say VAR(2)  /* a constant symbol */
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
say VAR("*")  /* an invalid symbol */
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
VERIFY(string, reference [,option [,start [,length]]])
```
verify: a builtin function that tests if the characters of a string are in an other string
this function gives a number: 0, or the position of a character.
the second argument is the set of characters to compare with.
the third argument is an option.
this function uses only the first letter of the option, and ignores the characters after it.
the letter of the option is caseless.
```
Nomatch
Match
```
the first option in the code before this line is the default.
with the first option, this function gives 0 if each character of the string is in the second argument.
with the first option, if not, this function gives the position of the first character of the string that is not in the second argument.
with the second option in the code before this line, this function gives the position of the first character of the string that is in the second argument.
with the second option, this function gives 0 if no character of the string is in the second argument.
the start argument is the position where the test starts.
the start argument must be a positive whole number.
the default start is 1.
the length argument is the count of characters to test.
the length argument must be a positive whole number or zero.
if you omit the length argument, the test goes to the end of the string.
if the string is a null string, the result is 0, with any option.
if the start argument is more than the length of the string, the result is 0.
if the second argument is a null string, the result is 0 with the second option.
if the second argument is a null string, the result is the start argument with the first option.
the code:
```rexx
say VERIFY("123","1234567890")
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
say VERIFY("1Z3","1234567890")
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
say VERIFY("AB4T","1234567890")
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
say VERIFY("AB4T","1234567890","M")
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
say VERIFY("AB4T","1234567890","N")
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
say VERIFY("1P3Q4","1234567890", ,3)
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
say VERIFY("123","",N,2)
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
say VERIFY("ABCDE","", ,3)
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
say VERIFY("AB3CD5","1234567890","M",4)
```
the result:
```
6
```
the reference says:
```
6
```

the code:
```rexx
say VERIFY("ABCDEF","ABC","N",2,3)
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
say VERIFY("ABCDEF","ADEF","M",2,3)
```
the result:
```
4
```
the reference says:
```
4
```

```
WORD(string, n)
```
this function gives one word of the string argument.
the second argument is the position of that word, as a count of words.
the second argument must be a positive whole number.
if the string has less words than the second argument, this function gives a null string.
this function is the same as the subword function with a length argument of 1.
the code:
```rexx
say WORD("Now is the time",3)
```
the result:
```
the
```
the reference says:
```
the
```

the code:
```rexx
say WORD("Now is the time",5)
```
the result:
```

```
the reference says:
```

```

```
WORDINDEX(string, n)
```
wordindex: a builtin function that gives the position of the first character of a word in a string
this function gives the position of the first character of one word of the string argument.
the second argument is the position of that word, as a count of words.
the second argument must be a positive whole number.
if the string has less words than the second argument, this function gives 0.
the code:
```rexx
say WORDINDEX("Now is the time",3)
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
say WORDINDEX("Now is the time",6)
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
WORDLENGTH(string, n)
```
wordlength: a builtin function that gives the length of a word in a string
this function gives the length of one word of the string argument.
the second argument is the position of that word, as a count of words.
the second argument must be a positive whole number.
if the string has less words than the second argument, this function gives 0.
the code:
```rexx
say WORDLENGTH("Now is the time",2)
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
say WORDLENGTH("Now comes the time",2)
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
say WORDLENGTH("Now is the time",6)
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
WORDPOS(phrase, string [,start])
```
wordpos: a builtin function that gives the position of some words in a string, as a count of words
the first argument is the words to find.
the second argument is the string to test.
this function gives the position, as a count of words, of the first word of the first argument in the string.
this function gives 0 if the first argument has no words.
this function gives 0 if it does not find the first argument in the string.
the start argument is the word where the test starts.
the start argument must be positive.
if you omit the start argument, the test starts at the first word of the string.
more than one blank between two words, in the first argument or in the string, is the same as one blank.
else, the words must be equal.
the code:
```rexx
say WORDPOS("the","now is the time")
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
say WORDPOS("The","now is the time")
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
say WORDPOS("is the","now is the time")
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
say WORDPOS("is   the","now is the time")
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
say WORDPOS("is   time ","now is   the time")
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
say WORDPOS("be","To be or not to be")
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
say WORDPOS("be","To be or not to be",3)
```
the result:
```
6
```
the reference says:
```
6
```

```
WORDS(string)
```
this function gives the count of words in the string argument.
the code:
```rexx
say WORDS("Now is the time")
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
say WORDS(" ")
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
X2B(hexstring)
```
this function changes a string of hexadecimal characters to a string of binary digits.
the argument can have any length.
for each hexadecimal character, the result has four binary digits.
the result has no blanks.
if the argument is a null string, the result is a null string.
blanks in the argument are optional, and this function ignores them.
a blank in the argument can be only between two bytes, and not at the start or at the end.
you can use this function with the functions in the code after this line, to change numbers or strings to binary.
```
D2X
C2X
```
the code:
```rexx
say X2B("C3")
```
the result:
```
11000011
```
the reference says:
```
11000011
```

the code:
```rexx
say X2B("7")
```
the result:
```
0111
```
the reference says:
```
0111
```

the code:
```rexx
say X2B("1 C1")
```
the result:
```
000111000001
```
the reference says:
```
000111000001
```

the code:
```rexx
say X2B(C2X("C3"x))
```
the result:
```
11000011
```
the reference says:
```
11000011
```

the code:
```rexx
say X2B(D2X("129"))
```
the result:
```
10000001
```
the reference says:
```
10000001
```

the code:
```rexx
say X2B(D2X("12"))
```
the result:
```
1100
```
the reference says:
```
1100
```

```
X2C(hexstring)
```
this function changes a string of hexadecimal characters to the characters they say.
the argument can have any length.
the count of bytes in the result is the count of hexadecimal digits divide by two.
if you cannot divide the count of hexadecimal digits by two with no remainder, this function puts a zero digit at the start.
blanks in the argument are optional, and this function ignores them.
a blank in the argument can be only between two bytes, and not at the start or at the end.
if the argument is a null string, the result is a null string.
the code:
```rexx
say X2C("4865 6c6c 6f")  /*  ASCII             */
```
the result:
```
Hello
```
the reference says:
```
Hello
```

the code:
```rexx
say X2C("3732 73")  /*  ASCII             */
```
the result:
```
72s
```
the reference says:
```
72s
```

```
X2D(hexstring [,n])
```
this function gives the decimal value of a string of hexadecimal characters.
the result is a whole number, and it can be negative when you give the second argument.
if you omit the second argument, this function uses the string as a binary number with no sign.
blanks in the string are optional, and this function ignores them.
a blank in the string can be only between two bytes, and not at the start or at the end.
if the string is a null string, the result is 0.
the second argument is a count of hexadecimal digits.
with the second argument, this function uses the string as a number with a sign and with that count of digits.
with the second argument, this function puts 0 characters at the left of the string, or takes away characters at its left, so that it has that count of characters.
with the second argument, if the first bit at the left is 0, the number is positive.
with the second argument, if the first bit at the left is 1, the number is negative.
if the second argument is 0, the result is 0.
it is an error if the result cannot be a whole number.
it is an error if the result has more digits than the precision of the numeric instruction.
the code:
```rexx
say X2D("0E")
```
the result:
```
14
```
the reference says:
```
14
```

the code:
```rexx
say X2D("81")
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
say X2D("F81")
```
the result:
```
3969
```
the reference says:
```
3969
```

the code:
```rexx
say X2D("FF81")
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
say X2D("46 30"X)  /*  ASCII   */
```
the result:
```
240
```
the reference says:
```
240
```

the code:
```rexx
say X2D("66 30"X)  /*  ASCII   */
```
the result:
```
240
```
the reference says:
```
240
```

the code:
```rexx
say X2D("81",2)
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
say X2D("81",4)
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
say X2D("F081",4)
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
say X2D("F081",3)
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
say X2D("F081",2)
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
say X2D("F081",1)
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
say X2D("0031",0)
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
XRANGE([start] [,end])
XRANGE(name)
```
xrange: a builtin function that gives a string of all the bytes from one byte to an other byte
this function gives a string of all the values of one byte, in order from less to more, from the start argument to the end argument.
the start argument and the end argument are both in the result.
the start argument and the end argument are optional.
```
'00'x
'ff'x
```
the first value in the code before this line is the default start, and the second value is the default end.
if the start argument is more than the end argument, the result goes from the start to the maximum byte, then from the minimum byte to the end.
the start argument and the end argument must each be one character.
in place of a start and an end, an argument can be the name of a set of characters.
the code after this line has the name of each set, and the characters of that set.
```
ALNUM   digits, then uppercase letters, then lowercase letters
ALPHA   uppercase letters, then lowercase letters
BLANK   space and tab only
CNTRL   control characters: '00'x to '1F'x, and '7F'x
DIGIT   0 to 9
GRAPH   visible characters, not the space
LOWER   a to z
PRINT   visible characters and the space
PUNCT   punctuation characters
SPACE   '09'x '0A'x '0B'x '0C'x '0D'x '20'x
UPPER   A to Z
XDIGIT  0 to 9, A to F, a to f
```
the characters of a set are in order from less to more.
you can give any count of start and end arguments and names of a set in one call.
this function puts the results of all of them in one string, in order.
the code:
```rexx
say XRANGE("a", "f")
```
the result:
```
abcdef
```
the reference says:
```
abcdef
```

the code:
```rexx
say c2x(XRANGE('03'x, '07'x))
```
the result:
```
0304050607
```
the reference says:
```
0304050607
```

the code:
```rexx
say c2x(XRANGE(, '04'x))
```
the result:
```
0001020304
```
the reference says:
```
0001020304
```

the code:
```rexx
say c2x(XRANGE('FE'x, '02'x))
```
the result:
```
FEFF000102
```
the reference says:
```
FEFF000102
```

the code:
```rexx
say XRANGE("t", "t", "h", "i", "r", "t")
```
the result:
```
thirst
```
the reference says:
```
thirst
```

the code:
```rexx
say XRANGE('xdigit')
```
the result:
```
0123456789ABCDEFabcdef
```
the reference says:
```
0123456789ABCDEFabcdef
```

the code:
```rexx
say XRANGE("a", "f", "A", "F", "digit")
```
the result:
```
abcdefABCDEF0123456789
```
the reference says:
```
abcdefABCDEF0123456789
```
