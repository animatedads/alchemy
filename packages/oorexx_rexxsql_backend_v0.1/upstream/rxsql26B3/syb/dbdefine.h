/***********************************************************************
 * dbdefine.h - Rexx/SQL definitions for Sybase System 10/11
 ***********************************************************************
 *
 * Rexx/SQL. A Rexx interface to SQL databases.
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

#if defined(SYB_PREFIX)
# define DLLNAME "rexxsyb"
# define DEFAULT_CONNECTION	"SYB"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SYB"   /* Default stem name of implicit stmt */
#else
# define DLLNAME "rexxsql"
# define DEFAULT_CONNECTION	"SQL"       /* Name of the unnamed connection */
# define DEFAULT_STEM		"SQL"   /* Default stem name of implicit stmt */
#endif

#define CURRENT_DB "Sybase"

#if defined(SYB_PREFIX)
# define SQLCA_STEM                "SYBCA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "SYBCA.SQLCODE"
# define SQLCA_SQLERRM             "SYBCA.SQLERRM"
# define SQLCA_SQLTEXT             "SYBCA.SQLTEXT"
# define SQLCA_SQLSTATE            "SYBCA.SQLSTATE"
# define SQLCA_ROWCOUNT            "SYBCA.ROWCOUNT"
# define SQLCA_COMPUTECOUNT        "SYBCA.COMPUTECOUNT"
# define SQLCA_FUNCTION            "SYBCA.FUNCTION"
# define SQLCA_INTCODE             "SYBCA.INTCODE"
# define SQLCA_INTERRM             "SYBCA.INTERRM"
# define NAME_SQLVARIABLE_INT      "RexxSYBVariable"
# define NAME_SQLGETINFO_INT       "RexxSYBGetInfo"
# define NAME_SQLCONNECT_INT       "RexxSYBConnect"
# define NAME_SQLDISCONNECT_INT    "RexxSYBDisconnect"
# define NAME_SQLDEFAULT_INT       "RexxSYBDefault"
# define NAME_SQLCOMMIT_INT        "RexxSYBCommit"
# define NAME_SQLROLLBACK_INT      "RexxSYBRollback"
# define NAME_SQLCOMMAND_INT       "RexxSYBCommand"
# define NAME_SQLPREPARE_INT       "RexxSYBPrepare"
# define NAME_SQLDISPOSE_INT       "RexxSYBDispose"
# define NAME_SQLEXECUTE_INT       "RexxSYBExecute"
# define NAME_SQLOPEN_INT          "RexxSYBOpen"
# define NAME_SQLCLOSE_INT         "RexxSYBClose"
# define NAME_SQLFETCH_INT         "RexxSYBFetch"
# define NAME_SQLGETDATA_INT       "RexxSYBGetData"
# define NAME_SQLDESCRIBE_INT      "RexxSYBDescribe"
# define NAME_SQLLOADFUNCS_INT         "SYBLoadFuncs"
# define NAME_SQLDROPFUNCS_INT     "RexxSYBDropFuncs"
# define SQLVARIABLE               RexxSYBVariable
# define SQLGETINFO                RexxSYBGetInfo
# define SQLCONNECT                RexxSYBConnect
# define SQLDISCONNECT             RexxSYBDisconnect
# define SQLDEFAULT                RexxSYBDefault
# define SQLCOMMIT                 RexxSYBCommit
# define SQLROLLBACK               RexxSYBRollback
# define SQLCOMMAND                RexxSYBCommand
# define SQLPREPARE                RexxSYBPrepare
# define SQLDISPOSE                RexxSYBDispose
# define SQLEXECUTE                RexxSYBExecute
# define SQLEXEC                   RexxSYBExec
# define SQLTRANSACT               RexxSYBTransact
# define SQLOPEN                   RexxSYBOpen
# define SQLCLOSE                  RexxSYBClose
# define SQLFETCH                  RexxSYBFetch
# define SQLGETDATA                RexxSYBGetData
# define SQLDESCRIBE               RexxSYBDescribe
# define SQLLOADFUNCS                  SYBLoadFuncs
# define SQLDROPFUNCS              RexxSYBDropFuncs
# define NAME_SQLVARIABLE_EXT      "SYBVARIABLE"
# define NAME_SQLGETINFO_EXT       "SYBGETINFO"
# define NAME_SQLCONNECT_EXT       "SYBCONNECT"
# define NAME_SQLDISCONNECT_EXT    "SYBDISCONNECT"
# define NAME_SQLDEFAULT_EXT       "SYBDEFAULT"
# define NAME_SQLCOMMIT_EXT        "SYBCOMMIT"
# define NAME_SQLROLLBACK_EXT      "SYBROLLBACK"
# define NAME_SQLCOMMAND_EXT       "SYBCOMMAND"
# define NAME_SQLPREPARE_EXT       "SYBPREPARE"
# define NAME_SQLDISPOSE_EXT       "SYBDISPOSE"
# define NAME_SQLOPEN_EXT          "SYBOPEN"
# define NAME_SQLCLOSE_EXT         "SYBCLOSE"
# define NAME_SQLFETCH_EXT         "SYBFETCH"
# define NAME_SQLGETDATA_EXT       "SYBGETDATA"
# define NAME_SQLEXECUTE_EXT       "SYBEXECUTE"
# define NAME_SQLEXEC_EXT          "SYBEXEC"
# define NAME_SQLDESCRIBE_EXT      "SYBDESCRIBE"
# define NAME_SQLLOADFUNCS_EXT     "SYBLOADFUNCS"
# define NAME_SQLDROPFUNCS_EXT     "SYBDROPFUNCS"
#else
# define SQLCA_STEM                "SQLCA"     /* Name of stem of SQLCA variable */
# define SQLCA_SQLCODE             "SQLCA.SQLCODE"
# define SQLCA_SQLERRM             "SQLCA.SQLERRM"
# define SQLCA_SQLTEXT             "SQLCA.SQLTEXT"
# define SQLCA_SQLSTATE            "SQLCA.SQLSTATE"
# define SQLCA_ROWCOUNT            "SQLCA.ROWCOUNT"
# define SQLCA_COMPUTECOUNT        "SQLCA.COMPUTECOUNT"
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

