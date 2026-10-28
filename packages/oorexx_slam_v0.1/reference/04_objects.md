# objects and classes

this file has facts from the rules of rexx about objects, classes, the objects that rexx gives, and concurrent methods, as oorexx has them.

```
class
```
finds: find, for one thing
superclasses: more than one superclass
inherited: a method is inherited when a class inherits it
often: many times
example: code that says how to use a thing
parses: parse, for one thing
a class can be of four kind: an object class, a mixin class, an abstract class, or a metaclass.
an object class makes objects.
a class makes instances, and gives the methods that the instances can use.
an object gets the methods of its class when the class makes it.
if you add a method to a class after that, the objects that are there before do not get it.
rexx does not make the variables of an instance at the start.
a variable of an instance is there when a method uses expose on it.
work: what you do to make a thing true or make a thing change
rexx makes an object in two steps: the class makes the instance and gives it its methods, then the instance does the rest of the work on it.
the string class and the array class are object classes.

```
mixin
```
a class can inherit from more than one superclass.
a mixin class adds a set of methods and class methods to other classes.
you can add the methods of a mixin to a class that is there by an inherit message, or by the inherit option of the class directive.
the class that a class inherits by inherit must be a mixin.
when rexx makes a class, the subclass inherits the methods and the class methods of its superclasses.
base: the base class of a mixin is the first superclass of it that is not a mixin
any subclass of the base class can inherit the mixin.
other classes can not inherit the mixin.
a mixin that is a subclass of the array class can be inherited only by a subclass of the array class.
a mixin whose base class is the object class can be inherited by any class.
to make a mixin, send a mixinclass message to a class, or use the class directive with the mixinclass option.
a mixin is also an object class, and it can make instances.

```
abstract
```
an abstract class has methods and class methods, but you do not use it to make instances.
an abstract class often says what messages its subclasses must have methods for.
you make an abstract class with the abstract option of the class directive.
to make an instance of an abstract class is an error.
a class can have abstract methods or abstract attributes; a subclass must give methods in place of them.
if a subclass does not give a method in place of an abstract method, a call of the abstract method is an error.

```
metaclass
```
a metaclass is a class that makes classes.
the class class is the metaclass of all classes that rexx gives, so the instances of the class class are classes.
the class class makes the classes that make objects.
to change what instances do, make a subclass; the methods of an instance work on the instance.
to change what a class does, you need a class method.
to add a class method, use the method directive with the class option.
to add a class method, you can also make a new metaclass; it is a subclass of the class class.
you use a metaclass by its name in a subclass or a mixinclass message, or in a class directive with the metaclass option.
use the method directive with the class option for a class method that only one class needs.
use a metaclass for a class method that many classes need, as a count of instances.
the code:
```rexx
/* Creating an array subclass for statistics */

::class statArray subclass array public

::method init    /*  Initialize running total and forward to superclass */
  expose total
  total = 0
  forward class (super)

::method put     /*  Modify to increment running total */
  expose total
  use arg value
  total = total + value  /* Should verify that value is numeric!!! */
  forward class (super)

::method "[]="   /*  Modify to increment running total */
  forward message "PUT"

::method remove  /*  Modify to decrement running total */
  expose total
  use arg index
  forward message "AT" continue
  total = total - result
  forward class (super)

::method average /*  Return the average of the array elements */
  expose total
  return total / self~items

::method total   /*  Return the running total of the array elements */
  expose total
  return total

/* Adding a class method using ::METHOD */

a = .point~new(1,1)               /* Create some point instances  */
say "Created point instance" a
b = .point~new(2,2)               /* create another point instance */
say "Created point instance" b
c = .point~new(3,3)               /* create another point instance */
say "Created point instance" c
                                  /* ask the point class how many */
                                  /* instances it has created     */
say "The point class has created" .point~instances "instances."



::class point public                /* create Point class           */

::method init class
  expose instanceCount
  instanceCount = 0                 /* Initialize instanceCount     */
  forward class (super)             /* Forward INIT to superclass   */

::method new class
  expose instanceCount              /* Creating a new instance      */
  instanceCount = instanceCount + 1 /* Bump the count               */
  forward class (super)             /* Forward NEW to superclass    */

::method instances class
  expose instanceCount              /* Return the instance count    */
  return instanceCount


::method init
  expose xVal yVal                  /* Set object variables         */
  use arg xVal, yVal                /* as passed on NEW             */

::method string
  expose xVal yVal                  /* Use object variables         */
  return "("xVal","yVal")"          /* to return string value       */

/* Adding a class method using a metaclass  */

a = .point~new(1,1)                    /* Create some point instances  */
say "Created point instance" a
b = .point~new(2,2)
say "Created point instance" b
c = .point~new(3,3)
say "Created point instance" c
                                       /* ask the point class how many */
                                       /* instances it has created     */
say "The point class has created" .point~instances "instances."

::class InstanceCounter subclass class /* Create a new metaclass that */
                                       /* will count its instances     */
::method init
  expose instanceCount
  instanceCount = 0                    /* Initialize instanceCount     */
  forward class (super)                /* Forward INIT to superclass   */

::method new
  expose instanceCount                 /* Creating a new instance      */
  instanceCount = instanceCount + 1    /* Bump the count               */
  forward class (super)                /* Forward NEW to superclass    */

::method instances
expose instanceCount                   /* Return the instance count    */
return instanceCount


::class point public metaclass InstanceCounter  /* Create Point class */
                                       /* using InstanceCounter metaclass */
::method init
  expose xVal yVal                     /* Set object variables         */
  use arg xVal, yVal                   /* as passed on NEW             */

::method string
  expose xVal yVal                     /* Use object variables         */
  return "("xVal","yVal")"             /* to return string value       */
```
the result:
```
99.901
```

