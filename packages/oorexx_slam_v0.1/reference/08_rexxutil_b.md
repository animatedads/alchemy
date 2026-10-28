# more external functions

this file is from the rules of the oorexx language about a package of external functions: the second part of the list of its functions, and the functions of it that you must not use now.

## words i add here

rexxutil: the name of a package of external functions that comes with oorexx
deprecated: a part of the language is deprecated when the rules say you must not use it in new code
shows: show, for one thing
codes: more than one code
directories: more than one directory
tails: more than one tail
deletes: delete, for one thing
inserts: insert, for one thing
sixth: the next after the fifth
seventh: the next after the sixth
lost: data is lost when you can not get it back
current: the one in use now
flag: a bit that the system keeps with a file; it says a fact about the file
flags: more than one flag
link: a file whose data is the name of an other file
offline: the name of a flag of a file on windows
sparse: the name of a flag of a file on windows
temporary: a thing is temporary when it is there for a short time only
version: a name or a number that says which form of a program or a system it is
macrospace: a place in memory where the system keeps rexx functions, so programs can call them
save: write data to a disk, so you can read it after the program ends
saves: save, for one thing
saved: data is saved when you save it
home: the home directory of a user is the directory that the system gives to that user for files
valid: a value is valid when the rules let you use it
permission: what lets a user read, write, or run a file
umask: a value on the unix platform that says which permission bits a new file does not get
thread: one way the system runs a part of a program; one process can have many of them
priority: a value that says which program the system runs first when many programs want to run
idle: a computer is idle when it has no work to do
kernel: the main part of a system; it has control of the computer
network: a set of computer systems that send data to each other
administrator: a user that can do all things on the system
screen: the part of a computer that shows text to the user
window: a part of the screen where a program shows text
console: a window where a program reads and writes lines of text
foreground: the window in the foreground is the window that the user uses now
title: the name that a window shows
color: a part of how a character shows on a screen
unicode: the name of a set of codes for the characters of all languages
child: a child process is a process that an other process starts
pipe: a stream between two programs; a named pipe has a name
paper: a thing that you can write text on
printer: a part of a computer system that puts text on paper
printers: more than one printer
driver: the program that the system uses to send data to a printer
port: the place where the computer sends data to a printer
encrypt: change the data of a file so that only the right user can read it
decrypt: change the data of a file back after you encrypt it
realtime: work is realtime when the computer must do it at the time it is needed
oem: the name of a kind of code page of windows

## the functions

```
SysIsFileNotContentIndexed(filename)
```
sysisfilenotcontentindexed: a rexxutil function that tests if the system must index a file
this function runs only on the windows platform.
this function tests if a file has the flag that says the system must index the file.
the first argument is the name of the file to test.
the name can not be a pattern that names many files.
the result is 1 if the file has the flag.
the result is 0 if the file does not have the flag, or if the file is not there.
the code:
```rexx
/* platform: windows */
if SysIsFileNotContentIndexed(InputFile) then say "File is flagged to be Indexed!"
else say "File is not flagged to be Indexed."
```
the result:
```
not run: this example is for the windows platform
```

```
SysIsFileOffline(filename)
```
sysisfileoffline: a rexxutil function that tests if a file has the offline flag
this function runs only on the windows platform.
this function tests if a file has the offline flag.
the first argument is the name of the file to test.
the name can not be a pattern that names many files.
the result is 1 if the file has the offline flag.
the result is 0 if the file does not have the offline flag, or if the file is not there.
the code:
```rexx
/* platform: windows */
if SysIsFileOffline(InputFile) then say "File is flagged as Offline!"
else say "File is not flagged as Offline."
```
the result:
```
not run: this example is for the windows platform
```

```
SysIsFileSparse(filename)
```
sysisfilesparse: a rexxutil function that tests if a file has the sparse flag
this function runs only on the windows platform.
this function tests if a file has the sparse flag.
the first argument is the name of the file, the directory, or the link to test.
the name can not be a pattern that names many files.
the result is 1 if the file has the sparse flag.
the result is 0 if the file does not have the sparse flag, or if the file is not there.
the code:
```rexx
/* platform: windows */
if SysIsFileSparse(InputFile) then say "File is Sparse!"
else say "File is not Sparse."
```
the result:
```
not run: this example is for the windows platform
```