#define MAX_DATATYPES       30 /* Maximum number of dataypes supported */

#define NUM_DESCRIBE_COLUMNS 6

#define SUPPORTSPLACEMARKERS TRUE    /* does database support placemarkers */
#define SUPPORTSTRANSACTIONS TRUE    /* does database support transactions */
#define SUPPORTSDMLROWCOUNT  TRUE  /* database sets SQLCA.ROWCOUNT for DML */
#define SUPPORTSSQLGETDATA   FALSE /* database supports SqlGetLong() function */

#define MAX_PATH_LENGTH		255

#define SWA(stmt)	(&((stmt)->sqlwa))	/* Ptr to STMT's SQL WorkArea */
#define CTX(swa)	((swa)->conn_handle)		/* Ptr to connection handle */
#define SQL(swa)	((swa)->sql_stmt)		/* Ptr to saved SQL text */

#define NO_DATA_FOUND   1

#if defined(CS_SQLSTATE_SIZE)
# define SQL_SQLSTATE_SIZE     CS_SQLSTATE_SIZE
#else
# define SQL_SQLSTATE_SIZE     6
#endif

#define USES_COMPUTE_COUNT 1

#define RXSQL_COMPUTECOUNT_TYPE  long
#define RXSQL_ROWCOUNT_TYPE  long
#define RXSQL_SQLCODE_TYPE   long
#define RXSQL_SQLSTATE_TYPE  char
#define RXSQL_SQLERRM_TYPE   char

#define SQL_COMMIT     1
#define SQL_ROLLBACK   0

#endif
