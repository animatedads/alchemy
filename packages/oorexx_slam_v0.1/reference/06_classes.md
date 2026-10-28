# the classes of oorexx other than the string class

these facts are about the classes of oorexx other than the string class: each class, and each method of it.

## words i add

finds: find, for one thing
sets: set, for one thing
changed: a thing is changed when you change it
added: a thing is added when you add it
got: get, at a time before now
was: is, at a time before now
did: do, at a time before now
had: have, at a time before now
superclasses: more than one superclass
kinds: more than one kind
tries: try, for one thing
found: a thing is found when you find it
example: a part of code that uses a thing, so you can know how to use it
examples: more than one example

## the object class

```
.Object
```
this class is the first class: each other class is a subclass of it, or a subclass of a subclass of it.
each object can use the instance methods of this class.
the class method of this class is new.

```
.Object~new
```
this method is a class method.
this method gives a new instance of the receiver class.

```
.Object~=(argument)
.Object~==(argument)
.Object~\=(argument)
.Object~><(argument)
.Object~<>(argument)
.Object~\==(argument)
```
strict: a strict compare of two values is true only when the two values are the same in each part
these methods compare the receiver and the argument, and give true or false.
the second method in this list is the strict equal compare.
in the object class, the first two methods give true when the receiver and the argument are the same object.
in the object class, the other methods give true when the receiver and the argument are not the same object.
the other methods give the result that is not the result of the first method.
a subclass can change these methods; the string class compares the characters of the two strings.
hash: a value that a method gets from the data of an object; two objects that are equal by a strict compare have the same hash
a collection that finds an item by its index, as a table, uses the strict equal compare and the hash to compare indexes and items.
a class that changes the strict equal compare must also change the method that gives the hash.

```
.Object~""(argument)
.Object~||(argument)
.Object~" "(argument)
```
these methods give a new string: the string value of the receiver, then the argument.
the first two methods put no blank between the two parts.
the third method puts one blank between the two parts.
the language uses the first method for two values in an expression with no operator between them.

```
.Object~class
```
this method gives the class object that made the receiver.

```
.Object~copy
```
copy: a method that gives a new object with the same methods and data as the receiver; also, what this method gives
this method gives a copy of the receiver.
the copy has the same methods as the receiver.
the copy has object variables with the same values as the variables of the receiver.
this method does not copy the objects that the receiver has in it.
a copy of an array is a new array, but the items in it are the same objects.
the code:
```rexx
myarray=.array~of("N","S","E","W")
/* Copies array myarray to array directions */
directions=myarray~copy
```
the result:
```
```

```
.Object~defaultName
```
this method gives the default name of the receiver: a short string that says what the receiver is.
the way of the string is not the same for each kind of object.
you may not be able to make the object again from the string.
each object must be able to give a short string like this, also an object that has no string value.
the string says the class of the object, as an array or a directory.
the example of the method that sets the name of an object uses this method.

```
.Object~hashCode
```
this method gives a string value that is the hash of the receiver.
a table, a set, a directory, and other collections that find an item by its index use this hash to find items.
if the data that the strict equal compare uses does not change, the same object gives the same hash each time.
two objects that are equal by a strict compare must give the same hash.
two objects that are not equal do not have to give hash values that are not the same.
the hash may be a string of four characters, and each character may be any byte.

```
.Object~hasMethod(methodname)
```
this method gives true if the receiver has a method with the name in the argument, else false.
the name in the argument is changed to upper.
this method gives true also for a private method.
so when you send a message with that name, you can get error 97, the error for a method that is not known.

```
.Object~identityHash
```
this method gives a number that only the receiver has.
no other object has this number while the receiver is in memory.

```
.Object~instanceMethod(methodname)
```
this method gives the method object for the name in the argument, if the class has a method with that name.
else this method gives nil.

```
.Object~instanceMethods([class_object])
```
this method gives a supplier.
the argument is optional; it is a class object.
with no argument, the supplier gives all the object methods of the receiver and of its superclasses.
with no argument, an index can be in the supplier more than one time, when a class changes a method of its superclass.
with the argument, the supplier gives only the methods that the receiver has from that class.
if the receiver is not an instance of that class, the supplier is empty.
each index of the supplier is a method name, and each item is the method object.
the supplier gives the names and methods that are there when the supplier is made.
a name that is set to no method is in the supplier too, and its item is nil.
the code:
```rexx
-- if running under ooRexx 5.1.0
-- list all class methods of .String only
say .String~instanceMethods(.String)~allIndexes~sort~toString(,', ')
    -- outputs:  ALNUM, ALPHA, BLANK, CNTRL, CR, DIGIT, GRAPH, LOWER, NEW, NL, NULL,
    --           PRINT, PUNCT, SPACE, TAB, UPPER, XDIGIT

-- count all class methods of .String and its superclasses
say .String~instanceMethods~allIndexes~items
    -- outputs: 83
    --             (17 .String class methods, 33 .Object class methods,
    --              33 .Class class methods, i.e., without its NEW method)

-- count all instance methods of .String only
say ''~instanceMethods(.String)~allIndexes~items
    -- outputs: 117

-- count all instance methods of .String and its superclasses
say ''~instanceMethods~allIndexes~items
    -- outputs: 150
    --             (117 .String instance methods, 32 .Object instance methods,
    --              1 .Comparable instance method)
```
the result:
```
ALNUM, ALPHA, BLANK, CNTRL, CR, DIGIT, GRAPH, LOWER, NEW, NL, NULL, PRINT, PUNCT, SPACE, TAB, UPPER, XDIGIT
83
117
150
```

```
.Object~isA(class)
```
this method is the same as the next method here.

```
.Object~isInstanceOf(class)
```
this method gives true if the receiver is an instance of the class in the argument, else false.
the receiver is an instance of that class also when that class is a superclass or a mixin of the class of the receiver.
the code:
```rexx
say "abc"~isInstanceOf(.string)             -
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
say "abc"~isInstanceOf(.object)             -
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
say "abc"~isInstanceOf(.mutablebuffer)      -
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
.Object~isNil
```
this method gives true if the receiver is the nil object, else false.
the code:
```rexx
say .Object~isNil
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
say .nil~isNil
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
.Object~objectName
```
this method gives the name that the receiver got from the method that sets the name of an object.
if the receiver has no name, this method gives the default name of the receiver.

```
.Object~objectName=(newname)
```
this method sets the name of the receiver to the string in the argument.
the argument must be a string.
after this, the string method of the receiver gives the new name.
the default name of the receiver does not change.
the receiver is the same object after the change.
the code:
```rexx
points=.array~of("N","S","E","W")
say points~objectName         /* (no change yet) Says: "an Array"    */
points~objectName=("compass") /* Changes obj name POINTS to "compass"*/
say points~objectName         /* Shows new obj name. Says: "compass" */
say points~defaultName        /* Default is still available.         */
                              /* Says "an Array"                     */
say points                    /* Says string representation of       */
                              /* points "compass"                    */
say points[3]                 /* Says: "E"  Points is still an array */
                              /* of 4 items                          */
```
the result:
```
an Array
compass
an Array
N
S
E
W
E
```

```
.Object~request(classid)
```
request: a method that gets from an object an other object of a class you name
this method gives an object of the class whose name is the argument, or nil.
first, if the name of the class of the receiver is the same as the argument, this method gives the receiver.
if not, it sends the receiver a message whose name is make and then the argument, in upper.
if the receiver has no method with that name, this method gives nil.
with these make methods an object can give an other kind of object for its data.
a list can give an array in this way, but a list can not give a directory.
each make method must give an object of the class in its name.
the language uses the make method for a string to get the string value of an object in some parts of the code.
with the argument string, this method sends the make message for a string.
the code:
```rexx
request("string")
```
the result:
```
43.1
```

```
.Object~run(method [,"Individual" [,argument...]])
.Object~run(method, "Array", arguments)
```
this method runs a method.
the first argument is a method object, a string with one line of code, or an array of strings with one line of code in each.
for a string or an array, this method makes a method object from it.
the method can use the object variables of the receiver, the same as a method that is added to the receiver.
the second argument is an option.
only the first letter of the option is used.
with the option i, the other arguments go to the method in the same order.
with the option a, the third argument is an array, and its items are the arguments of the method.
the item at index 1 is the first argument of the method, the item at index 2 is the second argument, and so on.
if the array has no item at an index, that argument is omitted.
with no option, the method runs with no arguments.
this method is private.
you can call this method only from an instance method of the receiver, or from a class method of the class of the receiver or of its superclasses.

```
.Object~send(messagename [,argument...])
```
this method sends a message to the receiver and gives the result of the method that runs.
with this method, the message name can be a string that the program makes while it runs.
the first argument is a string or an array.
if the first argument is an array, its first item is the message name, and its second item is a class object.
the computer starts to find the method at that class.
the other arguments go to the method in the same order.
the code:
```rexx
world = .WorldObject~new
-- these calls are equivalent and produce "Hello World, I'm Fred!"
say world~hello("World", "Fred")
say world~send("HELLO", "World", "Fred")

::class WorldObject
::method hello
  use strict arg place, name
  return "Hello" place", I'm"  name"!"
```
the result:
```
Hello World, I'm Fred!
Hello World, I'm Fred!
```

```
.Object~sendWith(messagename, arguments)
```
dimension: one of the whole numbers in the index of an array item; an array with one dimension has one whole number in each index
dimensions: more than one dimension
this method sends a message to the receiver with the arguments in an array, and gives the result of the method that runs.
with this method, the message name and the arguments can be values that the program makes while it runs.
the first argument is a string or an array.
if the first argument is an array, its first item is the message name, and its second item is a class object.
the computer starts to find the method at that class.
the second argument must be an array with one dimension.
the items of the second argument go to the method as arguments, in the same order.
the code:
```rexx
world = .WorldObject~new
-- these calls are equivalent and produce "Hello World, I'm Fred!"
say world~hello("World", "Fred")
say world~sendWith("HELLO", .Array~of("World", "Fred"))

::class WorldObject
::method hello
  use strict arg place, name
  return "Hello" place", I'm"  name"!"
```
the result:
```
Hello World, I'm Fred!
Hello World, I'm Fred!
```

```
.Object~setMethod(methodname [,method [,scope]])
```
unknown: not known; also the name of a method that runs when an object gets a message and has no method with that name
float: a scope option; a method with this scope has the scope of the methods made outside of a class
this method adds a method to the object methods of the receiver.
the first argument is the name of the new method, and it is changed to upper.
if this method added a method with that name before, the new method takes its place.
if you omit the second argument, the receiver can not use that method name.
then a message with that name runs the unknown method, if there is one.
the second argument is a method object, a string with one line of code, or an array of strings with one line of code in each.
for a string or an array, this method makes a method object from it.
the third argument is optional; it says the scope of the method: object or float.
the default scope is float.
with the object scope, the method has the scope of the other methods of the object.
this method is private.
you can call this method only from an instance method of the receiver, or from a class method of the class of the receiver or of its superclasses.

```
.Object~start(messagename [,argument...])
```
this method makes a message object, sends it a start message, and gives back the message object.
the receiver runs the method, and the caller goes on to run at the same time: the two are concurrent.
the first argument is a string or an array.
if the first argument is an array, its first item is the message name, and its second item is a class object.
the computer starts to find the method at that class.
the other arguments go to the method in the same order.
when the method ends, the message object keeps the result until the caller sends it a result message.
the start method of the message class says more about this.
the code:
```rexx
world = .WorldObject~new
-- these calls are equivalent and produce "Hello World, I'm Fred!"
msg1 = world~start("HELLO", "World", "Fred")
msg2 = .message~new(world, "HELLO", "i", "World", "Fred")~~start
say msg1~result
say msg2~result

::class WorldObject
::method hello
  use strict arg place, name
  return "Hello" place", I'm"  name"!"
```
the result:
```
Hello World, I'm Fred!
Hello World, I'm Fred!
```

```
.Object~startWith(messagename, arguments)
```
this method makes a message object, sends it a start message, and gives back the message object.
the receiver runs the method, and the caller goes on to run at the same time: the two are concurrent.
the first argument is a string or an array.
if the first argument is an array, its first item is the message name, and its second item is a class object.
the computer starts to find the method at that class.
the second argument must be an array with one dimension.
the items of the second argument go to the method as arguments, in the same order.
when the method ends, the message object keeps the result until the caller sends it a result message.
the start method of the message class says more about this.
the code:
```rexx
world = .WorldObject~new
-- these calls are equivalent and produce "Hello World, I'm Fred!"
msg1 = world~startWith("HELLO", .Array~of("World", "Fred"))
msg2 = .message~new(world,"HELLO", "a", .Array~of("World", "Fred"))~~start
say msg1~result
say msg2~result

::class WorldObject
::method hello
  use strict arg place, name
  return "Hello" place", I'm"  name"!"
```
the result:
```
Hello World, I'm Fred!
Hello World, I'm Fred!
```

```
.Object~string
```
makestring: the name of the method that gives the string value of an object
this method gives a string that says what the receiver is.
the way of the string is not the same for each kind of object.
you may not be able to make the object again from the string.
each object must be able to give a string like this.
this method gets the string from the method that gives the name of the object, and that method can use the default name.
you can use this string in a trace, or to debug.
this method is not the same as the makestring method or the request method.
each object has a string method, but only an object with a string value has a makestring method.
the string method of a directory gives the string a directory, but a directory has no string value and no makestring method.
the array class, the string class, and some other classes have a makestring method.
a subclass of these classes inherits that method, so its objects have a string value too.
an other class can give its objects a string value with a makestring method in that class.

```
.Object~unsetMethod(methodname)
```
setmethod: the name of a private method that adds a method to an object
enhanced: the name of a class method that makes a new instance with more methods
this method takes away each method with the name in the argument that the setmethod method added to the receiver.
it also takes away a method with that name that the receiver got from the enhanced method when it was made.
if the receiver did not get a setmethod message, this method does not change the receiver.
this method is private.
you can call this method only from an instance method of the receiver, or from a class method of the class of the receiver or of its superclasses.

## the class class

```
.Class
```
this class is a metaclass: its instances are classes.
this class is a subclass of the object class.
the instance methods of this class are the class methods of each class.
you can not copy this class or an other class object: the copy method gives an error for them.

```
.Class~=(argument)
.Class~==(argument)
.Class~\=(argument)
.Class~><(argument)
.Class~<>(argument)
.Class~\==(argument)
```
these methods compare the receiver class and the argument, and give true or false.
the first two methods give true when the argument is the same class as the receiver.
the other methods give true when the argument is not the same class as the receiver.

```
.Class~activate
```
activate: a method that the language runs to end the steps that make a class
this method is the last step to make a class object from a class directive.
the language calls this method after it makes all the classes of a package, and before the first clause of the program runs.
the language calls this method for each class of the package, in the order in which it makes the classes.
when this method runs, the class object is whole and can make new instances.
all other classes of the package are there, but the activate method of each of them may not have run yet.
the init method of a class runs before the class is whole, so it can do less.
use this method, and not the init method, to give a class object its first values.

```
.Class~annotation(name)
```
annotation: a name with a value that a directive puts on a class, a method, or a routine
this method gives the value of the annotation of the class that has the name in the argument.
if the class has no annotation with that name, this method gives nil.

```
.Class~annotations
```
annotations: more than one annotation
this method gives a collection with all the annotations of the class.
each index of the collection is the name of an annotation, and each item is its value.
the collection is an instance of the class for a table of strings.

```
.Class~baseClass
```
base: the base class of a class that is not a mixin is that class; the base class of a mixin is its first superclass that is not a mixin
this method gives the base class of the receiver class.
if the receiver is a mixin, the base class is the first superclass of it that is not a mixin.
if the receiver is not a mixin, the base class is the receiver.

```
.Class~defaultName
```
id: the string that names a class
this method gives a short string that says what the class is.
the string is the word the, then the id of the class, then the word class.
the id is the name the class got when it was made.
the code:
```rexx
say .array~defaultName     /* Displays "The Array class"   */
say .account~defaultName   /* Displays "The ACCOUNT class" */
say .savings~defaultName   /* Displays "The Savings class" */

::class account            /* Name is all upper case       */
::class "Savings"          /* String name is mixed case    */
```
the result:
```
The Array class
The ACCOUNT class
The Savings class
```

```
.Class~define(methodname [,method])
```
define: a method that adds a method to the instance methods of a class
this method adds a method object to the instance methods of the receiver class.
the first argument is the name of the method, and it is changed to upper.
if the receiver class has a method with that name, the new method takes its place.
the second argument is a method object, a string with one line of code, or an array of strings with one line of code in each.
for a string or an array, this method makes a method object from it.
if you omit the second argument, the receiver class can not use that method name.
then a message with that name to an instance of the class runs the unknown method, if there is one.
you can not change or add methods of the classes that rexx gives.
the code:
```rexx
bank_account=.object~subclass("Account")
bank_account~define("TYPE",'return "a bank account"')
```
the result:
```
```

```
.Class~defineMethods(methods)
```
this method adds the methods in a collection to the instance methods of the receiver class.
the argument is a collection; each index is a method name.
each item is a method object, or a string or an array of strings with the code of the method.
the method names are changed to upper.
if the receiver class has a method with that name, the new method takes its place.
if the item for a name is nil, the receiver class can not use the method with that name.
the define method says more about this.
the code:
```rexx
before = .c~new
say before~a                           -- a-original

.c~defineMethods(.methods)
after = .c~new
say after~a after~b                    -- a-define b-define

::method a
return "a-define"
::method b
return "b-define"

::class c
::method a
return "a-original"
```
the result:
```
a-original
a-define b-define
```

```
.Class~delete(methodname)
```
delete: a method that takes away a thing
this method takes away the method of the receiver class with the name in the argument.
if the class used the define method so that it can not use that name, this method takes away that too.
if the class has no method with that name, this method does not change the class.
this method takes away only a method that is a part of the class; it can not take away a method that the class inherits from its superclasses.
you can not change or add methods of the classes that rexx gives.
the code:
```rexx
myclass=.object~subclass("Myclass")        /* After creating a class  */
myclass~define("TYPE",'return "my class"') /* and defining a method   */
myclass~delete("TYPE")                     /* this deletes the method */
```
the result:
```
```

```
.Class~enhanced(methods [,argument...])
```
this method gives a new instance of the receiver class.
the object methods of the new instance are the instance methods of the class, and the methods in the first argument.
the first argument is a collection; each index is the name of a method.
each item is a method object, or a string or an array of strings with the code of the method.
the first argument can be any collection that has a supplier method.
this method sends an init message to the new object, with the other arguments.
the define method says more about this.
the code:
```rexx
/* Set up rclass with class method or methods you want in your */
/* remote class */
rclassmeths = .directory~new

rclassmeths["DISPATCH"]=d_source     /* d_source must have code for a  */
                                     /* DISPATCH  method.              */
/* The following sends init("Remote Class") to a new instance */
rclass=.class~enhanced(rclassmeths,"Remote Class")
```
the result:
```
```

