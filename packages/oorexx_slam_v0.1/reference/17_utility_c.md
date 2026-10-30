# more classes of oorexx

this file is from the parts of the oorexx reference about the stream classes, some collection classes, and some classes for other uses.

## words i add

context: the code that runs now, with its settings and its variables
frame: one routine, method, or other part of code that runs now; it may wait for the end of a call it made
frames: more than one frame
threads: more than one thread
entries: more than one entry
session: the name of the default external data queue
interpreter: the program that reads rexx code and runs it
native: native code is not rexx code; the computer runs it with no interpreter
executable: a routine object or a method object that runs
type: the kind of a thing
architecture: the count of bits that the interpreter uses for an address in memory
release: the second part of the version of the interpreter
modification: the third part of the version of the interpreter
revision: a number that says from which state of the source code the interpreter was made
create: make a new thing
created: a thing is created when you create it
fifo: the order where the first item in is the first item out
lifo: the order where the last item in is the first item out
unique: there is only one of it
resize: change the size of a thing
full: a queue is full when it has as many items as its size
property: a name and its value in a properties object

## the rexxcontext class

```
.RexxContext
```
an object of this class gives facts about the context of the rexx code that runs now.
you get an object of this class only from the environment symbol point context, or from the context method of a stack frame.
you can not make an object of this class with the new method.
this class is a subclass of the object class.

```
.RexxContext~args
```
this method gives an array of the arguments of the context.
this method is the same as the arg builtin function with the arguments 1 and the letter a in a string.

```
.RexxContext~condition
```
this method gives the condition object of the context.
if the context has no trapped condition now, this method gives nil.
this method is the same as the condition builtin function with the option that gives the condition object.

```
.RexxContext~digits
```
this method gives the numeric digits setting of the context.
this method is the same as the digits builtin function.

```
.RexxContext~executable
```
this method gives the executable of the context: a routine object or a method object.
it is a routine object or a method object as the type of the context is.

```
.RexxContext~form
```
this method gives the numeric form setting of the context.
this method is the same as the form builtin function.

```
.RexxContext~fuzz
```
this method gives the numeric fuzz setting of the context.
this method is the same as the fuzz builtin function.

```
.RexxContext~interpreter
```
this method gives the id of the interpreter of the context, as a number.

```
.RexxContext~invocation
```
this method gives the id of the invocation of the context, as a number.
this method can give nil, as for native code.

```
.RexxContext~line
```
this method gives the line of the context that runs now.
this method is the same as the environment symbol point line.

```
.RexxContext~name
```
this method gives the name that the caller used to run the context.
if the context is a method, the name is the name of the message that runs the method.
if the context is a routine that you call as an external routine, the name is the name in the call.
if the context is an internal routine, the name is the name of the label that the call used.
if the context is the main part of the program, the name is the name of the package.

```
.RexxContext~package
```
this method gives the package object of the executable of the context.

```
.RexxContext~rs
```
this method gives the value of the environment symbol point rs for the context.
if the context sent no commands, this method gives nil.

```
.RexxContext~stackFrames
```
this method gives an array of stack frame objects for the stack of calls now.
the first item is the frame of the context that runs now.
the next items are the frames before it in the stack, in order.

```
.RexxContext~thread
```
this method gives the id of the thread of the context, as a number.

```
.RexxContext~variables
```
this method gives a directory with all the variables of the context.
each index of the directory is the name of a variable, and each item is the value of that variable.
the directory has only simple variables and stem variables, not compound variables.
you can get the value of a compound variable from the stem object that the directory has for its stem name.
the sysdumpvariables function of rexxutil also shows the variables.

## the rexxinfo class

```
.RexxInfo
```
this class gives facts about the language and about the platform, in one place.
you get the one object of this class from the environment symbol point rexxinfo.
you can not make or copy an other object of this class.
its methods give values that you can read but not change.
some of the values are not the same on each platform, and some are not the same for each version of the interpreter.

```
.RexxInfo~architecture
```
this method gives the architecture of the interpreter, as a count of bits.
the code:
```rexx
say .RexxInfo~architecture
```
the result:
```
64
```

```
.RexxInfo~caseSensitiveFiles
```
this method gives true if the names of files are not caseless, else false.
on a unix platform, this method gives the value for the root directory of the files.
the file class has a method that gives the same value.
the code:
```rexx
/* platform: windows */
say .RexxInfo~caseSensitiveFiles
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
0
```

the code:
```rexx
/* platform: unix */
say .RexxInfo~caseSensitiveFiles
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
.RexxInfo~date
```
this method gives the date of the release of the interpreter as a string.
the string is in the default form of the date builtin function.
the name method and the parse version instruction also give this date, as the third to fifth tokens of their result.
the code:
```rexx
say .RexxInfo~date
```
the result:
```
3 Aug 2026
```

```
.RexxInfo~debug
```
this method gives true if the interpreter is a version for debug, else false.
the code:
```rexx
say .RexxInfo~debug
```
the result:
```
1
```

```
.RexxInfo~digits
```
this method gives the default value of the numeric digits setting of the language.
the code:
```rexx
say .RexxInfo~digits
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
.RexxInfo~directorySeparator
```
this method gives the character between the names of directories in a path.
on the windows platform, this method gives a backslash.
on a unix platform, this method gives a slash.
the code:
```rexx
/* platform: windows */
say .RexxInfo~directorySeparator
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
\
```

the code:
```rexx
/* platform: unix */
say .RexxInfo~directorySeparator
```
the result:
```
/
```
the reference says:
```
/
```

```
.RexxInfo~endofline
```
this method gives the characters that end a line on this platform.
on the windows platform, this method gives two characters: the character with the decimal value 13, then the character with the decimal value 10.
on a unix platform, this method gives one character: the character with the decimal value 10.
the environment symbol point endofline gives the same value.
the code:
```rexx
/* platform: windows */
say c2x(.RexxInfo~endofline)
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
0D0A
```

the code:
```rexx
/* platform: unix */
say c2x(.RexxInfo~endofline)
```
the result:
```
0A
```
the reference says:
```
0A
```

