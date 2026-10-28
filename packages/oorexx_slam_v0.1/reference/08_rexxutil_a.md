# rexx functions for files and the system first part

this file is from the rules of the oorexx language about a package of functions for files and the system: the first part of the list of functions.

## words i add here

current: the one in use now
shows: show, for one thing
screen: the place where a computer can show text to you
window: a part of the screen where a program can show text
drives: more than one drive
directories: more than one directory
codes: more than one code
computers: more than one computer
users: more than one user
tails: more than one tail
handles: more than one handle
works: work, for one thing
different: not the same
cursor: the mark on the screen that says where the next character goes
row: one line of the screen
column: a position in a row of the screen
top: the first part of the screen; a window is on top when no other window is on it
clear: make empty; take away all that is in it
clears: clear, for one thing
key: a thing you push to give a character to a program
keys: more than one key
pushes: push, for one thing
enter: the name of a key; you push it at the end of a line
escape: the name of a key
button: a part of a window that a user can push
buttons: more than one button
title: the name of a window; the window shows it
icon: a mark in a window that says the kind of message
style: one of the ways a thing can be
stays: is there and does not go away
yes: the word you say when a thing is true
ok: a word that says yes
cancel: stop a thing and not do it
abort: stop a thing before its end
retry: try again
continue: go on
hides: makes a thing not shown
minimize: make a window take the least place on the screen
minimizes: minimize, for one thing
minimized: a window is minimized when it takes the least place on the screen
maximized: a window is maximized when it takes the whole screen
search: try to find
searches: search, for one thing
exist: be there
exists: exist, for one thing
loaded: a thing is loaded when you load it
wildcard: a mark in a file name, as a star or a question mark, that can match other characters
home: the home directory of a user is the directory where the user keeps files
subdirectory: a directory in an other directory
subdirectories: more than one subdirectory
move: change the place of a thing
moves: move, for one thing
deletes: delete, for one thing
remote: on an other computer
network: computers that can send data to each other
share: let more than one use the same thing
valid: a thing is valid when it is as the rules say
dos: the name of a system for computers
fat: the name of a kind of file system
cdrom: a kind of disk drive
pipe: a stream between two programs; what one program writes to it, the other program reads
parent: the process that makes an other process
child: the process that an other process makes
macrospace: a place in memory where rexx keeps routines that each program can call
codepage: a table that gives the character for each byte or set of bytes; each codepage has a name or a number
codepages: more than one codepage
unicode: a way to store the characters of all languages as bytes
console: the window of a shell
thread: one of the parts of a process that can run at the same time
separate: not a part of an other thing
catalog: a file of messages where each message has a number
ampersand: the name of a mark
long: not short
application: a program that a user runs
applications: more than one application
ini: a kind of text file on windows that keeps keywords and their values for each application name
compressed: a file is compressed when the system stores it in less bytes
encrypted: a file is encrypted when the system stores it so that only some users can read it
link: a name in a directory for a file or a directory that has an other name
device: a part of a computer that the system can read from or write to, as a disk
mask: a string where each position says a rule for one attribute

## the package

```
RexxUtil
```
rexxutil: a package of functions for the windows platform and the unix platforms
its functions work with the files and the directories of the system.
some of its functions work with the classes and the objects of windows.
some of its functions read text from the screen and write text to the screen.
all these functions are registered when rexx starts, so a program does not have to make them registered.
some of these functions run only on one platform; each part of this file says which.
some of these functions give an error code of the system when there is an error.

## the functions

```
RxMessageBox(text [,title] [,button] [,icon] [,option])
```
rxmessagebox: a function that shows a window with a message and buttons
this function runs only on the windows platform.
this function shows a window with the text argument and one or more buttons.
it uses a function of windows to show the window.
the title argument is the title of the window.
the default title is the word error.
the third argument is the style of the buttons.
the default style is ok.
```
RxMessageBox(text, title, 'OK')
```
with this style, the window has one button: ok.
```
RxMessageBox(text, title, 'OKCANCEL')
```
with this style, the window has an ok button and a cancel button.
```
RxMessageBox(text, title, 'RETRYCANCEL')
```
with this style, the window has a retry button and a cancel button.
```
RxMessageBox(text, title, 'ABORTRETRYIGNORE')
```
with this style, the window has an abort button, a retry button, and an ignore button.
```
RxMessageBox(text, title, 'CANCELTRYCONTINUE')
```
with this style, the window has a cancel button, a try again button, and a continue button.
the reference says to use this style in place of the style before it.
```
RxMessageBox(text, title, 'YESNO')
```
with this style, the window has a yes button and a no button.
```
RxMessageBox(text, title, 'YESNOCANCEL')
```
with this style, the window has a yes button, a no button, and a cancel button.
the fourth argument says which icon the window shows.
by default, the window shows no icon.
```
RxMessageBox(text, title, button, 'NONE')
```
with this value, the window shows no icon.
```
RxMessageBox(text, title, button, 'INFORMATION')   or 'ASTERISK'
```
these two values give the same icon.
```
RxMessageBox(text, title, button, 'WARNING')   or 'EXCLAMATION'
```
these two values give the same icon; it is an exclamation mark.
```
RxMessageBox(text, title, button, 'ERROR')   or 'HAND' or 'STOP'
```
these three values give the same icon.
```
RxMessageBox(text, title, button, 'QUESTION')   or 'QUERY'
```
these two values give the same icon; it is a question mark.
the reference says not to use this icon now.
the fifth argument can have more than one of these options.
```
RxMessageBox(text, title, button, icon, 'DEFBUTTON2')
```
with this option, the second button is the default button.
```
RxMessageBox(text, title, button, icon, 'DEFBUTTON3')
```
with this option, the third button is the default button.
```
RxMessageBox(text, title, button, icon, 'DEFBUTTON4')
```
with this option, the fourth button is the default button.
if you give no one of these three options, the first button is the default button.
```
RxMessageBox(text, title, button, icon, 'RIGHT')
```
with this option, the text is at the right of the window.
```
RxMessageBox(text, title, button, icon, 'TOPMOST')
```
with this option, the window stays on top of the other windows, also when it is not active.
the result says which button the user pushes.
the result is 1 when the user pushes the ok button.
the result is 2 when the user pushes the cancel button.
the result is 3 when the user pushes the abort button.
the result is 4 when the user pushes the retry button.
the result is 5 when the user pushes the ignore button.
the result is 6 when the user pushes the yes button.
the result is 7 when the user pushes the no button.
the result is 10 when the user pushes the try again button.
the result is 11 when the user pushes the continue button.
the result is 0 when that function of windows has an error.
if the window has a cancel button, the escape key gives 2.
if the window has no cancel button, the escape key does nothing, but when the window has an ok button, the escape key gives 1.
the code:
```rexx
/* platform: windows */
-- Give option to quit
if RxMessageBox("Shall we continue?", "", "YesNo", "Question") = 7
  then exit  -- "No" button clicked, exit
```
the result:
```
not run: this example is for the windows platform
```

