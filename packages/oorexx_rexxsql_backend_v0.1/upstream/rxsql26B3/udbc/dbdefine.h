/***********************************************************************
 * dbdefine.h - REXX/SQL definitions for Openlink UDBC Interface
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

#if defined(UDBC_PREFIX)
# define DLLNAME "rexxudbc"
# define DEFAULT_CONNECTION	"UDBC"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"UDBC"   /* Default stem name of implicit stmt */
#else
# define DLLNAME "rexxsql"
# define DEFAULT_CONNECTION	"SQL"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SQL"   /* Default stem name of implicit stmt */
#endif

#define CURRENT_DB "UDBC"

/* Names of SQL interface functions */
#if defined(UDBC_PREFIX)
# define SQLCA_STEM                "UDBCCA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "UDBCCA.SQLCODE"
# define SQLCA_SQLERRM             "UDBCCA.SQLERRM"
# define SQLCA_SQLTEXT             "UDBCCA.SQLTEXT"
# define SQLCA_SQLSTATE            "UDBCCA.SQLSTATE"
# define SQLCA_ROWCOUNT            "UDBCCA.ROWCOUNT"
# define SQLCA_FUNCTION            "UDBCCA.FUNCTION"
# define SQLCA_INTCODE             "UDBCCA.INTCODE"
# define SQLCA_INTERRM             "UDBCCA.INTERRM"
# define NAME_SQLVARIABLE_INT      "RexxUDBCVariable"
# define NAME_SQLGETINFO_INT       "RexxUDBCGetInfo"
# define NAME_SQLCONNECT_INT       "RexxUDBCConnect"
# define NAME_SQLDISCONNECT_INT    "RexxUDBCDisconnect"
# define NAME_SQLDEFAULT_INT       "RexxUDBCDefault"
# define NAME_SQLCOMMIT_INT        "RexxUDBCCommit"
# define NAME_SQLROLLBACK_INT      "RexxUDBCRollback"
# define NAME_SQLCOMMAND_INT       "RexxUDBCCommand"
# define NAME_SQLPREPARE_INT       "RexxUDBCPrepare"
# define NAME_SQLDISPOSE_INT       "RexxUDBCDispose"
# define NAME_SQLEXECUTE_INT       "RexxUDBCExecute"
# define NAME_SQLOPEN_INT          "RexxUDBCOpen"
# define NAME_SQLCLOSE_INT         "RexxUDBCClose"
# define NAME_SQLFETCH_INT         "RexxUDBCFetch"
# define NAME_SQLGETDATA_INT       "RexxUDBCGetData"
# define NAME_SQLDESCRIBE_INT      "RexxUDBCDescribe"
# define NAME_SQLDATASOURCES_INT   "RexxUDBCDataSources"
# define NAME_SQLTABLES_INT        "RexxUDBCTables"
# define NAME_SQLCOLUMNS_INT       "RexxUDBCColumns"
# define NAME_SQLLOADFUNCS_INT         "UDBCLoadFuncs"
# define NAME_SQLDROPFUNCS_INT     "RexxUDBCDropFuncs"
# define SQLVARIABLE               RexxUDBCVariable
# define SQLGETINFO                RexxUDBCGetInfo
# define SQLCONNECT                RexxUDBCConnect
# define SQLDISCONNECT             RexxUDBCDisconnect
# define SQLDEFAULT                RexxUDBCDefault
# define SQLCOMMIT                 RexxUDBCCommit
# define SQLROLLBACK               RexxUDBCRollback
# define SQLCOMMAND                RexxUDBCCommand
# define SQLPREPARE                RexxUDBCPrepare
# define SQLDISPOSE                RexxUDBCDispose
# define SQLEXECUTE                RexxUDBCExecute
# define SQLEXEC                   RexxUDBCExec
# define SQLTRANSACT               RexxUDBCTransact
# define SQLOPEN                   RexxUDBCOpen
# define SQLCLOSE                  RexxUDBCClose
# define SQLFETCH                  RexxUDBCFetch
# define SQLGETDATA                RexxUDBCGetData
# define SQLDESCRIBE               RexxUDBCDescribe
# define SQLDATASOURCES            RexxUDBCDataSources
# define SQLTABLES                 RexxUDBCTables
# define SQLCOLUMNS                RexxUDBCColumns
# define SQLLOADFUNCS                  UDBCLoadFuncs
# define SQLDROPFUNCS              RexxUDBCDropFuncs
# define NAME_SQLVARIABLE_EXT      "UDBCVARIABLE"
# define NAME_SQLGETINFO_EXT       "UDBCGETINFO"
# define NAME_SQLCONNECT_EXT       "UDBCCONNECT"
# define NAME_SQLDISCONNECT_EXT    "UDBCDISCONNECT"
# define NAME_SQLDEFAULT_EXT       "UDBCDEFAULT"
# define NAME_SQLCOMMIT_EXT        "UDBCCOMMIT"
# define NAME_SQLROLLBACK_EXT      "UDBCROLLBACK"
# define NAME_SQLCOMMAND_EXT       "UDBCCOMMAND"
# define NAME_SQLPREPARE_EXT       "UDBCPREPARE"
# define NAME_SQLDISPOSE_EXT       "UDBCDISPOSE"
# define NAME_SQLOPEN_EXT          "UDBCOPEN"
# define NAME_SQLCLOSE_EXT         "UDBCCLOSE"
# define NAME_SQLFETCH_EXT         "UDBCFETCH"
# define NAME_SQLGETDATA_EXT       "UDBCGETDATA"
# define NAME_SQLEXECUTE_EXT       "UDBCEXECUTE"
# define NAME_SQLEXEC_EXT          "UDBCEXEC"
# define NAME_SQLDESCRIBE_EXT      "UDBCDESCRIBE"
# define NAME_SQLDATASOURCES_EXT   "UDBCDATASOURCES"
# define NAME_SQLTABLES_EXT        "UDBCTABLES"
# define NAME_SQLCOLUMNS_EXT       "UDBCCOLUMNS"
# define NAME_SQLLOADFUNCS_EXT     "UDBCLOADFUNCS"
# define NAME_SQLDROPFUNCS_EXT     "UDBCDROPFUNCS"
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
#define MAX_BINDVARS		254
#define TBL_OPTIONS	17

