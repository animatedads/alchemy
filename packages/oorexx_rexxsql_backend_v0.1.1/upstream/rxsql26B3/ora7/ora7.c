/*
 * ora.c - REXX/SQL for Oracle
 *
 *
 * REXX/SQL. A REXX interface to SQL databases.
 * Copyright Impact Systems Pty Ltd, 1994.
 * Copyright (C) Mark Hessling 1995-2004.
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
 * Author:  Chris O'Sullivan  Ph (Australia) 015 123414
 *
 *    Purpose: This module provides an Oracle SQL interface for REXX. It
 *    allows REXX programs to connect to Oracle servers, issue SQL
 *    queries, DDL, DCL & DML statements. Multiple concurrent
 *    connections are supported. Additionally, multiple statements
 *    may be active concurrently against any or all of these
 *    connections. This interface is called "REXX/SQL".
 *
 *      Notes: 1) The REXX/SQL interface is built using the Oracle Call
 *    Interface (OCI libraries). As such it does require that the
 *    object code be linked with the OCI libraries. Consequently,
 *    it does not require the Oracle Pre-compilers (i.e. Pro*C) to
 *    compile it. Also, it does not require the Pro* libraries
 *    (e.g. SQLLIB) at link time.
 *
 *    2) I have attempted to write this module so that the Oracle
 *              interface could be replaced by another (say GUPTA) without
 *              affecting REXX programs which have been written for this inter-
 *              face (providing these programs use ANSI SQL). Any programs
 *    using DDL or DCL will not be portable without some clever
 *    programming!
 *
 *    3) Very little has been added to support the performance
 *    features of Oracle. The interface does allow a statement to be
 *    parsed once and executed multiple times. Binding is another
 *    matter. Since arguments are passed by value, it was a tradeoff
 *    as to whether to dynamically allocate a buffer for each bind
 *    value and allow the statement to be reexecuted without rebinding
 *    (or rebinding of selected variables). The alternative was to
 *    assume that the extra overhead of the malloc() and strcpy()
 *    would be less efficient in many cases. At this point in time,
 *    the values passed to the function are bound directly. A rebind
 *    is thus necessary each time SQLEXECUTE() or SQLOPEN() is
 *    called.
 *
 *              5) As far as performance features there is currently no support
 *    for the following:
 *     + Array fetches
 *     + Array binding
 *     + Bundled calls.
 *
 *    5) PL/SQL blocks are supported, however since all arguments
 *    to REXX functions are passed by value I have not thought of
 *    a suitable method of supporting bind values in PL/SQL blocks
 *    where the bind value is used for output. Input bind values
 *    are supported.
 *
 */

static char RCSid[] = "$Id: ora7.c,v 1.22 2010/09/20 21:43:49 mark Exp $";

#include "rxpack.h"

#define INCL_RXSHV   /* Shared variable support */
#define INCL_RXFUNC  /* External functions support */

#include "dbdefine.h"
#include "rexxsql.h"
#include "dbheader.h"
#include "dbtypes.h"

/*
 * Definition of SQL Work Area (SQLWA).  This contains the ORACLE user
 * context area plus additional information required by this interface to
 * control the processing of SQL statements.
 * Note that the oracle CURSOR structure must be physically the first object
 * in this structure!!
 */

typedef struct {
   CURSOR ora;                                 /* ORACLE cursor area */
   SAVEDSQLSTMT saved_stmt; /* structure to hold SQL statement */
   int select_stmt;       /* 1 if statement is a SELECT, 0 otherwise */
   int bind_cnt;                      /* number of bind values bound */
   int expr_cnt;             /* number of expressions in select list */
   FLDDSCR *fa[MAX_COLS];      /* array of pointers to column dscr's */
   PMDSCR  *pm[MAX_BINDVARS];    /* array of pointers to bind values */
} SQLWA;

/* Connection structure. Each connection requires one of these!
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct
{
   char      name[MAX_IDENTIFIER+1];   /* Connection name */
   CURSOR    lda;       /* Logon Data Area for connection */
   ub1       hda[SIZEOF_HDA];    /* Host Data Area for connection */
   void      *dflt_stmt;      /* Pointer to implicit statement */
   int       num_statements;     /* Number of explicit statements */
   SQLVAL    *db_opt;   /* SqlGetInfo linked list */
} DBCON;

/* Statement structure. Each statement requires one of these!
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct
{
   char      name[MAX_IDENTIFIER+1];   /* Statement name */
   DBCON     *db;       /* Pointer to connection structure */
   SQLWA     sqlwa;        /* SQL Work Area */
   ULONG     Argc;
   RXSTRING  *Argv;
} STMT;

/*
 * Basic REXXSQL environment structure - allocated when 1st connection made!
 */
typedef struct
{
   int       num_connections;    /* Number of active connections */
   DBCON     *current_connection;   /* Pointer to current connection */
   BUCKET    *db_tbl[TBL_CONNECTIONS]; /* Connection hash table */
   BUCKET    *stmt_tbl[TBL_STATEMENTS];/* Statement hash table */
} DBENV;

static char *col_attribute[] =
{
   "NAME", "TYPE", "SIZE", "PRECISION", "SCALE", "NULLABLE", (char *)NULL
};

/* ---------------------------------------------------------------------
 * Error value returned for errors returned by Oracle as opposed to
 * those generated by the interface.
 */
#define DB_ERROR  (-1L)

/* ---------------------------------------------------------------------
 * These globals are constant and are used for NULL column indicators
 * They CAN be global and their use is thread-safe
 */
static const short  not_null = 0;
static const short  is_null = (-1);

static int ValidateDataType Args(( RxPackageGlobalDataDef *, char *, int, DBCON * ));

#include "rxsqlinc1.h"

#if 0
/* ---------------------------------------------------------------------
 * The following table defines those values that can be used with the
 * SQLGetInfo() and SQLSetInfo() functions.
 */
/* name            settable  type         dyn/conn reqd                     maxlen  value func */
static SQLVAL sqlvariable_vars[] =
{
   {NULL,NULL,"DEBUG",                1, TYPE_INT,     OPT_STATIC ,0, NULL,   SQLVAL_DEBUG},
   {NULL,NULL,"DEBUGFILE",            1, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_DEBUGFILE},
   {NULL,NULL,"ROWLIMIT",             1, TYPE_INT,     OPT_STATIC ,0, (void*)&RexxSQLData->RowLimit,0},
   {NULL,NULL,"LONGLIMIT",            1, TYPE_INT,     OPT_STATIC ,0, (void*)&RexxSQLData->LongLimit,0},
   {NULL,NULL,"SAVESQL",              1, TYPE_BOOL,    OPT_STATIC ,0, (void*)&RexxSQLData->SaveSQL,0},
   {NULL,NULL,"AUTOCOMMIT",           1, TYPE_BOOL,    OPT_STATIC ,0, (void*)&RexxSQLData->AutoCommit,0},
   {NULL,NULL,"IGNORETRUNCATE",       1, TYPE_BOOL,    OPT_STATIC ,0, (void*)&RexxSQLData->IgnoreTruncate,0},
   {NULL,NULL,"NULLSTRINGIN",         1, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_NULLSTRINGIN},
   {NULL,NULL,"NULLSTRINGOUT",        1, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_NULLSTRINGOUT},
   {NULL,NULL,"STANDARDPLACEMARKERS", 1, TYPE_BOOL,    OPT_STATIC ,0, (void*)&RexxSQLData->StandardPlacemarkers,0},
   {NULL,NULL,"SUPPORTSDMLROWCOUNT",  0, TYPE_BOOL,    OPT_STATIC ,0, (void*)&RexxSQLData->SupportsDMLRowcount,0},
   {NULL,NULL,"SUPPORTSPLACEMARKERS", 0, TYPE_BOOL,    OPT_STATIC ,0, (void*)&RexxSQLData->SupportsPlacemarkers,0},
   {NULL,NULL,"VERSION",              0, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_VERSION},
   {NULL,NULL,"",                     0, 0,            0          ,0, NULL,0},
};

static SQLVAL sqlgetinfo_vars[] =
{
   {NULL,NULL,"SUPPORTSTRANSACTIONS", 0, TYPE_BOOL,    OPT_STATIC ,0, NULL,   SQLVAL_SUPPORTSTRANSACTIONS},
   {NULL,NULL,"SUPPORTSSQLGETDATA",   0, TYPE_BOOL,    OPT_STATIC ,0, NULL,   SQLVAL_SUPPORTSSQLGETDATA},
   {NULL,NULL,"DESCRIBECOLUMNS",      0, TYPE_ARRAY,   OPT_DYNAMIC,0, NULL,   SQLVAL_DESCRIBECOLUMNS},
   {NULL,NULL,"DATATYPES",            0, TYPE_DATATYPE,OPT_DYNAMIC,0, NULL,   SQLVAL_DATATYPES},
   {NULL,NULL,"DBMSNAME",             0, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_DBMSNAME},
   {NULL,NULL,"DBMSVERSION",          0, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_DBMSVERSION},
   {NULL,NULL,"",                     0, 0,            0          ,0, NULL,0},
};
#endif


/*-----------------------------------------------------------------------------
 * Fetch the DB error and put into REXX "SQLCA." compound variable.
 *----------------------------------------------------------------------------*/
static void SetDBError( RxPackageGlobalDataDef *RxPackageGlobalData, char *file, int lineno, CURSOR *lda, SQLWA *swa )
{
   CURSOR  *cursor=NULL;
   long    sqlcode=0L;
   char    *txt=NULL;
   char    msg[MAX_ERROR_TEXT];

   InternalTrace( RxPackageGlobalData, "SetDbError", "%s,%d,%x,%x", file, lineno, lda, swa );

   cursor = (swa) ? CTX(swa) : lda;

   /* Get the Oracle error code */
   sqlcode = V4ERRORCODE(cursor);

   /* Get the Oracle error message */
   (void)oerhms(lda, V4ERRORCODE(cursor), (text*)msg, sizeof(msg));

   /* Remove trailing newline character */
   msg[strlen(msg)-1] = '\0';

   /* Get the statement text */
   txt = (swa == (SQLWA*)NULL) ? "" : (swa->saved_stmt.sql_stmt) ? swa->saved_stmt.sql_stmt : "";

   /* Set SQLCA. variable */
   SetSQLCA( RxPackageGlobalData, sqlcode, "ZZZZZ", msg, txt );

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

   InternalTrace( RxPackageGlobalData, "AllocateDbEnvironment", NULL);

   if ( ( dbenv = (DBENV*)MALLOC_TSD(  RxPackageGlobalData, sizeof(DBENV) ) ) == (DBENV*)NULL )
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

   InternalTrace( RxPackageGlobalData, "AllocateConnection", "%s", name);

   if ( ( db = (DBCON*)NewObject( RxPackageGlobalData, sizeof(DBCON) ) ) == (DBCON*)NULL )
      return (DBCON*)NULL;
   (void)strncpy(db->name, name, MAX_IDENTIFIER);
   db->dflt_stmt = (void*)NULL;
   db->db_opt = (SQLVAL*)NULL;
   db->num_statements = 0;
   memset( &db->lda, 0, sizeof(CURSOR) );
   return db;
}

/*-----------------------------------------------------------------------------
 * Open a database connection. This requires allocating a connection object
 * and making the connection to Oracle.
 *----------------------------------------------------------------------------*/
