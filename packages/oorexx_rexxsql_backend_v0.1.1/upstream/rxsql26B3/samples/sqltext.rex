/***********************************************************************
 * Program     :  sqltext.rex
 * Version     :  1.10
 * Author      :  Mark Hessling
 * Date        :  09 Mar 1996
 * Platform    :  Oracle 7
 * Purpose     :  This program displays the full text of the SQL
 *             :  statement for the supplied process id(s).
 * Arguments   :  Process id(s) seperated by spaces.
 ***********************************************************************/
Trace o
processes = ''
username = 'system'                         /* change this as required */
password = 'manager'                        /* change this as required */
Do i = 1 To Arg()
   processes = processes Arg(i)
End
processes = Strip(processes)
If processes = '' Then
  Do
    Say 'ERROR: Must supply at least one process id'
    Exit 1
  End
query0 = "select osuser,sql_text",
         " from v$session s,v$sqlarea t,v$process p",
         " where s.sql_address = t.address",
         " and  s.sql_hash_value = t.hash_value",
         " and  p.spid = :APROC",
         " and  p.addr = s.paddr"

If sqlconnect(,username,password) < 0 Then Abort()
Do i = 1 To Words(processes)
   If sqlcommand(q0,query0,':APROC',Word(processes,i)) < 0 Then Abort()
   Say
   If q0.sql_text.0 = 0 Then Say Word(processes,i)||': No SQL text available for process'
   Else
     Do
       Say Word(processes,i)||': SQL Text for process owned by' q0.osuser.1
       Do While q0.sql_text.1 \= ''
         Say Substr(q0.sql_text.1,1,60)
         q0.sql_text.1 = Substr(q0.sql_text.1,61)
       End
     End
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
