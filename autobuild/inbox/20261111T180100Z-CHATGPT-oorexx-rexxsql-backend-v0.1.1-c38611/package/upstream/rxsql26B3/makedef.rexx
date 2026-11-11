/*
 * This program creates a DLL import file for Rexx/SQL on Windows and OS/2 platforms
 * Args:
 * db      - database mnemonic (upper case) or 'SQL'
 * deftype - 'EXE' or 'DLL' or 'EXP' - determines if the funcs are output and DEF header
 * os      - 'OS2' or 'W32' or 'W64' or 'AIX'
 * outfile - file to write
 */
Parse Arg db deftype os outfile database
funcs =     '%D%LoadFuncs',
        'Rexx%D%DropFuncs',
        'Rexx%D%Connect',
        'Rexx%D%Disconnect',
        'Rexx%D%Command',
        'Rexx%D%Variable',
        'Rexx%D%Default',
        'Rexx%D%Commit',
        'Rexx%D%Rollback',
        'Rexx%D%Prepare',
        'Rexx%D%Dispose',
        'Rexx%D%Open',
        'Rexx%D%Execute',
        'Rexx%D%Close',
        'Rexx%D%Fetch',
        'Rexx%D%Describe',
        'Rexx%D%DataSources',
        'Rexx%D%Tables',
        'Rexx%D%Columns',
        'Rexx%D%GetInfo',
        'Rexx%D%GetData'
If db = 'SQL' Then
   Do
      library = 'REXXSQL'
      description = 'Rexx/SQL for' os
   End
Else
   Do
      library = 'REXX'db
      description = 'Rexx/SQL for' db
   End

header = os||deftype
Call Stream outfile, 'C', 'OPEN WRITE REPLACE'
Interpret 'Call' header
Return 0

Exports:
If os = 'OS2' | os = 'AIX' Then exports = ''
Else exports = 'EXPORTS'
Do i = 1 To Words( funcs )
   Call Lineout outfile, exports Changestr( '%D%', Word( funcs, i ), db )
End
/*
 * Add extra, database specific functions
 */
If database = 'LITE' Then
   Do
      Call Lineout outfile, exports 'RexxLITEGetInsertId'
   End
If database = 'MY' Then
   Do
      Call Lineout outfile, exports 'RexxMYGetInsertId'
   End
If database = 'ORA' Then
   Do
      Call Lineout outfile, exports 'RexxORAStartup'
      Call Lineout outfile, exports 'RexxORAShutdown'
   End

Call Stream outfile, 'C', 'CLOSE'
Return 0

w32dll:
Call Lineout outfile, 'LIBRARY' library 'INITINSTANCE'
Call Lineout outfile, 'HEAPSIZE 40960'
Call Lineout outfile, 'STACKSIZE 10240'
Call Exports
Return

w64dll:
Call Lineout outfile, 'LIBRARY' library
Call Lineout outfile, 'HEAPSIZE 40960'
Call Lineout outfile, 'STACKSIZE 10240'
Call Exports
Return

w32exe:
Call Abort 'w32exe should not be called!'
Return

w64exe:
Call Abort 'w64exe should not be called!'
Return

os2dll:
Call Lineout outfile, 'LIBRARY' library
Call Lineout outfile, "DESCRIPTION '"description"'"
Call Lineout outfile, 'DATA    MULTIPLE NONSHARED'
Call Lineout outfile, ''
Call Lineout outfile, 'STACKSIZE   32768'
Call Lineout outfile, ''
Call Lineout outfile, 'PROTMODE'
Call Lineout outfile, ''
Call Lineout outfile, 'EXPORTS'
Call Exports
Return

os2exe:
Call Lineout outfile, 'NAME' library 'WINDOWCOMPAT NEWFILES'
Return

aixexp:
Call Exports
Return

Abort: Procedure
Parse Arg msg
Say msg
Exit 1