static int OpenConnection( RxPackageGlobalDataDef *RxPackageGlobalData, PSZ name, PSZ uid, size_t uidlen, DBCON **new_db )
{
   DBCON   *db=NULL;
   CURSOR  *lda=NULL;
   int     rc=0,i=0;
   void    *result=NULL;
   SQLVAL  *curr=NULL;

   InternalTrace( RxPackageGlobalData, "OpenConnection", "%s,%s,%d,%x", name, uid, uidlen, new_db );

   if ( ( db = AllocConnection( RxPackageGlobalData, name ) ) == (DBCON*)NULL )
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
   lda = &(db->lda);

   /*
    * Do the database-specific connection
    */
   rc = orlon(lda, HDA(db), (ub1*)uid, uidlen, (ub1*)0, -1, 0);
   if (rc)
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, lda, (SQLWA*)NULL);
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }

   /*
    * Setup any connection-specific variable information
    */
   for (i=0;strlen(sqlgetinfo_vars[i].name)!=0;i++)
   {
      if (sqlgetinfo_vars[i].value)
        result = sqlgetinfo_vars[i].value;
      else
        result = GetSqlVariableValue( RxPackageGlobalData, sqlgetinfo_vars[i].valtype, (void*)db );
      if ((curr = InstallSQLVariable( RxPackageGlobalData,
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
      if (db->db_opt == NULL)
        db->db_opt = curr;
   }
   *new_db = db;
   return 0;
}

/*-----------------------------------------------------------------------------
 * Allocate a STMT object. One of these is required for each statement
 * including the default statement for a connection. An instance of this object
 * is allocated when (i) a statement is prepared & (ii) the first time
 * SQLCOMMAND() is called for a connection (ie. the default statement is used).
 *----------------------------------------------------------------------------*/
static STMT *AllocStatement( RxPackageGlobalDataDef *RxPackageGlobalData, char *name, DBCON *db )
{
   STMT    *stmt=NULL;
   SQLWA   *swa=NULL;
   int     i=0;

   InternalTrace( RxPackageGlobalData, "AllocateStatement", "%s,%x", name, db );

   if ( ( stmt = (STMT*)NewObject( RxPackageGlobalData, sizeof(STMT) ) ) == (STMT*)NULL )
      return (STMT*)NULL;
   stmt->db = db;
   (void)strncpy(stmt->name, name, MAX_IDENTIFIER);

   /* Initialise SQL Work Area */
   swa = SWA(stmt);
   swa->bind_cnt = 0;
   swa->expr_cnt = 0;
   memset( &(swa->saved_stmt), 0, sizeof(SAVEDSQLSTMT) );

   stmt->Argc = 0L;
   stmt->Argv = NULL;

   /*
    * Set pointer for each column descriptor to NULL (unused)
    */
   for (i = 0; i < MAX_COLS; i++)
     swa->fa[i] = (FLDDSCR*)NULL;

   /*
    * Create bind value arrays (empty)
    */
   for (i = 0; i < MAX_BINDVARS; i++)
     swa->pm[i] = (PMDSCR*)NULL;

   return stmt;
}

/*-----------------------------------------------------------------------------
 * Open a statement. This allocates a statement & then opens an Oracle cursor
 * (also called a context area).
 *----------------------------------------------------------------------------*/
static int OpenStatement( RxPackageGlobalDataDef *RxPackageGlobalData, char *name, DBCON *db, STMT **new_stmt )
{
   int     rc=0;
   STMT    *stmt=NULL;
   SQLWA   *swa=NULL;

   InternalTrace( RxPackageGlobalData, "OpenStatement", "%s,%x,%x", name, db, new_stmt );

   if ( ( stmt = AllocStatement( RxPackageGlobalData, name, db ) ) == (STMT*)NULL )
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));

   /* Open the Oracle cursor */
   swa = SWA(stmt);
   if ((rc = oopen(CTX(swa), LDA(stmt), (ub1*)-1, -1, -1, (ub1*)-1, -1)))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), (SQLWA*)NULL);
      FreeObject( RxPackageGlobalData, stmt );
   }

   *new_stmt = stmt;
   return (rc==0) ? 0 : DB_ERROR;
}

/*-----------------------------------------------------------------------------
 * Disposes a SQL statement. This closes the Oracle cursor and frees the
 * statement structure and all resources associated with it.
 *----------------------------------------------------------------------------*/
static int ReleaseStatement( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt )
{
   SQLWA    *swa = SWA(stmt);
   FLDDSCR  *fd=NULL;
   PMDSCR   *pmd=NULL;
   int     rc=0, i=0;

   InternalTrace( RxPackageGlobalData, "ReleaseStatement", "%x", stmt );

   /*
    * Close Oracle cursor
    */
   if ((rc = oclose(CTX(swa))))
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);

   /*
    * Free up select column descriptors
    */
   for ( i = 0; i < MAX_COLS; i++ )
   {
      fd = swa->fa[i];
      if ( fd == NULL )
         break;

      if ( fd->rbuf )
         FREE_TSD( RxPackageGlobalData, fd->rbuf);
      if ( fd->cbuf )
         FREE_TSD( RxPackageGlobalData, fd->cbuf);
      FREE_TSD( RxPackageGlobalData, fd);
      swa->fa[i] = NULL;
   }

   /*
    * Free up parameter marker descriptors
    */
   for (i = 0; i < MAX_BINDVARS; i++)
   {
      pmd = swa->pm[i];
      if ( pmd == NULL )
         break;
      if ( pmd->buf )
         FREE_TSD( RxPackageGlobalData, pmd->buf);
      FREE_TSD( RxPackageGlobalData, pmd);
      swa->pm[i] = NULL;
   }

   /*
    * Free sql statement buffer (if any)
    */
   if ( swa->saved_stmt.sql_stmt )
   {
      FREE_TSD( RxPackageGlobalData, swa->saved_stmt.sql_stmt);
      memset( &(swa->saved_stmt), 0, sizeof(SAVEDSQLSTMT) );
   }

   /*
    * Free the input bind values (if any)
    */
   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
   FreeObject( RxPackageGlobalData, stmt );

   return (rc==0) ? 0 : DB_ERROR;
}

/*-----------------------------------------------------------------------------
 * Release an Oracle connection. This closes any open statements associated
 * with the connection, closes the connection and frees all resources
 * associated with it.
 *----------------------------------------------------------------------------*/
static int ReleaseConnection( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   int    i=0, rc=0, last_error=0;
   STMT   *stmt=NULL, *t=NULL;
   CURSOR *lda = &(db->lda);
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
   for (i = 0; db->num_statements && i < TBL_STATEMENTS; i++)
   {
     stmt = (STMT*)FirstObject( RxPackageGlobalData, i, RexxSQLData->DbEnv->stmt_tbl );
     while (stmt && db->num_statements)
     {
        t = (STMT*)NextObject( RxPackageGlobalData, stmt );
        if (stmt->db == db)
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
    db->db_opt = ll_free( RxPackageGlobalData, db->db_opt );

   /*
    * Dispose the default statement (if any).
    */
   if (db->dflt_stmt)
      last_error = (rc = ReleaseStatement( RxPackageGlobalData, (STMT*)(db->dflt_stmt) )) ? rc : last_error;

   /*
    * Disconnect from Oracle
    */
   if ((rc = ologof(lda)))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, lda, (SQLWA*)NULL);
      last_error = rc;
   }
   memset( lda, 0, sizeof(CURSOR) );

   /*
    * Free the connection structure
    */
   FreeObject( RxPackageGlobalData, db );

   return (last_error);
}

/*-----------------------------------------------------------------------------
 * Release the Oracle environment. This releases all active connections
 * (if any).
 *----------------------------------------------------------------------------*/
int ReleaseDbEnvironment( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   int    i=0, rc=0, last_error=0;
   DBCON  *db=NULL, *t=NULL;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "ReleaseDbEnvironment", NULL );

   /* Ensure there is an environment to release! */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
      return 0;

   /* Release all connections. */
   for (i = 0; RexxSQLData->DbEnv->num_connections && i < TBL_CONNECTIONS; i++)
   {
      db = (DBCON*)FirstObject( RxPackageGlobalData, i, RexxSQLData->DbEnv->db_tbl );
      while (db && RexxSQLData->DbEnv->num_connections)
      {
         t = (DBCON*)NextObject( RxPackageGlobalData, db );
         last_error = (rc = ReleaseConnection( RxPackageGlobalData, db )) ? rc : last_error;
         db = t;
      }
   }

   /* Free the DB environment */
   FREE_TSD( RxPackageGlobalData, RexxSQLData->DbEnv);
   RexxSQLData->DbEnv = (DBENV*)NULL;

   return (last_error);
}

/*-----------------------------------------------------------------------------
 * Convert "standard" parameter markers; ? with Oracle's :1 -> :n
 * placemarkers.
 *----------------------------------------------------------------------------*/