```
RxWinExec(cmdline, cmdshow)
```
rxwinexec: a function that runs a program on windows
this function runs only on the windows platform.
the first argument is a string with the name of a program file, and the arguments of the program.
the arguments of the program are optional.
if the name of the program file has no path, the function searches for it in these places, in this order.
first, the directory that oorexx was loaded from.
second, the current directory.
third, the system directory of windows.
fourth, the directory of windows.
fifth, the directories in the path variable of the environment.
the second argument says how windows shows the window of the program.
```
RxWinExec(cmdline, 'SHOWNORMAL')
```
with this value, windows makes the window active and shows it.
```
RxWinExec(cmdline, 'SHOWNOACTIVATE')
```
with this value, windows shows the window, and the window that is active stays active.
```
RxWinExec(cmdline, 'SHOWMINNOACTIVE')
```
with this value, windows shows the window minimized, and the window that is active stays active.
```
RxWinExec(cmdline, 'SHOWMINIMIZED')
```
with this value, windows makes the window active and shows it minimized.
```
RxWinExec(cmdline, 'SHOWMAXIMIZED')
```
with this value, windows makes the window active and shows it maximized.
```
RxWinExec(cmdline, 'HIDE')
```
with this value, windows hides the window and makes an other window active.
```
RxWinExec(cmdline, 'MINIMIZE')
```
with this value, windows minimizes the window and makes the next window active.
if there is no error, the result is the process id of the program.
if there is an error, the result is less than 32.
the error codes are system error codes of windows.
if an error code is more than 32, the function gives it as a negative number, so that it is not the same as a process id.
the code 2 says that the file is not found.
the code 3 says that the path is not found.
the code 11 says that the program file is not valid.
the code -53 says that the path on the network is not valid.

```
SysAddRexxMacro(name, file [,order])
```
sysaddrexxmacro: a function that adds a routine to the macrospace
this function adds a routine to the macrospace of rexx.
the name argument is the name of the function in the macrospace.
the file argument is the file with the rexx program.
the third argument is the search order of the macrospace.
```
SysAddRexxMacro(name, file, 'B')   Before
```
with this value, the order is before.
this is the default order.
```
SysAddRexxMacro(name, file, 'A')   After
```
with this value, the order is after.
the result is the return code of the rexx function that adds a routine to the macrospace.

```
SysBootDrive()
```
sysbootdrive: a function that gives the drive that windows starts from
this function runs only on the windows platform.
this function gives the drive that the computer used to start windows.

```
SysClearRexxMacroSpace()
```
sysclearrexxmacrospace: a function that clears the macrospace
this function clears the macrospace of rexx.
the result is the return code of the rexx function that clears the macrospace.

```
SysCls()
```
syscls: a function that clears the screen
this function clears the screen.
the code:
```rexx
call SysCls
```
the result:
```
```

```
SysCreatePipe()
```
syscreatepipe: a function that makes a pipe
this function runs only on the unix platform.
this function makes a pipe that has no name.
the result is a string of two handles with a blank between them.
the first handle is for read, and the second handle is for write.

```
SysCurPos([row, col])
```
syscurpos: a function that gives the position of the cursor and can move the cursor
this function runs only on the windows platform.
this function gives the position of the cursor as the row, a blank, and the column.
the first argument is the row to move the cursor to.
the second argument is the column to move the cursor to.
the row 0 and the column 0 are at the top left of the screen.
if you omit the row and the column, the function gives the position of the cursor and does not move the cursor.
the reference gives the result of this example only as one result that you can get.
the code:
```rexx
/* platform: windows */
say SysCurPos() -- (e. g.) 10 0
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
10 0
```

```
SysCurState(state)
```
syscurstate: a function that shows or hides the cursor
this function runs only on the windows platform.
the state argument is the new state of the cursor.
```
SysCurState('ON')
```
with this value, the function shows the cursor.
```
SysCurState('OFF')
```
with this value, the function hides the cursor.

