# the classes of oorexx for files, patterns, tests, and compares

these facts are from the part of the reference about some classes of oorexx: the file class, the class for patterns, the class that tests arguments, the buffer class, and other classes for compares and for objects.

## words i add

singleton: the only instance of a class that can make only one instance
replace: put a new thing in the place of an other thing
access: a use of a thing, as a read or a write
native: native code is code that is not rexx code; the computer runs it, and a rexx program can use it
pointer: a value that says where a thing is in memory
orderable: the name of a mixin class; a class that inherits it gets each compare operator method, and needs only a compareto method
datetime: the name of the class whose objects are a date and a time
identityhash: the name of the method that gives a number that only the receiver has

## the file class

```
.File
```
this class gives ways to use files that are the same on each file system that rexx can use.
a file object is a path to a file or to a directory.
the path can be relative or absolute.
if you make a file object with a relative path, the object gets the absolute path from the current default directory.
the object keeps this absolute path; the path of the object does not change when you change the default directory.
this class inherits the orderable mixin class and the comparable mixin class.

```
.File~isCaseSensitive
```
this method is a class method.
on the unix platform, this method gives true if the root directory is not caseless, and false if it is caseless.
on the windows platform, this method gives true if the system directory of windows is not caseless, and false if it is caseless.
an instance method of this class has the same name; it tests the absolute path of the receiver.

```
.File~listRoots
```
this method is a class method.
this method gives the root directories of the file system, as an array of strings.
on the windows platform, each drive is a root; the string of a root is the letter of the drive, a colon, and a backslash.
on the unix platform, there is only one root: a slash.
the code:
```rexx
/* platform: windows */
say .File~listRoots~toString(, " ")
```
the result:
```
not run: this example is for the windows platform
```

the code:
```rexx
/* platform: unix */
say .File~listRoots~toString(, " ")
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
.File~pathSeparator
```
this method is a class method, and it is also an instance method.
this method gives the separator character that is between two paths in a list of paths for a search.
on the windows platform, this separator is a semicolon.
on the unix platform, this separator is a colon.

```
.File~readChars(filename)
```
this method is a class method.
this method reads all the data of the file whose name is the argument, and gives the data.
the code:
```rexx
filename = "slam_file_test.txt"                     -- setup: a file in this folder
.File~writeChars(filename, "some data", "Replace")  -- setup
data=.File~readChars(filename)
say data
```
the result:
```
some data
```

```
.File~readLines(filename)
```
this method is a class method.
this method reads the lines of text of the file whose name is the argument, puts them in an array, and gives the array.
the code:
```rexx
filename = "slam_file_test.txt"                     -- setup: a file in this folder
.File~writeChars(filename, "some data", "Replace")  -- setup
arr=.File~readLines(filename)
say arr~items
```
the result:
```
1
```

```
.File~searchPath(name [,path])
```
this method is a class method.
this method searches for a file with the name argument as its name, in the directories of the path argument.
if this method finds the file, it gives a new file object for the file.
else this method gives nil.
the name argument must be a valid file name with no wildcard characters.
the name argument can have a relative path in it.
the path argument must be a string, a collection, or an object that has a makearray method.
each part of the path argument must be a valid directory.
the path separator of the platform must be between two parts of the path argument.
if you omit the path argument, the default is the value of the environment variable path.
the code:
```rexx
/* platform: windows */
say .File~searchPath("rexx.exe")
```
the result:
```
not run: this example is for the windows platform
```

the code:
```rexx
/* platform: unix */
say .File~searchPath("rexx")
```
the result:
```
/home/claude/oorexx/usr/local/bin/rexx
```

```
.File~separator
```
this method is a class method, and it is also an instance method.
this method gives the separator character that the file system puts between two names in a path.
on the windows platform, this separator is a backslash.
on the unix platform, this separator is a slash.
the code:
```rexx
/* platform: unix */
file = .File~new("dir1" || .File~separator || "dir2" || .File~separator || "file")
say file~path
```
the result:
```
dir1/dir2/file
```
the reference says:
```
dir1/dir2/file
```

the code:
```rexx
/* platform: windows */
file = .File~new("dir1" || .File~separator || "dir2" || .File~separator || "file")
say file~path
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
dir1\dir2\file
```

```
.File~temporaryPath
```
tmp: the name of an environment variable
temp: the name of an environment variable
userprofile: the name of an environment variable
tmpdir: the name of an environment variable
this method is a class method.
this method gives the absolute path of the temporary directory of the user, as a new file object.
on the windows platform, this method gives the value of the first of the environment variables tmp, temp, and userprofile that has a value.
on the windows platform, if no one of these three variables has a value, this method gives the current directory.
on the unix platform, this method gives the value of the environment variable tmpdir.
on the unix platform, if the environment variable tmpdir has no value, this method gives the directory with the name tmp in the root directory.
the code:
```rexx
/* platform: windows */
say .File~temporaryPath
```
the result:
```
not run: this example is for the windows platform
```

the code:
```rexx
/* platform: unix */
say .File~temporaryPath
```
the result:
```
/tmp
```

```
.File~writeChars(filename, string [,option])
```
this method is a class method.
this method writes the string argument to the file whose name is the first argument.
the third argument is optional; it is the option append or the option replace.
the default is the option append.
the code:
```rexx
filename = "slam_file_test.txt"     -- setup: a file in this folder
string = "some text"                -- setup
.File~writeChars(filename, string)  -- by default appends the string to the file
```
the result:
```
```

```
.File~writeLines(filename, collection [,option])
```
this method is a class method.
this method writes the ordered collection in the collection argument to the file whose name is the first argument.
the third argument is optional; it is the option append or the option replace.
the default is the option append.
with the option replace, the new data takes the place of the data in the file, if the file exists.
the code:
```rexx
filename = "slam_file_test.txt"                   -- setup: a file in this folder
collection = .array~of("line one", "line two")    -- setup
-- write the ordered collection to a text file, replacing its content, if it exists
.File~writeLines(filename, collection, 'Replace')
```
the result:
```
```

