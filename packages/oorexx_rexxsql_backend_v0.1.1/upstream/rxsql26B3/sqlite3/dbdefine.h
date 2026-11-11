/***********************************************************************
 * dbdefine.h - REXX/SQL definitions for SQLite3
 ***********************************************************************
 *
 * REXX/SQL. A REXX interface to SQL databases.
 * Copyright Mark Hessling, 2002-2006.
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
 * Mark Hessling  mark@rexx.org http://www.rexx.org
 *
 */
#ifndef REXXSQL_DBDEFINE_H
#define REXXSQL_DBDEFINE_H

#if defined(HAVE_CONFIG_H)
#  include "config.h"
#endif

#if defined(LITE_PREFIX)
# define DLLNAME "rexxlite"
# define DEFAULT_CONNECTION	"LITE"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"LITE"   /* Default stem name of implicit stmt */
#else
# define DLLNAME "rexxsql"
# define DEFAULT_CONNECTION	"SQL"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SQL"   /* Default stem name of implicit stmt */
#endif

#define CURRENT_DB "SQLite3"

/* Names of SQL interface functions */
#if defined(LITE_PREFIX)
# define SQLCA_STEM                "LITECA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "LITECA.SQLCODE"
# define SQLCA_SQLERRM             "LITECA.SQLERRM"
# define SQLCA_SQLTEXT             "LITECA.SQLTEXT"
# define SQLCA_SQLSTATE            "LITECA.SQLSTATE"
# define SQLCA_ROWCOUNT            "LITECA.ROWCOUNT"
# define SQLCA_FUNCTION            "LITECA.FUNCTION"
# define SQLCA_INTCODE             "LITECA.INTCODE"
# define SQLCA_INTERRM             "LITECA.INTERRM"
# define NAME_SQLVARIABLE_INT      "RexxLITEVariable"
# define NAME_SQLGETINFO_INT       "RexxLITEGetInfo"
# define NAME_SQLCONNECT_INT       "RexxLITEConnect"
# define NAME_SQLDISCONNECT_INT    "RexxLITEDisconnect"
# define NAME_SQLDEFAULT_INT       "RexxLITEDefault"
# define NAME_SQLCOMMIT_INT        "RexxLITECommit"
# define NAME_SQLROLLBACK_INT      "RexxLITERollback"
# define NAME_SQLCOMMAND_INT       "RexxLITECommand"
# define NAME_SQLPREPARE_INT       "RexxLITEPrepare"
# define NAME_SQLDISPOSE_INT       "RexxLITEDispose"
# define NAME_SQLEXECUTE_INT       "RexxLITEExecute"
# define NAME_SQLOPEN_INT          "RexxLITEOpen"
# define NAME_SQLCLOSE_INT         "RexxLITEClose"
# define NAME_SQLFETCH_INT         "RexxLITEFetch"
# define NAME_SQLGETDATA_INT       "RexxLITEGetData"
# define NAME_SQLDESCRIBE_INT      "RexxLITEDescribe"
# define NAME_SQLDATASOURCES_INT   "RexxLITEDataSources"
# define NAME_SQLTABLES_INT        "RexxLITETables"
# define NAME_SQLCOLUMNS_INT       "RexxLITEColumns"
# define NAME_SQLLOADFUNCS_INT         "LITELoadFuncs"
# define NAME_SQLDROPFUNCS_INT     "RexxLITEDropFuncs"
# define SQLVARIABLE               RexxLITEVariable
# define SQLGETINFO                RexxLITEGetInfo
# define SQLCONNECT                RexxLITEConnect
# define SQLDISCONNECT             RexxLITEDisconnect
# define SQLDEFAULT                RexxLITEDefault
# define SQLCOMMIT                 RexxLITECommit
# define SQLROLLBACK               RexxLITERollback
# define SQLCOMMAND                RexxLITECommand
# define SQLPREPARE                RexxLITEPrepare
# define SQLDISPOSE                RexxLITEDispose
# define SQLEXECUTE                RexxLITEExecute
# define SQLEXEC                   RexxLITEExec
# define SQLTRANSACT               RexxLITETransact
# define SQLOPEN                   RexxLITEOpen
# define SQLCLOSE                  RexxLITEClose
# define SQLFETCH                  RexxLITEFetch
# define SQLGETDATA                RexxLITEGetData
# define SQLDESCRIBE               RexxLITEDescribe
# define SQLDATASOURCES            RexxLITEDataSources
# define SQLTABLES                 RexxLITETables
# define SQLCOLUMNS                RexxLITEColumns
# define SQLLOADFUNCS                  LITELoadFuncs
# define SQLDROPFUNCS              RexxLITEDropFuncs
# define NAME_SQLVARIABLE_EXT      "LITEVARIABLE"
# define NAME_SQLGETINFO_EXT       "LITEGETINFO"
# define NAME_SQLCONNECT_EXT       "LITECONNECT"
# define NAME_SQLDISCONNECT_EXT    "LITEDISCONNECT"
# define NAME_SQLDEFAULT_EXT       "LITEDEFAULT"
# define NAME_SQLCOMMIT_EXT        "LITECOMMIT"
# define NAME_SQLROLLBACK_EXT      "LITEROLLBACK"
# define NAME_SQLCOMMAND_EXT       "LITECOMMAND"
# define NAME_SQLPREPARE_EXT       "LITEPREPARE"
# define NAME_SQLDISPOSE_EXT       "LITEDISPOSE"
# define NAME_SQLOPEN_EXT          "LITEOPEN"
# define NAME_SQLCLOSE_EXT         "LITECLOSE"
# define NAME_SQLFETCH_EXT         "LITEFETCH"
# define NAME_SQLGETDATA_EXT       "LITEGETDATA"
# define NAME_SQLEXECUTE_EXT       "LITEEXECUTE"
# define NAME_SQLEXEC_EXT          "LITEEXEC"
# define NAME_SQLDESCRIBE_EXT      "LITEDESCRIBE"
# define NAME_SQLDATASOURCES_EXT   "LITEDATASOURCES"
# define NAME_SQLTABLES_EXT        "LITETABLES"
# define NAME_SQLCOLUMNS_EXT       "LITECOLUMNS"
# define NAME_SQLLOADFUNCS_EXT     "LITELOADFUNCS"
# define NAME_SQLDROPFUNCS_EXT     "LITEDROPFUNCS"
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
#define MAX_COLS		75
#define MAX_NAMELEN		19
#define MAX_BINDVARS		256	
#define TBL_OPTIONS	17