```
.Class~id
```
this method gives the id of the receiver class.
the id is the string you give to the subclass method, or to the method that makes a mixin.
the string of the class, and the string of each instance of it, has the id in it.
the code:
```rexx
myobject=.object~subclass("my object")  /* Creates a subclass    */
say myobject~id                         /* Produces: "my object" */
```
the result:
```
my object
```

```
.Class~inherit(classobj [,classpos])
```
this method makes the receiver class inherit the instance methods and the class methods of the first argument.
the first argument must be a mixin: a class made with the mixin option of the class directive, or with the method that makes a mixin.
the second argument is optional; it is a class in the list of superclasses of the receiver.
the new superclass goes after the second argument in that list.
if you omit the second argument, the new superclass goes at the end of the list.
if the second argument is not in the list of superclasses of the receiver, it is an error.
this method adds the first argument and its superclasses to the order in which the computer tries to find a method, if they are not there yet.
the receiver must not be a subclass of the first argument, and the first argument must not be a subclass of the receiver.
the base class of the first argument must be a superclass of the receiver.
the methods that the receiver inherits in this way are found before the methods of the base class of the first argument and of its superclasses, but not before the methods of other classes.
when the instance methods of the first argument change, each class that inherits from it gets the change.
the superclasses method gives the list of superclasses.
you can not change the classes that rexx gives with this method.
the code:
```rexx
room~inherit(.location)
```
the result:
```
97.1
```

```
.Class~isAbstract
```
abstract: an option of the class directive; it makes an abstract class
this method gives true if the receiver class is abstract, else false.
the code:
```rexx
say .abs ~ isAbstract
-- 1
::class abs abstract
```
the result:
```
1
```

```
.Class~isMetaclass
```
this method gives true if the receiver class is a metaclass, else false.
the class class is the only metaclass that rexx gives.
each subclass of the class class is a metaclass too.
the code:
```rexx
do class over .RexxInfo~package~classes~allItems~appendAll( -
  .context~package~classes~allItems                         -
  )
  if class~isMetaclass then
    say class~string": metaclass"      -- The Class class: metaclass
                                       -- The META class: metaclass
end

::class meta subclass class
::class other
```
the result:
```
The Class class: metaclass
The Singleton class: metaclass
The META class: metaclass
```

```
.Class~isSubclassOf(class)
```
this method gives true if the receiver class is a subclass of the class in the argument, else false.
the receiver is a subclass of the argument also when it is the same class as the argument.
the receiver is a subclass of the argument also when the argument is in the list of classes the receiver inherits from, also as a mixin.
the code:
```rexx
say .String~isSubclassOf(.object)             -
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
say .String~isSubclassOf(.mutablebuffer)      -
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
.Class~metaClass
```
this method gives the default metaclass of the receiver class.
the default metaclass is the class that makes a subclass of the receiver when the subclass message, or the message to make a mixin, has no metaclass argument.
the instance methods of the default metaclass are the class methods of the receiver class.

```
.Class~method(methodname)
```
this method gives the method object that the receiver class has for the name in the argument.
if the class used the define method so that it can not use that name, this method gives nil.
if the class has no method with that name, it is an error.
the code:
```rexx
/* Create and retrieve the method definition of a class */
myclass=.object~subclass("My class")   /* Create a class         */
mymethod=.method~new(" ","Say arg(1)") /* Create a method object */
myclass~define("ECHO",mymethod)        /* Define it in the class */
method_source = myclass~method("ECHO")~source     /* Extract it  */
say method_source                 /* Says "an Array"              */
say method_source[1]              /* Shows the method source code */
```
the result:
```
Say arg(1)
Say arg(1)
```

```
.Class~methods([class_object])
```
this method gives a supplier of the instance methods of the receiver class.
the argument is optional.
with no argument, the supplier gives the instance methods of the receiver class and of its superclasses.
with no argument, an index can be in the supplier more than one time, when a class changes a method of its superclass.
if the argument is nil, the supplier gives only the instance methods of the receiver class.
if the argument is a class, the supplier gives only the instance methods of that class.
each index of the supplier is a method name, and each item is the method object.
the supplier gives the names and methods that are there when the supplier is made.
a name that is set to no method by setmethod or by define is in the supplier too, and its item is nil.
the code:
```rexx
objsupp = .object~methods
do while objsupp~available
  say objsupp~index           -- displays all instance method
  objsupp~next                -- names of the Object class
end
```
the result:
```

COPY
SETMETHOD
STARTWITH
\=
ISNIL
STRING
==
INSTANCEMETHOD
CLASS
REQUEST
RUN
INIT
HASHCODE
 
||
SENDWITH
INSTANCEMETHODS
SEND
UNSETMETHOD
\==
ISINSTANCEOF
OBJECTNAME
OBJECTNAME=
><
DEFAULTNAME
START
IDENTITYHASH
<>
HASMETHOD
=
ISA
```

```
.Class~mixinClass(classid [,metaclass [,methods]])
```
this method makes a new mixin that is a subclass of the receiver class, and gives it back.
the first argument is a string, the id of the new class; the id method gives it.
the second argument is optional; it is a class object.
if you give the second argument, the new class is an instance of that metaclass.
if you omit the second argument, the new class is an instance of the default metaclass of the receiver.
for a subclass of the object class, the default metaclass is the class class.
the third argument is optional; it is a collection; each index is a method name.
each item of the third argument is a method object, or a string or an array of strings with the code of the method.
if you give the third argument, the new class gets these methods as class methods.
the third argument does not change the metaclass of the new class.
the order in which the computer tries to find a method of the new class is the same as for the receiver, with the new class at the start.
the code:
```rexx
buyable=.object~mixinClass("Buyable")  /* New subclass is buyable    */
                                       /* Superclass is Object class */
```
the result:
```
```

```
.Class~new([argument...])
```
this method gives a new instance of the receiver class.
the object methods of the new instance are the instance methods of the class.
this method runs the init methods of the new instance: it sends it an init message.
if you give arguments, this method sends them with the init message.
the code:
```rexx
/* new method example */
a = .account~new             /* --> Object variable balance=0           */
y = .account~new(340.78)     /* --> Object variable balance=340.78      */
                             /*    plus free toaster oven              */
::class account subclass object
::method init                /* Report time each account created       */
                             /* plus free toaster when more than $100  */
Expose balance
Arg opening_balance
Say "Creating" self~objectName "at time" time()
If datatype(opening_balance, "N") then balance = opening_balance
else balance = 0
If balance > 100 then Say "  You win a free toaster oven"
```
the result:
```
Creating an ACCOUNT at time 17:43:43
Creating an ACCOUNT at time 17:43:43
  You win a free toaster oven
```

```
.Class~package
```
this method gives the package object that has the code of the receiver class.
this package says the order in which the computer finds the classes and the routines that the class uses.
the code:
```rexx
say .Class~package~name                -- REXX
say .other~package~name                -- C:\ExampleClassPackage.rex

::class other
```
the result:
```
REXX
/tmp/claude-0/-home-claude/7a454f5a-2610-5341-b35a-ce8fb6712926/scratchpad/runall/slam_examples_2026102863809/run/example.rex
```

```
.Class~queryMixinClass
```
this method gives true if the receiver class is a mixin, else false.

```
.Class~subclass(classid [,metaclass [,methods]])
```
this method makes a new subclass of the receiver class, and gives it back.
you send this message to the class that is to be the superclass.
the first argument is a string, the id of the new class; the id method gives it.
the second argument is optional; it is a class object.
if you give the second argument, the new class is an instance of that metaclass.
if you omit the second argument, the new class is an instance of the default metaclass of the receiver.
for a subclass of the object class, the default metaclass is the class class.
the third argument is optional; it is a collection; each index is a method name.
each item of the third argument is a method object, or a string or an array of strings with the code of the method.
if you give the third argument, the new class gets these methods as class methods.
the third argument does not change the metaclass of the new class.
the order in which the computer tries to find a method of the new class is the same as for the receiver, with the new class at the start.
the code:
```rexx
room=.object~subclass("Room")   /* Superclass is .object     */
                                /* Subclass is room          */
                                /* Subclass identity is Room */
```
the result:
```
```

```
.Class~subclasses
```
this method gives an array with one dimension that has the subclasses of the receiver class.
the array has only the subclasses of the receiver, not the subclasses of these subclasses.
the items are in no order you can know; a program must not need an order of them.

```
.Class~superClass
```
this method gives the superclass of the receiver class: the class that got the subclass message, or the message to make a mixin.
for the object class, this method gives nil.
the code:
```rexx
say .object~superclass    -- displays "The NIL object"
say .class~superclass     -- displays "The Object class"
say .set~superclass       -- displays "The Table class"
```
the result:
```
The NIL object
The Object class
The Object class
```

```
.Class~superClasses
```
this method gives an array with one dimension that has the superclasses of the receiver class.
the array has the class that got the subclass message or the message to make a mixin, and each class that the inherit method added.
the classes are in the order in which the receiver inherits them.
the first item is the class that got the subclass message or the message to make a mixin.
the code:
```rexx
z=.class~superClasses
/* To obtain the information this returns, you could use:     */
do i over z
  say i
end
```
the result:
```
The Object class
```

```
.Class~uninherit(classobj)
```
uninherit: a method that takes away what an inherit message did
this method takes away what each inherit message for the class in the argument did to the receiver.
you can not change the classes that rexx gives with this method.
the code:
```rexx
location=.object~mixinClass("Location")
room=.object~subclass("Room")~~inherit(location) /* Creates subclass */
/* and specifies inheritance */
room~uninherit(location)
```
the result:
```
```

## the kinds of collection classes

```
collection classes
```
map: a kind of collection where each item has an index, and you find the item by its index
ordered: an ordered collection keeps its items in an order
these facts are about the kinds of collection classes, not about the order in which the classes inherit methods.
the collection class is the base of the collection classes.
there are three kinds of collection classes: the map collection, the ordered collection, and the set collection.
identitytable: the name of a map collection class
properties: the name of a map collection class
relation: the name of a map collection class
stringtable: the name of a map collection class
circularqueue: the name of an ordered collection class
bag: the name of a set collection class
the map collection classes are: directory, identitytable, properties, relation, stem, stringtable, and table.
the ordered collection classes are: array, circularqueue, list, and queue.
the set collection classes are: bag and set.

## the collection class

```
.Collection
```
this class is a mixin.
this class has the methods that all collections have.
many of its methods are abstract: each subclass must have a method with that name.

```
.Collection~[](index...)
```
this method is abstract: each subclass must have a method with this name.
this method gives the item of the collection at the index or indexes in the arguments.
if the collection has no item at that index, this method gives nil.

```
.Collection~[]=(item, index...)
```
this method is abstract: each subclass must have a method with this name.
this method adds an item to the collection at the index in the arguments.

```
.Collection~allIndexes
```
this method is abstract: each subclass must have a method with this name.
this method gives an array of all the indexes of the collection.

```
.Collection~allItems
```
this method is abstract: each subclass must have a method with this name.
this method gives an array of all the items of the collection.

```
.Collection~at(index...)
```
this method is abstract: each subclass must have a method with this name.
this method gives the item of the collection at the index or indexes in the arguments.
if the collection has no item at that index, this method gives nil.

```
.Collection~difference(argument)
```
makearray: the name of the method that gives the items of an object in an array
this method gives a new collection of the same class as the receiver.
the new collection has only the items of the receiver whose index is not an index of the argument.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

```
.Collection~disjoint(argument)
```
disjoint: two collections are disjoint when no item is in both of them
this method gives true if the receiver and the argument have no item that is the same, else false.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

```
.Collection~equivalent(argument)
```
equivalent: two collections are equivalent when each one has each index of the other
this method gives true if each index of the receiver is an index of the argument, and the two collections have the same count of items.
else this method gives false.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

```
.Collection~hasIndex(index...)
```
this method gives true if the collection has an item at the index or indexes in the arguments, else false.

```
.Collection~hasItem(item)
```
this method gives true if the collection has the item in the argument at any index, else false.

```
.Collection~index(item)
```
this method is abstract: each subclass must have a method with this name.
this method gives the index of the item in the argument.
if the item is in the collection more than one time, you can not know which index this method gives.

```
.Collection~intersection(argument)
```
intersection: the part that is in both of two collections
this method gives a new collection of the same class as the receiver.
the new collection has only the items of the receiver whose index is also an index of the argument.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

```
.Collection~items
```
this method gives the count of items in the collection.

```
.Collection~makeArray
```
this method gives an array with one dimension.
the array has the same count of items as the receiver.
an index with no item is not in the new array.
the items in the new array are in the same order as in the collection.

```
.Collection~put(item, index...)
```
this method is abstract: each subclass must have a method with this name.
this method adds an item to the collection at the index in the arguments.

```
.Collection~subset(argument)
```
subset: a collection is a subset of an other collection when each index of it is also an index of the other collection
this method gives true if each index of the receiver is also an index of the argument, else false.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

```
.Collection~supplier
```
this method gives a supplier for the collection.
with the supplier you can get each index and item of the collection.
the supplier gets the indexes and items when it is made.
a change to the collection after that does not change the supplier.

```
.Collection~union(argument)
```
union: all of two collections in one collection
this method gives a new collection of the same class as the receiver.
the new collection has all the items of the receiver.
it also has each item of the argument whose index is not an index of an item of the receiver, and is not an index of an item that this method added before.
you can not know the order in which this method takes the items of the argument; a program must not need that order.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

```
.Collection~xor(argument)
```
xor: the items of two collections, but not an item whose index is in both
this method gives a new collection of the same class as the receiver.
the new collection has all the items of the receiver and of the argument, but not the items whose index is in both collections.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

## the map collection class

```
.MapCollection
```
this class is a mixin.
this class has the methods of all the collections that keep each item with an index object.
these classes inherit this class: directory, identitytable, properties, relation, stem, stringtable, table, bag, and set.
this class inherits the methods of the collection class; they are the same as in that class.

```
.MapCollection~of(argument...)
```
this method is a class method.
this method makes a new map collection with the indexes and items in the arguments, and gives it back.
each argument must be an array with one dimension and with two items.
the first item of each argument is the index, and the second item is the value.
this method adds the arguments to the new collection from the first argument to the last.
with no arguments, this method gives an empty map collection.
the code:
```rexx
iso639 = .Directory~of(("de", "Deutsch"), ("en", "English"), ("fr", "fran&ccedil;ais"))
say iso639~allIndexes~toString(, ", ")  -- de, en, fr
say iso639~allItems~toString(, ", ")    -- Deutsch, English, fran&ccedil;ais
```
the result:
```
de, en, fr
Deutsch, English, fran&ccedil;ais
```

```
.MapCollection~makeArray
```
this method gives an array with one dimension that has the indexes of the receiver.
the indexes are in no order that you can know.

```
.MapCollection~putAll(collection)
```
this method adds all the items of the argument to the receiver, and gives back the receiver.
the argument can be any object that has a supplier method.
this method puts each item at the index that the supplier gives for it.
the indexes of the items of the argument must be strings.
this method adds the items in the order in which the supplier gives them.
if two items of the argument have the same index, the last item the supplier gives takes the place of the items before it.

## the ordered collection class

```
.OrderedCollection
```
this class is a mixin.
this class has the methods of all the collections whose indexes have an order.
these classes inherit this class: array, circularqueue, list, and queue.
this class inherits the methods of the collection class; they are the same as in that class, but this class changes the difference, intersection, subset, union, and xor methods.

```
.OrderedCollection~append(item)
```
append: add at the end
this method is abstract: each subclass must have a method with this name.
this method adds an item at the end of the order of the collection.

```
.OrderedCollection~appendAll(collection)
```
this method adds all the items of the argument at the end of the receiver, and gives back the receiver.
the argument can be any object that has the method that gives all of its items.

```
.OrderedCollection~delete(index)
```
this method is abstract: each subclass must have a method with this name.
this method takes away the item at the index in the argument, and gives back that item.
if there is no item at that index, this method gives nil and does not change the collection.
each item after the item it takes away gets a position one less in the order.
the collection has one item less.
in some kinds of collection, the indexes of these items change.

```
.OrderedCollection~difference(argument)
```
this method gives a new collection of the same class as the receiver.
the new collection has only the items of the receiver that are not items of the argument.
the argument is a collection, or an other object that has a makearray method.

```
.OrderedCollection~first
```
this method is abstract: each subclass must have a method with this name.
this method gives the index of the first item in the order of the collection.
if the collection is empty, this method gives nil.

```
.OrderedCollection~firstItem
```
this method is abstract: each subclass must have a method with this name.
this method gives the first item in the order of the collection.
if the collection is empty, this method gives nil.

```
.OrderedCollection~insert(item [,index])
```
insert: put a thing in the middle of other things, or at the start or at the end of them
this method is abstract: each subclass must have a method with this name.
this method adds an item to the collection, and gives the index that the collection gives to the item.
the second argument is optional; it is the index of an item in the collection.
the new item goes after the item at that index in the order.
if you omit the second argument, the new item is the last item of the collection.
if the second argument is nil, the new item is the first item of the collection.
each item after the new item gets a position one more in the order.
in some kinds of collection, the indexes of the items in the collection change.

```
.OrderedCollection~intersection(argument)
```
this method gives a new collection of the same class as the receiver.
the new collection has only the items that are in both the receiver and the argument.
the argument is a collection, or an other object that has a makearray method.

```
.OrderedCollection~last
```
this method is abstract: each subclass must have a method with this name.
this method gives the index of the last item in the order of the collection.
if the collection is empty, this method gives nil.

```
.OrderedCollection~lastItem
```
this method is abstract: each subclass must have a method with this name.
this method gives the last item in the order of the collection.
if the collection is empty, this method gives nil.

```
.OrderedCollection~next(index)
```
this method is abstract: each subclass must have a method with this name.
this method gives the index of the item after the item at the index in the argument.
if the item at that index is the last item, this method gives nil.

```
.OrderedCollection~previous(index)
```
previous: the one before
this method is abstract: each subclass must have a method with this name.
this method gives the index of the item before the item at the index in the argument.
if the item at that index is the first item, this method gives nil.

```
.OrderedCollection~section(start [,items])
```
section: a part of a collection, with items in the same order
this method is abstract: each subclass must have a method with this name.
this method gives a new collection of the same class as the receiver, with some items of the receiver.
the first item of the new collection is the item of the receiver at the index in the first argument.
the items after it are the items after that item in the receiver, in the same order.
the second argument is optional; it is a whole number, the count of items in the new collection.
if the receiver has less items after the start, the new collection has less items.
if you omit the second argument, the new collection has all the items after the start.
this method does not change the receiver.

```
.OrderedCollection~sort
```
sort: put items in order, from the less to the more
sorts: sort, for one thing
sorted: a thing is sorted when you sort it
comparable: the name of a class of objects that you can compare, to put them in order
stable: a sort is stable when items that are equal are in the same order after the sort as before it
this method sorts the items of the collection, from the less to the more.
the items must be comparable.
this sort may not be stable.
this method gives the sorted collection.
the part of these facts about how to sort an ordered collection says more.

```
.OrderedCollection~sortWith(comparator)
```
comparator: an object that compares two items, so that a sort can know the order of them
this method sorts the items of the collection, from the less to the more.
the argument is a comparator; it says the order of the items.
this sort may not be stable.
this method gives the sorted collection.