```
SysIsFileTemporary(filename)
```
sysisfiletemporary: a rexxutil function that tests if a file has the temporary flag
this function runs only on the windows platform.
this function tests if a file has the temporary flag.
the first argument is the name of the file, the directory, or the link to test.
the name can not be a pattern that names many files.
the result is 1 if the file has the temporary flag.
the result is 0 if the file does not have the temporary flag, or if the file is not there.
the code:
```rexx
/* platform: windows */
if SysIsFileTemporary(InputFile) then say "File is Temporary!"
else say "File is not Temporary."
```
the result:
```
not run: this example is for the windows platform
```

```
SysLinVer()
```
syslinver: a rexxutil function that gives the version of the linux system
this function runs only on the linux platform.
this function gives a string that says the version of the linux system.
the first word of the result is linux.
the rest of the result says the version.
a program must not need the result to be in one set form.
the examples of the reference for this function call an other rexxutil function, as the code shows.
the reference says that these results are only what the output can be.
the code:
```rexx
/* platform: linux */
-- CentOS 7
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Linux 3.10.0-957.10.1.el7.x86_64
```

the code:
```rexx
/* platform: linux */
-- Ubuntu 16.04
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Linux 4.4.0-154-generic
```

the code:
```rexx
/* platform: linux */
-- Raspbian
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Linux 4.14.70-v7+
```

the code:
```rexx
/* platform: linux */
-- SLES/390
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Linux 3.12.74-60.64.40-default
```

```
SysLoadRexxMacroSpace(file)
```
sysloadrexxmacrospace: a rexxutil function that loads functions from a file in the macrospace
this function loads functions from a file in the macrospace.
the file argument is the name of the file to load from.
a call of the function that saves the macrospace must make that file first.
the result is the return code of the function of the system that loads a macrospace.

```
SysMkDir(dirspec [,mode])
```
sysmkdir: a rexxutil function that makes a directory
this function makes a directory.
it makes only the last directory of the name; each directory before it must be there.
the first argument is the name of the directory to make.
the name can not be a pattern that names many directories.
on the unix platform, the function puts the home directory of the user in place of a tilde at the start of the name.
on the unix platform, a user name after that tilde says which user.
the mode argument is only for the unix platform.
the mode argument gives the permission bits of the new directory, as a decimal number from 0 to 511.
the default mode is 511.
the umask of the system always takes away bits from the mode.
the result is 0 if the function makes the directory.
else the result is an error code of the system.
on windows, the error code can be one of these codes, but it can also be an other code.
the code 2 says the file is not found.
the code 3 says the path is not found.
the code 5 says the system does not let the user do it.
the code 26 says the disk is not of a kind that the system can use.
the code 87 says an argument is not valid.
the code 108 says the drive is in use by an other program.
the code 183 says the directory is there now.
the code 206 says the file name has too many characters.
the code:
```rexx
call SysMkDir "backup"
```
the result:
```
```

```
SysQueryProcess(info)
```
sysqueryprocess: a rexxutil function that gives facts about the current process or its current thread
this function gives facts about the current process or about its current thread.
the first argument says which fact the function gives.
```
PID
```
with this option, the result is the id of the current process.
```
PPID
```
with this option, the result is the id of the process that starts the current process.
```
TID
```
with this option, the result is the id of the current thread.
```
PPRIO
```
with this option, the result is the priority class of the current process.
on windows, the result is the name of a priority class, or the name unknown.
on the unix platform, the result is a number from -20 to 20.
```
TPRIO
```
with this option, the result is the name of the priority of the current thread, or the name unknown.
```
PTIME
```
with this option, the result has facts about the time of the current process.
on windows, the result has the date and time when the process starts, the time in kernel mode, and the time in user mode.
on the unix platform, the result has a short list of the time, with the time in kernel mode and the time in user mode.
```
TTIME
```
with this option, the result has facts about the time of the current thread.
```
PMEM
```
with this option, the result is the maximum memory that the current process uses.
```
PRCVDSIG
```
with this option, the result is the count of times that the process gets a signal.

