/***********************************************************************
 * Program     :  sqlplus.rex
 * Version     :  1.10
 * Author      :  Chris O'Sullivan
 * Updates     :  Mark Hessling
 * Date        :  09 Mar 1996
 * Purpose     :  A simple formatting of dynamic queries. Works like a
 *             :  crude Oracle SQL*Plus.
 * Arguments   :  For Oracle:
 *             :     username
 *             :     password
 *             :     SELECT statement
 *             :  For mSQL:
 *             :     database name
 *             :     host
 *             :     SELECT statement
 * Platform    :  Oracle, mSQL
 * Notes       :  There MUST be a semi-colon preceding the SQL statement
 *             :  to seperate the statement from the optional arguments.
 ***********************************************************************/
If Arg() < 2 Then usage()
Trace o
pagesize = 22  /* Lines per page */
linesize = 80  /* Columns */
Call Initialise
void = SQLVariable("rowlimit",13)
Parse Arg arg1 arg2 ':' query
username = ''
password = ''
dbname = ''
host = ''
Select
  When database = 'ORACLE' Then
                           Do
                             username = arg1
                             password = arg2
                           End
  When database = 'MSQL' Then
                           Do
                             dbname = arg1
                             host = arg2
                           End
  Otherwise Nop
End
If SQLConnect('db1',username,password,dbname,host) < 0 Then Abort()
If SQLPrepare('S1', query) < 0 Then Abort()

/* Open a cursor for the statement */
rc = SQLOpen('S1')
If rc < 0 Then Abort()

/* Get a column description */
cols = SQLDescribe('S1')

/* Determine how many columns fit on page 
 * Note the following:
 *
 * 1) The SQLDescribe() function returns column names/expressions in upper case.
 * In Oracle this is a consequence of the Oracle OCI function "odescr()". 
 * SQL*Plus does not use OCI and hence returns the true form of the 
 * column name/expression!
 *
 * 2) SQLDescribe() returns the following attributes of the parsed statement:
 *      <stem-name>.COLUMN.<attribute-name>.<column-index>
 *
 * where <attribute-name> is one of:
 *   NAME	Name of the column/expression (up to 30 chars)
 *   TYPE	type of column/expression as a string. Values are:-
 *		"VARCHAR2","CHAR","NUMBER","DATE","ROWID,"RAW","LONG","LONG RAW"
 *		"MLSLABEL"
 *   SIZE	maximum size that will be returned to Rexx
 *   PRECISION	precision (NUMBER only)
 *   SCALE	scale (NUMBER only)
 *   NULLOK	0=null not permitted, <>0=null permitted
 */
cnt = 0
j = 0
Do i = 1 To cols /* Could use "S1.COLUMN.NAME.0" etc. !!! */
  Select
    When s1.column.type.i = "NUMBER" Then
      len = 10	/* Rexx/SQL for Oracle returns these as length 40! */
    When s1.column.type.i = "INT" Then
      len = 10
    When s1.column.type.i = "REAL" Then
      len = 10
    When s1.column.type.i = "LONG" | s1.column.type.i = "LONG RAW" Then
      len = 80	/* Rexx/SQL returns these as length 32767! */
    Otherwise
      len = s1.column.size.i
  End /* Select */
  
  If cnt + len > linesize Then Leave
  cnt = cnt + len + 2
  j = j + 1
  s1.column.width.i = len
End
cols = j

/* Print the rows fetching in groups of PAGESIZE. This will be more efficient
 * when array processing is implemented! Currently there is no difference
 * to that above!
 */
cnt = 0
Do Forever
  rc = SQLFetch('S1',pagesize)
  If rc < 0 Then Abort()
  If rc = 0 Then Leave
  Call Print_Hdg
  Do i = 1 To sqlca.rowcount
    cnt = cnt + 1
    row = ""
    Do j = 1 To cols
      nam = Translate(s1.column.name.j)
      If s1.column.type.j = "NUMBER" Then
        Do
          If Length(s1.nam.i) > s1.column.width.j Then
            fld = Copies("#",s1.column.width.j)
          Else
            fld = Right(s1.nam.i,s1.column.width.j)
        End
      Else
        fld = Substr(s1.nam.i,1,s1.column.width.j)
      If j > 1 Then row = row || "  "
      row = row||fld
    End
    Say row
  End
  If rc < pagesize Then leave
