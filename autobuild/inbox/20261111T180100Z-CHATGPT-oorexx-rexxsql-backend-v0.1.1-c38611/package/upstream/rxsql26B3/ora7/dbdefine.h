/***********************************************************************
 * dbdefine.h - REXX/SQL definitions for Oracle
 ***********************************************************************
 *
 * REXX/SQL. A REXX interface to SQL databases.
 * Copyright Mark Hessling, 1994-1999.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to:
 *
 *    The Free Software Foundation, Inc.
 *    675 Mass Ave,
 *    Cambridge, MA 02139 USA.
 *
 *
 * If you make modifications to this software that you feel increases
 * it usefulness for the rest of the community, please email the
 * changes, enhancements, bug fixes as well as any and all ideas to
 * address below.
 * This software is going to be maintained and enhanced as deemed
 * necessary by the community.
 *
 * Mark Hessling  M.Hessling@qut.edu.au  http://www.lightlink.com/hessling/
 *
 */
#ifndef REXXSQL_DBDEFINE_H
#define REXXSQL_DBDEFINE_H

#if defined(HAVE_CONFIG_H)
#  include "config.h"
#endif

#if defined(ORA7_PREFIX)
# define DLLNAME "rexxora7"
# define DEFAULT_CONNECTION	"ORA7"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"ORA7"   /* Default stem name of implicit stmt */
#else
# define DLLNAME "rexxsql"
# define DEFAULT_CONNECTION	"SQL"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SQL"   /* Default stem name of implicit stmt */
#endif

#define CURRENT_DB "Oracle7"

