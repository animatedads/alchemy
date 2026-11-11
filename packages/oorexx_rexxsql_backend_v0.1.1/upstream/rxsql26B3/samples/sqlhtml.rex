#!/usr/local/bin/rexxsql
/***********************************************************************
 * Program     : sqlhtml.rex
 * Version     : 1.10
 * Author      : Mark Hessling
 * Date        : 09 Mar 1996
 * Purpose     : This program runs as a CGI-BIN executable and provides
 *             : a user with a WWW browser the ability to execute any
 *             : valid SQL on a SQL database.  The one program accepts
 *             : database/user and the SQL command the user wants to
 *             : run. This program also displays the result of the SQL
 *             : command.
 * Arguments   : None.
 * Notes       : The first line of this program must point to the
 *             : full filename of your REXXSQL executable.
 *             : Also, the location of this script (in relation to the
 *             : httpd cgi-bin directory) needs to be specified in the
 *             : formstart procedure.
 ***********************************************************************/
Trace i

version = sqlvariable('VERSION')
If Word(version,6) = 'OS/2' Then env = 'OS2ENVIRONMENT'
Else env = 'SYSTEM'

arguments = ''
If Value('CONTENT_LENGTH',,env) \= '' Then Parse Pull arguments
arguments = Hexconvert(clean(arguments))

Call display_head
Select
  When arguments = '' Then Call get_connect
  When Substr(arguments,1,8) = 'username' | Substr(arguments,1,6) = 'dbname' Then Call get_command arguments
  Otherwise Call execute_query arguments
End
Exit 0

/***********************************************************************/
/* This procedure displays the logon screen                            */
/***********************************************************************/
get_connect: Procedure Expose version
Call formstart
Call explain 'LOGON'
Select
  When Word(version,7) = 'ORACLE' Then
       Do
         Say 'Username: <INPUT SIZE=30 MAXLENGTH=30 NAME="username"> <P>'
         Say 'Password: <INPUT TYPE="password" SIZE=30 MAXLENGTH=30 NAME="password"> <P>'
         Say 'Connect string (optional): <INPUT SIZE=30 NAME="host"> <P>'
       End
  When Word(version,7) = 'MSQL' Then
       Do
         Say 'mSQL database: <INPUT SIZE=30 MAXLENGTH=30 NAME="dbname"> <P>'
         Say 'mSQL host (optional): <INPUT SIZE=30 NAME="host"> <P>'
       End
  Otherwise Nop
End
Say 'To connect, press this button: <INPUT TYPE="submit" VALUE="Connect">. <P>'
Call formend
Return

/***********************************************************************/
/* This procedure displays the query screen                            */
/***********************************************************************/
get_command: Procedure Expose version
username = ''
password = ''
dbname = ''
host = ''
Select
  When Word(version,7) = 'ORACLE' Then
       Do
         Parse Arg 'username=' username '&' . 'password=' password '&' . 'host=' host .
       End
  When Word(version,7) = 'MSQL' Then
       Do
         Parse Arg 'dbname=' dbname '&' . 'host=' host .
       End
  Otherwise Nop
End
If sqlconnect('TEST',username,password,dbname,host) < 0 Then Abort()
If sqldisconnect('TEST') < 0 Then Abort()
Call formstart
Call explain 'QUERY'
Say '<INPUT TYPE="hidden" NAME="action" VALUE="query">'
Say '<INPUT TYPE="hidden" NAME="username" VALUE="'username'">'
Say '<INPUT TYPE="hidden" NAME="password" VALUE="'password'">'
Say '<INPUT TYPE="hidden" NAME="dbname" VALUE="'dbname'">'
Say '<INPUT TYPE="hidden" NAME="host" VALUE="'host'">'
Say 'Query: <INPUT SIZE=50 NAME="query"> <P>'
Say 'To execute query, press this button: <INPUT TYPE="submit" VALUE="Execute">. <P>'
Call formend
Return

/***********************************************************************/
/* This procedure executes the SQL command.                            */
/***********************************************************************/
execute_query: Procedure Expose version sqlca.
Parse Arg . 'username=' username '&' . 'password=' password '&' . 'dbname=' dbname '&' . 'host=' host '&' .'query=' query
Say '<H2>Results of statement:</H2><P>'
Say '<H3>'query'</H3><P>'
If sqlconnect('TEST',username,password,dbname,host) < 0 Then Abort()
If SQLPrepare('S1',query) < 0 Then Abort()

cmd = Translate(Word(query,1))
Select
  When cmd = 'SELECT' Then Call QueryStatement
  When cmd = 'INSERT' | cmd = 'DELETE' | cmd = 'UPDATE' Then Call ExecuteStatement cmd
  Otherwise Say 'Statement executed successfully'
End
If sqldisconnect('TEST') < 0 Then Abort()
Return