```
.RexxInfo~executable
```
this method gives a new file object with the whole path of the interpreter that runs now.
the code:
```rexx
say .RexxInfo~executable
```
the result:
```
/home/claude/oorexx/usr/local/bin/rexx
```

```
.RexxInfo~form
```
this method gives the default value of the numeric form setting of the language.
the code:
```rexx
say .RexxInfo~form
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
.RexxInfo~fuzz
```
this method gives the default value of the numeric fuzz setting of the language.
the code:
```rexx
say .RexxInfo~fuzz
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
.RexxInfo~internalDigits
```
this method gives the numeric digits setting that the builtin functions use in their maths.
the value is 9 when the architecture is 32 bits, and 18 when the architecture is 64 bits.
the code:
```rexx
say .RexxInfo~internalDigits
```
the result:
```
18
```

```
.RexxInfo~internalMaxNumber
```
this method gives the maximum value of a whole number that the language uses in its maths.
a value of this kind is an argument of a builtin function, the number at the right of the power operator, or a value for the for or by keywords of a loop.
the code:
```rexx
say .RexxInfo~internalMaxNumber
```
the result:
```
999999999999999999
```

```
.RexxInfo~internalMinNumber
```
this method gives the minimum value of a whole number that the language uses in its maths.
a value of this kind is an argument of a builtin function, the number at the right of the power operator, or a value for the for or by keywords of a loop.
the code:
```rexx
say .RexxInfo~internalMinNumber
```
the result:
```
-999999999999999999
```

```
.RexxInfo~languageLevel
```
this method gives the level of the language as a decimal number.
the name method and the parse version instruction also give this level, as the second token of their result.
the code:
```rexx
say .RexxInfo~languageLevel
```
the result:
```
6.06
```

```
.RexxInfo~libraryPath
```
this method gives a new file object with the path of the libraries of the interpreter that runs now.
the code:
```rexx
say .RexxInfo~libraryPath
```
the result:
```
/home/claude/oorexx/usr/local/lib
```

```
.RexxInfo~majorVersion
```
this method gives the first part of the version of the interpreter, as a number.
the code:
```rexx
say .RexxInfo~majorVersion
```
the result:
```
5
```

```
.RexxInfo~maxArraySize
```
this method gives the maximum size of an array or a queue.
the code:
```rexx
say .RexxInfo~maxArraySize
```
the result:
```
100000000000000000
```

```
.RexxInfo~maxExponent
```
this method gives the maximum exponent of a number in scientific form.
the code:
```rexx
say .RexxInfo~maxExponent
```
the result:
```
999999999
```
the reference says:
```
999999999
```

```
.RexxInfo~maxPathLength
```
this method gives the maximum length of a whole path of a file, with the name of the file.
the code:
```rexx
/* platform: windows */
say .RexxInfo~maxPathLength
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
259
```

the code:
```rexx
/* platform: linux */
say .RexxInfo~maxPathLength
```
the result:
```
4096
```
the reference says:
```
4096
```

```
.RexxInfo~minExponent
```
this method gives the minimum exponent of a number in scientific form.
the code:
```rexx
say .RexxInfo~minExponent
```
the result:
```
-999999999
```
the reference says:
```
-999999999
```

```
.RexxInfo~modification
```
this method gives the modification of the interpreter, as a number: the third part of the version.
the code:
```rexx
say .RexxInfo~modification
```
the result:
```
0
```

```
.RexxInfo~name
```
this method gives the name of the interpreter, as the parse version instruction gives it.
the name has three parts: a string that says the interpreter, its version, and its architecture; the language level; and the date when the interpreter was made.
the code:
```rexx
say .RexxInfo~name
```
the result:
```
REXX-ooRexx_5.3.0(MT)_64-bit 6.06 3 Aug 2026
```

```
.RexxInfo~package
```
this method gives a package object with all the classes that rexx has in the namespace rexx.
the code:
```rexx
say .RexxInfo~package~publicClasses~items -
 "Rexx-defined public classes"
```
the result:
```
62 Rexx-defined public classes
```

```
.RexxInfo~pathSeparator
```
this method gives the character between two paths in a list of paths where the system searches for files.
on the windows platform, this method gives a semicolon.
on a unix platform, this method gives a colon.
the code:
```rexx
/* platform: windows */
say .RexxInfo~pathSeparator
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
;
```

the code:
```rexx
/* platform: unix */
say .RexxInfo~pathSeparator
```
the result:
```
:
```
the reference says:
```
:
```

```
.RexxInfo~platform
```
this method gives the name of the system of the platform, as a string.
the parse source instruction gives the same name, as the first token of its result.
the code:
```rexx
/* platform: windows */
say .RexxInfo~platform
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
WindowsNT
```

the code:
```rexx
/* platform: linux */
say .RexxInfo~platform
```
the result:
```
LINUX
```
the reference says:
```
LINUX
```

```
.RexxInfo~release
```
this method gives the release of the interpreter, as a number: the second part of the version.
the code:
```rexx
say .RexxInfo~release
```
the result:
```
3
```

```
.RexxInfo~revision
```
this method gives the revision of the interpreter.
a program must not need the way of this value.
the code:
```rexx
say .RexxInfo~revision
```
the result:
```
13196
```

```
.RexxInfo~version
```
this method gives the version of the interpreter.
the version is the first part, a point, the release, a point, and the modification.
the code:
```rexx
say .RexxInfo~version
```
the result:
```
5.3.0
```

## the stack frame class

```
.StackFrame
```
an object of this class gives facts about one frame of the stack of calls of an activity that runs now.
you get these objects from the environment symbol point context, or from the condition object of a trapped condition.
a stack frame says where the code is, its arguments, and other facts you can use to debug.
you can not make an object of this class with the new method.

```
.StackFrame~arguments
```
this method gives the arguments of the frame.

```
.StackFrame~context
```
this method gives the context object of the frame, an object of the rexxcontext class.

