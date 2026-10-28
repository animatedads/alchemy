# input and output

this file is from the part of the rexx language rules about input, output, streams, and the queue.

persistent: a persistent stream has a read position, as a file
transient: a transient stream has no read position; it is not a file
close: end the use of a stream; then it is not open
closes: close, for one thing
opens: open, for one thing
user: the one that uses a program
fourth: the next after the third
kinds: more than one kind
device: a thing for input or output, as a disk
pipe: a stream that one program writes and an other program reads

```
input and output
```
the way of input and output in rexx has three parts.
the first part is one or more input stream objects.
the second part is one or more output stream objects.
the third part is one or more external data queue objects.
rexx methods, instructions, and builtin functions change these parts.

```
CHARIN   LINEIN   PULL   PARSE PULL   PARSE LINEIN
```
rexx input is a stream of characters in order.
it comes from a user, or it does the same things as input from a user.
some stream objects can get characters at the end of the stream at any time; other streams do not change.
the method in the first line of the code reads a stream as characters.
the method in the second line of the code reads a stream as lines.
the third and fourth instructions read the default input stream, but only when the external data queue is empty.
the third instruction is the same as the fourth instruction with the upper option.
the last instruction reads lines from the default input stream, if the external data queue has data or not.
the third and fourth instructions are the way to read the default input you use as a rule.

```
read position
CHARS   LINES   SEEK   POSITION   COMMAND
```
for a persistent stream, the language keeps the position where it reads now.
when the stream opens, the read position is at the start of the stream.
the first function in the code gives the count of characters from the read position to the end, with the characters at the end of each line.
the second function in the code says if there is data between the read position and the end of the stream.
you can change the read position with the third or the fourth method in the code, from the stream class.
you can also change it with the same two words as an argument of the last method in the code.
you can also change it with the start argument of the method that reads characters, or the line argument of the method that reads lines.

```
transient stream
CHARS   LINES   SEEK   POSITION
```
a transient stream has no read position.
for a transient stream, the first two functions in the code give 1 if data waits, or if the computer can not know if data waits.
if not, they give 0.
the third and fourth methods in the code are not for transient streams.
the same two words as an argument of the command method are also not for transient streams.

```
SAY   CHAROUT   LINEOUT
```
these give output from a rexx program.
the say instruction writes to the default output stream object, the output object.
the second method in the code writes characters to the default output stream or to a stream you name.
the third method in the code writes lines to the default output stream or to a stream you name.
the third method and the say instruction write the characters for the end of a line at the end of each line.
the computer can change the way the output is, but the data is one line.

```
write position
CHAROUT   LINEOUT   SEEK   POSITION   COMMAND
```
the language keeps the position where it writes now in a stream.
the write position is not the same as the read position.
the write position is at the end of the stream as a rule, as when the stream opens, so the data goes at the end.
for a persistent stream, you can set the write position to the start of the stream, to write in the place of the data there.
to do this, give 1 as the start argument of the method that writes characters, or as the line argument of the method that writes lines.
you can write output at any place in the stream with one of these: the start argument of the method that writes characters, the line argument of the method that writes lines, the third or fourth method in the code, or the same two words as a command to the last method in the code.
when data is in a transient output stream, rexx can not get it back.

```
external data queue
PUSH   QUEUE   PULL   PARSE PULL   QUEUED
```
the external data queue is a list of strings.
only instructions and methods for lines can use the external data queue.
it is outside of rexx programs, so other rexx programs can use it.
programs can use it to send data from one program to an other program.
the data in the queue can be any characters; no character is special.
the queue does not change while a rexx program runs, but only by the rexx instructions on it.
it can change when the program calls an external command or routine, and that command or routine changes it.
rexx has two kinds of queue.
you use each kind by its name.

```
STDIN   STDOUT   STDERR
```
a stream name can be the name of a file, a queue, a pipe, or any device that reads or writes characters.
for a file or a device, the name can be any file name that the computer can use.
the computer has three default streams, with the names in the code.
rexx keeps these three names, so rexx functions can use them for these stream objects.
these names are caseless.
to use a file that has one of these names, put a directory before the name.

```
.INPUT   .OUTPUT
```
rexx has these two public objects.
by default they are the default input and output streams of the computer.
when a rexx call for input or output has no stream name, it uses the default stream object.
a program that uses these objects runs the same way on any computer.
the code:
```rexx
Lineout(,"Hello World")
.Output~lineout("Hello World")
```
the result:
```
Hello World
Hello World
```