```
.File~absoluteFile
```
this method gives the absolute path of the receiver as a new file object.
the code:
```rexx
/* platform: windows */
'cd c:\program files\oorexx'
say .File~new("my file")~absoluteFile~class
say .File~new("my file")~absoluteFile
say .File~new("..\my file")~absoluteFile
say .File~new("..\..\my file")~absoluteFile
say .File~new("..\..\my dir\my file")~absoluteFile
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
The File class
c:\program files\oorexx\my file
c:\program files\my file
c:\my file
c:\my dir\my file
```

the code:
```rexx
/* platform: linux */
'cd /opt/ooRexx'
say .File~new("my file")~absoluteFile
say .File~new("../my file")~absoluteFile
```
the result:
```
/tmp/claude-0/-home-claude/7a454f5a-2610-5341-b35a-ce8fb6712926/scratchpad/runall/slam_examples_2026103074082/run/my file
/tmp/claude-0/-home-claude/7a454f5a-2610-5341-b35a-ce8fb6712926/scratchpad/runall/slam_examples_2026103074082/my file
```
the reference says:
```
/opt/ooRexx/my file
/opt/my file
```

```
.File~absolutePath
```
this method gives the absolute path of the receiver as a string.
the code:
```rexx
/* platform: windows */
'cd c:\program files\oorexx'
say .File~new("my file")~absolutePath~class
say .File~new("my file")~absolutePath
say .File~new("..\my file")~absolutePath
say .File~new("..\..\my file")~absolutePath
say .File~new("..\..\my dir\my file")~absolutePath
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
The String class
c:\program files\oorexx\my file
c:\program files\my file
c:\my file
c:\my dir\my file
```

the code:
```rexx
/* platform: linux */
'cd /opt/ooRexx'
say .File~new("my file")~absolutePath
say .File~new("../my file")~absolutePath
```
the result:
```
/tmp/claude-0/-home-claude/7a454f5a-2610-5341-b35a-ce8fb6712926/scratchpad/runall/slam_examples_2026103074082/run/my file
/tmp/claude-0/-home-claude/7a454f5a-2610-5341-b35a-ce8fb6712926/scratchpad/runall/slam_examples_2026103074082/my file
```
the reference says:
```
/opt/ooRexx/my file
/opt/my file
```

```
.File~canRead
```
this method gives true if the file exists and a program can read it.
else this method gives false.

```
.File~canWrite
```
this method gives true if the file exists and a program can write to it.
else this method gives false.

```
.File~compareTo(other)
```
this method compares the receiver to the other file object, for a sort.
this method compares the absolute paths of the two file objects, as strings.
if the file system is not caseless, the compare is not caseless; else the compare is caseless.
the result is 0 if the two paths are equal.
the result is 1 if the path of the receiver is more than the other path.
the result is negative one if the other path is more than the path of the receiver.
on the windows platform, the two file objects in the next example are the same path, so the result is 0.
the code:
```rexx
/* platform: windows */
call directory .File~listRoots[1]
file1 = .File~new("file", "dir")
file2 = .File~new("FILE", "DIR")
say file1~compareTo(file2)
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
call directory .File~listRoots[1]
file1 = .File~new("file", "dir")
file2 = .File~new("FILE", "DIR")
say file1~compareTo(file2)
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
.File~delete
```
this method deletes the file or the directory at the absolute path of the receiver.
this method can delete a directory only when the directory is empty.
the result is true if this method deletes it, else false.

```
.File~exists
```
this method gives true if the file or the directory at the absolute path of the receiver exists.
else this method gives false.

```
.File~extension
```
this method gives the extension of the file: the part of the file name after the last point.
if the only point in the file name is its first character, the result is a null string.
the code:
```rexx
say .File~new("/usr/local/lib/rexx.img")~extension
say .File~new("c:\windows")~extension
say .File~new(".config")~extension
```
the result:
```
img


```
the reference says:
```
img


```

```
.File~hashCode
```
this method gives a string value; map collections, as a table, a relation, a set, a bag, and a directory, use it as a hash value.

```
.File~init(path [,dir])
```
this method makes a new file object with the path argument as its path.
the method first makes the path normal: it changes each separator to the separator of the platform, and takes away the separator at the end of the path, if there is one.
the second argument is optional; it is a parent path that the method puts before the path argument.
if the second argument is a file object, the method puts the absolute path of that object before the path argument.
else the method puts the second argument before the path argument as it is, after it makes it normal.
you give these arguments to the new method of this class, as the examples show.
the code:
```rexx
/* platform: windows */
file = .File~new("file")
say file~path
file = .File~new("c:\program files\")
say file~path
file = .File~new("file", "c:/program files")
say file~path
'cd c:\program files\oorexx'
samples = .File~new("samples")
say samples~path
file = .File~new("file", "samples")
say file~path
file = .File~new("file", samples)
say file~path
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
file
c:\program files
c:\program files\file
samples
samples\file
c:\program files\oorexx\samples\file
```

the code:
```rexx
/* platform: unix */
file = .File~new("/opt/ooRexx/")
say file~path
'cd /opt/ooRexx'
samples = .File~new("samples")
say samples~path
file = .File~new("file", "samples")
say file~path
file = .File~new("file", samples)
say file~path
```
the result:
```
/opt/ooRexx
samples
samples/file
/tmp/claude-0/-home-claude/7a454f5a-2610-5341-b35a-ce8fb6712926/scratchpad/runall/slam_examples_2026103074082/run/samples/file
```
the reference says:
```
/opt/ooRexx
samples
samples/file
/opt/ooRexx/samples/file
```

```
.File~isCaseSensitive
```
this method is an instance method.
this method gives true if the file or the directory at the absolute path of the receiver is not caseless, and false if it is caseless.
if that file or directory does not exist, this method gives this value for the last directory on the absolute path that exists.
a class method of this class has the same name.

```
.File~isDirectory
```
this method gives true if the absolute path of the receiver is a directory.
else this method gives false.