```
scope
```
a scope has the methods and the object variables of one class.
a scope does not have the methods and variables of the superclasses.
only the methods of a scope can use the object variables of that scope.
a subclass can use the same variable names as its superclass, as the variables of each class are in an other scope.
the scope method of the method class gives the scope of a method: a class object or nil.

```
object~setMethod
class~enhanced
```
setmethod: the name of a method that adds a method to one object
enhanced: the name of a method of the class class that makes an instance with more methods
in rexx, an instance gets its methods from its class.
you can also add methods to one instance with the setmethod method or the enhanced method.
all subclasses of the object class inherit the setmethod method.
with setmethod you can make an object that is the only one of its kind, with no class that makes more instances.
the enhanced method of the class class makes new instances of a class with more methods.
the methods and object variables you add with setmethod or enhanced are a scope, not the scope of a class.

```
method names
```
the name of a method can be any string.
when an object gets a message, rexx finds the method whose name is the message name in upper.
rexx puts in upper the name of each method that you add to an object.
put the name of a method in quote marks when it has characters that a symbol can not have, as operator characters.
the code:
```rexx
cost=.object~subclass("A cost")
cost~define("%", 'expose p; say "Enter a price."; pull p; say p*1.07;')
mycost=cost~new
mycost~"%"        /* Produces:  Enter a price.             */
                  /* If the user specifies a price of 100, */
                  /* produces: 107.00                      */
```
the result:
```
41.1
```

```
message
```
when an object gets a message, rexx finds the method in this order.
first: a method of the object, that setmethod or enhanced adds.
second: a method of the class of the object.
third: a method of a superclass of the class of the object.
rexx uses only the methods that the class has when it makes the object.
the order of the inherit messages to the class is the order rexx uses to test the superclasses.
with this order, a class can add to the methods it inherits, or use other methods in place of them.
unknown: not known; also the name of a method that runs when an object has no method for a message
nomethod: the name of a condition
if there is no method with the name, rexx tests if the object has an unknown method.
if the object has an unknown method, rexx calls it with the message name and an array of the message arguments.
the result of the unknown method is the result of the message.
if there is no unknown method, the nomethod condition is raised.
if no trap is on for nomethod, a syntax error is raised.

