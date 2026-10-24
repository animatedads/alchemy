/***********************************************************************
 * dbdefine.h - REXX/SQL definitions for mySQL
 ***********************************************************************
 *
 * REXX/SQL. A REXX interface to SQL databases.
 * Copyright Mark Hessling, 1994-2004.
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

#if defined(MY_PREFIX)
# define DLLNAME "rexxmy"
# define DEFAULT_CONNECTION   "MY"       /* Name of the unnamed connection */
# define DEFAULT_STEM      "MY"   /* Default stem name of implicit stmt */
#else
# define DLLNAME "rexxsql"
# define DEFAULT_CONNECTION   "SQL"       /* Name of the unnamed connection */
# define DEFAULT_STEM      "SQL"   /* Default stem name of implicit stmt */
#endif

#define CURRENT_DB "MySQL"

/* Names of SQL interface functions */
#if defined(MY_PREFIX)
# define SQLCA_STEM                "MYCA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "MYCA.SQLCODE"
# define SQLCA_SQLERRM             "MYCA.SQLERRM"
# define SQLCA_SQLTEXT             "MYCA.SQLTEXT"
# define SQLCA_SQLSTATE            "MYCA.SQLSTATE"
# define SQLCA_ROWCOUNT            "MYCA.ROWCOUNT"
# define SQLCA_FUNCTION            "MYCA.FUNCTION"
# define SQLCA_INTCODE             "MYCA.INTCODE"
# define SQLCA_INTERRM             "MYCA.INTERRM"
# define NAME_SQLVARIABLE_INT      "RexxMYVariable"
# define NAME_SQLGETINFO_INT       "RexxMYGetInfo"
# define NAME_SQLCONNECT_INT       "RexxMYConnect"
# define NAME_SQLDISCONNECT_INT    "RexxMYDisconnect"
# define NAME_SQLDEFAULT_INT       "RexxMYDefault"
# define NAME_SQLCOMMIT_INT        "RexxMYCommit"
# define NAME_SQLROLLBACK_INT      "RexxMYRollback"
# define NAME_SQLCOMMAND_INT       "RexxMYCommand"
# define NAME_SQLPREPARE_INT       "RexxMYPrepare"
# define NAME_SQLDISPOSE_INT       "RexxMYDispose"
# define NAME_SQLEXECUTE_INT       "RexxMYExecute"
# define NAME_SQLOPEN_INT          "RexxMYOpen"
# define NAME_SQLCLOSE_INT         "RexxMYClose"
# define NAME_SQLFETCH_INT         "RexxMYFetch"
# define NAME_SQLGETDATA_INT       "RexxMYGetData"
# define NAME_SQLDESCRIBE_INT      "RexxMYDescribe"
# define NAME_SQLDATASOURCES_INT   "RexxMYDataSources"
# define NAME_SQLTABLES_INT        "RexxMYTables"
# define NAME_SQLCOLUMNS_INT       "RexxMYColumns"
# define NAME_SQLLOADFUNCS_INT         "MYLoadFuncs"
# define NAME_SQLDROPFUNCS_INT     "RexxMYDropFuncs"
# define SQLVARIABLE               RexxMYVariable
# define SQLGETINFO                RexxMYGetInfo
# define SQLCONNECT                RexxMYConnect
# define SQLDISCONNECT             RexxMYDisconnect
# define SQLDEFAULT                RexxMYDefault
# define SQLCOMMIT                 RexxMYCommit
# define SQLROLLBACK               RexxMYRollback
# define SQLCOMMAND                RexxMYCommand
# define SQLPREPARE                RexxMYPrepare
# define SQLDISPOSE                RexxMYDispose
# define SQLEXECUTE                RexxMYExecute
# define SQLEXEC                   RexxMYExec
# define SQLTRANSACT               RexxMYTransact
# define SQLOPEN                   RexxMYOpen
# define SQLCLOSE                  RexxMYClose
# define SQLFETCH                  RexxMYFetch
# define SQLGETDATA                RexxMYGetData
# define SQLDESCRIBE               RexxMYDescribe
# define SQLDATASOURCES            RexxMYDataSources
# define SQLTABLES                 RexxMYTables
# define SQLCOLUMNS                RexxMYColumns
# define SQLLOADFUNCS                  MYLoadFuncs
# define SQLDROPFUNCS              RexxMYDropFuncs
# define NAME_SQLVARIABLE_EXT      "MYVARIABLE"
# define NAME_SQLGETINFO_EXT       "MYGETINFO"
# define NAME_SQLCONNECT_EXT       "MYCONNECT"
# define NAME_SQLDISCONNECT_EXT    "MYDISCONNECT"
# define NAME_SQLDEFAULT_EXT       "MYDEFAULT"
# define NAME_SQLCOMMIT_EXT        "MYCOMMIT"
# define NAME_SQLROLLBACK_EXT      "MYROLLBACK"
# define NAME_SQLCOMMAND_EXT       "MYCOMMAND"
# define NAME_SQLPREPARE_EXT       "MYPREPARE"
# define NAME_SQLDISPOSE_EXT       "MYDISPOSE"
# define NAME_SQLOPEN_EXT          "MYOPEN"
# define NAME_SQLCLOSE_EXT         "MYCLOSE"
# define NAME_SQLFETCH_EXT         "MYFETCH"
# define NAME_SQLGETDATA_EXT       "MYGETDATA"
# define NAME_SQLEXECUTE_EXT       "MYEXECUTE"
# define NAME_SQLEXEC_EXT          "MYEXEC"
# define NAME_SQLDESCRIBE_EXT      "MYDESCRIBE"
# define NAME_SQLDATASOURCES_EXT   "MYDATASOURCES"
# define NAME_SQLTABLES_EXT        "MYTABLES"
# define NAME_SQLCOLUMNS_EXT       "MYCOLUMNS"
# define NAME_SQLLOADFUNCS_EXT     "MYLOADFUNCS"
# define NAME_SQLDROPFUNCS_EXT     "MYDROPFUNCS"
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
#define MAX_COLS     75
#define MAX_NAMELEN     19
#define MAX_BINDVARS    256
#define TBL_OPTIONS  17