```
.File~isFile
```
this method gives true if the absolute path of the receiver is a file.
else this method gives false.

```
.File~isHidden
```
hidden: the name of a state of a file or a directory; the next facts say when a file or a directory is in this state
this method gives true if the absolute path of the receiver is a file or a directory that exists and is hidden.
else this method gives false.
on the windows platform, a file or a directory is hidden when its hidden attribute is set.
on the unix platform, a file or a directory is hidden when its name starts with a point, or when the name of one of its parent directories starts with a point.
the reference gives the results of the next example for files that exist.
the code:
```rexx
/* platform: unix */
say .File~new("/tmp/file")~isHidden
say .File~new("/tmp/.file")~isHidden
say .File~new("/tmp/.dir/file")~isHidden
```
the result:
```
0
0
0
```
the reference says:
```
0
1
1
```

```
.File~lastAccessed
```
this method is an attribute method that gets a value.
this method gives the date of the last access to the file or the directory at the absolute path of the receiver.
the result is a datetime object.
the result is nil if the file or the directory does not exist, or if this method can not get the date of the last access.
the date of the last access is not there on all file systems.
ntfs: the name of a kind of file system on the windows platform
on the windows platform, by default the system does not change the date of the last access on a disk of the ntfs kind.
the code:
```rexx
say .File~new(".")~lastAccessed
```
the result:
```
2026-10-30T20:34:42.905357
```

```
.File~lastAccessed=(date)
```
this method is an attribute method that sets a value.
if the file or the directory at the absolute path of the receiver exists, this method sets the date of the last access to it.
else this method does nothing.
the date argument must be a datetime object.

```
.File~lastModified
```
this method is an attribute method that gets a value.
this method gives the date of the last change to the file or the directory at the absolute path of the receiver.
the result is a datetime object.
the result is nil if the file or the directory does not exist, or if this method can not get the date of the last change.
the code:
```rexx
/* platform: windows */
say .File~new("C:\Program Files")~lastModified~class
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
The DateTime class
```

the code:
```rexx
/* platform: windows */
say .File~new("C:\Program Files")~lastModified
say .File~new("dummy")~lastModified
```
the result:
```
not run: this example is for the windows platform
```

```
.File~lastModified=(date)
```
this method is an attribute method that sets a value.
if the file or the directory at the absolute path of the receiver exists, this method sets the date of the last change to it.
else this method does nothing.
the date argument must be a datetime object.
the next example sets the date of the last change of a file to the date of the last change of an other file.
the code:
```rexx
/* A possible implementation of : touch -c -m -r referenceFile file
   -c, --no-create             do not create any files
   -m                          change only the modification time
   -r, --reference=FILE        use this file's time instead of current time
*/
parse arg referenceFilePath filePath .
file = .File~new(filePath)
if \file~exists then
  return 0         -- OK, not an error
referenceFile = .File~new(referenceFilePath)
referenceDate = referenceFile~lastModified
if referenceDate == .nil then
  return 1         -- KO
file~lastModified = referenceDate
return 0           -- OK
```
the result:
```
```

```
.File~length
```
this method gives the size in bytes of the file or the directory at the absolute path of the receiver.

```
.File~list
```
this method gives an array of the names of the files and the directories that are in the directory at the absolute path of the receiver, but not in a subdirectory of it.
the order of the names is the order that the file system gives; it is not always the order of the letters.
the special name that is one point, and the special name that is two point marks, are not in the array.
the result is an array of strings.
if the receiver is not a directory, the result is nil.
the code:
```rexx
/* platform: windows */
names = .File~new("c:\program files\oorexx\samples")~list
say names~toString
```
the result:
```
not run: this example is for the windows platform
```

```
.File~listFiles
```
this method gives an array of the files and the directories that are in the directory at the absolute path of the receiver, but not in a subdirectory of it.
the order of the items is the order that the file system gives; it is not always the order of the letters.
the special name that is one point, and the special name that is two point marks, are not in the array.
the result is an array of file objects.
if the receiver is not a directory, the result is nil.
the code:
```rexx
/* platform: windows */
do file over deepListFiles("c:\program files\oorexx\samples")
    say file
end

-- Depth first iteration
::routine deepListFiles
use strict arg directory, accumulator=(.List~new)
files = .File~new(directory)~listFiles
if files == .nil then return accumulator
do file over files
    accumulator~append(file)
    if file~isDirectory then call deepListFiles file~absolutePath, accumulator
end
return accumulator
```
the result:
```
not run: this example is for the windows platform
```

```
.File~makeDir
```
this method makes only the directory with the last name of the absolute path of the receiver.
this method does not make a parent directory; each parent directory must exist before, or this method can not make the directory.
the result is true if this method makes the directory, else false.
if the directory exists before, the result is false.

```
.File~makeDirs
```
this method makes all the directories of the absolute path of the receiver.
the result is true if this method makes them, else false.
if the directory exists before, the result is false.

```
.File~makeString
```
this method gives the absolute path of the receiver as a string.
this method is an other name for the method that gives the absolute path as a string.

```
.File~name
```
this method gives the name part of the absolute path of the receiver: all the characters after the last path separator.
the extension of the file is a part of the name.
the code:
```rexx
/* platform: windows */
say .File~new("c:\program files\oorexx\rexx.exe")~name
say .File~new("c:\")~name
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
rexx.exe

```

the code:
```rexx
/* platform: unix */
say .File~new("/usr/local/lib/rexx.img")~name
say .File~new("/")~name
```
the result:
```
rexx.img

```
the reference says:
```
rexx.img

```

```
.File~parent
```
this method gives the parent directory part of the absolute path of the receiver, as a string.
if the absolute path has no separator, or if it ends with a separator, this method gives nil.
an absolute path that ends with a separator is a root path.
the code:
```rexx
/* platform: windows */
say .File~new("c:\program files\oorexx\rexx.exe")~parent
say .File~new("c:\")~parent
say .File~new("c:")~parent
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
c:\program files\oorexx
The NIL object
The NIL object
```