```
SysDriveInfo([drive])
```
sysdriveinfo: a function that gives facts about a drive
this function runs only on the windows platform.
the result has four words: the drive, the count of bytes that are not in use, the count of all bytes of the drive, and the name of the disk.
if the function cannot use the drive, the result is the null string.
the drive argument is a drive or a path on the network.
if you omit the drive argument, the function uses the current drive.
the reference gives the result of this example only as one result that you can get.
the code:
```rexx
/* platform: windows */
say SysDriveInfo() -- e. g. C: 23989809152 254721126400 Windows
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
C: 23989809152 254721126400 Windows
```

```
SysDriveMap([drive] [,opt])
```
sysdrivemap: a function that gives a list of drives
this function runs only on the windows platform.
the result is a list of drives with a blank between each two drives.
the first argument is the first drive of the list.
the second argument is an option that says which drives are in the list.
if you omit the two arguments, the function does the same as this code.
```
SysDriveMap()   same as   SysDriveMap("C:", "USED")
```
```
SysDriveMap(drive, 'USED')
```
with this option, the list has the drives that you can use or that are in use, on this computer and on other computers.
this is the default option.
```
SysDriveMap(drive, 'FREE')
```
with this option, the list has the drives that are not in use.
```
SysDriveMap(drive, 'LOCAL')
```
with this option, the list has only the drives on this computer.
```
SysDriveMap(drive, 'REMOTE')
```
with this option, the list has only the drives on other computers.
```
SysDriveMap(drive, 'REMOVABLE')
```
with this option, the list has only the drives that you can take out of the computer.
```
SysDriveMap(drive, 'CDROM')
```
with this option, the list has only the cdrom drives.
```
SysDriveMap(drive, 'RAMDISK')
```
with this option, the list has only the drives that the system makes in memory.
the code:
```rexx
/* platform: windows */
say SysDriveMap("C:", "USED") -- C: M: N: O: P: R: Z:
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
C: M: N: O: P: R: Z:
```

```
SysDropRexxMacro(name)
```
sysdroprexxmacro: a function that takes away a routine from the macrospace
this function takes away a routine from the macrospace of rexx.
the name argument is the name of the function to take away.
the result is the return code of the rexx function that takes away a routine from the macrospace.

```
SysDumpVariables([filename])
```
sysdumpvariables: a function that writes all variables and their values
this function writes all the variables of the current scope.
the first argument is the name of a file.
the function adds the variables at the end of that file.
if you omit the first argument, the function writes to stdout.
the function writes each variable on one line, in this form.
```
Name=MYVAR, Value='This is the content of MYVAR'
```
the result is 0 if the function writes all variables with no error.
the result is -1 if there is an error.
the variables method of the rexxcontext class also gives the variables.
the code:
```rexx
Call SysDumpVariables "MyVars.Lst" /* append vars to file */
Call SysDumpVariables              /* list vars on STDOUT */
```
the result:
```
Name=RESULT, Value='0'
```

```
SysFileCopy(source, target)
```
sysfilecopy: a function that makes a copy of a file
this function makes a copy of a file in an other place.
the source argument is the path and the name of the file to copy.
the target argument is the path and the name of the copy.
the two arguments cannot have wildcard marks.
on unix, if the source argument starts with a tilde, the function puts the home directory of the user in place of the tilde.
after the tilde can come the name of a user; then the function uses the home directory of that user.
the result is 0 if the function makes the copy with no error.
else the result is a system error code.
the code:
```rexx
/* platform: windows */
call SysFileCopy "c:\temp\myfile.txt", "d:\myfolder\myCopy.txt"
```
the result:
```
not run: this example is for the windows platform
```

the code:
```rexx
/* platform: unix */
call SysFileCopy "/tmp/myfile.txt", "~/myCopy.txt"
```
the result:
```
```

```
SysFileDelete(file)
```
sysfiledelete: a function that deletes a file
this function deletes a file.
the file argument is the name of the file to delete.
the name cannot have wildcard marks.
on unix, if the name starts with a tilde, the function puts the home directory of the user in place of the tilde.
after the tilde can come the name of a user; then the function uses the home directory of that user.
the result is 0 if the function deletes the file with no error.
else the result is an error code of the system.
on windows, the result can be one of these codes, and it can be other codes.
the code 2 says that the file is not found.
the code 3 says that the path is not found.
the code 5 says that the user cannot use the file, or that the file is in use.
the code 26 says that the disk is not a dos disk.
the code 32 says that an other program uses the file now.
the code 87 says that the file does not exist.
the code 206 says that the file name is too long.
the code:
```rexx
parse arg InputFile OutputFile
call SysFileDelete OutputFile  -- unconditionally erase output file
```
the result:
```
```

```
SysFileExists(filename)
```
sysfileexists: a function that tests if a file or a directory exists
this function tests if a file exists.
the result is 1 if a file or a directory with that name exists.
the result is 0 if the file does not exist.
the name cannot have wildcard marks.
on unix, if the name starts with a tilde, the function puts the home directory of the user in place of the tilde.
after the tilde can come the name of a user; then the function uses the home directory of that user.
the code:
```rexx
if SysFileExists(InputFile) then say "File Exists!"
else say "File does not exist."
```
the result:
```
File does not exist.
```

```
SysFileMove(source, target)
```
sysfilemove: a function that moves a file
this function moves a file from one place to an other place.
the source argument is the path and the name of the file to move.
the target argument is the path of the place where the file goes.
the two arguments cannot have wildcard marks.
on unix, if the source argument starts with a tilde, the function puts the home directory of the user in place of the tilde.
after the tilde can come the name of a user; then the function uses the home directory of that user.
the result is 0 if the function moves the file with no error.
else the result is an error code of the system.
the code:
```rexx
/* platform: windows */
call SysFileMove "c:\temp\myfile.txt", "d:\myfolder\myCopy.txt"
```
the result:
```
not run: this example is for the windows platform
```

