# directives

this file has facts from the rules of rexx about directives, as oorexx has them.

```
directives
```
prolog: the code of a package before its first directive
annotate: add a name and a value to a part of a package
requires: needs; also the name of a directive
resource: lines of data in a package after a resource directive; they are not code
resources: more than one resource
interpret: an instruction that runs a string as rexx code
a directive is a clause that does not run.
a directive starts with two colon marks.
a directive can not be in a string that the interpret instruction runs.
directives cut the code of a program in parts.
the first directive ends the prolog.
rexx reads all directives first, and makes the classes, methods, and routines of the package.
then the prolog runs, and it can use all that the directives make.
the directives are annotate, attribute, class, constant, method, options, requires, resource, and routine.
a directive ends at a semicolon, or at the end of the line.

```
::ANNOTATE PACKAGE name value
::ANNOTATE CLASS classname name value
::ANNOTATE ATTRIBUTE attributename name value
::ANNOTATE CONSTANT constantname name value
::ANNOTATE METHOD methodname name value
::ANNOTATE ROUTINE routinename name value
```
annotation: a name and a value that the annotate directive adds to a package, a class, a method, an attribute, a constant, or a routine
annotations: more than one annotation
copy: a new object with the same data as an other object
this directive adds an annotation.
this directive can annotate the package it is in.
this directive can annotate a class, a method, an attribute, a constant, or a routine of the package.
that class, method, attribute, constant, or routine must have its directive in the same package.
the name of an annotation must be a symbol; rexx takes it as a constant.
the name of an annotation can not be a literal.
the value of an annotation can be a literal.
the value of an annotation can be a symbol; rexx takes it as a constant.
the value of an annotation can be a number; an add mark or a subtract mark can be before it.
this directive must come after the directive of the thing it adds an annotation to.
this rule is not for an annotation of the package.
for a method, an attribute, or a constant of a class, this directive must come before the next class directive.
body: the code of a method or a routine, after its directive
this directive ends the body of a method, an attribute, or a routine, so put it after that body.
a subclass does not inherit the annotations of its superclass or of a mixin.
a copy of a method, a package, or a routine keeps its annotations.
this directive can not annotate a thing that rexx gives.
this directive can not annotate a thing from a requires directive.
rexx does not use any annotation name, and it gives no annotation names.
a method can get, add, and change annotations.
the code:
```rexx
::annotate package author "B. Fox"                 -- annotate current package

::class command

::attribute address
::attribute command

::method init
use strict arg command, address = ""
self~command = command
self~address = address

::annotate class command languagelevel "6.05"      -- annotate class COMMAND
::annotate attribute command os "unix windows mac" -- annotate attribute COMMAND
::annotate method init version "100" maxParms 2    -- annotate method INIT
```
the result:
```
```