static char *ConvertPlacemarkers( RxPackageGlobalDataDef *RxPackageGlobalData, char *stmt, int len, int *new_len )
{
   int num_placemarkers=0;
   int placemarker=1;
   int i,j,k;
   int new_size;
   char buf[15];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "ConvertPlacemarkers", "Starting: Stmt: \"%s\" Len: %d", stmt, len );

   for ( i = 0; i < len; i++ )
   {
      if ( stmt[i] == '?' )
        num_placemarkers++;
   }

   new_size = (10+len+(num_placemarkers*4));
   if ( new_size > RexxSQLData->converted_stmt_len )
   {
      /* New statement size is > than previous */
      if ( RexxSQLData->converted_stmt != (char*)NULL )
      {
         /* Free old statement */
         FREE_TSD( RxPackageGlobalData, RexxSQLData->converted_stmt );
         RexxSQLData->converted_stmt = (char*)NULL;
         RexxSQLData->converted_stmt_len = 0;
      }

      /* Allocate a buffer for the new statement */
      if ( ( RexxSQLData->converted_stmt = (char*)MALLOC_TSD(  RxPackageGlobalData, new_size ) ) == (char*)NULL )
         return(NULL);
      RexxSQLData->converted_stmt_len = new_size;
   }

   for ( i = 0, j = 0; i < len; i++ )
   {
      if (stmt[i] == '?')
      {
         RexxSQLData->converted_stmt[j++] = ':';
         sprintf( buf, "%d", placemarker++ );
         for ( k = 0; k < (int)strlen(buf); k++ )
            RexxSQLData->converted_stmt[j++] = buf[k];
      }
      else
      {
        RexxSQLData->converted_stmt[j++] = stmt[i];
      }
   }

   RexxSQLData->converted_stmt[j] = '\0';
   *new_len = j;

   InternalTrace( RxPackageGlobalData, "ConvertPlacemarkers", "Returning: Stmt: \"%s\" new_len: %d", RexxSQLData->converted_stmt, *new_len );

   return(RexxSQLData->converted_stmt);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLCONNECT( [connection-name, ] [username], [password], [database name], [host])
 *
 * ARGUMENTS:
 *            0 - connection_name (optional)
 *            1 - username (optional)
 *            2 - password (optional)
 *            3 - database name (ignored under Oracle)
 *            4 - host name (optional)
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLCONNECT )
{
   char   uid[256];
   int    uidlen=0;
   char   dbname[MAX_IDENTIFIER+1];
   int    rc=0;
   char   tmp[128];
   DBCON  *db=NULL;
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

   /* Allocate a DB environment if none exists! */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
   {
      if ( ( RexxSQLData->DbEnv = AllocDbEnvironment( RxPackageGlobalData ) ) == (DBENV*)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory." );
   }
   switch(argc)
   {
      case 0:
      case 1:
         RXSTRCPY(uid,uidlen,"/",1);
         break;
      case 2:
         if (RXSTRLEN(argv[1]))
         {
            RXSTRCPY(uid,uidlen,RXSTRPTR(argv[1]),RXSTRLEN(argv[1]));
         }
         else
         {
            RXSTRCPY(uid,uidlen,"/",1);
         }
         break;
      case 4:
      case 5:
         if ( RXSTRLEN(argv[3]) )
         {
            (void)sprintf(tmp, "extraneous parameter <database name> value of \"%s\".", RXSTRPTR(argv[3]) );
            return ReturnError( RxPackageGlobalData, retstr, 18, tmp );
         }
         /* meant to fall through */
      case 3:
         RXSTRCPY(uid,uidlen,RXSTRPTR(argv[1]),RXSTRLEN(argv[1]));
         RXSTRCAT(uid,uidlen,"/",1);
         RXSTRCAT(uid,uidlen,RXSTRPTR(argv[2]),RXSTRLEN(argv[2]));
         if (argc == 5
         &&  RXSTRLEN(argv[4]))
         {
            if (*(RXSTRPTR(argv[4])) != '@')
               RXSTRCAT(uid,uidlen,"@",1);
            RXSTRCAT(uid,uidlen,RXSTRPTR(argv[4]),RXSTRLEN(argv[4]));
         }
         break;
   }
#if REXXSQL_12_CODE
   /*
    * If a name is given then it is arg#1 and the connect string
    * is arg#2. If no name is given then connect-string is arg#1 unless
    * both name & connect-string are omitted.
    */
   if (argc == 0)
   {
      uid = "/";
      uidlen = 1;
   }
   else
   {
      if (argc == 1)
      {
         uid = RXSTRPTR(argv[0]);
         uidlen = RXSTRLEN(argv[0]);
      }
      else
      {
         uid = RXSTRPTR(argv[1]);
         uidlen = RXSTRLEN(argv[1]);
      }
   }
#endif

   /*
    * If a name is given it is the first argument!/
    * Get the name of the connection (default if not specified).
    */
   if (argc > 1 && RXSTRLEN(argv[0]))
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], dbname, sizeof(dbname) ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc);
   }
   else
   {
      (void)strcpy(dbname, DEFAULT_CONNECTION);
   }

   /* Make sure there is no existing connection with the same name */
   if ( FindObject( RxPackageGlobalData, dbname, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS ) )
   {
      (void)sprintf(tmp, "connection already open with name \"%s\".", dbname);
      return ReturnError( RxPackageGlobalData, retstr, 20, tmp );
   }

   /* Open a new connection for the given connect string. */
   if ( ( rc = OpenConnection( RxPackageGlobalData, dbname, uid, uidlen, &db ) ) )
       return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

   RexxSQLData->DbEnv->num_connections++;
   RexxSQLData->DbEnv->current_connection = db;
   (void)InsertObject( RxPackageGlobalData, db, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS );

   return RxReturnNumber( RxPackageGlobalData, retstr, 0L);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDISCONNECT( [connection-name ] )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLDISCONNECT )
{
   int       rc = 0;
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

   if (RexxSQLData->DbEnv == (DBENV*)NULL)
       return RxReturnNumber( RxPackageGlobalData, retstr, 0L);

   if (argc && RXSTRLEN(argv[0]))
   {
      /* A connection has been named */
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], dbname, sizeof(dbname) ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc);

      /* Make sure the named connection exists. */
      if ( ( db = FindObject( RxPackageGlobalData, dbname, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS ) ) == (DBCON*)NULL )
      {
         (void)sprintf(tmp,"connection \"%s\" is not open.", dbname);
         return ReturnError( RxPackageGlobalData, retstr, 21, tmp );
      }
   }
   else
   {
      if (RexxSQLData->DbEnv->current_connection)
         db = RexxSQLData->DbEnv->current_connection;
      else
         return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );
   }
   /*
    * If terminating the current connection then make it so there is
    * no current connection!
    */
   if (db == RexxSQLData->DbEnv->current_connection)
       RexxSQLData->DbEnv->current_connection = (DBCON*)NULL;

   /* Do the disconnection */
   rc = ReleaseConnection( RxPackageGlobalData, db );

   /* Free the environment if zero connections remaining */
   if (RexxSQLData->DbEnv->num_connections == 0)
   {
      FREE_TSD( RxPackageGlobalData, RexxSQLData->DbEnv);
      RexxSQLData->DbEnv = (DBENV*)NULL;
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
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

   if (argc && RXSTRLEN(argv[0]))
   {
      /* Get the normalised name of the connection. */
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], dbname, sizeof(dbname) ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc);

      /* Make sure we have an environment! */
      if (RexxSQLData->DbEnv == (DBENV*)NULL)
         return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

      /* Make sure the Connection Name is a valid one! */
      if ( ( db = FindObject( RxPackageGlobalData, dbname, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS ) ) == (DBCON*)NULL )
      {
         (void)sprintf(tmp,"connection \"%s\" is not open.", dbname);
         return ReturnError( RxPackageGlobalData, retstr, 21, tmp );
      }

      /* Make connection the default one! */
      RexxSQLData->DbEnv->current_connection = db;

      return RxReturnNumber( RxPackageGlobalData, retstr, 0L);
   }
   else
   {
      if (RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection)
      {
         return RxReturnString( RxPackageGlobalData, retstr,RexxSQLData->DbEnv->current_connection->name);
      }
      else
      {
         return RxReturnString( RxPackageGlobalData, retstr, "");
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
   int         rc = 0;
   DBCON       *db=NULL;
   CURSOR      *lda=NULL;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if (argc > 1) return 1;

   if (RexxSQLData->DbEnv == (DBENV*)NULL)
       return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

   if (RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   lda = &(db->lda);

   if ((rc = (commit) ? ocom(lda) : orol(lda)))
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, lda, (SQLWA*)NULL);

   return RxReturnNumber( RxPackageGlobalData, retstr, (rc==0)?0:DB_ERROR);
}

/*-----------------------------------------------------------------------------
 * Binds all arguments for standard placemarkers (by number)
 *----------------------------------------------------------------------------*/
static int BindByStandard( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt,ULONG argc,RXSTRING argv[] )
{
   int     i=0,file_bind=0,bind_type=0;
   int     rc=0, bindlen=0;
   short   *indp=NULL;
   char    tmp[128];
   SQLWA   *swa= SWA(stmt);
   PMDSCR  *pmd=(PMDSCR*)NULL;
   FILE    *fp=NULL;
   struct stat stat_buf;
   RXSTRING *Varg=NULL, *Darg=NULL;
   int     colno=0;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "BindByStandard", "%x,%d,%x", stmt, argc, argv );

   /*
    * For StandardPlacemarkers, each second parameter is ignored, as
    * Oracle knows the datatype of the bind value. Except for FILE.
    */
   if ( argc % 2 )
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 62, "bind values must be paired" ));

   /*
    * Bind all variables (if any) to placeholders in SQL statement. It is
    * assumed that the variables are static for the life of the SQL statement
    * i.e. their addresses remain fixed.
    */
   for ( i = 0, colno = 0; i < (int)argc && colno < MAX_BINDVARS; colno++ )
   {
      Darg = &argv[i++];
      Varg = &argv[i++];
      /*
       * Get the parameter marker descriptor
       */
      if ( swa->pm[colno] == (PMDSCR*)NULL )
      {
         if ( ( pmd = (swa->pm[colno] = (PMDSCR*)MALLOC_TSD(  RxPackageGlobalData, sizeof(PMDSCR) ) ) ) == (PMDSCR*)NULL )
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
         pmd->buf = (ub1*)NULL;
         pmd->buflen = 0;
         pmd->valuelen = 0;
      }
      else
         pmd = swa->pm[colno];
      /*
       * Check bind value type. If "FILE:", then get bind value from
       * the filename.
       */
      file_bind = 0;
      if ( memcmpi( RxPackageGlobalData, RXSTRPTR(*Darg), "FILE:", 5 ) == 0 )
      {
         ub1 *ptr = (ub1 *)RXSTRPTR(*Darg);
         bind_type = ValidateDataType( RxPackageGlobalData, (char*)(ptr+5), RXSTRLEN(*Darg)-5, stmt->db );
         if ( bind_type == (RXSQL_INVALID_DATATYPE) )
         {
            sprintf( tmp, "invalid datatype <%s> specified.", (ptr+5) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 64, tmp ));
         }
         file_bind = 1;
      }
      else
      {
         bind_type = ValidateDataType( RxPackageGlobalData, RXSTRPTR(*Darg), RXSTRLEN(*Darg), stmt->db );
         if ( bind_type == (RXSQL_INVALID_DATATYPE) )
         {
            sprintf( tmp, "invalid datatype <%s> specified.", RXSTRPTR(*Darg) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 64, tmp ));
         }
      }
      if ( file_bind )
      {
         if ( ( fp = fopen( RXSTRPTR(*Varg), "rb" ) ) == NULL )
         {
            sprintf( tmp, "<open> on file <%s> failed: %s.", RXSTRPTR(*Varg), strerror(errno) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp ));
         }
         stat( RXSTRPTR(*Varg), &stat_buf );
         bindlen = (int)stat_buf.st_size;
         /*
          * In an attempt to save malloc() & free() calls we keep the old
          * buffer providing it is not grossly oversized.
          */
         if ( (size_t)pmd->buflen < (size_t)bindlen
         ||   (size_t)pmd->buflen > (size_t)(bindlen + 256) )
         {
            /* Free the old buffer (if any) */
            if ( pmd->buf )
            {
               FREE_TSD( RxPackageGlobalData, pmd->buf);
               pmd->buflen = 0;
               pmd->buf = NULL;
            }
            /* Allocate a new buffer */
            if ( ( pmd->buf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, bindlen+1 ) ) == (ub1*)NULL )
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
            pmd->buflen = bindlen;
         }
         pmd->valuelen = bindlen;
         if ( fseek( fp, 0L, SEEK_SET ) != 0 )
         {
            sprintf( tmp, "<read> on file <%s> failed: %s.", RXSTRPTR(*Varg), strerror(errno) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp ));
         }
         if ( (int)fread( pmd->buf, sizeof(ub1), bindlen, fp ) != bindlen )
         {
            sprintf( tmp, "<seek> on file <%s> failed: %s.", RXSTRPTR(*Varg), strerror(errno) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp ));
         }
         if ( fclose( fp ) )
         {
            sprintf( tmp, "<close> on file <%s> failed: %s.", RXSTRPTR(*Varg), strerror(errno) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp ));
         }
         if ( ( memcmp( (char*)pmd->buf, RexxSQLData->NullStringIn, bindlen ) ) == 0 )
            /* indicate a NULL value */
            indp = (short*)&is_null;
         else
            indp = (short*)&not_null;
      }
      else
      {
         /*
          * In an attempt to save malloc() & free() calls we keep the old
          * buffer providing it is not grossly oversized.
          */
         if ( (size_t)pmd->buflen < RXSTRLEN(*Varg)
         ||   (size_t)pmd->buflen > RXSTRLEN(*Varg) + 256 )
         {
            /* Free the old buffer (if any) */
            if ( pmd->buf )
            {
               FREE_TSD( RxPackageGlobalData, pmd->buf );
               pmd->buflen = 0;
               pmd->buf = NULL;
            }
            /* Allocate a new buffer */
            if ( ( pmd->buf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, RXSTRLEN(*Varg)+1 ) ) == (ub1*)NULL )
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
            pmd->buflen = RXSTRLEN(*Varg);
         }
         pmd->valuelen = RXSTRLEN(*Varg);
         memcpy( (char*)pmd->buf, RXSTRPTR(*Varg), RXSTRLEN(*Varg) );
         if ( memcmp( RXSTRPTR(*Varg), RexxSQLData->NullStringIn, RXSTRLEN(*Varg) ) == 0 )
            /* indicate a NULL value */
            indp = (short*)&is_null;
         else
            indp = (short*)&not_null;
      }
      switch( bind_type )
      {
         case ORA_RAW:
         case ORA_LONGRAW:
            bind_type = EXT_LONGRAW;
            break;
         default:
            bind_type = EXT_LONG;
            break;
      }
      InternalTrace( RxPackageGlobalData, "BindByStandard", "ColNo: %d Arg: \"%s\" Len: %d Type: %d", colno+1, (char *)pmd->buf, pmd->valuelen, bind_type );
      if ( ( rc = obndrn(CTX(swa), (int)colno+1, pmd->buf, pmd->valuelen, bind_type,
                                            -1, indp, (ub1*)-1, -1, -1) ) )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa );
         return DB_ERROR;
      }
   }

   /*
    * If previous bind count is non-zero (i.e. a previous bind for
    * this statement then check all values are re-bound.
    */
   if ( swa->bind_cnt && colno < swa->bind_cnt )
   {
      (void)sprintf( tmp, "%d bind values passed. %d expected", colno, swa->bind_cnt );
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 61, tmp ));
   }

   /*
    * save the new bind count
    */
   swa->bind_cnt = colno;

   return (int)FunctionEpilogue( RxPackageGlobalData, "BindByStandard", (long)0 );
}

