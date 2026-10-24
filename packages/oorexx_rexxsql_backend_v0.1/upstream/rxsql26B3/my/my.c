/*
 * my.c - Rexx/SQL for MySQL
 *
 *
 * Rexx/SQL. A Rexx interface to SQL databases.
 * Copyright (C) Mark Hessling 1995-2006.
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
 *  This software is going to be maintained and enhanced as deemed
 *  necessary by the community.
 *
 * Mark Hessling  M.Hessling@qut.edu.au  http://www.lightlink.com/hessling/
 *
 * Author:  Mark Hessling
 *
 *    Purpose: This module provides a MySQL SQL interface for Rexx. It
 *    allows Rexx programs to connect to mySQL servers, issue SQL
 *    queries, DDL, DCL & DML statements. Multiple concurrent
 *    connections are supported. Additionally, multiple statements
 *    may be active concurrently against any or all of these
 *    connections. This interface is called "Rexx/SQL".
 *
 */

static char RCSid[] = "$Id: my.c,v 1.28 2010/09/20 21:43:09 mark Exp $";

#include "rxpack.h"

#define INCL_RXSHV   /* Shared variable support */
#define INCL_RXFUNC  /* External functions support */

#include "dbdefine.h"
#include "rexxsql.h"
#include "dbheader.h"
#include "dbtypes.h"

#define FLDDSCR MYSQL_FIELD

#define MY_INFO_DATASOURCES 0
#define MY_INFO_TABLES      1
#define MY_INFO_COLUMNS     2

/*
 * Definition of SQL Work Area (SQLWA).  This contains the mySQL user
 * context area plus additional information required by this interface to
 * control the processing of SQL statements.
 */

typedef struct
{
   MYSQL_RES *result;           /* mySQL result handle */
   MYSQL_STMT *stmt;              /* MySQL statement */
   SAVEDSQLSTMT saved_stmt; /* structure to hold SQL statement */
   int      expr_cnt;     /* number of expressions in select list */
   FLDDSCR  *fa[MAX_COLS];   /* array of pointers to column dscr's */
} SQLWA;


/*
 * Connection structure. Each connection requires one of these!
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct
{
   char      name[MAX_IDENTIFIER+1];  /* Connection name */
   MYSQL     mysql;       /* Socket descriptor for connection */
   char      dbName[MAX_PATH_LENGTH];    /* Database name */
   void      *dflt_stmt;     /* Pointer to implicit statement */
   int       num_statements;    /* Number of explicit statements */
   SQLVAL    *db_opt;  /* SqlGetInfo linked list */
} DBCON;


/*
 * Statement structure. Each statement requires one of these!
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct
{
   char      name[MAX_IDENTIFIER+1];  /* Statement name */
   DBCON     *db;         /* Pointer to connection structure */
   SQLWA     sqlwa;       /* MYSQL_RES etc. for statement */
} STMT;


/*
 * Basic REXXSQL environment structure - allocated when 1st connection made!
 */
typedef struct
{
   int       num_connections;      /* Number of active connections */
   DBCON     *current_connection;  /* Pointer to current connection */
   BUCKET    *db_tbl[TBL_CONNECTIONS];   /* Connection hash table */
   BUCKET    *stmt_tbl[TBL_STATEMENTS];/* Statement hash table */
} DBENV;

static char *col_attribute[] =
{
   "NAME", "TYPE", "SIZE", "PRECISION", "SCALE", "NULLABLE", "PRIMARYKEY", "BLOB", (char*)NULL
};

#ifdef WIN32
/*
 * The following code is to enable Rexx/SQL for MySQL on Windows to build
 * independently of the compiler. Since 5.0, MySQL changed the compiler
 * to VC 7.0 which is incompatible with VC 6.0.
 */
HMODULE handle=NULL;

typedef my_ulonglong STDCALL T_MYSQL_AFFECTED_ROWS(MYSQL *);
T_MYSQL_AFFECTED_ROWS *p_mysql_affected_rows;
typedef void STDCALL T_MYSQL_CLOSE(MYSQL *);
T_MYSQL_CLOSE *p_mysql_close;
typedef const char * STDCALL T_MYSQL_ERROR(MYSQL *);
T_MYSQL_ERROR *p_mysql_error;
typedef MYSQL_FIELD * STDCALL T_MYSQL_FETCH_FIELD(MYSQL_RES *);
T_MYSQL_FETCH_FIELD *p_mysql_fetch_field;
typedef MYSQL_ROW STDCALL T_MYSQL_FETCH_ROW(MYSQL_RES *);
T_MYSQL_FETCH_ROW *p_mysql_fetch_row;
typedef unsigned int STDCALL T_MYSQL_FIELD_COUNT(MYSQL *);
T_MYSQL_FIELD_COUNT *p_mysql_field_count;
typedef MYSQL_FIELD_OFFSET STDCALL T_MYSQL_FIELD_SEEK(MYSQL_RES *,MYSQL_FIELD_OFFSET);
T_MYSQL_FIELD_SEEK *p_mysql_field_seek;
typedef void STDCALL T_MYSQL_FREE_RESULT(MYSQL_RES *);
T_MYSQL_FREE_RESULT *p_mysql_free_result;
typedef const char * STDCALL T_MYSQL_GET_SERVER_INFO(MYSQL *);
T_MYSQL_GET_SERVER_INFO *p_mysql_get_server_info;
typedef MYSQL * STDCALL T_MYSQL_INIT(MYSQL *);
T_MYSQL_INIT *p_mysql_init;
typedef my_ulonglong STDCALL T_MYSQL_INSERT_ID(MYSQL *);
T_MYSQL_INSERT_ID *p_mysql_insert_id;
typedef unsigned int STDCALL T_MYSQL_NUM_FIELDS(MYSQL_RES *);
T_MYSQL_NUM_FIELDS *p_mysql_num_fields;
typedef my_ulonglong STDCALL T_MYSQL_NUM_ROWS(MYSQL_RES *);
T_MYSQL_NUM_ROWS *p_mysql_num_rows;
typedef MYSQL * STDCALL T_MYSQL_REAL_CONNECT(MYSQL *,const char *,const char *,const char *,const char *,unsigned int,const char *,unsigned long);
T_MYSQL_REAL_CONNECT *p_mysql_real_connect;
typedef int STDCALL T_MYSQL_REAL_QUERY(MYSQL *,const char *,unsigned long);
T_MYSQL_REAL_QUERY *p_mysql_real_query;
typedef int STDCALL T_MYSQL_SELECT_DB(MYSQL *,const char *);
T_MYSQL_SELECT_DB *p_mysql_select_db;
typedef MYSQL_RES * STDCALL T_MYSQL_STORE_RESULT(MYSQL *);
T_MYSQL_STORE_RESULT *p_mysql_store_result;
typedef void STDCALL T_MYSQL_THREAD_END(void);
T_MYSQL_THREAD_END *p_mysql_thread_end;
typedef unsigned int STDCALL T_MYSQL_THREAD_SAFE(void);
T_MYSQL_THREAD_SAFE *p_mysql_thread_safe;

# define MYSQL_AFFECTED_ROWS ((*p_mysql_affected_rows))
# define MYSQL_CLOSE ((*p_mysql_close))
# define MYSQL_ERROR ((*p_mysql_error))
# define MYSQL_FETCH_FIELD ((*p_mysql_fetch_field))
# define MYSQL_FETCH_ROW ((*p_mysql_fetch_row))
# define MYSQL_FIELD_COUNT ((*p_mysql_field_count))
# define MYSQL_FIELD_SEEK ((*p_mysql_field_seek))
# define MYSQL_FREE_RESULT ((*p_mysql_free_result))
# define MYSQL_GET_SERVER_INFO ((*p_mysql_get_server_info))
# define MYSQL_INIT ((*p_mysql_init))
# define MYSQL_INSERT_ID ((*p_mysql_insert_id))
# define MYSQL_NUM_FIELDS ((*p_mysql_num_fields))
# define MYSQL_NUM_ROWS ((*p_mysql_num_rows))
# define MYSQL_REAL_CONNECT ((*p_mysql_real_connect))
# define MYSQL_REAL_QUERY ((*p_mysql_real_query))
# define MYSQL_SELECT_DB ((*p_mysql_select_db))
# define MYSQL_STORE_RESULT ((*p_mysql_store_result))
# define MYSQL_THREAD_END ((*p_mysql_thread_end))
# define MYSQL_THREAD_SAFE ((*p_mysql_thread_safe))
#else
# define MYSQL_AFFECTED_ROWS mysql_affected_rows
# define MYSQL_CLOSE mysql_close
# define MYSQL_ERROR mysql_error
# define MYSQL_FETCH_FIELD mysql_fetch_field
# define MYSQL_FETCH_ROW mysql_fetch_row
# define MYSQL_FIELD_COUNT mysql_field_count
# define MYSQL_FIELD_SEEK mysql_field_seek
# define MYSQL_FREE_RESULT mysql_free_result
# define MYSQL_GET_SERVER_INFO mysql_get_server_info
# define MYSQL_INIT mysql_init
# define MYSQL_INSERT_ID mysql_insert_id
# define MYSQL_NUM_FIELDS mysql_num_fields
# define MYSQL_NUM_ROWS mysql_num_rows
# define MYSQL_REAL_CONNECT mysql_real_connect
# define MYSQL_REAL_QUERY mysql_real_query
# define MYSQL_SELECT_DB mysql_select_db
# define MYSQL_STORE_RESULT mysql_store_result
# define MYSQL_THREAD_END mysql_thread_end
# define MYSQL_THREAD_SAFE mysql_thread_safe
#endif