```
.OrderedCollection~stableSort
```
this method sorts the items of the collection, from the less to the more.
the items must be comparable.
this sort is stable.
this method gives the sorted collection.

```
.OrderedCollection~stableSortWith(comparator)
```
this method sorts the items of the collection, from the less to the more.
the argument is a comparator; it says the order of the items.
this sort is stable.
this method gives the sorted collection.

```
.OrderedCollection~subset(argument)
```
this method gives true if each item of the receiver is also an item of the argument, else false.
the argument is a collection, or an other object that has a makearray method.

```
.OrderedCollection~union(argument)
```
this method gives a new collection of the same class as the receiver.
the new collection has all the items of the receiver.
it also has each item of the argument that is not an item of the receiver, and that this method did not add before.
you can not know the order in which this method takes the items of the argument; a program must not need that order.
the argument is a collection, or an other object that has a makearray method.

```
.OrderedCollection~xor(argument)
```
this method gives a new collection of the same class as the receiver, and does not change the receiver.
the new collection has all the items of the receiver and of the argument, but not the items that are in both collections.
the argument is a collection, or an other object that has a makearray method.

## the array class

```
.Array
```
size: the count of items that a thing can have
sizes: more than one size
in this class, each index is one or more positive whole numbers.
an array may have no item at some indexes.
the count of whole numbers in each index is the count of dimensions of the array.
an item of an array can be any rexx object.
the size of an array can change.
the count of dimensions of an array can not change, but the size of each dimension can.
when you make an array, you can give its size or its count of dimensions, but you do not have to.
each method that takes an index can take the whole numbers as arguments, or one array of them.
a method that gives an index gives one number for an array with one dimension, and an array of numbers for an array with more dimensions.
this class inherits the methods of the collection class and of the ordered collection class.
the code:
```rexx
x = myarray[1,2,3]
index = .array~of(1,2,3)
x = myarray[index]
```
the result:
```
93.902
```

```
.Array~new([size...])
```
this method is a class method.
this method gives a new empty array.
the arguments are optional; with no arguments, the array is empty.
each argument is the size of one dimension; the array class uses the sizes only to get memory for the array at the start.
each argument must be a whole number that is not negative.
a size of 0 makes that dimension empty at the start.
you can also give the sizes as one array with one dimension.
the code:
```rexx
   a = .array~new()        -- create a new, empty array
   a = .array~new(3,3)     -- create a new 3x3 array
   sizes = .array~of(4,4,4)
   a = .array~new(sizes)   -- create new 4x4x4 array
```
the result:
```
```

```
.Array~of([item...])
```
this method is a class method.
this method gives a new array with one dimension that has the items in the arguments.
the first item has index 1, the second item has index 2, and so on.
if you omit an argument, the new array has no item at the index of that argument.
the code:
```rexx
a = .array~of("Fred", "Mike", "David")

do name over a
   say name  -- displays "Fred", "Mike", and "David"
end
```
the result:
```
Fred
Mike
David
```

```
.Array~[](index...)
```
this method gives the same result as the at method.
the index can also be one array of indexes.

```
.Array~[]=(item, index...)
```
this method is the same as the put method.
the index can also be one array of indexes.

```
.Array~allIndexes
```
this method gives an array of all the indexes of the array that have an item.
for an array with more than one dimension, each index in the result is an array of whole numbers.
the code:
```rexx
a = .array~of("Fred", "Mike", "David")

do name over a~allIndexes
   say name  -- displays "1", "2", and "3"
end

a~remove(2)  -- remove second item

do name over a~allIndexes
   say name  -- displays "1" and "3"
end
```
the result:
```
1
2
3
1
3
```

```
.Array~allItems
```
this method gives an array of all the items in the array.
the code:
```rexx
a = .array~of("Fred", "Mike", "David")

do name over a~allItems
   say name  -- displays "Fred", "Mike", and "David"
end

a~remove(2)  -- remove second item

do name over a~allItems
   say name  -- displays "Fred" and "David"
end
```
the result:
```
Fred
Mike
David
Fred
David
```

```
.Array~append(item)
```
this method adds the item at the end of the array, after the item with the last index.
this method gives the index of the new item.
you can use this method only with an array of one dimension.
the code:
```rexx
   a = .array~of("Mike", "Rick")
   a~append("Fred")  -- a = .array~of("Mike", "Rick", "Fred")
```
the result:
```
```

```
.Array~at(index...)
```
this method gives the item at the index or indexes in the arguments.
if the array has no item at that index, this method gives nil.
the index can also be one array of indexes.
the code:
```rexx
   a = .array~of("Mike", "Rick")
   say a~at(2)
```
the result:
```
Rick
```
the reference says:
```
Rick
```

```
.Array~delete(index)
```
this method takes away the item at the index in the argument, and gives back that item.
if there is no item at that index, this method gives nil and does not change the array.
each item after the item it takes away gets an index one less.
the size of the array is one less.
you can use this method only with an array of one dimension.
the index can also be an array with one index in it.
the code:
```rexx
   a = .array~of("Fred", "Mike", "Rick", "David")
   a~delete(2)  -- removes "Mike", resulting in the array
                -- ("Fred", "Rick", "David")
```
the result:
```
```

```
.Array~dimension([argument])
```
this method gives the last index of a dimension of the array.
the argument is optional; it is a positive whole number that says which dimension.
if you omit the argument, this method gives the count of dimensions of the array.
if the array has no count of dimensions yet, this method gives 0.
the code:
```rexx
a = .array~of(,"Mike", "Rick")
say a~dimension
say a~dimension(1)

a = .array~new~~put("Mike",1,1)~~put("Rick",1,2)
say a~dimension
say a~dimension(1)
say a~dimension(2)
```
the result:
```
1
3
2
1
2
```
the reference says:
```
1 (number of dimensions in the array)
3 (upper bound of dimension one)
2 (number of dimensions in the array)
1 (upper bound of dimension one)
2 (upper bound of dimension two)
```

```
.Array~dimensions
```
this method gives an array that has the size of each dimension of the array.
for an array with one dimension, the result is an array with one item: the size of that dimension.

```
.Array~empty
```
this method takes away all the items of the array, and gives back the array.
the code:
```rexx
a = .array~of("Mike", "Rick", "Fred", "Rick")
a~empty    -- a~items now returns "0"
```
the result:
```
```

```
.Array~fill(value)
```
fill: put a value at each place
this method puts the value in the argument at each index of the array, and gives back the array.
the code:
```rexx
a = .array~new(3,3)
a~fill(0)    -- initialize the matrix to all zeroes.
```
the result:
```
```

```
.Array~first
```
this method gives the index of the first item in the array.
if the array is empty, this method gives nil.
for an array with more than one dimension, the index is an array of whole numbers.
the code:
```rexx
a = .array~of("Mike", "Rick", "Fred", "Rick")
say a~first
a = .array~of(,"Mike", "Rick")
say a~first
```
the result:
```
1
2
```
the reference says:
```
1
2
```

```
.Array~firstItem
```
this method gives the first item in the array.
if the array is empty, this method gives nil.
the code:
```rexx
musketeers=.array~of("Porthos","Athos","Aramis")  /* Creates array MUSKETEERS      */
item=musketeers~firstItem                         /* Gives first item in array     */
                                                  /* (Assigns "Porthos" to item)   */
```
the result:
```
```

```
.Array~hasIndex(index...)
```
this method gives true if the array has an item at the index or indexes in the arguments, else false.
the index can also be one array of indexes.
the code:
```rexx
a = .array~of("Mike", "Rick", "Fred", "Rick")
say a~hasIndex(2)
say a~hasIndex(5)
```
the result:
```
1
0
```
the reference says:
```
1
0
```

```
.Array~hasItem(item)
```
this method gives true if the array has the item in the argument at any index, else false.
to compare items, this method uses the strict equal compare of the item.
the code:
```rexx
a = .array~of("Mike", "Rick", "Fred", "Rick")
say a~hasItem("Rick")
say a~hasItem("Mark")
```
the result:
```
1
0
```
the reference says:
```
1
0
```

```
.Array~index(item)
```
this method gives the index of the item in the argument.
if the item is at more than one index, this method gives the first index where it finds the item.
for an array with more than one dimension, the index is an array of whole numbers.
if the array does not have the item, this method gives nil.
to compare items, this method uses the strict equal compare of the item.
the code:
```rexx
a = .array~of("Mike", "Rick", "Fred", "Rick")
say a~index("Rick")
```
the result:
```
2
```
the reference says:
```
2
```

```
.Array~insert(item [,index])
```
this method adds an item to the array, and gives the index of the new item.
the new item goes after the item at the index in the second argument.
the second argument is optional.
if the second argument is nil, the new item is the first item of the array.
if you omit the second argument, the new item is the last item of the array.
each item after the new item gets an index one more.
the code:
```rexx
musketeers=.Array~of("Porthos","Athos","Aramis") /* Creates Array MUSKETEERS        */
                                                 /* consisting of: Porthos         */
                                                 /*                Athos           */
                                                 /*                Aramis          */
musketeers~insert("D'Artagnan",1)    /* Adds D'Artagnan after Porthos  */
                                          /* Array is now: Porthos           */
                                          /*              D'Artagnan   */
                                          /*              Athos             */
                                          /*              Aramis            */
/* Alternately, you could use */
musketeers~insert("D'Artagnan",.nil) /* Adds D'Artagnan before Porthos */
                                          /* Array is now:  D'Artagnan  */
                                          /*               Porthos          */
                                          /*               Athos            */
                                          /*               Aramis           */
/* Alternately, you could use */
musketeers~insert("D'Artagnan")      /* Adds D'Artagnan after Aramis   */
                                          /* Array is now:  Porthos          */
                                          /*               Athos            */
                                          /*               Aramis           */
                                          /*               D'Artagnan  */
```
the result:
```
```

```
.Array~isEmpty
```
this method gives true if the array is empty, else false.
the code:
```rexx
a = .array~new
say a~isEmpty
a[1] = "1"
say a~isEmpty
```
the result:
```
1
0
```
the reference says:
```
1
0
```

```
.Array~items
```
this method gives the count of items in the array.
the code:
```rexx
a = .array~of("Fred", , "Mike", , "David")
say a~items
```
the result:
```
3
```
the reference says:
```
3
```

```
.Array~last
```
this method gives the index of the last item in the array.
if the array is empty, this method gives nil.
for an array with more than one dimension, the index is an array of whole numbers.
the code:
```rexx
a = .array~of("Fred", , "Mike", , "David")
say a~last
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
.Array~lastItem
```
this method gives the last item in the array.
if the array is empty, this method gives nil.
the code:
```rexx
musketeers=.array~of("Porthos","Athos","Aramis")  /* Creates array MUSKETEERS      */
item=musketeers~lastItem                          /* Gives last item in array      */
                                                  /* (Assigns "Aramis" to item)    */
```
the result:
```
```

```
.Array~makeArray
```
this method gives an array with one dimension.
the new array has the same count of items as the receiver.
an index with no item is not in the new array.
the items in the new array are in the same order as in the receiver.
an array with more than one dimension is changed to an array with one dimension and with an item at each index.
the code:
```rexx
a = .array~of("Fred", , "Mike", , "David")
b = a~makeArray  -- b = .array~of("Fred", "Mike", "David")
```
the result:
```
```

```
.Array~makeString([option] [,separator])
```
separator: a string that you put between two parts
this method gives a string with the data of the array.
the array can have one or more dimensions.
this method starts at the first item of the array.
this method puts the items in the string in the line way or in the character way.
the default is the line way.
in the line way, you can give a separator; it goes between each two items, in place of the end of a line.
this method is the same as the last method of this class.

```
.Array~next(index)
```
this method gives the index of the item after the item at the index in the argument.
if the item at that index is the last item, this method gives nil.
for an array with more than one dimension, this method uses the same order as the method that gives all the items, and the index is an array of whole numbers.
the index can also be one array of indexes.
the code:
```rexx
a = .array~of("Fred", , "Mike", , "David")
say a~next(3)
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
.Array~previous(index)
```
this method gives the index of the item before the item at the index in the argument.
if the item at that index is the first item, this method gives nil.
for an array with more than one dimension, this method uses the same order as the method that gives all the items, and the index is an array of whole numbers.
the index can also be one array of indexes.
the code:
```rexx
a = .array~of("Fred", , "Mike", , "David")
say a~previous(3)
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
.Array~put(item, index...)
```
this method puts the item in the array at the index or indexes in the arguments.
if there is an item at that index, the new item takes its place.
if the index for a dimension is more than the size of that dimension, the array gets more size.
the index can also be one array of indexes.
the code:
```rexx
a = .array~new
a~put("Fred", 1) -- a = .array~of("Fred")
a~put("Mike", 2) -- a = .array~of("Fred", "Mike")
a~put("Mike", 1) -- a = .array~of("Mike", "Mike")

do name over a
  say name
end
```
the result:
```
Mike
Mike
```
the reference says:
```
Mike
Mike
```

```
.Array~remove(index...)
```
remove: take a thing away from a collection, and give it back
this method takes away the item at the index or indexes in the arguments, and gives back that item.
if there is no item at that index, this method gives nil and does not change the array.
after this, the array has no item at that index: the method that tests for an index gives false for it.
the size of the array does not change.
the indexes of the other items do not change.
the index can also be one array of indexes.
the code:
```rexx
a = .array~of("Fred", "Mike", "Mike", "David")
a~remove(2)  -- removes "Mike"
```
the result:
```
```

```
.Array~removeItem(item)
```
this method takes away the item in the argument from the array, and gives back that item.
if the item is at more than one index, this method takes away only the first one it finds.
to compare items, this method uses the strict equal compare of the item.
the code:
```rexx
a = .array~of("Fred", "Mike", "Mike", "David")
a~removeItem("Mike")  -- removes the item at index "2"
```
the result:
```
```

```
.Array~section(start [,items])
```
this method gives a new array of the same class as the receiver, with some items of the receiver.
the first item of the new array is the item of the receiver at the index in the first argument.
the items after it are the items after that item in the receiver, in the same order.
the first argument can also be an array of indexes.
the second argument is optional; it is a whole number, the count of items in the new array.
if the receiver has less items after the start, the new array has less items.
if you omit the second argument, the new array has all the items after the start.
this method does not change the receiver.
you can use this method only with an array of one dimension.
the code:
```rexx
a = .array~of(1,2,3,4)  -- Loads the array

b = a~section(2)   -- b = .array~of(2,3,4)
c = a~section(2,2) -- c = .array~of(2,3)
d = a~section(2,0) -- d = .array~new
```
the result:
```
```

```
.Array~size
```
this method gives the count of items the array can have before it must get more size.
this count is the size of the first dimension, times the size of the second dimension, and so on.

```
.Array~sort
```
this method sorts the items of the array, from the less to the more.
the items must be comparable.
this sort may not be stable.
this method gives the sorted array.

```
.Array~sortWith(comparator)
```
this method sorts the items of the array, from the less to the more.
the argument is a comparator; it says the order of the items.
this sort may not be stable.
this method gives the sorted array.

```
.Array~stableSort
```
this method sorts the items of the array, from the less to the more.
the items must be comparable.
this sort is stable.
this method gives the sorted array.

```
.Array~stableSortWith(comparator)
```
this method sorts the items of the array, from the less to the more.
the argument is a comparator; it says the order of the items.
this sort is stable.
this method gives the sorted array.

```
.Array~supplier
```
this method gives a supplier for the array.
with the supplier you can get each index and item of the array.
the supplier gives the items in the order of the array.
for an array with more than one dimension, the index method of the supplier gives each index as an array of whole numbers.
the supplier has the items that the array has when the supplier is made.
the code:
```rexx
a = .array~of("Fred", "Mike", "David")
sup = a~supplier
a~append("Joe")
do while sup~available
   say sup~item  -- displays "Fred", "Mike", and "David"
   sup~next
end
```
the result:
```
Fred
Mike
David
```

```
.Array~toString([option] [,separator])
```
this method gives a string with the data of the array.
the array can have one or more dimensions.
this method starts at the first item of the array.
this method puts the items in the string in the line way or in the character way.
the first argument is optional; it is the option.
the default is the line way: the end of a line goes between each two items.
in the character way, the items are next to each other, with no thing between them.
the second argument is optional; it is a separator for the line way; it goes between each two items, in place of the end of a line.
this method is the same as the makestring method of the array class.
the code:
```rexx
a = .array~of(1,2,3,4)  -- Loads the array

say a~toString  -- Produces: 1
                --           2
                --           3
                --           4

say a~toString("c")  -- Produces: 1234

say a~toString(, ", ")  -- Produces: 1, 2, 3, 4
```
the result:
```
1
2
3
4
1234
1, 2, 3, 4
```

## the list class

```
.List
```
a list is a collection in order, like an array, but you can add a new item at any position in the order.
a list has no index without an item.
the list makes a new index each time you add an item.
that index is the index of the item while the item is in the list, also when you add or take away other items.
only the indexes that the list makes are indexes of the list.
the list does not change the index of an item it has.
this class inherits the methods of the collection class and of the ordered collection class.

```
.List~new([size])
```
this method is a class method.
this method gives a new empty list.
the argument is optional; it says how many items the list may get, so the list can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.List~of(item...)
```
this method is a class method.
this method gives a new list with the items in the arguments, in the same order.

```
.List~[](index)
```
this method gives the item at the index in the argument.
this method is the same as the at method.

```
.List~[]=(item, index)
```
this method puts the item in the place of the item at the index.
this method is the same as the put method.

```
.List~allIndexes
```
this method gives an array of all the indexes of the list, in the order of the list.

```
.List~allItems
```
this method gives an array of all the items of the list, in the order of the list.

```
.List~append(item)
```
this method adds the item at the end of the list.
this method gives the index of the new item.

```
.List~at(index)
```
this method gives the item at the index in the argument.
if the list has no item at that index, this method gives nil.

```
.List~delete(index)
```
this method takes away the item at the index in the argument, and gives back that item.
if there is no item at that index, this method gives nil and does not change the list.
each item after the item it takes away gets a position one less in the order of the list.
the indexes of these items do not change.
the list has one item less.
for a list, this method and the remove method give the same result.

```
.List~empty
```
this method takes away all the items of the list, and gives back the list.

```
.List~first
```
this method gives the index of the first item in the list.
if the list is empty, this method gives nil.

```
.List~firstItem
```
this method gives the first item in the list.
if the list is empty, this method gives nil.
the code:
```rexx
musketeers=.list~of("Porthos","Athos","Aramis") /* Creates list MUSKETEERS      */
item=musketeers~firstItem                       /* Gives first item in list     */
                                                /* (Assigns "Porthos" to item)  */