/*-----------------------------------------------------------------------------
 * Binds all arguments (by number) to the parsed (prepared) SQL statement.
 *----------------------------------------------------------------------------*/
static int BindByNumber( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt,ULONG argc,RXSTRING argv[] )
{
   int     i=0;
   int     rc=0, bindlen=0;
   void    *bindaddr=NULL;
   short   *indp=NULL;
   char    tmp[128];
   SQLWA   *swa= SWA(stmt);
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "BindByNumber", "%x,%d,%x", stmt, argc, argv );

   /*
    * Bind all variables (if any) to placeholders in SQL statement. It is
    * assumed that the variables are static for the life of the SQL statement
    * i.e. their addresses remain fixed.
    */
   for ( i = 0; i != (int)argc && i < MAX_BINDVARS; i++ )
   {
      if ( memcmp( RXSTRPTR(argv[i]), RexxSQLData->NullStringIn, RXSTRLEN(argv[i]) ) == 0 )
      {
         /* indicate a NULL value */
         bindaddr = (void*)NULL;
         bindlen = 0;
         indp = (short*)&is_null;
      }
      else
      {
         bindaddr = (void*)RXSTRPTR(argv[i]);
         bindlen = (int)RXSTRLEN(argv[i]);
         indp = (short*)&not_null;
      }
      InternalTrace( RxPackageGlobalData, "BindByNumber", "ArgNo: %d Arg: \"%s\" Len: %d", i, (char *)bindaddr, bindlen );
      if ((rc = obndrn(CTX(swa), (int)i+1, bindaddr, bindlen, EXT_VARCHAR2,
                                            -1, indp, (ub1*)-1, -1, -1)))
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
         return DB_ERROR;
      }
   }

   /*
    * If previous bind count is non-zero (i.e. a previous bind for
    * this statement then check all values are re-bound.
    */
   if (swa->bind_cnt && i < swa->bind_cnt)
   {
      (void)sprintf(tmp, "%d bind values passed. %d expected", i, swa->bind_cnt);
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 61, tmp ));
   }

   /* save the new bind count */
   swa->bind_cnt = i;

   return (int)FunctionEpilogue( RxPackageGlobalData, "BindByNumber", (long)0 );
}

/*-----------------------------------------------------------------------------
 * Binds all arguments (by name) to the parsed (prepared) SQL statement.
 *----------------------------------------------------------------------------*/
static int BindByName( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt,ULONG argc,RXSTRING argv[] )
{
   SQLWA         *swa= SWA(stmt);
   RXSTRING      *Varg=NULL, *Narg=NULL;
   int           i=0, j=0, colno=0;
   int           file_bind=0,bind_type=0;
   int           rc=0, bindlen=0;
   short         *indp=NULL;
   PMDSCR        *pmd=(PMDSCR*)NULL;
   FILE          *fp=NULL;
   struct stat   stat_buf;
   char          tmp[128];
   char          name[MAX_IDENTIFIER+1];
   char          type[MAX_IDENTIFIER+1];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "BindByName", "%x,%d,%x", stmt, argc, argv );

   /*
    * Bind all variables (if any) to placeholders in SQL statement. It is
    * assumed that the variables are static for the life of the SQL statement
    * i.e. their addresses remain fixed.
    */
   if ( argc % 2 )
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 62, "bind values must be paired" ));

   for ( i = 0, colno = 0; i < (int)argc && colno < MAX_BINDVARS; colno++ )
   {
      Narg = &argv[i++];
      Varg = &argv[i++];
      memcpy( type, RXSTRPTR(*Narg), RXSTRLEN(*Narg) );
      type[RXSTRLEN(*Narg)] = '\0';
      strcpy( name, "" );
      /*
       * Substitution variables can be of the following formats:
       *   :name
       *   type:name
       *   file:type:name
       */
      /*
       * Get the parameter marker descriptor
       */
      if ( swa->pm[colno] == (PMDSCR*)NULL )
      {
         if ( ( pmd = (swa->pm[colno] = (PMDSCR*)MALLOC_TSD(  RxPackageGlobalData, sizeof(PMDSCR) ) ) ) == (PMDSCR*)NULL )
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
         pmd->buf = (ub1*)NULL;
         pmd->buflen = 0;
         pmd->valuelen = 0;
      }
      else
         pmd = swa->pm[colno];
      /*
       * Extract the bind name from the bind variable first
       */
      for ( j = (RXSTRLEN(*Narg))-1; j > -1; j-- )
      {
         if ( type[j] == ':' )
         {
            if ( j == 0 )
            {
               strcpy( name, type );
               strcpy( type, "" );
            }
            else
            {
               memcpy( name, type+j, (RXSTRLEN(*Narg))-j );
               name[(RXSTRLEN(*Narg))-j] = '\0';
               type[j] = '\0';
            }
            break;
         }
      }
      if ( strlen( name ) == 0 )
      {
         (void)sprintf( tmp, "invalid substitution variable name at bind pair %d.", colno );
         return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 63, tmp ));
      }
      /*
       * Check bind value type. If it starts with "FILE:", then get bind value from
       * the filename.
       */
      file_bind = 0;
      if ( strlen( type ) == 0 )
      {
         bind_type = EXT_VARCHAR2;
      }
      else if ( memcmpi( RxPackageGlobalData, RXSTRPTR(*Narg), "FILE:", 5 ) == 0 )
      {
         bind_type = ValidateDataType( RxPackageGlobalData, (char*)(type+5), strlen((char*)type+5), stmt->db );
         if ( bind_type == (RXSQL_INVALID_DATATYPE) )
         {
            sprintf( tmp, "invalid datatype <%s> specified.", (type+5) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 64, tmp ));
         }
         file_bind = 1;
      }
      else
      {
         bind_type = ValidateDataType( RxPackageGlobalData, type, strlen((char*)type), stmt->db );
         if ( bind_type == (RXSQL_INVALID_DATATYPE) )
         {
            sprintf( tmp, "invalid datatype <%s> specified.", RXSTRPTR(*Narg) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 64, tmp ));
         }
      }

      if ( file_bind )
      {
         if ( ( fp = fopen( RXSTRPTR(*Varg), "rb" ) ) == NULL )
         {
            sprintf( tmp, "<open> on file <%s> failed: %s.", RXSTRPTR(*Varg), strerror(errno) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp ));
         }
         stat( RXSTRPTR(*Varg), &stat_buf );
         bindlen = (int)stat_buf.st_size;
         /*
          * In an attempt to save malloc() & free() calls we keep the old
          * buffer providing it is not grossly oversized.
          */
         if ( (size_t)pmd->buflen < (size_t)bindlen
         ||   (size_t)pmd->buflen > (size_t)(bindlen + 256) )
         {
            /* Free the old buffer (if any) */
            if ( pmd->buf )
            {
               FREE_TSD( RxPackageGlobalData, pmd->buf);
               pmd->buflen = 0;
               pmd->buf = NULL;
            }
            /* Allocate a new buffer */
            if ( ( pmd->buf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, bindlen+1 ) ) == (ub1*)NULL )
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
            pmd->buflen = bindlen;
         }
         pmd->valuelen = bindlen;
         if ( fseek( fp, 0L, SEEK_SET ) != 0 )
         {
            sprintf( tmp, "<read> on file <%s> failed: %s.", RXSTRPTR(*Varg), strerror(errno) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp ));
         }
         if ( (int)fread( pmd->buf, sizeof(ub1), bindlen, fp ) != bindlen )
         {
            sprintf( tmp, "<seek> on file <%s> failed: %s.", RXSTRPTR(*Varg), strerror(errno) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp ));
         }
         if ( fclose( fp ) )
         {
            sprintf( tmp, "<close> on file <%s> failed: %s.", RXSTRPTR(*Varg), strerror(errno) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp ));
         }
         if ( ( memcmp( (char*)pmd->buf, RexxSQLData->NullStringIn, bindlen ) ) == 0 )
            /* indicate a NULL value */
            indp = (short*)&is_null;
         else
            indp = (short*)&not_null;
      }
      else
      {
         /*
          * In an attempt to save malloc() & free() calls we keep the old
          * buffer providing it is not grossly oversized.
          */
         if ( (size_t)pmd->buflen < RXSTRLEN(*Varg)
         ||   (size_t)pmd->buflen > RXSTRLEN(*Varg) + 256 )
         {
            /* Free the old buffer (if any) */
            if ( pmd->buf )
            {
               FREE_TSD( RxPackageGlobalData, pmd->buf );
               pmd->buflen = 0;
               pmd->buf = NULL;
            }
            /* Allocate a new buffer */
            if ( ( pmd->buf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, RXSTRLEN(*Varg)+1 ) ) == (ub1*)NULL )
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
            pmd->buflen = RXSTRLEN(*Varg);
         }
         pmd->valuelen = RXSTRLEN(*Varg);
         memcpy( (char*)pmd->buf, RXSTRPTR(*Varg), RXSTRLEN(*Varg) );
         if ( memcmp( RXSTRPTR(*Varg), RexxSQLData->NullStringIn, RXSTRLEN(*Varg) ) == 0 )
            /* indicate a NULL value */
            indp = (short*)&is_null;
         else
            indp = (short*)&not_null;
      }
      switch( bind_type )
      {
         case ORA_RAW:
         case ORA_LONGRAW:
            bind_type = EXT_LONGRAW;
            break;
         default:
            bind_type = EXT_VARCHAR2;
            break;
      }
      InternalTrace( RxPackageGlobalData, "BindByName", "ColNo: %d Arg: \"%s\" Len: %d Type: %d", colno+1, (char *)pmd->buf, pmd->valuelen, bind_type );

      if ( ( rc = obndrv( CTX(swa), (ub1*)name, (int)strlen(name),
                           pmd->buf, pmd->valuelen, bind_type, -1, indp,
                           (ub1*)-1, -1, -1) ) )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa );
         return DB_ERROR;
      }
   }

   /*
    * If previous bind count is non-zero (i.e. a previous bind for
    * this statement then check all values are re-bound.
    */
   if ( swa->bind_cnt && colno < swa->bind_cnt )
   {
      (void)sprintf( tmp, "%d bind values passed. %d expected", colno, swa->bind_cnt );
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 61, tmp ));
   }

   /* save the new bind count */
   swa->bind_cnt = colno;

   return (int)FunctionEpilogue( RxPackageGlobalData, "BindByName", (long)0 );
}