the code:
```rexx
/* platform: unix */
call SysFileMove "/tmp/myfile.txt", "~/myCopy.txt"
```
the result:
```
```

```
SysFileSearch(target, file, stemarray [,options])
```
sysfilesearch: a function that finds the lines of a file that have a string
this function gives all the lines of a file that have the target string in them.
the target argument is the string to find.
the file argument is the file where the function searches.
the third argument is a stem or an array variable for the lines.
with a stem, the function puts the count of lines in the stem with the tail 0.
the lines go in the stem with the tails 1, 2, and so on, to the count.
the options argument can have any set of these options; each option is one letter.
```
SysFileSearch(target, file, stemarray, 'C')
```
with this option, the search is not caseless.
```
SysFileSearch(target, file, stemarray, 'I')
```
with this option, the search is caseless.
```
SysFileSearch(target, file, stemarray, 'N')
```
with this option, the function puts the number of each line at the start of the line.
the default is a caseless search with no line numbers.
the result is 0 if there is no error.
the result is 2 if the computer does not have the memory the function needs.
the result is 3 if the function cannot open the file.
the code:
```rexx
/* platform: windows */
/* Find DEVICE statements in CONFIG.SYS */
call SysFileSearch "DEVICE", "C:\CONFIG.SYS", "file."
do i=1 to file.0
say file.i
end
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
DEVICE=C:\SB16\DRV\CTSB16.SYS /UNIT=0 /BLASTER=A:240 I:5 D:1 H:5
DEVICE=C:\SB16\DRV\CTMMSYS.SYS
rem ****    DOS SCSI CDROM device drivers ***
DEVICE=C:\SCSI\ASPI8DOS.SYS /D
DEVICE=C:\SCSI\ASPICD.SYS /D:ASPICD0
rem **** IDE CDROM device drivers
DEVICE=C:\DOS\HIMEM.SYS
DEVICE=C:\SBCD\DRV\SBIDE.SYS /V /D:MSCD001  /P:1f0,14
DEVICE=C:\DOS\SETVER.EXE
DEVICE=C:\WINDOWS\SMARTDRV.EXE /DOUBLE_BUFFER
DEVICE=C:\WINDOWS\IFSHLP.SYS
```

the code:
```rexx
/* platform: windows */
/* Find DEVICE statements in CONFIG.SYS (along with */
/* line numbers)                                    */
call SysFileSearch "DEVICE", "C:\CONFIG.SYS", "file.", "N"
do i=1 to file.0
say file.i
end
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
1 DEVICE=C:\SB16\DRV\CTSB16.SYS /UNIT=0 /BLASTER=A:240 I:5 D:1
H:5
2 DEVICE=C:\SB16\DRV\CTMMSYS.SYS
4 rem ****    DOS SCSI CDROM device drivers ***
5 DEVICE=C:\SCSI\ASPI8DOS.SYS /D
6 DEVICE=C:\SCSI\ASPICD.SYS /D:ASPICD0
8 rem **** IDE CDROM device drivers
9 DEVICE=C:\DOS\HIMEM.SYS
10 DEVICE=C:\SBCD\DRV\SBIDE.SYS /V /D:MSCD001  /P:1f0,14
13 DEVICE=C:\DOS\SETVER.EXE
16 DEVICE=C:\WINDOWS\SMARTDRV.EXE /DOUBLE_BUFFER
17 DEVICE=C:\WINDOWS\IFSHLP.SYS
```

```
SysFileSystemType([drive])
```
sysfilesystemtype: a function that gives the kind of file system of a drive
this function runs only on the windows platform.
this function gives the name of the kind of file system that a drive uses.
the drive argument is a drive or a path on the network.
if you omit the drive argument, the function uses the current drive.
if the function cannot use the drive, the result is the null string.
the code:
```rexx
/* platform: windows */
say SysFileSystemType("C:\")    -- NTFS
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
NTFS
```

