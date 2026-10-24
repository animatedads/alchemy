/*
 * This is a simple test program for Rexx/SQL.  It simply connects to
 * the database using the supplied username, password and database
 * specified as arguments.
 * Run this as:
 * rexxsql simple.cmd user=username pass=password data=database serv=server
 *
 * If your database does not require values for any of the parameters,
 * simply leave the parameter out. eg rexxsql simple.cmd data=MYDB
 *
 * This program will unload the Rexx/SQL external functions on exit,
 * so don't run this if unloading the external functions could cause
 * other running Rexx/SQL programs to fail.
 */
Signal On Syntax
Parse Arg . 'user=' username . 1 . 'pass=' password . 1 . 'data=' database . 1 . 'serv=' server .
Call RxFuncAdd 'SQLLoadFuncs', 'rexxsql', 'SQLLoadFuncs'
Call SQLLoadFuncs
/*
 * Connect and display some details of the connection
 */
If SQLConnect( 'c1', username, password, database, server ) < 0 Then Abort( 'connecting' )
Say 'Connect succeeded!'
Parse Version ver
Say 'Rexx Version:' ver
Say 'Rexx/SQL Version:' SQLVariable( 'VERSION' )
If SQLGetinfo('c1','DBMSNAME','desc.') < 0 Then Abort( 'getting db version' )
Say 'Database Name:   ' desc.1
If SQLGetinfo('c1','DBMSVERSION','desc.') < 0 Then Abort( 'getting db version' )
Say 'Database Version:' desc.1
/*
 * All done, lets get out
 */
If SQLDisconnect( 'c1' ) < 0 Then Abort( 'disconnecting' )
Say 'Disconnect succeeded!'
Call SQLDropFuncs 'UNLOAD'
Return 0

Abort: Procedure Expose sqlca.
Parse Arg msg
Say 'Program failed:' msg
Say sqlca.interrm
If Datatype( sqlca.sqlerrm.0 ) = 'NUM' Then
   Do i = 1 To sqlca.sqlerrm.0
      Say '('sqlca.sqlstate.i')' sqlca.sqlerrm.i
   End
Else
   Do
      Say '('sqlca.sqlstate')' sqlca.sqlerrm
   End
Call SQLDropFuncs 'UNLOAD'
Exit 1

Syntax:
Call Abort 'syntax error on line' sigl
Return
