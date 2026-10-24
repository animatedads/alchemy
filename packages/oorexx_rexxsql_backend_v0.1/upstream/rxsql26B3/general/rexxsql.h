/***********************************************************************
 * rexxsql.h - Rexx/SQL common includes
 ***********************************************************************
 *
 * Rexx/SQL. A Rexx interface to SQL databases.
 * Copyright Mark Hessling, 1994-2002.
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

#if 0  /* following supplied by rxpack.h */

#if defined(HAVE_CONFIG_H)
#  include "config.h"
#endif

#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <sys/stat.h>

#ifdef HAVE_MEMORY_H
# include <memory.h>
#endif

#define INCL_RXSHV   /* Shared variable support */
#define INCL_RXFUNC  /* External functions support */
#define INCL_RXSYSEXIT  /* System exit support */

#if !defined(__EMX__)
# if defined(USE_REGINA)
#  include <rexxsaa.h>
# elif defined(USE_QUERCUS)
#  include <windows.h>
#  include <wrexx32.h>
# elif defined(USE_WINREXX)
#  include <windows.h>
#  include <wrexx32.h>
# elif defined(USE_OREXX)
#  include <rexx.h>
# elif defined(USE_OOREXX)
#  include <rexx.h>
# elif defined(USE_UNIREXX)
#  include <rexxsaa.h>
# elif defined(USE_REXXTRANS)
#  include <rexxtrans.h>
# else
#  include <rexxsaa.h>
# endif
#endif

#if defined(__OS2__)
# define OS2 3
# include <os2.h>
#endif

#if 0
#if defined(UNIX)
# if defined(USE_REXX6000)
#  define RXSQL_PUCHAR     PSZ
#  define RXSQL_PCSZ       PSZ
#  define RXSQL_PSZ        PSZ
#  define RXSQL_RXSTRPTR   PUCHAR
#  define RXSQL_PRXFUNC    PRXFUNC
# else
#  define RXSQL_PUCHAR     PSZ
#  define RXSQL_PCSZ       PSZ
#  define RXSQL_PSZ        PSZ
#  define RXSQL_RXSTRPTR   PSZ
#  define RXSQL_PRXFUNC    PFN
# endif
#endif
#endif

#if defined(__OS2__)
# define HAVE_SIZE_T
# define HAVE_STRERROR

#if 0
# if defined(__EMX__)
#  define RXSQL_PUCHAR     PCSZ
#  define RXSQL_PCSZ       PCSZ
#  define RXSQL_PSZ        PSZ
#  define RXSQL_RXSTRPTR   PSZ
#  define RXSQL_PRXFUNC    RexxFunctionHandler *
# else
#  define RXSQL_PUCHAR     PSZ
#  define RXSQL_PCSZ       PSZ
#  define RXSQL_PSZ        PSZ
#  define RXSQL_RXSTRPTR   PSZ
#  define RXSQL_PRXFUNC    PFN
# endif
#endif

#endif

#if defined(WIN32) || defined(WIN64)
# define HAVE_STRERROR
#endif

#if !defined(RXAUTOBUFLEN)
# define RXAUTOBUFLEN 256L
#endif

#if defined(UNIX)
# include <unistd.h>
# define RXSQL_APIENTRY
/* # define RexxSQLFunctionHandler RexxFunctionHandler*/
#endif


#if !defined(HAVE_SIZE_T)
# define HAVE_SIZE_T
  typedef unsigned int  size_t;
#endif

#if !defined(HAVE_STRERROR)
  char *rxsql_get_sys_errlist( int num );
# define strerror(a)    rxsql_get_sys_errlist(a)
#endif

#ifndef R_OK
# define R_OK 4
#endif


#define RETBUFLEN 250

#if defined(__OS2__) && defined(__IBMC__)
# if defined(__DLL__)
#   define DYNAMIC_LIBRARY 1
# endif
# define RXSQL_APIENTRY
/* # define RexxSQLFunctionHandler RexxFunctionHandler*/
#endif