```
SysFileTree(filespec, stemarray [,options] [,tattrib] [,nattrib])
```
sysfiletree: a function that gives a list of the files whose names match a pattern
this function gives a list of all the files whose names match the first argument.
the list can also have the date, the time, the size, the attributes, and the name of each file.
the order of the list is the order in which the system finds the files; you cannot know the order.
this function works in a different way on each platform.
the first argument cannot be an empty string.
the first argument can be a whole path or a part of a path, with wildcard marks only in its last part.
on windows, the wildcard marks are the star and the question mark.
on unix, a set of characters between two brackets is also a wildcard; it can match each character in the set.
in the brackets, a dash says a range of characters, and an exclamation mark at the start says the characters not in the set.
the second argument is a stem or an array variable for the list.
with a stem, the function puts the count of files in the stem with the tail 0.
the files go in the stem with the tails 1, 2, and so on, to the count.
the options argument is a string of option letters.
```
SysFileTree(filespec, stemarray, 'B')
```
with this option, the function searches for files and directories.
this is the default option.
```
SysFileTree(filespec, stemarray, 'D')
```
with this option, the function searches only for directories.
```
SysFileTree(filespec, stemarray, 'F')
```
with this option, the function searches only for files.
```
SysFileTree(filespec, stemarray, 'H')
```
with this option, the size is right for files with more than 9999999999 bytes.
without this option, the size in the result is never more than 9999999999.
```
SysFileTree(filespec, stemarray, 'I')
```
with this option, the search is caseless.
this option is only for systems where the names of files are not caseless; windows ignores it.
```
SysFileTree(filespec, stemarray, 'L')   date and time as YYYY-MM-DD HH:MM:SS
```
with this option, the date and the time have the form that this code shows.
```
SysFileTree(filespec, stemarray, 'T')   date and time as YY/MM/DD/HH/MM
```
with this option, the date and the time have the form that this code shows.
if the options also have the option before this one, the function ignores this option.
```
SysFileTree(filespec, stemarray, 'O')
```
with this option, the list has only the whole name of each file, with its path.
```
SysFileTree(filespec, stemarray, 'S')
```
with this option, the function also searches each subdirectory, and the subdirectories in them.
with no option for the date and the time, the form of the date and the time is not the same on each platform.
the fourth argument is a mask that says which attributes the files must have.
the fifth argument is a mask that says how the function changes the attributes of each file it finds.
the fourth and the fifth arguments are used only on windows; on unix the function ignores them.
each mask has five positions, one for each attribute, in this order.
```
ADHRS   Archive, Directory, Hidden, Read-Only, System
```
in the fourth argument, a star in a position says that the attribute can be on or off.
in the fourth argument, a plus in a position says that the attribute must be on.
in the fourth argument, a dash in a position says that the attribute must be off.
the default fourth argument has a star in each position.
in the fifth argument, a star in a position says not to change the attribute.
in the fifth argument, a plus in a position says to make the attribute on.
in the fifth argument, a dash in a position says to make the attribute off.
the default fifth argument has a star in each position, so the function changes no attribute.
the function cannot make the directory attribute on for a file that is not a directory.
the attributes in the list are the attributes after the function changes them.
the result is 0 if there is no error.
the result is 2 if the computer does not have the memory the function needs.
on windows, the result can also be a system error code.
the code:
```rexx
/* platform: windows */
/* Find all subdirectories on C: */
call SysFileTree "c:\*.*", "file", "SD"
```
the result:
```
not run: this example is for the windows platform
```

the code:
```rexx
/* platform: windows */
/* Find all executable (.exe) files under Program Files*/
ret = SysFileTree('C:\Program Files\*.exe', f, 'FS')
```
the result:
```
not run: this example is for the windows platform
```

the code:
```rexx
/* platform: windows */
/* Find all Read-Only files */
call SysFileTree "c:\*.*", "file", "S", "***+*"
```
the result:
```
not run: this example is for the windows platform
```

the code:
```rexx
/* platform: windows */
/* Clear Archive and Read-Only attributes of files that have them set */
call SysFileTree "c:\*.*", "file", "S", "+**+*", "-**-*"
```
the result:
```
not run: this example is for the windows platform
```

the reference gives the result of this example only as one result that you can get.
the code:
```rexx
/* platform: windows */
call SysFileTree "c:\win*", file., "b"
do i = 1 to file.0
  say file.i   -- 3/12/21   1:56p           0  -D---  c:\Windows
end
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
3/12/21   1:56p           0  -D---  c:\Windows
```

```
SysFork()
```
sysfork: a function that makes a new process
this function runs only on the unix platform.
this function makes a new child process.
in the parent process, the result is the process id of the child.
in the child process, the result is 0.
the reference says that this example is a whole program that you can run on unix.
the code:
```rexx
/* platform: unix */
/* Example SysFork() and SysWait() */

  pid = SysFork()

  if pid == 0 then do
    say "I am the child."
    code = executeChild()
    say "Child : done with execution, will exit with" code
    exit code
  end
  else do
    say 'I am the parent, child pid is:' pid
    code = executeParent()
    say 'Parent: going to wait for child.'
    code = SysWait()
    say 'Parent: back from waiting. Child exit code:' code
  end

  say 'Operating system version:' SysVersion()

::routine executeChild

    say 'Child : will sleep 1 second.'
    j = SysSleep(1)
    say 'Child : done sleeping 1. Will do some calculations.'

    total = 0
    do 786
      total += 3
    end
    say 'Child : 3 * 786 is:' total

    say 'Child : will sleep 2 seconds.'
    j = SysSleep(2)
    say 'Child : done sleeping 2. Will do some calculations.'

    total = 0
    do 1865
      total += 7
    end
    say 'Child : 7 * 1865 is:' total

    say 'Child : will sleep 2 seconds.'
    j = SysSleep(2)
    say 'Child : done sleeping 2.'
    say 'Child : done executing, will return 0.'
    return 0

::routine executeParent

    say 'Parent: 3 * 786 is:' (3 * 786)
    j = SysSleep(2)
    say 'Parent: 7 * 1865 is:' (7 * 1865)
    return 0
```
the result:
```
I am the parent, child pid is: 4903
Parent: 3 * 786 is: 2358
I am the child.
Child : will sleep 1 second.
Child : done sleeping 1. Will do some calculations.
Child : 3 * 786 is: 2358
Child : will sleep 2 seconds.
Parent: 7 * 1865 is: 13055
Parent: going to wait for child.
Child : done sleeping 2. Will do some calculations.
Child : 7 * 1865 is: 13055
Child : will sleep 2 seconds.
Child : done sleeping 2.
Child : done executing, will return 0.
Child : done with execution, will exit with 0
Parent: back from waiting. Child exit code: 0
Operating system version: Linux 6.18.44-fc-v180
```

