/***********************************************************************
 * Program     : msqlsetup.rex
 * Version     : 1.10
 * Author      : Mark Hessling
 * Date        : 09 Mar 1996
 * Purpose     : This program creates the table emp in the REXXSQL
 *             : database and inserts rows into it.  All other sample
 *             : programs rely on this table existing.
 *             : If the REXXSQL database does not exist, create it with
 *             : msqladmin create REXXSQL
 * Platform    : mSQL
 * Arguments   : None.
 ***********************************************************************/
Trace o
Call Initialise
If sqlconnect(,,,"REXXSQL") < 0 Then Abort()

ct = "create table emp (",
     "empno    int primary key,",
     "ename    char(10),",
     "job      char(9),",
     "mgr      int,",
     "hiredate char(9),",
     "sal      int,",
     "comm     int,",
     "deptno   int not null )"

If sqlcommand('C1',ct) < 0 Then Abort()
Say "Table emp create successfully"

If sqlcommand("insert into emp values (7369,'SMITH','CLERK',7902,'17-DEC-80',800,0,20)") < 0 Then Abort()
If sqlcommand("insert into emp values (7499,'ALLEN','SALESMAN',7698,'20-FEB-81',1600,300,30)") < 0 Then Abort()
If sqlcommand("insert into emp values (7521,'WARD','SALESMAN',7698,'22-FEB-81',1250,500,30)") < 0 Then Abort()
If sqlcommand("insert into emp values (7566,'JONES','MANAGER',7839,'2-APR-81',2975,0,20)") < 0 Then Abort()
If sqlcommand("insert into emp values (7654,'MARTIN','SALESMAN',7698,'28-SEP-81',1250,1400,30)") < 0 Then Abort()
If sqlcommand("insert into emp values (7698,'BLAKE','MANAGER',7839,'1-MAY-81',2850,0,30)") < 0 Then Abort()
If sqlcommand("insert into emp values (7782,'CLARK','MANAGER',7839,'9-JUN-81',2450,0,10)") < 0 Then Abort()
If sqlcommand("insert into emp values (7788,'SCOTT','ANALYST',7566,'09-DEC-82',3000,0,20)") < 0 Then Abort()
If sqlcommand("insert into emp values (7839,'KING','PRESIDENT',0,'17-NOV-81',5000,0,10)") < 0 Then Abort()
If sqlcommand("insert into emp values (7844,'TURNER','SALESMAN',7698,'8-SEP-81',1500,0,30)") < 0 Then Abort()
If sqlcommand("insert into emp values (7876,'ADAMS','CLERK',7788,'12-JAN-83',1100,0,20)") < 0 Then Abort()
If sqlcommand("insert into emp values (7900,'JAMES','CLERK',7698,'3-DEC-81',950,0,30)") < 0 Then Abort()
If sqlcommand("insert into emp values (7902,'FORD','ANALYST',7566,'3-DEC-81',3000,0,20)") < 0 Then Abort()
If sqlcommand("insert into emp values (7934,'MILLER','CLERK',7782,'23-JAN-82',1300,0,10)") < 0 Then Abort()

If sqldisconnect() < 0 Then Abort()
Call Finalise
Exit 0

/***********************************************************************/
Abort: Procedure Expose sqlca.
/***********************************************************************/
Parse Arg text
say sqlca.sqltext
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