```
UNKNOWN
```
rexx runs this method when an object gets a message and has no method with that name.
the first argument is the name of the method that rexx can not find.
the second argument is an array of the arguments of the message.
this method can say the name and the arguments of each message, then send the message to an other object.
the code:
```rexx
::method unknown
expose target      -- will receive all of the messages
use arg name, arguments
say name "invoked with" arguments~toString
-- send along the message with the original args
forward to(target) message(name) arguments(arguments)
```
the result:
```
```

```
receiver~messagename:classsymbol
```
a colon and a class symbol after the message name change the order rexx uses to find the method.
the class symbol can be a variable or an environment symbol.
the class symbol says the class object where rexx starts to find the method.
that class must be a superclass of the class of the method that runs now.
if setmethod adds the method that runs now, that class must be the class of the object.
the class symbol is often super, but any variable or environment symbol whose value is a class can be there.
with super, rexx starts to find the method in the superclass, not in the subclass.
the code:
```rexx
savings~define("TYPE", 'return "a savings account"')
savings~define("TYPE", 'return self~type:super "(savings)"')
say asav~type
```
the result:
```
97.1
```
the reference says:
```
an account (savings)
```

```
private
```
any object can send a message that runs a public method.
only the methods and routines in the same package can run a package method.
code can run a private method only from a method of the same class as the method; often this is self.
other instances of the same class, and instances of its subclasses, can also run the private method.
a method with the same scope as a private method can run it.
an instance of a class, or of its subclass, can run a private class method of that class.
an object can have private methods in more than one scope, so a superclass can give methods to its subclasses and not to other objects.
a private method is like an internal subroutine: it keeps the data of an object from the outside, but the object and its class can use it.
the code:
```rexx
::class Savings
::method newCheckingAccount CLASS
  instance = self~new
  instance~makeChecking
  return instance

::method makeChecking private
  expose checking
  checking = .true

::class Savings
::method init class
  expose counter
  counter = 0

::method allocateAccountNumber private class
  expose counter
  counter = counter + 1
  return counter

::method init
  expose accountNumber
  accountNumber = self~class~allocateAccountNumber
```
the result:
```
99.901
```

in the first example, the class method can run the private method, as the scope of the two is the same class.
in the second example, the init method can run the private class method, as the caller is an instance of the same class.

```
init
```
an object that needs work when rexx makes it must have an init method.
the new method makes the object, then the class object runs its init method.
the new method gives its arguments to the init method.
if more than one class of the object has an init method, each init method must send the init message on to its superclass.
the init method of a subclass can call the init method of its superclass with other arguments.
the code:
```rexx
asav = .savings~new(1000.00, 6.25)
say asav~type
asav~name = "John Smith"

::class Account

::method INIT
  expose balance
  use arg balance

::method TYPE
  return "an account"

::method name attribute

::class Savings subclass Account

::method INIT
  expose interest_rate
  use arg balance, interest_rate
  self~init:super(balance)

::method type
  return "a savings account"
```
the result:
```
a savings account
```

```
uninit
```
uninit: the name of the method that rexx runs before it takes away the memory of an object
when no code uses an object, rexx takes back its memory.
if an object has other things of the computer, as an open file, rexx can not give them back, as it does not know of them; the code must do it.
an object can need other work before its end, as a message object with an error that it does not say yet.
an object that needs this work must have an uninit method.
if there is an uninit method, rexx runs it before it takes the memory of the object.
if more than one class of the object has an uninit method, each must send the uninit message on to its superclass.