```
SysQueryRexxMacro(name)
```
sysqueryrexxmacro: a rexxutil function that tests if a function is in the macrospace
this function tests if a function is in the macrospace.
the name argument is the name of a function in the macrospace.
the result is the order of the function in the macrospace.
if the function is not in the macrospace, the result is an empty string.

```
SysReorderRexxMacro(name, order)
```
sysreorderrexxmacro: a rexxutil function that changes the order of a function in the macrospace
this function changes the order of a function that is in the macrospace.
the name argument is the name of a function in the macrospace.
the order argument is the new order.
```
B   Before
```
with this option, the new order is before.
```
A   After
```
with this option, the new order is after.
the result is the return code of the function of the system that changes the order of a function in the macrospace.

```
SysRmDir(dirspec)
```
sysrmdir: a rexxutil function that deletes a directory
this function deletes a directory.
it does not ask the user first.
the first argument is the name of the directory to delete.
the name can not be a pattern that names many directories.
on the unix platform, the function puts the home directory of the user in place of a tilde at the start of the name.
on the unix platform, a user name after that tilde says which user.
the result is 0 if the function deletes the directory.
else the result is an error code of the system.
on windows, the error code can be one of these codes, but it can also be an other code.
the code 2 says the file is not found.
the code 3 says the path is not found.
the code 5 says the system does not let the user do it, or the directory is in use.
the code 16 says the directory is the current directory.
the code 26 says the disk is not of a kind that the system can use.
the code 32 says an other program uses the directory now.
the code 108 says the drive is in use by an other program.
the code 123 says the name is not valid.
the code 145 says the directory is not empty.
the code 206 says the file name has too many characters.
the code:
```rexx
call SysRmDir "backup"
```
the result:
```
```

```
SysSaveRexxMacroSpace(file)
```
syssaverexxmacrospace: a rexxutil function that saves the functions of the macrospace in a file
this function saves the functions of the macrospace in a file.
the file argument is the name of the file to save the functions in.
the result is the return code of the function of the system that saves a macrospace.

```
SysSearchPath(path, filename [,option])
```
syssearchpath: a rexxutil function that finds a file in the directories that an environment variable lists
this function finds a file in a list of directories.
the path argument is the name of an environment variable whose value is a list of directories, as the path variable.
the second argument is the name of the file to find; it can have directory names before it.
the name must be the name of a file, not of a directory.
if the second argument is an absolute path, the function gives it back and does not use the list of directories.
the name can not be a pattern that names many files.
on the unix platform, the function puts the home directory of the user in place of a tilde at the start of the name.
on the unix platform, a user name after that tilde says which user.
the option argument says where the function tries to find the file first.
```
C
```
with this option, the function tries the current directory first, then the directories of the list.
this option is the default.
```
N
```
with this option, the function tries only the directories of the list.
the result is the absolute path of the file, if the function finds it.
else the result is an empty string.
the code:
```rexx
/* platform: unix */
say SysSearchPath("PATH", "rexx")
```
the result:
```
/home/claude/oorexx/usr/local/bin/rexx
```
the reference says:
```
/usr/local/bin/rexx
```

the code:
```rexx
/* platform: windows */
say SysSearchPath("PATH", "rexx.exe")
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
C:\Program Files\ooRexx\rexx.exe
```

```
SysSetFileDateTime(filename [,newdate] [,newtime])
```
syssetfiledatetime: a rexxutil function that sets the date and time of the last change of a file
this function sets the date and the time of the last change of a file.
the first argument is the name of a file or of a directory.
the name can not be a pattern that names many files.
on the unix platform, the function puts the home directory of the user in place of a tilde at the start of the name.
on the unix platform, a user name after that tilde says which user.
the second argument is the new date: four digits for the year, a dash, two digits for the month, a dash, and two digits for the day.
on windows, the year must be 1800 or more.
the third argument is the new time: two digits for the hour, a colon, two digits for the minute, a colon, and two digits for the second.
the hour counts the hours from midnight.
if you omit the second argument and the third argument, the function sets the date and the time to now.
if you give only one of them, the other part does not change.
the result is 0 if the function sets the date or the time.
the result is -1 if the function can not set them.
the code:
```rexx
call SysSetFileDateTime "."                       -- touch current directory
call SysSetFileDateTime "main.c", , "05:00:00"    -- change file time only
```
the result:
```
```