```
the result:
```
```

```
.List~hasIndex(index)
```
this method gives true if the list has an item at the index in the argument, else false.

```
.List~hasItem(item)
```
this method gives true if the list has the item in the argument at any index, else false.
to compare items, this method uses the strict equal compare of the item.

```
.List~index(item)
```
this method gives the index of the item in the argument.
if the item is at more than one index, this method gives the first index where it finds the item.
if the list does not have the item, this method gives nil.
to compare items, this method uses the strict equal compare of the item.

```
.List~insert(item [,index])
```
this method adds an item to the list, and gives the index that the list makes for the new item.
the new item goes after the item at the index in the second argument.
the second argument is optional.
if the second argument is nil, the new item is the first item of the list.
if you omit the second argument, the new item is the last item of the list.
each item after the new item gets a position one more in the order of the list.
this method does not change the index of any item in the list.
the code:
```rexx
musketeers=.list~of("Porthos","Athos","Aramis") /* Creates list MUSKETEERS        */
                                                /* consisting of: Porthos         */
                                                /*                Athos           */
                                                /*                Aramis          */
index=musketeers~first                    /* Gives index of first item      */
musketeers~insert("D'Artagnan",index) /* Adds D'Artagnan after Porthos  */
                                          /* List is now: Porthos           */
                                          /*              D'Artagnan   */
                                          /*              Athos             */
                                          /*              Aramis            */
/* Alternately, you could use */
musketeers~insert("D'Artagnan",.nil) /* Adds D'Artagnan before Porthos */
                                          /* List is now:  D'Artagnan  */
                                          /*               Porthos          */
                                          /*               Athos            */
                                          /*               Aramis           */
/* Alternately, you could use */
musketeers~insert("D'Artagnan")      /* Adds D'Artagnan after Aramis   */
                                          /* List is now:  Porthos          */
                                          /*               Athos            */
                                          /*               Aramis           */
                                          /*               D'Artagnan  */
```
the result:
```
```

```
.List~isEmpty
```
this method gives true if the list is empty, else false.

```
.List~items
```
this method gives the count of items in the list.

```
.List~last
```
this method gives the index of the last item in the list.
if the list is empty, this method gives nil.

```
.List~lastItem
```
this method gives the last item in the list.
if the list is empty, this method gives nil.

```
.List~makeArray
```
this method gives an array with one dimension that has the items of the list.
the indexes of the array are from 1 to the count of items.
the items are in the same order as in the list.

```
.List~next(index)
```
this method gives the index of the item after the item at the index in the argument.
if the item at that index is at the end of the list, this method gives nil.

```
.List~previous(index)
```
this method gives the index of the item before the item at the index in the argument.
if the item at that index is at the start of the list, this method gives nil.

```
.List~put(item, index)
```
this method puts the item in the place of the item at the index in the second argument.
if the list does not have that index, it is an error.

```
.List~remove(index)
```
this method takes away the item at the index in the argument, and gives back that item.
if there is no item at that index, this method gives nil and does not change the list.
each item after the item it takes away gets a position one less in the order of the list.
the indexes of these items do not change.

```
.List~removeItem(item)
```
this method takes away the item in the argument from the list, and gives back that item.
if the item is at more than one index, this method takes away only the first one it finds.
to compare items, this method uses the strict equal compare of the item.

```
.List~section(start [,items])
```
this method gives a new list of the same class as the receiver, with some items of the receiver.
the first item of the new list is the item of the receiver at the index in the first argument.
the items after it are the items after that item in the receiver, in the same order.
the second argument is optional; it is a whole number, the count of items in the new list.
if the receiver has less items after the start, the new list has less items.
if you omit the second argument, the new list has all the items after the start.
this method does not change the receiver.

```
.List~supplier
```
this method gives a supplier for the list.
with the supplier you can get each index and item of the list.
the supplier has the indexes and items that the list has when the supplier is made.
the supplier gives them in the order of the list.

## the queue class

```
.Queue
```
a queue is a collection in order, with whole numbers as indexes, and with no index without an item.
an index says the position of an item from the start of the queue: the first item has index 1.
when you add or take away an item, the item at an index can change.
you can add an item at the end or at the start of the queue.
this class inherits the methods of the collection class and of the ordered collection class.

```
.Queue~new([size])
```
this method is a class method.
this method gives a new empty queue.
the argument is optional; it says how many items the queue may get, so the queue can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.Queue~of(item...)
```
this method is a class method.
this method gives a new queue with the items in the arguments, in the same order.

```
.Queue~[](index)
```
this method gives the item at the index in the argument.
this method is the same as the at method.

```
.Queue~[]=(item, index)
```
this method puts the item in the place of the item at the index.
this method is the same as the put method.

```
.Queue~allIndexes
```
this method gives an array of all the indexes of the queue.
for a queue, the indexes are the whole numbers from 1 to the count of items.

```
.Queue~allItems
```
this method gives an array of all the items of the queue, in the order of the queue.

```
.Queue~append(item)
```
this method adds the item at the end of the queue.
this method gives the index of the new item.

```
.Queue~at(index)
```
this method gives the item at the index in the argument.
if the queue has no item at that index, this method gives nil.

```
.Queue~delete(index)
```
this method takes away the item at the index in the argument, and gives back that item.
if there is no item at that index, this method gives nil and does not change the queue.
each item after the item it takes away gets a position one less in the order of the queue.
the indexes of these items change too.
the queue has one item less.
for a queue, this method and the remove method give the same result.
the code:
```rexx
   a = .queue~of("Fred", "Mike", "Rick", "David")
   a~delete(2)  -- removes "Mike", resulting in the queue
                -- ("Fred", "Rick", "David")
```
the result:
```
```

```
.Queue~empty
```
this method takes away all the items of the queue, and gives back the queue.

```
.Queue~first
```
this method gives the index of the first item in the queue.
if the queue is empty, this method gives nil.
if the queue is not empty, this index is always 1.

```
.Queue~firstItem
```
this method gives the first item in the queue.
if the queue is empty, this method gives nil.

```
.Queue~hasIndex(index)
```
this method gives true if the queue has an item at the index in the argument, else false.

```
.Queue~hasItem(item)
```
this method gives true if the queue has the item in the argument at any index, else false.
to compare items, this method uses the strict equal compare of the item.

```
.Queue~index(item)
```
this method gives the index of the item in the argument.
if the item is at more than one index, this method gives the first index where it finds the item.
if the queue does not have the item, this method gives nil.
to compare items, this method uses the strict equal compare of the item.

```
.Queue~insert(item [,index])
```
this method adds an item to the queue, and gives the index that the queue gives to the new item.
the new item goes after the item at the index in the second argument.
the second argument is optional.
if the second argument is nil, the new item is the first item of the queue.
if you omit the second argument, the new item is the last item of the queue.
the indexes of the items after the new item change; the queue makes these changes.
the code:
```rexx
musketeers=.queue~of("Porthos","Athos","Aramis") /* Creates queue MUSKETEERS       */
                                                 /* consisting of: Porthos         */
                                                 /*                Athos           */
                                                 /*                Aramis          */
index=musketeers~first                     /* Gives index of first item      */
musketeers~insert("D'Artagnan",index)      /* Adds D'Artagnan after Porthos  */
                                           /* List is now: Porthos           */
                                           /*              D'Artagnan        */
                                           /*              Athos             */
                                           /*              Aramis            */
/* Alternately, you could use */
musketeers~insert("D'Artagnan",.nil)       /* Adds D'Artagnan before Porthos */
                                           /* List is now:  D'Artagnan       */
                                           /*               Porthos          */
                                           /*               Athos            */
                                           /*               Aramis           */
/* Alternately, you could use */
musketeers~insert("D'Artagnan")            /* Adds D'Artagnan after Aramis   */
                                           /* List is now:  Porthos          */
                                           /*               Athos            */
                                           /*               Aramis           */
                                           /*               D'Artagnan       */
```
the result:
```
```

```
.Queue~isEmpty
```
this method gives true if the queue is empty, else false.

```
.Queue~items
```
this method gives the count of items in the queue.
the size method is the same as this method.

```
.Queue~last
```
this method gives the index of the last item in the queue.
if the queue is empty, this method gives nil.

```
.Queue~lastItem
```
this method gives the last item in the queue.
if the queue is empty, this method gives nil.

```
.Queue~makeArray
```
this method gives an array with one dimension that has the items of the queue.
the indexes of the array are from 1 to the count of items.
the items are in the same order as in the queue: the first item of the queue is at index 1.

```
.Queue~next(index)
```
this method gives the index of the item after the item at the index in the argument.
if the item at that index is the last item, this method gives nil.

```
.Queue~peek
```
peek: get the first item of a queue, and do not take it away
this method gives the item at the start of the queue.
if the queue is empty, this method gives nil.
this method does not change the queue.

```
.Queue~previous(index)
```
this method gives the index of the item before the item at the index in the argument.
if the item at that index is the first item, this method gives nil.

```
.Queue~pull
```
pull: take away the first item of a queue, and give it back
this method takes away the item at the start of the queue, and gives back that item.
if the queue is empty, this method gives nil.

```
.Queue~push(item)
```
push: add an item at the start of a queue
this method adds the item at the start of the queue.

```
.Queue~put(item, index)
```
this method puts the item in the place of the item at the index in the second argument.
if the queue does not have that index, it is an error.

```
.Queue~queue(item)
```
this method adds the item at the end of the queue.

```
.Queue~remove(index)
```
this method takes away the item at the index in the argument, and gives back that item.
if there is no item at that index, this method gives nil.

```
.Queue~removeItem(item)
```
this method takes away the item in the argument from the queue, and gives back that item.
if the item is at more than one index, this method takes away only the first one it finds.
to compare items, this method uses the strict equal compare of the item.

```
.Queue~section(start [,items])
```
this method gives a new queue of the same class as the receiver, with some items of the receiver.
the first item of the new queue is the item of the receiver at the index in the first argument.
the items after it are the items after that item in the receiver, in the same order.
the second argument is optional; it is a whole number, the count of items in the new queue.
if the receiver has less items after the start, the new queue has less items.
if you omit the second argument, the new queue has all the items after the start.
this method does not change the receiver.

```
.Queue~size
```
this method gives the count of items in the queue.
this method is the same as the items method.

```
.Queue~supplier
```
this method gives a supplier for the queue.
with the supplier you can get each index and item of the queue.
the supplier has the indexes and items that the queue has when the supplier is made.
the supplier gives them in the order of the queue, from the start of the queue.

## the directory class

```
.Directory
```
a directory is a map collection where each index is a string, and no two items have the same index.
an item of a directory can be any rexx object.
a stringtable is a map collection like a directory, but it has no setmethod method and no method to take away what setmethod did.
you can use the name of an index as a method name to put an item in a directory or to get it.
this class inherits the methods of the collection class and of the map collection class.
the code:
```rexx
mydir = .directory~new
mydir~name = "Mike"   -- same as mydir~put("Mike", "NAME")
say mydir~name        -- same as say mydir['NAME']
```
the result:
```
Mike
```

```
.Directory~new([size])
```
this method is a class method.
this method gives a new empty directory.
the argument is optional; it says how many items the directory may get, so the directory can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.Directory~[](name)
```
this method gives the item at the index in the argument.
this method is the same as the at method.

```
.Directory~[]=(item, name)
```
this method adds the item at the index in the second argument, or puts it in the place of the item there.
this method is the same as the put method.

```
.Directory~allIndexes
```
this method gives an array of all the indexes of the directory.
the array also has the names that the setmethod method set.

```
.Directory~allItems
```
this method gives an array of all the items of the directory.
the array also has the items that the methods that setmethod set give.

```
.Directory~at(name)
```
this method gives the item at the index in the argument.
if the setmethod method set a method for that index, this method runs that method and gives its result.
if the directory has no item and no method for that index, this method gives nil.
the code:
```rexx
say .environment~at("OBJECT")   /* Produces: "The Object class" */
```
the result:
```
The Object class
```

```
.Directory~empty
```
this method takes away all the items of the directory, and gives back the directory.
it also takes away all the methods that the setmethod method added.

```
.Directory~entry(name)
```
entry: an index of a directory with its item
this method gives the entry of the directory for the name in the argument.
the name is changed to upper.
if there is no entry, this method gives the item that the setmethod method gives for the name.
if there is no entry and no method for the name, this method gives nil.

```
.Directory~hasEntry(name)
```
the name in the argument is changed to upper.
this method gives true if the directory has an entry or a method for the name, else false.

```
.Directory~hasIndex(name)
```
this method gives true if the directory has an item at the index in the argument, else false.

```
.Directory~hasItem(item)
```
this method gives true if the directory has the item in the argument at any index, else false.
to compare items, this method uses the strict equal compare of the item.

```
.Directory~index(item)
```
this method gives the index of the item in the argument.
if the item is at more than one index, this method gives the first index where it finds the item.
if the directory does not have the item, this method gives nil.
to compare items, this method uses the strict equal compare of the item.

```
.Directory~isEmpty
```
this method gives true if the directory is empty, else false.

```
.Directory~items
```
this method gives the count of items in the collection.

```
.Directory~makeArray
```
this method gives an array with one dimension that has the indexes of the directory.
the indexes of the array are from 1 to the count of items.
the items are in no order that you can know; a program must not need an order of them.

```
.Directory~put(item, name)
```
this method puts the item in the directory at the index in the second argument.
if there is an item or a method at that index, the new item takes its place.

```
.Directory~remove(name)
```
this method takes away the item at the index in the argument, and gives back that item.
if the setmethod method set a method for that index, this method takes away the method and gives the result of the method.
if there is no item and no method for that index, this method gives nil.

```
.Directory~removeEntry(name)
```
this method takes away the entry for the name in the argument, and gives back its item.
the name is changed to upper.
if the setmethod method set a method for that name, this method takes away the method and gives the result of the method.
if there is no item and no method for that name, this method gives nil.

```
.Directory~removeItem(item)
```
this method takes away the item in the argument from the directory, and gives back that item.
if the item is at more than one index, this method takes away only the first one it finds.
to compare items, this method uses the strict equal compare of the item.

```
.Directory~setEntry(name [,entry])
```
this method sets the entry for the name in the first argument to the object in the second argument.
the name is changed to upper.
the new entry takes the place of any entry or method with the same name.
the second argument is optional.
if you omit the second argument, this method takes away any entry or method with that name.

```
.Directory~setMethod(name [,method])
```
this method sets a method for the name in the first argument.
the name is changed to upper.
after this, when you get that entry with the at, entry, or remove method, or with the method that is the same as at, you get the result of the method.
the new method takes the place of any item or method with the same name.
the second argument is a method object, a string with one line of code, or an array of strings with one line of code in each.
for a string or an array, this method makes a method object from it.
the second argument is optional; if you omit it, this method takes away the entry with that name.
the name can be unknown: then the method runs when an at or entry message has an index with no item and no method.
the first argument of that unknown method is the index.
that unknown method does not change the result of the items, remove, and supplier methods, or of the methods that test for an entry or an index.

```
.Directory~supplier
```
this method gives a supplier for the directory.
with the supplier you can get each index and item of the directory.
the supplier has the indexes and items that the directory has when the supplier is made.
the supplier gives them in no order that you can know.

```
.Directory~unknown(messagename, messageargs)
```
setentry: the name of a method of a directory that sets an entry
this method runs the entry method or the setentry method.
if the message name does not end with the equal mark, this method runs the entry method with the message name as the argument.
then this method does not use the second argument, and it gives the result of the entry method.
if the message name ends with the equal mark, this method runs the setentry method.
then the first argument of setentry is the message name without the last equal mark, and the second argument is the first item of the array in the second argument.
then this method gives no result.

```
.Directory~unsetMethod(name)
```
this method takes away the method that the setmethod method set for the name in the argument.
the name is changed to upper.

## the stringtable class

```
.StringTable
```
a stringtable is a map collection where each index is a string, and no two items have the same index.
an item of a stringtable can be any rexx object.
a directory is a map collection like a stringtable, but a directory also has the setmethod method and a method to take away what setmethod did.
you can use the name of an index as a method name to put an item in a stringtable or to get it.
this class inherits the methods of the collection class and of the map collection class.
the code:
```rexx
sTable = .StringTable~new
sTable~name = "Mike"   -- same as sTable~put("Mike", "NAME")
say sTable~name        -- same as say sTable["NAME"]
```
the result:
```
Mike
```

```
.StringTable~new([size])
```
this method is a class method.
this method gives a new empty stringtable.
the argument is optional; it says how many items the stringtable may get, so the stringtable can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.StringTable~[](name)
```
this method gives the item at the index in the argument.
this method is the same as the at method.

```
.StringTable~[]=(item, name)
```
this method adds the item at the index in the second argument, or puts it in the place of the item there.
this method is the same as the put method.

```
.StringTable~allIndexes
```
this method gives an array of all the indexes of the stringtable.

```
.StringTable~allItems
```
this method gives an array of all the items of the stringtable.

```
.StringTable~at(name)
```
this method gives the item at the index in the argument.
if the stringtable has no item at that index, this method gives nil.
the code:
```rexx
say .environment~at("OBJECT")   /* Produces: "The Object class" */
```
the result:
```
The Object class
```

```
.StringTable~empty
```
this method takes away all the items of the stringtable, and gives back the stringtable.

```
.StringTable~entry(name)
```
this method gives the entry of the stringtable for the name in the argument.
the name is changed to upper.
if there is no entry for the name, this method gives nil.

```
.StringTable~hasEntry(name)
```
the name in the argument is changed to upper.
this method gives true if the stringtable has an entry for the name, else false.

```
.StringTable~hasIndex(name)
```
this method gives true if the stringtable has an item at the index in the argument, else false.

```
.StringTable~hasItem(item)
```
this method gives true if the stringtable has the item in the argument at any index, else false.
to compare items, this method uses the strict equal compare of the item.

```
.StringTable~index(item)
```
this method gives the index of the item in the argument.
if the item is at more than one index, this method gives the first index where it finds the item.
if the stringtable does not have the item, this method gives nil.
to compare items, this method uses the strict equal compare of the item.

```
.StringTable~isEmpty
```
this method gives true if the stringtable is empty, else false.

```
.StringTable~items
```
this method gives the count of items in the collection.

```
.StringTable~makeArray
```
this method gives an array with one dimension that has the indexes of the stringtable.
the indexes of the array are from 1 to the count of items.
the items are in no order that you can know; a program must not need an order of them.

```
.StringTable~put(item, name)
```
this method puts the item in the stringtable at the index in the second argument.
if there is an item or a method at that index, the new item takes its place.

```
.StringTable~remove(name)
```
this method takes away the item at the index in the argument, and gives back that item.
if there is no item at that index, this method gives nil.

```
.StringTable~removeEntry(name)
```
this method takes away the entry for the name in the argument, and gives back its item.
the name is changed to upper.
if there is no item for that name, this method gives nil.

```
.StringTable~removeItem(item)
```
this method takes away the item in the argument from the stringtable, and gives back that item.
if the item is at more than one index, this method takes away only the first one it finds.
to compare items, this method uses the strict equal compare of the item.

```
.StringTable~setEntry(name [,entry])
```
this method sets the entry for the name in the first argument to the object in the second argument.
the name is changed to upper.
the new entry takes the place of any entry or method with the same name.
the second argument is optional.
if you omit the second argument, this method takes away any entry or method with that name.