```
string
```
address: an instruction that sends a command to an environment
arg: an instruction that parses the arguments; also a builtin function that gives the arguments
pull: an instruction that reads a line from the queue, or from the input when the queue is empty, and parses it
push: an instruction that puts a line in the queue
rexx needs a string value at each place in this list.
the count expression or the for expression of a do instruction.
a value in the tail of a compound variable.
a command to an environment.
the command and the environment name of the address instruction.
the string that arg, parse, or pull parses.
the expression in parentheses after the call instruction.
the variable list of drop, expose, and procedure.
the string of the interpret instruction.
the digits, form, and fuzz values of the numeric instruction.
the string of the options instruction.
the data of push and queue.
the label name of signal value.
the trace value of trace value.
the arguments of builtin functions.
the data of the say instruction.
an operator with two operands, when the left operand is a string.
by default, rexx changes an object that is not a string to a string that says what it is, and uses that string.
you can make rexx raise the nostring condition when the object has no string value.
request: the name of a method; rexx sends it with the argument string to an object to get a string value
makestring: the name of a method that gives the string value of an object
to get a string value, rexx sends the request message with the argument string to the object.
strings and subclasses of the string class inherit a makestring method from the string class.
any other object with a string value must have a makestring method.
if the object has no makestring method and a trap is on for nostring, the nostring condition is raised.
if the object has no makestring method and no trap is on for nostring, rexx sends a string message to the object and uses the string it gives.
the maths, compare, and string methods of a string always need a string argument; rexx sends the request message to the argument first.
if the request message gives nil and no trap is on for nostring, rexx sends a string message to the argument.
for all other methods, if the request message gives nil, an error is raised.
the code:
```rexx
d = .directory~new
say substr(d,5,7)         /* Produces "rectory" from "a Directory" */
signal on nostring
say substr(d,5,7)         /* Raises the NOSTRING condition */
say substr(d~string,3,6)  /* Displays "Direct" */
```
the result:
```
16.1
```

```
concurrent
```
rexx can run concurrent methods: many methods can run at the same time on one object.
each rexx object is like a computer: it runs its methods, it has memory for its variables, and it sends and gets messages.
more than one method can run at the same time.
any count of objects can run at the same time; they send messages to each other.
traceobject: the name of a class for trace
you can debug a program with concurrent methods by the trace instruction and the traceobject class.

```
classes
```
rexx gives a set of classes; all are subclasses of the object class.
the classes are in an order of superclass and subclass.
there can be other classes, by the kind of computer.
you can get more classes with a requires directive.
some of the classes are array, class, collection, directory, message, method, object, package, queue, routine, stem, stream, string, supplier, and table.

```
.ENVIRONMENT
```
this object is a directory of public objects; code can use them at any time.
rexx tests this object when code uses an environment symbol.
code can also use this object by its name.
the index of each item is the name of the environment symbol, in upper, without the point.
the index is not caseless: the index object in upper gives the object class, but the index object in lower gives nil.
this object has all the builtin classes of rexx, as array.
endofline: the name of an object that rexx gives; its value is the characters at the end of a line
rexxinfo: the name of an object that gives facts about rexx
this object has the nil, true, false, and endofline objects.
this object has the rexxinfo object.
the code:
```rexx
say .object                            -- Displays "The Object class"
say .environment~object                -- Displays "The Object class"
say .environment["OBJECT"]             -- Displays "The Object class"
say .environment["object"]             -- Displays "The NIL object"
say .rexxinfo                          -- Displays "a RexxInfo"
say .rexxinfo~platform                 -- Displays "WindowsNT" (if running on Windows)
say .environment~rexxinfo~platform     -- Displays "WindowsNT" (if running on Windows)
say .environment["REXXINFO"]~platform  -- Displays "WindowsNT" (if running on Windows)
```
the result:
```
The Object class
The Object class
The Object class
The NIL object
a RexxInfo
LINUX
LINUX
LINUX
```

```
.ENDOFLINE
'0d0a'x   -- on Windows
'0a'x     -- on Unix-like systems
```
this object is a string constant.
its value is the characters that end a line.
windows: the name of a program that runs a computer and its other programs
unix: the name of an other program that runs a computer and its other programs
on windows, its value is two characters.
on unix, its value is one character.
it is in the point environment object.

```
.FALSE
```
this object is the false value.
it is the constant 0.
it is the result of compare and boolean operators when the result is false.