```
SysSetPriority(class, delta)
```
syssetpriority: a rexxutil function that changes the priority of the current process
this function changes the priority of the current process.
the class argument is the new priority class of the process.
```
class IDLE 0
```
with this class, the process runs in idle time.
the number 0 is the same as this class.
```
class NORMAL 1
```
with this class, the process has the normal priority.
the number 1 is the same as this class.
```
class HIGH 2
```
with this class, the process has a priority that is more than normal.
the number 2 is the same as this class.
```
class REALTIME 3
```
with this class, the process has the realtime priority.
the number 3 is the same as this class.
the second argument is the change to the priority level of the process.
the second argument is a whole number from -15 to 15, or one of these names.
```
delta IDLE
```
this name is the same as -15.
```
delta LOWEST
```
this name is the same as -2.
```
delta BELOW_NORMAL
```
this name is the same as -1.
```
delta NORMAL
```
this name is the same as 0.
```
delta ABOVE_NORMAL
```
this name is the same as 1.
```
delta HIGHEST
```
this name is the same as 2.
```
delta TIME_CRITICAL
```
this name is the same as 15.
the result is 0 if there is no error.
else the result is an error code of the system.
on windows, the code 307 says the priority class is not valid.

```
SysShutdownSystem([computer] [,message] [,timeout] [,force] [,reboot])
```
sysshutdownsystem: a rexxutil function that stops the system of a computer
this function runs only on the windows platform.
this function stops the system of a computer.
after you call it, you can not stop it, and data that is not saved can be lost.
it can stop the system when a user uses it and programs have data that is not saved.
to stop the local computer, the user does not need to be an administrator.
to stop an other computer, the user must be an administrator.
the first argument is the name of the computer to stop on the network.
if you omit the first argument, or it is empty, the function stops the local computer.
the second argument is text that the function adds to the window that it shows.
if you omit the second argument, the function adds no text.
the third argument is the count of seconds before the system stops.
the default count is 30.
if the third argument is 0, the system stops with no wait, shows no window, and you can not stop it.
if the third argument is not 0, the system shows a window on that computer.
the window says which user starts the stop, shows the time that is left, and asks the user to end its work.
the user can not close that window.
if the fourth argument is true, the system closes each program, if its data is saved or not.
then a program can ask the user to save its data, but the user has only a few seconds to do it.
if the fourth argument is false, the system waits until the user does what the window asks, and the user can stop the stop.
if the third argument is 0 and the fourth argument is true, the system stops with no wait, and data that is not saved is lost.
if the fifth argument is true, the system starts again after it stops.
if the fifth argument is false, the system stops and does not start again.
the default of the fifth argument is false.
the result is 0 if there is no error.
else the result is an error code of windows.
the code 1300 says the system does not let the user stop that computer.
sysgeterrortext: a rexxutil function that gives the text for an error code of the system
the function sysgeterrortext gives the text for an error code.

```
SysSleep(delay)
```
syssleep: a rexxutil function that makes a program wait for a time
this function makes the program wait for a time.
the first argument is the count of seconds to wait.
on windows, the count must be from 0 to 2147483.
on the unix platform, the count must be from 0 to 999999999.
the code:
```rexx
Say "Now paused for 2 seconds ..."
Call SysSleep 2
Say "Now paused for 0.1234567 seconds ..."
Call SysSleep 0.1234567
```
the result:
```
Now paused for 2 seconds ...
Now paused for 0.1234567 seconds ...
```

```
SysStemCopy(fromstem, tostem [,from] [,to] [,count] [,insert])
```
sysstemcopy: a rexxutil function that copies items from one stem to an other stem
this function copies items from one stem to an other stem.
the stems must be like arrays: the item with the tail 0 is the count of items, and the items have the tails from 1 to that count, with no omitted tail.
the first argument is the name of the stem to copy from.
the second argument is the name of the stem to copy to.
the third argument is the index in the first stem of the first item to copy.
the default of the third argument is 1.
the fourth argument is the index in the second stem where the items go.
the default of the fourth argument is 1.
the count argument is the count of items to copy.
the default count is all the items of the first stem.
the sixth argument is an option.
```
I   Insert
```
with this option, the function inserts the items at that index, and puts the items that are there after them.
```
O   Overwrite
```
with this option, the new items take the place of the items that are there.
the result is 0 if the function copies the stem.
the result is -1 if the function can not copy the stem.
the code:
```rexx
Source.0 = 3
Source.1 = "Hello"
Source.2 = "from"
Source.3 = "Rexx"
Call SysStemCopy "Source.", "Target."

Call SysStemCopy "Source.", "Target.", 1, 5, 2, "I"
```
the result:
```
40.923
```