#ifdef WIN32
void RexxSQLLoadMySQL()
{
   char LoadError[256];
   if ( handle == NULL )
   {
      handle = LoadLibrary( "libmysql" ) ;
      if ( handle == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to load external library \"%s\": LoadLibrary() failed: ", "libmysql" );
         exit(1);
      }

      p_mysql_affected_rows = (T_MYSQL_AFFECTED_ROWS *)GetProcAddress( (HMODULE)handle, "mysql_affected_rows" );
      if ( p_mysql_affected_rows == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: %s", "mysql_affected_rows", LoadError );
         exit(1);
      }
      p_mysql_close = (T_MYSQL_CLOSE *)GetProcAddress( (HMODULE)handle, "mysql_close" );
      if ( p_mysql_close == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_close" );
         exit(1);
      }
      p_mysql_error = (T_MYSQL_ERROR *)GetProcAddress( (HMODULE)handle, "mysql_error" );
      if ( p_mysql_error == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_error" );
         exit(1);
      }
      p_mysql_fetch_field = (T_MYSQL_FETCH_FIELD *)GetProcAddress( (HMODULE)handle, "mysql_fetch_field" );
      if ( p_mysql_fetch_field == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_fetch_field" );
         exit(1);
      }
      p_mysql_fetch_row = (T_MYSQL_FETCH_ROW *)GetProcAddress( (HMODULE)handle, "mysql_fetch_row" );
      if ( p_mysql_fetch_row == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_fetch_row" );
         exit(1);
      }
      p_mysql_field_count = (T_MYSQL_FIELD_COUNT *)GetProcAddress( (HMODULE)handle, "mysql_field_count" );
      if ( p_mysql_field_count == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_field_count" );
         exit(1);
      }
      p_mysql_field_seek = (T_MYSQL_FIELD_SEEK *)GetProcAddress( (HMODULE)handle, "mysql_field_seek" );
      if ( p_mysql_field_seek == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_field_seek" );
         exit(1);
      }
      p_mysql_free_result = (T_MYSQL_FREE_RESULT *)GetProcAddress( (HMODULE)handle, "mysql_free_result" );
      if ( p_mysql_free_result == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_free_result" );
         exit(1);
      }
      p_mysql_get_server_info = (T_MYSQL_GET_SERVER_INFO *)GetProcAddress( (HMODULE)handle, "mysql_get_server_info" );
      if ( p_mysql_get_server_info == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_get_server_info" );
         exit(1);
      }
      p_mysql_init = (T_MYSQL_INIT *)GetProcAddress( (HMODULE)handle, "mysql_init" );
      if ( p_mysql_init == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_init" );
         exit(1);
      }
      p_mysql_insert_id = (T_MYSQL_INSERT_ID *)GetProcAddress( (HMODULE)handle, "mysql_insert_id" );
      if ( p_mysql_insert_id == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_insert_id" );
         exit(1);
      }
      p_mysql_num_fields = (T_MYSQL_NUM_FIELDS *)GetProcAddress( (HMODULE)handle, "mysql_num_fields" );
      if ( p_mysql_num_fields == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_num_fields" );
         exit(1);
      }
      p_mysql_num_rows = (T_MYSQL_NUM_ROWS *)GetProcAddress( (HMODULE)handle, "mysql_num_rows" );
      if ( p_mysql_num_rows == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_num_rows" );
         exit(1);
      }
      p_mysql_real_connect = (T_MYSQL_REAL_CONNECT *)GetProcAddress( (HMODULE)handle, "mysql_real_connect" );
      if ( p_mysql_real_connect == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_real_connect" );
         exit(1);
      }
      p_mysql_real_query = (T_MYSQL_REAL_QUERY *)GetProcAddress( (HMODULE)handle, "mysql_real_query" );
      if ( p_mysql_real_query == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_real_query" );
         exit(1);
      }
      p_mysql_select_db = (T_MYSQL_SELECT_DB *)GetProcAddress( (HMODULE)handle, "mysql_select_db" );
      if ( p_mysql_select_db == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_select_db" );
         exit(1);
      }
      p_mysql_store_result = (T_MYSQL_STORE_RESULT *)GetProcAddress( (HMODULE)handle, "mysql_store_result" );
      if ( p_mysql_store_result == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_store_result" );
         exit(1);
      }
      p_mysql_thread_end = (T_MYSQL_THREAD_END *)GetProcAddress( (HMODULE)handle, "mysql_thread_end" );
      if ( p_mysql_thread_end == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_thread_end" );
         exit(1);
      }
      p_mysql_thread_safe = (T_MYSQL_THREAD_SAFE *)GetProcAddress( (HMODULE)handle, "mysql_thread_safe" );
      if ( p_mysql_thread_safe == NULL )
      {
         FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastError(), MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT), LoadError, 256, NULL );
         fprintf( stderr, "Failed to find \"%s\" in external library: GetProcAddress() failed: ", "mysql_thread_safe" );
         exit(1);
      }
   }
}

void RexxSQLUnloadMySQL(void)
{
   if ( handle )
      FreeLibrary( handle );
}
#endif


/* ---------------------------------------------------------------------
 * Error value returned for errors returned by mySQL as opposed to
 * those generated by the interface.
 */
#define DB_ERROR  (-1L)

/*
 * #define extra database-specific entry points and function declarations just
 * before #include "rxsqlinc1.h"
 */
#define INCLUDE_MYGETINSERTID_FUNC
RexxFunctionHandler RexxMYGetInsertId;
#include "rxsqlinc1.h"

/*-----------------------------------------------------------------------------
 * Fetch the DB error and put into REXX "SQLCA." compound variable.
 *----------------------------------------------------------------------------*/
static void SetDBError( RxPackageGlobalDataDef *RxPackageGlobalData, char *fn, int lineno, SQLWA *swa, MYSQL *mysql )
{
   char    *txt=NULL;

   InternalTrace( RxPackageGlobalData, "SetDBError", "%s,%d,%x,%x", fn, lineno, swa, mysql );

   /* Get the statement text */
   txt = (swa == (SQLWA*)NULL) ? "" : (swa->saved_stmt.sql_stmt) ? swa->saved_stmt.sql_stmt : "";

   /* Set SQLCA. variable */
   SetSQLCA( RxPackageGlobalData, (-1), "ZZZZZ", (char *)MYSQL_ERROR(mysql), txt );

   return;
}

static void SetDBWarning( RxPackageGlobalDataDef *RxPackageGlobalData, char *fn, int lineno, SQLWA *swa, MYSQL *mysql )
{
   char    *txt=NULL;

   InternalTrace( RxPackageGlobalData, "SetDBWarning", "%s,%d,%x,%x", fn, lineno, swa, mysql );

   /* Get the statement text */
   txt = (swa == (SQLWA*)NULL) ? "" : (swa->saved_stmt.sql_stmt) ? swa->saved_stmt.sql_stmt : "";

   /* Set SQLCA. variable */
   SetSQLCA( RxPackageGlobalData, (1), "ZZZZZ", (char *)MYSQL_ERROR(mysql), txt );

   return;
}

/*-----------------------------------------------------------------------------
 * Allocate a DBENV object. Only one database environment is allocated.
 * This structure is allocated when the first connection is made and deallocated
 * when the last connection is released.
 * Note that statement names are global and hence are defined in this structure
 * and not in the connection structure as would be the case if they were unique
 * to a connection!
 *----------------------------------------------------------------------------*/
static DBENV *AllocDbEnvironment( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   DBENV  *dbenv=NULL;
   int    i=0;

   InternalTrace( RxPackageGlobalData, "AllocateDbEnvironment", NULL );

   if ( ( dbenv = (DBENV*)MALLOC_TSD( RxPackageGlobalData, sizeof(DBENV) ) ) == (DBENV*)NULL )
      return (DBENV*)NULL;
   dbenv->num_connections = 0;
   dbenv->current_connection = (DBCON*)NULL;
   for (i = 0; i < TBL_CONNECTIONS; i++)
      dbenv->db_tbl[i] = (BUCKET*)NULL;
   for (i = 0; i < TBL_STATEMENTS; i++)
      dbenv->stmt_tbl[i] = (BUCKET*)NULL;
   return dbenv;
}

/*-----------------------------------------------------------------------------
 * Allocate a DBCON object. One of these is required for each database
 * connection. This structure is allocated when the connection is made and
 * deallocated when the connection is released.
 *----------------------------------------------------------------------------*/
static DBCON *AllocConnection( RxPackageGlobalDataDef *RxPackageGlobalData, char *name )
{
   DBCON  *db=NULL;

   InternalTrace( RxPackageGlobalData, "AllocConnection", "%s", name );

   if ( ( db = (DBCON*)NewObject( RxPackageGlobalData, sizeof(DBCON) ) ) == (DBCON*)NULL )
       return (DBCON*)NULL;
   (void)strncpy(db->name, name, MAX_IDENTIFIER);
   db->dflt_stmt = (void*)NULL;
   db->db_opt = (SQLVAL*)NULL;
   db->num_statements = 0;
   return db;
}

/*-----------------------------------------------------------------------------
 * Open a database connection. This requires allocating a connection object
 * and making the connection to mySQL.
 *----------------------------------------------------------------------------*/
static int OpenConnection(RxPackageGlobalDataDef *RxPackageGlobalData, PSZ cnctname, PSZ host, PSZ dbName, PSZ username, PSZ password, DBCON **new_db)
{
   DBCON   *db=NULL;
   int     rc=0,i=0;
   void    *result=NULL;
   SQLVAL  *curr=NULL;

   InternalTrace( RxPackageGlobalData, "OpenConnection", "%s,%s,%s,%s,%s", cnctname, host, dbName, username, password );

   if ( ( db = AllocConnection( RxPackageGlobalData, cnctname ) ) == (DBCON*)NULL )
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));

#if MYSQL_VERSION_ID >= 32200
   if ( MYSQL_INIT( &(db->mysql) ) == NULL )
   {
      FreeObject( RxPackageGlobalData, db );
      return( SetIntError( RxPackageGlobalData,  __FILE__, __LINE__, 10, "out of memory" ));
   }
   if ( MYSQL_REAL_CONNECT( &(db->mysql), host, username, password, dbName, 0, NULL, 0 ) == NULL )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, (SQLWA*)NULL, &(db->mysql) );
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }
#else
   if ( MYSQL_REAL_CONNECT( &(db->mysql), host, username, password, 0, NULL, 0 ) == NULL )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, (SQLWA*)NULL, &(db->mysql) );
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }
   if ( MYSQL_SELECT_DB( &(db->mysql),dbName) )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, (SQLWA*)NULL, &db->mysql );
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }
#endif

   /*
    * Setup any connection-specific variable information
    */
   for ( i = 0; strlen(sqlgetinfo_vars[i].name) != 0; i++ )
   {
      if ( sqlgetinfo_vars[i].value )
         result = sqlgetinfo_vars[i].value;
      else
         result = GetSqlVariableValue( RxPackageGlobalData, sqlgetinfo_vars[i].valtype, (void*)db );
      if ((curr = InstallSQLVariable(RxPackageGlobalData,
                &rc,
                sqlgetinfo_vars[i].name,
                db->db_opt,
                sqlgetinfo_vars[i].user_update,
                sqlgetinfo_vars[i].dtype,
                sqlgetinfo_vars[i].option,
                result,
                sqlgetinfo_vars[i].valtype)) == NULL)
      {
         return(rc);
      }
      if ( db->db_opt == NULL )
         db->db_opt = curr;
   }
   if ( dbName )
      strcpy( db->dbName, dbName );
   *new_db = db;
   InternalTrace( RxPackageGlobalData, "OpenConnection leaving", "%x", db );
   return 0;
}

