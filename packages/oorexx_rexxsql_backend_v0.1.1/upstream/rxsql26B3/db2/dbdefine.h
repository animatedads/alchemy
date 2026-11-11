/***********************************************************************
 * dbdefine.h - REXX/SQL definitions for DB2
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

#if defined(DB2_PREFIX)
# define DLLNAME "rexxdb2"
# define DEFAULT_CONNECTION	"DB2"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"DB2"   /* Default stem name of implicit stmt */
#else
# define DLLNAME "rexxsql"
# define DEFAULT_CONNECTION	"SQL"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SQL"   /* Default stem name of implicit stmt */
#endif

#define CURRENT_DB "DB2"

/* Names of SQL interface functions */
#if defined(DB2_PREFIX)
# define SQLCA_STEM                "DB2CA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "DB2CA.SQLCODE"
# define SQLCA_SQLERRM             "DB2CA.SQLERRM"
# define SQLCA_SQLTEXT             "DB2CA.SQLTEXT"
# define SQLCA_SQLSTATE            "DB2CA.SQLSTATE"
# define SQLCA_ROWCOUNT            "DB2CA.ROWCOUNT"
# define SQLCA_FUNCTION            "DB2CA.FUNCTION"
# define SQLCA_INTCODE             "DB2CA.INTCODE"
# define SQLCA_INTERRM             "DB2CA.INTERRM"
# define NAME_SQLVARIABLE_INT      "RexxDB2Variable"
# define NAME_SQLGETINFO_INT       "RexxDB2GetInfo"
# define NAME_SQLCONNECT_INT       "RexxDB2Connect"
# define NAME_SQLDISCONNECT_INT    "RexxDB2Disconnect"
# define NAME_SQLDEFAULT_INT       "RexxDB2Default"
# define NAME_SQLCOMMIT_INT        "RexxDB2Commit"
# define NAME_SQLROLLBACK_INT      "RexxDB2Rollback"
# define NAME_SQLCOMMAND_INT       "RexxDB2Command"
# define NAME_SQLPREPARE_INT       "RexxDB2Prepare"
# define NAME_SQLDISPOSE_INT       "RexxDB2Dispose"
# define NAME_SQLEXECUTE_INT       "RexxDB2Execute"
# define NAME_SQLOPEN_INT          "RexxDB2Open"
# define NAME_SQLCLOSE_INT         "RexxDB2Close"
# define NAME_SQLFETCH_INT         "RexxDB2Fetch"
# define NAME_SQLGETDATA_INT       "RexxDB2GetData"
# define NAME_SQLDESCRIBE_INT      "RexxDB2Describe"
# define NAME_SQLDATASOURCES_INT   "RexxDB2DataSources"
# define NAME_SQLTABLES_INT        "RexxDB2Tables"
# define NAME_SQLCOLUMNS_INT       "RexxDB2Columns"
# define NAME_SQLLOADFUNCS_INT         "DB2LoadFuncs"
# define NAME_SQLDROPFUNCS_INT     "RexxDB2DropFuncs"
# define SQLVARIABLE               RexxDB2Variable
# define SQLGETINFO                RexxDB2GetInfo
# define SQLCONNECT                RexxDB2Connect
# define SQLDISCONNECT             RexxDB2Disconnect
# define SQLDEFAULT                RexxDB2Default
# define SQLCOMMIT                 RexxDB2Commit
# define SQLROLLBACK               RexxDB2Rollback
# define SQLCOMMAND                RexxDB2Command
# define SQLPREPARE                RexxDB2Prepare
# define SQLDISPOSE                RexxDB2Dispose
# define SQLEXECUTE                RexxDB2Execute
# define SQLEXEC                   RexxDB2Exec
# define SQLTRANSACT               RexxDB2CTransact
# define SQLOPEN                   RexxDB2Open
# define SQLCLOSE                  RexxDB2Close
# define SQLFETCH                  RexxDB2Fetch
# define SQLGETDATA                RexxDB2GetData
# define SQLDESCRIBE               RexxDB2Describe
# define SQLDATASOURCES            RexxDB2DataSources
# define SQLTABLES                 RexxDB2Tables
# define SQLCOLUMNS                RexxDB2Columns
# define SQLLOADFUNCS                  DB2LoadFuncs
# define SQLDROPFUNCS              RexxDB2DropFuncs
# define NAME_SQLVARIABLE_EXT      "DB2VARIABLE"
# define NAME_SQLGETINFO_EXT       "DB2GETINFO"
# define NAME_SQLCONNECT_EXT       "DB2CONNECT"
# define NAME_SQLDISCONNECT_EXT    "DB2DISCONNECT"
# define NAME_SQLDEFAULT_EXT       "DB2DEFAULT"
# define NAME_SQLCOMMIT_EXT        "DB2COMMIT"
# define NAME_SQLROLLBACK_EXT      "DB2ROLLBACK"
# define NAME_SQLCOMMAND_EXT       "DB2COMMAND"
# define NAME_SQLPREPARE_EXT       "DB2PREPARE"
# define NAME_SQLDISPOSE_EXT       "DB2DISPOSE"
# define NAME_SQLOPEN_EXT          "DB2OPEN"
# define NAME_SQLCLOSE_EXT         "DB2CLOSE"
# define NAME_SQLFETCH_EXT         "DB2FETCH"
# define NAME_SQLGETDATA_EXT       "DB2GETDATA"
# define NAME_SQLEXECUTE_EXT       "DB2EXECUTE"
# define NAME_SQLEXEC_EXT          "DB2EXEC"
# define NAME_SQLDESCRIBE_EXT      "DB2DESCRIBE"
# define NAME_SQLDATASOURCES_EXT   "DB2DATASOURCES"
# define NAME_SQLTABLES_EXT        "DB2TABLES"
# define NAME_SQLCOLUMNS_EXT       "DB2COLUMNS"
# define NAME_SQLLOADFUNCS_EXT     "DB2LOADFUNCS"
# define NAME_SQLDROPFUNCS_EXT     "DB2DROPFUNCS"
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

#define NUM_DESCRIBE_COLUMNS 6

#define MAX_DATATYPES      100 /* Maximum number of dataypes supported */

#define SUPPORTSPLACEMARKERS TRUE    /* does database support placemarkers */
#define SUPPORTSTRANSACTIONS TRUE    /* does database support transactions */
#define SUPPORTSDMLROWCOUNT  TRUE  /* database sets SQLCA.ROWCOUNT for DML */
#define SUPPORTSSQLGETDATA   TRUE  /* database supports SqlGetData() function */
#define SUPPORTSTHREADS      TRUE  /* database supports threads */

#define SWA(stmt)	(&((stmt)->sqlwa))	/* Ptr to STMT's SQL WorkArea */
#define SEL(swa)	((swa)->select)		/* Ptr to SELECT flag */

/*
 * the sqlcode that occurs on truncation of bind variables
 */
#define RXSQL_TRUNCATION_SQLCODE -302

#define USES_MULTIPLE_ERRORS 1

/*
 * Define the following datatypes to the CLI values
 */
#define RXSQL_HENV   SQLHENV
#define RXSQL_HDBC   SQLHDBC
#define RXSQL_HSTMT  SQLHSTMT
#define RXSQL_SQLPOINTER SQLPOINTER

#define RXSQL_ROWCOUNT_TYPE  long
#define RXSQL_SQLCODE_TYPE   long
#define RXSQL_SQLSTATE_TYPE  unsigned char
#define RXSQL_SQLERRM_TYPE   unsigned char

#endif