```
::ATTRIBUTE name [GET | SET] [CLASS] [PUBLIC | PRIVATE | PACKAGE]
            [UNGUARDED] [PROTECTED | UNPROTECTED]
            [ABSTRACT] [DELEGATE delegatename] [EXTERNAL "spec"]
```
abstract: a method or a class is abstract when you can not use it as it is; a subclass must give what it does not have
delegate: an other object that gets the messages that an object does not run
protected: a word for a method with the protected option
unprotected: not protected
library: a file with functions and methods that are not rexx code
this directive makes the methods of an attribute.
the name is a literal or a symbol; rexx takes it as a constant.
the name must be a name that a rexx variable can have.
you can give the options in any order.
without get and without set, this directive makes two methods: a get method and a set method.
the get method has the name of the attribute.
the set method has the name of the attribute with an equal mark after it.
the two methods have the same options.
with get or with set, this directive makes only that one method.
you can use two of these directives, one with get and one with set, so each method has other options.
with get or with set, you can write a body after the directive, in place of the default code.
without a body, an other directive or the end of the program must come after this directive.
rexx makes the methods in the class of the last class directive before this directive.
with the class option, the methods are class methods.
the class option needs a class directive before this directive; if there is no class directive, it is an error.
without a class directive before it, the methods are not a part of a class; code can get them by the point methods object.
without a class directive, only one of these directives can have the same name.
in a class, it is an error if two of these directives make the same get method or the same set method.
the public option makes the methods public; public is the default.
the private option makes the methods private.
the package option makes the methods known only in the package.
without the unguarded option, the methods are guarded: each must have the variable pool of its object only for it while it runs.
with the unguarded option, the methods can run while other methods of the object run.
the protected option makes the methods protected.
unprotected is the default.
the abstract option makes the methods abstract; there is no body.
it is an error to run an abstract method.
the delegate option sends each message of the two methods to the delegate object that you name.
the external option says that the methods are in a library.
the first word of the external string must be library.
the second word of the external string is the name of the library.
on some kind of computer, the name of the library is not caseless.
the third word of the external string is the name of the method in the library; it is optional.
the name of the method in the library is caseless.
with external and without get and set, the get method is the word get and then the name, in the library.
with external and without get and set, the set method is the word set and then the name, in the library.
with external and with get or set, and with no third word, the method in the library is the name and then the word get or set.
with external and with get or set, and with a third word, the method in the library is that third word.
the code:
```rexx
::method name         -- attribute get method
  expose name         -- establish direct access to object variable (attribute)
  use strict arg      -- enforce zero parameters
  return name         -- return object variable's current value

::method "NAME="      -- attribute set method
  expose name         -- establish direct access to object variable (attribute)
  use strict arg name -- retrieve argument and assign it to the object variable

::attribute size get
::attribute size set
  expose size     /* establish direct access to object variable (attribute) */
  use arg value   /* retrieve argument                                      */
  if datatype(value, "Whole") = .false | value < 0  then
    raise syntax 93.906 array ("size", value)
  size=value

::method name
expose delegateName
forward to(delegateName)

::method "NAME="
expose delegateName
forward to(delegateName)

-- maps "NAME" method to "GETNAME and
-- "NAME=" to "SETNAME"
::ATTRIBUTE name EXTERNAL "LIBRARY mylib"
-- maps "ADDRESS" method to "GETADDRESS"
::ATTRIBUTE address GET EXTERNAL "LIBRARY mylib"
-- maps "ADDRESS=" method to "setHomeAddress"
::ATTRIBUTE address SET EXTERNAL "LIBRARY mylib setHomeAddress"
```
the result:
```
99.902
```

```
::CLASS classname [PUBLIC] [METACLASS metaclass] [SUBCLASS sclass]
      [MIXINCLASS mclass] [ABSTRACT] [INHERIT iclasses]
```
mixinclass: an option of the class directive; the class you name after it is the superclass
namespace: a name for a package that you put with a colon before the name of a class or a routine of that package
this directive makes a class.
the class name is a literal or a symbol; rexx takes it as a constant.
code can use the class by a point and the class name, as an environment symbol.
each method directive after this directive makes a method of this class, until the next class directive or the end of the program.
between this directive and the next directive, there can be only a comment or a line with no code.
only one of these directives can have the same class name in a program.
rexx reads directives in order.
if a class needs a class from a class directive after it, rexx makes it after the class it needs.
you can give the metaclass, subclass, mixinclass, and public options in any order.
the inherit option must be the last option.
the metaclass option names a class; the methods of each instance of that class are class methods of this class.
the name after the metaclass option is a literal or a symbol, and can have a namespace; rexx takes it as a constant.
to find a class method, rexx tests the methods of the metaclass after the class methods from method directives with the class option.
to find a class method, rexx tests the methods of the metaclass before the class methods that the class inherits.
the public option makes the class known to other programs that use this program by a requires directive.
without the public option, the class is known only in its program.
the subclass option makes the class a subclass of the class you name, so it inherits its methods and class methods.
the name after the subclass option is a literal or a symbol, and can have a namespace; rexx takes it as a constant.
the mixinclass option makes the class a subclass of the class you name, so it inherits its methods and class methods.
the name after the mixinclass option is a literal or a symbol, and can have a namespace; rexx takes it as a constant.
you can add the methods of a mixinclass class to other classes by the inherit option, or by an inherit message to a class.
the inherit option gives a list of classes with blanks between them.
each name in the inherit list is a literal or a symbol, and can have a namespace; rexx takes it as a constant.
the class inherits methods and class methods from each class in the inherit list, in order, the first at the left first.
the inherit option is the same as a list of inherit messages to the class object.
in these messages, each message after the first gives the class before it in the list as the class position argument.
each class in the inherit list must be a mixin.
without the inherit option, the class inherits only from the class of the subclass option.
without the subclass option and the mixinclass option, the class is a subclass of the object class, and it is not a mixin.
the abstract option makes the class abstract.
to make an instance of an abstract class is an error.
only a subclass of an abstract class can make instances.
the code:
```rexx
::class rectangle
::method area    /* defined for the RECTANGLE class */
  expose width height
  return width*height

::class triangle
::method area    /* defined for the TRIANGLE class */
  expose width height
  return width*height/2

::class savings subclass account  /* requires the ACCOUNT class */
::method type
  return "a Savings Account"

::class account
::method type
  return "an Account"
```
the result:
```
```