#define MAX_EXPRLEN        255     /* Max length of column expressions */
#define MAX_IDENTIFIER      30            /* Max length of identifiers */
#define TBL_STATEMENTS     253     /* Statement hash table vector size */
#define TBL_CONNECTIONS     17    /* Connection hash table vector size */
#define MAX_ERROR_TEXT    1024             /* Size of SQL error buffer */

#define MAX_DATATYPES       25 /* Maximum number of dataypes supported */

#define NUM_DESCRIBE_COLUMNS 8
#define SQL_SQLSTATE_SIZE    5

#define SUPPORTSPLACEMARKERS FALSE   /* database does NOT support placemarkers */
#define SUPPORTSTRANSACTIONS TRUE    /* database MAY support transactions */
#define SUPPORTSDMLROWCOUNT  TRUE    /* database does set SQLCA.ROWCOUNT for DML */
#define SUPPORTSSQLGETDATA   FALSE   /* database does NOT support SqlGetData() function */
#define SUPPORTSTHREADS      FALSE   /* database MAY support threads */

#define MAX_PATH_LENGTH    255

#define SWA(stmt) (&((stmt)->sqlwa))   /* Ptr to STMT's SQL WorkArea */
#define CTX(swa)  ((swa)->result)        /* Ptr to mySQL statement */
#define SQL(swa)  ((swa)->sql_stmt)    /* Ptr to mySQL sql statement text */

#define NO_DATA_FOUND   1

#define RXSQL_ROWCOUNT_TYPE  my_ulonglong
#define RXSQL_SQLCODE_TYPE   long
#define RXSQL_SQLSTATE_TYPE  char
#define RXSQL_SQLERRM_TYPE   char

#define SQL_COMMIT   1
#define SQL_ROLLBACK 0

#endif