the code:
```rexx
/* platform: unix */
say .File~new("/opt/ooRexx/bin/rexx.img")~parent
say .File~new("/")~parent
```
the result:
```
/opt/ooRexx/bin
The NIL object
```
the reference says:
```
/opt/ooRexx/bin
The NIL object
```

```
.File~parentFile
```
this method gives the parent directory part of the absolute path of the receiver, as a file object.
if the absolute path has no separator, or if it ends with a separator, this method gives nil.

```
.File~path
```
this method gives the path that you used to make the file object, after the new method makes it normal.
to make a path normal, the method changes each separator to the separator of the platform, and takes away the separator at the end of the path, if there is one.

```
.File~renameTo(dest)
```
movefile: the name of a function of the system on the windows platform
rename: change the name of a thing; also the name of a function of the system on the unix platform
this method changes the name of the file or the directory at the absolute path of the receiver.
the argument is the new name.
the result is true if this method changes the name, else false.
on the windows platform, this method calls the movefile function of the system to do it.
on the unix platform, this method calls the rename function of the system to do it.

```
.File~setReadOnly
```
this method sets the flag that says that a program can only read the file or the directory at the absolute path of the receiver.

```
.File~setWritable
```
this method clears the flag that says that a program can only read the file or the directory at the absolute path of the receiver.

```
.File~string
```
this method gives a string that says the path that you used to make the file object.

## the class for patterns

```
.RegularExpression
```
this class gives a way to match strings to a pattern.
this class is not a builtin class, and the language does not load it at the start.
to use this class, a program must have a requires directive for the file of this class, as the examples show.
the next example has some patterns, and says in a comment what each one can match.
the code:
```rexx
::requires "rxregexp.cls"

/*
     "(Hi|Hello) World"           Matches "Hi World" and
                                  "Hello World".
     "file.???"                   Matches any file with three
                                  characters after "."
     "file.?{3}"                  Same as above.
     "a *b"                       Matches all strings that begin with
                                  "a" and end with "b" and have an
                                  arbitrary number of spaces in between
                                  both.
     "a +b"                       Same as above, but at least one space
                                  must be present.
     "file.[bd]at"                Matches "file.bat" and "file.dat".
     "[A-Za-z]+"                  Matches any string containing only
                                  letters.
     "[:alpha:]+"                 Same as above, using symbolic names.
     "[^0-9]*"                    Matches any string containing no
                                  numbers, including the empty string.
     "[:digit::lower:]"           A single character, either a digit or
                                  a lower case character.
     "This is (very )+nice."      Matches all strings with one or more
                                  occurrences of "very " between
                                  "This is " and "nice.".
*/
```
the result:
```
```

a pattern can have these parts.
```
|
```
this mark is the or operator between the expression at its left and the expression at its right.
```
?
```
this mark can match any one character.
```
*
```
this mark can match the expression before it zero or more times.
```
+
```
this mark can match the expression before it one or more times.
```
\
```
this mark is an escape: the pattern uses the next character as it is, not as a mark of the pattern.
```
(expression)
```
parentheses make one expression of the part between them; use them where you need them.
```
{n}
```
this part can match the expression before it as many times as the number in it says.
the number must be more than one.
```
[set]
```
this part is a set: it can match any one character of the set.
```
[^set]
```
when this mark is the first character after the open bracket, the set can match any one character that is not in the rest of the set.
```
[a-z]
```
in a set, a dash makes a range from the character before it to the character after it.
a dash after a backslash does not make a range.
if the dash is the first character in the set, it is a dash and not a range.
in a set, you can use these names of sets of characters; each name starts and ends with a colon.
```
:alpha:
```
this set has all the letters, in upper and in lower.
```
:lower:
```
this set has all the letters in lower.
```
:upper:
```
this set has all the letters in upper.
```
:digit:
```
this set has the digits from 0 to 9.
```
:alnum:
```
this set has the characters of the digit set and of the alpha set.
```
:xdigit:
```
this set has the characters of the digit set, and the first six letters in upper and in lower.
```
:blank:
```
this set has the blank and the tab character.
```
:space:
```
this set has the characters with the byte values from 9 to 13, and the blank.
```
:cntrl:
```
this set has the characters with the byte values from 0 to 31, and the character with the byte value 127.
```
:print:
```
this set has the characters with the byte values from 32 to 126.
```
:graph:
```
this set has the characters of the print set, but not the blank.
```
:punct:
```
this set has the characters of the print set that are not the blank and that are not in the alnum set.

```
.RegularExpression~new([pattern] [,option])
```
maximal: the name of an option for a pattern; with it, a match takes as many characters as it can
minimal: the name of an option for a pattern; with it, a match takes as few characters as it can
this method is a class method.
this method makes a new instance of this class.
the pattern argument is optional; it is the pattern that the new object uses to match strings.
the second argument is optional; it is the option maximal or the option minimal.
the default is the option maximal.
the parse method can change the pattern and the option.
this class has an init method; the init method of a subclass of this class must forward to the init method of its superclass, so that the new object is ready.
the code:
```rexx
re1 = .RegularExpression~new
re2 = .RegularExpression~new("Hello?*")

::requires "rxregexp.cls"                 -- setup
```
the result:
```
```

```
.RegularExpression~match(string)
```
this method tries to match the string argument to the pattern that the new method or the parse method set.
with the option maximal, there is a match only if the pattern can match the whole string.
with the option minimal, a match always starts at the first character of the string, but it does not have to go to the end of the string.
so with the option minimal, a match is always a part at the start of the string.
the result is 0 if there is no match, and 1 if there is a match.
the code:
```rexx
str = "<p>Paragraph 1</p><p>Paragraph 2</p>"
re1 = .RegularExpression~new("<p>?*</p>", "MINIMAL")
re1~match(str)
re2 = .RegularExpression~new("<p>?*</p>", "MAXIMAL")
re2~match(str)

say "re1 (minimal) matched" str~substr(1, re1~position)
say "re2 (maximal) matched" str~substr(1, re2~position)

::requires "rxregexp.cls"
```
the result:
```
re1 (minimal) matched <p>Paragraph 1</p>
re2 (maximal) matched <p>Paragraph 1</p><p>Paragraph 2</p>
```
the reference says:
```
re1 (minimal) matched <p>Paragraph 1</p>
re2 (maximal) matched <p>Paragraph 1</p><p>Paragraph 2</p>
```