```
HANDLE:x
```
this stream name gives you a file that is open when rexx starts; the number after the colon is the number the computer gives that file.
you can use it as any other stream name, also as the receiver of a stream method.
if the number is not a file the computer has open, the first input or output on the object is an error.
when you close this stream object, you can not open it again.
rexx keeps this name; to use a file or a device with this name, put a directory before the name.

```
MyStream~charin(10,0)
```
you can change the read position or the write position of a persistent stream to any place in the stream.
you can give the place in characters or in lines.
with characters, the stream is a list of bytes, and no character is special.
you can change the position only with characters.
when you change the read position, you get no data.
if the stream is open, output that the program writes before, and that the computer does not write yet, goes away.
when you change the write position, the computer first writes the output it does not write yet.
the index of a position in a rexx stream starts at one, not zero.
character position 1 and line position 1 are the same: the start of a persistent stream.
the code:
```rexx
MyStream~charin(10,0)
```
the result:
```
97.1
```
the reference says:
```
the tenth character is the next character to read; no data
```

```
MyStream~command(position 5 read line)
```
with lines, the stream is a list of lines.
if you open a binary stream with a length for each line, a new line starts after that count of characters.
then the line position is a way to give a character position.
in a stream that is not binary, the characters at the end of each line are between two lines.
these characters are a part of the stream.
you can change the line number of the read position: write more line end characters before it, or write other characters in the place of line end characters.
at some times you must read the stream first, as when you change from character methods to line methods, or when you start from the end of the stream.
if you write the stream again at a place before the read position, the line number of the read position can be false.
the code:
```rexx
MyStream~command(position 5 read line)
MyStream~command(position 321 read char)    /* same as the line before, in a binary stream with 80 characters for each line */
```
the result:
```
97.1
```

```
OPEN   CLOSE   COMMAND
CHARIN   CHAROUT   CHARS   LINEIN   LINEOUT   LINES
SAY   PULL   PARSE PULL
PARSE LINEIN
```
when a program opens a persistent stream, as a file, the computer does it, as a rule.
the first message to a stream from the list in the second line of the code opens it.
a stream that one of the methods to read or write opens is open to read and to write, if the computer can do it.
the open method or the command method can open a stream only to read or only to write.
the stream class has the open, close, and command methods, to open or close a stream when you want.
a stream is open until you close it, or until the program ends.
you can close it with the method that writes characters or the method that writes lines.
if you give the method that writes lines only the name of the stream, with no string and no line, it closes the stream.
a rexx program gives lines to the user and gets lines from the user, as a rule, with the instructions in the third line of the code.
the external data queue can give the input that the user writes, so an other program can give the input in place of the user.
use the instruction in the fourth line of the code only when you do not want to use the external data queue.
for input and output that is not in lines, use the methods that read and write characters.
these methods are of use for transient streams.

```
NOTREADY
STATE   DESCRIPTION
ERROR   NOTREADY   UNKNOWN
SAY .OUTPUT   PULL .INPUT
```
rexx uses this event for an error in input and output; call on or signal on can trap it.
the two methods in the second line of the code give more data about the error.
when there is an error in input or output, the function or method goes on as a rule.
an output method gives back a count that is not zero.
a program can raise this event for some kinds of input and output.
this event is like the error and failure events of commands.
it does not end the program, also when it is not trapped.
if it is not trapped, the program goes on, and the trap is off.
if signal on traps it, the clause that runs now stops, and the signal goes on as a signal does.
if call on traps it, the clause that runs now goes on to its end, and the trap is delayed.
then input methods on the same stream can give a null string, and output methods can give a count.
at the end of the clause, the call runs.
if the trap is delayed, the program goes on, and the trap is delayed as before.
while the trap is delayed, the condition function with the object option gives the stream object that is in use at the error.
the state method of the stream class gives one of the strings in the third line of the code.
the description method of the stream class gives more data about the state of the stream.
the two instructions in the fourth line of the code never raise this event, but the state and description methods can give this event name for them.

```
charIn charOut chars close command description flush lineIn lineOut lines makeArray open position qualify query seek state
PARSE LINEIN   PARSE PULL   PULL   PUSH   QUEUE   SAY
QUEUED()
```
the first line of the code is the list of the methods of the stream class.
the second line is the list of the rexx instructions for input and output.
the third line is the builtin function for input and output.