```
SysFormatMessage(message, substitutions)
```
sysformatmessage: a function that puts strings in the places of a message
this function gives the text of a message, with strings in the places of the message.
the message argument is the text of the message.
the message can have nine places or less, in any order.
each place is an ampersand and a digit from one to nine.
the second argument is one string, an array of strings, or an other object that has a makearray method.
the first item goes in the place with the digit one, the second item goes in the place with the digit two, and so on.
there can be nine items or less.
the code:
```rexx
s = .Stream~new("xyzzy")
if \s~open("read")~startsWith("READY") then
  -- Cannot read file 'xyzzy': ERROR:2 No such file or directory
  say SysFormatMessage("Cannot read file '&1': &2", (s~string, s~description))
```
the result:
```
Cannot read file 'xyzzy': ERROR:2 No such file or directory
```
the reference says:
```
Cannot read file 'xyzzy': ERROR:2 No such file or directory
```

```
SysFromUnicode(string [,codepage] [,mappingflags] [,defaultchar], outstem)
```
sysfromunicode: a function that changes unicode text to text in an other codepage
this function runs only on the windows platform.
this function changes a string of unicode characters to a string in a codepage.
the function puts the result in a stem.
it uses a function of windows, so the rules of that windows function are also rules of this function.
the string argument is the string of unicode characters to change.
the codepage argument is the codepage of the result.
it can be the number of a codepage, or one of these names.
```
SysFromUnicode(string, 'ACP')
```
with this value, the codepage is the default windows codepage of the system.
```
SysFromUnicode(string, 'CONSOLE')
```
with this value, the codepage is the codepage of the windows console now.
```
SysFromUnicode(string, 'MACCP')
```
the reference says not to use this codepage now.
```
SysFromUnicode(string, 'OEMCP')
```
this is the default codepage.
```
SysFromUnicode(string, 'SYMBOL')
```
the reference says not to use this codepage now.
```
SysFromUnicode(string, 'THREAD_ACP')
```
with this value, the codepage is the windows codepage of the current thread.
```
SysFromUnicode(string, 'UTF7')
```
with this value, the result is in the seven bit unicode form.
the reference says not to use this value, but to use the next value in its place.
```
SysFromUnicode(string, 'UTF8')
```
with this value, the result is in the eight bit unicode form.
the third argument says how the function changes the characters.
it can have any set of these options.
the function runs in less time when you give no option.
```
SysFromUnicode(string, codepage, 'COMPOSITECHECK')
```
with this option, the function finds characters that are made of a base character and marks that do not take space, and it tries to make one character of them before it changes them.
you can use this option with the next three options.
if you give no one of the next three options, the function works as if you give the last of them.
```
SysFromUnicode(string, codepage, 'DEFAULTCHAR')
```
with this option, the function puts the default character in place of each character it cannot change.
```
SysFromUnicode(string, codepage, 'DISCARDNS')
```
with this option, the function takes away the marks that do not take space.
```
SysFromUnicode(string, codepage, 'SEPCHARS')
```
with this option, the function makes separate characters.
this is the default option.
```
SysFromUnicode(string, codepage, 'ERR_INVALID_CHARS')
```
with this option, the function stops with the result 1113 when the string has a unicode character that is not valid.
you can use this option only with the eight bit unicode form or the codepage 54936.
```
SysFromUnicode(string, codepage, 'NO_BEST_FIT_CHARS')
```
with this option, the function puts the default character in place of each character that the codepage does not have, and not an other character that is like it but does not mean the same.
the fourth argument is the character for each unicode character that the codepage does not have.
if you omit the fourth argument or it is empty, the function uses the default character of the codepage; it is often a question mark.
the last argument is the name of the stem variable for the result.
```
outstem.!USEDDEFAULTCHAR
```
this is true if the function used the default character, else false.
```
outstem.!TEXT
```
this is the string the function makes.
the result is 0 if there is no error.
else the result is an error code of windows; it can be other codes than these.
the code 87 says that an argument is not right.
it is so when the length of the string is not even, when the string is too long, or when the codepage number is not a codepage of windows.
the code 1004 says that the options are not valid.
it is so when you give one of the three options after the first option, but not the first option.
it is also so when you give the option for characters that are not valid with an other codepage than the eight bit unicode form or 54936.
the code 1113 says that the codepage has no character for a unicode character.
it is so when the string has a character that is not valid, and you give the option for characters that are not valid.
the code:
```rexx
/* platform: windows */
-- two steps to convert a string from one code page to another
string = '64 C3A9 6A C3A0 20 76 75'x -- UTF-8 encoded
-- step 1: convert the string from its codepage to UTF-16
call SysToUnicode string, "UTF8", , out.
-- step 2: convert the UTF-16 string to the desired output codepage
call SysFromUnicode out.!text, "CONSOLE", , , out.
say out.!text -- déjà vu
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
déjà vu
```

```
SysGetErrorText(errornumber)
```
sysgeterrortext: a function that gives the text for an error code of the system
this function gives a string that says what the system error with that number is.
the argument is the number of the error.
the result is an empty string if the system has no text for the error.
the error numbers and their text are not the same on each system.
some functions of the rexxutil package give an error code of the system when there is an error; this function gives the text for that code.
on windows, you can read what each code is in the list of system error codes of windows.
the code:
```rexx
/* platform: windows */
-- Windows: Cannot create a file when that file already exists.
say SysGetErrorText(SysMkDir("\Users"))
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
Cannot create a file when that file already exists.
```

the code:
```rexx
/* platform: unix */
-- Unix-like system: File exists
say SysGetErrorText(SysMkDir("/usr"))
```
the result:
```
File exists
```
the reference says:
```
File exists
```