#if defined(ORA7_PREFIX)
# define SQLCA_STEM                "ORA7CA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "ORA7CA.SQLCODE"
# define SQLCA_SQLERRM             "ORA7CA.SQLERRM"
# define SQLCA_SQLTEXT             "ORA7CA.SQLTEXT"
# define SQLCA_SQLSTATE            "ORA7CA.SQLSTATE"
# define SQLCA_ROWCOUNT            "ORA7CA.ROWCOUNT"
# define SQLCA_FUNCTION            "ORA7CA.FUNCTION"
# define SQLCA_INTCODE             "ORA7CA.INTCODE"
# define SQLCA_INTERRM             "ORA7CA.INTERRM"
# define NAME_SQLVARIABLE_INT      "RexxORA7Variable"
# define NAME_SQLGETINFO_INT       "RexxORA7GetInfo"
# define NAME_SQLCONNECT_INT       "RexxORA7Connect"
# define NAME_SQLDISCONNECT_INT    "RexxORA7Disconnect"
# define NAME_SQLDEFAULT_INT       "RexxORA7Default"
# define NAME_SQLCOMMIT_INT        "RexxORA7Commit"
# define NAME_SQLROLLBACK_INT      "RexxORA7Rollback"
# define NAME_SQLCOMMAND_INT       "RexxORA7Command"
# define NAME_SQLPREPARE_INT       "RexxORA7Prepare"
# define NAME_SQLDISPOSE_INT       "RexxORA7Dispose"
# define NAME_SQLEXECUTE_INT       "RexxORA7Execute"
# define NAME_SQLOPEN_INT          "RexxORA7Open"
# define NAME_SQLCLOSE_INT         "RexxORA7Close"
# define NAME_SQLFETCH_INT         "RexxORA7Fetch"
# define NAME_SQLGETDATA_INT       "RexxORA7GetData"
# define NAME_SQLDESCRIBE_INT      "RexxORA7Describe"
# define NAME_SQLDATASOURCES_INT   "RexxORA7DataSources"
# define NAME_SQLTABLES_INT        "RexxORA7Tables"
# define NAME_SQLCOLUMNS_INT       "RexxORA7Columns"
# define NAME_SQLLOADFUNCS_INT         "ORA7LoadFuncs"
# define NAME_SQLDROPFUNCS_INT     "RexxORA7DropFuncs"
# define SQLVARIABLE               RexxORA7Variable
# define SQLGETINFO                RexxORA7GetInfo
# define SQLCONNECT                RexxORA7Connect
# define SQLDISCONNECT             RexxORA7Disconnect
# define SQLDEFAULT                RexxORA7Default
# define SQLCOMMIT                 RexxORA7Commit
# define SQLROLLBACK               RexxORA7Rollback
# define SQLCOMMAND                RexxORA7Command
# define SQLPREPARE                RexxORA7Prepare
# define SQLDISPOSE                RexxORA7Dispose
# define SQLEXECUTE                RexxORA7Execute
# define SQLEXEC                   RexxORA7Exec
# define SQLTRANSACT               RexxORA7Transact
# define SQLOPEN                   RexxORA7Open
# define SQLCLOSE                  RexxORA7Close
# define SQLFETCH                  RexxORA7Fetch
# define SQLGETDATA                RexxORA7GetData
# define SQLDESCRIBE               RexxORA7Describe
# define SQLDATASOURCES            RexxORA7DataSources
# define SQLTABLES                 RexxORA7Tables
# define SQLCOLUMNS                RexxORA7Columns
# define SQLLOADFUNCS                  ORA7LoadFuncs
# define SQLDROPFUNCS              RexxORA7DropFuncs
# define NAME_SQLVARIABLE_EXT      "ORA7VARIABLE"
# define NAME_SQLGETINFO_EXT       "ORA7GETINFO"
# define NAME_SQLCONNECT_EXT       "ORA7CONNECT"
# define NAME_SQLDISCONNECT_EXT    "ORA7DISCONNECT"
# define NAME_SQLDEFAULT_EXT       "ORA7DEFAULT"
# define NAME_SQLCOMMIT_EXT        "ORA7COMMIT"
# define NAME_SQLROLLBACK_EXT      "ORA7ROLLBACK"
# define NAME_SQLCOMMAND_EXT       "ORA7COMMAND"
# define NAME_SQLPREPARE_EXT       "ORA7PREPARE"
# define NAME_SQLDISPOSE_EXT       "ORA7DISPOSE"
# define NAME_SQLOPEN_EXT          "ORA7OPEN"
# define NAME_SQLCLOSE_EXT         "ORA7CLOSE"
# define NAME_SQLFETCH_EXT         "ORA7FETCH"
# define NAME_SQLGETDATA_EXT       "ORA7GETDATA"
# define NAME_SQLEXECUTE_EXT       "ORA7EXECUTE"
# define NAME_SQLEXEC_EXT          "ORA7EXEC"
# define NAME_SQLDESCRIBE_EXT      "ORA7DESCRIBE"
# define NAME_SQLDATASOURCES_EXT   "ORA7DATASOURCES"
# define NAME_SQLTABLES_EXT        "ORA7TABLES"
# define NAME_SQLCOLUMNS_EXT       "ORA7COLUMNS"
# define NAME_SQLLOADFUNCS_EXT     "ORA7LOADFUNCS"
# define NAME_SQLDROPFUNCS_EXT     "ORA7DROPFUNCS"
#else
# define SQLCA_STEM                "SQLCA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "SQLCA.SQLCODE"
# define SQLCA_SQLERRM             "SQLCA.SQLERRM"
# define SQLCA_SQLTEXT             "SQLCA.SQLTEXT"
# define SQLCA_SQLSTATE            "SQLCA.SQLSTATE"
# define SQLCA_ROWCOUNT            "SQLCA.ROWCOUNT"
# define SQLCA_FUNCTION            "SQLCA.FUNCTION"
# define SQLCA_INTCODE             "SQLCA.INTCODE"
# define SQLCA_INTERRM             "SQLCA.INTERRM"
# define NAME_SQLVARIABLE_INT      "RexxSQLVariable"
# define NAME_SQLGETINFO_INT       "RexxSQLGetInfo"
# define NAME_SQLCONNECT_INT       "RexxSQLConnect"
# define NAME_SQLDISCONNECT_INT    "RexxSQLDisconnect"
# define NAME_SQLDEFAULT_INT       "RexxSQLDefault"
# define NAME_SQLCOMMIT_INT        "RexxSQLCommit"
# define NAME_SQLROLLBACK_INT      "RexxSQLRollback"
# define NAME_SQLCOMMAND_INT       "RexxSQLCommand"
# define NAME_SQLPREPARE_INT       "RexxSQLPrepare"
# define NAME_SQLDISPOSE_INT       "RexxSQLDispose"
# define NAME_SQLEXECUTE_INT       "RexxSQLExecute"
# define NAME_SQLOPEN_INT          "RexxSQLOpen"
# define NAME_SQLCLOSE_INT         "RexxSQLClose"
# define NAME_SQLFETCH_INT         "RexxSQLFetch"
# define NAME_SQLGETDATA_INT       "RexxSQLGetData"
# define NAME_SQLDESCRIBE_INT      "RexxSQLDescribe"
# define NAME_SQLDATASOURCES_INT   "RexxSQLDataSources"
# define NAME_SQLTABLES_INT        "RexxSQLTables"
# define NAME_SQLCOLUMNS_INT       "RexxSQLColumns"
# define NAME_SQLLOADFUNCS_INT         "SQLLoadFuncs"
# define NAME_SQLDROPFUNCS_INT     "RexxSQLDropFuncs"
# define SQLVARIABLE               RexxSQLVariable
# define SQLGETINFO                RexxSQLGetInfo
# define SQLCONNECT                RexxSQLConnect
# define SQLDISCONNECT             RexxSQLDisconnect
# define SQLDEFAULT                RexxSQLDefault
# define SQLCOMMIT                 RexxSQLCommit
# define SQLROLLBACK               RexxSQLRollback
# define SQLCOMMAND                RexxSQLCommand
# define SQLPREPARE                RexxSQLPrepare
# define SQLDISPOSE                RexxSQLDispose
# define SQLEXECUTE                RexxSQLExecute
# define SQLEXEC                   RexxSQLExec
# define SQLTRANSACT               RexxSQLTransact
# define SQLOPEN                   RexxSQLOpen
# define SQLCLOSE                  RexxSQLClose
# define SQLFETCH                  RexxSQLFetch
# define SQLGETDATA                RexxSQLGetData
# define SQLDESCRIBE               RexxSQLDescribe
# define SQLDATASOURCES            RexxSQLDataSources
# define SQLTABLES                 RexxSQLTables
# define SQLCOLUMNS                RexxSQLColumns
# define SQLLOADFUNCS                  SQLLoadFuncs
# define SQLDROPFUNCS              RexxSQLDropFuncs
# define NAME_SQLVARIABLE_EXT      "SQLVARIABLE"
# define NAME_SQLGETINFO_EXT       "SQLGETINFO"
# define NAME_SQLCONNECT_EXT       "SQLCONNECT"
# define NAME_SQLDISCONNECT_EXT    "SQLDISCONNECT"
# define NAME_SQLDEFAULT_EXT       "SQLDEFAULT"
# define NAME_SQLCOMMIT_EXT        "SQLCOMMIT"
# define NAME_SQLROLLBACK_EXT      "SQLROLLBACK"
# define NAME_SQLCOMMAND_EXT       "SQLCOMMAND"
# define NAME_SQLPREPARE_EXT       "SQLPREPARE"
# define NAME_SQLDISPOSE_EXT       "SQLDISPOSE"
# define NAME_SQLOPEN_EXT          "SQLOPEN"
# define NAME_SQLCLOSE_EXT         "SQLCLOSE"
# define NAME_SQLFETCH_EXT         "SQLFETCH"
# define NAME_SQLGETDATA_EXT       "SQLGETDATA"
# define NAME_SQLEXECUTE_EXT       "SQLEXECUTE"
# define NAME_SQLEXEC_EXT          "SQLEXEC"
# define NAME_SQLDESCRIBE_EXT      "SQLDESCRIBE"
# define NAME_SQLDATASOURCES_EXT   "SQLDATASOURCES"
# define NAME_SQLTABLES_EXT        "SQLTABLES"
# define NAME_SQLCOLUMNS_EXT       "SQLCOLUMNS"
# define NAME_SQLLOADFUNCS_EXT     "SQLLOADFUNCS"
# define NAME_SQLDROPFUNCS_EXT     "SQLDROPFUNCS"
#endif

