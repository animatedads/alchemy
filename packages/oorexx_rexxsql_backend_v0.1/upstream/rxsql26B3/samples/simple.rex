/***********************************************************************
 * Program     : simple.rex
 * Version     : 1.10
 * Author      : Mark Hessling
 * Date        : 09 Mar 1996
 * Purpose     : This program is an example of how simple it is to
 *             : display information from a SQL database.
 * To run:     : rexxsql simple.rex
 *             : Under OS/2, you can rename the file to simple.cmd
 *             : and simply type "simple" to execute it.
 *             : Under Unix, you can add a line as the first line
 *             : of the program like:
 *             : #! /usr/local/bin/rexxsql
 *             : and simply type "simple.rex" to execute it.
 * Platform    : Oracel, mSQL
 * Arguments   : None.
 ***********************************************************************/
Trace o
query1 = "select empno, ename, sal from emp order by empno"
username.oracle = "scott"
password.oracle = "tiger"
dbname.oracle   = ""
username.msql   = ""
password.msql   = ""
dbname.msql     = "REXXSQL"

Call Initialise
If sqlconnect(,username.database,password.database,dbname.database) < 0 Then Abort()
If sqlcommand("Q1",query1) < 0 Then Abort()
Do i = 1 To q1.empno.0
   Say Right(q1.empno.i,6) Left(q1.ename.i,15) Right(q1.sal.i,8)
End
Call Finalise
Return

/***********************************************************************/
Abort: Procedure Expose sqlca.
/***********************************************************************/
Parse Arg text
If text \= '' Then Say text
Else
   If sqlca.intcode = -1 Then Say sqlca.sqlerrm
   Else Say sqlca.interrm
Call Finalise
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