```
.RegularExpression~parse(pattern [,option])
```
this method sets the pattern of the receiver to the pattern argument, and parses it.
the match method and the pos method use the new pattern.
the second argument is optional; it is the option current, the option maximal, or the option minimal.
the default is the option current: the receiver keeps the option it has now.
the result is 0 if this method parses the pattern with no error.
else the result is an error code.
the code 1 says that the pattern has a symbol at a place where it can not be.
the code 2 says that the pattern has no close parenthesis where it needs one.
the code 3 says that a set in the pattern is not valid.
the code 4 says that the pattern ends at a place where it can not end.
the code 5 says that a number in the pattern is not valid.
the code 6 says that the pattern has the name of a set that is not known.
the code:
```rexx
patterns = "A [:alpha:]{4} fl?*.", -
           "?*[l|e]?*e?*[r|g]?*", -
           "[invalid"
texts = "A nice flower.", -
        "A yellow flower.", -
        "A blue flag."

re = .RegularExpression~new
do pattern over patterns
  code = re~parse(pattern)
  if code == 0 then
    do text over texts
      say text~left(16) -
        re~match(text)~?("matches", "doesn't match") "regex" pattern
    end
  else
    say "error" code "parsing pattern" pattern
  say
end

::requires rxregexp.cls
```
the result:
```
A nice flower.   matches regex A [:alpha:]{4} fl?*.
A yellow flower. doesn't match regex A [:alpha:]{4} fl?*.
A blue flag.     matches regex A [:alpha:]{4} fl?*.

A nice flower.   matches regex ?*[l|e]?*e?*[r|g]?*
A yellow flower. matches regex ?*[l|e]?*e?*[r|g]?*
A blue flag.     matches regex ?*[l|e]?*e?*[r|g]?*

error 3 parsing pattern [invalid

```
the reference says:
```
A nice flower.   matches regex A [:alpha:]{4} fl?*.
A yellow flower. doesn't match regex A [:alpha:]{4} fl?*.
A blue flag.     matches regex A [:alpha:]{4} fl?*.

A nice flower.   matches regex ?*[l|e]?*e?*[r|g]?*
A yellow flower. matches regex ?*[l|e]?*e?*[r|g]?*
A blue flag.     matches regex ?*[l|e]?*e?*[r|g]?*

error 3 parsing pattern [invalid

```

the code:
```rexx
nrs = 1, 42, 0, 5436412, "1A", "f43g"
re = .RegularExpression~new("[1-9][0-9]*")
do nr over nrs
  say nr "is" re~match(nr)~?("a valid", "an invalid") "number"
end
say

-- allow hexadecimal numbers and a single 0
re~parse("0|([1-9a-fA-F][:xdigit:]*)")
do nr over nrs
  say nr "is" re~match(nr)~?("a valid", "an invalid") "number"
end

::requires rxregexp.cls
```
the result:
```
1 is a valid number
42 is a valid number
0 is an invalid number
5436412 is a valid number
1A is an invalid number
f43g is an invalid number

1 is a valid number
42 is a valid number
0 is a valid number
5436412 is a valid number
1A is a valid number
f43g is an invalid number
```
the reference says:
```
1 is a valid number
42 is a valid number
0 is an invalid number
5436412 is a valid number
1A is an invalid number
f43g is an invalid number

1 is a valid number
42 is a valid number
0 is a valid number
5436412 is a valid number
1A is a valid number
f43g is an invalid number
```

```
.RegularExpression~pos(haystack)
```
this method searches for the pattern of the receiver in the argument string; the new method or the parse method set the pattern.
the result is 0 if there is no match, else the position where the match starts.
the position method gives the position where the match ends.
the code:
```rexx
text = "It's the year 2016!"
re = .RegularExpression~new("[1-9][0-9]*")
begin = re~pos(text)
if begin > 0 then
  do
    year = text~substr(begin, re~position - begin + 1)
    say "Found the number" year "in this sentence."
  end

::requires rxregexp.cls
```
the result:
```
Found the number 2016 in this sentence.
```
the reference says:
```
Found the number 2016 in this sentence.
```

```
.RegularExpression~position
```
this method gives the character position where the last parse method, pos method, or match method got to its end.
the code:
```rexx
re = .RegularExpression~new
re~parse("[abc")                       -- illegal set definition
say re~position

re = .RegularExpression~new("[abc]12")
re~match("c12")
say re~position

re~match("a13")                        -- unsuccessful match
say re~position                        -- failure to match

::requires "rxregexp.cls"
```
the result:
```
4
3
2
```
the reference says:
```
4
3
2
```

## the class that tests arguments

```
.Validate
```
this class has class methods that test arguments: if an argument is an instance of a class, if it is true or false, if it is a number, or if it is in a range of numbers.
each method of this class has a name argument: the name of the argument that it tests.