```
SysGetFileDateTime(filename [,timesel])
```
sysgetfiledatetime: a function that gives a date and a time of a file
this function gives a date and a time of a file or a directory.
the first argument is the name of the file or the directory.
the name cannot have wildcard marks.
on unix, if the name starts with a tilde, the function puts the home directory of the user in place of the tilde.
after the tilde can come the name of a user; then the function uses the home directory of that user.
the second argument says which date and time you want.
the function uses only the first letter of the second argument.
some of these values do not work on each system or on each file system.
```
SysGetFileDateTime(filename, 'ACCESS')
```
with this value, the result is the last date and time that a program used the file.
this value does not work on a fat file system.
```
SysGetFileDateTime(filename, 'CREATE')
```
with this value, the result is the date and time when the file was made.
this value does not work on unix or on a fat file system.
```
SysGetFileDateTime(filename, 'WRITE')
```
with this value, the result is the last date and time that the file changed.
this is the default value.
the result has the form that this code shows.
```
yyyy-mm-dd hh:mm:ss
```
if the function cannot get the date and the time, the result is -1.
the file class also has two attributes that give these times; their names are in this code.
```
lastAccessed   lastModified
```
the reference gives the results of this example only as one result that you can get.
the code:
```rexx
say SysGetFileDateTime(".")           -- (e. g.) 2020-04-01 17:45:20
say SysGetFileDateTime("main.c", "w") -- (e. g.) 2020-02-11 05:00:00
```
the result:
```
2026-10-28 18:03:38
-1
```
the reference says:
```
2020-04-01 17:45:20
2020-02-11 05:00:00
```

```
SysGetKey([opt])
```
sysgetkey: a function that reads the next key that the user pushes
this function reads the next key from the buffer of keys and gives it.
if the buffer is empty, the function waits until the user pushes a key.
the charin function waits until the user pushes the enter key, but this function does not.
the first argument is an option that says if the function shows the key on the screen.
```
SysGetKey('ECHO')
```
with this option, the function shows the key on the screen.
this is the default option.
```
SysGetKey('NOECHO')
```
with this option, the function does not show the key.

```
SysGetLongPathName(path)
```
sysgetlongpathname: a function that gives the long form of a path
this function runs only on the windows platform.
this function gives the long form of the path argument.
the path argument is a path from the current directory, or a whole path, of a file or a directory that exists.
if the path does not exist, the result is the null string.
if the windows function for this has an error, the result is also the null string.
the code:
```rexx
/* platform: windows */
say SysGetLongPathName("C:\progra~1")            -- C:\Program Files
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
C:\Program Files
```

the code:
```rexx
/* platform: windows */
say SysGetLongPathName("\windows\explorer.exe")  -- \Windows\explorer.exe
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
\Windows\explorer.exe
```

```
SysGetMessage(num [,filename] [,str]...)
```
sysgetmessage: a function that gives a message from a catalog of messages
this function runs only on the unix platform.
this function gives a message from a unix catalog, with strings in the places of the message.
this function always uses the set 1 of the catalog.
for an other set, use the next function.
you make a unix catalog with this command.
```
gencat
```
the first argument is the number of the message.
the catalog file argument is the name of the catalog file.
if you omit the catalog file argument, or give the name of the rexx catalog file, the function searches the catalog of rexx.
else the function finds the catalog by its whole path, or searches the directories in this environment variable.
```
NLSPATH
```
after the catalog file argument, there can be nine strings or less.
the first string goes in the place with the digit one, the second string goes in the place with the digit two, and so on.
each place is an ampersand and a digit from one to nine.
if a place has no string, the function puts the null string there.
the function ignores more strings than places.
places of an other form are not changed.
the code:
```rexx
/* platform: unix */
say SysGetMessage(485, "rexx.cat", "foo") -- Class "foo" not found.
```
the result:
```
Class "foo" not found.
```
the reference says:
```
Class "foo" not found.
```

```
SysGetMessageX(set, num [,filename] [,str]...)
```
sysgetmessagex: a function that gives a message from a set of a catalog of messages
this function runs only on the unix platform.
this function gives a message from a unix catalog, with strings in the places of the message.
you make a unix catalog with this command.
```
gencat
```
the set argument is the set of messages in the catalog.
the second argument is the number of the message.
the catalog file argument is the name of the catalog file.
if you omit the catalog file argument, or give the name of the rexx catalog file, the function searches the catalog of rexx.
else the function finds the catalog by its whole path, or searches the directories in this environment variable.
```
NLSPATH
```
after the catalog file argument, there can be nine strings or less.
the first string goes in the place with the digit one, the second string goes in the place with the digit two, and so on.
each place is an ampersand and a digit from one to nine.
if a place has no string, the function puts the null string there.
the function ignores more strings than places.
places of an other form are not changed.
the code:
```rexx
/* platform: unix */
say SysGetMessageX(1, 485, "rexx.cat", "foo") -- Class "foo" not found.
```
the result:
```
Class "foo" not found.
```
the reference says:
```
Class "foo" not found.
```

```
SysGetShortPathName(path)
```
sysgetshortpathname: a function that gives the short form of a path
this function runs only on the windows platform.
this function gives the short form of the path argument.
the path argument is a path from the current directory, or a whole path, of a file or a directory that exists.
if the path does not exist, the result is the null string.
if the windows function for this has an error, the result is also the null string.
the code:
```rexx
/* platform: windows */
say SysGetShortPathName("C:\Program Files")       -- C:\PROGRA~1
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
C:\PROGRA~1
```

the code:
```rexx
/* platform: windows */
say SysGetShortPathName("\windows\explorer.exe")  -- \windows\explorer.exe
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
\windows\explorer.exe
```

