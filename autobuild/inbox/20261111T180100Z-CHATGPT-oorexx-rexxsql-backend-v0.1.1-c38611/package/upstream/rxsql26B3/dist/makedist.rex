/**/
Trace o
Parse Arg os db ver .
If ver = '' Then
  Do
     Say 'Usage: makedist.rex os db ver'
     Say 'where: os - os2 or w32'
     Say '       db - one of "ora saw odbc min2 sol db2 udbc my vel lite "'
     Say '       ver - 2.4 eg'
     Exit 1
  End
If Stream('rexxsql.exe','C','QUERY EXISTS') = '' Then
   Do
      Say 'This program must be run from a directory that contains rexxsql.exe'
      Exit 1
   End

If os = 'w32' Then
  Do
    database.1 = "Oracle"
    database.2 = "SQLAnyWhere"
    database.3 = "MS ODBC 3.0+"
    database.4 = "mSQL 2.0"
    database.5 = "Solid Server"
    database.6 = "DB2/NT"
    database.7 = "Openlink UDBC"
    database.8 = "MySQL"
    database.9 = "Raima Velocis"
    database.10 = "SQLite"
    database.11 = "SQLite3"
    dirs1 = 'ora saw odbc min2 sol db2 udbc my vel lite lite3'
    zipfiles = '*'
    envvar = 'REXXSQL_SRCDIR'
  End
Else
  Do
    database.1 = "Oracle"
    database.2 = "SQLAnyWhere"
    database.3 = "ODBC"
    database.4 = "mSQL 1.0.16"
    database.5 = "mSQL 2.0+"
    database.6 = "Solid Server"
    database.7 = "Openlink UDBC"
    database.8 = "DB2/2"
    database.9 = "MySQL"
    database.10 = "SQLite"
    database.11 = "SQLite3"
    dirs1 = 'ora saw odbc min min2 sol udbc db2 my lite lite3'
    zipfiles = '*'
    envvar = 'REXXSQL_SRCDIR'
  End

rexxsqldir = Value(envvar,,'ENVIRONMENT')
distdir = rexxsqldir || '\dist'
samplesdir = rexxsqldir || '\samples'
targetdir = distdir|| '\' || db
Say 'distdir is' distdir
rexxtransdir = Value('REXXTRANS_BINDIR',,'ENVIRONMENT')

dotversion = ver
version = Changestr('.',ver,'')
k = pos(db,dirs1)
src.=''


/* remove all files in directory, or create directory */
If Stream(targetdir,'C','QUERY EXISTS') = '' Then
   'mkdir' targetdir
Else
   'del' targetdir || '\*.*'

/*
 * Special for min2 - change min2 to min for executable and DLLs
 */
If db = 'min2' Then dbb = 'min'
Else dbb = db
/* Copy files to dist dir */
'copy' rexxsqldir'\README' targetdir
'copy' rexxsqldir'\COPYING-LIB' targetdir
'copy' rexxsqldir'\HISTORY' targetdir
'copy' rexxsqldir'\INSTALL' targetdir
'copy' samplesdir'\tester.cmd' targetdir
'copy' samplesdir'\simple.cmd' targetdir
'copy' samplesdir'\blob.cmd' targetdir
'copy  rexxsql.exe' targetdir
'copy  rexxsql.dll' targetdir
'copy  rexx'dbb'.exe' targetdir
'copy  rexx'dbb'.dll' targetdir
'copy' distdir'\README.rexxsql.tmpl.'os targetdir'\README.rexxsql'
If os = 'w32' Then
   Do
      rexxtrans = rexxtransdir'\rexxtrans.dll'
   End
Else
   Do
      rexxtrans = 'c:\dll\rexxtran.dll'
   End
If Stream(rexxtrans,'C','QUERY EXISTS') = '' Then
   Do
      Say 'Cannot find Rexx/Trans DLL:' rexxtrans
      Exit 1
   End
'copy' rexxtrans targetdir

files = 'file_id.diz README.'db
Do i = 1 To Words(files)
   infile = distdir'\'Word(files,i)'.'os
   Say 'Processing...' infile
   j = 0
   Do While(Lines(infile)>0)
      j = j + 1
      src.j = Linein(infile)
   End
   src.0 = j
   outfile = targetdir'\'Word(files,i)
   Address System 'del' outfile
   Do m = 1 To src.0
      line = ProcessLine(src.m)
      rc = Lineout(outfile,line)
   End
   rc = Stream(outfile,'C','CLOSE')
End

rc = chdir(targetdir)
Say 'Changed directory to' targetdir 'with rc=' rc
zipfile = 'rxsql'version'_'db'_'os'.zip'
If rc \= 0 Then
   Do
      Say 'Cannot change directory. You have to run: zip' zipfile zipfiles 'manually'
      Return 1
   End
Address System 'zip' zipfile zipfiles
Address System 'copy' zipfile distdir
Return 0

ProcessLine:
Parse Arg myline
myline = Changestr('[*database*]',myline,database.k)
If os = 'w32' Then myline = Changestr('[*interpreter*]',myline,'most Rexx interpreters')
Else myline = Changestr('[*interpreter*]',myline,"OS/2 Rexx or Object Rexx")
myline = Changestr('[*DB*]',myline,Translate(Word(dirs1,k)))
If os = 'w32' Then myline = Changestr('[*INT*]',myline,'R')
Else myline = Changestr('[*INT*]_',myline,"")
myline = Changestr('[*version*]',myline,version)
myline = Changestr('[*dotversion*]',myline,dotversion)
If Substr(myline,1,1) = '+' Then myline = Center(Strip(Substr(myline,2)),75)
Return myline