```
::CONSTANT name [value]
```
this directive makes a method that returns a constant value.
the name is a literal or a symbol; rexx takes it as a constant.
the value can be a literal.
the value can be a symbol; rexx takes it as a constant.
the value can be a number; an add mark or a subtract mark can be before it.
the value can be an expression in parentheses.
if you omit the value, the method returns the name in upper.
with a class directive before it, rexx makes the method as a method of each instance and as a class method of the last class.
a class directive is not a need.
floating: a method is floating when no class directive is before its directive; it is not a part of a class
without a class directive, this directive makes one floating method; code can get it by the point methods object.
only one of these directives can make a floating method with the same name.
the methods this directive makes are unguarded.
you can use the method by the class object or by an instance.
this directive can not have a body.
an expression in parentheses can use the value of an other constant.
an expression in parentheses can use an other constant with an expression only if that constant is before it.
a floating constant can not have an expression in parentheses.
the value of a floating constant must be a literal, a symbol, or a number.
the code:
```rexx
::class MathConstants public
::constant pi 3.14159265
::constant author "Isaac Asimov"
::constant absolute_zero -273.15
::constant e ( rxcalcexp(1) )
::constant eSquare (self~e ** 2)
::constant primes (2, 3, 5, 7, 11, 13)

::class Search
::constant caseless

::requires rxmath library

say "Pi is" .MathConstants~pi    -- displays "Pi is 3.14159265"
instance = .MathConstants~new
say "Pi is" instance~pi          -- also displays "Pi is 3.14159265"

say .Search~caseless             -- "CASELESS"

::class MathConstants public
::constant pi 3.14159265

::class Search
::constant caseless
```
the result:
```
99.916
```

```
::METHOD methodname [CLASS] [PUBLIC | PRIVATE | PACKAGE] [UNGUARDED]
            [PROTECTED | UNPROTECTED] [ATTRIBUTE] [ABSTRACT]
            [DELEGATE delegatename] [EXTERNAL "spec"]
```
this directive makes a method.
the method name is a literal or a symbol; rexx takes it as a constant.
you can give the options in any order.
with a class directive before it, the method is a part of the last class.
without a class directive before it, the method is floating; the prolog can get it by the point methods object.
the class option makes a class method.
the class option needs a class directive before this directive; if there is no class directive, it is an error.
the public option makes the method public; public is the default, and any caller can use the method.
the private option makes a private method; not each caller can use it.
the package option makes a package method; not each caller can use it.
without the unguarded option, a method is guarded: it must have the variable pool of its object only for it while it runs.
with the unguarded option, the method can run while other methods of the same object run.
the protected option makes the method protected.
unprotected is the default.
the attribute option makes a get method with the method name and a set method with the method name and an equal mark.
the attribute option is the same as the attribute directive.
the abstract option makes a method that a subclass must give; it has no body.
syntax: the rules of the language about the order of words and marks in code; also the name of the condition that is raised for an error in code
if you run an abstract method, a syntax condition is raised.
the delegate option makes the method send its message to the delegate object that you name.
forward: an instruction that sends the message again, to an other object
the delegate option is the same as an expose of the delegate and a forward to the delegate.
the external option says that the method is in a library.
the first word of the external string must be library.
the second word of the external string is the name of the library.
on some kind of computer, the name of the library is not caseless.
the third word of the external string is the name of the method in the library; it is optional.
if you omit the third word, rexx uses the method name.
the name of the method in the library is caseless.
with the attribute option and the external option, the get method is the word get and then the name, and the set method is the word set and then the name.
the body of a method is the code after this directive, until the next directive or the end of the program.
the line of this directive is not a part of the code of the method.
with the attribute, abstract, or external option, there is no body; an other directive or the end of the program must come after this directive.
in a class, it is an error if two of these directives have the same name.
only one floating method can have the same name.
the code:
```rexx
r = .rectangle~new(20,10)
say "Area is" r~area       /* Produces "Area is 200" */

::class rectangle

::method area              /* defined for the RECTANGLE class */
  expose width height
  return width*height

::method init
  expose width height
  use arg width, height

::method perimeter
  expose width height
  return (width+height)*2

::method name
expose delegateName
forward to(delegateName)

-- creates method INIT from method RegExp_Init in library rxregexp
::METHOD INIT EXTERNAL "LIBRARY rxregexp RegExp_Init"

-- creates method RegExp_Parse from library rxregexp
::METHOD RegExp_Parse EXTERNAL "LIBRARY rxregexp"

-- maps "NAME" method to "GETNAME and
-- "NAME=" to "SETNAME"
::METHOD name ATTRIBUTE EXTERNAL "LIBRARY mylib"

-- maps "ADDRESS" method to "GETMyAddress and
-- "ADDRESS=" to "SETMyAddress"
::METHOD address ATTRIBUTE EXTERNAL "LIBRARY mylib MyAddress"
```
the result:
```
99.902
```