```
.NIL
```
this object has no data.
it says that there is no object, as an empty string says that there is no text.
its only methods are the methods it inherits from the object class.
to test if an item of an array or an other collection is not there, compare it with this object, not with the null string.
the code:
```rexx
if .nil = board[row,col]   /* .NIL rather than "" */
then ...
```
the result:
```
93.924
```

```
.TRUE
```
this object is the true value.
it is the constant 1.
it is the result of compare and boolean operators when the result is true.

```
.LOCAL
```
process: a program that runs on a computer, with its memory
this object is a directory of objects of one rexx process; code can use them at any time.
code uses the objects in it in the same way as the objects in the point environment object.
monitor: an object that has an other object, and sends to it the messages it gets
debuginput: the name of a monitor object for input when you debug
traceoutput: the name of a monitor object for trace output
stdin: the name of the input stream of a process
stdout: the name of the output stream of a process
stderr: the name of the stream for trace and error output
stdque: the name of the queue of rexx
syscargs: the name of an array of the arguments that the command gives the program
by default it has the monitor objects input, output, error, debuginput, and traceoutput.
by default it has the streams stdin, stdout, and stderr.
by default it has stdque, a queue object for the external queue of rexx.
by default it has syscargs, an array of the arguments of the command that runs the program.
this object is a directory object.
you can put objects in it, and get objects from it, with the methods of the directory class.
the index of each object that the program adds must have a point in it, so its name is not the name of an object that rexx gives.
the code:
```rexx
/* .LOCAL example--places something in the Local environment directory */
.local~my.alarm = theAlarm
/* To retrieve it                                                      */
say .local~my.alarm

/* Another .LOCAL example (Windows) */
.environment["MYAPP.PASSWORD"] = "topsecret"
.environment["MYAPP.UID"] = 200

/* Create a local directory for my stuff */
.local["MYAPP.LOCAL"] = .directory~new

/* Add log file for my local directory                                 */
.myapp.local["LOG"] = .stream~new("myapp.log")
say .myapp.password                    /* Displays "topsecret"         */
say .myapp.uid                         /* Displays "200"               */

/* Write a line to the log file */
.myapp.local~log~lineout("Logon at "time()" on "date())

/* Redirect SAY lines into a file:  */
.output~destination(.stream~new("SAY_REDIRECT.TXT"))
say "This goes into a file, and not onto the screen!"

/* .LOCAL example--get the individual command line arguments */
cmdargs = .local~syscargs
do carg over cmdargs
   say carg
end
```
the result:
```
THEALARM
topsecret
200
```

```
.ERROR
```
this object is a monitor object; it has the error stream object.
you can send its output to an other place, in the same way as with the point output object.
by default it sends its output to the point stderr stream.

```
.INPUT
```
linein: a builtin function and a method of the stream class that read a line
this object is a monitor object; it has the default input stream object.
the parse linein instruction reads from it.
the linein method of the stream class reads from it.
the linein function reads from it when you give no stream name.
the pull instruction and the parse pull instruction read from it, but only when the external queue is empty.
by default it reads from the point stdin stream.

```
.OUTPUT
```
lineout: a builtin function and a method of the stream class that write a line
this object is a monitor object; it has the default output stream object.
the say instruction writes to it.
the lineout method writes to it.
the lineout function writes to it when you give no stream name.
you can put an other object in its place in the environment, to send the output to an other place.
by default it writes to the point stdout stream.

```
.TRACEOUTPUT
```
this object is a monitor object; it has the object that gets the trace output.
you can send the trace output to an other place, in the same way as with the point output object.
by default it writes to the point error monitor.

```
.STDERR
```
this object is a stream object.
it is the default stream for trace output and error messages.

```
.STDIN
```
this object is a stream object.
it is the input file of the process.
at the start, it is the default stream of the point input object.

```
.STDOUT
```
this object is a stream object.
it is the output file of the process.
at the start, it is the default stream of the point output object.