#define MAX_EXPRLEN        255     /* Max length of column expressions */
#define MAX_IDENTIFIER     255            /* Max length of identifiers */
#define TBL_STATEMENTS     253     /* Statement hash table vector size */
#define TBL_CONNECTIONS     17    /* Connection hash table vector size */
#define MAX_ERROR_TEXT    1024             /* Size of SQL error buffer */

#define MAX_DATATYPES       25 /* Maximum number of dataypes supported */

#define NUM_DESCRIBE_COLUMNS 6
#define SQL_SQLSTATE_SIZE    5

#define SUPPORTSPLACEMARKERS TRUE    /* database does support placemarkers */
#define SUPPORTSTRANSACTIONS TRUE    /* database does support transactions */
#define SUPPORTSDMLROWCOUNT  TRUE    /* database does set SQLCA.ROWCOUNT for DML */
#define SUPPORTSSQLGETDATA   FALSE   /* database does NOT support SqlGetData() function */
#define SUPPORTSTHREADS      TRUE    /* database does support threads */

#define MAX_PATH_LENGTH		255

#define SWA(stmt)	(&((stmt)->sqlwa))	/* Ptr to STMT's SQL WorkArea */
#define CTX(swa)	((swa)->cstmt)		/* Ptr to SQLite3 compiled statment */
#define SQL(swa)	((swa)->sql_stmt)		/* Ptr to SQLite3 statement */

#define NO_DATA_FOUND   1

#define RXSQL_ROWCOUNT_TYPE  long
#define RXSQL_SQLCODE_TYPE   long
#define RXSQL_SQLSTATE_TYPE  char
#define RXSQL_SQLERRM_TYPE   char

#define SQL_COMMIT   1
#define SQL_ROLLBACK 0

#endif