/***********************************************************************/
/* This procedure displays the results screen                          */
/***********************************************************************/
QueryStatement: Procedure Expose sqlca.
cols = SQLDescribe('S1')
If cols < 0 Then Abort()
line = ''
just. = 'L'
Do i = 1 To cols
  If Substr(type,1,4) = 'LONG' Then s1.column.size.i = 80
  Else 
    Do
      If s1.column.precision.i = 0 Then s1.column.size.i = s1.column.size.i + s1.column.scale.i
      Else s1.column.size.i = s1.column.precision.i + s1.column.scale.i
    End
  s1.column.size.i = max(s1.column.size.i,Length(s1.column.name.i))
  If s1.column.type.i = 'NUMBER',
  |  s1.column.type.i = 'INT',
  |  s1.column.type.i = 'REAL' Then 
    Do
      just.i = 'R'
      s1.column.size.i = Min(15,s1.column.size.i)
     line = line Right(s1.column.name.i,s1.column.size.i)
    End
  Else
    line = line Left(s1.column.name.i,s1.column.size.i)
End
/*---------------------------------------------------------------------*/
/* Start displaying the results...                                     */
/*---------------------------------------------------------------------*/
Say '<PRE>'
Say line
Say '<HR>'
If SQLOpen('S1') < 0 Then Abort()
cnt = 0
Do Forever
   rc = SQLFetch('S1')
   If rc < 0 Then Abort()
   If rc = 0 Then Leave
   line = ''
   cnt = cnt + 1
   Do j = 1 To cols
      nam = Translate(s1.column.name.j)
      If just.j = 'R' Then
         line = line Right(s1.nam,s1.column.size.j)
      Else
         line = line Left(s1.nam,s1.column.size.j)
   End
   Say line
End
Say
Say '<HR>'
Say cnt "row(s) selected."
Say '</PRE>'
Return

/***********************************************************************/
/* This procedure executes non-SELECT statements.                      */
/***********************************************************************/
ExecuteStatement: Procedure Expose sqlca. version
dml = 'INSERT DELETE UPDATE'
rsp = 'inserted deleted updated'
Parse Upper Arg cmd .
If sqlexecute('S1') < 0 Then Abort()
Say '<PRE>'
If Word(version,7) = 'MSQL' Then
  Do
    Say 'Statement executed successfully'
    Return
  End
idx = Wordpos(cmd,dml)
Say sqlca.rowcount 'rows' Word(rsp,idx)
Say '</PRE>'
Return

/***********************************************************************/
/* This procedure displays the form start strings                      */
/***********************************************************************/
formstart: Procedure
Say '<FORM METHOD="POST" ACTION="http://boojum4/cgi-bin/sqlhtml.rex">'
Return

/***********************************************************************/
/* This procedure displays the initial HTML format and title           */
/***********************************************************************/
display_head: Procedure
Say 'Content-type: text/html'
Say
Say '<TITLE>REXX/SQL Query Tool</TITLE>'
Return

/***********************************************************************/
/* This procedure displays explanation info...                         */
/***********************************************************************/
explain: Procedure
Parse Arg status .
If status = 'LOGON' Then
   Do
     Say '<H3>This form accepts connection information specific to the database'
     Say 'to which you wish to connect.</H3><P>'
   End
Else
   Do
     Say '<H3>This form accepts a SQL query which is passed to the database to'
     Say 'which you have connected.</H3><P>'
   End
Return

/***********************************************************************/
/* This procedure displays the form end strings                        */
/***********************************************************************/
formend: Procedure
Say '</FORM>'
Return

/***********************************************************************/
/* This procedure displays errors from REXX/SQL or the database        */
/***********************************************************************/
Abort: Procedure Expose sqlca.
If sqlca.intcode = '-1' Then
   Say '<H2>' sqlca.sqlerrm '</H2>'
Else
   Say '<H2>' sqlca.interrm '</H2>'
Exit 0
Return

/***********************************************************************/
/* This procedure removes any trailing CR from the passed argument.    */
/***********************************************************************/
clean: Procedure
Parse Arg line
len = Length(line)
If len = 0 Then Return line
If C2D(Substr(line,len,1)) = 13 Then line = Substr(line,1,len-1)
Return line

/***********************************************************************/
/* This procedure converts Hex values of the form %XX into their real  */
/* values. Also converts "+" to " ".                                   */
/***********************************************************************/
Hexconvert: Procedure
Parse Arg line
len = Length(line)
line = Translate(line," ","+")
newline = ''
i = 0
Do Forever
   i = i + 1
   If i > len Then Leave
   ch = Substr(line,i,1)
   If ch = '%' Then
      Do
        newline = newline || X2C(Substr(line,i+1,2))
        i = i + 2
      End
   Else
      newline = newline || ch
End
Return newline