```
.STDQUE
```
rexxqueue: the name of a class whose objects are queue objects of rexx
this object is a rexxqueue object.
the push instruction and the queue instruction put lines in it.
the pull instruction and the parse pull instruction read lines from it.

```
.SYSCARGS
```
this object is an array of all the arguments of the command that runs the program.
often, rexx puts the arguments of the command in one string, and the arg function gets that string.
with this object, code gets each argument of the command as it is, not as a part of one string.
this object is not always there, as with some options of the rexx command.
the code:
```rexx
say .SysCArgs~items "SysCArgs" .SysCArgs~makeString(, ",")
say arg() "ARGs" arg(1, "A")~makeString(, ",")

/* when called with command line parameters 1 "2 3" 4, displays:
3 SysCArgs 1,2 3,4
1 ARGs 1 "2 3" 4
*/
```
the result:
```
0 SysCArgs 
0 ARGs 
```

```
.CONTEXT
```
rexxcontext: the name of a class whose objects give facts about the code that runs now
this environment symbol gives a rexxcontext object for the code that runs now.
active: a thing is active when it runs or can run now
the object is active only until the method, the routine, or the program that runs now ends.
after that, a call of any method of the rexxcontext object is an error.

```
.LINE
```
this object is the number of the line of the instruction that runs now.
in an interpret instruction, this object is the number of the line of the interpret instruction.

```
.METHODS
```
stringtable: the name of a class of table objects where each index is a string
this environment symbol gives a stringtable of methods.
the methods are from attribute, constant, and method directives in the program that runs now.
each index is a method name, and each item is a method object.
only floating methods are in it: methods with no class directive before them.
if there are no floating methods, its value is the name of the symbol.
the code:
```rexx
/* .methods contains one entry with the index (method name) "TALK" */
o=.object~enhanced(.methods)  /* create object, enhance it with methods */
o~talk("echo this text")  /* test "TALK" method */
::method talk  /* floating method by the name of "TALK" */
  use arg text  /* retrieve the argument */
  say text  /* display received argument */
```
the result:
```
echo this text
```

```
.ROUTINES
```
this environment symbol gives a stringtable of the routines from routine directives in the program that runs now.
each index is a routine name, and each item is a routine object.
if there are no routine directives, its value is the name of the symbol.
the code:
```rexx
/* .routines contains one entry with the index (routine name) "TALK" */
.routines~talk~call("echo this text")  /* test talk routine */
::routine talk  /* floating routine by the name of "TALK" */
  use arg text  /* retrieve the argument */
  say text  /* display received argument */
```
the result:
```
echo this text
```

```
.RESOURCES
```
this environment symbol gives a stringtable of the resources from resource directives in the program that runs now.
each index is a resource name.
each item is an array of the lines of data of the resource.
if there are no resource directives, its value is the name of the symbol.
the code:
```rexx
do name over .resources
  say name":" .resources[name]~items "lines"
  say .resources[name]~makeString
end

::resource greyCat end "-"
La nuit, tous les chats sont gris
---------------------------------

::resource "brown fox"
The quick brown fox jumps over the lazy dog
::END

::resource nollop end ANONYMOUS
     The wicked peon quivered,
then gazed balefully at the judges
         who examined him.
ANONYMOUS TYPESETTER

/* Displays:
GREYCAT: 1 lines
La nuit, tous les chats sont gris
BROWN FOX: 1 lines
The quick brown fox jumps over the lazy dog
NOLLOP: 3 lines
     The wicked peon quivered,
then gazed balefully at the judges
         who examined him.
*/
```
the result:
```
BROWN FOX: 1 lines
The quick brown fox jumps over the lazy dog
NOLLOP: 3 lines
     The wicked peon quivered,
then gazed balefully at the judges
         who examined him.
GREYCAT: 1 lines
La nuit, tous les chats sont gris
```

