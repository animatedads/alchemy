/***********************************************************************
 * Program     :  actual.rex
 * Version     :  1.10
 * Author      :  Mark Hessling
 * Date        :  13 Aug 1995
 * Purpose     :  This program displays the amount of space allocated
 *             :  to a particular table and the amount of space
 *             :  used.
 * Arguments   :  tablename - name of table
 *             :  owner     - owner of table
 * Platform    :  Oracle
 * Notes       :  Must run as DBA.
 ***********************************************************************/
Trace o
username = 'system'
password = 'manager'
If Arg() < 2 Then Abort('Syntax: tablename owner')
Parse Upper Arg tablename, owner .
Call Initialise
If sqlconnect(,username,password) < 0 Then Abort()
query1 = "select count(distinct(substr(rowid,1,8))) blocks from" owner||'.'||tablename
query2 = "select segment_name, extents, bytes, blocks from dba_segments where segment_name = '"||tablename||"' and owner = '"||owner||"'"
/*---------------------------------------------------------------------*/
/* Get number of distinct blocks for the table...                      */
/*---------------------------------------------------------------------*/
If sqlcommand(q1,query1) < 0 Then Abort()
/*---------------------------------------------------------------------*/
/* Get number of allocated blocks in for the table...                  */
/*---------------------------------------------------------------------*/
If sqlcommand(q2,query2) < 0 Then Abort()
bytes_per_block = q2.bytes.1 / q2.blocks.1
actual_bytes = q1.blocks.1 * bytes_per_block
perc_used = Format((actual_bytes / q2.bytes.1) * 100,3,2)
Say "                                           Bytes       Bytes    %"
Say "TABLE                          Extents  Allocated       Used   Used"
Say "-------------------------------------------------------------------"
Say Left(tablename,30) Right(q2.extents.1,7) Right(q2.bytes.1,10) Right(actual_bytes,10) perc_used
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
Return

/***********************************************************************/
Finalise:
/***********************************************************************/
If dll = 'YES' Then Call SqlDropFuncs
Return