```
SysStemDelete(stem, startitem [,itemcount])
```
sysstemdelete: a rexxutil function that deletes items from a stem
this function deletes the item at an index of a stem.
to delete more than one item, give the count of items as the third argument.
then each item after them goes back, so there are no omitted tails.
the stem must be like an array: the item with the tail 0 is the count of items, and the items have the tails from 1 to that count, with no omitted tail.
the stem argument is the name of the stem.
the second argument is the index of the first item to delete.
the third argument is the count of items to delete.
the result is 0 if the function deletes the items.
the result is -1 if the function can not delete them.
the code:
```rexx
Call SysStemDelete "MyStem.", 5
Call SysStemDelete "MyStem.", 5, 4
```
the result:
```
40.922
```

```
SysStemInsert(stem, position, value)
```
syssteminsert: a rexxutil function that inserts a new item in a stem
this function inserts a new item at a position in a stem.
each item at that position and after it goes one position on.
the stem must be like an array: the item with the tail 0 is the count of items, and the items have the tails from 1 to that count, with no omitted tail.
the stem argument is the name of the stem.
the position argument is the index of the new item.
the value argument is the value of the new item.
the result is 0 if the function inserts the item.
the result is -1 if the function can not insert it.
the code:
```rexx
Call SysStemInsert "MyStem.", 5, "New value for item 5"
```
the result:
```
40.922
```

```
SysStemSort(stem [,order] [,type] [,start] [,end] [,firstcol] [,lastcol])
```
sysstemsort: a rexxutil function that sorts the items of a stem
this function sorts all the items of a stem, or a range of them.
the stem must be like an array: the item with the tail 0 is the count of items, and the items have the tails from 1 to that count, with no omitted tail.
if the count of items is 0, the function does not sort, and that is not an error.
the order of the items whose sort parts are equal is not known.
the stem argument is the name of the stem.
the order argument says the order of the sort.
```
order A
```
with this option, the order is from the least item to the most item.
this option is the default.
```
order D
```
with this option, the order is from the most item to the least item.
the third argument says how the function compares.
```
type C
```
with this option, the compare is not caseless.
this option is the default.
```
type I
```
with this option, the compare is caseless.
the start argument is the index where the sort starts.
the default start is 1.
the end argument is the index where the sort ends.
the default end is the last item.
the sixth argument is the position of the first character of the part of each item that the function compares.
the default of the sixth argument is 1.
the seventh argument is the position of the last character of that part.
the default of the seventh argument is the last character.
the result is 0 if the function sorts the stem.
the result is -1 if the function can not sort it.
the code:
```rexx
Call SysStemSort "MyStem.", "D", , , ,5, 10
```
the result:
```
```

the code:
```rexx
Call SysStemSort "MyStem.", "A", "I"
```
the result:
```
```

the code:
```rexx
Call SysStemSort "MyStem.", , ,10, 20, 1, 10
```
the result:
```
```

```
SysSwitchSession(name)
```
sysswitchsession: a rexxutil function that puts a window in the foreground
this function runs only on the windows platform.
this function puts the window that you name in the foreground.
the name argument is the title of the window.
the name must be the same as the title of the window, but the compare is caseless.
the result is 0 if there is no error.
else the result is an error code of windows.

```
SysSystemDirectory()
```
syssystemdirectory: a rexxutil function that gives the system directory of windows
this function runs only on the windows platform.
this function gives the system directory of windows.