```
SysIni([inifile], app [,key] [,val] [,stemarray])
```
sysini: a function that reads and writes the values of an ini file
this function runs only on the windows platform.
this function gives a program some use of the values in an ini file.
an ini file keeps each value for an application name and a keyword.
a program can use it to share variables with other applications.
the values can be text, numbers, or binary data.
the function can do six things.
it can set the value of one keyword.
it can give the value of one keyword.
it can delete one keyword.
it can delete an application name and all its keywords.
it can give the names of all the keywords of an application, in the stem or array variable.
it can give the names of all the applications, in the stem or array variable.
the first argument is the ini file.
if you omit the first argument, the function uses this file.
```
WIN.INI
```
if the name of the file is not a whole path, windows searches for it in the directory of windows.
so for a file in an other directory, give the whole path.
the second argument is the name of the application that has the keywords.
the key argument is the name of a keyword that has a value.
the fourth argument is the value of the keyword for that application.
the fourth argument can also be one of these special strings.
```
"DELETE:"   "ALL:"
```
the last argument is a stem or an array variable for the names that the function gives.
with a stem, the function puts the count of names in the stem with the tail 0.
the names go in the stem with the tails 1, 2, and so on, to the count.
when the function sets or deletes a value with no error, the result is the null string.
when the function gives the value of a keyword, the result is that value.
if there is an error, the result can be this string.
```
ERROR:
```
it is an error to give or delete a keyword or an application that does not exist.
it is an error when the function cannot open the ini file.
this can be so when you give a part path for the ini file of the user or of the system; give the drive, the path, and the name of the file.
the code:
```rexx
/* platform: windows */
/***  Save the user entered name under the key "NAME" of *****
****  the application "MYAPP".                           ****/
pull name .
call SysIni , "MYAPP", "NAME", name /* Save the value        */
say  SysIni(, "MYAPP", "NAME")      /* Query the value       */
call SysIni , "MYAPP"               /* Delete all MYAPP info */
exit
```
the result:
```
not run: this example is for the windows platform
```

the code:
```rexx
/* platform: windows */
/****  Type all WIN.INI file information to the screen  *****/
call SysIni "WIN.INI", "All:", "Apps."
if Result \= "ERROR:" then
do i = 1 to Apps.0
call SysIni "WIN.INI", Apps.i, "All:", "Keys"
if Result \= "ERROR:" then
do j=1 to Keys.0
val = SysIni("WIN.INI", Apps.i, Keys.j)
say left(Apps.i, 20) left(Keys.j, 20),
"Len=x"Left(d2x(length(val)),4) left(val, 20)
end
end
exit
```
the result:
```
not run: this example is for the windows platform
```

```
SysIsFile(filename)
```
sysisfile: a function that tests if a file exists
this function tests if a file exists.
the result is 1 if the file exists.
the result is 0 if the file does not exist.
the first argument is the name of the file.
the name cannot have wildcard marks.
on unix, if the name starts with a tilde, the function puts the home directory of the user in place of the tilde.
after the tilde can come the name of a user; then the function uses the home directory of that user.
on unix, this function also gives 1 for a block device.
the code:
```rexx
if SysIsFile(InputFile) then say "File Exists!"
else say "File does not exist."
```
the result:
```
File does not exist.
```

```
SysIsFileCompressed(filename)
```
sysisfilecompressed: a function that tests if a file is compressed
this function runs only on the windows platform.
this function tests if a file is compressed.
the first argument is the name of the file.
the name cannot have wildcard marks.
the result is 1 if the file is compressed.
the result is 0 if the file is not compressed or does not exist.
the code:
```rexx
/* platform: windows */
if SysIsFileCompressed(InputFile) then say "File is compressed!"
else say "File is not compressed or does not exist."
```
the result:
```
not run: this example is for the windows platform
```

```
SysIsFileDirectory(dirname)
```
sysisfiledirectory: a function that tests if a subdirectory exists
this function tests if a subdirectory exists.
the first argument is the name of the subdirectory.
the name cannot have wildcard marks.
on unix, if the name starts with a tilde, the function puts the home directory of the user in place of the tilde.
after the tilde can come the name of a user; then the function uses the home directory of that user.
the result is 1 if the subdirectory exists.
the result is 0 if the subdirectory does not exist.
the code:
```rexx
if SysIsFileDirectory(InputFile) then say "Subdirectory Exists!"
else say "Subdirectory does not exist."
```
the result:
```
Subdirectory does not exist.
```

```
SysIsFileEncrypted(filename)
```
sysisfileencrypted: a function that tests if a file is encrypted
this function runs only on the windows platform.
this function tests if a file is encrypted.
the first argument is the name of the file.
the name cannot have wildcard marks.
the result is 1 if the file is encrypted.
the result is 0 if the file is not encrypted or does not exist.
the code:
```rexx
/* platform: windows */
if SysIsFileEncrypted(InputFile) then say "File is encrypted!"
else say "File is not encrypted or does not exist."
```
the result:
```
not run: this example is for the windows platform
```

```
SysIsFileLink(linkname)
```
sysisfilelink: a function that tests if a link exists
this function tests if a link exists.
the first argument is the name of the link.
the name cannot have wildcard marks.
on unix, if the name starts with a tilde, the function puts the home directory of the user in place of the tilde.
after the tilde can come the name of a user; then the function uses the home directory of that user.
the result is 1 if the link exists.
the result is 0 if the link does not exist or it is not a link.
the code:
```rexx
if SysIsFileLink(InputFile) then say "Link Exists!"
else say "Link does not exist."
```
the result:
```
Link does not exist.
```