/*-----------------------------------------------------------------------------
 * Allocate a STMT object. One of these is required for each statement
 * including the default statement for a connection. An instance of this object
 * is allocated when (i) a statement is prepared & (ii) the first time
 * SQLCOMMAND() is called for a connection (ie. the default statement is used).
 *----------------------------------------------------------------------------*/
static STMT *AllocStatement( RxPackageGlobalDataDef *RxPackageGlobalData, char *name, DBCON *db)
{
   STMT    *stmt=NULL;
   SQLWA   *swa=NULL;
   int      i=0;

   InternalTrace( RxPackageGlobalData, "AllocateStatement", "%s,%x", name, db );

   if ( ( stmt = (STMT*)NewObject( RxPackageGlobalData, sizeof(STMT) ) ) == (STMT*)NULL )
      return (STMT*)NULL;
   stmt->db = db;
   (void)strncpy( stmt->name, name, MAX_IDENTIFIER );

   /* Initialise SQL Work Area */
   swa = SWA(stmt);
   swa->expr_cnt = 0;
   memset( &(swa->saved_stmt), 0, sizeof(SAVEDSQLSTMT) );

   /* Set pointer for each column descriptor to NULL (unused) */
   for (i = 0; i < MAX_COLS; i++)
      swa->fa[i] = (FLDDSCR*)NULL;

   return stmt;
}

/*-----------------------------------------------------------------------------
 * Open a statement. This allocates a statement.
 *----------------------------------------------------------------------------*/
static int OpenStatement( RxPackageGlobalDataDef *RxPackageGlobalData, char *name, DBCON *db, STMT **new_stmt)
{
 int      rc=0;
 STMT    *stmt=NULL;

 InternalTrace( RxPackageGlobalData, "OpenStatement", "%s,%x,%x", name, db, new_stmt );

 if ( ( stmt = AllocStatement( RxPackageGlobalData, name, db ) ) == (STMT*)NULL )
     return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));

 *new_stmt = stmt;
 return (rc==0) ? 0 : DB_ERROR;
}

/*-----------------------------------------------------------------------------
 * Disposes a SQL statement. This closes the mySQL cursor and frees the
 * statement structure and all resources associated with it.
 *----------------------------------------------------------------------------*/
static int ReleaseStatement( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt )
{
   SQLWA    *swa = SWA(stmt);
   int       rc=0;

   InternalTrace( RxPackageGlobalData, "ReleaseStatement", "%x", stmt );

   /* Close mySQL cursor */
   if ( CTX(swa) )
   {
      MYSQL_FREE_RESULT( CTX(swa) );
      CTX(swa) = NULL;
   }

   /* Free sql statement buffer (if any) */
   if ( swa->saved_stmt.sql_stmt )
   {
      FREE_TSD( RxPackageGlobalData, swa->saved_stmt.sql_stmt );
      memset( &(swa->saved_stmt), 0, sizeof(SAVEDSQLSTMT) );
   }

   FreeObject( RxPackageGlobalData, stmt );

   return (rc==0) ? 0 : DB_ERROR;
}

/*-----------------------------------------------------------------------------
 * Release an mySQL connection. This closes any open statements associated
 * with the connection, closes the connection and frees all resources
 * associated with it.
 *----------------------------------------------------------------------------*/
static int ReleaseConnection(RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db)
{
   int    i=0, rc=0, last_error=0;
   STMT   *stmt=NULL, *t=NULL;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "ReleaseConnection", "%x", db );

   /*
    * Remove the Connection structure from the hash structures etc.
    */
   (void)RemoveObject( RxPackageGlobalData, db );

   /*
    * Decrement the count of active connections.
    */
   RexxSQLData->DbEnv->num_connections--;

   /*
    * Dispose all active statements for this connection.
    */
   for ( i = 0; db->num_statements && i < TBL_STATEMENTS; i++ )
   {
      stmt = (STMT*)FirstObject( RxPackageGlobalData, i, RexxSQLData->DbEnv->stmt_tbl );
      while( stmt && db->num_statements )
      {
         t = (STMT*)NextObject( RxPackageGlobalData, stmt );
         if ( stmt->db == db )
         {
            RemoveObject( RxPackageGlobalData, stmt );
            last_error = (rc = ReleaseStatement( RxPackageGlobalData, stmt )) ? rc : last_error;
            db->num_statements--;
         }
         stmt = t;
      }
   }

   /*
    * Dispose all informational data for this connection.
    */
   if ( db->db_opt )
      db->db_opt = ll_free( RxPackageGlobalData, db->db_opt );

   /*
    * Dispose the default statement (if any).
    */
   if (db->dflt_stmt)
       last_error = (rc = ReleaseStatement( RxPackageGlobalData, (STMT*)(db->dflt_stmt) ))
                      ? rc : last_error;

   /*
    * Disconnect from mySQL
    */
   MYSQL_CLOSE( &db->mysql );

   /*
    * Free the connection structure
    */
   FreeObject( RxPackageGlobalData, db );

   return (last_error);
}

/*-----------------------------------------------------------------------------
 * Release the mySQL environment. This releases all active connections
 * (if any).
 *----------------------------------------------------------------------------*/
int ReleaseDbEnvironment(RxPackageGlobalDataDef *RxPackageGlobalData)
{
   int    i=0, rc=0, last_error=0;
   DBCON  *db=NULL, *t=NULL;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "ReleaseDbEnvironment", NULL );

   /* Ensure there is an environment to release! */
   if ( RexxSQLData->DbEnv == (DBENV*)NULL )
      return 0;

   /* Release all connections. */
   for ( i = 0; RexxSQLData->DbEnv->num_connections && i < TBL_CONNECTIONS; i++ )
   {
      db = (DBCON*)FirstObject( RxPackageGlobalData, i, RexxSQLData->DbEnv->db_tbl );
      while( db && RexxSQLData->DbEnv->num_connections )
      {
         t = (DBCON*)NextObject( RxPackageGlobalData, db );
         last_error = (rc = ReleaseConnection( RxPackageGlobalData, db )) ? rc : last_error;
         db = t;
      }
   }

   /* Free the DB environment */
   FREE_TSD( RxPackageGlobalData, RexxSQLData->DbEnv );
   RexxSQLData->DbEnv = (DBENV*)NULL;

   return (last_error);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS : SQLCONNECT( [connection-name] [,username] [,password] [,database name] [,host name])
 *
 * ARGUMENTS:
 *            0 - connection_name (optional)
 *            1 - username (optional)
 *            2 - password (optional)
 *            3 - database name (optional)
 *            4 - host name (optional)
 *
 * RETURNS  : 0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLCONNECT )
{
   char *host=NULL;
   char *dbName=NULL;
   char *username=NULL;
   char *password=NULL;
   char cnctname[MAX_IDENTIFIER+1];
   int  rc=0;
   char tmp[128];
   DBCON *db=NULL;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 5 ) )
      return 1;

   /*
    * Allocate a DB environment if none exists!
    */
   if ( RexxSQLData->DbEnv == (DBENV*)NULL )
   {
      if ( ( RexxSQLData->DbEnv = AllocDbEnvironment( RxPackageGlobalData ) ) == (DBENV*)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory." );
   }
   /*
    * Get username parameter
    */
   if ( RXSTRLEN(argv[1]) )
   {
      if ( ( username = (char *)MALLOC_TSD( RxPackageGlobalData, 1+RXSTRLEN(argv[1]) ) ) == NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory." );
      MkAsciz( RxPackageGlobalData, username, RXSTRLEN(argv[1])+1, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );
   }
   /*
    * Get password parameter
    */
   if ( RXSTRLEN(argv[2]) )
   {
      if ( ( password = (char *)MALLOC_TSD( RxPackageGlobalData, 1+RXSTRLEN(argv[2]) ) ) == NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory." );
      MkAsciz( RxPackageGlobalData, password, RXSTRLEN(argv[2])+1, RXSTRPTR(argv[2]), RXSTRLEN(argv[2]) );
   }
   /*
    * Get database name parameter
    */
   if ( RXSTRLEN(argv[3]) )
   {
      if ( ( dbName = (char *)MALLOC_TSD( RxPackageGlobalData, 1+RXSTRLEN(argv[3])) ) == NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory.");
      MkAsciz( RxPackageGlobalData, dbName, RXSTRLEN(argv[3])+1, RXSTRPTR(argv[3]), RXSTRLEN(argv[3]) );
   }
   /*
    * If a host name is specified, use it.
    */
   if ( argc == 5
   &&   RXSTRLEN(argv[4]) )
   {
      if ( ( host = (char *)MALLOC_TSD( RxPackageGlobalData, 1+RXSTRLEN(argv[4]) ) ) == NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory.");
      MkAsciz( RxPackageGlobalData, host, RXSTRLEN(argv[4])+1, RXSTRPTR(argv[4]), RXSTRLEN(argv[4]) );
   }

   /*
    * If a name is given it is the first argument!/
    * Get the name of the connection (default if not specified).
    */
   if ( RXSTRLEN(argv[0]) )
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], cnctname, sizeof(cnctname) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );
   }
   else
   {
      (void)strcpy( cnctname, DEFAULT_CONNECTION );
   }

   /* Make sure there is no existing connection with the same name */
   if ( FindObject( RxPackageGlobalData, cnctname, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS ) )
   {
      (void)sprintf( tmp, "connection already open with name \"%s\".", cnctname );
      return ReturnError( RxPackageGlobalData, retstr, 20, tmp );
   }

   /* Open a new connection for the given connect string. */
   if ( ( rc = OpenConnection( RxPackageGlobalData, cnctname, host, dbName, username, password, &db ) ) != 0 )
   {
      if ( dbName ) FREE_TSD( RxPackageGlobalData, dbName );
      if ( host ) FREE_TSD( RxPackageGlobalData, host );
      if ( username ) FREE_TSD( RxPackageGlobalData, username );
      if ( password ) FREE_TSD( RxPackageGlobalData, password );
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   }
   if ( dbName ) FREE_TSD( RxPackageGlobalData, dbName );
   if ( host ) FREE_TSD( RxPackageGlobalData, host );
   if ( username ) FREE_TSD( RxPackageGlobalData, username );
   if ( password ) FREE_TSD( RxPackageGlobalData, password );

   RexxSQLData->DbEnv->num_connections++;
   RexxSQLData->DbEnv->current_connection = db;
   (void)InsertObject( RxPackageGlobalData, db, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS );
   /*
    * Set AUTOCOMMIT = 0 (turn it off) by default
    */
   if ( ( rc = MYSQL_REAL_QUERY( &db->mysql, "SET AUTOCOMMIT=0", 16 ) != 0 ) )
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, (SQLWA*)NULL, &db->mysql );
   else
      RexxSQLData->AutoCommit = 0;
   return RxReturnNumber( RxPackageGlobalData, retstr, 0L);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDISCONNECT( [connection-name ] )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLDISCONNECT )
{
   int     rc = 0;
   char        dbname[MAX_IDENTIFIER+1];
   DBCON       *db=NULL;
   char        tmp[128];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 1 ) )
      return 1;

   if ( RexxSQLData->DbEnv == (DBENV*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, 0L );

   if ( argc && RXSTRLEN(argv[0]) )
   {
      /* A connection has been named */
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], dbname, sizeof(dbname) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );

      /* Make sure the named connection exists. */
      if ( ( db = FindObject(RxPackageGlobalData , dbname, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS ) )  == (DBCON*)NULL )
      {
         (void)sprintf( tmp, "connection \"%s\" is not open.", dbname );
         return ReturnError( RxPackageGlobalData, retstr, 21, tmp );
      }
   }
   else
   {
      if ( RexxSQLData->DbEnv->current_connection )
         db = RexxSQLData->DbEnv->current_connection;
      else
         return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );
   }

   /*
    * If terminating the current connection then make it so there is
    * no current connection!
    */
   if ( db == RexxSQLData->DbEnv->current_connection )
      RexxSQLData->DbEnv->current_connection = (DBCON*)NULL;

   /* Do the disconnection */
   rc = ReleaseConnection( RxPackageGlobalData, db );

   /* Free the environment if zero connections remaining */
   if ( RexxSQLData->DbEnv->num_connections == 0 )
   {
      FREE_TSD( RxPackageGlobalData, RexxSQLData->DbEnv );
      RexxSQLData->DbEnv = (DBENV*)NULL;
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDEFAULT( [connection-name ] )
 *
 * RETURNS :  When called with 0 args : 0-success, <0-error.
 *         :  When called with 1 arg  : Name of current connection else "".
 *----------------------------------------------------------------------------*/
rxfunc( SQLDEFAULT )
{
   char        dbname[MAX_IDENTIFIER+1];
   DBCON       *db=NULL;
   char        tmp[128];
   int rc=0;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 1 ) )
      return 1;

   if ( argc && RXSTRLEN(argv[0]) )
   {
      /* Get the normalised name of the connection. */
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], dbname, sizeof(dbname) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );

      /* Make sure we have an environment! */
      if ( RexxSQLData->DbEnv == (DBENV*)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

      /* Make sure the Connection Name is a valid one! */
      if ( ( db = FindObject( RxPackageGlobalData, dbname, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS ) ) == (DBCON*)NULL )
      {
         (void)sprintf( tmp, "connection \"%s\" is not open.", dbname );
         return ReturnError( RxPackageGlobalData, retstr, 21, tmp );
      }

      /* Make connection the default one! */
      RexxSQLData->DbEnv->current_connection = db;
      if ( ( rc = MYSQL_SELECT_DB( &db->mysql, db->dbName ) ) == DB_ERROR )
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, db->dflt_stmt, &db->mysql );

      return RxReturnNumber( RxPackageGlobalData, retstr, (rc==0)?0:DB_ERROR );
   }
   else
   {
      if ( RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection )
      {
         return RxReturnString( RxPackageGlobalData, retstr, RexxSQLData->DbEnv->current_connection->name );
      }
      else
      {
         return RxReturnString( RxPackageGlobalData, retstr, "" );
      }
   }
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  Called by SQLCOMMIT( ) &  SQLROLLBACK( )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
APIRET APIENTRY SQLTRANSACT( RFH_ARG0_TYPE name, RFH_ARG1_TYPE argc, RFH_ARG2_TYPE argv, RFH_ARG3_TYPE stck, RFH_ARG4_TYPE retstr, int commit )
{
   int     rc = 0;
   DBCON   *db=NULL;
   char    *trans_cmd;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 1 ) )
      return 1;

   if ( RexxSQLData->DbEnv == (DBENV*)NULL )
      return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

   if ( RexxSQLData->DbEnv->current_connection )
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current");

   if ( commit )
      trans_cmd = "COMMIT";
   else
      trans_cmd = "ROLLBACK";
   rc = MYSQL_REAL_QUERY( &db->mysql, trans_cmd, strlen( trans_cmd ) );
   if ( rc != 0 )
   {
      char *err = (char *)MYSQL_ERROR( &db->mysql );
      if ( err
      &&   strlen( err ) > 8
      &&   memcmp( err, "Warning:", 8 ) == 0 )
      {
         rc = DB_WARNING;
         SetDBWarning( RxPackageGlobalData, __FILE__, __LINE__, (SQLWA*)NULL, &db->mysql );
      }
      else
      {
         rc = DB_ERROR;
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, (SQLWA*)NULL, &db->mysql );
      }
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, rc);
}