```
::OPTIONS option value [option value ...]
::OPTIONS DIGITS digits
::OPTIONS FORM SCIENTIFIC | ENGINEERING
::OPTIONS FUZZ fuzz
::OPTIONS NUMERIC INHERIT | NOINHERIT
::OPTIONS TRACE setting
::OPTIONS ALL SYNTAX | CONDITION
::OPTIONS ERROR | FAILURE | LOSTDIGITS | NOSTRING | NOTREADY | NOVALUE  SYNTAX | CONDITION
::OPTIONS PROLOG | NOPROLOG
```
sets: set, for one thing
numeric: about numbers; also the name of an instruction that sets the rules of maths
fuzz: the count of digits at the right of a number that a compare of numbers ignores
this directive sets the default values of numeric, trace, and other rules for all rexx code in a package.
one directive can have many options, in any order.
rexx reads these directives in order; each one adds its values to the values of the directives before it.
if two options set the same thing, rexx uses the last one.
the options change only the code in the same file.
the options do not change code in other files that use this code.
a subclass in an other package does not inherit them.
the options set only the values at the start; code can change them when it runs, as with the numeric digits instruction.
the digits option sets the precision of maths and of builtin functions.
the digits value must be a positive whole number, as a symbol or a string.
the digits value must be more than the fuzz value.
there is no maximum digits value but the memory; with more digits, maths takes more time.
form: the way rexx puts a number with an exponent in a string
scientific: a form where one digit that is not zero is before the point
engineering: a form where the exponent is three times a whole number
the form option sets the form of numbers in the results of maths and builtin functions.
the form value is scientific or engineering, as a symbol.
the default form is scientific.
the fuzz option sets the fuzz.
the fuzz value must be a positive whole number, as a symbol or a string.
the fuzz value must be less than the digits value.
to compare two numbers, rexx takes the difference of the two numbers with a precision of the digits value subtract the fuzz value, and compares the result with zero.
noinherit: not inherit
the numeric option says if routines and methods in the package inherit the numeric values of the caller.
the numeric value is inherit or noinherit, as a symbol.
the default numeric value is noinherit.
failure: the name of a condition
lostdigits: the name of a condition
nostring: the name of a condition
notready: the name of a condition
novalue: the name of a condition
the error, failure, lostdigits, nostring, notready, and novalue options each say what condition is raised for its event.
with the value condition, the condition of that name is raised; this is the default.
with the value syntax, a syntax condition is raised in place of it.
the all option sets all six of these options to the same value.
the all option with syntax makes all six raise a syntax condition.
the all option with condition gives all six the default.
signal on, signal off, signal on any, and signal off any can change this for all six.
call on, call off, call on any, and call off any can change this only for error, failure, and notready.
noprolog: the prolog does not run
the prolog option says the prolog runs when an other program needs this program by a requires directive; this is the default.
the noprolog option says the prolog does not run then.
the trace option sets what trace rexx gives while the code of the package runs.
the trace value is one of the options that the trace instruction can have.
the options method of the package class can get and set each of these values.
the digits, form, fuzz, and trace methods of the package class can get these values.
the code:
```rexx
::OPTIONS DIGITS 20
::OPTIONS ALL SYNTAX
::OPTIONS ALL CONDITION
```
the result:
```
```