#define MAX_EXPRLEN        255     /* Max length of column expressions */
#define MAX_IDENTIFIER      30            /* Max length of identifiers */
#define MAX_DB_CURSOR_NAME  18         /* Max length of DB cursor name */
#define TBL_STATEMENTS     253     /* Statement hash table vector size */
#define TBL_CONNECTIONS     17    /* Connection hash table vector size */
#define MAX_ERROR_TEXT    1024             /* Size of SQL error buffer */

#define NUM_DESCRIBE_COLUMNS 6
#define MAX_DATATYPES        30

#define SUPPORTSPLACEMARKERS TRUE    /* does database support placemarkers */
#define SUPPORTSTRANSACTIONS TRUE    /* does database support transactions */
#define SUPPORTSDMLROWCOUNT  TRUE  /* database sets SQLCA.ROWCOUNT for DML */
#define SUPPORTSSQLGETDATA   TRUE    /* database does support SqlGetData() */

#define SWA(stmt)	(&((stmt)->sqlwa))	/* Ptr to STMT's SQL WorkArea */
#define SEL(swa)	((swa)->select)		/* Ptr to SELECT flag */

/*
 * the sqlcode that occurs on truncation of bind variables
 */
#define RXSQL_TRUNCATION_SQLCODE -302

#define SQLSTATE_SIZE SQL_SQLSTATE_SIZE

#define USES_MULTIPLE_ERRORS 1

/*
 * Define the following datatypes to the CLI values
 */
#define RXSQL_HENV   HENV
#define RXSQL_HDBC   HDBC
#define RXSQL_HSTMT  HSTMT

#define RXSQL_SQLPOINTER SQLPOINTER
#define RXSQL_ROWCOUNT_TYPE  long
#define RXSQL_SQLCODE_TYPE   long
#define RXSQL_SQLSTATE_TYPE  unsigned char
#define RXSQL_SQLERRM_TYPE   unsigned char

#define REXXSQL_SS_NO_SQLGETFUNCTIONS

#endif