#if defined(__WATCOMC__)
# if defined(__OS2__) || defined(__WINDOWS__) || defined(__NT__)
#  if defined(__SW_BD)
#    define DYNAMIC_LIBRARY 1
#    if defined(__NT__)
#      define RXSQL_APIENTRY /* __cdecl __stdcall  __export */
#    endif
#    if defined(__OS2__)
#      define RXSQL_APIENTRY __syscall __export
#    endif
#  else
#    define RXSQL_APIENTRY /* APIENTRY */
#  endif
# endif
/*# define RexxSQLFunctionHandler RexxFunctionHandler*/
#endif

#if defined(_MSC_VER)
# include <windows.h>
# if defined(DYNAMIC)
#   define DYNAMIC_LIBRARY 1
#   if defined(WIN32) || defined(WIN64)
#     define RXSQL_APIENTRY APIENTRY /* __declspec(dllexport) */
#   else
#     define RXSQL_APIENTRY
#   endif
# else
#   define RXSQL_APIENTRY APIENTRY
# endif
#endif
/*
 * Create our own typedef for a RexxFunctionHandler
 */

#if defined(USE_OREXX) || defined(USE_OOREXX)
# define RexxSQLFunctionHandler RexxFunctionHandler
#else
typedef ULONG RXSQL_APIENTRY RexxSQLFunctionHandler(RXSQL_PUCHAR, ULONG, RXSTRING *, RXSQL_PSZ, RXSTRING *);
#endif

#ifndef TRUE
# define TRUE  1
# define FALSE 0
#endif

/*
 * Run time modes
 */
#define MODE_DEBUG   1
#define MODE_VERBOSE 2

#endif


/*
 * Defines for REXX/SQL variable types
 */
#define TYPE_INT      0
#define TYPE_STRING   1
#define TYPE_ARRAY    2
#define TYPE_BOOL     3
#define TYPE_DATATYPE 4
/*
 * Defines for default NULL string representation
 */
#define NULLSTRINGOUT ""
#define NULLSTRINGIN ""

/*
 * Defines for other SqlVariable() options
 */
#define DEBUGFILE "stderr"
/*
 * Used in SetSqlVariable
 */
#define SQLVAL_NULLSTRINGIN           1
#define SQLVAL_NULLSTRINGOUT          2
#define SQLVAL_VERSION                3
#define SQLVAL_SUPPORTSTRANSACTIONS   4
#define SQLVAL_SUPPORTSSQLGETDATA     5
#define SQLVAL_DESCRIBECOLUMNS        6
#define SQLVAL_DATATYPES              7
#define SQLVAL_DBMSNAME               8
#define SQLVAL_DBMSVERSION            9
#define SQLVAL_DEBUG                 10
#define SQLVAL_DEBUGFILE             11
#define SQLVAL_ROWLIMIT              12
#define SQLVAL_LONGLIMIT             13
#define SQLVAL_SAVESQL               14
#define SQLVAL_AUTOCOMMIT            15
#define SQLVAL_IGNORETRUNCATE        16
#define SQLVAL_STANDARDPLACEMARKERS  17
#define SQLVAL_SUPPORTSDMLROWCOUNT   18
#define SQLVAL_SUPPORTSPLACEMARKERS  19
#define SQLVAL_SUPPORTSTHREADS       20
/*
 * Name of default (implict) statement
 */
#define DEFAULT_STATEMENT "DEFAULT"
/*
 * Name of COMMIT/ROLLBACK (implict) statement
 */
#define TRANS_STATEMENT "TRANS"

/*
 * Default size of LONG data returned
 */
#define DEFAULT_LONG_LIMIT  32768

/*
 * Error value returned for errors returned by database as opposed to
 * those generated by the interface.
 */
#define DB_ERROR  (-1L)
#define DB_WARNING   (1L)

/*
 * Some arbitrary number to ensure it doesn't match a valid
 * internal datatype; ODBC uses negative and positive numbers :-(
 */
#define RXSQL_INVALID_DATATYPE  (-94563)

/* Directory separator is:
 * MS-DOS   '\'
 * OS/2  '\'
 * UNIX     '/'
 * VMS      ']' & ':'
 * WIN32 '\'
 */