```
SysTempFileName(template [,filler])
```
systempfilename: a rexxutil function that gives a new name for a temporary file or directory
this function gives a name for a file or a directory that is not there now.
it is of use when a program needs a temporary file.
the template argument is the name of a file or a directory, with its path, and with from one to nine special characters in it.
the second argument is that special character.
the default special character is a question mark.
the function puts a random digit in place of each special character.
if a file of that name is there, the function adds one to the number, until it finds a name that is not there or there are no more names to try.
if there is an error, or the function can not make a name of that kind, the result is an empty string.
if the template has no special character, or more than nine, the result is an empty string.
the path and the name can have any length.
the special characters can be in the path and in the name.
the function makes the name only by digits in place of the special characters.
if a directory of the path is not there, the function gives a name, but you can not write to the file until you make each directory.
on the unix platform, this function now does the same as on windows.
on the unix platform, the function does not now use only the first five characters of the name with a random string after them.
on the unix platform, if the template has no path, the function does not now put a path that the system gives before the name.
programs that use this function on the unix platform must change.
the code:
```rexx
/* platform: windows */
say SysTempFileName("file???")
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
C:\Users\User1\file392
```

the code:
```rexx
/* platform: unix */
say SysTempFileName("file???")
```
the result:
```
/tmp/claude-0/-home-claude/7a454f5a-2610-5341-b35a-ce8fb6712926/scratchpad/runall/slam_examples_2026102865054/run/file541
```
the reference says:
```
/home/user1/file384
```

the code:
```rexx
/* platform: windows */
say SysTempFileName("/temp/myfile.***", "*")
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
C:\temp\myfile.938
```

the code:
```rexx
/* platform: unix */
say SysTempFileName("/temp/myfile.***", "*")
```
the result:
```
/temp/myfile.667
```
the reference says:
```
/temp/myfile.341
```

```
SysTextScreenRead(row, col [,len])
```
systextscreenread: a rexxutil function that gives characters from the buffer of the console screen
this function runs only on the windows platform.
this function gives characters from a place in the buffer of the console screen.
the first argument is the line where the function starts to read; the first line is line 0.
the second argument is the position in the line where the function starts to read; the first position is 0.
the third argument is the count of characters to read.
the default is to read to the end of the buffer.
the function reads only the characters, not the color of each character.
if you write the string to the screen again with say or charout, it does not have the color of each character that it had.
the code:
```rexx
/* platform: windows */
-- read the entire console screen buffer
screen = SysTextScreenRead(0, 0)

-- read one screen buffer line
parse value SysTextScreenSize() with rows columns
line = SysTextScreenRead(2, 0, columns)
```
the result:
```
not run: this example is for the windows platform
```

```
SysTextScreenSize([option])
```
systextscreensize: a rexxutil function that gives or sets the size of the console buffer and the place of the console window
this function runs only on the windows platform.
this function gives or sets the size of the buffer of the console screen.
it also gives or sets the place of the console window in the buffer, and gives the maximum size of the console window.
the option argument says which size or place the function gives or sets.
```
BUFFERSIZE
```
with this option, the function gives the size of the console buffer: the count of lines and the count of positions in a line, with a blank between them.
if no console is there, the result is 0 0.
to set the size, give the count of lines and the count of positions as the second argument and the third argument.
the buffer can not be less than the current console window.
if the function sets the size, the result is 0, else an error code of windows.
this option is the default.
```
WINDOWRECT
```
with this option, the function gives four numbers: the first line, the first position, the last line, and the last position of the console window in the buffer.
the first line of the buffer is line 0, and the first position is 0.
if no console is there, the result is 0 0 0 0.
to set the place, give the four numbers as the second, third, fourth, and fifth arguments.
the window must be in the buffer.
if the function sets the place, the result is 0, else an error code of windows.
```
MAXWINDOWSIZE
```
with this option, the function gives the maximum size of the console window: the count of lines and the count of positions in a line.
this size comes from the current buffer, the size of the characters, and the size of the screen.
if no console is there, the result is 0 0.
the code:
```rexx
/* platform: windows */
parse value SysTextScreenSize() with rows columns
parse value SysTextScreenSize("windowrect") with top left bottom right
say "current console buffer is" rows "rows by" columns "columns"
say "current window rectangle is ("top"," left") ("bottom"," right")"
```
the result:
```
not run: this example is for the windows platform
```