End
Say
Say cnt "rows selected."

/* 
 * Note: Exiting REXX/SQL will close all cursors, release all connections and
 *       free all associated resources. It is more efficient to let REXX/SQL
 *       disconnect then to code it in REXX!  Variables are not freed!
 */
Call Finalise
Exit 0


/***********************************************************************/
usage: Procedure
/***********************************************************************/
  Say "Usage: <username/password>|<database> <SELECT statement>"
  Exit 0

/***********************************************************************/
print_hdg: Procedure Expose cols s1.
/***********************************************************************/
l1 = ""
l2 = ""
Do i = 1 To cols
  If s1.column.type.i = "NUMBER" Then
    hdg = Right(Strip(Left(s1.column.name.i,s1.column.width.i)),s1.column.width.i)
  Else
    hdg = Left(s1.column.name.i,s1.column.width.i)
  If i > 1 Then
    Do
      l1 = l1 || "  "
      l2 = l2 || "  "
    End
  l1 = l1||hdg
  l2 = l2||Copies("-",s1.column.width.i)
End
Say
Say l1
Say l2
Return 3


/*
 * PURPOSE : Print the SQL error
 * SYNOPSIS: PrintSQLError(prompt,msg,left-margin,width)
 * RETURNS : Number of lines printed
 */
/***********************************************************************/
PrintSQLError:	Procedure Expose sqlca.
/***********************************************************************/
    /* Print the message text */
  leftmargin = Arg(3)
  prompt = Right(arg(1),leftmargin)
  width = Arg(4)
  msg = Arg(2)
  cnt = 0
  Do While msg \= ""
    Say prompt||Substr(msg,1,width)
    prompt = Right("",leftmargin)
    msg = Substr(msg,width+1)
    cnt = cnt + 1
  End
  Return cnt


/* Returns date & time in format "Mon dd  hh:mi:ss " */
/***********************************************************************/
DateTime:
/***********************************************************************/
  Return Substr(date('M'),1,3) Substr(date('E'),1,2)||'  '||Time()||' '


/* Here on fatal error */
/***********************************************************************/
Abort: Procedure Expose sqlca.
/***********************************************************************/
  Say
  If Arg() \= 0 Then
    Do
      Say arg(1)
      If sqlca.sqlerrm = "" Then
         void = PrintSQLError("",sqlca.interrm,0,72)
      Else
         void = PrintSQLError("",sqlca.sqlerrm,0,72)
      Say
    End
  Else
    Do
      Say "Fatal error trapped in execution of SQL statement:"
      Say

      /* Print the statement text (if any)*/
      If sqlca.sqltext \= "" Then
      Do
        hdr = ' Statement:'
        txt = sqlca.sqltext
        Do while txt \= ""
          Say hdr Substr(txt,1,60)
          hdr = "           "
          txt = Substr(txt,61,1000)
        End
        Say
      End

      Say "      Call:" sqlca.function||"()"
      Say
      void = PrintSQLError("Error: ",sqlca.sqlerrm,12,60)
      Say
    End
  Exit 1

/***********************************************************************/
Initialise:
/***********************************************************************/
Parse Source os method .
If os = 'OS/2' & method = 'COMMAND' Then
   Do
     Call RXFuncAdd 'SqlLoadFuncs','REXXSQL','SqlLoadFuncs'
     Call SqlLoadFuncs
     dll = 'YES'
   End
version = sqlvariable("VERSION")
If version < 0 Then Abort()
database = Word(version,7)
Return

/***********************************************************************/
Finalise:
/***********************************************************************/
If dll = 'YES' Then Call SqlDropFuncs
Return