```
.StackFrame~executable
```
this method gives the executable of the frame: a routine object or a method object.

```
.StackFrame~invocation
```
this method gives the id of the invocation of the frame, as a number.
this method can give nil, as for native code.

```
.StackFrame~line
```
this method gives the number of the line of the frame that runs now.
if the frame is not rexx code, as native code, this method gives nil.

```
.StackFrame~makeString
```
this method gives the line for a trace of the frame, as the string value of the object.

```
.StackFrame~name
```
this method gives the name of the frame; the name is not the same for each type of frame.
if the frame is a method, the name is the name of the message that runs the method.
if the frame is a routine, the name is the name of the routine.
if the frame is an internal routine, the name is the name of the label that the call used.
if the frame is the main part of a program, the name is the name of the file of the program.
if the frame is an interpret instruction, the name is a null string.

```
.StackFrame~string
```
this method gives the line for a trace of the frame, as the string value of the object.

```
.StackFrame~target
```
if the type of the frame is method, this method gives the object that runs the method.
for each other type of frame, this method gives nil.

```
.StackFrame~traceLine
```
this method gives the line that the trace of an error message shows for this frame.
when it can, this line is the line of rexx source code.
if the source is not available, the line says the method or routine of the frame.

```
.StackFrame~type
```
this method gives the type of the frame as a string, one of these values.
```
PROGRAM
```
with this value, the frame is the top level of a program.
```
METHOD
```
with this value, the frame is a method.
```
ROUTINE
```
with this value, the frame is a routine.
```
INTERPRET
```
with this value, the frame is code that an interpret instruction made.
```
INTERNALCALL
```
with this value, the frame is a call of a subroutine or a function at an internal label.
```
COMPILE
```
with this value, the frame makes rexx code ready to run.
many syntax errors come from a frame of this type.
the code:
```rexx
interpret "call level2" 21
::routine level2
  call level3 31, 32
  return
  level3: procedure
    signal on syntax
    .Method~new("", "~~")
    return
    syntax:
    do f over condition("o")["STACKFRAMES"]
      say (f~type f~name"("f~arguments~makeString(, ",")")")~left(27) f~line":" -
        f~traceLine~strip
    end
```
the result:
```
COMPILE ()                  1: 1 *-* ~~
METHOD NEW(,~~)             The NIL object: *-* Compiled method "NEW" with scope "Method".
INTERNALCALL LEVEL3(31,32)  7: 7 *-*   .Method~new("", "~~")
ROUTINE LEVEL2(21)          3: 3 *-* call level3 31, 32
INTERPRET ()                1: 1 *-* call level2 21
PROGRAM /tmp/claude-0/-home 1: 1 *-* interpret "call level2" 21
```
the reference says:
```
COMPILE ()                  1: 1 *-* ~~
METHOD NEW(,~~)             The NIL object: *-* Compiled method "NEW" with scope "Method".
INTERNALCALL LEVEL3(31,32) 9: 9 *-*    .Method~new("", "~~")
ROUTINE LEVEL2(21)          4: 4 *-* call level3 31, 32
INTERPRET ()                1: 1 *-*   call level2 21
PROGRAM C:\stackFrame.rex() 1: 1 *-* interpret "call level2" 21
```

## the traceobject class

```
.TraceObject
```
this class is a subclass of the stringtable class, so it is a map collection.
each index of a trace object is a unique string.
a trace object keeps facts about the trace, with facts about the context, so you can trace and debug programs, also programs with many threads.
when trace is on, the language makes a trace object for each clause in the trace, and puts the facts of the trace in it.
as a default, the language sends each new trace object to the traceoutput monitor, so it shows its string value.
the monitor sends the makestring message to the trace object, and that method gives the string.
the option attribute of this class says the way of each trace line for all trace objects.
you can use the collector attribute of this class to keep all new trace objects, so a program can use them after the trace.

```
.TraceObject~activate
```
this method is a class method.
this method sets the attributes of the class: the option attribute to the letter for normal, the collector attribute to nil, and the counter attribute to 0.

```
.TraceObject~collector
```
this method is a class method.
this method gives the value of the collector attribute of the class.
the collector attribute says if the class keeps the new trace objects.
its default value is nil: then the class does not keep them.

```
.TraceObject~collector=(object)
```
this method is a class method.
this method sets the collector attribute of the class to the object in the argument.
if the object is not nil, from then on the new method sends each new trace object to the collector object with the append message.
when the append message is sent, the trace object has only the entries for the number, the option, and the time.
the language adds the other entries to the trace object while the trace goes on, so after the trace each trace object has all its entries.
if you need all entries at the time of the append message, use the notify attribute.
each ordered collection class has an append method, so you can use an array or a list as the collector.

```
.TraceObject~counter
```
this method is a class method.
this method gives the value of the counter attribute of the class.
the new method uses the counter attribute to give a unique number to each new trace object.
the value is the count of all trace objects made before now, or 0 if no trace object was made yet.

```
.TraceObject~makeStringImpl(traceObject)
```
this method is a class method.
this method makes the trace line from the trace object in the argument, and gives it as a string.
the option attribute says the way of the trace line.
```
N
```
normal: the way that is used when you do not say an other way
with this option, the result is the trace line of the trace object.
```
T
```
with this option, the number of the thread goes in the prefix of the trace line, after the second character.
```
S
```
with this option, a string between square brackets goes before the trace line.
the string has the number of the thread and the number of the invocation.
if the trace is in a method, the string also says if the method is guarded, the number of the attribute pool, the lock count of the object scope, if the object scope lock is reserved, and if the method waits for a guard to be true.
```
F
```
with this option, the string between square brackets also has the number of the rexx instance of the interpreter.
```
P
```
with this option, the language shows no trace line.
each new trace object goes to the collector attribute if it is not nil.
so a program can use the trace objects after the trace ends.
with a class method of this class, you can put a method you make in the place of this method.