```
SysToUnicode(string [,codepage] [,translateflags], outstem)
```
systounicode: a rexxutil function that changes a string from a code page to the unicode form that windows uses
this function runs only on the windows platform.
this function changes a string from a code page to the unicode form that windows uses, with two bytes for each code.
the string argument is the string to change.
the second argument is the code page of the string.
the second argument can be the number of a code page, as 437 or 1252, or one of these names.
```
codepage ACP
```
with this code page, the function uses the default code page of the windows system.
```
codepage CONSOLE
```
with this code page, the function uses the code page of the current console.
```
codepage MACCP
```
with this code page, the function uses a code page of the system for one kind of computer.
the reference says not to use this code page.
```
codepage OEMCP
```
with this code page, the function uses the oem code page of the system.
this code page is the default.
```
codepage SYMBOL
```
with this code page, the function uses the symbol code page.
the reference says not to use this code page.
with this code page, you can not give flags; then the result is the code 1004.
```
codepage THREAD_ACP
```
with this code page, the function uses the default code page of windows for the current thread.
```
codepage UTF7
```
with this code page, the function uses the seven bit form of unicode.
the reference says not to use this code page, and to use the next code page in its place.
with this code page, you can not give flags; then the result is the code 1004.
```
codepage UTF8
```
with this code page, the function uses the eight bit form of unicode.
the third argument is a list of flags that say how the function changes the string.
you can not give the next two flags at the same time.
```
translateflags COMPOSITE
```
with this flag, the result has a character and its marks as more than one character.
```
translateflags PRECOMPOSED
```
with this flag, the result has a character and its marks as one character.
this flag is the default.
```
translateflags ERR_INVALID_CHARS
```
with this flag, if the function finds a character that is not valid, it stops and the result is the code 1113.
```
translateflags USEGLYPHCHARS
```
with this flag, the function uses characters that show as marks in place of control characters.
the fourth argument is the name of a stem for the result.
if there is no error, the variable of that stem with the tail !TEXT has the new string.
the result is 0 if there is no error.
else the result is an error code of windows; it can be one of these codes, but it can also be an other code.
the code 87 says an argument is not valid: the string has too many characters, or the code page is not a valid code page of windows.
the code 1004 says the flags are not valid, as when you give flags with one of the code pages 50220, 50221, 50222, 50225, 50227, 50229, 57002 to 57011, and 54936.
the code 1113 says a unicode character has no character in the code page.

```
SysUtilVersion()
```
sysutilversion: a rexxutil function that gives the version of the rexxutil package
this function gives a version number of the rexxutil package that runs now.
the result is three numbers with a point between each two of them.

```
SysVersion()
```
sysversion: a rexxutil function that gives the name and the version of the system
this function gives a string.
the first word of the string is the name of the system.
the rest of the string is the version of the system, in the form that the system uses.
a program must not need the result to be in one set form.
the reference says that these results are only what the output can be.
the code:
```rexx
-- CentOS 7
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Linux 3.10.0-957.10.1.el7.x86_64
```

the code:
```rexx
-- Ubuntu 16.04
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Linux 4.4.0-154-generic
```

the code:
```rexx
-- macOS 10.13
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Darwin 18.7.0
```

the code:
```rexx
-- Raspbian
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Linux 4.14.70-v7+
```

the code:
```rexx
-- SLES/390
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Linux 3.12.74-60.64.40-default
```

the code:
```rexx
-- Windows 10
say SysVersion()
```
the result:
```
Linux 6.18.44-fc-v180
```
the reference says:
```
Windows 10.0.18363
```

```
SysVolumeLabel([drive])
```
sysvolumelabel: a rexxutil function that gives the label of the disk in a drive
this function runs only on the windows platform.
this function gives the label of the disk in a drive.
the drive argument names the drive.
if you omit the drive argument, the function uses the current drive.

```
SysWait()
```
syswait: a rexxutil function that waits until each child process ends
this function runs only on the unix platform.
this function waits until each child process ends.
the result is the exit code from the child process.

```
SysWaitNamedPipe(name [,timeout])
```
syswaitnamedpipe: a rexxutil function that waits for a named pipe for a set time
this function runs only on the windows platform.
this function waits for a named pipe for a set time.
the name argument is the name of the pipe: two backslash marks, the name of the computer, a backslash, the word pipe, a backslash, and the name of the pipe.
the second argument is the time to wait, in microseconds.
if you omit the second argument, or it is 0, the function uses the default time.
if the second argument is -1, the function waits until the pipe is not in use.
the result is 0 if there is no error.
else the result is an error code of windows.