```
.StringTable~supplier
```
this method gives a supplier for the stringtable.
with the supplier you can get each index and item of the stringtable.
the supplier has the indexes and items that the stringtable has when the supplier is made.
the supplier gives them in no order that you can know.

```
.StringTable~unknown(messagename, messageargs)
```
this method runs the entry method or the setentry method.
if the message name does not end with the equal mark, this method runs the entry method with the message name as the argument.
then this method does not use the second argument, and it gives the result of the entry method.
if the message name ends with the equal mark, this method runs the setentry method.
then the first argument of setentry is the message name without the last equal mark, and the second argument is the first item of the array in the second argument.
then this method gives no result.

## the table class

```
.Table
```
a table is a map collection where an index can be any object.
each item has one index, and there can be only one item for each index.
a relation is not like this: a relation can have more than one item with the same index.
to compare indexes, a table uses the strict equal compare.
this class inherits the methods of the collection class and of the map collection class.

```
.Table~new([size])
```
this method is a class method.
this method gives a new empty table.
the argument is optional; it says how many items the table may get, so the table can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.Table~[](index)
```
this method gives the item at the index in the argument.
this method is the same as the at method.

```
.Table~[]=(item, index)
```
this method adds the item to the table at the index in the second argument.
this method is the same as the put method.

```
.Table~allIndexes
```
this method gives an array of all the indexes of the table.

```
.Table~allItems
```
this method gives an array of all the items of the table.

```
.Table~at(index)
```
this method gives the item at the index in the argument.
if the table has no item at that index, this method gives nil.

```
.Table~empty
```
this method takes away all the items of the table, and gives back the table.

```
.Table~hasIndex(index)
```
this method gives true if the table has an item at the index in the argument, else false.

```
.Table~hasItem(item)
```
this method gives true if the table has the item in the argument at any index, else false.
to compare items, this method uses the strict equal compare of the item.

```
.Table~index(item)
```
this method gives the index of the item in the argument.
if the item is at more than one index, this method gives the first index where it finds the item.
if the table does not have the item, this method gives nil.
to compare items, this method uses the strict equal compare of the item.

```
.Table~isEmpty
```
this method gives true if the table is empty, else false.

```
.Table~items
```
this method gives the count of items in the collection.

```
.Table~makeArray
```
this method gives an array with one dimension that has the indexes of the table.
the indexes of the array are from 1 to the count of items.
the items are in no order that you can know.

```
.Table~put(item, index)
```
this method puts the item in the table at the index in the second argument.
the new item takes the place of any item at the same index.

```
.Table~remove(index)
```
this method takes away the item at the index in the argument, and gives back that item.
if there is no item at that index, this method gives nil.

```
.Table~removeItem(item)
```
this method takes away the item in the argument from the table, and gives back that item.
if the item is at more than one index, this method takes away only the first one it finds.
to compare items, this method uses the strict equal compare of the item.

```
.Table~supplier
```
this method gives a supplier for the table.
with the supplier you can get each index and item of the table.
the supplier has the indexes and items that the table has when the supplier is made.
the supplier gives them in no order that you can know.

## the stem class

```
.Stem
```
a stem object is a map collection where each index is a string, and no two items have the same index.
the language makes a stem object when a program uses a stem variable or a compound variable.
in the first example, the language makes a stem object with the name a and a point, assigns it to the variable with that name, and puts 2 at the index 1.
the value at an index that has no value is the name of the stem, then the index.
the put method or the method with two marks and an equal mark, with no index, puts a value at each index of the stem.
after that, each index gives that value, until you assign an other value to it or drop it.
the at method or the method with two marks, with no index, gives that value; its default is the name of the stem.
this class takes away the six compare methods for equal and not equal, with the define method.
this class inherits the methods of the collection class and of the map collection class.
the code:
```rexx
a.1 = 2

say a.[1,2]  -- implicitly creates stem object with name "A."
-- displays "A.1.2"

a = .stem~new("B.")
say a[1,2]     -- displays "B.1.2"
```
the result:
```
A.1.2
B.1.2
```

```
.Stem~new([name])
```
this method is a class method.
this method gives a new stem object.
the argument is optional; it is a string, the name of the stem.
the stem uses the name to make the names of compound variables.
if you omit the argument, the name of the stem is a null string.

```
.Stem~[]([index...])
```
this method gives the item at the index in the arguments.
each argument is an expression; a comma is between two of them.
the stem makes the index from the values of the arguments, with a point between each two.
for an omitted argument, the stem uses a null string.
if the stem has no item at that index, this method gives the default value of the stem.
if the stem has no default value, this method gives the name of the stem, then the index.
the arguments are optional; with no argument, this method gives the default value of the stem.
with no argument and no default value, this method gives the name of the stem.
the at method is the same as this method.
you can not use this method in a drop instruction or in a procedure instruction.

```
.Stem~[]=(value [,index...])
```
this method puts the value in the stem at the index in the other arguments.
the stem makes the index from the arguments, with a point between each two.
the index arguments are optional.
with no index, this method sets a new default value of the stem.
then the stem starts again: this method takes away the value of each index.
the put method says more about this.

```
.Stem~allIndexes
```
this method gives an array of each tail that the stem uses.

```
.Stem~allItems
```
this method gives an array of all the items in the stem.

```
.Stem~at([index...])
```
this method gives the item at the index in the arguments.
each argument is an expression; a comma is between two of them.
the stem makes the index from the values of the arguments, with a point between each two.
for an omitted argument, the stem uses a null string.
if the stem has no item at that index, this method gives the default value of the stem.
if the stem has no default value, this method gives the name of the stem, then the index.
the arguments are optional; with no argument, this method gives the default value of the stem.
with no argument and no default value, this method gives the name of the stem.
the method with two marks is the same as this method.

```
.Stem~empty
```
this method takes away all the items of the stem object, and gives back the stem object.

```
.Stem~hasIndex([index...])
```
this method gives true if the stem has an item at the index in the arguments.
the stem makes the index from the arguments, with a point between each two.
with no index arguments, this method always gives true.

```
.Stem~hasItem(item)
```
this method gives true if the stem has the item in the argument at any tail, else false.
to compare items, this method uses the strict equal compare of the item.

```
.Stem~index(item)
```
this method gives the index of the item in the argument.
if the stem does not have the item, this method gives nil.
to compare items, this method uses the strict equal compare of the item.

```
.Stem~isEmpty
```
this method gives true if the stem is empty, else false.

```
.Stem~items
```
this method gives the count of items in the collection.

```
.Stem~makeArray
```
this method gives an array of all the indexes of the stem that have a value now.
the items are in no order that you can know.

```
.Stem~put(item [,index...])
```
this method puts the item in the stem at the index in the other arguments.
the stem makes the index from the arguments, with a point between each two.
with no index, this method sets a new default value of the stem.
then the stem starts again: this method takes away the value of each index.

```
.Stem~remove([index...])
```
this method takes away the item at the index in the arguments, and gives back that item.
the stem makes the index from the arguments, with a point between each two.
the arguments are optional.
with no index, this method gives the default value of the stem and takes it away, if the stem has a default value.
with no index and no default value, this method gives the name of the stem.

```
.Stem~removeItem(item)
```
this method takes away the item in the argument from the stem, and gives back that item.
if the item is at more than one tail, this method takes away only the first one it finds.
to compare items, this method uses the strict equal compare of the item.

```
.Stem~request(classid)
```
if the argument is array, this method gives the result of the makearray method of the stem.
for each other class, this method sends the request to the default value of the stem.

```
.Stem~supplier
```
this method gives a supplier for the stem.
with the supplier you can get each index and item of the stem.
the supplier has the indexes and items that the stem has when the supplier is made.
the supplier gives them in no order that you can know.

```
.Stem~toDirectory
```
this method gives a directory for the stem.
the directory has a name and a value for each index of the stem that has a value assigned to it.

```
.Stem~unknown(messagename, messageargs)
```
this method sends each unknown message again to the default value of the stem.

## the set class

```
.Set
```
a set is a collection where the index of each item is the item, like a bag.
you can put any object in a set.
an object can be in a set only one time; a bag is not like this.
to compare items, a set uses the strict equal compare.
this class inherits the methods of the collection class and of the map collection class.
it also inherits the set collection class, which has no methods.

```
.Set~of(item...)
```
this method is a class method.
this method gives a new set with the items in the arguments.

```
.Set~new([size])
```
this method is a class method.
this method gives a new empty set.
the argument is optional; it says how many items the set may get, so the set can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.Set~[](index)
```
this method gives the item at the index in the argument.
this method is the same as the at method.

```
.Set~[]=(item [,index])
```
this method adds the item to the set.
if you give the second argument, it must be the same object as the item.
this method is the same as the put method.

```
.Set~allIndexes
```
this method gives an array of all the indexes of the set.

```
.Set~allItems
```
this method gives an array of all the items of the set.

```
.Set~at(index)
```
this method gives the item at the index in the argument.
if the set has no item at that index, this method gives nil.

```
.Set~empty
```
this method takes away all the items of the set, and gives back the set.

```
.Set~hasIndex(index)
```
this method gives true if the collection has an item at the index in the argument, else false.

```
.Set~hasItem(item)
```
this method gives true if the collection has the item in the argument at any index, else false.

```
.Set~index(item)
```
this method gives the index of the item in the argument.
if the item is at more than one index, this method gives the first index where it finds the item.
if the set does not have the item, this method gives nil.
to compare items, this method uses the strict equal compare of the item.

```
.Set~intersection(argument)
```
this method gives a new collection of the same class as the receiver.
the new collection has only the items of the receiver whose index is also an index of the argument.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

```
.Set~isEmpty
```
this method gives true if the set is empty, else false.

```
.Set~items
```
this method gives the count of items in the collection.

```
.Set~makeArray
```
this method gives an array with one dimension that has the indexes of the set.
the indexes of the array are from 1 to the count of items.
the items are in no order that you can know.

```
.Set~put(item [,index])
```
this method adds the item to the set.
if the set has an item that is equal to it, the new item takes the place of that item.
to compare items, this method uses the strict equal compare of the item.
if you give the second argument, it must be the same as the item.

```
.Set~putAll(collection)
```
this method adds all the items of the argument to the set, and gives back the set.
the argument can be any object that has a supplier method.
this method adds the values that the supplier of the argument gives.
if two items of the argument are the same, the last item the supplier gives takes the place of the items before it.

```
.Set~remove(index)
```
this method takes away the item at the index in the argument, and gives back that item.
if there is no item at that index, this method gives nil.

```
.Set~removeItem(item)
```
this method takes away the item in the argument from the set, and gives back that item.
if the set does not have the item, this method gives nil.
to compare items, this method uses the strict equal compare of the item.

```
.Set~subset(argument)
```
this method gives true if each item of the receiver is also in the argument, else false.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

```
.Set~supplier
```
this method gives a supplier for the set.
with the supplier you can get each index and item of the set.
the supplier has the indexes and items that the set has when the supplier is made.
the supplier gives them in no order that you can know.

```
.Set~union(argument)
```
this method gives a new set.
the new set has all the items of the receiver.
it also has each item of the argument that is not an item of the receiver, and that this method did not add before.
you can not know the order in which this method takes the items of the argument.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

```
.Set~xor(argument)
```
this method gives a new set.
the new set has the items of the receiver and of the argument, but not the items that are in both.
the argument is a collection, or an other object that has a makearray method.
the argument must be able to have each index value of the receiver.

## the bag class

```
.Bag
```
a bag is a collection with no index without an item, where the item of each index must be the same as the index.
you can put any object in a bag, and you can put the same object in it more than one time.
this class inherits the methods of the collection class and of the map collection class.
it also inherits the set collection class, which has no methods.