/*-----------------------------------------------------------------------------
 * Describes columns (expressions) and defines the output buffers for each
 * column for the select statement in nominated cursor.
 * Returns the number of expressions in the select statement.
 *----------------------------------------------------------------------------*/
static int DefineExpressions( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt )
{
   SQLWA    *swa= SWA(stmt);
   FLDDSCR  *fd=NULL;
   int      i=0;
   char     tmp[128];
   DBCON    *db=stmt->db;

   InternalTrace( RxPackageGlobalData, "DefineExpressions", "%x", stmt );

   if ( !CTX(swa) )
   {
      (void)sprintf( tmp, "statement \"%s\" has not been OPENed or EXECUTEd", stmt->name );
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 26, tmp ));
   }

#if MYSQL_VERSION_ID >= 32224
   swa->expr_cnt = MYSQL_FIELD_COUNT( &db->mysql );
#else
   swa->expr_cnt = MYSQL_NUM_FIELDS( &db->mysql );
#endif

   MYSQL_FIELD_SEEK( CTX(swa), 0 );
   /* Describe & define buffer for each expression in the SELECT statement */
   DEBUGDUMP(fprintf(stderr,"%s-%d: number columns in statement: %d\n", __FILE__,__LINE__,swa->expr_cnt);)
   for (i = 0; i < swa->expr_cnt ; i++)
   {
      /* Get a new field descriptor */
      swa->fa[i] = fd = MYSQL_FETCH_FIELD( CTX(swa) );
      (void)make_upper( RxPackageGlobalData, fd->name );
      DEBUGDUMP(fprintf(stderr,"%s-%d: fetched column name: %s\n", __FILE__,__LINE__,fd->name);)
   }

   return (swa->expr_cnt);
}

/*-----------------------------------------------------------------------------
 * Fetches the next row from the nominated cursor and returns the values
 * of the expressions for the fetched row into the compound variable with
 * name constructed as follows:
 *
 * For single fetches. eg. SQLFETCH('s1')
 *                     or  SQLFETCH('s1','') :
 *  <statement-name>.<column-name>
 *
 * For bulk fetches. eg. SQLCOMMAND(stmt1)
 *                   or  SQLFETCH('s1',0)
 *                   or  SQLFETCH('s1',1)
 *                   or  SQLFETCH('s1',20) :
 *  <statement-name>.<column-name>.<row-number>
 *
 * Note that the row-number always starts at 1!
 *
 * Returns:
 * success:  0
 * failure: MYSQL return code
 *----------------------------------------------------------------------------*/
static int FetchRow( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt, char *stem, RXSQL_ROWCOUNT_TYPE rowcount )
{
   SQLWA   *swa=NULL;
   FLDDSCR *fd=NULL;
   int     rc=0, i=0;
   size_t  varlen=0;
   char    varname[MAX_IDENTIFIER+1+10];
   char    tmp[128];
   MYSQL_ROW   row;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "FetchRow", "%x,%s,%ld", stmt, stem, rowcount );

   swa = SWA(stmt);
   if ( !CTX(swa) )
   {
      (void)sprintf( tmp, "statement \"%s\" has not been OPENed or EXECUTEd", stmt->name );
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 26, tmp ) );
   }

   row = MYSQL_FETCH_ROW( CTX(swa) );
   if ( row == NULL )
      return (1);

   /* Get each expr value in turn */
   for (i = 0; rc == 0 && i < swa->expr_cnt; i++)
   {
      fd = swa->fa[i];

      /* Add each column value to the stem's values */
      if ( rowcount )
         varlen = sprintf( varname, "%s.%s.%lu", stem, fd->name, rowcount );
      else
         varlen = sprintf( varname, "%s.%s",  stem, fd->name );

      if ( row[i] )  /* returned value is not NULL */
      {
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, row[i], strlen( row[i] ) );
      }
      else
      {
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, RexxSQLData->RXSNullStringOut.strptr, RexxSQLData->RXSNullStringOut.strlength );
      }
   }
   if (rc)
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 16, "unable to set REXX variable" ) );
   return rc;
}

/*-----------------------------------------------------------------------------
 * Fetches the next row from a result set
 *
 * Returns:
 * success:  0
 * failure: MYSQL return code
 *----------------------------------------------------------------------------*/