```
.Validate~classType(name, object, class)
```
this method is a class method.
this method tests if the object argument is an instance of the class argument.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~length(name, number [,digits])
```
internaldigits: the name of a value of the language; it is the default of the digits argument of some methods
this method is a class method.
this method tests if the number argument is zero or a positive whole number, with the digits argument as the numeric digits setting.
if you omit the digits argument, the default is internaldigits.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~logical(name, number)
```
this method is a class method.
this method tests if the number argument is true or false.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~nonNegativeNumber(name, number [,digits])
```
this method is a class method.
this method tests if the number argument is zero or a positive rexx number, with the digits argument as the numeric digits setting.
if you omit the digits argument, the default is 9.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~nonNegativeWholeNumber(name, number [,digits])
```
this method is a class method.
this method tests if the number argument is zero or a positive whole number, with the digits argument as the numeric digits setting.
if you omit the digits argument, the default is 9.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~number(name, number)
```
this method is a class method.
this method tests if the number argument is a valid rexx number.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~numberRange(name, number, min, max [,digits])
```
this method is a class method.
this method tests if the number argument is a valid rexx number in the range from the min argument to the max argument.
the compares use the digits argument as the numeric digits setting.
if you omit the digits argument, the default is 9.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~position(name, number [,digits])
```
this method is a class method.
this method tests if the number argument is a positive whole number, with the digits argument as the numeric digits setting.
if you omit the digits argument, the default is internaldigits.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~positiveNumber(name, number [,digits])
```
this method is a class method.
this method tests if the number argument is a positive rexx number, with the digits argument as the numeric digits setting.
if you omit the digits argument, the default is 9.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~requestClassType(name, object, class)
```
this method is a class method.
this method sends a request message to the object argument, to test if it can give an instance of the class argument.
if it can, this method gives that instance.
else this method raises a syntax error for the argument whose name is the name argument.

```
.Validate~positiveWholeNumber(name, number [,digits])
```
this method is a class method.
this method tests if the number argument is a positive whole number, with the digits argument as the numeric digits setting.
if you omit the digits argument, the default is 9.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~wholeNumber(name, number [,digits])
```
this method is a class method.
this method tests if the number argument is a whole number, with the digits argument as the numeric digits setting.
if you omit the digits argument, the default is 9.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

```
.Validate~wholeNumberRange(name, number, min, max [,digits])
```
this method is a class method.
this method tests if the number argument is a valid whole number in the range from the min argument to the max argument.
the compares use the digits argument as the numeric digits setting.
if you omit the digits argument, the default is 9.
if the test is false, this method raises a syntax error for the argument whose name is the name argument.
if the test is true, this method gives no result.

## the buffer class

```
.Buffer
```
an instance of this class is a block of memory; the program that runs the rexx code has control of it.
this class is first for methods and functions that you write in native code.
only native code can make an instance of this class.

```
.Buffer~new
```
this method is a class method.
you can not make an instance of this class with rexx code.
this method raises an error if you use it.

## the pointer class

```
.Pointer
```
an instance of this class has in it a pointer value of native code.
this class is first for methods and functions that you write in native code.
only native code can make an instance of this class.

```
.Pointer~new
```
this method is a class method.
you can not make an instance of this class with rexx code.
this method raises an error if you use it.

```
.Pointer~=(argument)
.Pointer~==(argument)
.Pointer~\=(argument)
.Pointer~><(argument)
.Pointer~<>(argument)
.Pointer~\==(argument)
```
these methods compare the receiver and the argument, and give true or false.
the argument must be an instance of the pointer class.
the first two methods give true if the two objects have the same pointer value.
the other methods give true if the two objects do not have the same pointer value.

```
.Pointer~isNull
```
this method gives true if the pointer value of the receiver is the null pointer: the value 0.
this method gives false if the pointer value is not zero.

## the comparable class

```
.Comparable
```
this class is a mixin class.

```
.Comparable~compareTo(other)
```
this method compares the receiver to the other argument.
this is a default method: it compares the two objects by the number that the identityhash method gives for each of them.
the result is negative one if the other argument is more than the receiver.
the result is 0 if the two objects are equal.
the result is 1 if the other argument is less than the receiver.
a class that inherits this class, as the file class or the datetime class, can forward to this method each compare that its compareto method does not do; the reference says that it is right to do so.

## the comparator classes

there are eight comparator classes for a sort.

```
.Comparator
```
this class is the base class of comparator objects.
you can use a comparator with the sortwith method or the stablesortwith method.
the compare method of a comparator compares two objects, to say the order of them.
a comparator is often only for some kinds of objects.
this class is a mixin class.

```
.Comparator~compare(first, second)
```
this method gives negative one if the second argument is more than the first argument.
this method gives 0 if the two objects are equal.
this method gives 1 if the second argument is less than the first argument.
this default method uses the compareto method of the first argument, so the first argument must have that method.
a subclass can change this method, to compare in a way that is only for some kinds of objects.
the code:
```rexx
wine = .Array~of("Strawberries", "cherries", "angel's kiss")
wine~sortWith(.Comparator~new)
say wine~toString(, ", ")
```
the result:
```
Strawberries, angel's kiss, cherries
```
the reference says:
```
Strawberries, angel's kiss, cherries
```

```
.CaselessComparator
```
this class puts strings in order with a caseless compare.
this class is a mixin class, and it inherits the comparator class.

```
.CaselessComparator~compare(first, second)
```
this method gives negative one if the second argument is more than the first argument.
this method gives 0 if the two objects are equal.
this method gives 1 if the second argument is less than the first argument.
this method compares the two strings with a caseless compare.
the code:
```rexx
wine = .Array~of("Strawberries", "cherries", "angel's kiss")
wine~sortWith(.CaselessComparator~new)
say wine~toString(, ", ")
```
the result:
```
angel's kiss, cherries, Strawberries
```
the reference says:
```
angel's kiss, cherries, Strawberries
```

```
.ColumnComparator
```
this class puts strings in order by a part of each string.
this class is a mixin class, and it inherits the comparator class.

```
.ColumnComparator~compare(first, second)
```
this method gives negative one if the second argument is more than the first argument.
this method gives 0 if the two objects are equal.
this method gives 1 if the second argument is less than the first argument.
this method compares only the part of each string that the init method says.

```
.ColumnComparator~init(start, length)
```
this method makes a new comparator that sorts strings by the part that starts at the position in the start argument and has the count of characters in the length argument.
you give these arguments to the new method of this class, as the example shows.
the code:
```rexx
wine = .Array~of("1. Strawberries", "2. cherries", "3. angel's kiss")
wine~sortWith(.ColumnComparator~new(3, 100))
say wine~toString(, ", ")
```
the result:
```
1. Strawberries, 3. angel's kiss, 2. cherries
```
the reference says:
```
1. Strawberries, 3. angel's kiss, 2. cherries
```