```
.Bag~new([size])
```
this method is a class method.
this method gives a new empty bag.
the argument is optional; it says how many items the bag may get, so the bag can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.Bag~of(item...)
```
this method is a class method.
this method gives a new bag with the items in the arguments.

```
.Bag~[](index)
```
this method gives the item at the index in the argument.
if the bag has no item at that index, this method gives nil.
to compare indexes, this method uses the strict equal compare of the index.
this method is the same as the at method.

```
.Bag~allAt(index)
```
this method gives an array with one dimension that has all the items at the index in the argument.
to compare indexes, this method uses the strict equal compare of the index.
this method gives the same result as the next method here.

```
.Bag~allIndex(item)
```
this method gives an array with one dimension that has all the indexes of the item in the argument.
to compare items, this method uses the strict equal compare of the item.
this method gives the same result as the method before it here.

```
.Bag~allIndexes
```
this method gives an array of all the indexes of the bag, in no order that you can know.
the array has one index for each item in the bag, so an index can be in it more than one time.
the last method but one of this class gives each index only one time.

```
.Bag~allItems
```
this method gives an array of all the items of the bag, in no order that you can know.

```
.Bag~at(index)
```
this method gives the item at the index in the argument.
if the bag does not have that index, this method gives nil.
to compare indexes, this method uses the strict equal compare of the index.
this method is the same as the method with two marks.

```
.Bag~[]=(item [,index])
```
this method adds the item to the bag.
if you give the second argument, it must be the same object as the item.
this method is the same as the put method.

```
.Bag~difference(argument)
```
this method gives a new bag.
the new bag has only the items of the receiver that are not in the argument.
the argument is a collection, or an other object that has a makearray method.

```
.Bag~empty
```
this method takes away all the items of the bag, and gives back the bag.

```
.Bag~hasIndex(index)
```
this method gives true if the bag has an item at the index in the argument, else false.
to compare indexes, this method uses the strict equal compare of the index.

```
.Bag~hasItem(item [,index])
```
this method gives true if the bag has the item in the first argument, else false.
the second argument is optional.
if you give the second argument, it must be the same object as the index of the item; if not, this method always gives false.
to compare items and indexes, this method uses the strict equal compare.

```
.Bag~index(item)
```
this method gives the index of the item in the argument, if the bag has the item.
if the bag does not have the item, this method gives false.
to compare items, this method uses the strict equal compare of the item.

```
.Bag~intersection(argument)
```
this method gives a new bag.
the new bag has only the items that are in both the receiver and the argument.
the argument is a collection, or an other object that has a makearray method.

```
.Bag~isEmpty
```
this method gives true if the bag is empty, else false.

```
.Bag~items([index])
```
this method gives the count of items of the bag at the index in the argument.
the argument is optional; if you omit it, this method gives the count of all items in the bag.
to compare indexes, this method uses the strict equal compare of the index.

```
.Bag~makeArray
```
this method gives an array with one dimension that has all the items of the bag, in no order that you can know.

```
.Bag~put(item [,index])
```
this method adds the item to the bag.
the second argument is optional; if you give it, it must be the same object as the item.
this method is the same as the method with two marks and an equal mark.

```
.Bag~putAll(collection)
```
this method adds all the items of the argument to the bag, and gives back the bag.
the argument can be any object that has a supplier method.
this method adds the item values that the supplier of the argument gives.

```
.Bag~remove(index)
```
this method takes away an item at the index in the argument from the bag, and gives back that item.
if the bag does not have that index, this method gives nil.
to compare indexes, this method uses the strict equal compare of the index.

```
.Bag~removeAll(index)
```
this method takes away all the items at the index in the argument from the bag.
this method gives an array with each item it takes away.
if the bag does not have that index, this method gives an empty array.
to compare indexes, this method uses the strict equal compare of the index.

```
.Bag~removeItem(item [,index])
```
this method takes away the item in the first argument from the bag, and gives back that item.
if the item is not in the bag, this method gives nil.
the second argument is optional; if you give it and it is not the same object as the index of the item, this method always gives nil.

```
.Bag~subset(argument)
```
this method gives true if each index of the receiver is also in the argument, else false.
the argument is a collection, or an other object that has a makearray method.

```
.Bag~supplier([index])
```
this method gives a supplier for the bag.
with the supplier you can get each index and item of the bag.
the supplier has the indexes and items that the bag has when the supplier is made.
the supplier gives them in no order that you can know.
the argument is optional; if you give it, the supplier has all the items at that index.

```
.Bag~union(argument)
```
this method gives a new bag.
the new bag has all the items of the receiver, and some items of the argument.
the argument is a collection, or an other object that has a makearray method.

```
.Bag~uniqueIndexes
```
this method gives an array of all the indexes of the bag, with each index only one time.

```
.Bag~xor(argument)
```
this method gives a new bag.
the new bag has the items of the receiver and of the argument, but not the items that are in both.
the argument is a collection, or an other object that has a makearray method.

## the relation class

```
.Relation
```
a relation is a map collection where an index can be any object.
each item has one index, but more than one item can have the same index.
a table is not like this: a table can have only one item for each index.
this class inherits the methods of the collection class and of the map collection class.

```
.Relation~new([size])
```
this method is a class method.
this method gives a new empty relation.
the argument is optional; it says how many items the relation may get, so the relation can get the right memory at the start.
the argument must be a whole number that is not negative.

```
.Relation~[](index)
```
this method gives an item at the index in the argument.
this method is the same as the at method.

```
.Relation~[]=(item, index)
```
this method adds the item to the relation at the index in the second argument.
this method is the same as the put method.

```
.Relation~allAt(index)
```
this method gives an array with one dimension that has all the items at the index in the argument.
the items are in no order that you can know.
to compare indexes, this method uses the strict equal compare of the index.

```
.Relation~allIndex(item)
```
this method gives an array with one dimension that has all the indexes of the item in the argument.
the indexes are in no order that you can know.
to compare items, this method uses the strict equal compare of the item.

```
.Relation~allIndexes
```
this method gives an array of the indexes of the relation, with one index for each item.
so an index can be in the array more than one time.
the last method but one of this class gives each index only one time.

```
.Relation~allItems
```
this method gives an array of all the items of the relation.

```
.Relation~at(index)
```
this method gives the item at the index in the argument.
if the relation has more than one item at that index, you can not know which one this method gives; a program must not need it.
if the relation has no item at that index, this method gives nil.
to compare indexes, this method uses the strict equal compare of the index.

```
.Relation~difference(argument)
```
this method gives a new relation.
the new relation has only the items of the receiver that the argument does not have with the same index.
the argument is a collection, or an other object that has a makearray method.

```
.Relation~empty
```
this method takes away all the items of the relation, and gives back the relation.

```
.Relation~hasIndex(index)
```
this method gives true if the relation has an item at the index in the argument, else false.
to compare indexes, this method uses the strict equal compare of the index.

```
.Relation~hasItem(item [,index])
```
this method gives true if the relation has the item in the first argument, else false.
the second argument is optional.
if you give the second argument, this method gives true only if the relation has that item at that index.
to compare items and indexes, this method uses the strict equal compare.

```
.Relation~index(item)
```
this method gives the index of the item in the argument.
if the item has more than one index, you can not know which one this method gives.
to compare items, this method uses the strict equal compare of the item.

```
.Relation~intersection(argument)
```
this method gives a new collection of the same class as the receiver.
the new collection has only the items that are in both the receiver and the argument, with the same index in both.
the argument is a collection, or an other object that has a makearray method.

```
.Relation~isEmpty
```
this method gives true if the relation is empty, else false.

```
.Relation~items([index])
```
this method gives the count of items of the relation at the index in the argument.
the argument is optional; if you omit it, this method gives the count of all items at all indexes of the relation.
to compare indexes, this method uses the strict equal compare of the index.

```
.Relation~makeArray
```
this method gives an array with one dimension that has the indexes of the relation.
the items are in no order that you can know.

```
.Relation~put(item, index)
```
this method puts the item in the relation at the index in the second argument.
if the relation has items at that index, this method adds a new item with the same index.
this method does not take away the items that the relation has.

```
.Relation~remove(index)
```
this method takes away an item at the index in the argument from the relation, and gives back that item.
if more than one item has that index, you can not know which one this method takes away.
if no item has that index, this method gives nil.
to compare indexes, this method uses the strict equal compare of the index.

```
.Relation~removeAll(index)
```
this method takes away all the items at the index in the argument from the relation.
this method gives an array with each item it takes away, in no order that you can know.
if no item has that index, this method gives an empty array.
to compare indexes, this method uses the strict equal compare of the index.

```
.Relation~removeItem(item [,index])
```
this method takes away the item in the first argument from the relation, and gives back that item.
the second argument is optional.
if you omit the second argument and the item has more than one index, you can not know which one this method takes away.
if you give the second argument, this method takes away the item at that index.
if the item is the only item at that index, the relation also takes away the index.
if the item is not in the relation, or not at that index, this method gives nil.

```
.Relation~subset(argument)
```
this method gives true if each item of the receiver is also in the argument with the same index, else false.
the argument is a collection, or an other object that has a makearray method.

```
.Relation~supplier([index])
```
this method gives a supplier for the relation.
with the supplier you can get each index and item of the relation.
the supplier has the indexes and items that the relation has when the supplier is made.
the supplier gives them in no order that you can know.
if you give the argument, the supplier has all the items at that index.

```
.Relation~union(argument)
```
this method gives a new collection.
the new collection has all the items of the receiver and of the argument.
the argument is a collection, or an other object that has a makearray method.

```
.Relation~uniqueIndexes
```
this method gives an array of all the indexes of the relation, with each index only one time.

```
.Relation~xor(argument)
```
this method gives a new collection of the same class as the receiver.
the new collection has the items of the receiver and of the argument, but not an item with an index that is in both collections with that item.
the argument is a collection, or an other object that has a makearray method.

## the supplier class

```
.Supplier
```
available: a thing is available when you can get it now
a supplier gives each item of a collection with its index, one after the other.
each class that inherits the collection class has a supplier method; it gives a supplier with the items that the collection has at that time.
you can use a supplier in a loop with the do instruction and the keyword with.
a change to the collection after that does not change what the supplier gives.

```
.Supplier~new(items, indexes)
```
this method is a class method.
this method gives a new supplier.
the first argument must be an array of the objects that the supplier gives.
the second argument is an array of index values; each index is for the object at the same position in the first array.
the supplier gives an item of the first array for each item message, and an index of the second array for each index message.
the supplier gives as many items as the first array has.
if an array has no item at a position, the supplier gives nil for it.

```
.Supplier~allIndexes
```
this method gives an array of all the index values from the place of the supplier now to its end.
after this method, the supplier can not give more items, and the available method gives false.

```
.Supplier~allItems
```
this method gives an array of all the items from the place of the supplier now to its end.
after this method, the supplier can not give more items, and the available method gives false.

```
.Supplier~available
```
this method gives true if an item is available: then the item method gives a value.
this method gives false if the collection is empty, or if the supplier is after the last item of the collection.

```
.Supplier~index
```
this method gives the index of the item of the collection at the place of the supplier now.
if no item is available, it is an error.

```
.Supplier~item
```
this method gives the item of the collection at the place of the supplier now.
if no item is available, it is an error.

```
.Supplier~next
```
this method goes to the next item of the collection.
if you send this message again and again while the available method gives true, you get all the items of the collection.
if no item is available, it is an error.

```
.Supplier~supplier
```
this method gives back the receiver: the same supplier.
so you can give a supplier to a method whose argument must be an object with a supplier method.

## the stream class

```
.Stream
```
close: end the use of a stream, so you can not read or write it until you open it again
closes: close, for one thing
closed: a stream is closed when you close it
opens: makes a stream open, so you can read or write it
opened: a stream is opened when it is made open
errors: more than one error
raises: raise, for one thing
inputoutputstream: the name of a mixin class for streams for input and output
inputstream: the name of a mixin class for input streams
outputstream: the name of a mixin class for output streams
with a stream object, a rexx program can read and write data outside the program.
this class is a subclass of the inputoutputstream class.
this class also inherits the methods of the inputstream class and of the outputstream class.
the inputoutputstream class has no methods.
the part of these facts about input and output streams says more.

```
.Stream~new(name)
```
this method is a class method that this class inherits.
this method makes a stream object for the stream with the name in the argument, and gives it back.
this method does not open the stream.
the argument can be a string or a file object.

```
.Stream~arrayIn(["LINES"|"CHARS"])
```
this method gives an array with the data of the stream, from the read position now.
the argument is optional; it says lines or characters; the default is lines.
if you read characters from the stream before, the first line may be only a part of a line.
```
LINES
```
with this option, each item of the array is one line of the stream; a line ends at a line end character.
this is the default.
```
CHARS
```
with this option, each item of the array is one character of the stream.

```
.Stream~arrayOut(array [,"LINES"|"CHARS"])
```
this method writes the data of the array in the first argument to the stream.
the second argument is optional; it says lines or characters; the default is lines.
```
LINES
```
with this option, this method writes each item of the array as a line.
this is the default.
```
CHARS
```
with this option, this method writes each item of the array as characters.

```
.Stream~charIn([start] [,length])
```
syntax: the rules of how to write code; also the name of a condition that is raised for some errors
notready: the name of a condition that is raised when a stream can not read or write
this method reads characters from an input stream and gives them as a string.
the string has length characters or less.
the read position of the stream goes on by the count of characters it reads.
the length argument is optional; the default is 1.
the start argument is optional; if you give it, the read position goes there before this method reads.
the start argument must be a positive whole number in the stream; if it is not a positive whole number, the syntax condition is raised.
if the start argument is after the end of the stream, this method gives the empty string and raises the notready condition.
if the stream is not open, this method tries to open it to read and write; if it can not, it opens the stream for input only.

```
.Stream~charOut([string] [,start])
```
this method writes the string to the output stream, and gives the count of characters that it did not write.
the write position of the stream goes on.
the string argument is optional, and it can be a null string.
with a null string, this method writes no characters and gives 0.
if you omit the string argument, this method writes no characters, gives 0, and closes the stream.
the start argument is optional; if you give it, the write position goes there before this method writes.
if the stream is not open, this method tries to open it to read and write; if it can not, it opens the stream for output only.

```
.Stream~chars
```
persistent: a persistent stream, as a file on a disk, keeps its data, and you can read it from any position
this method gives the count of characters that are left in the input stream.
the count has the line end characters, if the stream has them.
for a persistent stream, the count is from the read position now.
for some streams, as the input of the program, the computer can not know the count.
for these streams, this method gives 1 when there is data, and 0 when there is no data.

```
.Stream~close
```
ready: a stream is ready when it can read or write
this method closes the stream.
if it can close the stream, this method gives the string ready with a colon after it.
if it can not, it gives an error message.
if the stream is not open, this method gives a null string.

```
.Stream~command(stream_command)
```
errno: a number that says what the error was
description: a string that says what a thing is
seek: set the read position or the write position of a stream
query: a stream command and a stream method that give facts about a stream
this method runs the stream command in the argument, and gives a string.
the argument can be any expression whose value is a stream command.
the string it gives is not the same for each command; it can be a null string.
with a command you can open a stream, close it, change the read or write position, or get facts about the stream.
if the command can not run, this method gives an error message, in the same way as the description method.
for many errors, there is more data in a number: the errno value.
the computer sets errno each time a step of the file code gives negative one.
```
OPEN
```
this command opens the stream; if it can, it gives the string ready with a colon after it.
the options are the same as the options of the open method.
with no option, the stream is open to read and to write.
the code:
```rexx
stream~command("open")
stream~command("open write")
stream~command("open read")
stream~command("open read shared")
```
the result:
```
97.1
```
```
CLOSE
```
this command closes the stream.
if it can close the stream, it gives the string ready with a colon after it; if not, it gives an error message.
if the stream is not open, it gives a null string.
```
FLUSH
```
this command makes the stream write all the data it keeps in memory for output.
```
SEEK
```
this command sets the read or write position of a persistent stream.
the position command is the same as this command.
it is the same as the seek method; that method says more.
the code:
```rexx
stream~command("seek =2 read")
stream~command("seek +15 read")
stream~command("seek -7 write line")
fromend  = 125
stream~command("seek <"fromend "read")
```
the result:
```
97.1
```
```
QUERY
```
this command gives facts about the stream.
it is the same as the query method; that method says more.
the code:
```rexx
say stream~command("query datetime")
```
the result:
```
97.1
```
the reference says:
```
11-12-15 03:29:12
```

the code:
```rexx
say stream~command("query exists")
```
the result:
```
97.1
```
the reference says:
```
c:\data\file.txt
```

the code:
```rexx
say stream~command("query handle")
```
the result:
```
97.1
```
the reference says:
```
3
```

the code:
```rexx
say stream~command("query position write")
```
the result:
```
97.1
```
the reference says:
```
247
```

the code:
```rexx
say stream~command("query size")
```
the result:
```
97.1
```
the reference says:
```
1305
```

the code:
```rexx
say stream~command("query timestamp")
```
the result:
```
97.1
```
the reference says:
```
2015-11-12 03:29:12
```

```
.Stream~description
```
state: what is true of a thing at one time
this method gives a string that says the state of the stream now.
the string is the same as the string of the state method, but with a colon after it.
for the error state and the notready state, the string can also have more data after the colon.

```
.Stream~flush
```
this method makes the stream write all the data it keeps in memory for output.
this method gives the string ready with a colon after it.

```
.Stream~init(name)
```
this method makes the stream object ready for the stream with the name in the argument.
the argument can be a string or a file object.

```
.Stream~lineIn([line] [,count])
```
transient: a transient stream is a stream that is not persistent
this method gives the next lines of the stream: as many as the count argument.
the count argument must be 0 or 1; it is optional, and the default is 1.
the read position of the stream goes on.
the line argument is optional; if you give it, the read position goes to the start of that line.
the line argument must be positive and in the stream; line 1 is the first line of the stream.
you must not give the line argument for a transient stream.
if the stream is not open, this method tries to open it to read and write; if it can not, it opens the stream for input only.

```
.Stream~lineOut([string] [,line])
```
this method writes the string as a line to the stream.
this method gives 0 if it writes the line, and 1 if there is an error.
the write position of the stream goes on.
the line argument is optional; if you give it, the write position goes there before this method writes.
if you omit both arguments, this method closes the stream.
if the stream is not open, this method tries to open it to read and write; if it can not, it opens the stream for output only.

```
.Stream~lines(["Count"|"Normal"])
```
slow: needs more time than an other way
this method says if a next read of characters or lines can get data.
the argument is optional; it is an option; the default is the first option here.
for a queue, the lines method gives the count of lines in the queue.
```
Count
```
with this option, this method gives the count of lines that are left for input.
this is the default.
if you read characters from the stream before, the count can have a first line that is only a part of a line.
this method gives 0 when there is no data left.
for a persistent stream, the count is from the read position now.
this method reads the stream from the position now to count the lines, so for a stream with many lines it can be slow.
do not use this option, or no option, in the condition of a loop that reads a stream; use the next option or the method that gives the count of characters.
```
Normal
```
with this option, this method gives true if one or more lines are left in the stream, else false.

```
.Stream~makeArray(["LINES"|"CHARS"])
```
this method gives an array with the data of the stream, from the read position now.
the data can be in lines or in characters; the default is lines.
if you read characters from the stream before, the first line may be only a part of a line.

```
.Stream~open([options])
```
this method opens the stream.
if it can open the stream, this method gives the string ready with a colon after it.
if it can not, it gives an error message, in the same way as the description method.
for many errors, there is more data in a number: the errno value.
the computer sets errno each time a step of the file code gives negative one.
with no option, the stream is open to read and to write.
```
READ
```
with this option, the stream is open for input only.
```
WRITE
```
with this option, the stream is open for output only.
```
BOTH
```
with this option, the stream is open for input and output, with a read position and a write position that are not the same.
this is the default.
```
APPEND
```
with this option, the write position is at the end of the stream.
the write position can not go to a place in the data that the file had when it was opened.
this is the default.
```
REPLACE
```
with this option, the write position is at the start of the stream, and the stream takes away all its data.
```
SHARED
```
with this option, an other program can also use the stream.
```
SHAREREAD
```
with this option, an other program can also read the stream.
```
SHAREWRITE
```
with this option, an other program can also write to the stream.
```
NOBUFFER
```
with this option, the stream does not keep data in memory: it gives all the data it writes to the computer at that time.
this can make output slow.
use it only when the data must be in the file when you write it, or when output must be in the same order as you write it.
```
BINARY
```
with this option, the stream is open in binary mode: a line end character is data like each other character.
use it for line reads and line writes of binary data.
if the stream is not there and you open it to write in binary mode, you must give the next option too; if not, an error condition is raised.
```
RECLENGTH
```
record: a part of a file that a line read or a line write uses as one line
with this option, each line of a stream in binary mode is a record with the length you give.
without it, a line read or a line write in binary mode uses the whole file.
the length must be 1 or more.
the code:
```rexx
stream~open
stream~open("write")
stream~open("read")
```
the result:
```
97.1
```

```
.Stream~position(offset)
```
this method is the same as the seek method.

```
.Stream~qualify
```
this method gives the whole name of the stream, with its directory.
the stream does not have to be open.

```
.Stream~query(option)
```
handle: a number that the computer gives to an open stream
this method gives facts about the stream.
the stream does not have to be open, but for the handle option and the position option it must be open.
if the stream is not there, this method gives a null string.
```
DATETIME
```
date: a value that the date builtin function gives
this option gives the date and time of a persistent stream, in the way of the example.
the code:
```rexx
say stream~query("datetime")
```
the result:
```
97.1
```
the reference says:
```
11-12-15 03:29:12
```
```
EXISTS
```
this option gives the whole name of the stream with its directory, if the stream is there, else a null string.
the code:
```rexx
say stream~query("exists")
```
the result:
```
97.1
```
the reference says:
```
c:\data\file.txt
```
```
HANDLE
```
this option gives the handle of the open stream.
the code:
```rexx
say stream~query("handle")
```
the result:
```
97.1
```
the reference says:
```
3
```
```
POSITION
```
this option gives the read position or the write position of the stream now.
the seek option is the same as this option.
with read, it gives the read position; with write, it gives the write position.
if the stream is open to read and to write, the default is the read position.
with the option for characters, it gives the position as a count of characters; this is the default.
with the option for lines, it gives the position as a count of lines; for a stream that is not in binary mode, this can be slow.
the code:
```rexx
say stream~query("position write")
```
the result:
```
97.1
```
the reference says:
```
247
```
```
SYS
```
this option gives the position of the stream in characters, as the computer has it.
```
SIZE
```
this option gives the size of a persistent stream, as a count of bytes.
the code:
```rexx
say stream~query("size")
```
the result:
```
97.1
```
the reference says:
```
1305
```
```
STREAMTYPE
```
this option gives the word persistent, the word transient, or the word unknown.
```
TIMESTAMP
```
this option gives the date and time of a persistent stream, in the way of the example.
the reference says to use this option, and not the first option here, so you get all four digits of the first number.
the code:
```rexx
say stream~query("timestamp")
```
the result:
```
97.1
```
the reference says:
```
2015-11-12 03:29:12
```

```
.Stream~say([string])
```
this method writes the string to the output stream.
this method gives 0 if it can write the string, and 1 if there is an error.

```
.Stream~seek(offset)
```
offset: a count of characters or lines from a place in a stream
this method sets the read position or the write position of a persistent stream to the offset in the argument.
if the stream is open to read and to write and you do not give read or write, this method sets both positions.
the stream must be open: with the open method, or by an input or output step.
this method gives the new position, or an error message if it can not set it.
before the offset there can be a mark: with the equal mark or no mark, the offset is from the start of the stream; 1 is the start of the stream.
with the less than mark, the offset is from the end of the stream.
with the add mark, the offset goes on from the read or write position now.
with the subtract mark, the offset goes back from the read or write position now.
after the offset there can be options.
```
READ
```
with this option, this method sets the read position.
```
WRITE
```
with this option, this method sets the write position.
```
CHAR
```
with this option, the offset is a count of characters; this is the default.
```
LINE
```
with this option, the offset is a count of lines.
for a stream that is not in binary mode, this can be slow: the computer must read the file from the start to count the lines.
for a binary stream with a record length, the computer gets the line number times the record length.
for a file that is open only to write, this option gives an error message.
the code:
```rexx
stream~seek("=2 read")
stream~seek("+15 read")
stream~seek("-7 write line")
fromend  = 125
stream~seek("<"fromend read)
```
the result:
```
97.1
```

```
.Stream~state
```
this method gives a string that says the state of the stream now.
```
ERROR
```
this value says that an input step, an output step, or a stream method had an error on the stream.
the description method can give more data about the error.
```
NOTREADY
```
this value says that an input or output step on the stream now raises the notready condition.
a read of characters or lines after the end of an input stream with a length can make the stream not ready.
the stream is not ready until you close it and open it again.
```
READY
```
this value says that the stream is in the state where you can try input and output.
it does not say that the next step has no error.
```
UNKNOWN
```
this value says that the state of the stream is not known.
it can say that the stream is closed, or that it was not opened yet.

```
.Stream~string
```
this method gives the name of the object the stream is for; this object is a file, so it is the name of the file.

```
.Stream~supplier
```
streamsupplier: the name of a class of supplier for the lines of a stream
this method gives a streamsupplier object for the stream.
the streamsupplier has the lines of the stream that are left, and the number of each line.

```
.Stream~uninit
```
uninit: the name of a method that runs when the computer takes an object away from memory
this method does the last steps for the stream object when the computer takes it away from memory.
do not call this method; only the uninit method of a subclass of the stream class may call it.
if a subclass of the stream class has an uninit method, that method must call the uninit method of the superclass.
that call must be the last step of the method.
the code:
```rexx
::class CustomStream subclass Stream

/* ... */

