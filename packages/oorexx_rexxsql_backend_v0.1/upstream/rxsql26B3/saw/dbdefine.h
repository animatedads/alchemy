/***********************************************************************
 * dbdefine.h - REXX/SQL definitions for Sybase SQLAnyWhere
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

#if defined(SAW_PREFIX)
# define DLLNAME "rexxsaw"
# define DEFAULT_CONNECTION	"SAW"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SAW"   /* Default stem name of implicit stmt */
#else
# define DLLNAME "rexxsql"
# define DEFAULT_CONNECTION	"SQL"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SQL"   /* Default stem name of implicit stmt */
#endif

#define CURRENT_DB "SQLAnywhere"

/* Names of SQL interface functions */
#if defined(SAW_PREFIX)
# define SQLCA_STEM                "SAWCA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "SAWCA.SQLCODE"
# define SQLCA_SQLERRM             "SAWCA.SQLERRM"
# define SQLCA_SQLTEXT             "SAWCA.SQLTEXT"
# define SQLCA_SQLSTATE            "SAWCA.SQLSTATE"
# define SQLCA_ROWCOUNT            "SAWCA.ROWCOUNT"
# define SQLCA_FUNCTION            "SAWCA.FUNCTION"
# define SQLCA_INTCODE             "SAWCA.INTCODE"
# define SQLCA_INTERRM             "SAWCA.INTERRM"
# define NAME_SQLVARIABLE_INT      "RexxSAWVariable"
# define NAME_SQLGETINFO_INT       "RexxSAWGetInfo"
# define NAME_SQLCONNECT_INT       "RexxSAWConnect"
# define NAME_SQLDISCONNECT_INT    "RexxSAWDisconnect"
# define NAME_SQLDEFAULT_INT       "RexxSAWDefault"
# define NAME_SQLCOMMIT_INT        "RexxSAWCommit"
# define NAME_SQLROLLBACK_INT      "RexxSAWRollback"
# define NAME_SQLCOMMAND_INT       "RexxSAWCommand"
# define NAME_SQLPREPARE_INT       "RexxSAWPrepare"
# define NAME_SQLDISPOSE_INT       "RexxSAWDispose"
# define NAME_SQLEXECUTE_INT       "RexxSAWExecute"
# define NAME_SQLOPEN_INT          "RexxSAWOpen"
# define NAME_SQLCLOSE_INT         "RexxSAWClose"
# define NAME_SQLFETCH_INT         "RexxSAWFetch"
# define NAME_SQLGETDATA_INT       "RexxSAWGetData"
# define NAME_SQLDESCRIBE_INT      "RexxSAWDescribe"
# define NAME_SQLDATASOURCES_INT   "RexxSAWDataSources"
# define NAME_SQLTABLES_INT        "RexxSAWTables"
# define NAME_SQLCOLUMNS_INT       "RexxSAWColumns"
# define NAME_SQLLOADFUNCS_INT         "SAWLoadFuncs"
# define NAME_SQLDROPFUNCS_INT     "RexxSAWDropFuncs"
# define SQLVARIABLE               RexxSAWVariable
# define SQLGETINFO                RexxSAWGetInfo
# define SQLCONNECT                RexxSAWConnect
# define SQLDISCONNECT             RexxSAWDisconnect
# define SQLDEFAULT                RexxSAWDefault
# define SQLCOMMIT                 RexxSAWCommit
# define SQLROLLBACK               RexxSAWRollback
# define SQLCOMMAND                RexxSAWCommand
# define SQLPREPARE                RexxSAWPrepare
# define SQLDISPOSE                RexxSAWDispose
# define SQLEXECUTE                RexxSAWExecute
# define SQLEXEC                   RexxSAWExec
# define SQLTRANSACT               RexxSAWTransact
# define SQLOPEN                   RexxSAWOpen
# define SQLCLOSE                  RexxSAWClose
# define SQLFETCH                  RexxSAWFetch
# define SQLGETDATA                RexxSAWGetData
# define SQLDESCRIBE               RexxSAWDescribe
# define SQLDATASOURCES            RexxSAWDataSources
# define SQLTABLES                 RexxSAWTables
# define SQLCOLUMNS                RexxSAWColumns
# define SQLLOADFUNCS                  SAWLoadFuncs
# define SQLDROPFUNCS              RexxSAWDropFuncs
# define NAME_SQLVARIABLE_EXT      "SAWVARIABLE"
# define NAME_SQLGETINFO_EXT       "SAWGETINFO"
# define NAME_SQLCONNECT_EXT       "SAWCONNECT"
# define NAME_SQLDISCONNECT_EXT    "SAWDISCONNECT"
# define NAME_SQLDEFAULT_EXT       "SAWDEFAULT"
# define NAME_SQLCOMMIT_EXT        "SAWCOMMIT"
# define NAME_SQLROLLBACK_EXT      "SAWROLLBACK"
# define NAME_SQLCOMMAND_EXT       "SAWCOMMAND"
# define NAME_SQLPREPARE_EXT       "SAWPREPARE"
# define NAME_SQLDISPOSE_EXT       "SAWDISPOSE"
# define NAME_SQLOPEN_EXT          "SAWOPEN"
# define NAME_SQLCLOSE_EXT         "SAWCLOSE"
# define NAME_SQLFETCH_EXT         "SAWFETCH"
# define NAME_SQLGETDATA_EXT       "SAWGETDATA"
# define NAME_SQLEXECUTE_EXT       "SAWEXECUTE"
# define NAME_SQLEXEC_EXT          "SAWEXEC"
# define NAME_SQLDESCRIBE_EXT      "SAWDESCRIBE"
# define NAME_SQLDATASOURCES_EXT   "SAWDATASOURCES"
# define NAME_SQLTABLES_EXT        "SAWTABLES"
# define NAME_SQLCOLUMNS_EXT       "SAWCOLUMNS"
# define NAME_SQLLOADFUNCS_EXT     "SAWLOADFUNCS"
# define NAME_SQLDROPFUNCS_EXT     "SAWDROPFUNCS"
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

#define MAX_DATATYPES       20 /* Maximum number of dataypes supported */

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

#ifndef SQL_SQLSTATE_SIZE
# define SQL_SQLSTATE_SIZE     SQLSTATE_SIZE
#endif
/*
 * Define the following datatypes to the CLI values
 */
#define RXSQL_HENV   HENV
#define RXSQL_HDBC   HDBC
#define RXSQL_HSTMT  HSTMT
#define RXSQL_SQLPOINTER PTR

#define RXSQL_ROWCOUNT_TYPE  long
#define RXSQL_SQLCODE_TYPE   long
#define RXSQL_SQLSTATE_TYPE  unsigned char
#define RXSQL_SQLERRM_TYPE   unsigned char

#endif