```
SysWinDecryptFile(filename)
```
syswindecryptfile: a rexxutil function that you call to decrypt a file
this function runs only on the windows platform.
this function makes the system decrypt a file.
the first argument is the name of the file to decrypt.
the result is 0 if the function can decrypt the file.
else the result is an error code of windows; it can be one of these codes, but it can also be an other code.
the code 2 says the file is not found.
the code 4 says the function can not open the file.
the code 5 says the system does not let the user do it.
the code 82 says the function can not decrypt the file.

```
SysWinEncryptFile(filename)
```
syswinencryptfile: a rexxutil function that you call to encrypt a file
this function runs only on the windows platform.
this function makes the system encrypt a file.
the first argument is the name of the file to encrypt.
the result is 0 if the function can encrypt the file.
else the result is an error code of windows; it can be one of these codes, but it can also be an other code.
the code 2 says the file is not found.
the code 4 says the function can not open the file.
the code 5 says the system does not let the user do it.
the code 82 says the function can not encrypt the file.

```
SysWinGetDefaultPrinter()
```
syswingetdefaultprinter: a rexxutil function that gives the default printer
this function runs only on the windows platform.
this function gives the current default printer.
the result is three names with a comma between each two: the name of the printer, the name of its driver, and the name of its port.

```
SysWinGetPrinters(stemarray)
```
syswingetprinters: a rexxutil function that gives a list of the printers
this function runs only on the windows platform.
this function gives a list of the printers that the system can use.
the first argument is a stem or an array for the list.
with a stem, the item with the tail 0 is the count of printers, and the items with the tails from 1 to that count are the printers.
each item is three names with a comma between each two: the name of the printer, the name of its driver, and the name of its port.
the result is 0 if there is no error.
the result is 1 if there is an error.

```
SysWinSetDefaultPrinter(description)
```
syswinsetdefaultprinter: a rexxutil function that sets the default printer
this function runs only on the windows platform.
this function sets the default printer.
the first argument names the printer.
it can be only the name of the printer, or three names with a comma between each two: the name of the printer, the name of its driver, and the name of its port.
use only the name of the printer; the form with three names uses a function of windows that is deprecated.
the result is 0 if there is no error.
else the result is an error code of windows.
the function sysgeterrortext gives the text for an error code.

```
SysWinVer()
```
syswinver: a rexxutil function that gives the version of the windows system
this function runs only on the windows platform.
this function gives a string that says the version of the windows system.
a program must not need the result to be in one set form.
the reference says that these results are only what the output can be.
the code:
```rexx
/* platform: windows */
-- Windows 7
say SysWinVer()
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
Windows 6.01.7601
```

the code:
```rexx
/* platform: windows */
-- Windows 10
say SysWinVer()
```
the result:
```
not run: this example is for the windows platform
```
the reference says:
```
Windows 10.0.18363
```

## the deprecated functions

eventsemaphore: the name of a class of oorexx
mutexsemaphore: the name of a class of oorexx

```
SysLoadFuncs
```
sysloadfuncs: a deprecated rexxutil function
this function is deprecated.
from oorexx 4.0.0 on, this function does nothing.

```
SysDropFuncs
```
sysdropfuncs: a deprecated rexxutil function
this function is deprecated.
from oorexx 4.0.0 on, this function does nothing.

```
SysCloseEventSem
```
syscloseeventsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysCloseMutexSem
```
sysclosemutexsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysCreateEventSem
```
syscreateeventsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysCreateMutexSem
```
syscreatemutexsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysOpenEventSem
```
sysopeneventsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysOpenMutexSem
```
sysopenmutexsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysPostEventSem
```
sysposteventsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysPulseEventSem
```
syspulseeventsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysReleaseMutexSem
```
sysreleasemutexsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysRequestMutexSem
```
sysrequestmutexsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysResetEventSem
```
sysreseteventsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.

```
SysWaitEventSem
```
syswaiteventsem: a deprecated rexxutil function
this function is deprecated.
use the eventsemaphore class or the mutexsemaphore class in its place.