::method uninit
/* the subclass instance cleanup code should be placed here */
super~uninit  -- this should be the last action in the method
return
```
the result:
```
```

## the message class

```
.Message
```
alarm: the name of a class; an alarm sends a message at a time you set
alarmnotification: the name of a mixin class for objects that get a message when an alarm ends
messagenotification: the name of a mixin class for objects that get a message when a message ends
startwith: the name of a method like start, but with the arguments in an array
sendwith: the name of a method like send, but with the arguments in an array
replywith: the name of a method like reply, but with the arguments in an array
ask: say that you want a thing
asks: ask, for one thing
fourth: the next after the third
ticker: the name of a class like the alarm class
with a message object, you can send a message at a time after now, or send it and go on to run at the same time.
to make a message object, use the new method of this class, or the start or startwith method of the object class.
this class inherits the mixin classes alarmnotification and messagenotification.

```
.Message~new(target, messagename [,"Individual"|"Array"] [,argument...])
```
target: the object that gets a message
this method is a class method.
this method makes a message object to send the message name in the second argument to the target in the first argument.
this method does not send the message.
the second argument is a string or an array.
if the second argument is an array, its first item is the message name, and its second item is a class object; the computer starts to find the method at that class.
the third argument is an option; only the first letter of it is used.
with the option i, the other arguments are optional, and they go to the target as the arguments of the message, in the same order.
with the option a, the fourth argument must be an array; its items go to the target as the arguments: the item at index 1 is the first argument, and so on.
if the array has no item at an index, that argument is omitted.
with no option, the message has no arguments.
the start, startwith, send, sendwith, reply, and replywith methods send the message.

```
.Message~arguments
```
this method gives an array of the arguments of the message.

```
.Message~completed
```
completed: done; at its end
this method gives 1 if the message object has completed its message, else 0.
you can use this method to test if the message is completed, and not use the result method, which waits for the message to end.

```
.Message~errorCondition
```
this method gives a condition object for an error in the message when it was running.
if the message completed with no error, or if it runs now, this method gives nil.

```
.Message~halt([description])
```
this method raises the halt condition for the message that the receiver runs now.
this method gives true if it can raise the halt condition, and false if no message runs.
the argument is optional; it is a string, a description of the halt.
the message that gets the halt can get that string as the description item from the condition builtin function or from the condition object.
the code:
```rexx
dog = .WatchDog~new(1)                 -- watchdog with 1 sec time-out
say dog~watchTask(.task~new~start("runsLong", 0.5))
say dog~watchTask(.task~new~start("runsLong", 1.5))


::class Task

-- a long-running task that we may want to terminate early
::method runsLong
  use strict arg seconds
  signal on halt
  do s = 0 to seconds by 0.1           -- split SysSleep to enable halting
    call SysSleep 0.1                  -- do "hard work"
  end
  return "task finished"

  halt:
  return condition("DESCRIPTION")      -- return description from halt()


::class Watchdog inherit AlarmNotification

-- sets a time-out, after which a running task will be halted
::method init
  expose timeOut
  use strict arg timeOut

-- watches over a task, halting it if it runs too long
::method watchTask
  expose timeOut
  use strict arg message
  -- we set an Alarm for 'timeOut' seconds, which, upon triggering
  -- will call method triggered(), passing this Alarm object as an argument
  -- (this is why we inherit from AlarmNotification)
  -- we also attach 'message' to enable triggered() to halt the task
  alarm = .Alarm~new(timeOut, self, message)

  -- now we just wait for 'message' to finish; either normally, or halted
  msgResult = message~result
  alarm~cancel                         -- cancel alarm; may still be active
  return msgResult

::method triggered unguarded
  expose timeOut
  -- our watchTask Alarm has triggered
  -- this means that the task has run too long
  use arg alarm
  message = alarm~attachment           -- message is our attachment
  message~halt("task took longer than" timeOut "sec")
```
the result:
```
task finished
task took longer than 1 sec
```
the reference says:
```
task finished
task took longer than 1 sec
```

```
.Message~hasError
```
this method gives 1 if the message ends with an error condition.
it gives 0 if the message is not completed, or if it completed with no error.

```
.Message~hasResult
```
this method gives true if the message object has completed its message and the message has a result.
it gives false if the message is not completed, or if the message has no result.
the result method says more.

```
.Message~messageComplete(source)
```
notify: send a message to an object when a thing is completed
this method is a part of the messagenotification mixin.
the language calls this method when a message ends, if the notify method of that message has this message object as its argument.
then this method starts the receiver message.
this method does not use its argument.
the code:
```rexx
msg = .Message~new(.Array~new(1000)~fill(0)~allIndexes, "sort")
msg~notify(.Message~new(.stdout, "say", "I", "sorting complete"))
msg~notify(.Message~new(.r~new, "items", "I", msg))
msg~start
say "processing continues"

::class r
::method items
use strict arg m
say m~target~items "items sorted"
```
the result:
```
processing continues
sorting complete
1000 items sorted
```
the reference says:
```
processing continues
sorting complete
1000 items sorted
```

```
.Message~messageName
```
this method gives the message name of the receiver message object.

```
.Message~notify(argument)
```
this method asks that the argument get a message when the message is completed.
the argument must have the methods of the messagenotification mixin.
when the message is completed, the language sends the argument the message of the messagenotification mixin, with the completed message object as its argument.
you can ask for this for one message as many times as you want.
to get the result of the completed message, use the result method.
the code:
```rexx
msg = .Message~new(.Array~new(1000)~fill(0)~allIndexes, "sort")
msg~notify(.Sorter~new)
msg~start
say "processing continues"

::class Sorter inherit MessageNotification
::method messageComplete
  use strict arg message

  say message~target~items "items sorted"
```
the result:
```
processing continues
1000 items sorted
```
the reference says:
```
processing continues
1000 items sorted
```

```
.Message~reply([target] [,argument...])
```
this method makes a copy of the message, sends the copy to start to run, and gives it back; the caller goes on to run too.
it is like the start method, but you can call it more than one time for the same message.
the first argument is optional; if you give it, the message goes to that target, and the receiver and the copy now use that target.
if you omit it, the message goes to the target of the message object.
the other arguments are optional; if you give them, the message goes with them, and the receiver and the copy now use them.
if you omit them, the message goes with the arguments of the message object.
this method does not wait for the message to end.
the notify method can ask for a message when the message ends.
when the message ends, the message object keeps the result until you get it with the result method.

```
.Message~replyWith([target,] arguments)
```
this method makes a copy of the message, sends the copy with the arguments in the array to start to run, and gives it back; the caller goes on to run too.
it is like the startwith method, but you can call it more than one time for the same message.
the target argument is optional; if you give it, the message goes to that target, and the receiver and the copy now use that target.
if you omit it, the message goes to the target of the message object.
the items of the array are the arguments of the message, and the receiver and the copy now use them.
this method does not wait for the message to end.
the notify method can ask for a message when the message ends.
when the message ends, the message object keeps the result until you get it with the result method.

```
.Message~result
```
this method gives the result of the send or start of the message.
if the message did not end yet, this method waits until it ends.
if the send or start raises an error condition, this method also raises an error condition.
the example of the halt method uses this method.

```
.Message~send([target] [,argument...])
```
this method sends the message and gives the result, if there is one.
this method waits until the message ends.
the first argument is optional; if you give it, the message goes to that target, and the message object now uses that target.
if you omit it, the message goes to the target of the message object.
the other arguments are optional; if you give them, the message goes with them, and the message object now uses them.
if you omit them, the message goes with the arguments of the message object.
the notify method can ask for a message when the message ends.
when the message ends, the message object keeps the result until you get it with the result method.

```
.Message~sendWith([target,] arguments)
```
this method sends the message with the arguments in the array, and gives the result, if there is one.
this method waits until the message ends.
the target argument is optional; if you give it, the message goes to that target, and the message object now uses that target.
if you omit it, the message goes to the target of the message object.
the items of the array are the arguments of the message, and the message object now uses them.
the notify method can ask for a message when the message ends.
when the message ends, the message object keeps the result until you get it with the result method.

```
.Message~start([target] [,argument...])
```
this method sends the message to start to run, and the caller goes on to run too.
this method does not wait for the message to end.
the first argument is optional; if you give it, the message goes to that target, and the message object now uses that target.
if you omit it, the message goes to the target of the message object.
the other arguments are optional; if you give them, the message goes with them, and the message object now uses them.
if you omit them, the message goes with the arguments of the message object.
after you start a message object with start or startwith, you can not run it again with send, sendwith, start, startwith, reply, or replywith.
you can run a message object more than one time with send, sendwith, reply, and replywith.
the notify method can ask for a message when the message ends.
when the message ends, the message object keeps the result until you get it with the result method.
the output of the caller and of the message can be in any order.
the code:
```rexx
ez=.testclass~new                  /* Creates a new instance of Testclass     */

/* Creates and starts message mymsg to send SHOWMSG to ez                     */
mymsg=ez~start("SHOWMSG","Hello, Ollie!",5)

/* Continue with main processing while SHOWMSG runs concurrently              */
do 5
  say "Hello, Stan!"
end

/* Get final result of the SHOWMSG method from the mymsg message object       */
say mymsg~result
say "Goodbye, Stan..."
exit

::class testclass public             /* Directive defines Testclass           */

::method showmsg                     /* Directive creates new method SHOWMSG  */
use arg text,reps                    /* class Testclass                       */
do reps
  say text
end
reply "Bye Bye, Ollie..."
return
```
the result:
```
Hello, Stan!
Hello, Ollie!
Hello, Stan!
Hello, Ollie!
Hello, Stan!
Hello, Ollie!
Hello, Stan!
Hello, Ollie!
Hello, Stan!
Hello, Ollie!
Bye Bye, Ollie...
Goodbye, Stan...
```
the reference says:
```
Hello, Ollie!
Hello, Stan!
Hello, Ollie!
Hello, Stan!
Hello, Ollie!
Hello, Stan!
Hello, Ollie!
Hello, Stan!
Hello, Ollie!
Hello, Stan!
Bye Bye, Ollie...
Goodbye, Stan...
```

```
.Message~startWith([target,] arguments)
```
this method sends the message with the arguments in the array to start to run, and the caller goes on to run too.
this method does not wait for the message to end.
the target argument is optional; if you give it, the message goes to that target, and the message object now uses that target.
if you omit it, the message goes to the target of the message object.
the items of the array are the arguments of the message, and the message object now uses them.
after you start a message object with start or startwith, you can not run it again with send, sendwith, start, startwith, reply, or replywith.
you can run a message object more than one time with send, sendwith, reply, and replywith.
the notify method can ask for a message when the message ends.
when the message ends, the message object keeps the result until you get it with the result method.

```
.Message~target
```
this method gives the object that is the target of the message.

```
.Message~triggered(source)
```
triggered: an alarm is triggered when the time you set is now
this method is a part of the alarmnotification mixin.
the language calls this method when an alarm or a ticker is triggered, if the alarm or ticker has this message object as the object to send to.
then this method starts the receiver message.
this method does not use its argument.
the code:
```rexx
arg = .Array~new(1)
msg = .Message~new(.a~new, "ring", "A", arg)
oneSecond = .Alarm~new(1, msg, arg)
arg~append(oneSecond)
-- oneSecond = .Alarm~new(1, .Message~new(.a~new, "ring", "I", alarm))
say "processing continues"

::class a
::method ring
use strict arg alarm
say "alarm went off at" .DateTime~new
say "was scheduled for" alarm~scheduledTime
```
the result:
```
processing continues
alarm went off at 2026-10-28T17:43:47.213810
was scheduled for 2026-10-28T17:43:47.212750
```
the reference says:
```
processing continues
alarm went off at 2015-12-18T16:54:15.550000
was scheduled for 2015-12-18T16:54:15.545000
```

```
.Message~wait
```
this method waits until the message object has completed its message.
the completed method says more.

## the method class

```
.Method
```
the method class makes method objects from rexx code.
this class is a subclass of the object class.

```
.Method~new(name, source [,context])
```
source: the code that a thing is made from
programscope: the name of an option; with it, a new method or routine finds classes and routines in the same way as its caller
this method is a class method.
this method makes a new method object, and gives it back; the object is code that can run, made from the source.
the first argument is a string, the name.
the source is one string, or an array of strings with one line of the method in each.
the third argument is optional; with it, the new method finds classes and routines in the same way as an other thing.
the third argument can be a method object, a routine object, a package object, or the string programscope.
the default is programscope: the new method finds classes and routines in the same way as the caller of this method.

```
.Method~newFile(filename [,context])
```
this method is a class method.
this method makes a new method object from the code in a file, and gives it back.
the first argument is a string, the name of the file.
if the computer can not read the file, it is an error.
the second argument is optional; it can be a method object, a routine object, a package object, or the string programscope.
the default is programscope: the new method finds classes and routines in the same way as the caller of this method.

```
.Method~loadExternalMethod(name, descriptor)
```
library: a file of code from outside rexx that a program can use
this method is a class method.
this method finds a method in an external library, and gives a method object that can call it.
the second argument is a string of words with blanks between them; the words say where the method is.
the first word must be library.
the second word is the name of the library; the computer finds the library in the way of that computer.
the third word is optional; it is the name of the method in the library; if you omit it, this method uses the name in the first argument.
if this method can not find the method, it gives nil.
on some kinds of computer the name of the library is not caseless, but the name of the method is caseless.
the code:
```rexx
method = .Method~loadExternalMethod("homeAddress=", "LIBRARY mylib setHomeAddress")
```
the result:
```
```

```
.Method~annotation(name)
```
this method gives the value of the annotation of this method that has the name in the argument.
if the method has no annotation with that name, this method gives nil.

```
.Method~annotations
```
this method gives a stringtable with all the annotations of this method: each index is a name, and each item is its value.

```
.Method~isAbstract
```
this method gives true if the method is abstract, else false.
the abstract option of the method directive and of the attribute directive make an abstract method.
the code:
```rexx
say .InputStream~method("lines")~isAbstract    -- 1
say .Stream~method("lines")~isAbstract         -- 0
```
the result:
```
1
0
```

```
.Method~isAttribute
```
this method gives true if the method is an attribute method, else false.
the attribute directive makes attribute methods.
the code:
```rexx
say .File~method("lastModified")~isAttribute     -- 1
say .File~method("lastModified=")~isAttribute    -- 1
```
the result:
```
1
1
```

```
.Method~isConstant
```
this method gives true if the method is a constant method, else false.
the constant directive makes constant methods.
the code:
```rexx
say .physics~method("c")~isConstant              -- 1

::class physics
::constant c 299792458
```
the result:
```
1
```

```
.Method~isGuarded
```
this method gives true if the method is guarded, and false if it is unguarded.

```
.Method~isPackage
```
this method gives true if the method has the scope of a package, and false for a public method or a private method.

```
.Method~isPrivate
```
this method gives true if the method is private, and false for a public method or a method with the scope of a package.

```
.Method~isProtected
```
security: rules about what code may do
manager: an object that says if a thing may be done
protected: the name of a kind of method; the part of these facts about the security manager says more
this method gives true if the method is protected, else false.

```
.Method~package
```
this method gives the package object that made this method object.
this package says the order in which the computer finds the classes and the routines that the code of the method uses.

```
.Method~scope
```
this method gives the class that is the scope of the method.
for a method that is not made in the scope of a class, this method gives nil.
the code:
```rexx
scopes = .Stem~new
scopes[] = 0
loop with item method over .List~methods
  scopes[method~scope] += 1                 -- possible output:
end                                         -- 27 methods from The List class
loop scope over scopes                      -- 19 methods from The Collection class
  say scopes[scope] "methods from" scope    -- 20 methods from The OrderedCollection class
end                                         -- 31 methods from The Object class

.Method~new("any", "nop")~scope             -- .nil

.methods["FLOAT"]~scope                     -- .nil
::method float
```
the result:
```
27 methods from The List class
19 methods from The Collection class
20 methods from The OrderedCollection class
32 methods from The Object class
```

```
.Method~setGuarded
```
this method makes the method object guarded.
a guarded method can run only when no other method can use the variable pool of its scope.
if the method is guarded, this message does not change it.
a method object is guarded by default.

```
.Method~setPrivate
```
this method makes the method object private.
a method object is public by default.

```
.Method~setProtected
```
this method makes the method object protected.
a method object is not protected by default.

```
.Method~setSecurityManager([security_manager_object])
```
this method puts a new security manager in the place of the one there.
the argument is optional; if you omit it, the method has no security manager.
this method is protected.

```
.Method~setUnguarded
```
this method makes the method object unguarded.
then the method can run on an object also when an other method has the use of the variable pool of the scope of the object.
methods are guarded by default.
a guarded method can run on an object only when no other method that needs the variable pool of that object runs in the same object.
but if an object sends a message to the same object to run a method while it has the variable pool, that method runs at that time, guarded or not.

```
.Method~source
```
this method gives the code of the method, as an array with one dimension; each item is one line of the code.
if the code is not there, this method gives an empty array.

## the routine class

```
.Routine
```
the routine class makes routine objects from rexx code.
this class is a subclass of the object class.

```
.Routine~new(name, source [,context])
```
this method is a class method.
this method makes a new routine object, and gives it back; the object is code that can run, made from the source.
the first argument is a string, the name.
the source is one string, or an array of strings with one line in each.
the third argument is optional; with it, the new routine finds classes and routines in the same way as an other thing.
the third argument can be a method object, a routine object, a package object, or the string programscope.
the default is programscope: the new routine finds classes and routines in the same way as the caller of this method.

```
.Routine~newFile(filename [,context])
```
this method is a class method.
this method makes a new routine object from the code in the file with the name in the first argument, and gives it back.
the first argument is a string.
the second argument is optional; it can be a method object, a routine object, a package object, or the string programscope.
the default is programscope: the new routine finds classes and routines in the same way as the caller of this method.

```
.Routine~loadExternalRoutine(name, descriptor)
```
this method is a class method.
this method finds a routine in an external library, and gives a routine object that can call it.
the second argument is a string of words with blanks between them; the words say where the routine is.
the first word must be library.
the second word is the name of the library; the computer finds the library in the way of that computer.
the third word is optional; it is the name of the routine in the library; if you omit it, this method uses the name in the first argument.
if this method can not find the routine, it gives nil.
on some kinds of computer the name of the library is not caseless, but the name of the routine is caseless.
the code:
```rexx
pi = .Routine~loadExternalRoutine("pi", "library rxmath rxcalcpi")
say pi~call(16) -- 3.141592653589793
```
the result:
```
3.141592653589793
```

```
.Routine~[]([argument...])
```
this method calls the routine object with the arguments.
the code of the routine runs as an external routine call.
this method gives the value that the routine gives.
this method is the same as the call method.

```
.Routine~annotation(name)
```
this method gives the value of the annotation of this routine that has the name in the argument.
if the routine has no annotation with that name, this method gives nil.

```
.Routine~annotations
```
this method gives a stringtable with all the annotations of this routine: each index is a name, and each item is its value.

```
.Routine~call([argument...])
```
this method calls the routine object with the arguments.
the code of the routine runs as an external routine call.
this method gives the value that the routine gives.
this method is the same as the method with two marks.

```
.Routine~callWith(array)
```
this method calls the routine object with the arguments in the array.
each item of the array is the argument at the same position.
the code of the routine runs as an external routine call.
this method gives the value that the routine gives.

```
.Routine~package
```
this method gives the package object that made this routine object.
this package says the order in which the computer finds the classes and the routines that the code of the routine uses.

```
.Routine~setSecurityManager([security_manager_object])
```
this method puts a new security manager in the place of the one there.
the argument is optional; if you omit it, the routine has no security manager.
this method is protected.

```
.Routine~source
```
this method gives the code of the routine, as an array with one dimension; each item is one line of the code.
if the code is not there, this method gives an empty array.

## the package class

```
.Package
```
load: read a file of code and put it in memory, so a program can use it
loads: load, for one thing
libraries: more than one library
named: a thing is named when you give its name
needed: a thing is needed when you need it
setting: a value that says how a thing is done
settings: more than one setting
conditions: more than one condition
requires: the name of a directive that makes a package use an other package
imported: a class or a routine is imported when a package gets it from an other package
a package object has the source of a package of rexx code.
it has all the routines, classes, and methods made from one source.
it also has the other packages that the requires directives name; the files that the requires directive loads are package objects too.
this class is a subclass of the object class.

```
.Package~new(name [,source] [,context])
```
this method is a class method.
this method makes a new package object for the code in the source, and gives it back.
the first argument is a string, the name.
the source is optional; it is one string, or an array of strings with one line in each.
if you omit the source, the name is the name of a file with the source; the computer finds the file in the order for external programs.
the third argument is optional; it can be a method object, a routine object, or a package object; the new package finds classes and routines in the same way as that object.
if you omit the third argument, the new package finds classes and routines in the same way as the caller of this method.

```
.Package~defaultOptions(option [,value])
```
this method is a class method.
this method sets the default options for packages that a program loads or requires after this.
an option that a package sets in its code does not change.
only the first letter of an option is needed; the computer does not use the other letters.
the options method can change the options of one package.
```
DefineDefaultOptions
```
with this option, this method gives the default options now, as an options directive.
the second argument is optional; it must be an options directive; it sets the new default options.
```
CountOverrides
```
with this option, this method gives its value now.
the default is 0: the default options do not change the options of a package.
a positive second argument sets the value: the count of times the default options change a package.
a negative value, as negative one, says to change each package.

```
.Package~addClass(class, name)
```
this method adds the class object in the first argument to the classes of the package, with the name in the second argument.
the class is not public in the package.

```
.Package~addPackage(package [,namespace])
```
namespace: a name for a package; code can put it before the name of a class or a routine of that package
this method adds the package object in the first argument to the packages that this package needs.
the package runs as if a requires directive in this package named it.
the second argument is optional; it is a string, a namespace for the classes and routines of the added package.
the code:
```rexx
.context~package~addPackage(.Package~new('winsystm.cls'), 'windows')
say windows:virtualkeycodes~new~keyName(36)   -- HOME
```
the result:
```
43.901
```

```
.Package~addPublicClass(class, name)
```
this method adds the class object in the first argument to the public classes of the package, with the name in the second argument.
the class is public in the package.

```
.Package~addPublicRoutine(routine, name)
```
this method adds the routine object in the first argument to the routines of the package, with the name in the second argument.
the routine is public in the package.

```
.Package~addRoutine(routine, name)
```
this method adds the routine object in the first argument to the routines of the package, with the name in the second argument.
the routine is not public in the package.

```
.Package~annotation(name)
```
this method gives the value of the annotation of this package that has the name in the argument.
if the package has no annotation with that name, this method gives nil.

```
.Package~annotations
```
this method gives a stringtable with all the annotations of this package: each index is a name, and each item is its value.

```
.Package~classes
```
this method gives a stringtable with all the classes that this package makes.
the methods that give the public classes and the imported classes are like this method.

```
.Package~definedMethods
```
this method gives a stringtable with all the methods of this package that are not a part of a class.
code in the package gets the same stringtable with the symbol point methods.

```
.Package~digits
```
numeric: the name of an instruction that sets how the computer does maths
this method gives the first numeric digits setting for all the rexx code in the package.
the default is 9.
the options directive can change this default.

```
.Package~findClass(name)
```
this method finds the name in the argument in the same way as the language finds a symbol that starts with a point, or a class name of a class directive.
if it finds the name, it gives the class; for some names it gives an object that is not a class, as for nil, true, false, or an object in the local directory.
if it does not find the name, it gives nil.
the code:
```rexx
say .RexxInfo~package~findClass("Dummy")  -- The NIL object
say .context~package~findClass("Dummy")   -- The DUMMY class