```
.TraceObject~new
```
this method is a class method.
this method makes a new trace object and gives it back.
it adds the facts of the trace context to the trace object.
if the collector attribute is not nil, this method sends the append message to the collector, with the new trace object as the argument.
the trace part of the language makes a trace object for each trace line, and stores these entries in it.
```
ATTRIBUTEPOOL   INTERPRETER   INVOCATION   SCOPELOCKCOUNT   THREAD
```
each of these entries is a number.
```
CALLERSTACKFRAME   STACKFRAME
```
each of these entries is a stringtable with facts about a stack frame: the caller frame, or the frame of the trace line.
the stringtable has the entries arguments, executable, invocation, line, name, target, and type, and the trace line of the frame.
```
HASSCOPELOCK   ISGUARDED   ISWAITING
```
each of these entries is true or false.
```
NUMBER
```
this entry is a number in order from the counter attribute; the default sort uses it.
```
OPTION
```
this entry is the option at the time when the trace object was made.
```
RECEIVER
```
this entry is the receiver object of the method that runs.
```
TIMESTAMP
```
this entry is the date and the time when the trace object was made.
```
TRACELINE
```
this entry is the trace line that the language uses when the option is normal.
```
VARIABLE
```
this entry is a stringtable for the variable that the trace shows.
it has the entries name, value, and assignment.
the assignment entry is true if a value was assigned to the variable, and false if the value was read from it.

```
.TraceObject~notify
```
this method is a class method.
this method gives the value of the notify attribute of the class.
its default value is nil.

```
.TraceObject~notify=(object)
```
this method is a class method.
this method sets the notify attribute of the class to the object in the argument.
if the object is not nil, from then on each trace object goes to the notify object as the argument of the append message, when all its entries are set.
so a program can use each new trace object at the time it is made.
each ordered collection class has an append method, so you can use an array or a list here.
you can also use an object of a class you make that has an append method.

```
.TraceObject~option
```
this method is a class method.
this method gives the value of the option attribute of the class.
the option attribute says the way of each trace line, as the class method that makes the trace line says.

```
.TraceObject~option=(value)
```
this method is a class method.
this method sets the option attribute of the class.
the value may be one of these strings.
```
Normal   Thread   Standard   Full   Profile   Probing
```
this method keeps only the first letter of the value, in upper.
with the last two values, each trace object goes to the collector attribute, but the language does not send it to the traceoutput monitor.

```
.TraceObject~setMakeString(makeStringMethod)
```
this method is a class method.
with this method you can give a makestring method that you make, to use in the place of the class method that makes the trace line.
the argument can be a method object, a string with one line of a method, or an array of strings with the lines of a method.
for a string or an array, the language makes a method object from it.
the method you give gets one trace object as its argument, and must give back a string.

```
.TraceObject~unsetMakeString
```
this method is a class method.
this method ends the change that each message to set the makestring method made before.

```
.TraceObject~compareTo(otherTraceObject)
```
this method compares two trace objects by their number entry, the order in which the language made them.
this method gives the default order of a sort.
this method gives negative one if the argument is more, zero if the two are equal, and one if the argument is less than the receiver.

```
.TraceObject~makeString
```
this method calls the class method that makes the trace line, with the receiver as the argument, and gives back its result.

## the rexxqueue class

```
.RexxQueue
```
an object of this class gives you a way to use a rexx external data queue as an object.

```
.RexxQueue~new([name])
```
this method is a class method.
this method gives a new rexxqueue object for the external data queue with the name in the argument.
if you omit the argument, the object is for the queue named session.
if the argument is nil, the method makes a new external data queue with a name that the system gives, and the object is for that queue.
if a queue with that name exists, the method opens it; if not, the method makes it.
the code:
```rexx
q = .RexxQueue~new
q~queue("line")
q~push("header")
say q~queued q~pull
q~delete
```
the result:
```
2 header
```
the reference says:
```
2 header
```

```
.RexxQueue~create([name])
```
this method is a class method.
this method makes a new external data queue and gives its name.
the name is the argument, if no external data queue with that name exists.
if you omit the argument, or if a queue with that name exists, the system gives the name.
the code:
```rexx
-- no MYQUEUE queue exists
say .RexxQueue~create("myqueue")         -- MYQUEUE
-- MYQUEUE queue already exists
say .RexxQueue~create("myqueue")         -- S0000000000004B48Q000001E1BEE66F20 (e. g.)
```
the result:
```
myqueue
S19dcQ7f2f00002380
```

```
.RexxQueue~delete(name)
```
this method is a class method.
this method deletes the external data queue with the name in the argument.
it gives 0 if it can delete the queue.
any other result is an error code from the queue functions of the interpreter.

```
.RexxQueue~exists(name)
```
this method is a class method.
this method gives true if an external data queue with the name in the argument exists now, else false.
the code:
```rexx
say .RexxQueue~exists("SESSION")
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
.RexxQueue~open(name)
```
this method is a class method.
this method gives 0 if the external data queue with the name in the argument exists, or if it does not exist and the method can make it.
any other result is an error code from the queue functions of the interpreter.

```
.RexxQueue~delete
```
this method deletes the external data queue of the receiver.
it gives 0 if it can delete the queue.
any other result is an error code from the queue functions of the interpreter.
after this, if you call the lineout, pull, push, queue, or say method of the receiver, it is an error.

```
.RexxQueue~empty
```
this method takes away all the lines from the external data queue of the receiver.
it gives 0 if it can; any other result is an error code from the queue functions of the interpreter.

```
.RexxQueue~get
```
this method gives the name of the external data queue of the receiver.

```
.RexxQueue~init([name])
```
this class has an init method.
a subclass that has an init method must forward the init message to its superclass, so the new object is ready.

```
.RexxQueue~lineIn
```
this method reads one line from the external data queue.
if the queue is empty, this method waits until a line is added to the queue.

```
.RexxQueue~lineOut([line])
```
this method adds the line at the end of the external data queue, in fifo order.
if you omit the argument, this method adds a null string.

```
.RexxQueue~makeArray
```
this method gives an array with one index, with as many items as the queue has.
the items of the array are in the order of the items of the queue.
this method makes the external data queue empty.