/*-----------------------------------------------------------------------------
 * This function binds all values (supplied as a list of arguments) to
 * the specified cursor. Two types of binding are supported:
 * (i)  By Name - This is the DEFAULT. Each bind value is a pair of consecutive
 *      arguments the first being the name of the substitution variable
 *      (placeholder) complete with a leading colon (":") and the second is
 * the value to be bound.
 * (ii) By Number - First arg must be the token '#' anything else defaults
 *      By Name. Args are bound to placeholders in the order supplied, one
 *      argument per placeholder.
 *
 *   Parameters            Bind Type      Using Array?   Number Params
 *  ------------------------------------------------------------------
 *  '#','a','b','c',...     name             no              ?
 *  '.','a.','b.'           name             yes             3
 *  ':a','a',':b','b',...   number           no              ?
 *  '.','a.'                number           yes             2
 *  'a','b',...             standard         no              ?
 *  'a.','b.'               standard         yes             2
 *----------------------------------------------------------------------------*/
static int BindValues( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt,ULONG argc,RXSTRING argv[] )
{
#define BIND_BY_NAME     1
#define BIND_BY_NUMBER   2
#define BIND_BY_STANDARD 3
   int bind_by_array=0,bind_type=0;
   int arglen1=0,arglen2=0;
   int rc=0;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "BindValues", "%x,%d,%x", stmt, argc, argv );

   if ( RexxSQLData->StandardPlacemarkers )
   {
      bind_type = BIND_BY_STANDARD;
      if ( ( stmt->Argv = (RXSTRING*)MALLOC_TSD(  RxPackageGlobalData, 2*MAX_BINDVARS*sizeof(RXSTRING) ) ) == NULL )
         return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
      memset( stmt->Argv, 0, 2 * MAX_BINDVARS * sizeof(RXSTRING) );
      if ( argc == 2 )
      {
         arglen1 = RXSTRLEN(argv[0]);
         arglen2 = RXSTRLEN(argv[1]);
         if ( arglen1 && *(RXSTRPTR(argv[0])+arglen1-1) == '.'
         &&   arglen2 && *(RXSTRPTR(argv[1])+arglen2-1) == '.' )
         {
            bind_by_array = 1;
            if ( ( rc = ArrayToArgv( RxPackageGlobalData, &(argv[0]), &(argv[1]), &stmt->Argc, stmt->Argv ) ) != 0 )
            {
               stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
               return (int)FunctionEpilogue( RxPackageGlobalData, "BindValues", (long)rc );
            }
         }
         else
         {
            if ( ArgvToArgv( RxPackageGlobalData, argc, argv, &stmt->Argc, stmt->Argv ) )
            {
               stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
            }
         }
      }
      else
      {
         if ( ArgvToArgv( RxPackageGlobalData, argc, argv, &stmt->Argc, stmt->Argv ) )
         {
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
         }
      }
   }
   else
   {
      if ( ( stmt->Argv = (RXSTRING*)MALLOC_TSD(  RxPackageGlobalData, 2*MAX_BINDVARS*sizeof(RXSTRING) ) ) == NULL )
         return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
      memset( stmt->Argv, 0, 2 * MAX_BINDVARS * sizeof(RXSTRING) );
      if ( RXSTRLEN(argv[0]) == 1 && *(RXSTRPTR(argv[0])) == '#' )
      {
         bind_type = BIND_BY_NUMBER;
         if ( ArgvToArgv( RxPackageGlobalData, --argc, &argv[1], &stmt->Argc, stmt->Argv ) )
         {
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
         }
      }
      else
      {
         if ( RXSTRLEN(argv[0]) == 1 && *(RXSTRPTR(argv[0])) == '.' )
         {
            /*
             * Binding with arrays (by name or number)
             */
            bind_by_array = 1;
            if ( argc == 2 )
            {
               bind_type = BIND_BY_NUMBER;
               arglen1 = RXSTRLEN(argv[1]);
               if ( arglen1 && *(RXSTRPTR(argv[1])+arglen1-1) == '.' )
               {
                  if ( ( rc = ArrayToArgv( RxPackageGlobalData, &(argv[1]), NULL, &stmt->Argc, stmt->Argv ) ) != 0 )
                  {
                     stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
                     return (int)FunctionEpilogue( RxPackageGlobalData, "BindValues", (long)rc );
                  }
               }
               else
               {
                  if ( ArgvToArgv( RxPackageGlobalData, argc, argv, &stmt->Argc, stmt->Argv ) )
                  {
                     stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
                     return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
                  }
               }
            }
            else
            {
               if ( argc == 3 )
               {
                  bind_type = BIND_BY_NAME;
                  arglen1 = RXSTRLEN(argv[1]);
                  arglen2 = RXSTRLEN(argv[2]);
                  if ( arglen1 && *(RXSTRPTR(argv[1])+arglen1-1) == '.'
                  &&   arglen2 && *(RXSTRPTR(argv[2])+arglen2-1) == '.' )
                  {
                     bind_by_array = 1;
                     if ( ( rc = ArrayToArgv( RxPackageGlobalData, &(argv[1]), &(argv[2]), &stmt->Argc, stmt->Argv ) ) != 0 )
                     {
                        stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
                        return (int)FunctionEpilogue( RxPackageGlobalData, "BindValues", (long)rc );
                     }
                  }
                  else
                  {
                     if ( ArgvToArgv( RxPackageGlobalData, argc, argv, &stmt->Argc, stmt->Argv ) )
                     {
                        stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
                        return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
                     }
                  }
               }
               else
               {
                  stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
                  return(-1);
               }
            }
         }
         else
         {
            bind_type = BIND_BY_NAME;
            if ( ArgvToArgv( RxPackageGlobalData, argc, argv, &stmt->Argc, stmt->Argv ) )
            {
               stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
            }
         }
      }
   }

   /*
    * Call the appropriate bind function...
    */
   switch( bind_type )
   {
      case BIND_BY_NAME:
         rc = BindByName( RxPackageGlobalData, stmt, stmt->Argc, stmt->Argv );
         break;
      case BIND_BY_NUMBER:
         rc = BindByNumber( RxPackageGlobalData, stmt, stmt->Argc, stmt->Argv );
         break;
      case BIND_BY_STANDARD:
         rc = BindByStandard( RxPackageGlobalData, stmt, stmt->Argc, stmt->Argv );
         break;
   }

   return (int)FunctionEpilogue( RxPackageGlobalData, "BindValues", (long)rc );
}

/*-----------------------------------------------------------------------------
 * Get a column expression descriptor.  Assumes the index is valid!
 *----------------------------------------------------------------------------*/
static FLDDSCR *GetFldDscr( RxPackageGlobalDataDef *RxPackageGlobalData, SQLWA *swa, int i )
{
   FLDDSCR *fd=NULL;

   InternalTrace( RxPackageGlobalData, "GetFldDscr", "%x,%d", swa, i );

   fd = swa->fa[i];
   if (fd == (FLDDSCR*)NULL)
   {
      fd = swa->fa[i] = (FLDDSCR*)MALLOC_TSD(  RxPackageGlobalData, sizeof(FLDDSCR) );
      if (fd == (FLDDSCR*)NULL)
      {
         return (FLDDSCR*)NULL;
      }
      fd->rbuf = (ub1*)NULL;
      fd->cbuf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, MAX_NAMELEN+1 );
      if (fd->cbuf == (ub1*)NULL)
      {
         FREE_TSD( RxPackageGlobalData, fd);
         fd = swa->fa[i] = NULL;
         return (FLDDSCR*)NULL;
      }

      fd->rbufl = 0;
      fd->cbufl = MAX_NAMELEN;
   }
   return fd;
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
   sb4      dsize=0, dbsize=0;
   size_t   varlen=0;
   int      ext_type=EXT_LONG;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "DefineExpressions", "%x", stmt );

   /* Describe & define buffer for each expression in the SELECT statement */
   for (i = 0; i < MAX_COLS ; i++)
   {
      /* Get a new field descriptor */
      if ( ( fd = GetFldDscr( RxPackageGlobalData, swa, i ) ) == (FLDDSCR*)NULL )
         return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ) );


      if ( odescr( CTX(swa), i+1, &dbsize, &fd->dbtype, (sb1*)fd->cbuf, &fd->cbufl, &dsize, &fd->prec, &fd->scale, &fd->nullok ) )
      {
         /*
          * Clean up the fd we just created
          */
         if ( fd->cbuf )
         {
            FREE_TSD( RxPackageGlobalData, fd->cbuf );
            fd->cbuf = NULL;
            fd->cbufl = 0;
         }
         FREE_TSD( RxPackageGlobalData, fd );
         swa->fa[i] = NULL;

         if ( V4ERRORCODE(CTX(swa))
         &&   V4ERRORCODE(CTX(swa)) != 1007 )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa );
            return (DB_ERROR);
         }
         break;
      }

      fd->cbuf[fd->cbufl] = '\0';     /* Terminate the Column Name */

      ext_type = EXT_LONG;
      switch ( fd->dbtype )
      {
         case ORA_LONGRAW:
            varlen = RexxSQLData->LongLimit;
            ext_type = EXT_LONGRAW;
            break;
         case ORA_RAW:
            varlen = dsize;
            ext_type = EXT_LONGRAW;
            break;
         case ORA_LONG:
            varlen = RexxSQLData->LongLimit;
            break;
         default:
            varlen = dsize;
            break;
      }

      InternalTrace( RxPackageGlobalData, "DefineExpressions", "Column: %s Database SIze: %d Allocated Size: %d Type: %d", fd->cbuf, dsize, varlen, ext_type );

      /*
       * In an attempt to save malloc() & free() calls we keep the old
       * buffer providing it is not grossly oversized.
       */
      if ( (size_t)fd->rbufl < varlen
      ||   (size_t)fd->rbufl > varlen + 256 )
      {
         /* Free the old buffer (if any) */
         if ( fd->rbufl )
         {
            FREE_TSD( RxPackageGlobalData, fd->rbuf );
            fd->rbufl = 0;
            fd->rbuf = NULL;
         }
         /* Allocate a new buffer */
         if ( ( fd->rbuf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, varlen ) ) == (ub1*)NULL )
            return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ) );
         fd->rbufl = varlen;
      }

      if ( odefin(CTX(swa), i+1, fd->rbuf, fd->rbufl, ext_type, 0, &fd->indp, (text*)NULL, 0, 0, (ub2*)&fd->retl, (ub2*)&fd->rcode) )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
         return (DB_ERROR);
      }
   }

   /*
    * Check if too many SELECT expressions.
    * ORACLE should trap it if MAX_COLS is set correctly!
    */
   if (i >= MAX_COLS)
       return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 71, "Too many columns specified in SELECT" ));

   return (int)FunctionEpilogue( RxPackageGlobalData, "DefineExpressions", (long)(swa->expr_cnt = i) );
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
 * failure: ORACLE return code (V2 codes).
 *----------------------------------------------------------------------------*/
