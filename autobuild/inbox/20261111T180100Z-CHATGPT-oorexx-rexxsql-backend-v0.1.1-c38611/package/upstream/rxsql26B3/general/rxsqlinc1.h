/*
 * rxsqlinc1.h - Rexx/SQL utility functions
 *
 *
 * Rexx/SQL. A Rexx interface to SQL databases.
 * Copyright Mark Hessling, 1996-2002.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 * This software is going to be maintained and enhanced as deemed
 * necessary by the community.
 *
 * Mark Hessling  M.Hessling@qut.edu.au  http://www.lightlink.com/hessling/
 *
 */

#include "rxmt.h"

char *RxPackageName = DLLNAME;

#if !defined(DYNAMIC_LIBRARY) && (defined(USE_WINREXX) || defined(USE_QUERCUS))
RexxExitHandler RxExitHandlerForSayTraceRedirection;
#endif

/*-----------------------------------------------------------------------------
 * Table of REXX/SQL Functions. Used to install/de-install functions.
 *----------------------------------------------------------------------------*/
static RexxFunction RexxSQLFunctions[] = {
  { (RRFD_ARG0_TYPE)NAME_SQLCONNECT_EXT    ,(RRFE_ARG1_TYPE)SQLCONNECT    ,(RRFD_ARG2_TYPE)NAME_SQLCONNECT_INT    , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLDISCONNECT_EXT ,(RRFE_ARG1_TYPE)SQLDISCONNECT ,(RRFD_ARG2_TYPE)NAME_SQLDISCONNECT_INT , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLDEFAULT_EXT    ,(RRFE_ARG1_TYPE)SQLDEFAULT    ,(RRFD_ARG2_TYPE)NAME_SQLDEFAULT_INT    , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLCOMMIT_EXT     ,(RRFE_ARG1_TYPE)SQLCOMMIT     ,(RRFD_ARG2_TYPE)NAME_SQLCOMMIT_INT     , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLROLLBACK_EXT   ,(RRFE_ARG1_TYPE)SQLROLLBACK   ,(RRFD_ARG2_TYPE)NAME_SQLROLLBACK_INT   , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLCOMMAND_EXT    ,(RRFE_ARG1_TYPE)SQLCOMMAND    ,(RRFD_ARG2_TYPE)NAME_SQLCOMMAND_INT    , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLPREPARE_EXT    ,(RRFE_ARG1_TYPE)SQLPREPARE    ,(RRFD_ARG2_TYPE)NAME_SQLPREPARE_INT    , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLDISPOSE_EXT    ,(RRFE_ARG1_TYPE)SQLDISPOSE    ,(RRFD_ARG2_TYPE)NAME_SQLDISPOSE_INT    , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLEXECUTE_EXT    ,(RRFE_ARG1_TYPE)SQLEXECUTE    ,(RRFD_ARG2_TYPE)NAME_SQLEXECUTE_INT    , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLOPEN_EXT       ,(RRFE_ARG1_TYPE)SQLOPEN       ,(RRFD_ARG2_TYPE)NAME_SQLOPEN_INT       , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLCLOSE_EXT      ,(RRFE_ARG1_TYPE)SQLCLOSE      ,(RRFD_ARG2_TYPE)NAME_SQLCLOSE_INT      , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLFETCH_EXT      ,(RRFE_ARG1_TYPE)SQLFETCH      ,(RRFD_ARG2_TYPE)NAME_SQLFETCH_INT      , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLGETDATA_EXT    ,(RRFE_ARG1_TYPE)SQLGETDATA    ,(RRFD_ARG2_TYPE)NAME_SQLGETDATA_INT    , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLVARIABLE_EXT   ,(RRFE_ARG1_TYPE)SQLVARIABLE   ,(RRFD_ARG2_TYPE)NAME_SQLVARIABLE_INT   , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLGETINFO_EXT    ,(RRFE_ARG1_TYPE)SQLGETINFO    ,(RRFD_ARG2_TYPE)NAME_SQLGETINFO_INT    , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLDESCRIBE_EXT   ,(RRFE_ARG1_TYPE)SQLDESCRIBE   ,(RRFD_ARG2_TYPE)NAME_SQLDESCRIBE_INT   , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLDATASOURCES_EXT,(RRFE_ARG1_TYPE)SQLDATASOURCES,(RRFD_ARG2_TYPE)NAME_SQLDATASOURCES_INT, 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLTABLES_EXT     ,(RRFE_ARG1_TYPE)SQLTABLES     ,(RRFD_ARG2_TYPE)NAME_SQLTABLES_INT     , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLCOLUMNS_EXT    ,(RRFE_ARG1_TYPE)SQLCOLUMNS    ,(RRFD_ARG2_TYPE)NAME_SQLCOLUMNS_INT    , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLDROPFUNCS_EXT  ,(RRFE_ARG1_TYPE)SQLDROPFUNCS  ,(RRFD_ARG2_TYPE)NAME_SQLDROPFUNCS_INT  , 1  },
  { (RRFD_ARG0_TYPE)NAME_SQLLOADFUNCS_EXT  ,(RRFE_ARG1_TYPE)SQLLOADFUNCS  ,(RRFD_ARG2_TYPE)NAME_SQLLOADFUNCS_INT  , 0  }, /* don't load this for DLL */
#ifdef INCLUDE_LITEGETINSERTID_FUNC
  { (RRFD_ARG0_TYPE)"LITEGETINSERTID"      ,(RRFE_ARG1_TYPE)RexxLITEGetInsertId,(RRFD_ARG2_TYPE)"RexxLITEGetInsertId", 1  },
#endif
#ifdef INCLUDE_MYGETINSERTID_FUNC
  { (RRFD_ARG0_TYPE)"MYGETINSERTID"        ,(RRFE_ARG1_TYPE)RexxMYGetInsertId,(RRFD_ARG2_TYPE)"RexxMYGetInsertId" , 1  },
#endif
#ifdef INCLUDE_ORASTARTUP_FUNC
  { (RRFD_ARG0_TYPE)"ORASTARTUP"           ,(RRFE_ARG1_TYPE)RexxORAStartup,(RRFD_ARG2_TYPE)"RexxORAStartup"       , 1  },
#endif
#ifdef INCLUDE_ORASHUTDOWN_FUNC
  { (RRFD_ARG0_TYPE)"ORASHUTDOWN"          ,(RRFE_ARG1_TYPE)RexxORAShutdown,(RRFD_ARG2_TYPE)"RexxORAShutdown"     , 1  },
#endif
  { NULL                                   ,NULL                          ,NULL                                   , 0  }
};