```
::REQUIRES programname [LIBRARY] [NAMESPACE namespace]
```
this directive says that this program needs an other program.
the program name is a literal or a symbol; rexx takes it as a constant.
the program name must be a name that a call instruction can use.
with the library option, the name is a library, not a rexx program.
on some kind of computer, the name of the library is not caseless.
if rexx can not get the library, the program can not run.
rexx reads each of these directives with the library option before the other directives of this kind, so the prolog of a package can use the library.
the namespace option gives a namespace to the package that this program needs.
the namespace must be a symbol; rexx takes it as a constant; it can not be a literal.
code can name a public class or a public routine of that package with the namespace, a colon, and the name.
without the library option, this program can use all public classes and public routines of the program it needs.
rexx calls the program it needs as an external routine with no arguments.
rexx gets that program in the order it uses to find external programs.
the prolog of the program it needs runs when rexx reads this directive, before the prolog of this program.
these directives can be at any place after the prolog.
the order of these directives is the order rexx uses to find classes and routines, and the order in which it gets the files.
an other directive or the end of the program must come after this directive; only a comment or a line with no code can be between them.
rexx gets a program only one time; each other requires directive for the same program uses what rexx has.
the prolog of the program runs only the first time.
a local routine is used before a routine with the same name from this directive.
a local class is used before a class with the same name from this directive.

```
::RESOURCE name [END delimiter]
resource data
...
delimiter
```
this directive gives lines of data a name.
the name is a literal or a symbol; rexx takes it as a constant.
the lines of data come after the directive.
the end option gives the line that ends the data; it is a literal or a symbol.
if you omit the end option, the data ends at a line with two colon marks and the word end.
the data can be one or more lines of any kind of text, also rexx code.
if the directive ends with a semicolon, rexx ignores the text after the semicolon on that line.
the end line must start at the first position of the line.
the end line is not caseless.
rexx ignores the text after the end string on that line.
each resource name can be used only one time; the same name in two of these directives is an error.
special characters, as the end of a line or the end of a file, in the data can give results you do not want.
binary data in a resource can give results you do not want.
code can get the data by the point resources object.
code can get the data by the resource method and the resources method of the package class.
the code:
```rexx
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
```
the result:
```
```

```
::ROUTINE routinename [PUBLIC | PRIVATE] [EXTERNAL "spec"]
```
this directive makes a routine.
the routine name is a literal or a symbol; rexx takes it as a constant.
only one of these directives can have the same name in a program; two is an error.
if the same name is in two programs, rexx uses the last one.
the public option makes the routine known to each program that uses this program by a requires directive.
with the private option, or with no option, the routine is known only in its program.
a local routine is used before a routine with the same name from a requires directive; this is not an error.
without the external option, the body of the routine ends at the next directive or at the end of the program.
registered: the name of a kind of external routine
the external option gives a string of words; the first word is library or registered.
with library, the second word is the name of the library.
with library, the third word is the name of the routine in the library; it is optional.
if you omit the third word, rexx uses the routine name.
the name of the routine in the library is caseless.
with registered, the second word is the name of the library.
with registered, the third word is the name of the function; it is optional.
with registered, if you omit the third word, rexx uses the routine name.
with registered, rexx can try the name as it is, and the name in upper.
on some kind of computer, the name of the library is not caseless.
a routine of this directive runs as an external routine.
to find a routine, rexx tests internal routines and builtin functions first, then these routines, then other external routines.
when a routine runs, it can not use the variables of the caller.
when a routine runs, the numeric values start at the default.
the code:
```rexx
::class c
::method a
call r "A"  /* displays "In method A" */

::method b
call r "B"  /* displays "In method B" */

::routine r
use arg name
say "In method" name

-- load a function from rxmath library
::routine RxCalcPi external "LIBRARY rxmath"
-- same function, but a different internal name
::routine Pi external "LIBRARY rxmath RxCalcPi"
-- same as call rxfuncadd "SQLLoadFuncs", "rexxsql", "SQLLoadFuncs"
::routine SQLLoadFuncs EXTERNAL "REGISTERED rexxsql SQLLoadFuncs"
```
the result:
```
```