static int FetchInfoRow( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db, STMT *stmt, char *stem, RXSQL_ROWCOUNT_TYPE rowcount, int type, char *tablename )
{
   SQLWA   *swa=NULL;
   FLDDSCR *fd=NULL;
   int     rc=0, i,j;
   size_t  varlen=0,fd_valuelen;
   char    varname[MAX_IDENTIFIER+1+10];
   char    tmp[128];
   char    *fd_name,fd_size[20],*fd_precision,*fd_scale;
   char    *fd_value;
   MYSQL_ROW   row;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "FetchInfoRow", "%x,%s,%ld,%d", stmt, stem, rowcount, type );

   swa = SWA(stmt);
   if ( !CTX(swa) )
   {
      (void)sprintf( tmp, "statement \"%s\" has not been OPENed or EXECUTEd", stmt->name );
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 26, tmp ) );
   }

   row = MYSQL_FETCH_ROW( CTX(swa) );
   if ( row == NULL )
      return (1);

   /* Get each expr value in turn */
   for (i = 0; rc == 0 && i < swa->expr_cnt; i++)
   {
      fd = swa->fa[i];
      fd_value = row[i];
      if ( fd_value )
         fd_valuelen = strlen( fd_value );
      /*
       * Switch fd->name depending on type
       */
      switch ( type )
      {
         case MY_INFO_DATASOURCES:
            fd_name = "DSN_NAME";
            break;
         case MY_INFO_TABLES:
            fd_name = "TABLE_NAME";
            break;
         case MY_INFO_COLUMNS:
            switch(i)
            {
               case 0:
                  fd_name = "COLUMN_NAME";
                  break;
               case 1:
                  fd_name = "COLUMN_TYPE";
                  if ( strcmp( fd_value, "date" ) == 0 )
                  {
                     fd_precision = "10";
                     fd_scale = "0";
                  }
                  else
                  {
                     int vl = fd_valuelen;
                     fd_precision = "0";
                     fd_scale = "0";
                     for ( j = 0; j < vl; j++ )
                     {
                        if ( fd_value[j] == '(' )
                        {
                           fd_value[j] = '\0';
                           fd_precision = fd_value+(j+1);
                           fd_valuelen = j+1;
                        }
                        else if ( fd_value[j] == ',' )
                        {
                           fd_value[j] = '\0';
                           fd_scale = fd_value+(j+1);
                        }
                        else if ( fd_value[j] == ')' )
                        {
                           fd_value[j] = '\0';
                        }
                     }
                  }
                  sprintf( fd_size, "%d", atoi(fd_precision)+atoi(fd_scale) );
                  break;
               case 2:
                  fd_name = "COLUMN_NULLABLE";
                  if ( fd_value )
                  {
                     if ( strcmp( fd_value, "YES" ) == 0 )
                        fd_value = "1";
                     else
                        fd_value = "0";
                  }
                  else
                  {
                     fd_value = "0";
                  }
                  break;
               case 5:
                  fd_name = "COLUMN_DESCRIPTION";
                  break;
               default:
                  fd_name = NULL;
                  break;
            }
            break;
         default:
            break;
      }
      if ( fd_name )
      {
         /* Add each column value to the stem's values */
         varlen = sprintf( varname, "%s.%s.%lu", stem, fd_name, rowcount );

         if ( fd_value )  /* returned value is not NULL */
         {
            rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, fd_value, fd_valuelen );
         }
         else
         {
            rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, RexxSQLData->RXSNullStringOut.strptr, RexxSQLData->RXSNullStringOut.strlength );
         }
      }
   }
   if (rc)
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 16, "unable to set REXX variable" ) );
   /*
    * Add any extra columns
    */
   switch( type )
   {
      case MY_INFO_DATASOURCES:
         varlen = sprintf( varname, "%s.%s.%lu", stem, "DSN_DESCRIPTION", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, "", 0 );
        break;
      case MY_INFO_TABLES:
         varlen = sprintf( varname, "%s.%s.%lu", stem, "TABLE_CATALOG", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, db->dbName, strlen( db->dbName) );
         varlen = sprintf( varname, "%s.%s.%lu", stem, "TABLE_OWNER", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, "", 0 );
         varlen = sprintf( varname, "%s.%s.%lu", stem, "TABLE_TYPE", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, "TABLE", 5 );
         varlen = sprintf( varname, "%s.%s.%lu", stem, "TABLE_DESCRIPTION", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, "", 0 );
        break;
      case MY_INFO_COLUMNS:
         varlen = sprintf( varname, "%s.%s.%lu", stem, "TABLE_CATALOG", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, db->dbName, strlen( db->dbName) );
         varlen = sprintf( varname, "%s.%s.%lu", stem, "TABLE_OWNER", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, "", 0 );
         varlen = sprintf( varname, "%s.%s.%lu", stem, "TABLE_NAME", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, tablename, strlen(tablename) );
         varlen = sprintf( varname, "%s.%s.%lu", stem, "COLUMN_SIZE", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, fd_size, strlen(fd_size) );
         varlen = sprintf( varname, "%s.%s.%lu", stem, "COLUMN_PRECISION", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, fd_precision, strlen(fd_precision) );
         varlen = sprintf( varname, "%s.%s.%lu", stem, "COLUMN_SCALE", rowcount );
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, fd_scale, strlen(fd_precision) );
         break;
   }
   return rc;
}

/*-----------------------------------------------------------------------------
 *
 *----------------------------------------------------------------------------*/
static int SetRowCountVar( RxPackageGlobalDataDef *RxPackageGlobalData, SQLWA *swa, char *stem_name, RXSQL_ROWCOUNT_TYPE rowcount )
{
   int     i=0;
   char    varname[MAX_IDENTIFIER*2+4], buf[50];

   InternalTrace( RxPackageGlobalData, "SetRowCountVar", "%x,%s,%ld", swa, stem_name, rowcount );

   for (i = 0; i < swa->expr_cnt; i++)
   {
      sprintf( varname, "%s.%s.0", stem_name, swa->fa[i]->name );
      sprintf( buf, "%lu", rowcount );
      if ( SetRexxVariable( RxPackageGlobalData, varname, strlen( varname ), buf, strlen( buf) ) )
         return(-16);
   }
   return 0;
}

/*-----------------------------------------------------------------------------
 *
 *----------------------------------------------------------------------------*/
static int SetInfoRowCountVar( RxPackageGlobalDataDef *RxPackageGlobalData, SQLWA *swa, char *stem_name, RXSQL_ROWCOUNT_TYPE rowcount, int type )
{
   int     i=0;
   int     varlen, buflen;
   char    varname[MAX_IDENTIFIER*2+4], buf[50];
   char    *fd_name;
   FLDDSCR *fd=NULL;

   InternalTrace( RxPackageGlobalData, "SetRowCountVar", "%x,%s,%ld", swa, stem_name, rowcount );

   buflen = sprintf( buf, "%lu", rowcount );

   for (i = 0; i < swa->expr_cnt; i++)
   {
      fd = swa->fa[i];
      /*
       * Switch fd->name depending on type
       */
      switch ( type )
      {
         case MY_INFO_DATASOURCES:
            fd_name = "DSN_NAME";
            break;
         case MY_INFO_TABLES:
            fd_name = "TABLE_NAME";
            break;
         case MY_INFO_COLUMNS:
            switch(i)
            {
               case 0:
                  fd_name = "COLUMN_NAME";
                  break;
               case 1:
                  fd_name = "COLUMN_TYPE";
                  break;
               case 2:
                  fd_name = "COLUMN_NULLABLE";
                  break;
               case 5:
                  fd_name = "COLUMN_DESCRIPTION";
                  break;
               default:
                  fd_name = NULL;
                  break;
            }
            break;
         default:
            break;
      }
      if ( fd_name )
      {
         varlen = sprintf( varname, "%s.%s.0", stem_name, fd_name );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
      }
   }
   /*
    * Add any extra columns
    */
   switch( type )
   {
      case MY_INFO_DATASOURCES:
         varlen = sprintf( varname, "%s.%s.0", stem_name, "DSN_DESCRIPTION" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
        break;
      case MY_INFO_TABLES:
         varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_CATALOG" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
         varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_OWNER" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
         varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_TYPE" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
         varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_DESCRIPTION" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
        break;
      case MY_INFO_COLUMNS:
         varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_CATALOG" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
         varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_OWNER" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
         varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_NAME" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
         varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_SIZE" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
         varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_PRECISION" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
         varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_SCALE" );
         if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) )
            return(-16);
         break;
   }
   return 0;
}

/*-----------------------------------------------------------------------------
 *
 *----------------------------------------------------------------------------*/
static int my_info_results( RxPackageGlobalDataDef *RxPackageGlobalData, RFH_ARG1_TYPE argc, RFH_ARG2_TYPE argv, int type, char *cmd, char *tablename )
{
   int         rc = 0;
   RXSQL_ROWCOUNT_TYPE rowcount=0L;
   DBCON       *db=NULL;
   STMT        *stmt=NULL;
   SQLWA   *swa=NULL;
   char        stem_name[MAX_IDENTIFIER+1];

   REXXSQLDATA *RexxSQLData;

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( argc == 0 || RXSTRLEN(argv[0]) == 0 ) /* No stem name specified! */
      (void)strcpy( stem_name, DEFAULT_STEM );
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) != 0 )
         return rc;
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: stem: %s\n", __FILE__,__LINE__, stem_name);)

   /*
    * Get pointer to current connection
    */
   if ( RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection )
      db = RexxSQLData->DbEnv->current_connection;
   else
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 25, "no connection is current" ));

   /*
    * If no default statement then create it!
    */
   if ( ( stmt = (STMT*)(db->dflt_stmt) ) == (STMT*)NULL )
   {
      /*
       * Open a statement for the default statement.
       */
      if ( ( rc = OpenStatement (RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt) ) != 0 )
         return rc;
      db->dflt_stmt = (void*)stmt;
   }

   swa = SWA(stmt);

   if ( SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), cmd, strlen(cmd) ) )
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));

   /*
    * Execute the SQL statement
    */
   if ( ( rc = MYSQL_REAL_QUERY( &db->mysql, swa->saved_stmt.sql_stmt, swa->saved_stmt.sql_stmt_sz ) ) != 0 )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, SWA(stmt), &db->mysql );
      return DB_ERROR;
   }

   /*
    * Save results
    */
   if ( !(CTX(swa) = (MYSQL_RES *)MYSQL_STORE_RESULT( &db->mysql) )
#if MYSQL_VERSION_ID >= 32224
   &&  MYSQL_FIELD_COUNT( &db->mysql ) )
#else
   &&  MYSQL_NUM_FIELDS( &db->mysql ) )
#endif
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, SWA(stmt), &db->mysql );
      return DB_ERROR;
   }

   /*
    * Get field definitions
    */
   rc = DefineExpressions( RxPackageGlobalData, stmt );
   if (rc < 0)
      return rc;

   /*
    * Fetch each row in turn
    */
   for ( rowcount = 1; ; rowcount++ )
   {
      if ( (rc = FetchInfoRow( RxPackageGlobalData, db, stmt, stem_name, rowcount, type, tablename )) != 0 )
         break;
   }
   rowcount--;

   if ( rc && rc != NO_DATA_FOUND )
      return rc;

   if ( ( rc = SetInfoRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount, type ) ) != 0 )
      return rc;

   /*
    * Inform MYSQL that operation is complete
    */
   if ( CTX(swa) )
   {
      MYSQL_FREE_RESULT( CTX(swa) );
      CTX(swa) = NULL;
   }
   SetRowCount( RxPackageGlobalData, rowcount );

   return 0;
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLTABLES([stem-name, ] [catalog], [owner], [table], [type] )
 *
 * ARGUMENTS:
 *            0 - stem_name (optional)
 *            1 - table catalog (optional - ignored)
 *            2 - table owner (optional - ignored)
 *            3 - table name (optional)
 *            4 - table type (optional - ignored)
 *
 *
 * RETURNS :  0-success, <0-error.
 *
 *----------------------------------------------------------------------------*/