typedef struct
{
   DBENV *DbEnv;
   SQLVAL *opt_tbl;
   char **column_attribute;
   /* ---------------------------------------------------------------------
    * These global variables hold the result of the last function call.
    */
   RXSQL_SQLCODE_TYPE  SQLCA_SqlCode;
   RXSQL_ROWCOUNT_TYPE SQLCA_RowCount;
   long SQLCA_IntCode;
   RXSQL_SQLSTATE_TYPE SQLCA_SqlState[SQL_SQLSTATE_SIZE+1];
#if defined(USES_COMPUTE_COUNT)
   RXSQL_COMPUTECOUNT_TYPE  SQLCA_ComputeCount;
#endif
   /*
    * Settable variables
    *
    * ---------------------------------------------------------------------
    * Limits number of rows returned by SQLCOMMAND(). If set to zero (0) then
    * all rows in query are returned (unless memory is exhausted in which case
    * an error is returned)!
    */
   ULONG RowLimit;
   /* ---------------------------------------------------------------------
    * Limits size of a "LONG" column to the specified size.
    * This limit is only imposed by a normal row FETCH; and is ignored by
    * the size specified in SqlGetData()
    */
   ULONG LongLimit;
   /* ---------------------------------------------------------------------
    * If TRUE; the SQL statement is saved on each parse (SqlCommand()
    * & SqlPrepare()).  If TRUE then on errors; the last SQL statement can be
    * retrieved in a REXX program by calling SQLVARIABLE().
    * eg.      error_stmt = SqlVariable('sqltext');
    */
   ULONG SaveSQL;
   /* ---------------------------------------------------------------------
    * If TRUE; the default AUTOCOMMIT behaviour for statements is ON.
    */
   ULONG AutoCommit;
   /* ---------------------------------------------------------------------
    * If TRUE; any truncation errors will be ignored
    */
   ULONG IgnoreTruncate;
   /* ---------------------------------------------------------------------
    * If TRUE; REXX/SQL will allow the user to supply ? as placemarkers
    * instead of :1 or :name placemarkers. Only applicable to Oracle.
    */
   ULONG StandardPlacemarkers;
   /* ---------------------------------------------------------------------
    * If TRUE; the database supports transactions.
    */
   ULONG SupportsTransactions;
   /* ---------------------------------------------------------------------
    * If TRUE; the database supports placemarkers.
    */
   ULONG SupportsPlacemarkers;
   /* ---------------------------------------------------------------------
    * If TRUE; the database sets SQLCA.ROWCOUNT for DML statements
    */
   ULONG SupportsDMLRowcount;
   /* ---------------------------------------------------------------------
    * If TRUE; the database supports the SqlGetData() function
    */
   ULONG SupportsSqlGetData;
   /* ---------------------------------------------------------------------
    * If TRUE; the database supports threads.
    */
   ULONG SupportsThreads;
   /* ---------------------------------------------------------------------
    * String representing a NULL value returned from a SELECT statement.
    * Default is the empty string; ""
    */
   RXSTRING RXSNullStringOut;
   char NullStringOut[MAX_IDENTIFIER+1]; /* set in InstallSQLVariables() */
   /* ---------------------------------------------------------------------
    * String representing a NULL value when passed as a bind value.
    * Default is ""
    */
   RXSTRING RXSNullStringIn;
   char NullStringIn[MAX_IDENTIFIER+1]; /* set in InstallSQLVariables() */
   /* ---------------------------------------------------------------------
    * Debug file storage.
    * Default is "stderr"
    */
   RXSTRING RXSDebugFile;
   char DebugFile[MAX_PATH+1]; /* set in InstallSQLVariables() */
   /* ---------------------------------------------------------------------
    * Current version/platform
    */
   RXSTRING RexxSqlVersion;
   char RexxSqlVersionString[100];
   /* ---------------------------------------------------------------------
    * Database Name and Version
    */
   RXSTRING RXSDBMSName;
   char DBMSName[100];
   RXSTRING RXSDBMSVer;
   char DBMSVer[250+1];
   /*
    * Memory for converted SQL statements.
    */
   char *converted_stmt;
   int converted_stmt_len;
   /*
    * The following items are specific to each database
    * Need to #define the appropriate item before #includeing
    * this file
    */
#if defined(NEED_RXSQL_HENV)
   RXSQL_HENV henv;
#endif
} REXXSQLDATA;