::class Dummy
```
the result:
```
The NIL object
The DUMMY class
```

```
.Package~findNamespace(name)
```
this method gives the package object that has the namespace in the argument.
if there is no namespace with that name, this method gives nil.
the method that adds a package says more.
the code:
```rexx
say .context~package~findNamespace("rexx")      -- The REXX Package
say .context~package~findNamespace("windows")   -- a Package

::requires "winsystm.cls" namespace windows
```
the result:
```
43.901
```

```
.Package~findProgram(name)
```
this method finds a program name for this package, and gives the whole file name.
it finds the file in the order for external programs.
the argument must be a string, the name of the file of an external program, or its path.
if it can not find the file, this method gives nil.
the code:
```rexx
say .context~package~findProgram("mime.cls")  -- e. g. C:\Program Files\ooRexx\mime.cls
```
the result:
```
/home/claude/oorexx/usr/local/bin/mime.cls
```

```
.Package~findPublicClass(name)
```
this method gives the public class with the name in the argument.
if there is no public class with that name in the scope of the receiver package, this method gives nil.
a class that is not public is not found.
the code:
```rexx
say .context~package~findPublicClass("String")   -- The String class
say .context~package~findPublicClass("Dummy")    -- The NIL object
say .context~package~findPublicClass("RexxInfo") -- The NIL object

::class Dummy   -- private class
```
the result:
```
The String class
The NIL object
The NIL object
```

```
.Package~findPublicRoutine(name)
```
this method gives the public routine with the name in the argument.
if there is no public routine with that name in the scope of the receiver package, this method gives nil.
the code:
```rexx
say .context~package~findPublicRoutine("Dummy")~source    -- "nop"

::routine Dummy public
nop
```
the result:
```
nop
```

```
.Package~findRoutine(name)
```
this method finds a routine in the order in which the package finds routines.
it finds the routines of the routine directives of the package, the public routines that the package gets from other packages, and the routines that the method to add a routine added.
the argument must be a string.
if it does not find the routine, this method gives nil.

```
.Package~form
```
form: the way to write a number; also the name of a numeric setting
scientific: the name of a form of numbers
this method gives the first numeric form setting for all the rexx code in the package.
the default is scientific.
the options directive can change this default.

```
.Package~fuzz
```
fuzz: the name of a numeric setting
this method gives the first numeric fuzz setting for all the rexx code in the package.
the default is 0.
the options directive can change this default.

```
.Package~importedClasses
```
this method gives a stringtable with all the public classes that this package gets from other packages.

```
.Package~importedPackages
```
this method gives an array with all the packages that this package gets.

```
.Package~importedRoutines
```
this method gives a stringtable with all the public routines that this package gets from other packages.

```
.Package~loadLibrary(name)
```
this method loads the external library with the name in the argument, and adds it to the libraries that the language has.
the language finds the library and loads it as if a requires directive with the library option named it.
this method gives true if it can load the library, else false.

```
.Package~loadPackage(name [,source])
```
this method loads a package and adds it to the packages that the language has.
if you give only the name, it is the name of a file; the language finds the file in the order for external programs, and loads it as if a requires directive named it.
the second argument is optional; it is an array of strings, the source of the package.
the package is added to the packages that the receiver package needs.
if the language has a package with the same name, it uses that package.

```
.Package~local
```
this method gives a directory of the objects that are local to the receiver package.
the local directory of the language is not this directory.

```
.Package~name
```
this method gives the name of the package, as a string.
instore: a package name for code that the rexx command runs from an expression
the name can be the whole file name of the program that runs, the name you give when you make a package or routine object, rexx for the classes of the language, or instore for code that the rexx command runs from an expression.
the code:
```rexx
say .context~package~name              -- e. g. C:\ExamplePackageName.rex
say .Class~package~name                -- REXX
say .Routine~new("rtn", "return .context~package~name")[]  -- rtn
say .Package~new("pkg", "")~name       -- pkg
```
the result:
```
/tmp/claude-0/-home-claude/7a454f5a-2610-5341-b35a-ce8fb6712926/scratchpad/runall/slam_examples_2026102863809/run/example.rex
REXX
rtn
pkg
```

```
.Package~namespaces
```
namespaces: more than one namespace
this method gives a stringtable with all the namespaces of the package.
the method that finds a namespace is like this method.
the code:
```rexx
say .context~package~namespaces~allIndexes      -- WINDOWS

::requires "winsystm.cls" namespace windows
```
the result:
```
43.901
```

```
.Package~options([option [,newValue]])
```
this method gives the options of the package now, or changes them while the program runs.
a change is used from the next call of a routine or method of the package.
with no argument, this method gives a string, as an options directive, with all the settings of the package.
with one argument, this method gives the setting of that option.
with two arguments, this method sets the option to the second argument, and gives the value it had before.
only the letters in upper in the name of an option are needed; the computer does not use the other letters.
the class method for default options can change the default options of packages that a program loads.
the code:
```rexx
say .context~package~options   -- ::OPTIONS DIGITS 9 FORM SCIENTIFIC FUZZ 0 NUMERIC NOINHERIT ERROR CONDITION FAILURE CONDITION LOSTDIGITS CONDITION NOSTRING CONDITION NOTREADY CONDITION NOVALUE CONDITION PROLOG TRACE NORMAL
```
the result:
```
::OPTIONS DIGITS 9 FORM SCIENTIFIC FUZZ 0 NUMERIC NOINHERIT ERROR CONDITION FAILURE CONDITION LOSTDIGITS CONDITION NOSTRING CONDITION NOTREADY CONDITION NOVALUE CONDITION PROLOG TRACE NORMAL
```
```
All  Condition|Syntax
```
with this option, the new value sets all the options for conditions; it is one of the values after the name.
```
Digits
```
with this option, the new value is a positive whole number; it must be more than the fuzz setting.
```
Error  Condition|Syntax
```
with this option, the new value is one of the values after the name.
```
FAilure  Condition|Syntax
```
with this option, the new value is one of the values after the name.
```
FUzz
```
with this option, the new value is a whole number; it must be less than the digits setting.
```
FOrm  Engineering|Scientific
```
with this option, the new value is one of the values after the name.
```
InitialPackageSettings
```
with this option, you give no new value; this method gives the settings before any change, as an options directive.
```
Lostdigits  Condition|Syntax
```
with this option, the new value is one of the values after the name.
```
NOString  Condition|Syntax
```
with this option, the new value is one of the values after the name.
```
NOTready  Condition|Syntax
```
with this option, the new value is one of the values after the name.
```
NOValue  Condition|Syntax
```
with this option, the new value is one of the values after the name.
```
NUmeric  Inherit|Noinherit
```
with this option, the new value is one of the values after the name.
```
Prolog  Noprolog|Prolog
```
with this option, the new value is one of the values after the name.
```
Reset
```
with this option, you give no new value; this method sets all options to the first settings of the package, and gives the settings before that, as an options directive.
```
SetPackageSettings
```
with this option, the second argument must be a string, as an options directive.
an option that is not in that string gets its default value.
this method gives the settings before the change, as an options directive.
```
Trace  All|Commands|Error|Failure|Intermediates|Labels|Normal|Off|Results
```
with this option, the new value is one of the values after the name.
```
X
```
with this option, you give no new value; this method gives a string with the names of the options that the package set in its code, with a blank between each two.

```
.Package~prolog
```
prolog: the code of a package before its first directive
this method gives a routine object with the prolog of the package.
the code:
```rexx
say .context~package~prolog~source  -- "say .context~package~prolog~source"

::options noprolog
```
the result:
```
say .context~package~prolog~source  -- "say .context~package~prolog~source"
```

```
.Package~publicClasses
```
this method gives a stringtable with all the public classes that this package makes.
the classes method and the method that finds a public class are like this method.
the code:
```rexx
say .package~new("csvstream.cls")~publicClasses~allIndexes -- CSVSTREAM
say .context~package~publicClasses~allIndexes              -- DUMMY
say .rexxinfo~package~publicClasses~items                  -- 56

::class dummy public
```
the result:
```
43.901
```

```
.Package~publicRoutines
```
this method gives a stringtable with all the public routines that this package makes.
each index is a routine name, and each item is a routine object.
the method that finds a public routine is like this method.
the code:
```rexx
say .package~new("csvstream.cls")~publicRoutines~items  -- 0
say .context~package~publicRoutines~allIndexes          -- DUMMY
say .rexxinfo~package~publicRoutines~items              -- 0

::routine dummy public
```
the result:
```
43.901
```

```
.Package~resource(name)
```
resource: lines of data that a resource directive puts in a package
this method gives an array with the lines of the resource with the name in the argument.
if there is no resource with that name, this method gives nil.
the code:
```rexx
say .context~package~resource("GREYCAT")~makeString  -- La nuit, tous les chats sont gris

::resource greyCat
La nuit, tous les chats sont gris
::END
```
the result:
```
La nuit, tous les chats sont gris
```

```
.Package~resources
```
resources: more than one resource
this method gives a stringtable with all the resources of the package.
each index is the name of a resource, and each item is an array of the lines of that resource.
the code:
```rexx
say .context~package~resources~allIndexes  -- "BROWN FOX"
                                           -- "GREYCAT"
::resource greyCat
La nuit, tous les chats sont gris
::END

::resource "brown fox"
The quick brown fox jumps over the lazy dog
::END
```
the result:
```
BROWN FOX
GREYCAT
```

```
.Package~routines
```
this method gives a stringtable with all the routines that this package makes.
each index is a routine name, and each item is a routine object.

```
.Package~setSecurityManager([security_manager_object])
```
this method puts a new security manager in the place of the one there.
the argument is optional; if you omit it, the package has no security manager.
this method is protected.

```
.Package~source
```
this method gives the source of the package, as an array with one dimension; each item is one line of the source.
if the source is not there, this method gives an empty array.

```
.Package~sourceLine(line)
```
this method gives the line of the source with the number in the argument.
if the source is not there, or there is no line with that number, this method gives a null string.

```
.Package~sourceSize
```
this method gives the size of the source of the package.
if the source is not there, this method gives 0.

```
.Package~trace
```
normal: the name of a trace setting
this method gives the first trace setting for all the rexx code in the package.
the default is normal.
the options directive can change this default.

## how to sort an ordered collection

```
sort ordered collections
```
compareto: the name of the method that compares an object to an other object for a sort; it gives negative one, zero, or one
you can sort an ordered collection, as an array with no index without an item, or a list, with the sort method.
the first example sorts an array of strings: the sort method puts the strings in order with the compareto method of the string class.
the compareto method gives negative one when the first string is less, zero when the two are equal, and one when the first string is more.
the code:
```rexx
myArray = .array~of("Zoe", "Fred", "Xavier", "Andy")
myArray~sort

do name over myArray
   say name
end
```
the result:
```
Andy
Fred
Xavier
Zoe
```
the reference says:
```
Andy
Fred
Xavier
Zoe
```

```
.Comparable
```
you can sort objects that are not strings.
you can sort an object if its class inherits the comparable mixin class and has a compareto method.
the rexx classes for a date and a time, and for a length of time, can be sorted in this way.
a class you make can have a compareto method, so its objects can be sorted.
when the sort method compares two instances, it calls the compareto method of one of them with the other as the argument.
the result of the compareto method says which instance goes first.
employee: a name that the example code uses
in the example, the employee class sorts by the id number of the employee.
the code:
```rexx
::class Employee inherit Comparable

::attribute id
::attribute name

::method init
  expose id name
  use arg id, name

::method compareTo
  expose id
  use arg other
  return id~compareTo(other~id) -- comparison performed using employee id

::method string
  expose name
  return "Employee" name
```
the result:
```
```

the code:
```rexx
    a = .array~new
    a[1] = .Employee~new(654321, "Fred")
    a[2] = .Employee~new(123456, "George")
    a[3] = .Employee~new(333333, "William")

    a~sort

    do employee over a
       say employee    -- sorted order is "George", "William", "Fred"
    end
```
the result:
```
97.1
```

```
.Comparator
```
compare: the name of the method of a comparator that compares two items
sortwith: the name of a sort method that uses a comparator
stablesort: the name of a sort method that is stable
stablesortwith: the name of a stable sort method that uses a comparator
the compareto method of the string class gives only one order: from the less to the more, with a strict compare.
the sortwith method can give an other order: its argument is one comparator object.
a comparator has a compare method that compares two items.
you can write a comparator for each way you want to compare items: it needs only a compare method.
rexx has a comparator class that sorts items from the more to the less; it gives the result of the compareto method of the item, with the sign changed.
the last example sorts employee objects by name, not by the id number.
the code:
```rexx
::CLASS 'DescendingComparator' MIXINCLASS Comparator
::METHOD compare
use strict arg left, right
return -left~compareTo(right)
```
the result:
```
```

the code:
```rexx
myArray = .array~of("Zoe", "Fred", "Xavier", "Andy")
myArray~sortWith(.DescendingComparator~new)

do name over myArray
   say name
end
```
the result:
```
Zoe
Xavier
Fred
Andy
```
the reference says:
```
Zoe
Xavier
Fred
Andy
```

the code:
```rexx
::CLASS EmployeeNameSorter MIXINCLASS Comparator
::METHOD compare
  use strict arg left, right
  return left~name~compareTo(right~name)  -- do the comparison using the names
```
the result:
```
```

```
builtin comparators
```
rexx has some comparator classes for ways to sort that you may want to use.
```
Comparator
```
this class is the base comparator: it uses the compareto method of the first argument to get the result.
the sortwith method with an instance of this class is the same as the sort method with no comparator.
```
CaselessComparator
```
this class is like the base comparator, but it uses the caseless compare method of the item, so it can sort strings in a caseless way.
```
ColumnComparator
```
this class sorts strings by the parts of each string at the positions you give.
to sort on more than one part, use the stablesortwith method, so items that are equal keep the order of the sort before.
```
CaselessColumnComparator
```
this class is like the class before it, but it compares the parts in a caseless way.
```
DescendingComparator
```
this class sorts items from the more to the less: the order of the base comparator, from the last to the first.
```
CaselessDescendingComparator
```
this class sorts items from the more to the less, with a caseless compare.
```
InvertingComparator
```
this class changes the sign of the result of an other comparator, so the order of the sort is from the last to the first.
```
NumericComparator
```
this class compares strings with the rules for numbers; use it to sort a collection of numbers.

```
stable sort
```
mergesort: the name of a way to sort that is stable
quicksort: the name of a way to sort that may not be stable
a stable sort keeps items that are equal in the order they had before.
the default sort may not be stable: items that are equal may not keep the positions they had.
the array class has the stablesort method and the stablesortwith method for a stable sort; they use mergesort.
the sort method and the sortwith method use quicksort.
mergesort is stable, but it needs more time than quicksort, and it needs more memory.
the reference also says that the sort method and the stablesort method now use the same stable way to sort.
in the example, three names that are equal in a caseless compare do not keep the order they had.
with the stablesortwith method, the same array keeps the order of these three names.
the code:
```rexx
a = .array~of("Fred", "George", "FRED", "Mike", "fred")
a~sortwith(.caselesscomparator~new)
do name over a
  say name
end
```
the result:
```
Fred
FRED
fred
George
Mike
```
the reference says:
```
Fred
fred
FRED
George
Mike
```