static int FetchRow( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt, char *stem, ULONG rowcount )
{
   FLDDSCR *fd=NULL;
   SQLWA   *swa=NULL;
   int     rc=0, i=0;
   size_t  varlen=0;
   char    varname[MAX_IDENTIFIER+1+10];
   char    tmp[128];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "FetchRow", "%x,%s,%d", stmt, stem, rowcount );

   swa = SWA(stmt);

   rc = ofetch( CTX(swa) );
   if ( rc == NO_DATA_FOUND )
      return (int)FunctionEpilogue( RxPackageGlobalData, "FetchRow", (long)rc );
   if ( rc )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
      return DB_ERROR;
   }

   /* Get each expr value in turn */
   for (i = 0; rc == 0 && i < swa->expr_cnt; i++)
   {
      fd = swa->fa[i];

      /* Add each column value to the stem's values */
      if ( rowcount )
         varlen = sprintf( varname, "%s.%s.%lu", stem, fd->cbuf, rowcount );
      else
         varlen = sprintf( varname, "%s.%s",  stem, fd->cbuf );

      if ( fd->rcode )    /* truncation or conversion error */
      {
         if ( fd->indp < 0 )      /* returned value is NULL */
         {
            rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, RexxSQLData->RXSNullStringOut.strptr, RexxSQLData->RXSNullStringOut.strlength );
         }
         else
         {
            if ( RexxSQLData->IgnoreTruncate )
               rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, (char*)fd->rbuf, (size_t)fd->rbufl );
            else
            {
               sprintf( tmp, "Conversion/truncation error (%d) occurred on column %s: Expecting %ld, got %ld", fd->rcode, fd->cbuf, (long)fd->rbufl, (long)fd->retl );
               return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 15, tmp ) );
            }
         }
      }
      else
      {
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, (char*)fd->rbuf, fd->retl );
      }
   }
   if ( rc )
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 16, "unable to set REXX variable" ) );
   return (int)FunctionEpilogue( RxPackageGlobalData, "FetchRow", (long)rc );
}

/*-----------------------------------------------------------------------------
 *
 *----------------------------------------------------------------------------*/
static int SetRowCountVar( RxPackageGlobalDataDef *RxPackageGlobalData, SQLWA *swa, char *stem_name, long rowcount )
{
   int     i=0;
   char    varname[MAX_IDENTIFIER*2+4], buf[11];

   InternalTrace( RxPackageGlobalData, "SetRowCountVar", "%x,%s,%d", swa, stem_name, rowcount );

   for (i = 0; i < swa->expr_cnt; i++)
   {
      sprintf(varname, "%s.%s.0", stem_name,swa->fa[i]->cbuf);
      sprintf(buf, "%lu", rowcount);
      if (SetRexxVariable( RxPackageGlobalData, varname,strlen(varname), buf,strlen(buf)))
         return(-16);
   }
   return (int)FunctionEpilogue( RxPackageGlobalData, "SetRowCountVar", (long)0 );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS: SQLCOMMAND(stem-name, sql-statement-text [, <bind-args>])
 *
 * RETURNS :  0-success < 0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLCOMMAND )
{
   int         rc = 0, i=0;
   ULONG       rowcount=0L;
   int         expr_cnt=0;
   DBCON       *db=NULL;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
   char        stem_name[MAX_IDENTIFIER+1];
   int         stmt_len=0;
   char        *stmt_ptr=NULL;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 0 ) )
      return 1;


   /* Get pointer to current connection */
   if (RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if (argc == 1 || RXSTRLEN(argv[0]) == 0) /* No stem name specified! */
      (void)strcpy(stem_name, DEFAULT_STEM);
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc);
   }

   /* If no default statement then create it! */
   if ((stmt = (STMT*)(db->dflt_stmt)) == (STMT*)NULL)
   {
      /* Open a statement for the default statement. */
      if ( ( rc = OpenStatement( RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

      db->dflt_stmt = (void*)stmt;
   }

   swa = SWA(stmt);

   /*
    * If only 1 arg then it is the SQL-statement-text. If more than 1 args
    * then arg#1 is stem-name, arg#2 is text and rest are bind values.
    * 'i' is index (base zero) to sql-statement-text arg.
    */
   i = (argc == 1) ? 0 : 1;

   /* set flag indicating if SELECT statement supplied */
   swa->select_stmt = SelectStatement( RxPackageGlobalData, RXSTRPTR(argv[i]), RXSTRLEN(argv[i]) );

   /*
    * If the request is to use "standard" placemarkers; ?, then we
    * need to convert these into Oracle's placemarkers, :1 -> :n
    */
   if (RexxSQLData->StandardPlacemarkers)
   {
      if ( ( stmt_ptr = ConvertPlacemarkers( RxPackageGlobalData, RXSTRPTR(argv[i]), (int)RXSTRLEN(argv[i]), &stmt_len ) ) == NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );
   }
   else
   {
      stmt_ptr = RXSTRPTR(argv[i]);
      stmt_len = (int)RXSTRLEN(argv[i]);
   }

   /* Save the SQL statement. MUST do this as oexec fails if you don't */
   if ( SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), stmt_ptr, stmt_len ) )
      return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

   /* Parse the statement */
#if defined(NO_OPARSE)
   if ((rc = osql3(CTX(swa), stmt_ptr,stmt_len)))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }
#else
   if ((rc = oparse(CTX(swa), (ub1*)swa->saved_stmt.sql_stmt, stmt_len, 1, 1L)))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }
#endif
   /* Bind variables in WHERE/INSERT/UPDATE clause (if any). */
   if (argc > 2)
   {
      if ( ( rc = BindValues( RxPackageGlobalData, stmt, argc-2, &argv[2] ) ) )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
      }
   }

   /* Describe the expression list & define output buffers (if any). */
   if (swa->select_stmt)
   {
      if ( ( expr_cnt = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt);
      }
   }

   /* Execute the SQL statement */
   if ((rc = oexec(CTX(swa))))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }

   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );

   /* Test if select statement. If not then done else fetch rows. */
   if (expr_cnt == 0)
   {
      rowcount = SQLROWCNT(CTX(swa));
      /* Inform ORACLE that operation is complete */
      if ((rc = ocan(CTX(swa))))   /* this should never fail */
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
         return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
      }
      /*
       * If the statement is NOT a SELECT, and we have AUTOCOMMIT
       * ON, then commit the statement.
       */
      if (RexxSQLData->AutoCommit)
      {
         if ((rc = ocom(LDA(stmt))))
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), (SQLWA*)NULL);
      }
   }
   else /* Then must be a SELECT statement */
   {
      /* Fetch each row in turn */
      for (rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= RexxSQLData->RowLimit; rowcount++)
      {
         if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount ) ) )
            break;
      }
      rowcount--;

      if (rc && rc != NO_DATA_FOUND)
      {
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
      }

      if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

      /* Inform ORACLE that operation is complete */
      if ((rc = ocan(CTX(swa)))) /* this should never fail */
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
         return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
      }
   }
   SetRowCount( RxPackageGlobalData, rowcount );

   /*
    * Release the statement and associated storage.
    */
   if ( ( rc = ReleaseStatement( RxPackageGlobalData, stmt ) ) )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   db->dflt_stmt = (STMT*)NULL;

   return RxReturnNumber( RxPackageGlobalData, retstr, 0L);
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
   SQLWA       *swa=NULL;
   char        stmt_name[MAX_IDENTIFIER+1];
   int         stmt_len=0;
   char        *stmt_ptr=NULL;
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
    * Make sure we have a current connection
    */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
      return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

   /* Get pointer to current connection */
   if (RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
       return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if (RXSTRLEN(argv[0]) == 0) /* No statement name specified! */
      return ReturnError( RxPackageGlobalData, retstr, 23, "statement name omitted or null" );
   else if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stmt_name, sizeof(stmt_name) ) ) )
      return RxReturnNumber( RxPackageGlobalData, retstr, rc);

   /*
    * Find the named statement or create if necessary. We have to be a
    * bit careful here because the statement may exist but point to a
    * different database connection!
    */
   stmt = FindObject( RxPackageGlobalData, stmt_name, RexxSQLData->DbEnv->stmt_tbl, TBL_STATEMENTS );

   if (stmt == (STMT*)NULL || stmt->db != db)
   {
      if (stmt)
      {
         /*
          * Statement is not for the same db, therefore we must dispose
          * & re-alloc it!
          */
         RemoveObject( RxPackageGlobalData, stmt );
         ((DBCON*)stmt->db)->num_statements--;
         if ( ( rc = ReleaseStatement( RxPackageGlobalData, stmt ) ) )
             return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
     }

     /* Open a statement for this statement. */
     if ( ( rc = OpenStatement( RxPackageGlobalData, stmt_name, db, &stmt ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

     /* Insert this statement into the connection hash table. */
     (void)InsertObject( RxPackageGlobalData, stmt, RexxSQLData->DbEnv->stmt_tbl, TBL_STATEMENTS );

     db->num_statements++;
   }

   swa = SWA(stmt);
   /* set flag indicating if SELECT statement supplied */
   swa->select_stmt = SelectStatement( RxPackageGlobalData, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );

   /*
    * If the request is to use "standard" placemarkers; ?, then we
    * need to convert these into Oracle's placemarkers, :1 -> :n
    */
   if ( RexxSQLData->StandardPlacemarkers )
   {
      if ( ( stmt_ptr = ConvertPlacemarkers( RxPackageGlobalData, RXSTRPTR(argv[1]), (int)RXSTRLEN(argv[1]), &stmt_len ) ) == NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );
   }
   else
   {
      stmt_ptr = RXSTRPTR(argv[1]);
      stmt_len = (int)RXSTRLEN(argv[1]);
   }

   /* Save the SQL statement. MUST do this as oexec fails if you don't */
   if ( SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), stmt_ptr, stmt_len ) )
       return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

   swa->bind_cnt = 0;
   swa->expr_cnt = 0;

   /* Parse the statement */
#if defined(NO_OPARSE)
   if ((rc = osql3(CTX(swa), stmt_ptr, stmt_len)))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
   }
#else
   if ((rc = oparse(CTX(swa), (ub1*)swa->saved_stmt.sql_stmt, stmt_len, 1, 1L)))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
   }
#endif

   return RxReturnNumber( RxPackageGlobalData, retstr, rc ? DB_ERROR : 0);
}

/*-----------------------------------------------------------------------------
 * Get a pointer to the nominated statement. Returns NULL on error.
 *----------------------------------------------------------------------------*/