rxfunc( SQLTABLES )
{
   int         rc = 0;
   char        cmd[150];
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 5 ) )
      return 1;

   if (argc > 3
   &&  RXSTRLEN(argv[3]))                            /* a table name passed */
      sprintf( cmd, "SHOW TABLES LIKE '%s'", RXSTRPTR(argv[3]) );
   else
      strcpy( cmd, "SHOW TABLES" );

   rc = my_info_results( RxPackageGlobalData, argc, argv, MY_INFO_TABLES, cmd, NULL );

   return RxReturnNumber( RxPackageGlobalData, retstr, 0 );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLCOLUMNS([stem-name, ] [catalog], [owner], [table], [type] )
 *
 * ARGUMENTS:
 *            0 - stem-name (optional)
 *            1 - table catalog (optional - ignored)
 *            2 - table owner (optional - ignored)
 *            3 - table name (mandatory)
 *            4 - table type (optional - ignored)
 *
 *
 * RETURNS :  0-success, <0-error.
 *
 *----------------------------------------------------------------------------*/
rxfunc( SQLCOLUMNS )
{
   int         rc = 0;
   char        cmd[150];
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 4, 5 ) )
      return 1;

   if (argc > 3
   &&  RXSTRLEN(argv[3]))                            /* a table name passed */
   {
      sprintf( cmd, "SHOW COLUMNS FROM %s", RXSTRPTR(argv[3]) );
   }
   else
      return 1;

   rc = my_info_results( RxPackageGlobalData, argc, argv, MY_INFO_COLUMNS, cmd, RXSTRPTR(argv[3]) );

   return RxReturnNumber( RxPackageGlobalData, retstr, rc );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDATASOURCES([stem-name] )
 *
 * ARGUMENTS:
 *            0 - stem_name (optional)
 *
 *
 * RETURNS :  0-success, <0-error.
 *
 *----------------------------------------------------------------------------*/
rxfunc( SQLDATASOURCES )
{
   int         rc = 0;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 1 ) )
      return 1;

   rc = my_info_results( RxPackageGlobalData, argc, argv, MY_INFO_DATASOURCES, "SHOW DATABASES", NULL );

   return RxReturnNumber( RxPackageGlobalData, retstr, rc );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS: SQLCOMMAND(stem-name, sql-statement-text)
 *
 * RETURNS :  0-success < 0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLCOMMAND )
{
   int         rc = 0, i=0;
   RXSQL_ROWCOUNT_TYPE rowcount=0L;
   DBCON       *db=NULL;
   STMT        *stmt=NULL;
   SQLWA   *swa=NULL;
   char        stem_name[MAX_IDENTIFIER+1];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 2 ) )
      return 1;

   /*
    * Get pointer to current connection
    */
   if ( RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection )
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if ( argc == 1 || RXSTRLEN(argv[0]) == 0 ) /* No stem name specified! */
      (void)strcpy( stem_name, DEFAULT_STEM );
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc);
   }

   /*
    * If no default statement then create it!
    */
   if ( ( stmt = (STMT*)(db->dflt_stmt) ) == (STMT*)NULL )
   {
      /*
       * Open a statement for the default statement.
       */
      if ( ( rc = OpenStatement (RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      db->dflt_stmt = (void*)stmt;
   }

   swa = SWA(stmt);

   /*
    * If only 1 arg then it is the SQL-statement-text. If more than 1 args
    * then arg#1 is stem-name, arg#2 is text.
    * 'i' is index (base zero) to sql-statement-text arg.
    */
   i = (argc == 1) ? 0 : 1;

   /*
    * Save the SQL statement if required
    * This MUST always be done for mySQL, because it is the saved
    * SQL ststement that gets passed to mysql_query().
    */
   if ( SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), RXSTRPTR(argv[i]),(int)RXSTRLEN(argv[i]) ) )
      return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

   /*
    * Execute the SQL statement
    */
   if ( ( rc = MYSQL_REAL_QUERY( &db->mysql, swa->saved_stmt.sql_stmt, swa->saved_stmt.sql_stmt_sz ) ) != 0 )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, SWA(stmt), &db->mysql );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
   }

   /*
    * Save results
    */
   if ( !(CTX(swa) = (MYSQL_RES *)MYSQL_STORE_RESULT( &db->mysql) )
#if MYSQL_VERSION_ID >= 32224
   &&  MYSQL_FIELD_COUNT( &db->mysql ) )
#else
   &&  MYSQL_NUM_FIELDS( &db->mysql ) )
#endif
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, SWA(stmt), &db->mysql );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
   }

   /*
    * If NOT a query, statement has been executed, leave...
    */
#if MYSQL_VERSION_ID >= 32224
   if ( MYSQL_FIELD_COUNT( &db->mysql ) == 0 )
#else
   if ( MYSQL_NUM_FIELDS( &db->mysql ) == 0 )
#endif
   {
      rowcount = MYSQL_AFFECTED_ROWS( &db->mysql );
      SetRowCount( RxPackageGlobalData, rowcount );
      /*
       * If the statement is NOT a SELECT, and we have AUTOCOMMIT
       * ON, then commit the statement.
       */
      if ( RexxSQLData->AutoCommit )
      {
         if ( ( rc = MYSQL_REAL_QUERY( &db->mysql, "COMMIT", 6 ) != 0 ) )
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, SWA(stmt), &db->mysql );
      }
      return RxReturnNumber( RxPackageGlobalData, retstr, 0L );
   }

   /*
    * Get field definitions
    */
   rc = DefineExpressions( RxPackageGlobalData, stmt );
   if (rc < 0)
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );

   /*
    * Fetch each row in turn
    */
   for ( rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= RexxSQLData->RowLimit; rowcount++ )
   {
      if ( (rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount)) != 0 )
         break;
   }
   rowcount--;

   if ( rc && rc != NO_DATA_FOUND )
   {
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   }

   if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount ) ) != 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );

   /*
    * Inform MYSQL that operation is complete
    */
   if ( CTX(swa) )
   {
      MYSQL_FREE_RESULT( CTX(swa) );
      CTX(swa) = NULL;
   }
   SetRowCount( RxPackageGlobalData, rowcount );

   return RxReturnNumber( RxPackageGlobalData, retstr, 0L );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLPREPARE(statement-name, sql-statement-text)
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLPREPARE )
{
   int         rc=0;
   DBCON       *db=NULL;
   STMT        *stmt=NULL;
   SQLWA   *swa=NULL;
   char        stmt_name[MAX_IDENTIFIER+1];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 2, 2 ) )
      return 1;

   /*
    * Get pointer to current connection
    */
   if ( RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection )
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if ( RXSTRLEN(argv[0]) == 0 )     /* No statement name specified! */
      return ReturnError( RxPackageGlobalData, retstr, 18, "statement name omitted or null" );
   else if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stmt_name, sizeof(stmt_name) ) ) != 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, rc );

   /*
    * Find the named statement or create if necessary. We have to be a
    * bit careful here because the statement may exist but point to a
    * different database connection!
    */
   stmt = FindObject( RxPackageGlobalData, stmt_name, RexxSQLData->DbEnv->stmt_tbl, TBL_STATEMENTS );

   if ( stmt == (STMT*)NULL || stmt->db != db )
   {
      if ( stmt )
      {
         /*
          * Statement is not for the same db, therefore we must dispose
          * & re-alloc it!
          */
         RemoveObject( RxPackageGlobalData, stmt );
         ((DBCON*)stmt->db)->num_statements--;
         if ( ( rc = ReleaseStatement( RxPackageGlobalData, stmt ) ) != 0 )
            return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      }
      /*
       * Open a statement for this statement.
       */
      if ( ( rc = OpenStatement( RxPackageGlobalData, stmt_name, db, &stmt ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      /*
       * Insert this statement into the connection hash table.
       */
      (void)InsertObject( RxPackageGlobalData, stmt, RexxSQLData->DbEnv->stmt_tbl, TBL_STATEMENTS );

      db->num_statements++;
   }

   swa = SWA(stmt);

   /*
    * Save the SQL statement if required
    * This MUST always be done for mySQL, because it is the saved
    * SQL ststement that gets passed to mysql_query().
    */

   if ( SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), RXSTRPTR(argv[1]), (int)RXSTRLEN(argv[1]) ) )
       return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

   swa->expr_cnt = 0;

   return RxReturnNumber( RxPackageGlobalData, retstr, rc ? DB_ERROR : 0 );
}

/*-----------------------------------------------------------------------------
 * Get a pointer to the nominated statement. Returns NULL on error.
 *----------------------------------------------------------------------------*/
static STMT *GetStatement( RxPackageGlobalDataDef *RxPackageGlobalData, RXSTRING  var, PSZ buf )
{
   STMT        *stmt=NULL;
   char        tmp[128];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "GetStatement", "%x,%s", var, buf );

   if ( RexxSQLData->DbEnv == (DBENV*)NULL )
   {
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 22, "no connections open." );
      return (STMT*)NULL;
   }

   if ( RXSTRLEN(var) == 0 )   /* No statement name specified! */
   {
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 23, "statement name omitted or null"  );
      return (STMT*)NULL;
   }

   /* Get the normalised form of the name */
   if ( MkIdentifier( RxPackageGlobalData, var, buf, MAX_IDENTIFIER+1 ) )
      return (STMT*)NULL;

   /* Find the named statement or create if necessary */
   if ( ( stmt = FindObject( RxPackageGlobalData, buf, RexxSQLData->DbEnv->stmt_tbl, TBL_STATEMENTS ) ) == (STMT*)NULL )
   {
      /* Statement not an existing one! */
      (void)sprintf( tmp, "statement \"%s\" does not exist", buf );
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 24, tmp );
      return (STMT*)NULL;
   }
   return stmt;
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDISPOSE(statement-name)
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLDISPOSE )
{
   int         rc=0;
   STMT        *stmt=NULL;
   DBCON       *db=NULL;
   char        stmt_name[MAX_IDENTIFIER+1];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 1 ) )
      return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   /* Get pointer to statement's connection structure */
   db = stmt->db;

   /* Dispose the statement */
   RemoveObject( RxPackageGlobalData, stmt );
   rc = ReleaseStatement( RxPackageGlobalData, stmt );

   db->num_statements--;

   return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLEXEC (called by SQLEXECUTE() and SQLOPEN()
 *
 * RETURNS :  0-success,
 *           >0-number of rows affected for SQLEXECUTE(),
 *           <0-error.
 *----------------------------------------------------------------------------*/
APIRET APIENTRY SQLEXEC( RFH_ARG0_TYPE name, RFH_ARG1_TYPE argc, RFH_ARG2_TYPE argv, RFH_ARG3_TYPE stck, RFH_ARG4_TYPE retstr, int open )
{
   RXSQL_ROWCOUNT_TYPE rowcount=0L;
   STMT        *stmt=NULL;
   SQLWA   *swa=NULL;
   DBCON       *db=NULL;
   char        stmt_name[MAX_IDENTIFIER+1];
   char        tmp[128];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( argc == 0 ) return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode);

   swa = SWA(stmt);

   /*
    * Make sure we have a current connection
    */
   if ( RexxSQLData->DbEnv == (DBENV*)NULL )
      return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

   /*
    * Get pointer to current connection
    */
   if ( RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection )
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   /*
    * This function can be called as SQLOPEN() or SQLEXECUTE(). These
    * operations are similar except for the describe. Use the function
    * name to determine what operation we are performing.
    */

   /*
    * Execute the SQL statement
    */
   if ( MYSQL_REAL_QUERY( &db->mysql, swa->saved_stmt.sql_stmt, swa->saved_stmt.sql_stmt_sz ) != 0 )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, SWA(stmt), &db->mysql );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
   }

   /*
    * Save results if we haven't already done it for this statement
    */
   if ( !CTX(swa) )
   {
      if ( !(CTX(swa) = (MYSQL_RES *)MYSQL_STORE_RESULT( &db->mysql ) )
#if MYSQL_VERSION_ID >= 32224
      &&  MYSQL_FIELD_COUNT( &db->mysql ) )
#else
      &&  MYSQL_NUM_FIELDS( &db->mysql ) )