```
.RS
```
rexx sets this object to the return value of each command that runs, also a command of the address instruction.
its value is -1 when a command gives a failure condition.
its value is 1 when a command gives an error condition.
its value is 0 when a command says it ends with no error.
you can use its value after a trap for the error or failure condition.
commands that you run in interactive trace do not change its value.
its value at the start is the name of the symbol.

```
activity
```
each rexx object is like a computer, so more than one method can run at the same time.
any count of objects can be active at the same time.
the objects send messages to each other to work and to wait for each other.
an activity runs methods; methods on one activity can run at the same time as methods on an other activity.
invocation: one program, routine, method, or interpret instruction that runs on an activity
invocations: more than one invocation
stack: a list where you put and take items at the same end
an activity has a stack of invocations.
main: the main program is the first program that runs
an invocation can be the main program, an internal call, an external call, an interpret instruction, or a message.
an invocation goes on the stack when it starts, and rexx takes it away when it ends.
a program starts with one activity, with one invocation.

```
REPLY [expression]
```
this instruction makes a method run at the same time as its caller.
the method gives back the result, if there is one, to its caller, and then the method goes on to run.
the caller goes on with the clause after the call, and the method goes on too.
when a method in an activity runs this instruction, rexx makes a new activity.
the invocation of the method goes from the first activity to the new activity.
the two activities can run at the same time, so the caller and the method both go on to run.
the code:
```rexx
/* Example of early reply */

object1 = .example~new
object2 = .example~new

say object1~repeat(10, "Object 1 running")
say object2~repeat(10, "Object 2 running")
say "Main ended."
exit

::class example
::method repeat
use arg reps,msg
reply "Repeating" msg"," reps "times."
do reps
  say msg
end
```
the result:
```
Repeating Object 1 running, 10 times.
Object 1 running
Object 2 running
Repeating Object 2 running, 10 times.
Object 1 running
Object 2 running
Main ended.
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
```

```
receiver~start(messagename [,argument ...])
```
this method gives a message object.
a message object is between two objects, so they can run at the same time.
all objects inherit this method from the object class.
the first argument is the message that the message object sends to the receiver.
the message object sends the message to the receiver; the receiver runs it and gives the result to the message object.
the object that gets the message object goes on to run while the message object runs.
when the message object has the result, it does not stop the object that has it; it waits until that object sends it the result message.
the result method of the message object gives the result.
the code:
```rexx
/* Example of using a message object */

object1 = .example~new
object2 = .example~new

a = object1~start("REPEAT",10,"Object 1 running")
b = object2~start("REPEAT",10,"Object 2 running")

say a~result
say b~result
say "Main ended."
exit

::class example
::method repeat
use arg reps,msg
do reps
  say msg
end
return "Repeated" msg"," reps "times."
```
the result:
```
Object 1 running
Object 1 running
Object 1 running
Object 1 running
Object 1 running
Object 1 running
Object 1 running
Object 1 running
Object 1 running
Object 1 running
Repeated Object 1 running, 10 times.
Object 2 running
Object 2 running
Object 2 running
Object 2 running
Object 2 running
Object 2 running
Object 2 running
Object 2 running
Object 2 running
Object 2 running
Repeated Object 2 running, 10 times.
Main ended.
```

```
guarded
```
the methods of an object use expose to say its object variables; these are the variable pool of the object.
the methods of a class, and the variables they can use, are a scope.
the pool has one part for each scope in the classes the object inherits from.
only the methods of a scope can use the object variables of that scope, so a class and its subclass do not use the same names in error.
by default, only one method of a scope runs on an object at a time.
methods from other activities for that scope wait until the method that runs ends.
messages in one scope run one after the other.
lock: what an activity has so that other activities must wait to use a scope of an object
the reply instruction gives the lock of the method to the new activity, so the caller can go on.
a second method of the same scope must wait until the first method ends.
if the first activity has other methods that have the lock, the reply instruction can not give the lock; it must wait until it can.
then an other method of the same object can run while it waits.
methods of an other scope can run at the same time on the same object.
the code:
```rexx
/* Example of default concurrency for methods of different scopes */

object1 = .subexample~new

say object1~repeat(8, "Object 1 running call 1")   /* These calls run */
say object1~repeater(8, "Object 1 running call 2") /*   concurrently  */
say "Main ended."
exit

::class example
::method repeat
use arg reps,msg
reply "Repeating" msg"," reps "times."
do reps
  say msg
end

::class subexample subclass example
::method repeater
use arg reps,msg
reply "Repeating" msg"," reps "times."
do reps
  say msg
end

/* Example of methods with the same scope not running concurrently*/

object1 = .example~new

say object1~repeat(10,"Object 1 running call 1") /* These calls   */
say object1~repeat(10,"Object 1 running call 2") /* cannot run    */
say "Main ended."                                /* concurrently. */
exit

::class example
::method repeat
use arg reps,msg
reply "Repeating" msg"," reps "times."
do reps
  say msg
end
```
the result:
```
99.901
```