/*
 * Constants defining limits
 */
#define MAX_COLS		254
#define MAX_NAMELEN		30
#define MAX_BINDVARS		256
#define TBL_OPTIONS	17

#define MAX_EXPRLEN        255     /* Max length of column expressions */
#define MAX_IDENTIFIER      30            /* Max length of identifiers */
#define MAX_DB_CURSOR_NAME  18         /* Max length of DB cursor name */
#define TBL_STATEMENTS     253     /* Statement hash table vector size */
#define TBL_CONNECTIONS     17    /* Connection hash table vector size */
#define MAX_ERROR_TEXT    1024             /* Size of SQL error buffer */

#define MAX_DATATYPES       15 /* Maximum number of dataypes supported */

#define SQL_SQLSTATE_SIZE    5
#define NUM_DESCRIBE_COLUMNS 6

#define SUPPORTSPLACEMARKERS TRUE    /* does database support placemarkers */
#define SUPPORTSTRANSACTIONS TRUE    /* does database support transactions */
#define SUPPORTSDMLROWCOUNT  TRUE  /* database sets SQLCA.ROWCOUNT for DML */
#define SUPPORTSSQLGETDATA   TRUE  /* database supports SqlGetData() function */
#define SUPPORTSTHREADS      TRUE  /* database supports threads */

#define SWA(stmt)	(&((stmt)->sqlwa))	/* Ptr to STMT's SQL WorkArea */
#define SEL(swa)	((swa)->select_stmt)		/* Ptr to SELECT flag */
#define LDA(stmt)	(&((stmt)->db->lda))	/* Ptr to STMT's LDA */
#define HDA(db)		((db)->hda)		/* Ptr to DBCON's HDA */
#define CTX(swa)	(&((swa)->ora))		/* Ptr to Oracle cursor */

#define DBLONGCOLUMN(dbtype)	((dbtype==ORA_LONG || dbtype==ORA_LONGRAW))

#define RXSQL_ROWCOUNT_TYPE  long
#define RXSQL_SQLCODE_TYPE   long
#define RXSQL_SQLSTATE_TYPE  char
#define RXSQL_SQLERRM_TYPE   char

#define SQL_COMMIT     1
#define SQL_ROLLBACK   0

#endif