RxPackageGlobalDataDef *TSD;

/* ---------------------------------------------------------------------
 * The following table defines those values that can be used with the
 * SQLGetInfo() and SQLSetInfo() functions.
 */
/*            name              settable type          dyn/conn reqd  maxlen  value func */
static SQLVAL sqlvariable_vars[] =
{
   {NULL,"DEBUG",                1, TYPE_INT,     OPT_STATIC , NULL,   SQLVAL_DEBUG},
   {NULL,"DEBUGFILE",            1, TYPE_STRING,  OPT_STATIC , NULL,   SQLVAL_DEBUGFILE},
   {NULL,"ROWLIMIT",             1, TYPE_INT,     OPT_STATIC , NULL,   SQLVAL_ROWLIMIT},
   {NULL,"LONGLIMIT",            1, TYPE_INT,     OPT_STATIC , NULL,   SQLVAL_LONGLIMIT},
   {NULL,"SAVESQL",              1, TYPE_BOOL,    OPT_STATIC , NULL,   SQLVAL_SAVESQL},
   {NULL,"AUTOCOMMIT",           1, TYPE_BOOL,    OPT_STATIC , NULL,   SQLVAL_AUTOCOMMIT},
   {NULL,"IGNORETRUNCATE",       1, TYPE_BOOL,    OPT_STATIC , NULL,   SQLVAL_IGNORETRUNCATE},
   {NULL,"NULLSTRINGIN",         1, TYPE_STRING,  OPT_STATIC , NULL,   SQLVAL_NULLSTRINGIN},
   {NULL,"NULLSTRINGOUT",        1, TYPE_STRING,  OPT_STATIC , NULL,   SQLVAL_NULLSTRINGOUT},
   {NULL,"STANDARDPLACEMARKERS", 1, TYPE_BOOL,    OPT_STATIC , NULL,   SQLVAL_STANDARDPLACEMARKERS},
   {NULL,"SUPPORTSDMLROWCOUNT",  0, TYPE_BOOL,    OPT_STATIC , NULL,   SQLVAL_SUPPORTSDMLROWCOUNT},
   {NULL,"SUPPORTSPLACEMARKERS", 0, TYPE_BOOL,    OPT_STATIC , NULL,   SQLVAL_SUPPORTSPLACEMARKERS},
   {NULL,"VERSION",              0, TYPE_STRING,  OPT_STATIC , NULL,   SQLVAL_VERSION},
   {NULL,"",                     0, 0,            0          , NULL,0},
};