static STMT *GetStatement( RxPackageGlobalDataDef *RxPackageGlobalData, RXSTRING var, PSZ buf )
{
   STMT        *stmt=NULL;
   char        tmp[128];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "GetStatement", "%x,%s", var, buf );

   if (RexxSQLData->DbEnv == (DBENV*)NULL)
   {
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 22, "no connections open." );
      return (STMT*)NULL;
   }

   if (RXSTRLEN(var) == 0)
   {
      /*
       * No statement name specified!
       */
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 23, "statement name omitted or null" );
      return (STMT*)NULL;
   }

   /*
    * Get the normalised form of the name
    */
   if ( MkIdentifier( RxPackageGlobalData, var, buf, MAX_DB_CURSOR_NAME+1 ) )
      return (STMT*)NULL;

   /*
    * Find the named statement or create if necessary
    */
   if ( ( stmt = FindObject( RxPackageGlobalData, buf, RexxSQLData->DbEnv->stmt_tbl, TBL_STATEMENTS ) ) == (STMT*)NULL )
   {
      /*
       * Statement not an existing one!
       */
      (void)sprintf(tmp,"statement \"%s\" does not exist", buf);
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
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode);

   /* Get pointer to statement's connection structure */
   db = stmt->db;

   /* Dispose the statement */
   RemoveObject( RxPackageGlobalData, stmt );
   rc = ReleaseStatement( RxPackageGlobalData, stmt );

   db->num_statements--;

   return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
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
   int         rc=0;
   int         expr_cnt=0;
   ULONG       rowcount=0L;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
   char        stmt_name[MAX_IDENTIFIER+1];
   char        tmp[128];
   DBCON       *db=NULL;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 0 ) )
      return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode);

   swa = SWA(stmt);

   /*
    * Make sure we have a current connection
    */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
      return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

   /* Get pointer to statement's connection structure */
   db = stmt->db;

   /*
    * Rest of args (if any) are bind values. Therefore bind the substitution
    * variables in WHERE/INSERT/UPDATE clause (if any).
    */
   argc--;
   if (argc)
   {
      if ( ( rc = BindValues( RxPackageGlobalData, stmt, argc, &argv[1] ) ) )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
      }
   }

   /*
    * This function can be called as SQLOPEN() or SQLEXECUTE(). These
    * operations are similar except for the describe. Use the function
    * name to determine what operation we are performing.
    */
   if (open)
   {
      /*
       * Describe the expression list & define output buffers (if any).
       */
      if ( ( expr_cnt = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt);
      }

      /*
       * Since this is a call to SQLOPEN() the statement must be a query!
       */
      if (expr_cnt == 0)
      {
         if (!SEL(swa))
         {
            (void)sprintf(tmp,"statement \"%s\" is not a query.", stmt_name);
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
            return ReturnError( RxPackageGlobalData, retstr, 13, tmp );
         }
         else
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
            return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
         }
      }
   }

   /*
    * Execute the SQL statement. This is required for Queries & DML!
    */
   if ((rc = oexec(CTX(swa))))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }

   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );

   /*
    * Return the ROWCOUNT.  For a query it will be zero at this stage.  For
    * a DML statement it will be the number of rows affected by the INSERT/
    * UPDATE/DELETE statement.
    */
   rowcount = SQLROWCNT(CTX(swa));
   SetRowCount( RxPackageGlobalData, rowcount );

   /*
    * If the statement is NOT called from SQLOPEN(), and we have AUTOCOMMIT
    * ON, then commit the statement.
    */
   if (!open
   && RexxSQLData->AutoCommit)
   {
      if ((rc = ocom(LDA(stmt))))
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), (SQLWA*)NULL);
   }
   return RxReturnNumber( RxPackageGlobalData, retstr, (long)0L);
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
   SQLWA       *swa=NULL;
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
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode);

   swa = SWA(stmt);

   /* Inform ORACLE that operation is complete. This should never fail! */
   if ((rc = ocan(CTX(swa))))
       SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);

   return RxReturnNumber( RxPackageGlobalData, retstr, rc ? DB_ERROR : 0);
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
   long        rc=0;
   int         single_fetch=0;
   ULONG       num_rows=0L;
   ULONG       rowcount=0L;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
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

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 2 ) )
      return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode);

   swa = SWA(stmt);

   /* Determine # of rows to fetch */
   if (argc > 1 && RXSTRLEN(argv[1]))
   {
      if ( RxStrToULong( RxPackageGlobalData, &argv[1], &num_rows ) )
      {
         return ReturnError( RxPackageGlobalData, retstr, 14, "<num-rows> is not a valid integer." );
      }
      single_fetch = FALSE;
   }
   else
      single_fetch = TRUE;

   if (single_fetch)
   {
      /* Fetch a single row */
      if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stmt_name, 0L ) ) )
         rc = (rc == NO_DATA_FOUND) ? 0 : rc;
      else
         rc = 1; /* single row fetch, must return 1 */
   }
   else
   {
      /* Fetch each row in turn */
      for (rowcount = 1; num_rows == 0 || rowcount <= num_rows; rowcount++)
      {
         if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stmt_name, rowcount ) ) )
            break;
      }

      rowcount--;

      if (rc && rc != NO_DATA_FOUND)
      {
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
      }

      if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stmt_name, rowcount ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

      rc = rowcount;
   }

   SetRowCount( RxPackageGlobalData, rc );
   return RxReturnNumber( RxPackageGlobalData, retstr, rc);
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
#define LONG_BLOCK_SIZE 0x8000      /* 32k */
   FLDDSCR *fd=NULL;
   long    rc=0,ret_len=0;
   ULONG   num_bytes=0L;
   ULONG   start_byte=0L;
   STMT    *stmt=NULL;
   SQLWA   *swa=NULL;
   char    stmt_name[MAX_IDENTIFIER+1];
   int     long_col=0,ext_type=0,i=0;
   size_t  varlen=0;
   char    varname[MAX_IDENTIFIER+1+10];
   FILE    *fp=NULL;
   char    tmp[128];
   sb4     rbufl;
   ub1     *rbuf;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 4, 5 ) )
      return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode);

   swa = SWA(stmt);

   /*
    * Check that the column name specified is really a "LONG" and
    * get column number.
    */
   if ( RXSTRLEN( argv[1] ) )
   {
      for ( i = 0; i < swa->expr_cnt; i++ )
      {
         fd = swa->fa[i];
         if ( fd->cbufl == RXSTRLEN(argv[1])
         &&   memcmpi( RxPackageGlobalData, RXSTRPTR(argv[1]), fd->cbuf, fd->cbufl ) == 0 )
         {
            /*
             * Found column name, is it a "LONG" ?
             */
            if ( !DBLONGCOLUMN(fd->dbtype) )
            {
               sprintf( tmp, "Column <%s> does not have a 'LONG' datatype.", fd->cbuf );
               return ReturnError( RxPackageGlobalData, retstr, 85, tmp );
            }
            long_col = i+1;
            break;
         }
      }
      if ( long_col == 0 )
      {
         sprintf( tmp, "Column <%s> not present in statement.", RXSTRPTR(argv[1]) );
         return ReturnError( RxPackageGlobalData, retstr, 85,tmp );
      }
   }
   else
   {
      return ReturnError( RxPackageGlobalData, retstr, 84,"<column-name> parameter MUST be supplied." );
   }

   /*
    * Determine starting byte
    */
   if ( RXSTRLEN(argv[2]) )
   {
      if ( RxStrToULong( RxPackageGlobalData, &argv[2], &start_byte ) )
      {
         return ReturnError( RxPackageGlobalData, retstr, 14,"<start-byte> is not a valid integer." );
      }
   }
   else
      start_byte = 0L;

   /*
    * Determine length
    */
   if ( RXSTRLEN(argv[3]) )
   {
      if ( RxStrToULong( RxPackageGlobalData, &argv[3], &num_bytes ) )
      {
         return ReturnError( RxPackageGlobalData, retstr, 14,"<number-bytes> is not a valid integer." );
      }
   }
   else
      num_bytes = 0L;

   /*
    * Check for filename if start and length = 0
    */
   if ( start_byte == 0L
   &&   num_bytes == 0L
   &&   RXSTRLEN(argv[4]) == 0 )
   {
      return ReturnError( RxPackageGlobalData, retstr, 84,"<file-name> parameter MUST be supplied." );
   }

   ext_type = (fd->dbtype==ORA_RAW||fd->dbtype==ORA_LONGRAW)?EXT_LONGRAW:EXT_LONG;
   if ( start_byte == 0L
   &&   num_bytes == 0L)
   {
      /*
       * Process a file
       */
      ub1 *buf=NULL;

      if ( ( fp = fopen( RXSTRPTR(argv[4]), "wb" ) ) == NULL )
      {
         sprintf( tmp, "<open> on file <%s> failed: %s.", RXSTRPTR(argv[4]), strerror( errno ) );
         return ReturnError( RxPackageGlobalData, retstr, 86, tmp );
      }
      if ( ( buf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, LONG_BLOCK_SIZE+1 ) ) == (ub1*)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );
      ret_len = 0;
      for ( i = 0; ; i++ )
      {
         if ( oflng( CTX(swa), long_col, buf, LONG_BLOCK_SIZE, ext_type, (ub4*)&ret_len, (i*LONG_BLOCK_SIZE) ) )
         {
            if ( buf )
               FREE_TSD( RxPackageGlobalData, buf);
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa );
            return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
         }
         if ( ret_len == 0 )
            break;
         if ( (long)fwrite( (void*)buf, sizeof(ub1), ret_len, fp ) != ret_len )
         {
            if ( buf )
               FREE_TSD( RxPackageGlobalData, buf );
            sprintf( tmp, "<write> on file <%s> failed: %s.", RXSTRPTR(argv[4]), strerror( errno ) );
            return ReturnError( RxPackageGlobalData, retstr, 86, tmp );
         }
      }
      if (buf)
         FREE_TSD( RxPackageGlobalData, buf );
      if ( fclose( fp ) )
      {
         sprintf( tmp, "<close> on file <%s> failed: %s.", RXSTRPTR(argv[4]), strerror( errno ) );
         return ReturnError( RxPackageGlobalData, retstr, 86, tmp );
      }
   }
   else
   {
      /*
       * Get the chunk of data specified
       * Size of the chunk MUST be < 64K
       */
      if ( num_bytes >= 0x10000 )
         return ReturnError( RxPackageGlobalData, retstr, 87, "<number-bytes> parameter must be < <65536>." );
      /*
       * We must not reuse the rbuf field of the field descriptor as this could get resized
       * and realloced, and then the address used in DefineExpressions() is not the same
       * address and things will crash!
       */
      if ( ( rbuf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, num_bytes ) ) == (ub1*)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );
      rbufl = num_bytes;
      if ( oflng( CTX(swa), long_col, rbuf, rbufl, ext_type, (ub4*)&ret_len, (start_byte-1) ) )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa );
         return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
      }
      (void)sprintf( varname, "%s.%s", stmt_name, fd->cbuf );
      varlen = strlen( varname );
      rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, (char*)rbuf, ret_len );
      FREE_TSD( RxPackageGlobalData, rbuf );
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, ret_len );
}


/*-----------------------------------------------------------------------------
 * Fetch the description for the column expression. Used by SQLDESCRIBE().
 *----------------------------------------------------------------------------*/
static int GetColumn( RxPackageGlobalDataDef *RxPackageGlobalData, SQLWA *swa, int i, char *stem_name )
{
   FLDDSCR *fd=NULL;
   int     idx=0, rc=0;
   char    column_size[7], column_prec[7], column_scale[7], column_nullok[7];
   char    *column_type=NULL;
   char    name[MAX_IDENTIFIER+32];
   char    *value[NUM_DESCRIBE_COLUMNS];
   int     value_len[NUM_DESCRIBE_COLUMNS];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "GetColumn", "%x,%d,%s", swa, i, stem_name );

   if (i >= swa->expr_cnt)
      return (int)FunctionEpilogue( RxPackageGlobalData, "GetColumn", (long)1 );

   fd = swa->fa[i];

   for (idx=0;datatype_conversion[idx].ext_datatype;idx++)
   {
      if (datatype_conversion[idx].int_datatype == fd->dbtype)
      {
         column_type = datatype_conversion[idx].ext_datatype;
      }
   }
   if (column_type == NULL)
      column_type = "UNKNOWN";
#if 0
   switch (fd->dbtype)
   {
      case ORA_CHAR:     column_type = "CHAR";     break;
      case ORA_VARCHAR2: column_type = "VARCHAR2"; break;
      case ORA_RAW:      column_type = "RAW";      break;
      case ORA_NUMBER:   column_type = "NUMBER";   break;
      case ORA_DATE:     column_type = "DATE";     break;
      case ORA_LONG:     column_type = "LONG";     break;
      case ORA_LONGRAW:  column_type = "LONG RAW"; break;
      case ORA_ROWID:    column_type = "ROWID";    break;
      case ORA_MLSLABEL: column_type = "MLSLABEL"; break;
      default:           column_type = "UNKNOWN";  break;
   }