```
.RexxQueue~pull
```
this method reads one line from the external data queue.
if the queue is empty now, this method gives nil now; it does not wait for lines.

```
.RexxQueue~push([line])
```
this method adds the line at the start of the external data queue, so it is the next line that a pull reads.
if you omit the argument, this method adds a null string.

```
.RexxQueue~queue([line])
```
this method adds the line at the end of the external data queue, in fifo order.
if you omit the argument, this method adds a null string.

```
.RexxQueue~queued
```
this method gives the count of lines in the external data queue now.

```
.RexxQueue~say([line])
```
this method adds the line at the end of the external data queue, in fifo order.
if you omit the argument, this method adds a null string.

```
.RexxQueue~set(name)
```
this method changes the external data queue of the receiver to the queue with the name in the argument.
that queue must be created before.
this method gives the name of the queue that the receiver uses now.

## the streamsupplier class

```
.StreamSupplier
```
this class is a subclass of the supplier class.
a streamsupplier gives the lines of a stream in the way a supplier gives items, so you can use a loop that gets each line that is left in the stream.
a streamsupplier gives the stream as it is at the time the streamsupplier is made, with the read position at that time.
as a rule, a change after that of the read position or the write position of the stream does not change what the streamsupplier gives.
but an other program can change the lines that are left while the loop runs.
this class inherits the other methods of the supplier class, as the supplier class has them.

```
.StreamSupplier~available
```
this method gives true if an item is available: then the item method gives a value.
this method gives false if the collection is empty, or if the supplier is after the last item of the collection.

```
.StreamSupplier~index
```
this method gives the index of the item of the collection at the place of the supplier now.
if no item is available, the supplier raises an error.

```
.StreamSupplier~init
```
this method makes the new object ready.

```
.StreamSupplier~item
```
this method gives the item of the collection at the place of the supplier now.
if no item is available, the supplier raises an error.

```
.StreamSupplier~next
```
this method goes to the next item of the collection.
if you send this message again and again while the available method gives true, you get all the items of the collection.
if no item is available, the supplier raises an error.

## the circularqueue class

```
.CircularQueue
```
a circularqueue keeps objects in a queue with a size that you give.
when the queue is full, new items go in at the start and take the place of the items there.
any object can be an item, and the same object can be at more than one position in the queue.
you can use the items in fifo order or in lifo order, as a stack.
this class inherits the methods of the collection class and of the ordered collection class.
this class is a subclass of the queue class; the methods of the queue class that this class does not have work as in the queue class.
the example makes a circularqueue with five items, then changes its size and adds items.
the code:
```rexx
-- create a circular buffer with five items
u=.circularQueue~of("a", "b", "c", "d", "e")
say "content: ["u"]," "content (LIFO): ["u~string("->","L")"]"
say
u~resize(4, "FIFO")     -- resize fifo-style (keep newest)
say "after resizing to 4 items in FIFO style (keeping the newest):"
say "content: ["u"]," "content (LIFO): ["u~string("->","L")"]"
say
u~resize(2, "LIFO")     -- resize lifo-style (keep oldest)
say "after resizing to 2 items in LIFO style (keeping the oldest):"
say "content: ["u"]," "content (LIFO): ["u~string("->","L")"]"
say
u~resize(0)             -- resize lifo-style (keep oldest)
say "after resizing to 0 items, thereby deleting all items:"
say "content: ["u"]," "content (LIFO): ["u~string("->","L")"]"
say
u~resize(2)             -- resize lifo-style (keep oldest)
say "after resizing to 2, size="u~size "and items="u~items
u~~queue('x')~~queue('y')~~queue('z')
say "after queuing the three items 'x', 'y', 'z':"
say "content: ["u"]," "content (LIFO): ["u~string("->","L")"]"
say
u~~push('1')~~push('2')~~push('3')
say "after pushing the three items '1', '2', '3':"
say "content: ["u"]," "content (LIFO): ["u~string("->","L")"]"
say
```
the result:
```
content: [a,b,c,d,e], content (LIFO): [e->d->c->b->a]

after resizing to 4 items in FIFO style (keeping the newest):
content: [b,c,d,e], content (LIFO): [e->d->c->b]

after resizing to 2 items in LIFO style (keeping the oldest):
content: [b,c], content (LIFO): [c->b]

after resizing to 0 items, thereby deleting all items:
content: [], content (LIFO): []

after resizing to 2, size=2 and items=0
after queuing the three items 'x', 'y', 'z':
content: [y,z], content (LIFO): [z->y]

after pushing the three items '1', '2', '3':
content: [3,2], content (LIFO): [2->3]

```
the reference says:
```
content: [a,b,c,d,e], content (LIFO): [e->d->c->b->a]

after resizing to 4 items in FIFO style (keeping the newest):
content: [b,c,d,e], content (LIFO): [e->d->c->b]

after resizing to 2 items in LIFO style (keeping the oldest):
content: [b,c], content (LIFO): [c->b]

after resizing to 0 items, thereby deleting all items:
content: [], content (LIFO): []

after resizing to 2, size=2 and items=0
after queuing the three items 'x', 'y', 'z':
content: [y,z], content (LIFO): [z->y]

after pushing the three items '1', '2', '3':
content: [3,2], content (LIFO): [2->3]

```

```
.CircularQueue~of([item] [,item]...)
```
this method is a class method.
this method gives a new circularqueue with the items in the arguments.
the first item has index 1, the second item has index 2, and so on.
for each omitted item, the queue gets a null string.
the count of the arguments, with the omitted arguments, is the size of the queue.

```
.CircularQueue~init(size)
```
this method makes the new circularqueue ready.
the argument is not optional; it is the size of the queue at the start.
the argument must be a whole number that is not negative.

```
.CircularQueue~append(item)
```
this method adds the item at the end of the order of the queue, and gives the index of the new item.
if the queue is full, this method first deletes the first item.

