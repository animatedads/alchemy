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

#if defined(ORA_PREFIX)
# define DLLNAME "rexxora"
# define DEFAULT_CONNECTION	"ORA"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"ORA"   /* Default stem name of implicit stmt */
#else
# define DLLNAME "rexxsql"
# define DEFAULT_CONNECTION	"SQL"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SQL"   /* Default stem name of implicit stmt */
#endif

#define CURRENT_DB "Oracle"

#if defined(ORA_PREFIX)
# define SQLCA_STEM                "ORACA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "ORACA.SQLCODE"
# define SQLCA_SQLERRM             "ORACA.SQLERRM"
# define SQLCA_SQLTEXT             "ORACA.SQLTEXT"
# define SQLCA_SQLSTATE            "ORACA.SQLSTATE"
# define SQLCA_ROWCOUNT            "ORACA.ROWCOUNT"
# define SQLCA_FUNCTION            "ORACA.FUNCTION"
# define SQLCA_INTCODE             "ORACA.INTCODE"
# define SQLCA_INTERRM             "ORACA.INTERRM"
# define NAME_SQLCLOSE_INT         "RexxORAClose"
# define NAME_SQLCOLUMNS_INT       "RexxORAColumns"
# define NAME_SQLCOMMAND_INT       "RexxORACommand"
# define NAME_SQLCOMMIT_INT        "RexxORACommit"
# define NAME_SQLCONNECT_INT       "RexxORAConnect"
# define NAME_SQLDATASOURCES_INT   "RexxORADataSources"
# define NAME_SQLDEFAULT_INT       "RexxORADefault"
# define NAME_SQLDESCRIBE_INT      "RexxORADescribe"
# define NAME_SQLDISCONNECT_INT    "RexxORADisconnect"
# define NAME_SQLDISPOSE_INT       "RexxORADispose"
# define NAME_SQLDROPFUNCS_INT     "RexxORADropFuncs"
# define NAME_SQLEXECUTE_INT       "RexxORAExecute"
# define NAME_SQLFETCH_INT         "RexxORAFetch"
# define NAME_SQLGETDATA_INT       "RexxORAGetData"
# define NAME_SQLGETINFO_INT       "RexxORAGetInfo"
# define NAME_SQLLOADFUNCS_INT         "ORALoadFuncs"
# define NAME_SQLOPEN_INT          "RexxORAOpen"
# define NAME_SQLPREPARE_INT       "RexxORAPrepare"
# define NAME_SQLROLLBACK_INT      "RexxORARollback"
# define NAME_SQLTABLES_INT        "RexxORATables"
# define NAME_SQLVARIABLE_INT      "RexxORAVariable"
# define SQLCLOSE                  RexxORAClose
# define SQLCOLUMNS                RexxORAColumns
# define SQLCOMMAND                RexxORACommand
# define SQLCOMMIT                 RexxORACommit
# define SQLCONNECT                RexxORAConnect
# define SQLDATASOURCES            RexxORADataSources
# define SQLDEFAULT                RexxORADefault
# define SQLDESCRIBE               RexxORADescribe
# define SQLDISCONNECT             RexxORADisconnect
# define SQLDISPOSE                RexxORADispose
# define SQLDROPFUNCS              RexxORADropFuncs
# define SQLEXEC                   RexxORAExec
# define SQLEXECUTE                RexxORAExecute
# define SQLFETCH                  RexxORAFetch
# define SQLGETDATA                RexxORAGetData
# define SQLGETINFO                RexxORAGetInfo
# define SQLLOADFUNCS                  ORALoadFuncs
# define SQLOPEN                   RexxORAOpen
# define SQLPREPARE                RexxORAPrepare
# define SQLROLLBACK               RexxORARollback
# define SQLTABLES                 RexxORATables
# define SQLTRANSACT               RexxORATransact
# define SQLVARIABLE               RexxORAVariable
# define NAME_SQLCLOSE_EXT         "ORACLOSE"
# define NAME_SQLCOLUMNS_EXT       "ORACOLUMNS"
# define NAME_SQLCOMMAND_EXT       "ORACOMMAND"
# define NAME_SQLCOMMIT_EXT        "ORACOMMIT"
# define NAME_SQLCONNECT_EXT       "ORACONNECT"
# define NAME_SQLDATASOURCES_EXT   "ORADATASOURCES"
# define NAME_SQLDEFAULT_EXT       "ORADEFAULT"
# define NAME_SQLDESCRIBE_EXT      "ORADESCRIBE"
# define NAME_SQLDISCONNECT_EXT    "ORADISCONNECT"
# define NAME_SQLDISPOSE_EXT       "ORADISPOSE"
# define NAME_SQLDROPFUNCS_EXT     "ORADROPFUNCS"
# define NAME_SQLEXECUTE_EXT       "ORAEXECUTE"
# define NAME_SQLEXEC_EXT          "ORAEXEC"
# define NAME_SQLFETCH_EXT         "ORAFETCH"
# define NAME_SQLGETDATA_EXT       "ORAGETDATA"
# define NAME_SQLGETINFO_EXT       "ORAGETINFO"
# define NAME_SQLLOADFUNCS_EXT     "ORALOADFUNCS"
# define NAME_SQLOPEN_EXT          "ORAOPEN"
# define NAME_SQLPREPARE_EXT       "ORAPREPARE"
# define NAME_SQLROLLBACK_EXT      "ORAROLLBACK"
# define NAME_SQLTABLES_EXT        "ORATABLES"
# define NAME_SQLVARIABLE_EXT      "ORAVARIABLE"
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

#define DBLONGCOLUMN(dbtype)	((dbtype==ORA_LONG || dbtype==ORA_LONGRAW))

#define RXSQL_ROWCOUNT_TYPE  long
#define RXSQL_SQLCODE_TYPE   long
#define RXSQL_SQLSTATE_TYPE  char
#define RXSQL_SQLERRM_TYPE   char

#define SQL_COMMIT     1
#define SQL_ROLLBACK   0

#endif