#endif

   /* Set up the array */
   value[0] = (char*)fd->cbuf;
   value_len[0] = fd->cbufl;

   value[1] = column_type;
   value_len[1] = strlen(column_type);

   (void)sprintf(column_size, "%ld", fd->rbufl);
   value[2] = column_size;
   value_len[2] = strlen(value[2]);

   (void)sprintf(column_prec, "%d", fd->prec);
   value[3] = column_prec;
   value_len[3] = strlen(value[3]);

   (void)sprintf(column_scale, "%d", fd->scale);
   value[4] = column_scale;
   value_len[4] = strlen(value[4]);

   (void)sprintf(column_nullok, "%d", fd->nullok);
   value[5] = column_nullok;
   value_len[5] = strlen(value[5]);

   /* Output into Rexx variable */
   i++;
   for (idx = 0; idx < NUM_DESCRIBE_COLUMNS; idx++)
   {
      sprintf( name, "%s.COLUMN.%s.%d", stem_name, RexxSQLData->column_attribute[idx], i );
      if (SetRexxVariable( RxPackageGlobalData, name,strlen(name),value[idx],value_len[idx]))
      {
         rc = -16;
         break;
      }
   }

   return (int)FunctionEpilogue( RxPackageGlobalData, "GetColumn", (long)rc );
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
   SQLWA       *swa=NULL;
   char        **p=NULL, buf1[MAX_IDENTIFIER+32], buf2[16];
   char        stmt_name[MAX_IDENTIFIER+1];
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

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode);

   swa = SWA(stmt);

   /* Get the name of the stem into which to put output */
   if (argc < 2 || RXSTRLEN(argv[1]) == 0) /* No stem name specified! */
      (void)strcpy(stem_name, stmt_name);
   else
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[1], stem_name, sizeof(stem_name) ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

   /* Describe the expression list & define output buffers (if any). */
   if ( ( rc = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

   /* Describe the parsed statement into REXX variables */
   for (rc = 0, i = 0; rc == 0; i++)
   {
      rc = GetColumn( RxPackageGlobalData, swa, i, stem_name );
   }

   if (rc >= 0)
   {
      (void)sprintf(buf2,"%d", --i);
      len2 = strlen(buf2);
      for ( p = RexxSQLData->column_attribute; *p && rc >= 0; p++ )
      {
         (void)sprintf(buf1, "%s.COLUMN.%s.0", stem_name, *p);
         len1 = strlen(buf1);
         if (SetRexxVariable( RxPackageGlobalData, buf1, len1, buf2, len2))
            rc = -16;
         else
            rc = 0;
      }
      rc = rc < 0 ? rc : i;
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDATASOURCES([stem-name] )
 *
 * ARGUMENTS:
 *            0 - stem_name (optional)
 *
 *
 * RETURNS :  0-success, <0-error.
 *            This is in effect a NOP, it sets all stem_name.0 to 0
 *
 *----------------------------------------------------------------------------*/
rxfunc( SQLDATASOURCES )
{
   int    rc, varlen;
   char   varname[MAX_IDENTIFIER*2+4];
   char   stem_name[MAX_IDENTIFIER+1];
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

   if ( argc == 0 || RXSTRLEN(argv[0]) == 0 ) /* No stem name specified! */
      (void)strcpy( stem_name, DEFAULT_STEM );
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) != 0 )
         return rc;
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: stem: %s\n", __FILE__,__LINE__, stem_name);)

   /*
    * Set the rowcount SQLCA member and the 0 element of the stems
    */
   SetRowCount( RxPackageGlobalData, 0 );
   varlen = sprintf( varname, "%s.%s.0", stem_name, "DSN_NAME" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "DSN_DESCRIPTION" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   return RxReturnNumber( RxPackageGlobalData, retstr, 0 );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLTABLES([stem-name, ] [catalog], [owner], [table], [type] )
 *
 * ARGUMENTS:
 *            0 - stem_name (optional)
 *            1 - table catalog (optional - ignored)
 *            2 - table owner (optional)
 *            3 - table name (optional)
 *            4 - table type (optional)
 *
 * SETS:
 *            Stems:
 *               TABLE_NAME
 *               TABLE_CATALOG
 *               TABLE_OWNER
 *               TABLE_TYPE
 *               TABLE_DESCRIPTION
 *
 * RETURNS :  0-success, <0-error.
 *            This is in effect a NOP, it sets all stem_name.0 to 0
 *
 *----------------------------------------------------------------------------*/
rxfunc( SQLTABLES )
{
   int         rc;
   char        stem_name[MAX_IDENTIFIER+1];
   char        buf[1024];
   char        whereclause[1024];
   ULONG       rowcount=0L;
   int         expr_cnt=0;
   DBCON       *db=NULL;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
   int         stmt_len=0;
   char        *stmt_ptr=NULL;
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

   /* Get pointer to current connection */
   if (RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if ( argc == 0 || RXSTRLEN(argv[0]) == 0 ) /* No stem name specified! */
      (void)strcpy( stem_name, DEFAULT_STEM );
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) != 0 )
         return rc;
   }
   /*
    * Build SELECT statement
    */
   strcpy( whereclause, "" );
   if ( argc > 2 && RXSTRLEN( argv[2] ) )
   {
      sprintf( buf, " and a.owner like '%s'", RXSTRPTR(argv[2]) );
      strcat( whereclause, buf );
   }
   if ( argc > 3 && RXSTRLEN( argv[3] ) )
   {
      sprintf( buf, " and table_name like '%s'", RXSTRPTR(argv[3]) );
      strcat( whereclause, buf );
   }
   if ( argc > 4 && RXSTRLEN( argv[4] ) )
   {
      sprintf( buf, " and table_type like '%s'", RXSTRPTR(argv[4]) );
      strcat( whereclause, buf );
   }
   stmt_len = sprintf( buf, "select '' as table_description, '' as table_catalog, a.owner as table_owner, table_name, object_type as table_type from all_tables a, all_objects b where a.owner = b.owner and object_name = table_name %s order by table_owner, table_name", whereclause );
   stmt_ptr = buf;

   DEBUGDUMP(fprintf(stderr,"%s-%d: stem: %s\n", __FILE__,__LINE__, stem_name);)

   /* If no default statement then create it! */
   if ((stmt = (STMT*)(db->dflt_stmt)) == (STMT*)NULL)
   {
      /* Open a statement for the default statement. */
      if ( ( rc = OpenStatement( RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

      db->dflt_stmt = (void*)stmt;
   }

   swa = SWA(stmt);


   /* set flag indicating if SELECT statement supplied */
   swa->select_stmt = SelectStatement( RxPackageGlobalData, stmt_ptr, stmt_len );

   /* Save the SQL statement. MUST do this as oexec fails if you don't */
   if ( SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), stmt_ptr, stmt_len ) )
      return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

   /* Parse the statement */
#if defined(NO_OPARSE)
   if ((rc = osql3(CTX(swa), stmt_ptr,stmt_len)))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }
#else
   if ((rc = oparse(CTX(swa), (ub1*)swa->saved_stmt.sql_stmt, stmt_len, 1, 1L)))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }
#endif

   /* Describe the expression list & define output buffers (if any). */
   if (swa->select_stmt)
   {
      if ( ( expr_cnt = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
      {
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt);
      }
   }

   /* Execute the SQL statement */
   if ((rc = oexec(CTX(swa))))
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }

   /* Fetch each row in turn */
   for (rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= RexxSQLData->RowLimit; rowcount++)
   {
      if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount ) ) )
         break;
   }
   rowcount--;

   if (rc && rc != NO_DATA_FOUND)
   {
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   }

   if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount ) ) )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

   /* Inform ORACLE that operation is complete */
   if ((rc = ocan(CTX(swa)))) /* this should never fail */
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, LDA(stmt), swa);
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }

   /*
    * Release the statement and associated storage.
    */
   if ( ( rc = ReleaseStatement( RxPackageGlobalData, stmt ) ) )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   db->dflt_stmt = (STMT*)NULL;

   return RxReturnNumber( RxPackageGlobalData, retstr, 0 );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLCOLUMNS([stem-name, ] [catalog], [owner], [table], [type] )
 *
 * ARGUMENTS:
 *            0 - stem-name (optional)
 *            1 - table catalog (optional - ignored)
 *            2 - table owner (optional)
 *            3 - table name (mandatory)
 *            4 - table type (optional)
 *
 *
 * RETURNS :  0-success, <0-error.
 *            This is in effect a NOP, it sets all stem_name.0 to 0
 *
 *----------------------------------------------------------------------------*/
rxfunc( SQLCOLUMNS )
{
   int    rc, varlen;
   char   varname[MAX_IDENTIFIER*2+4];
   char   stem_name[MAX_IDENTIFIER+1];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 4, 5 ) )
      return 1;

   if ( argc == 0 || RXSTRLEN(argv[0]) == 0 ) /* No stem name specified! */
      (void)strcpy( stem_name, DEFAULT_STEM );
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) != 0 )
         return rc;
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: stem: %s\n", __FILE__,__LINE__, stem_name);)

   /*
    * Set the rowcount SQLCA member and the 0 element of the stems
    */
   SetRowCount( RxPackageGlobalData, 0 );
   varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_CATALOG" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_OWNER" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "TABLE_NAME" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_NAME" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_TYPE" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_SIZE" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_PRECISION" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_NULLABLE" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_SCALE" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);
   varlen = sprintf( varname, "%s.%s.0", stem_name, "COLUMN_DESCRIPTION" );
   if ( SetRexxVariable( RxPackageGlobalData, varname, varlen, "0", 1 ) )
      return(-16);

   return RxReturnNumber( RxPackageGlobalData, retstr, 0 );
}

/*-----------------------------------------------------------------------------
 * Database initialisation
 *----------------------------------------------------------------------------*/
static int DBInitialise( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   return(0);
}

/*-----------------------------------------------------------------------------
 * Database termination
 *----------------------------------------------------------------------------*/
static int DBTerminate( RxPackageGlobalDataDef *RxPackageGlobalData)
{
   return 0;
}

/*-----------------------------------------------------------------------------
 * Set up the string containing database name
 *----------------------------------------------------------------------------*/
static void *SQLValSetDBMSName( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetDBMSName", "%x", db );
   strcpy(RexxSQLData->DBMSName,"ORACLE");
   MAKERXSTRING(RexxSQLData->RXSDBMSName,RexxSQLData->DBMSName,(ULONG)strlen(RexxSQLData->DBMSName));
   return((void*)&RexxSQLData->RXSDBMSName);
}

/*-----------------------------------------------------------------------------
 * Set up the DBMSVer variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetDBMSVer( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   strcpy(RexxSQLData->DBMSVer,"unknown");
   MAKERXSTRING(RexxSQLData->RXSDBMSVer,RexxSQLData->DBMSVer,(ULONG)strlen(RexxSQLData->DBMSVer));
   return((void*)&RexxSQLData->RXSDBMSVer);
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

   InternalTrace( RxPackageGlobalData, "SetSupportsTransactions", "%x", db );
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
   RexxSQLData->SupportsSqlGetData = TRUE;
   return((void*)&RexxSQLData->SupportsSqlGetData);
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
   RexxSQLData->SupportsPlacemarkers = TRUE;
   return( (void*)&RexxSQLData->SupportsPlacemarkers);
}

/*-----------------------------------------------------------------------------
 * Set up the SupportsThreads variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetSupportsThreads( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetSupportsThreads", "%x", db );
   RexxSQLData->SupportsThreads = SUPPORTSTHREADS;
   return( (void*)&RexxSQLData->SupportsThreads);
}

#include "rxsqlinc2.h"