#ifdef __OS2__
# define BAD_ARGS 0
# define REXX_FAIL   1
# define DIRSEP(ch) (ch == '\\' && ch == ':')
# define CURRENT_OS "OS/2"
#endif

#ifdef MSDOS
# define BAD_ARGS 0
# define REXX_FAIL   1
# define DIRSEP(ch) (ch == '\\' && ch == ':')
# define CURRENT_OS "DOS"
#endif

#ifdef UNIX
# define BAD_ARGS 2
# define REXX_FAIL   1
# define DIRSEP(ch) (ch == '/')
# define CURRENT_OS "UNIX"
#endif

#ifdef WIN32
# define BAD_ARGS 0
# define REXX_FAIL   1
# define DIRSEP(ch) (ch == '\\' && ch == ':')
# define CURRENT_OS "WIN32"
#endif

#ifdef WIN64
# define BAD_ARGS 0
# define REXX_FAIL   1
# define DIRSEP(ch) (ch == '\\' && ch == ':')
# define CURRENT_OS "WIN64"
#endif

#ifdef VMS
# define BAD_ARGS 0
# define REXX_FAIL   0
# define DIRSEP(ch) (ch == ']' || ch == ':')
# define CURRENT_OS "VMS"
#endif

RexxFunctionHandler SQLVARIABLE;
RexxFunctionHandler SQLGETINFO;
RexxFunctionHandler SQLCONNECT;
RexxFunctionHandler SQLDISCONNECT;
RexxFunctionHandler SQLDEFAULT;
RexxFunctionHandler SQLCOMMIT;
RexxFunctionHandler SQLROLLBACK;
RexxFunctionHandler SQLCOMMAND;
RexxFunctionHandler SQLPREPARE;
RexxFunctionHandler SQLDISPOSE;
RexxFunctionHandler SQLEXECUTE;
RexxFunctionHandler SQLOPEN;
RexxFunctionHandler SQLCLOSE;
RexxFunctionHandler SQLFETCH;
RexxFunctionHandler SQLGETDATA;
RexxFunctionHandler SQLDESCRIBE;
RexxFunctionHandler SQLDATASOURCES;
RexxFunctionHandler SQLTABLES;
RexxFunctionHandler SQLCOLUMNS;
RexxFunctionHandler SQLLOADFUNCS;
RexxFunctionHandler SQLDROPFUNCS;

/*
 * Structure to define a REXX/SQL variable descriptor entry. Note that this
 * describes the variable but does not define storage for it!
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct _SQLVAL
{
   struct _SQLVAL *next;
   char  name[MAX_IDENTIFIER+1];
   char  user_update;
   char  dtype;
   int   option;
   void  *value;
   int   valtype;
} SQLVAL;

/*
 * Structure to define a saved SQL statement; ie the text of the statement.
 */
typedef struct _SAVEDSQLSTMT
{
   char     *sql_stmt;      /* ptr to buffer to hold SQL statement */
   int      sql_stmt_sz;    /* size of SQL statement */
   int      sql_buffer_sz;  /* size of allocated statement buffer >= sql_stmt_sz*/
} SAVEDSQLSTMT;

#ifdef HAVE_PROTO
# define Args(a) a
#else
# define Args(a) ()
#endif