```
.CircularQueue~insert(item [,index])
```
this method adds the item to the queue and gives the index that the queue gives the item.
the new item goes after the item with the index in the second argument.
if the second argument is nil, the new item goes at the start of the queue.
if you omit the second argument, the new item is the last item of the queue.
the items after the new item get new indexes.
if the queue gets more items than its size, this method takes away the last item of the queue.

```
.CircularQueue~intersection(argument)
```
this method gives a new collection of the same class as the receiver.
the new collection has only the items of the receiver that are also in the argument.
the argument can be a collection, or an other object that has a makearray method.
the new circularqueue has the same size as the receiver.

```
.CircularQueue~makeArray([order])
```
this method gives an array with one dimension, with the items of the queue in the order in the argument.
only the first letter of the argument is needed; this method ignores the other characters.
```
Fifo
```
with this option, the order is fifo.
this is the default.
```
Lifo
```
with this option, the order is lifo, as a stack.
the code:
```rexx
-- reverse an array
a = .Array~of("one", "two", "three", "four", "five")
say .CircularQueue~new(a~size)~appendAll(a)~makeArray("lifo")~makeString(, ", ")
```
the result:
```
five, four, three, two, one
```
the reference says:
```
five, four, three, two, one
```

```
.CircularQueue~makeString([delimiter] [,order])
```
this method gives a string with the string values of the items, in the order in the second argument.
the first argument is the string that goes between two items.
if you omit the first argument, the string between two items is a comma.
only the first letter of the second argument is needed; this method ignores the other characters.
```
Fifo
```
with this option, the order is fifo.
this is the default.
```
Lifo
```
with this option, the order is lifo, as a stack.

```
.CircularQueue~push(item [,option])
```
this method adds the item before the first item of the queue; the new item is the first item.
if the queue is full, this method first deletes the last item of the queue, and gives back that item.
if the queue is not full, this method gives nil.
the second argument is optional; it may be normal or unique.
the default is normal.
only the first letter of the second argument is needed; this method ignores the other characters.
with the unique option, this method first takes away from the queue each item that is the same as the new item.
so you can keep a list of the last files you used, as an editor does.

```
.CircularQueue~queue(item [,option])
```
this method adds the item at the end of the queue.
if the queue is full, this method first deletes the first item of the queue, and gives back that item.
if the queue is not full, this method gives nil.
the second argument is optional; it may be normal or unique.
the default is normal.
only the first letter of the second argument is needed; this method ignores the other characters.
with the unique option, this method first takes away from the queue each item that is the same as the new item.
so you can keep a list of the last files you used, as an editor does.

```
.CircularQueue~resize(newsize [,order])
```
this method changes the size of the queue, so it can have as many items as the first argument says.
if the queue has more items than that, this method takes away items, in the order in the second argument, until the queue has that many items.
only the first letter of the second argument is needed; this method ignores the other characters.
the default order is fifo.
if the first argument is 0, this method takes away all the items of the queue.

```
.CircularQueue~section(start [,items])
```
this method gives a new queue of the same class as the receiver, with some items of the receiver.
the first item of the new queue is the item at the index in the first argument.
the next items of the new queue are the items after it in the receiver, in the same order.
if you give the second argument, a whole number, the new queue has only that many items, or less if the receiver has less items after the start.
if you omit the second argument, the new queue has all the items after the start.
this method does not change the receiver.
the size of the new queue is the size of the receiver or the second argument, the one that is more.
the items this method takes go on from the end of the receiver to its start.
so with the first argument 2, the new queue has all the items in a new order: it starts with the second item, and the first item is the last.

```
.CircularQueue~size
```
this method gives the maximum count of items that the queue can have.

```
.CircularQueue~string([delimiter] [,order])
```
this method gives a string with the string values of the items, in the order in the second argument.
the first argument is the string that goes between two items.
if you omit the first argument, the string between two items is a comma.
only the first letter of the second argument is needed; this method ignores the other characters.
```
Fifo
```
with this option, the order is fifo.
this is the default.
```
Lifo
```
with this option, the order is lifo, as a stack.

```
.CircularQueue~supplier([order])
```
this method gives a supplier for the queue.
the supplier gives the items that are in the queue at the time when the supplier is made.
the supplier gives the items in the order in the argument.
only the first letter of the argument is needed; this method ignores the other characters.
```
Fifo
```
with this option, the order is fifo.
this is the default.
```
Lifo
```
with this option, the order is lifo, as a stack.

```
.CircularQueue~union(argument)
```
this method gives a new collection of the same class as the receiver.
the new collection has all the items of the receiver, and some items of the argument.
it has an item of the argument only if the receiver has no item that is equal to it, and this method did not add it before.
you can not know the order in which this method takes the items of the argument; a program must not need that order.
the argument can be a collection, or an other object that has a makearray method.
the size of the new circularqueue is the size of the receiver or the count of items of the union, the one that is more.

```
.CircularQueue~xor(argument)
```
this method gives a new collection of the same class as the receiver.
the new collection has all the items of the receiver and of the argument, but not the items that are in both.
the argument can be a collection, or an other object that has a makearray method.
the size of the new circularqueue is the size of the receiver or the count of items of the result, the one that is more.

## the identitytable class

```
.IdentityTable
```
an identitytable is a map collection where each index can be any object.
each item has one index, and there can be only one item for each index.
an identitytable compares indexes and items by the object, not by the value: an index is equal only to the same object.
this class inherits the methods of the collection class and of the map collection class.