```
.CaselessColumnComparator
```
this class puts strings in order by a part of each string, with a caseless compare.
this class is a mixin class, and it inherits the comparator class.

```
.CaselessColumnComparator~compare(first, second)
```
this method gives negative one if the second argument is more than the first argument.
this method gives 0 if the two objects are equal.
this method gives 1 if the second argument is less than the first argument.
this method compares only the part of each string that the init method says, with a caseless compare.

```
.CaselessColumnComparator~init(start, length)
```
this method makes a new comparator that sorts strings by the part that starts at the position in the start argument and has the count of characters in the length argument.
the code:
```rexx
wine = .Array~of("1. Strawberries", "2. cherries", "3. angel's kiss")
wine~sortWith(.CaselessColumnComparator~new(3, 100))
say wine~toString(, ", ")
```
the result:
```
3. angel's kiss, 2. cherries, 1. Strawberries
```
the reference says:
```
3. angel's kiss, 2. cherries, 1. Strawberries
```

```
.DescendingComparator
```
this class puts strings in the reverse of the order that the comparator class gives.
this class is a mixin class, and it inherits the comparator class.

```
.DescendingComparator~compare(first, second)
```
this method gives 1 if the second argument is more than the first argument.
this method gives 0 if the two objects are equal.
this method gives negative one if the second argument is less than the first argument.
so a sort with this method puts the items in reverse order.
this method uses the compareto method of the first argument, so the first argument must have that method.
the code:
```rexx
wine = .Array~of("Strawberries", "cherries", "angel's kiss")
wine~sortWith(.DescendingComparator~new)
say wine~toString(, ", ")
```
the result:
```
cherries, angel's kiss, Strawberries
```
the reference says:
```
cherries, angel's kiss, Strawberries
```

```
.CaselessDescendingComparator
```
this class puts strings in the reverse of the order that the caseless comparator class gives.
this class is a mixin class, and it inherits the comparator class.

```
.CaselessDescendingComparator~compare(first, second)
```
this method gives 1 if the second argument is more than the first argument.
this method gives 0 if the two objects are equal.
this method gives negative one if the second argument is less than the first argument.
so a sort with this method puts the items in reverse order.
this method compares the two strings with a caseless compare.
the code:
```rexx
wine = .Array~of("Strawberries", "cherries", "angel's kiss")
wine~sortWith(.CaselessDescendingComparator~new)
say wine~toString(, ", ")
```
the result:
```
Strawberries, cherries, angel's kiss
```
the reference says:
```
Strawberries, cherries, angel's kiss
```

```
.InvertingComparator
```
this class changes the results of an other comparator, so that the order of a sort is the reverse order.
this class is a mixin class, and it inherits the comparator class.

```
.InvertingComparator~compare(first, second)
```
this method gives the reverse of the order that the comparator of the init method gives.

```
.InvertingComparator~init(comparator)
```
this method makes a new comparator that sorts strings with the reverse of the result of the compare method of the comparator argument.
the code:
```rexx
wine = .Array~of("1. Strawberries", "2. cherries", "3. angel's kiss")
wine~sortWith(.InvertingComparator~new(.LengthComparator~new))
say wine~toString(, ", ")

-- compare 1. by length, 2. by standard comparison
::class LengthComparator mixinclass Comparator public
::method compare
  use strict arg left, right

  lengthDelta = left~length - right~length
  if lengthDelta = 0 then
    return left~compareTo(right)
  else
    return lengthDelta~sign
```
the result:
```
3. angel's kiss, 1. Strawberries, 2. cherries
```
the reference says:
```
3. angel's kiss, 1. Strawberries, 2. cherries
```

```
.NumericComparator
```
this class compares strings with the rules for numbers, not with the rules for strings.
this class is a mixin class, and it inherits the comparator class.

```
.NumericComparator~compare(first, second)
```
this method gives negative one if the second argument is more than the first argument.
this method gives 0 if the two objects are equal.
this method gives 1 if the second argument is less than the first argument.
this method compares with the rules for numbers, so each string in the collection must be a valid number.

```
.NumericComparator~init([digits])
```
this method makes a new comparator that sorts strings with the rules for numbers.
the digits argument is optional; if you give it, the compares use it as the precision.
the default precision is 9.
the code:
```rexx
primes = .Array~of(23, 19, 17, 13, 11, 7, 5, 3, 2)
primes~sortWith(.NumericComparator~new)
say primes~toString(, ", ")
```
the result:
```
2, 3, 5, 7, 11, 13, 17, 19, 23
```
the reference says:
```
2, 3, 5, 7, 11, 13, 17, 19, 23
```

## the orderable class

```
.Orderable
```
this class is a mixin class.
a class that inherits this class gets each compare operator method, and needs only a compareto method.

```
.Orderable~compareTo(other)
```
this method compares the receiver to the other argument.
this is a default method: it compares the two objects by the number that the identityhash method gives for each of them.
the result is negative one if the other argument is more than the receiver.
the result is 0 if the two objects are equal.
the result is 1 if the other argument is less than the receiver.
a class that inherits this class, as the file class or the datetime class, can forward to this method each compare that its compareto method does not do; the reference says that it is right to do so.

```
.Orderable~=(argument)
.Orderable~\=(argument)
.Orderable~><(argument)
.Orderable~<>(argument)
```
these methods compare the receiver and the argument, and give true or false.
the first method gives true if the two are equal.
the other methods give true if the two are not equal.

```
.Orderable~>(argument)
.Orderable~<(argument)
.Orderable~>=(argument)
.Orderable~\<(argument)
.Orderable~<=(argument)
.Orderable~\>(argument)
```
these methods compare the receiver and the argument, and give true or false.
the first method gives true if the receiver is more than the argument.
the second method gives true if the receiver is less than the argument.
the third method gives true if the receiver is more than the argument or equal to it.
the fourth method gives true if the receiver is not less than the argument.
the fifth method gives true if the receiver is less than the argument or equal to it.
the sixth method gives true if the receiver is not more than the argument.