static SQLVAL sqlgetinfo_vars[] =
{
   {NULL,"SUPPORTSTRANSACTIONS", 0, TYPE_BOOL,    OPT_STATIC , NULL,   SQLVAL_SUPPORTSTRANSACTIONS},
   {NULL,"SUPPORTSSQLGETDATA",   0, TYPE_BOOL,    OPT_STATIC , NULL,   SQLVAL_SUPPORTSSQLGETDATA},
   {NULL,"SUPPORTSTHREADS",      0, TYPE_BOOL,    OPT_STATIC , NULL,   SQLVAL_SUPPORTSTHREADS},
   {NULL,"DESCRIBECOLUMNS",      0, TYPE_ARRAY,   OPT_DYNAMIC, NULL,   SQLVAL_DESCRIBECOLUMNS},
   {NULL,"DATATYPES",            0, TYPE_DATATYPE,OPT_DYNAMIC, NULL,   SQLVAL_DATATYPES},
   {NULL,"DBMSNAME",             0, TYPE_STRING,  OPT_STATIC , NULL,   SQLVAL_DBMSNAME},
   {NULL,"DBMSVERSION",          0, TYPE_STRING,  OPT_STATIC , NULL,   SQLVAL_DBMSVERSION},
   {NULL,"",                     0, 0,            0          , NULL,   0},
};

static void *SQLValSetDescribeColumns Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetDatatypes Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetVersion Args((RxPackageGlobalDataDef *,void *));
static void *SQLValSetDebugFile Args((RxPackageGlobalDataDef *,void *));
static void *SQLValSetNullStringIn Args((RxPackageGlobalDataDef *,void *));
static void *SQLValSetNullStringOut Args((RxPackageGlobalDataDef *,void *));
static void *SQLValSetDBMSName Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetDBMSVer Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetSupportsSqlGetData Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetSupportsTransactions Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetSupportsThreads Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetRowLimit Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetLongLimit Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetSaveSQL Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetAutoCommit Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetIgnoreTruncate Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetStandardPlacemarkers Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetSupportsDMLRowcount Args((RxPackageGlobalDataDef *,DBCON *));
static void *SQLValSetSupportsPlacemarkers Args((RxPackageGlobalDataDef *,DBCON *));