#endif
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, SWA(stmt), &db->mysql );
         return RxReturnNumber( RxPackageGlobalData,  retstr, DB_ERROR );
      }
   }

   /*
    * If called from SQLOPEN() the statement must be a query!
    */
   if ( open
#if MYSQL_VERSION_ID >= 32224
   &&  MYSQL_FIELD_COUNT( &db->mysql ) == 0 )
#else
   &&  MYSQL_NUM_FIELDS( &db->mysql ) == 0 )
#endif
   {
      (void)sprintf( tmp, "statement \"%s\" is not a query.", stmt_name );
      return ReturnError( RxPackageGlobalData, retstr, 13, tmp );
   }

   /*
    * Return the ROWCOUNT.  For a query it will be zero at this stage.  For
    * a DML statement it will be the number of rows affected by the INSERT/
    * UPDATE/DELETE statement.
    * This ALWAYS returns 0 with mySQL at this stage.
    */
#if MYSQL_VERSION_ID >= 32224
   if ( MYSQL_FIELD_COUNT( &db->mysql ) )
#else
   if ( MYSQL_NUM_FIELDS( &db->mysql ) )
#endif
      rowcount = MYSQL_NUM_ROWS( CTX(swa) );
   else
   {
      rowcount = MYSQL_AFFECTED_ROWS( &db->mysql );
      /*
       * If the statement is NOT called from SQLOPEN(), and we have AUTOCOMMIT
       * ON, then commit the statement.
       */
      if ( RexxSQLData->AutoCommit )
      {
         if ( MYSQL_REAL_QUERY( &db->mysql, "COMMIT", 6 ) != 0 )
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, SWA(stmt), &db->mysql );
      }
   }
   SetRowCount( RxPackageGlobalData, rowcount );
   return RxReturnNumber( RxPackageGlobalData, retstr, (long)0L );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS: SQLCLOSE(statement-name)
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLCLOSE )
{
   int         rc=0;
   STMT        *stmt=NULL;
   SQLWA   *swa=NULL;
   char        stmt_name[MAX_IDENTIFIER+1];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 1 ) )
      return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   swa = SWA(stmt);

   /* Inform mySQL that operation is complete. This should never fail! */
   if ( CTX(swa) )
   {
      MYSQL_FREE_RESULT( CTX(swa) );
      CTX(swa) = NULL;
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, rc ? DB_ERROR : 0 );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLFETCH(statement-name [, number-of-rows])
 *
 * RETURNS :  0-end-of-data,
 *           >0- single fetch: row number of last row fetched
 *           >0- group fetch : number of rows fetched if < number-of-rows then
 *                             end--of-data is indicated.
 *           <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLFETCH )
{
   int         single_fetch=0;
   rx_long_long rc=0L;
   rx_long_long num_rows=0L;
   RXSQL_ROWCOUNT_TYPE rowcount=0L;
   STMT        *stmt=NULL;
   SQLWA   *swa=NULL;
   char        stmt_name[MAX_IDENTIFIER+1];
   char        tmp[128];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 2 ) )
      return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   swa = SWA(stmt);

   if ( !CTX(swa) )
   {
      (void)sprintf( tmp, "statement \"%s\" has not been OPENed or EXECUTEd", stmt->name );
      return ReturnError( RxPackageGlobalData, retstr, 26, tmp );
   }

   /*
    * Determine # of rows to fetch
    */
   if ( argc > 1 && RXSTRLEN(argv[1]) )
   {
      if ( RxStrToLongLong( RxPackageGlobalData, &argv[1], &num_rows ) )
      {
         return ReturnError( RxPackageGlobalData, retstr, 14,"<num-rows> is not a valid integer." );
      }
      single_fetch = FALSE;
   }
   else
      single_fetch = TRUE;

   /*
    * Get field definitions
    */
   rc = DefineExpressions( RxPackageGlobalData, stmt );
   if ( rc < 0 )
   {
      (void)sprintf( tmp, "statement \"%s\" has not been OPENed or EXECUTEd", stmt->name );
      return ReturnError( RxPackageGlobalData, retstr, 26, tmp );
   }

   if ( single_fetch )
   {
      /*
       * Fetch a single row
       */
      if ( (rc = FetchRow( RxPackageGlobalData, stmt, stmt_name, 0L ) ) != 0 )
         rc = (rc == NO_DATA_FOUND) ? 0 : rc;
      else
         rc = 1; /* single row fetch, must return 1 */
   }
   else
   {
      /*
       * Fetch each row in turn
       */
      for ( rowcount = 1; num_rows == 0 || rowcount <= num_rows; rowcount++ )
      {
         if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stmt_name, rowcount ) ) != 0 )
            break;
      }

      rowcount--;

      if ( rc && rc != NO_DATA_FOUND )
      {
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      }

      if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stmt_name, rowcount ) ) != 0 )
         return RxReturnLongLong( RxPackageGlobalData, retstr, rc );

      rc = rowcount;
   }

   SetRowCount( RxPackageGlobalData, rc );
   return RxReturnLongLong( RxPackageGlobalData, retstr, rc );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLGETDATA(statement-name, column-name, start-byte, length [, file-name])
 *
 * RETURNS :  0-end-of-data,
 *           >0- bytes obtained - <= length
 *           <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLGETDATA )
{
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();
   return RxReturnNumber( RxPackageGlobalData, retstr, 0L);
}

/*-----------------------------------------------------------------------------
 * Fetch the description for the column expression. Used by SQLDESCRIBE().
 *----------------------------------------------------------------------------*/
static int GetColumn( RxPackageGlobalDataDef *RxPackageGlobalData, SQLWA *swa, int i, char *stem_name )
{
   FLDDSCR *fd=NULL;
   int     idx=0, rc=0, j=0;
   char    column_size[15], column_scale[15], column_precision[15], column_primarykey[15], column_nullok[15], column_blob[15];
   char    *column_type=NULL;
   char    name[MAX_IDENTIFIER+32];
   char    *value[NUM_DESCRIBE_COLUMNS];
   int     value_len[NUM_DESCRIBE_COLUMNS];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "GetColumn", "%x,%d,%s", swa, i, stem_name );

   if ( i >= swa->expr_cnt )
      return 1;

   fd = swa->fa[i];

   for ( j = 0; datatype_conversion[j].ext_datatype; j++ )
   {
      if ( datatype_conversion[j].int_datatype == fd->type )
      {
         column_type = datatype_conversion[j].ext_datatype;
         break;
      }
   }
   if ( column_type == NULL )
      column_type = "UNKNOWN";

   /*
    * Set up the array
    */
   value[0] = fd->name;
   value_len[0] = strlen(fd->name);
   value[1] = column_type;
   value_len[1] = strlen(column_type);
   value[2] = column_size;
   value_len[2] = sprintf(column_size, "%d", fd->length);
   value[3] = column_precision;
   value_len[3] = sprintf(column_precision, "%d", fd->length);
   value[4] = column_scale;
   value_len[4] = sprintf(column_scale, "%d", fd->decimals);
   value[5] = column_nullok;
   value_len[5] = sprintf(column_nullok, "%d", (IS_NOT_NULL(fd->flags)) ? 0 : 1);
   value[6] = column_primarykey;
   value_len[6] = sprintf(column_primarykey, "%d", (IS_PRI_KEY(fd->flags)) ? 1 : 0);
   value[7] = column_blob;
   value_len[7] = sprintf(column_blob, "%d", (IS_BLOB(fd->flags)) ? 1 : 0);

   /*
    * Output into Rexx variable
    */
   i++;
   for ( idx = 0; idx < NUM_DESCRIBE_COLUMNS; idx++ )
   {
      sprintf( name, "%s.COLUMN.%s.%d", stem_name, RexxSQLData->column_attribute[idx], i);
      if ( SetRexxVariable( RxPackageGlobalData, name, strlen( name ), value[idx], value_len[idx] ) )
      {
         rc = -16;
         break;
      }
   }

   return rc;
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDESCRIBE(statement-name [, stem-name])
 *
 * RETURNS : >0-number of columns in the prepared SELECT statement.
 *            0-prepared statement is not a SELECT statement.
 *           <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLDESCRIBE )
{
   int         i=0, len1=0, len2=0, rc=0;
   STMT        *stmt=NULL;
   SQLWA   *swa=NULL;
   DBCON       *db=NULL;
   char        **p=NULL, buf1[MAX_IDENTIFIER+32], buf2[16];
   char        stmt_name[MAX_IDENTIFIER+1];
   char        tmp[128];
   char        stem_name[MAX_IDENTIFIER+1];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 2 ) )
      return 1;

   /* Get pointer to current connection */
   if ( RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection )
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   swa = SWA(stmt);

   /* Get the name of the stem into which to put output */
   if ( argc < 2 || RXSTRLEN(argv[1]) == 0 ) /* No stem name specified! */
      (void)strcpy( stem_name, stmt_name );
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[1], stem_name, sizeof(stem_name) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   }
   /*
    * Execute the SQL statement
    */
   if ( MYSQL_REAL_QUERY( &db->mysql, swa->saved_stmt.sql_stmt, swa->saved_stmt.sql_stmt_sz ) != 0 )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, SWA(stmt), &db->mysql );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
   }

   /* Save results if we haven't already done it for this statement */
   if ( !CTX(swa) )
      CTX(swa) = MYSQL_STORE_RESULT( &db->mysql );

   if ( CTX(swa) == NULL )  /* not SELECT */
   {
      (void)sprintf( tmp, "statement \"%s\" is not a query.", stmt_name );
      return ReturnError( RxPackageGlobalData, retstr, 13, tmp );
   }

