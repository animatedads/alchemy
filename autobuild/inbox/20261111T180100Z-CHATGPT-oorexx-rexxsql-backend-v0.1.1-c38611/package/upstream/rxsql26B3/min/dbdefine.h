/***********************************************************************
 * dbdefine.h - REXX/SQL definitions for mSQL
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

#if defined(MIN_PREFIX)
# define DLLNAME "rexxmin"
# define DEFAULT_CONNECTION	"MIN"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"MIN"   /* Default stem name of implicit stmt */
#else
# define DLLNAME "rexxsql"
# define DEFAULT_CONNECTION	"SQL"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SQL"   /* Default stem name of implicit stmt */
#endif

#define CURRENT_DB "mSQL"

/* Names of SQL interface functions */
#if defined(MIN_PREFIX)
# define SQLCA_STEM                "MINCA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "MINCA.SQLCODE"
# define SQLCA_SQLERRM             "MINCA.SQLERRM"
# define SQLCA_SQLTEXT             "MINCA.SQLTEXT"
# define SQLCA_SQLSTATE            "MINCA.SQLSTATE"
# define SQLCA_ROWCOUNT            "MINCA.ROWCOUNT"
# define SQLCA_FUNCTION            "MINCA.FUNCTION"
# define SQLCA_INTCODE             "MINCA.INTCODE"
# define SQLCA_INTERRM             "MINCA.INTERRM"
# define NAME_SQLVARIABLE_INT      "RexxMINVariable"
# define NAME_SQLGETINFO_INT       "RexxMINGetInfo"
# define NAME_SQLCONNECT_INT       "RexxMINConnect"
# define NAME_SQLDISCONNECT_INT    "RexxMINDisconnect"
# define NAME_SQLDEFAULT_INT       "RexxMINDefault"
# define NAME_SQLCOMMIT_INT        "RexxMINCommit"
# define NAME_SQLROLLBACK_INT      "RexxMINRollback"
# define NAME_SQLCOMMAND_INT       "RexxMINCommand"
# define NAME_SQLPREPARE_INT       "RexxMINPrepare"
# define NAME_SQLDISPOSE_INT       "RexxMINDispose"
# define NAME_SQLEXECUTE_INT       "RexxMINExecute"
# define NAME_SQLOPEN_INT          "RexxMINOpen"
# define NAME_SQLCLOSE_INT         "RexxMINClose"
# define NAME_SQLFETCH_INT         "RexxMINFetch"
# define NAME_SQLGETDATA_INT       "RexxMINGetData"
# define NAME_SQLDESCRIBE_INT      "RexxMINDescribe"
# define NAME_SQLLOADFUNCS_INT         "MINLoadFuncs"
# define NAME_SQLDROPFUNCS_INT     "RexxMINDropFuncs"
# define SQLVARIABLE               RexxMINVariable
# define SQLGETINFO                RexxMINGetInfo
# define SQLCONNECT                RexxMINConnect
# define SQLDISCONNECT             RexxMINDisconnect
# define SQLDEFAULT                RexxMINDefault
# define SQLCOMMIT                 RexxMINCommit
# define SQLROLLBACK               RexxMINRollback
# define SQLCOMMAND                RexxMINCommand
# define SQLPREPARE                RexxMINPrepare
# define SQLDISPOSE                RexxMINDispose
# define SQLEXECUTE                RexxMINExecute
# define SQLEXEC                   RexxMINExec
# define SQLTRANSACT               RexxMINTransact
# define SQLOPEN                   RexxMINOpen
# define SQLCLOSE                  RexxMINClose
# define SQLFETCH                  RexxMINFetch
# define SQLGETDATA                RexxMINGetData
# define SQLDESCRIBE               RexxMINDescribe
# define SQLLOADFUNCS                  MINLoadFuncs
# define SQLDROPFUNCS              RexxMINDropFuncs
# define NAME_SQLVARIABLE_EXT      "MINVARIABLE"
# define NAME_SQLGETINFO_EXT       "MINGETINFO"
# define NAME_SQLCONNECT_EXT       "MINCONNECT"
# define NAME_SQLDISCONNECT_EXT    "MINDISCONNECT"
# define NAME_SQLDEFAULT_EXT       "MINDEFAULT"
# define NAME_SQLCOMMIT_EXT        "MINCOMMIT"
# define NAME_SQLROLLBACK_EXT      "MINROLLBACK"
# define NAME_SQLCOMMAND_EXT       "MINCOMMAND"
# define NAME_SQLPREPARE_EXT       "MINPREPARE"
# define NAME_SQLDISPOSE_EXT       "MINDISPOSE"
# define NAME_SQLOPEN_EXT          "MINOPEN"
# define NAME_SQLCLOSE_EXT         "MINCLOSE"
# define NAME_SQLFETCH_EXT         "MINFETCH"
# define NAME_SQLGETDATA_EXT       "MINGETDATA"
# define NAME_SQLEXECUTE_EXT       "MINEXECUTE"
# define NAME_SQLEXEC_EXT          "MINEXEC"
# define NAME_SQLDESCRIBE_EXT      "MINDESCRIBE"
# define NAME_SQLLOADFUNCS_EXT     "MINLOADFUNCS"
# define NAME_SQLDROPFUNCS_EXT     "MINDROPFUNCS"
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
#define MAX_IDENTIFIER      30            /* Max length of identifiers */
#define TBL_STATEMENTS     253     /* Statement hash table vector size */
#define TBL_CONNECTIONS     17    /* Connection hash table vector size */
#define MAX_ERROR_TEXT    1024             /* Size of SQL error buffer */

#define MAX_DATATYPES       10 /* Maximum number of dataypes supported */

#define NUM_DESCRIBE_COLUMNS 7

#define SUPPORTSPLACEMARKERS FALSE   /* database does NOT support placemarkers */
#define SUPPORTSTRANSACTIONS FALSE   /* database does NOT support transactions */
#define SUPPORTSDMLROWCOUNT  FALSE /* database does NOT set SQLCA.ROWCOUNT for DML */
#define SUPPORTSSQLGETDATA   FALSE /* database does NOT support SqlGetData() function */

#define MAX_PATH_LENGTH		255

#define SWA(stmt)	(&((stmt)->sqlwa))	/* Ptr to STMT's SQL WorkArea */
#define CTX(swa)	((swa)->result)		/* Ptr to mSQL cursor */
#define SQL(swa)	((swa)->sql_stmt)		/* Ptr to mSQL cursor */

#define NO_DATA_FOUND   1

#define RXSQL_ROWCOUNT_TYPE  long
#define RXSQL_SQLCODE_TYPE   long
#define RXSQL_SQLSTATE_TYPE  char
#define RXSQL_SQLERRM_TYPE   char

#define SQL_COMMIT   1
#define SQL_ROLLBACK 0

#endif