```
.IdentityTable~new([size])
```
this method is a class method.
this method gives a new empty identitytable.
the argument is optional; it says how many items the identitytable may get, so it can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.IdentityTable~[](index)
```
this method gives the item at the index in the argument.
this method is the same as the at method.

```
.IdentityTable~[]=(item, index)
```
this method puts the item in the table at the index.
this method is the same as the put method.

```
.IdentityTable~allIndexes
```
this method gives an array of all the indexes of the table.

```
.IdentityTable~allItems
```
this method gives an array of all the items of the table.

```
.IdentityTable~at(index)
```
this method gives the item at the index in the argument.
if the table has no item at that index, this method gives nil.

```
.IdentityTable~empty
```
this method takes away all the items of the table, and gives back the receiver.

```
.IdentityTable~hasIndex(index)
```
this method gives true if the table has an item at the index in the argument, else false.

```
.IdentityTable~hasItem(item)
```
this method gives true if the table has the item in the argument at any index, else false.

```
.IdentityTable~index(item)
```
this method gives the index of the item in the argument.
if the item is at more than one index, this method gives the first index where it finds the item.
if the table does not have the item, this method gives nil.

```
.IdentityTable~isEmpty
```
this method gives true if the table is empty, else false.

```
.IdentityTable~items
```
this method gives the count of items in the table.

```
.IdentityTable~makeArray
```
this method gives an array with one dimension, with the indexes of the table.
the indexes of the array are from 1 to the count of items.
you can not know the order of the items in the array.

```
.IdentityTable~put(item, index)
```
this method puts the item in the table at the index in the second argument.
the new item takes the place of an item that was at that index before.

```
.IdentityTable~remove(index)
```
this method takes away the item at the index in the argument, and gives back that item.
if no item has that index, this method gives nil.

```
.IdentityTable~removeItem(item)
```
this method takes away the item in the argument from the table, and gives back that item.
if the item is at more than one index, this method takes away the first one it finds.

```
.IdentityTable~supplier
```
this method gives a supplier for the table.
the supplier gives each index and item that the table has at the time when the supplier is made.
you can not know the order in which the supplier gives the items.

## the properties class

```
.Properties
```
a properties object is a map collection where each index is a unique string, a name, and each item is a string too.
you can use a properties object to keep a set of options for an application.
this class is a subclass of the directory class.
this class inherits the methods of the collection class and of the map collection class.
the methods of the directory class that this class does not have work as in the directory class.

```
.Properties~load(source)
```
this method is a class method.
this method reads a set of properties from the argument, and gives them as a new properties object.
the argument can be the name of a file as a string, a file object, or a stream object.
this method reads the source line by line, with the linein method.
it ignores blank lines, and lines where the first characters that are not blanks are two dash marks, a rexx comment.
each other line must be a name, an equal mark, and a value.
this method adds the value to the properties object, with the name as its index.

```
.Properties~new([size])
```
this method is a class method.
this method gives a new empty properties object.
the argument is optional; it says how many items the object may get, so it can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.Properties~[]=(item, name)
```
this method adds the item at the index in the argument.
this method is the same as the put method.

```
.Properties~getLogical(name [,default])
```
this method gives the value of the property with the name in the first argument, as true or false.
the value of the property must be 0, 1, true, or false; any other value raises a syntax error.
if there is no property with that name and you give the second argument, this method gives the second argument.
if there is no property with that name and you omit the second argument, a syntax error is raised.

```
.Properties~getProperty(name [,default])
```
this method gives the value of the property with the name in the first argument.
if there is no property with that name and you give the second argument, this method gives the second argument.
if there is no property with that name and you omit the second argument, this method gives nil.

```
.Properties~getWhole(name [,default])
```
this method gives the value of the property with the name in the first argument; the value must be a rexx whole number.
if there is no property with that name and you give the second argument, this method gives the second argument.
if there is no property with that name and you omit the second argument, a syntax error is raised.

```
.Properties~load(source)
```
this method reads a set of properties from the argument and puts them in the receiver.
the argument can be the name of a file as a string, a file object, or a stream object.
this method reads the source line by line, with the linein method.
it ignores blank lines, and lines where the first characters that are not blanks are two dash marks, a rexx comment.
each other line must be a name, an equal mark, and a value.
this method adds the value to the receiver, with the name as its index.
a property from the source with the same name as a property in the receiver takes the place of it.

```
.Properties~put(item, name)
```
this method puts the item in the collection at the index in the second argument.
the item must be a string.
the new item takes the place of an item or a method that was at that index before.

```
.Properties~save(target)
```
this method writes the properties to the argument.
the argument can be the name of a file as a string, a file object, or a stream object.
this method writes each property as one line, with the lineout method.
each line is a name, an equal mark, and a value.
the load method can read a file that this method writes.

```
.Properties~setLogical(name, value)
```
this method sets a property with a value that is true or false.
the value argument must be 0, 1, true, or false.
this method stores the value as the string true or the string false.

```
.Properties~setProperty(name, value)
```
this method sets the property with the name in the first argument.
the value argument must be a string.

```
.Properties~setWhole(name, value)
```
this method sets a property with a whole number value.
the value argument must be a rexx whole number.

## the inputoutputstream class

```
.InputOutputStream
```
this class is an abstract mixin class.
you must make a subclass of it, or a class that inherits it as a mixin.
this class inherits the methods of the outputstream class and of the inputstream class.
this class has only the methods that it inherits.
the stream class is a subclass of this class.

## the inputstream class

```
.InputStream
```
this class is an abstract mixin class.
you must make a subclass of it, or a class that inherits it as a mixin.
many methods of this class are abstract: if you call one of them and the subclass does not have it, a syntax error is raised.
the stream class inherits the methods of this class.

```
.InputStream~arrayIn
```
this method is the default way to read the stream and put its lines in an array.
it uses the linein method to put lines in the array.

```
.InputStream~charIn
```
this method is abstract: if you call it, syntax error 93.965 is raised.

```
.InputStream~charOut
```
this method is not for an input stream: if you call it, syntax error 93.963 is raised.

```
.InputStream~chars
```
this method is abstract: if you call it, syntax error 93.965 is raised.

```
.InputStream~close
```
as a default, this method does nothing.

```
.InputStream~lineIn
```
this method is abstract: if you call it, syntax error 93.965 is raised.

```
.InputStream~lineOut
```
this method is not for an input stream: if you call it, syntax error 93.963 is raised.

```
.InputStream~lines
```
this method is abstract: if you call it, syntax error 93.965 is raised.

```
.InputStream~open
```
this method does nothing.

