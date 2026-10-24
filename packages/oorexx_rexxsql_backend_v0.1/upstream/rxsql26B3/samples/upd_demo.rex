/***********************************************************************
 * Program     : upd_demo.rex
 * Version     : 1.10
 * Author      : Mark Hessling
 * Date        : 09 Mar 1996
 * Purpose     : This program updates the EMP table of scott/tiger.
 *             : It adds 30 to the SAL column, reporting the SAL
 *             : column before and after the update.  The method used
 *             : to do the updating is purely  to test as many of the
 *             : REXX/SQL functions as possible, not as good coding
 *             : technique!
 * Arguments   : anything - if an argument is supplied the updates
 *             :            are committed, otherwise they are
 *             :            rolled back.
 * Platform    : Oracle - uses bind variables
 ***********************************************************************/
Trace o
query1 = "select empno, sal from emp where deptno = 20 order by empno"
If Arg() \= 0 Then commit = 1
Else commit = 0

Call Initialise

username="scott"
password="tiger"
If sqlconnect(,username,password) < 0 Then Abort()

Call display_current "*** Initial ***",query1
If sqlprepare("AA",query1) < 0 Then Abort()
If sqlprepare("BB","update emp set sal = :NEWSAL where empno = :EMPNO") < 0 Then Abort()
If sqlopen("AA") rc < 0 Then Abort()
Do Forever
   rc = sqlfetch("AA") 
   If rc < 0 Then Abort()
   If rc = 0 Then Leave
   If sqlexecute("BB",":NEWSAL",aa.sal+30,":EMPNO",aa.empno) < 0 Then Abort()
End
If sqlclose("AA") < 0 Then Abort()
Call display_current "*** After update ***",query1
If commit Then rc = sqlcommit()
Else rc = sqlrollback()
If rc < 0 Then Abort()
If commit Then Call display_current "*** After Commit ***",query1
Else Call display_current "*** After Rollback ***",query1
If sqldisconnect() < 0 Then Abort()
Call Finalise
Return

/***********************************************************************/
display_current: Procedure Expose sqlca.
/***********************************************************************/
Parse Arg where,stmt
Say where
If sqlcommand("Q1",stmt) < 0 Then Abort()
Do i = 1 To q1.sal.0
   Say Right(q1.empno.i,6) Right(q1.sal.i,8)
End
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
Return

/***********************************************************************/
Finalise:
/***********************************************************************/
If dll = 'YES' Then Call SqlDropFuncs
Return