#if MYSQL_VERSION_ID >= 32224
   swa->expr_cnt = MYSQL_FIELD_COUNT( &db->mysql );
#else
   swa->expr_cnt = MYSQL_NUM_FIELDS( &db->mysql );
#endif
   MYSQL_FIELD_SEEK( CTX(swa), 0 );
   /* Get each expr value in turn */
   for ( i = 0; rc == 0 && i < swa->expr_cnt; i++ )
   {
      swa->fa[i] = MYSQL_FETCH_FIELD( CTX(swa) );
      /* should check here for NULL fd !! */
      rc = GetColumn( RxPackageGlobalData, swa, i, stem_name );
   }

   if ( rc >= 0 )
   {
      len2 = sprintf( buf2, "%d", i );
      for ( p = RexxSQLData->column_attribute; *p && rc >= 0; p++ )
      {
         len1 = sprintf( buf1, "%s.COLUMN.%s.0", stem_name, *p );
         if ( SetRexxVariable( RxPackageGlobalData, buf1, len1, buf2, len2 ) )
            rc = -16;
         else
            rc = 0;
      }
      rc = rc < 0 ? rc : i;
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
}

/*-----------------------------------------------------------------------------
 * Database initialisation
 *----------------------------------------------------------------------------*/
static int DBInitialise( RxPackageGlobalDataDef *RxPackageGlobalData)
{
#ifdef WIN32
   RexxSQLLoadMySQL();
#endif
   return(0);
}

/*-----------------------------------------------------------------------------
 * Database termination
 *----------------------------------------------------------------------------*/
static int DBTerminate( RxPackageGlobalDataDef *RxPackageGlobalData)
{
   /*
    * for threaded programs > 4.0 need to call mysql_thread_end() at end of prog
    */
#if MYSQL_VERSION_ID >= 40000
   if ( MYSQL_THREAD_SAFE() )
      MYSQL_THREAD_END();
#endif
#ifdef WIN32
   RexxSQLUnloadMySQL();
#endif
   return 0;
}

/*-----------------------------------------------------------------------------
 * Set up the string containing database name
 *----------------------------------------------------------------------------*/
static void *SQLValSetDBMSName( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetDBMSName", "%x", db );
   strcpy( RexxSQLData->DBMSName, "mySQL" );
   MAKERXSTRING( RexxSQLData->RXSDBMSName, RexxSQLData->DBMSName, (ULONG)strlen(RexxSQLData->DBMSName) );
   return( (void*)&RexxSQLData->RXSDBMSName );
}

/*-----------------------------------------------------------------------------
 * Set up the DBMSVer variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetDBMSVer( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;
   char *ver=(char *)MYSQL_GET_SERVER_INFO( &(db->mysql) );

   InternalTrace( RxPackageGlobalData, "SetDBMSVer", "%x", db );
   strcpy( RexxSQLData->DBMSVer, ver );
   MAKERXSTRING( RexxSQLData->RXSDBMSVer, RexxSQLData->DBMSVer, (ULONG)strlen( RexxSQLData->DBMSVer ) );
   return( (void*)&RexxSQLData->RXSDBMSVer );
}

/*-----------------------------------------------------------------------------
 * Set up the Datatypes supported
 *----------------------------------------------------------------------------*/
static void *SQLValSetDatatypes( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   int i=0;
   RXSTRING_DT *dt=NULL;

   InternalTrace( RxPackageGlobalData, "SetDatatypes", "%x", db );

   dt = (RXSTRING_DT *)MALLOC_TSD( RxPackageGlobalData, sizeof(RXSTRING_DT)*(MAX_DATATYPES+1) );
   for ( i = 0; i < MAX_DATATYPES && datatype_conversion[i].ext_datatype; i++ )
   {
      dt[i].strptr = (char*)MALLOC_TSD( RxPackageGlobalData, 1+strlen(datatype_conversion[i].ext_datatype) );
      strcpy(dt[i].strptr, datatype_conversion[i].ext_datatype);
      dt[i].strlength = strlen(datatype_conversion[i].ext_datatype);
      dt[i].internal = datatype_conversion[i].int_datatype;
   }
   dt[i].strptr = NULL;
   dt[i].strlength = 0;
   dt[i].internal = 0;
   return((void*)dt);
}

/*-----------------------------------------------------------------------------
 * Set up the Describe Columns supported
 *----------------------------------------------------------------------------*/
static void *SQLValSetDescribeColumns( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   int i=0;
   RXSTRING *dc=NULL;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetDescribeColumns", "%x", db );

   dc = (RXSTRING *)MALLOC_TSD( RxPackageGlobalData, sizeof(RXSTRING)*(NUM_DESCRIBE_COLUMNS+1) );
   for ( i = 0; i < NUM_DESCRIBE_COLUMNS; i++ )
   {
      dc[i].strptr = (char*)MALLOC_TSD( RxPackageGlobalData, 1+strlen( RexxSQLData->column_attribute[i] ) );
      strcpy( dc[i].strptr, RexxSQLData->column_attribute[i] );
      dc[i].strlength = strlen( RexxSQLData->column_attribute[i] );
   }
   dc[i].strptr = NULL;
   dc[i].strlength = 0;
   return((void*)dc);
}

/*-----------------------------------------------------------------------------
 * Set up the SupportsTransactions variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetSupportsTransactions( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;
   char *show_variables = "SHOW VARIABLES LIKE \"have_%\"";

   InternalTrace( RxPackageGlobalData, "SetSupportsTransactions", "%x", db );
#if 0
   /*
    * If the MySQL database we are connected to has support for BDB or INNOBASE
    * then we will assume it has support for transactions.
    */
   if ( (rc = MYSQL_REAL_QUERY( &db->mysql, show_variables, strlen( show_variables ) ) ) != 0 )
   {
      RexxSQLData->SupportsTransactions = FALSE;
   }
   else
   {
      RexxSQLData->SupportsTransactions = TRUE;
   }
#endif
      RexxSQLData->SupportsTransactions = TRUE;
   return((void*)&RexxSQLData->SupportsTransactions);
}

/*-----------------------------------------------------------------------------
 * Set up the SupportsSqlGetData variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetSupportsSqlGetData( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetSupportsSqlGetData", "%x", db );
   RexxSQLData->SupportsSqlGetData = SUPPORTSSQLGETDATA;
   return( (void*)&RexxSQLData->SupportsSqlGetData);
}

/*-----------------------------------------------------------------------------
 * Set up the RowLimit variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetRowLimit( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetRowLimit", "%x", db );
   RexxSQLData->RowLimit = 0;
   return( (void*)&RexxSQLData->RowLimit);
}

/*-----------------------------------------------------------------------------
 * Set up the LongLimit variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetLongLimit( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetLongLimit", "%x", db );
   RexxSQLData->LongLimit = DEFAULT_LONG_LIMIT;
   return( (void*)&RexxSQLData->LongLimit);
}

/*-----------------------------------------------------------------------------
 * Set up the SaveSQL variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetSaveSQL( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetSaveSQL", "%x", db );
   RexxSQLData->SaveSQL = TRUE;
   return( (void*)&RexxSQLData->SaveSQL);
}

/*-----------------------------------------------------------------------------
 * Set up the AutoCommit variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetAutoCommit( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetAutoCommit", "%x", db );
   RexxSQLData->AutoCommit = FALSE;
   return( (void*)&RexxSQLData->AutoCommit);
}

/*-----------------------------------------------------------------------------
 * Set up the IgnoreTruncate variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetIgnoreTruncate( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetIgnoreTruncate", "%x", db );
   RexxSQLData->IgnoreTruncate = FALSE;
   return( (void*)&RexxSQLData->IgnoreTruncate);
}

/*-----------------------------------------------------------------------------
 * Set up the StandardPlacemarkers variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetStandardPlacemarkers( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetStandardPlacemarkers", "%x", db );
   RexxSQLData->StandardPlacemarkers = FALSE;
   return( (void*)&RexxSQLData->StandardPlacemarkers);
}

/*-----------------------------------------------------------------------------
 * Set up the SupportsDMLRowcount variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetSupportsDMLRowcount( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetSupportsDMLRowcount", "%x", db );
   RexxSQLData->SupportsDMLRowcount = TRUE;
   return( (void*)&RexxSQLData->SupportsDMLRowcount);
}

/*-----------------------------------------------------------------------------
 * Set up the SupportsPlacemarkers variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetSupportsPlacemarkers( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetSupportsPlacemarkers", "%x", db );
   RexxSQLData->SupportsPlacemarkers = SUPPORTSPLACEMARKERS;
   return( (void*)&RexxSQLData->SupportsPlacemarkers);
}

/*-----------------------------------------------------------------------------
 * Set up the SupportsThreads variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetSupportsThreads( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetSupportsThreads", "%x", db );
#if MYSQL_VERSION_ID >= 40000
   if ( MYSQL_THREAD_SAFE() )
      RexxSQLData->SupportsThreads = TRUE;
   else
      RexxSQLData->SupportsThreads = FALSE;
#else
   RexxSQLData->SupportsThreads = FALSE;
#endif
   return( (void*)&RexxSQLData->SupportsThreads);
}
/*
 * MySQL - specific functions; to go into rexxmy.dll
 */

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  MYGETINSERTID()
 *
 * RETURNS : The rowid of the last INSERT/UPDATE of an AUTO_INCREMENT column
 *----------------------------------------------------------------------------*/
rxfunc( RexxMYGetInsertId )
{
   DBCON       *db=NULL;
   REXXSQLDATA *RexxSQLData;
   rx_long_long rowid=0L;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if (RexxSQLData->SQLCA_SqlCode) ClearDBError( RxPackageGlobalData );
   if (RexxSQLData->SQLCA_IntCode) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 0 ) )
      return 1;

   /* Get pointer to current connection */
   if ( RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection )
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );
   /*
    * Get the rowid now; no errors possible
    */
   rowid = MYSQL_INSERT_ID( &db->mysql );

   return RxReturnLongLong( RxPackageGlobalData, retstr, rowid );
}

#include "rxsqlinc2.h"