static int SetIntError Args((RxPackageGlobalDataDef *,char *, int, int, char *));
static void SetSQLCA Args((RxPackageGlobalDataDef *,RXSQL_SQLCODE_TYPE, RXSQL_SQLSTATE_TYPE *, RXSQL_SQLERRM_TYPE *, char *));
static void SetRowCount Args((RxPackageGlobalDataDef *,RXSQL_ROWCOUNT_TYPE));
#if defined(USES_COMPUTE_COUNT)
static void SetComputeCount Args((RxPackageGlobalDataDef *,RXSQL_COMPUTECOUNT_TYPE));
#endif
static void ClearDBError Args((RxPackageGlobalDataDef *RxPackageGlobalData));
static void ClearIntError Args((RxPackageGlobalDataDef *RxPackageGlobalData));
#if !defined(REXXSQL_IGNORE_SELECTSTATEMENT)
static int SelectStatement Args((RxPackageGlobalDataDef *,char *,long));
#endif
static ULONG ReturnError Args((RxPackageGlobalDataDef *,RXSTRING *, int, char *));
static int MkIdentifier Args((RxPackageGlobalDataDef *,RXSTRING, PSZ, size_t));
static int SaveSqlStatement Args((RxPackageGlobalDataDef *, SAVEDSQLSTMT *, char *, int));
#if !defined(REXXSQL_IGNORE_COUNTQUESTIONMARKS)
static int CountQuestionMarks Args((RxPackageGlobalDataDef *,char *));
#endif
static void *GetSqlVariableValue Args(( RxPackageGlobalDataDef *,int, void * ));
static SQLVAL *InstallSQLVariable Args((RxPackageGlobalDataDef *,int *,char *, SQLVAL *tbl, int, int, int, void *, int));
static int InstallSQLVariables Args((RxPackageGlobalDataDef *RxPackageGlobalData));
static int InitRexxSQL Args((RxPackageGlobalDataDef *,char *,int));
static int TerminateRexxSQL Args((RxPackageGlobalDataDef *,char *));
static int DBInitialise Args((RxPackageGlobalDataDef *RxPackageGlobalData));
static int ArrayToArgv Args((RxPackageGlobalDataDef *,RXSTRING*, RXSTRING*, ULONG *, RXSTRING *));
static int ArgvToArgv Args((RxPackageGlobalDataDef *,ULONG, RXSTRING *, ULONG *, RXSTRING *));
static RXSTRING *FreeArgv Args((RxPackageGlobalDataDef *,ULONG *, RXSTRING *));
static int ReleaseDbEnvironment Args((RxPackageGlobalDataDef *));
static SQLVAL *ll_add Args((RxPackageGlobalDataDef *,SQLVAL *,SQLVAL *));
static SQLVAL *ll_free Args((RxPackageGlobalDataDef *,SQLVAL *));
static  SQLVAL *ll_find Args((RxPackageGlobalDataDef *,SQLVAL *, char *));
int RexxSQLInitialiser Args(( RxPackageGlobalDataDef * ));
int RexxSQLTerminator Args(( RxPackageGlobalDataDef * ));

/*
 * Hash functions...
 */
typedef struct _BUCKET
{
   struct _BUCKET *next;
   struct _BUCKET **prev;
} BUCKET;

void*  NewObject(RxPackageGlobalDataDef*,int size);
void   FreeObject(RxPackageGlobalDataDef*,void *obj);
void*  InsertObject(RxPackageGlobalDataDef*,void *obj, BUCKET *tbl[], int tblsz);
void   RemoveObject(RxPackageGlobalDataDef*,void *obj);
void*  FindObject(RxPackageGlobalDataDef*,char *name, BUCKET *tbl[], int tblsz);
void*  FirstObject(RxPackageGlobalDataDef*,int idx, BUCKET *tbl[]);
void*  NextObject(RxPackageGlobalDataDef*,void *obj);

#define OPT_DYNAMIC   0001
#define OPT_STATIC    0002

/*
 * Structure to define datatypes supported by the database
 */
typedef struct
{
   char  *ext_datatype; /* external datatype name */
   int   int_datatype;  /* internal datatype */
   char  long_datatype; /* indicates if column data needs to be accessed via SqlGetData() */
} REXXSQL_DT;

/*
 * Structure to define datatypes supported by the database
 */
typedef struct
{
   int   strlength;  /* length of the strptr */
   char  *strptr;    /* datatype string */
   int   internal;   /* internal datatype */
   int   binary;     /* indicates if this is an internal binary type; used by ODBC/CLI */
} RXSTRING_DT;

#if !defined(max)
# define max(a,b)        (((a) > (b)) ? (a) : (b))
#endif

#if !defined(min)
# define min(a,b)        (((a) < (b)) ? (a) : (b))
#endif