```
.InputStream~position
```
a subclass does not have to have this method.
as a default, if you call it, syntax error 93.963 is raised.

## the outputstream class

```
.OutputStream
```
this class is an abstract mixin class.
you must make a subclass of it, or a class that inherits it as a mixin.
many methods of this class are abstract: if you call one of them and the subclass does not have it, a syntax error is raised.
the stream class inherits the methods of this class.

```
.OutputStream~arrayOut
```
this method is the default way to write an array to the stream.
it uses the lineout method to write all the lines.

```
.OutputStream~charIn
```
this method is not for an output stream: if you call it, syntax error 93.963 is raised.

```
.OutputStream~charOut
```
this method is abstract: if you call it, syntax error 93.965 is raised.

```
.OutputStream~chars
```
this method is not for an output stream: if you call it, syntax error 93.963 is raised.

```
.OutputStream~close
```
as a default, this method does nothing.

```
.OutputStream~lineIn
```
this method is not for an output stream: if you call it, syntax error 93.963 is raised.

```
.OutputStream~lineOut
```
this method is abstract: if you call it, syntax error 93.965 is raised.

```
.OutputStream~lines
```
this method is not for an output stream: if you call it, syntax error 93.963 is raised.

```
.OutputStream~open
```
as a default, this method does nothing.

```
.OutputStream~position
```
a subclass does not have to have this method.
as a default, if you call it, syntax error 93.963 is raised.

## how a set operation works

operations: more than one operation
elements: more than one element
bags: more than one bag

```
SET OPERATIONS
result = receiver~setoperator(argument)
```
rexx has these methods for set operations: difference, intersection, subset, union, and xor.
these facts say how to use them, most of all when the class of the receiver is not the class of the argument.
the ordered collections array, list, queue, and circularqueue have these methods.
the map collections directory, stem, table, identitytable, and relation have these methods.
the set collections set and bag have these methods.
the receiver is the collection that gets the message, and the argument is the collection you give to the method.
the argument can be an object of a rexx collection class, or any object that has a makearray method or a supplier method, as the class of the receiver needs.
the result is an object of the same class as the receiver.
a set operation takes each element of the receiver in turn and compares it with each element of the argument.
an element is a pair of two things: an index and an item.
the method and the result of the compare say if an element of the receiver goes in the result or not.
a receiver that can have two equal elements can also take elements of the argument, after they are changed to the kind of the receiver.
the examples here write a collection as a list of elements between brackets, with a comma between two elements.

```
SET OPERATIONS ON SETS
A={a,b}   B={b,c,d}
```
in these examples, the two collections are sets: no set has two equal elements.
the result of each set operation is a set, but not for the subset, equivalent, and disjoint operations.
```
A UNION B = {a,b,c,d}
```
the union has all the elements of the two sets.
```
A DIFFERENCE B = {a}
B DIFFERENCE A = {c,d}
```
the difference has all the elements of the first set, but not the elements that are also in the second set.
the system takes each element of the second set in turn, and takes it away from the first set.
```
A XOR B = {a,c,d}
```
the xor has the elements of the first set that are not in the second set, and the elements of the second set that are not in the first set.
```
A INTERSECTION B = {b}
```
the intersection has the elements that are in both sets.
```
A SUBSET B = .false
B SUBSET A = .false
```
the subset operation gives true if the first set has only elements that are also in the second set, else false.
```
A EQUIVALENT B = .false
B EQUIVALENT A = .false
```
the equivalent operation gives true if the first set has only elements that are also in the second set, and the two sets have the same count of elements, else false.
```
A DISJOINT B = .false
B DISJOINT A = .false
```
the disjoint operation gives true if no element is in both sets, else false.

```
SET OPERATIONS ON BAGS
A={a,b,b}   B={b,b,c,c,d}
```
in these examples, the two collections are bags: a bag can have two equal elements.
the result of each operation is a bag, but not for the subset, equivalent, and disjoint operations.
```
A UNION B = {a,b,b,b,b,c,c,d}
A DIFFERENCE B = {a}
B DIFFERENCE A = {c,c,d}
A XOR B = {a,c,c,d}
A INTERSECTION B = {b,b}
A SUBSET B = .false
B SUBSET A = .false
A EQUIVALENT B = .false
B EQUIVALENT A = .false
A DISJOINT B = .false
B DISJOINT A = .false
```
each operation does the same as with sets.

```
SET OPERATIONS AND ITEMS
```
to know if an element is in the receiver, a set operation must know when two elements are the same.
an element of a collection is the pair of its index and its item; the index is the name of the item.
the class of the index is not the same for each collection class: a string for a directory, an integer for an array, or any class for a relation.
an array can have more than one dimension, so more than one index; but a set operation uses it as a list in one order.
for the set, identitytable, table, directory, and stem classes, each index is unique, so an item is known by its index.
for the relation class, many items can have the same index, so an item is known by its index and its item.
for the bag class and the set class, many items can have the same index, but the index and the item must be the same, so an item is known by its index.
for the array, list, and queue classes, the index comes from the position of the item in the order of the collection, so an item is known only by the item.
when the receiver and the argument have indexes of other kinds, the language first changes the argument to a collection of the same kind as the receiver, then does the operation with it.
the way of this change is not the same for each kind of receiver and argument.
```
Map Collection
```
when the receiver is a map collection, these rules are true.
if the argument is a map collection, its indexes say which elements are in it, and the result gets pairs of index and item.
if the argument is an ordered collection or a set collection, it is changed to a map collection where each item is both the index and the item.
the argument can have two equal items, so the changed collection is like a relation.
for any other argument object, its makearray method gives the values, and they are used as an ordered collection.
```
Ordered Collection and Set Collection
```
when the receiver is an ordered collection or a set collection, these rules are true.
if the argument is a collection, its method that gives all its items gives the items to compare.
for any other argument object, its makearray method gives the items.
the method that says if a collection has an item compares the items of the two collections.
```
Relation
```
when the receiver is a relation, the rules are the same as for a map collection.
also, each test that says if an element goes in the result uses both the index and the item.