```
lock
```
when a message runs a method of an object, the activity gets the lock of the scope of that object.
other activities that send messages to the object and need that scope must wait until the first activity gives back the lock.
if a method on an activity sends an other message to the same object, the new method can run, as the activity has the lock.
so methods can call methods of the same object on one activity, and they do not wait for each other with no end.
rexx runs these messages as subroutine calls, not as concurrent methods.
a method can send a message to self, and the method of that message runs while the first method runs.
an object can send a message to an other object that sends a message back to the first object; on one activity, this does not wait with no end.
the code:
```rexx
/* Example of sending message to SELF */

object1 = .example~new
object2 = .example~new

say object1~repeater(10, "Object 1 running")
say object2~repeater(10, "Object 2 running")

say "Main ended."
exit

::class example
::method repeater
use arg reps,msg
reply "Entered repeater."
say self~repeat(reps,msg)
::method repeat
use arg reps,msg
do reps
  say msg
end
return "Repeated" msg"," reps "times."
```
the result:
```
Entered repeater.
Object 1 running
Object 2 running
Object 1 running
Entered repeater.
Object 2 running
Object 1 running
Main ended.
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Object 1 running
Object 2 running
Repeated Object 1 running, 10 times.
Repeated Object 2 running, 10 times.
```

```
methodname~SETUNGUARDED
::METHOD methodname UNGUARDED
```
setunguarded: the name of a method of the method class that makes a method unguarded
the setunguarded method of the method class and the unguarded option of the method directive say if a method needs the lock of the scope.
with them, a method can run while an other method of the same object runs.
use them only for methods that do not need the variable pool of the object only for them.
if you use them for other methods, concurrent methods can give results you do not want.
for a method that the new method of the method class makes, use the setunguarded method.

```
GUARD ON
GUARD OFF
```
you can not always use the setunguarded method or the unguarded option.
let: make a thing able to do a thing
lets: let, for one thing
a method can need its object variables only for it, then let methods on other activities run, then need its object variables only for it again.
with guard on and guard off, a method can change between the lock of its scope and the use of that scope by other activities.
by default, a method must wait until the method that runs now ends, before it starts.
guard off lets a method on an other activity that needs the same object variables run on the same object.

```
GUARD ON WHEN expression
```
concurrent methods must wait for each other, and data must not change by two methods on two activities at the same time.
a guarded method of this kind is a method with the unguarded option or setunguarded, and with a guard instruction.
the unguarded option and setunguarded always let a method run at the same time as other methods.
with a guard instruction, the method runs at the same time only when a condition is true.
the condition is the expression after guard on when.
if the expression is true, the method goes on to run.
if the expression is false, the method does not go on; it waits.
the guard instruction tests the expression again each time the value of an exposed object variable changes.
safe: a thing is safe when it can not make an error or a false result
the guard instruction can stop any method when it is not safe to go on.
the expression must be able to be true; if it can not be true, the method waits with no end.
this can be so when a second activity makes the expression false before guard on when tests it.
so run guard on when before the expression is made true.
the order of activities is not the order of calls, so the code must not need the activities in one order.