```
.Orderable~==(argument)
.Orderable~\==(argument)
.Orderable~>>(argument)
.Orderable~<<(argument)
.Orderable~>>=(argument)
.Orderable~\<<(argument)
.Orderable~<<=(argument)
.Orderable~\>>(argument)
```
these methods are the strict compares; each one has a character of its operator two times.
these methods give the same results as the compares that are not strict.
the first method gives true if the two are equal by a strict compare.
the second method gives true if the two are not equal by a strict compare.
the third method gives true if the receiver is more than the argument.
the fourth method gives true if the receiver is less than the argument.
the fifth method gives true if the receiver is more than the argument or equal to it.
the sixth method gives true if the receiver is not less than the argument.
the seventh method gives true if the receiver is less than the argument or equal to it.
the last method gives true if the receiver is not more than the argument.

## the singleton class

```
.Singleton
```
this class is a metaclass: a subclass of the metaclass class.
you can use it for any class, when you want the class to make only one instance: a singleton.
to do this, the class directive must name this class in its metaclass option.
this class is a mixin class.

```
.Singleton~new
```
this method is a class method.
with this metaclass, a class can make only one instance.
after the class makes the singleton, each new message to the class gives that singleton.
this metaclass also gives the singleton a copy method, so a copy message to the singleton gives the same singleton.
in the next example, the test class makes a new instance for each new message, but its subclass with this metaclass gives the same singleton each time.
the hash values in the result are not the same each time the program runs.
the code:
```rexx
#!/usr/bin/env rexx
do clz over .test, .testSingleton   -- iterate over the two classes
   rounds=3
   say "creating" rounds "objects of type:" clz
   do i=1 to rounds
      say "   round #" i":" clz~new -- create new instance
   end
   say
end

/* ========================================================================= */
/** This Test class counts the number of instances that get created for it. */
::class Test
/* ------------- class method and class attribute definitions -------------- */
::method init class -- class constructor
  expose counter
  counter=0          -- make sure attribute is initialized to 0

::attribute counter get private class -- getter method that increases counter
  expose counter     -- access attribute
  counter+=1         -- increase counter by 1
  return counter     -- return new counter value
/* ------------- instance method and instance attribute definitions -------- */
::attribute nr get   -- getter method

::method init        -- constructor that sets the value of attribute nr
  expose nr          -- expose attribute
  nr=self~class~counter -- new instance: fetch new counter from class and save it

::method makestring  -- a string representation of the object
  expose nr          -- expose attribute
                     -- return a string representation
  return "a" self~class~id"[nr="nr",identityHash="self~identityHash"]"

/* ========================================================================= */
/** This class makes sure that only a single instance of it gets created by
*   using Singleton as its metaclass.
*/
::class TestSingleton subclass Test metaclass Singleton
```
the result:
```
creating 3 objects of type: The TEST class
   round # 1: a TEST[nr=1,identityHash=-140265415384209]
   round # 2: a TEST[nr=2,identityHash=-140265415390609]
   round # 3: a TEST[nr=3,identityHash=-140265415397009]

creating 3 objects of type: The TESTSINGLETON class
   round # 1: a TESTSINGLETON[nr=1,identityHash=-140265415439745]
   round # 2: a TESTSINGLETON[nr=1,identityHash=-140265415439745]
   round # 3: a TESTSINGLETON[nr=1,identityHash=-140265415439745]

```
the reference says:
```
creating 3 objects of type: The TEST class
   round # 1: a TEST[nr=1,identityHash=-49085937]
   round # 2: a TEST[nr=2,identityHash=-49089489]
   round # 3: a TEST[nr=3,identityHash=-49093009]

creating 3 objects of type: The TESTSINGLETON class
   round # 1: a TESTSINGLETON[nr=1,identityHash=-49114993]
   round # 2: a TESTSINGLETON[nr=1,identityHash=-49114993]
   round # 3: a TESTSINGLETON[nr=1,identityHash=-49114993]

```

## the class for a reference that the garbage collector can ignore

```
.WeakReference
```
an instance of this class keeps a reference to an other object.
this reference does not stop the garbage collector: when there is no other normal reference to the object, the garbage collector can take the object away, and the uninit method of the object can run.
when the garbage collector can take the object away, the reference in the instance is lost, and the value method gives nil each time after that.
you can use this class to keep a set of objects that you may want again, and the garbage collector can take them away when it needs.

```
.WeakReference~new(object)
```
this method is a class method.
this method gives a new instance of this class with a reference to the object argument.

```
.WeakReference~value
```
this method gives the object of the reference.
if the garbage collector takes the object away, this method gives nil.

## the variable reference class

```
.VariableReference
```
an instance of this class keeps a reference to an other object.
you can make an instance of this class only with a variable reference term, as the examples show.
you can not use the new method to make an instance of this class.

```
.VariableReference~name
```
this method gives the name of the variable of the reference.
the code:
```rexx
variable = 123
say >variable~name
```
the result:
```
VARIABLE
```
the reference says:
```
VARIABLE
```

```
.VariableReference~request(classid)
```
with this method, the receiver can forward the request message to the variable of the reference.

```
.VariableReference~unknown
```
with this method, the receiver can forward to the unknown method of the variable of the reference.

```
.VariableReference~value
```
this method is an attribute method that gets a value.
this method gives the value that the variable of the reference has now.
the code:
```rexx
array = 1, 2, 3

say >array~class~id
say >array~value~class~id

say >array~value~toString(, ", ")
-- this also works because we have an UNKNOWN method
say >array~toString(, ", ")
```
the result:
```
VariableReference
Array
1, 2, 3
1, 2, 3
```
the reference says:
```
VariableReference
Array
1, 2, 3
1, 2, 3
```

```
.VariableReference~value=(object)
```
this method is an attribute method that sets a value.
this method sets the value of the variable of the reference to the object argument.
