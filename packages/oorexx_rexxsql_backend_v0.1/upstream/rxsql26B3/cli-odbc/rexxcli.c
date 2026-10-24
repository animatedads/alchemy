/*
 * rexxcli.c - Rexx/SQL for X/Open CLI and ODBC
 *
 *
 * Rexx/SQL. A Rexx interface to SQL databases.
 * Copyright Mark Hessling, 1996-2008.
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
 * Mark Hessling  mark@rexx.org http://www.rexx.org/
 *
 */

static char RCSid[] = "$Id: rexxcli.c,v 1.27 2010/09/20 21:41:25 mark Exp $";

#include "rxpack.h"
#include "dbdefine.h"
#if defined(SOLID_SERVER) && !defined(__OS2__)
# include "dbheader.h"
#endif
#if defined(UNIX)
# include "dbheader.h"
#endif
#include "rexxsql.h"
#include "dbheader.h"
#include "dbtypes.h"

#define UNBOUND_COLUMN "<use sqlgetdata for this column>"
/*
 * Definition of field descriptions
 */
typedef struct
{
   UCHAR  cbuf[MAX_NAMELEN+1];             /* Buffer to hold column name */
   SWORD  cbufl;                                /* Length of column name */
   SWORD  dbtype;                                  /* Datatype of column */
   UDWORD prec;                                   /* Precision of column */
   SWORD  scale;                             /* Scale of number datatype */
   SWORD  nullok;                  /* Are nulls permitted? 0=no, <>0=yes */
   UCHAR  *rbuf;       /* Pointer to buffer to hold fetched column value */
   SDWORD rbufl;          /* Size of buffer to hold fetched column value */
   SDWORD retl;                                /* Return length of field */
   int    rcode;          /* Column return code - valid only after fetch */
   int    indp;                /* Indicator for field - after each fetch */
                     /* <0 - NULL; 0 - OK; >0 - length BEFORE truncation */
   int    bind;                  /* 1 if column to be bound, 0 otherwise */
} FLDDSCR;

/*
 * Definition of parameter markers
 */
typedef struct
{
   UCHAR  *buf;   /* Pointer to buffer containing parameter marker value */
   SDWORD buflen;                                /* Actual length of buf */
   SDWORD retlen;                         /* Return length of bind value */
} PMDSCR;

/*
 * Definition of SQL Work Area (SQLWA).
 */

typedef struct
{
   SAVEDSQLSTMT saved_stmt;           /* structure to hold SQL statement */
   int     select;            /* 1 if statement is a SELECT, 0 otherwise */
   int     bind_cnt;                      /* number of bind values bound */
   SWORD   expr_cnt;             /* number of expressions in select list */
   FLDDSCR *fa[MAX_COLS];          /* array of pointers to column dscr's */
   PMDSCR  *pm[MAX_BINDVARS];      /* array of pointers to param markers */
} SQLWA;


/*
 * Connection structure. Each connection requires one of these!
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct
{
   char       name[MAX_IDENTIFIER+1];                 /* Connection name */
   RXSQL_HDBC hdbc;                                 /* connection handle */
   void       *dflt_stmt;               /* Pointer to implicit statement */
   int        num_statements;           /* Number of explicit statements */
   char       have_sqlbindparameter; /* does the driver support SQLBindParameter ? */
   char       have_sqlnumparams; /* does the driver support SQLNumParams ? */
   UDWORD     sqlgetdataext;         /* extended SQLGetData extensions ? */
   SQLVAL     *db_opt;                          /* SqlGetInfo hash table */
} DBCON;

/*
 * Statement structure. Each statement requires one of these!
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct
{
   char        name[MAX_DB_CURSOR_NAME+1];             /* Statement name */
   RXSQL_HSTMT hstmt;                                /* statement handle */
   DBCON       *db;                   /* Pointer to connection structure */
   SQLWA       sqlwa;                                   /* SQL Work Area */
   ULONG       Argc;
   RXSTRING    *Argv;
   char        bind;  /* 1 - bind columns on sqlopen() */
} STMT;


/* Basic REXXSQL environment structure - allocated when 1st connection made! */
typedef struct
{
   int     num_connections;              /* Number of active connections */
   int     max_connections;     /* Maximum number of connections allowed */
   DBCON   *current_connection;         /* Pointer to current connection */
   BUCKET  *db_tbl[TBL_CONNECTIONS];            /* Connection hash table */
   BUCKET  *stmt_tbl[TBL_STATEMENTS];            /* Statement hash table */
} DBENV;

/* conversion of column names for SQLTables() and SQLColumns() */
typedef struct
{
   char *odbc_colname;              /* column name from ODBC */
   int odbc_colname_length;         /* length of ODBC colname */
   char *rxsql_colname;             /* column name for rxsql */
} RXCOLCONV;

static RXCOLCONV sqltables_conv[] =
{
   {"TABLE_QUALIFIER"   , 15, "TABLE_CATALOG"      },
   {"TABLE_QUALIFER"    , 14, "TABLE_CATALOG"      }, /* bug in MySQL ODBC!! */
   {"TABLE_CATALOG"     , 13, "TABLE_CATALOG"      },
   {"TABLE_CAT"         ,  9, "TABLE_CATALOG"      },
   {"TABLE_OWNER"       , 11, "TABLE_OWNER"        },
   {"TABLE_SCHEM"       , 11, "TABLE_OWNER"        },
   {"TABLE_SCHEMA"      , 12, "TABLE_OWNER"        },
   {"TABLE_NAME"        , 10, "TABLE_NAME"         },
   {"TABLE_TYPE"        , 10, "TABLE_TYPE"         },
   {"REMARKS"           ,  7, "TABLE_DESCRIPTION"  },
   {NULL                ,  0, NULL                 }
};

static RXCOLCONV sqlcolumns_conv[] =
{
   {"TABLE_QUALIFIER"   , 15, "TABLE_CATALOG"      },
   {"TABLE_CATALOG"     , 13, "TABLE_CATALOG"      },
   {"TABLE_CAT"         ,  9, "TABLE_CATALOG"      },
   {"TABLE_OWNER"       , 11, "TABLE_OWNER"        },
   {"TABLE_SCHEM"       , 11, "TABLE_OWNER"        },
   {"TABLE_SCHEMA"      , 12, "TABLE_OWNER"        },
   {"TABLE_NAME"        , 10, "TABLE_NAME"         },
   {"COLUMN_NAME"       , 11, "COLUMN_NAME"        },
   {"TYPE_NAME"         ,  9, "COLUMN_TYPE"        },
   {"LENGTH"            ,  6, "COLUMN_SIZE"        },
   {"BUFFER_LENGTH"     , 13, "COLUMN_SIZE"        },
   {"PRECISION"         ,  9, "COLUMN_PRECISION"   },
   {"COLUMN_SIZE"       , 11, "COLUMN_PRECISION"   },
   {"SCALE"             ,  5, "COLUMN_SCALE"       },
   {"DECIMAL_DIGITS"    , 14, "COLUMN_SCALE"       },
   {"NULLABLE"          ,  8, "COLUMN_NULLABLE"    },
   {"REMARKS"           ,  7, "COLUMN_DESCRIPTION" },
   {NULL                ,  0, NULL                 }
};

static char *col_attribute[] =
{
 "NAME", "TYPE", "SIZE", "PRECISION", "SCALE", "NULLABLE", (char *)NULL
};

static int ValidateDataType Args(( RxPackageGlobalDataDef *, char *, int, DBCON * ));

#define SPECIAL_NORMAL     0
#define SPECIAL_SQLTABLES  1
#define SPECIAL_SQLCOLUMNS 2

#define NEED_RXSQL_HENV
#include "rxsqlinc1.h"

/* ---------------------------------------------------------------------
 * Pointer to REXXSQL environment - initially unallocated!
 * Only one object of this type is required and this object is created
 * the first time a connection is made. This object is released whenever
 * the last connection is released or upon exit.
 */
/*static DBENV *DbEnv = (DBENV*)NULL;*/

/*-----------------------------------------------------------------------------
 * Fetch the DB error and put into REXX "SQLCA." compound variable.
 *
 * Really should try to set multiple errors.
 *----------------------------------------------------------------------------*/
static void SetDBError( RxPackageGlobalDataDef *RxPackageGlobalData, char *file, int lineno, RXSQL_HENV henvir, RXSQL_HDBC hdbc, RXSQL_HSTMT hstmt, SQLWA *swa )
{
/* SDWORD    sqlcode=0L;*/
   SQLINTEGER sqlcode=0L;
   char      *txt=NULL;
   UCHAR     msg[SQL_MAX_MESSAGE_LENGTH+1];
   RXSQL_SQLSTATE_TYPE tmpSqlState[SQL_SQLSTATE_SIZE+1];
   char      tmp[50];
/*   SWORD     length=0;*/
   SQLSMALLINT length=0;
   int       i=1;

   InternalTrace( RxPackageGlobalData, "SetDBError", "%s,%d,%x,%x,%x,%x", file, lineno, henvir, hdbc, hstmt, swa );

   /*
    * Get the statement text
    */
   txt = (swa == (SQLWA*)NULL) ? "" : (swa->saved_stmt.sql_stmt) ? swa->saved_stmt.sql_stmt : "";

   /*
    * Get the Database error code and message
    */
   for ( i=1; ; i++ )
   {
      if (SQLError(henvir, hdbc, hstmt, tmpSqlState, &sqlcode, msg, (SQLINTEGER)sizeof(msg)-1, &length) != SQL_SUCCESS)
         break;
      if (i == 1)
      {
         /*
          * Set initial SQLCA. variable
          */
         SetSQLCA( RxPackageGlobalData, sqlcode, tmpSqlState, msg, txt );
      }
      sprintf(tmp,"%s.%d",SQLCA_SQLERRM,i);
      (void)SetRexxVariable( RxPackageGlobalData, tmp, strlen((char*)tmp), msg, strlen((char*)msg) );
      sprintf(tmp,"%s.%d",SQLCA_SQLSTATE,i);
      (void)SetRexxVariable( RxPackageGlobalData, tmp, strlen((char*)tmp), tmpSqlState, strlen((char*)tmpSqlState) );
   }
   sprintf((char*)msg,"%d",i-1);
   sprintf(tmp,"%s.0",SQLCA_SQLERRM);
   (void)SetRexxVariable( RxPackageGlobalData, tmp, strlen((char*)tmp), msg, strlen((char*)msg) );
   sprintf(tmp,"%s.0",SQLCA_SQLSTATE);
   (void)SetRexxVariable( RxPackageGlobalData, tmp, strlen((char*)tmp), msg, strlen((char*)msg) );

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
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "AllocDbEnvironment", NULL );

   if ( ( dbenv = (DBENV*)MALLOC_TSD( RxPackageGlobalData, sizeof(DBENV) ) ) == (DBENV*)NULL )
   {
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10,"out of memory");
      return (DBENV*)NULL;
   }
   dbenv->num_connections = 0;
   dbenv->max_connections = 0;
   dbenv->current_connection = (DBCON*)NULL;

   if ( SQLAllocEnv( &RexxSQLData->henv ) == SQL_ERROR )
   {
      if ( RexxSQLData->henv == SQL_NULL_HENV )
         SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 8,"unable to allocate environment" );
      else
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->henv, SQL_NULL_HDBC, SQL_NULL_HSTMT, NULL );
         SQLFreeEnv( RexxSQLData->henv );
      }
      FREE_TSD( RxPackageGlobalData, dbenv);
      return(DBENV*)NULL;
   }
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
 * Check to make sure we are not attempting to allocate more
 * connections than we are allowed.
 *----------------------------------------------------------------------------*/
static DBCON *AllocConnection( RxPackageGlobalDataDef *RxPackageGlobalData, char *name )
{
   DBCON       *db=NULL;
   char        tmp[61];
#if TRY_TO_GET_CONNECTIONS
   SWORD cons=0,conslen=0;
#endif
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   /*
    * If the number of connections is unlimited or this is the
    * first connection (dbenv->max_connections == 0) for both
    * situations, then continue...
    * ...else check that this connection does not exceed the
    * maximum number of connections.
    */

   InternalTrace( RxPackageGlobalData, "AllocConnection", "%s", name );

   if (RexxSQLData->DbEnv->max_connections != 0
   &&  RexxSQLData->DbEnv->num_connections == RexxSQLData->DbEnv->max_connections)
   {
      sprintf(tmp,"reached maximum number of connections: %d",
                RexxSQLData->DbEnv->max_connections);
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 27,tmp );
      return (DBCON*)NULL;
   }
   if ( ( db = (DBCON*)NewObject( RxPackageGlobalData, sizeof(DBCON) ) ) == (DBCON*)NULL )
   {
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10,"out of memory" );
      return (DBCON*)NULL;
   }
   (void)strncpy(db->name, name, MAX_IDENTIFIER);
   db->dflt_stmt = (void*)NULL;
   db->db_opt = (SQLVAL*)NULL;
   db->num_statements = 0;
   if ( SQLAllocConnect( RexxSQLData->henv, &(db->hdbc) ) != SQL_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->henv, SQL_NULL_HDBC, SQL_NULL_HSTMT, NULL );
      FREE_TSD( RxPackageGlobalData, db );
      return(DBCON*)NULL;
   }
   /*
    * Now we have a valid connection, see how many we are allowed
    */
#if TRY_TO_GET_CONNECTIONS
   SQLGetInfo( db->hdbc, SQL_ACTIVE_CONNECTIONS, &cons, sizeof(cons), &conslen );
   RexxSQLData->DbEnv->max_connections = cons;
#else
   RexxSQLData->DbEnv->max_connections = 0;
#endif
   return db;
}

/*-----------------------------------------------------------------------------
 * Open a database connection. This requires allocating a connection object
 * and making the connection to Database.
 * Check to make sure we are allowed more than 1 connection.
 *----------------------------------------------------------------------------*/
static int OpenConnection( RxPackageGlobalDataDef *RxPackageGlobalData, PSZ name, UCHAR *uid, SWORD uidlen, UCHAR *pwd, SWORD pwdlen, UCHAR *srv, SWORD srvlen, UCHAR *conn, SWORD connlen, DBCON **new_db )
{
#define RET_BUFFER_LEN 1024
   DBCON   *db=NULL;
   UCHAR   buffer[RET_BUFFER_LEN+1];/* buffer for complete connect string */
   SWORD   buflen=0;
   UWORD   funcsupport=0;
   UWORD   have_sqlsetconnectattr=0;
   UWORD   have_sqlsetconnectoption=0;
   int     rc=0,i=0;
   ULONG   warning=0;
   SQLVAL  *curr=NULL;
   void    *result=NULL;
   UDWORD  ext;
   SWORD   extlen;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "OpenConnection", "%s,%s,%d,%s,%d,%s,%d,%s,%d,%x", name, uid, uidlen, pwd, pwdlen, srv, srvlen, conn, connlen, new_db );

   if ( ( db = AllocConnection( RxPackageGlobalData, name ) ) == (DBCON*)NULL )
      return (RexxSQLData->SQLCA_IntCode);

   /*
    * If we have an optional connect string call SQLDriverConnect()
    * rather than SQLConnect() This is not available under OS/2, Unix
    * with Solid Server.
    */
   if ( connlen )
   {
#if defined(REXXSQL_SS_NO_SQLDRIVERCONNECT)
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
#else
# if defined(UDBC_ODBC)
      rc = SQLDriverConnect( db->hdbc, NULL, conn, connlen, buffer, RET_BUFFER_LEN, &buflen, SQL_DRIVER_COMPLETE );
# else
      rc = SQLDriverConnect( db->hdbc, NULL, conn, connlen, buffer, RET_BUFFER_LEN, &buflen, SQL_DRIVER_NOPROMPT );
# endif
#endif
   }
   else
      rc = SQLConnect( db->hdbc, srv, srvlen, uid, uidlen, pwd, pwdlen );
   if (rc != SQL_SUCCESS
   &&  rc != SQL_SUCCESS_WITH_INFO)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }
   /*
    * Check if SQLConnectOption() function is valid...
    * Not available for Solid Server..grrr!
    */
#if !defined(REXXSQL_SS_NO_SQLGETFUNCTIONS)
   funcsupport = 0;
   if (SQLGetFunctions(db->hdbc, SQL_API_SQLBINDPARAMETER, &funcsupport) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }
   db->have_sqlbindparameter = (funcsupport) ? 1 : 0;
   InternalTrace( RxPackageGlobalData, "OpenConnection", "have sqlbindparameter() function: %d", db->have_sqlbindparameter );

   funcsupport = 0;
   if (SQLGetFunctions(db->hdbc, SQL_API_SQLNUMPARAMS, &funcsupport) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }
   db->have_sqlnumparams  = (funcsupport) ? 1 : 0;
   InternalTrace( RxPackageGlobalData, "OpenConnection", "have sqlnumparams function(): %d", db->have_sqlnumparams );

   funcsupport = 0;
   if (SQLGetFunctions(db->hdbc, SQL_API_SQLSETCONNECTOPTION, &funcsupport) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }
   have_sqlsetconnectoption = (funcsupport) ? 1 : 0;
   InternalTrace( RxPackageGlobalData, "OpenConnection", "have sqlsetconnectoption() function: %d", have_sqlsetconnectoption );

   if (!funcsupport)
   {
      funcsupport = 0;
      if (SQLGetFunctions(db->hdbc, SQL_API_SQLSETCONNECTATTR, &funcsupport) != SQL_SUCCESS)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
         FreeObject( RxPackageGlobalData, db );
         return DB_ERROR;
      }
      have_sqlsetconnectattr = funcsupport;
   }
   InternalTrace( RxPackageGlobalData, "OpenConnection", "have sqlsetconnectattr() function: %d", have_sqlsetconnectattr );
#else
   funcsupport = 1;  /* force this to TRUE for Solid Server */
#endif

   /*
    * Force the status of AUTOCOMMIT to OFF
    * We will do our own (more flexible) autocommit
    */
   if (have_sqlsetconnectattr)
   {
      rc = SQLSetConnectAttr(db->hdbc, SQL_ATTR_AUTOCOMMIT, (SQLPOINTER)SQL_AUTOCOMMIT_OFF, SQL_NTS);
      if (rc != SQL_SUCCESS)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
         if (rc == SQL_SUCCESS_WITH_INFO
         ||  strcmp(RexxSQLData->SQLCA_SqlState,"S1C00") == 0)
         {
            warning = DB_WARNING;
         }
         else
         {
            FreeObject( RxPackageGlobalData, db );
            return DB_ERROR;
         }
      }
      InternalTrace( RxPackageGlobalData, "OpenConnection", "Setting AUTOCOMMIT OFF: Result: %d", rc );
   }
   else if (have_sqlsetconnectoption)
   {
      rc = SQLSetConnectOption(db->hdbc, SQL_AUTOCOMMIT, SQL_AUTOCOMMIT_OFF);
      if (rc != SQL_SUCCESS)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
         if (rc == SQL_SUCCESS_WITH_INFO
         ||  strcmp(RexxSQLData->SQLCA_SqlState,"S1C00") == 0)
         {
            warning = DB_WARNING;
         }
         else
         {
            FreeObject( RxPackageGlobalData, db );
            return DB_ERROR;
         }
      }
      InternalTrace( RxPackageGlobalData, "OpenConnection", "Setting AUTOCOMMIT OFF: Result: %d", rc );
   }
   if ( SQLGetInfo( db->hdbc, SQL_GETDATA_EXTENSIONS, (PTR)&ext, sizeof(ext), &extlen) == SQL_ERROR )
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      db->sqlgetdataext = 0;
   }
   else
      db->sqlgetdataext = ext;
   /*
    * Setup any connection-specific variable information
    */
   for ( i = 0; strlen(sqlgetinfo_vars[i].name) != 0; i++ )
   {
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
      /*
       * If this is the first item added, set the pointer to our head.
       */
      if (db->db_opt == NULL)
         db->db_opt = curr;
   }
   *new_db = db;
   return warning;
}

/*-----------------------------------------------------------------------------
 * Allocate a STMT object. One of these is required for each statement
 * including the default statement for a connection. An instance of this object
 * is allocated when (i) a statement is prepared & (ii) the first time
 * SQLCOMMAND() is called for a connection (ie. the default statement is used).
 * Set the cursor name equal to the statment name so that "UPDATE WHERE
 * CURRENT OF cursor" commands can refer to the cursor.
 *----------------------------------------------------------------------------*/
static STMT *AllocStatement( RxPackageGlobalDataDef *RxPackageGlobalData, char *name, DBCON *db )
{
   STMT    *stmt=NULL;
   SQLWA   *swa=NULL;
   int     i=0;
   UWORD   funcsupport=0;

   InternalTrace( RxPackageGlobalData, "AllocStatement", "%s,%x", name, db );

   if ( ( stmt = (STMT*)NewObject( RxPackageGlobalData, sizeof(STMT) ) ) == (STMT*)NULL )
      return (STMT*)NULL;
   stmt->db = db;
   (void)strncpy(stmt->name, name, MAX_DB_CURSOR_NAME);
   stmt->bind = 1;

   /*
    * Initialise SQL Work Area
    */
   swa = SWA(stmt);
   swa->bind_cnt = 0;
   swa->expr_cnt = 0;
   memset( &(swa->saved_stmt), 0, sizeof(SAVEDSQLSTMT) );

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

   /*
    * Allocate a statement handle
    */
   if (SQLAllocStmt(db->hdbc, &stmt->hstmt) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      FreeObject( RxPackageGlobalData, stmt );
      stmt = (STMT*)NULL;
   }
   /*
    * Check if driver supports SQLSetCursorName()
    */
   if (SQLGetFunctions(db->hdbc, SQL_API_SQLSETCURSORNAME, &funcsupport) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      FreeObject( RxPackageGlobalData, db );
      stmt = (STMT*)NULL;
   }
   if ( funcsupport )
   {
      /*
       * Set the cursor name for the statement
       */
      if (SQLSetCursorName(stmt->hstmt,(UCHAR*)name,SQL_NTS) != SQL_SUCCESS)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,NULL );
         FreeObject( RxPackageGlobalData, stmt );
         stmt = (STMT*)NULL;
      }
   }

   return stmt;
}

/*-----------------------------------------------------------------------------
 * Open a statement. This allocates a statement.
 *----------------------------------------------------------------------------*/
static int OpenStatement( RxPackageGlobalDataDef *RxPackageGlobalData, char *name, DBCON *db, STMT **new_stmt )
{
   int     rc=0;
   STMT    *stmt=NULL;

   InternalTrace( RxPackageGlobalData, "OpenStatement", "%s,%x,%x", name, db, new_stmt );

   if ( ( stmt = AllocStatement( RxPackageGlobalData, name, db ) ) == (STMT*)NULL )
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") ); /* ??? */

   *new_stmt = stmt;
   return (rc==0) ? 0 : DB_ERROR;
}

/*-----------------------------------------------------------------------------
 * Disposes a SQL statement. This frees the statement.
 *----------------------------------------------------------------------------*/
static int ReleaseStatement( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt )
{
   SQLWA    *swa = SWA(stmt);
   FLDDSCR  *fd=NULL;
   PMDSCR   *pmd=NULL;
   int      rc=0, i=0;

   InternalTrace( RxPackageGlobalData, "ReleaseStatement", "%x", stmt );

   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );

   /*
    * Close any open cursor...
    */
   if (SQLFreeStmt(stmt->hstmt,SQL_CLOSE) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV,stmt->db->hdbc,SQL_NULL_HSTMT,swa );
      rc = DB_ERROR;
   }
   /*
    * Release the statement
    */
   if (SQLFreeStmt(stmt->hstmt,SQL_DROP) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV,stmt->db->hdbc,SQL_NULL_HSTMT,swa );
      rc = DB_ERROR;
   }

   /*
    * Free up select column descriptors
    */
   for (i = 0; i < MAX_COLS; i++)
   {
      fd = swa->fa[i];
      if (fd == NULL)
         break;
      if (fd->rbuf)
         FREE_TSD( RxPackageGlobalData, fd->rbuf );
      FREE_TSD( RxPackageGlobalData, fd );
   }

   /*
    * Free up parameter marker descriptors
    */
   for (i = 0; i < MAX_BINDVARS; i++)
   {
      pmd = swa->pm[i];
      if (pmd == NULL)
         break;
      if (pmd->buf)
         FREE_TSD( RxPackageGlobalData, pmd->buf );
      FREE_TSD( RxPackageGlobalData, pmd );
   }

   /*
    * Free sql statement buffer (if any)
    */
   if (swa->saved_stmt.sql_stmt)
   {
      FREE_TSD( RxPackageGlobalData, swa->saved_stmt.sql_stmt );
      memset( &(swa->saved_stmt), 0, sizeof(SAVEDSQLSTMT) );
   }

   FreeObject( RxPackageGlobalData, stmt );

   return (rc);
}

/*-----------------------------------------------------------------------------
 * Release a connection. This closes any open statements associated
 * with the connection, closes the connection and frees all resources
 * associated with it.
 * Any open transaction is comitted.
 *----------------------------------------------------------------------------*/
static int ReleaseConnection( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
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
   for (i = 0; db->num_statements && i < TBL_STATEMENTS; i++)
   {
      stmt = (STMT*)FirstObject( RxPackageGlobalData, i, RexxSQLData->DbEnv->stmt_tbl);
      while (stmt && db->num_statements)
      {
         t = (STMT*)NextObject( RxPackageGlobalData, stmt);
         if (stmt->db == db)
         {
            RemoveObject( RxPackageGlobalData, stmt);
            last_error = (rc = ReleaseStatement( RxPackageGlobalData, stmt )) ? rc : last_error;
            db->num_statements--;
         }
         stmt = t;
      }
   }

   /*
    * Dispose all informational data for this connection.
    */
   ll_free( RxPackageGlobalData, db->db_opt );

   /*
    * Dispose the default statement (if any).
    */
   if (db->dflt_stmt)
      last_error = (rc = ReleaseStatement( RxPackageGlobalData, (STMT*)(db->dflt_stmt) )) ? rc : last_error;

#if defined(HAVE_SQLENDTRAN)
   /*
    * End all transactions
    */
   if (SQLEndTran(SQL_HANDLE_DBC,db->hdbc,SQL_COMMIT) == SQL_ERROR)
   {
      if (!last_error)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc,SQL_NULL_HSTMT,NULL );
         last_error = RexxSQLData->SQLCA_SqlCode;
      }
   }
#else
   /*
    * Commit the current transaction (if there is one)
    */
   if (SQLTransact(RexxSQLData->henv, db->hdbc,SQL_COMMIT) == SQL_ERROR)
   {
      if (!last_error)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT, NULL );
         last_error = RexxSQLData->SQLCA_SqlCode;
      }
   }
#endif

   /*
    * Disconnect from DB
    */
   if (SQLDisconnect(db->hdbc) == SQL_ERROR)
   {
      if (!last_error)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc,SQL_NULL_HSTMT,NULL );
         last_error = RexxSQLData->SQLCA_SqlCode;
      }
   }

   /*
    * Release the connection
    */
   if (SQLFreeConnect(db->hdbc) == SQL_ERROR)
   {
      if (!last_error)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc,SQL_NULL_HSTMT,NULL );
         last_error = RexxSQLData->SQLCA_SqlCode;
      }
   }

   /*
    * Free the connection structure
    */
   FreeObject( RxPackageGlobalData, db);

   return (last_error);
}

/*-----------------------------------------------------------------------------
 * Release the database environment. This releases all active connections
 * (if any).
 *----------------------------------------------------------------------------*/
int ReleaseDbEnvironment( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   int    i=0, rc=0, last_error=0;
   DBCON  *db=NULL, *t=NULL;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "ReleaseDbEnvironment", NULL);

   /*
    * Ensure there is an environment to release!
    */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
      return 0;

   /*
    * Release all connections.
    */
   for (i = 0; RexxSQLData->DbEnv->num_connections && i < TBL_CONNECTIONS; i++)
   {
      db = (DBCON*)FirstObject( RxPackageGlobalData, i, RexxSQLData->DbEnv->db_tbl);
      while (db && RexxSQLData->DbEnv->num_connections)
      {
         t = (DBCON*)NextObject( RxPackageGlobalData, db);
         last_error = (rc = ReleaseConnection( RxPackageGlobalData, db )) ? rc : last_error;
         db = t;
      }
   }

   /*
    * Release the environment
    */
   if (SQLFreeEnv(RexxSQLData->henv) == SQL_ERROR)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,RexxSQLData->henv, SQL_NULL_HDBC,SQL_NULL_HSTMT,NULL );
      last_error = RexxSQLData->SQLCA_SqlCode;
   }

   /*
    * Free the DB environment
    */
   FREE_TSD( RxPackageGlobalData, RexxSQLData->DbEnv );
   RexxSQLData->DbEnv = (DBENV*)NULL;

   return (last_error);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLCONNECT( [connection-name, ] [username], [password], <database source>, [connect string])
 *
 * ARGUMENTS:
 *            0 - connection_name (optional)
 *            1 - username (optional)
 *            2 - password (optional)
 *            3 - database source (mandatory) - database name in DB2/2
 *                                            - data source name in ODBC
 *            4 - ODBC connect string (optional)
 *                if arg 4 supplied all other arguments MUST be empty
 *                (except connection_name)
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLCONNECT )
{
   UCHAR uid[MAX_IDENTIFIER];
   SWORD uidlen=0;
   UCHAR pwd[MAX_IDENTIFIER];
   SWORD pwdlen=0;
   UCHAR srv_dsn[MAX_IDENTIFIER+1];
   SWORD srvlen=0;
   UCHAR *conn=NULL;
   SWORD connlen=0;
   char  dbname[MAX_IDENTIFIER+1];
   int   rc=0;
   char  tmp[128];
   DBCON *db=NULL;
   char  dsn_supplied=0;
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

   /*
    * If there is an optional connect string, ensure that none of
    * the other data arguments are supplied.
    */
   if (argc == 5
   &&  RXSTRLEN(argv[4]))
   {
      dsn_supplied = 1;
      if (RXSTRLEN(argv[1])
      ||  RXSTRLEN(argv[2])
      ||  RXSTRLEN(argv[3]))
        return ReturnError( RxPackageGlobalData, retstr, 76, "<connect string> must be only argument" );
   }

   if (RXSTRLEN(argv[1]))                            /* a userid passed */
   {
      RXSTRCPY(uid,uidlen,RXSTRPTR(argv[1]),(SWORD)RXSTRLEN(argv[1]));
   }
   else
   {
      RXSTRCPY(uid,uidlen,"",0);
   }

   if (RXSTRLEN(argv[2]))                          /* a password passed */
   {
      RXSTRCPY(pwd,pwdlen,RXSTRPTR(argv[2]),(SWORD)RXSTRLEN(argv[2]));
   }
   else
   {
      RXSTRCPY(pwd,pwdlen,"",0);
   }

   if (RXSTRLEN(argv[3]))                /* a DSN or server name passed */
   {
      RXSTRCPY(srv_dsn,srvlen,RXSTRPTR(argv[3]),(SWORD)RXSTRLEN(argv[3]));
   }
   else
   {
#if defined(SOLID_SERVER)
      /*
       * Solid Server allows an empty DSN. This uses the default DSN
       */
      RXSTRCPY(srv_dsn,srvlen,"",0);
#else
      if (!dsn_supplied)
         return ReturnError( RxPackageGlobalData, retstr, 75, "no database name supplied" );
#endif
   }

   /*
    * Get the name of the connection (default if not specified).
    */
   if (RXSTRLEN(argv[0]))
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], dbname, sizeof(dbname) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );
   }
   else
      (void)strcpy(dbname, DEFAULT_CONNECTION);

   /*
    * Allocate a DB environment if none exists!
    */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
   {
      if ( ( RexxSQLData->DbEnv = AllocDbEnvironment( RxPackageGlobalData ) ) == (DBENV*)NULL )
         return RxReturnNumber( RxPackageGlobalData, retstr,RexxSQLData->SQLCA_IntCode );
   }

   /*
    * Make sure there is no existing connection with the same name
    */
   if ( FindObject( RxPackageGlobalData,  dbname, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS ) )
   {
      (void)sprintf( tmp, "connection already open with name \"%s\".", dbname );
      return ReturnError( RxPackageGlobalData, retstr, 20, tmp );
   }

   /*
    * If there is an optional connect string, make a copy of it
    */
   if ( dsn_supplied )
   {
      if ( ( conn = (UCHAR *)MALLOC_TSD( RxPackageGlobalData, (RXSTRLEN(argv[4])+1)*sizeof(UCHAR) ) ) == NULL )
         return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
      connlen = (SWORD)RXSTRLEN(argv[4]);
      RXSTRCPY(conn,connlen,RXSTRPTR(argv[4]),(SWORD)RXSTRLEN(argv[4]));
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: conn: %x connlen: %d\n", __FILE__,__LINE__,conn, connlen);)
   /*
    * Open a new connection for the given connect string.
    */
   if ( ( rc = OpenConnection( RxPackageGlobalData, dbname, uid, uidlen, pwd, pwdlen,
             srv_dsn, srvlen, (conn) ? conn : (UCHAR *)"", connlen, &db)) == DB_ERROR)
       return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );

   DEBUGDUMP(fprintf(stderr,"%s-%d: conn: %x connlen: %d\n", __FILE__,__LINE__,conn, connlen);)

   if (conn)
      FREE_TSD( RxPackageGlobalData, conn );
   RexxSQLData->DbEnv->num_connections++;
   RexxSQLData->DbEnv->current_connection = db;
   (void)InsertObject( RxPackageGlobalData, db, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS );

   return RxReturnNumber( RxPackageGlobalData, retstr, rc );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDISCONNECT( [connection-name ] )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLDISCONNECT )
{
   int         rc = 0;
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
      return RxReturnNumber( RxPackageGlobalData, retstr, 0L );

   if (argc && RXSTRLEN(argv[0]))
   {
      /*
       * A connection has been named
       */
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], dbname, sizeof(dbname) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );

      /*
       * Make sure the named connection exists.
       */
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

   /*
    * Do the disconnection
    */
   rc = ReleaseConnection( RxPackageGlobalData, db );

   /*
    * Free the environment if zero connections remaining
    */
   if (RexxSQLData->DbEnv->num_connections == 0)
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

   if (argc && RXSTRLEN(argv[0]))
   {
      /*
       * Get the normalised name of the connection.
       */
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], dbname, sizeof(dbname) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );

      /*
       * Make sure we have an environment!
       */
      if (RexxSQLData->DbEnv == (DBENV*)NULL)
         return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

      /*
       * Make sure the Connection Name is a valid one!
       */
      if ( ( db = FindObject( RxPackageGlobalData, dbname, RexxSQLData->DbEnv->db_tbl, TBL_CONNECTIONS ) ) == (DBCON*)NULL )
      {
         (void)sprintf(tmp,"connection \"%s\" is not open.", dbname);
         return ReturnError( RxPackageGlobalData, retstr, 21, tmp );
      }

      /*
       * Make connection the default one!
       */
      RexxSQLData->DbEnv->current_connection = db;

      return RxReturnNumber( RxPackageGlobalData, retstr, 0L );
   }
   else
   {
      if (RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection)
      {
         return RxReturnString( RxPackageGlobalData, retstr,RexxSQLData->DbEnv->current_connection->name );
      }
      else
         return RxReturnString( RxPackageGlobalData, retstr, "" );
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
       return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

   if (RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if (SQLTransact(RexxSQLData->henv, db->hdbc,commit) == SQL_ERROR)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT, NULL );
      rc = RexxSQLData->SQLCA_SqlCode;
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, (rc==0)?0:DB_ERROR );
}


/*-----------------------------------------------------------------------------
 * This function determines the number of decimal places (if any) in
 * the supplied string.
 *----------------------------------------------------------------------------*/
static int GetDecimals( RxPackageGlobalDataDef *RxPackageGlobalData, char *val, int vallen )
{
   int i=0,numdec=0;

   InternalTrace( RxPackageGlobalData, "GetDecimals", "Entry: %s,%d", val, vallen );

/*
  for (i=vallen;i>(-1);i--)
*/
  for ( i = 0 ; i < vallen; i++ )
   {
      if (*(val+i) == '.')
      {
         numdec = vallen - i - 1;
         break;
      }
   }
   InternalTrace( RxPackageGlobalData, "GetDecimals", "Exit: NumDecimals %d", numdec );
   return (numdec);
}

/*-----------------------------------------------------------------------------
 * This function validates the supplied datatype and attempts to set
 * the length and scale values correctly.
 *----------------------------------------------------------------------------*/
static int GetValidDatatype( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db, char *str, int strlen, char *val, int vallen, SWORD *datatype, SDWORD *length, SWORD *scale )
{
   int   bind_type=0;

   InternalTrace( RxPackageGlobalData, "GetValidDatatype", "Entry: %x,Type: %s,%d Vallen:%d BindType:%d Length:%d Scale:%d", db,str,strlen,vallen,*datatype,*length,*scale );

   /*
    * Check that the supplied string is valid.
    */
   bind_type = ValidateDataType( RxPackageGlobalData, str, strlen, db );
   if (bind_type == (RXSQL_INVALID_DATATYPE))
      return(1);
   *datatype = (SWORD)bind_type;

   switch(*datatype)
   {
      case SQL_DECIMAL:
      case SQL_NUMERIC:
         *length = vallen+2;     /* extra 2 for sign and decimal point */
         *scale = GetDecimals( RxPackageGlobalData, val, vallen ); /* digits to right of decimal point */
         break;
      case SQL_TIMESTAMP:
         /*
          * Major hack for SQLBase; its handling of TIMESTAMP datatypes
          * appears to be inconsitant with other databases :-(
          */
#ifdef SQLBASE_HACK
         if ( strcmp( DBMSName, "SQLBase" ) == 0 )
         {
            *length = vallen;       /* no extra for TIMESTAMP */
            *scale = GetDecimals( RxPackageGlobalData, val, vallen )-1; /* digits to right of decimal point */
         }
         else
#endif
         {
            *length = vallen+2;     /* extra 2 for sign and decimal point */
            *scale = GetDecimals( RxPackageGlobalData, val, vallen ); /* digits to right of decimal point */
         }
         break;
      default:
         *length = vallen;
         *scale = 0;
         break;
   }
   InternalTrace( RxPackageGlobalData, "GetValidDatatype", "Exit: %x,Type: %s,%d Vallen:%d BindType:%d Length:%d Scale:%d", db,str,strlen,vallen,*datatype,*length,*scale );
   return (0);
}

/*-----------------------------------------------------------------------------
 * Binds all arguments for standard placemarkers (by number)
 *----------------------------------------------------------------------------*/
static int BindByStandard( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt, ULONG argc, RXSTRING argv[] )
{
   int      colno=0,i=0;
   int      rc=0;
   long     bindlen=0L;
   char     tmp[128];
   SQLWA    *swa=SWA(stmt);
   SWORD    pm=0;
   SDWORD   length=0;
   SWORD    scale=0;
   SWORD    datatype=0;
   PMDSCR   *pmd=(PMDSCR*)NULL;
   RXSTRING *Varg=NULL, *Darg=NULL;
   FILE     *fp=NULL;
   struct   stat stat_buf;
   int      long_value=0;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "BindByStandard", "%x,%d,%x", stmt, argc, argv );

   /*
    * Check that the number of parameter markers in the statement (* 2)
    * matches the number of arguments passed.
    */
   if (argc % 2)
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 62, "bind values must be paired") );

   if (stmt->db->have_sqlnumparams)
   {
      if (SQLNumParams(stmt->hstmt, &pm) != SQL_SUCCESS)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
         return DB_ERROR;
      }
   }
   else
   {
      pm = CountQuestionMarks( RxPackageGlobalData, swa->saved_stmt.sql_stmt );
   }
   if (pm * 2 != (SWORD)argc)
   {
      (void)sprintf(tmp, "%ld bind values passed. %d expected",argc/2, pm);
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 61, tmp) );
   }

   /*
    * Bind all variables (if any) to placeholders in SQL statement. It is
    * assumed that the variables are static for the life of the SQL statement
    * i.e. their addresses remain fixed.
    */
   for (i=0,colno=0;i<(int)argc && i<MAX_BINDVARS;colno++)
   {
      /*
       * Reset to default values
       */
      length=0;
      scale=0;
      datatype=0;
      Darg = &argv[i++];
      Varg = &argv[i++];
      /*
       * Get the parameter marker descriptor
       */
      if (swa->pm[colno] == (PMDSCR*)NULL)
      {
         if ( ( pmd = (swa->pm[colno] = (PMDSCR*)MALLOC_TSD( RxPackageGlobalData, sizeof(PMDSCR) ) ) ) == (PMDSCR*)NULL )
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
         pmd->buf = (char*)NULL;
         pmd->buflen = 0L;
         pmd->retlen = 0L;
      }
      else
         pmd = swa->pm[colno];
      /*
       * Check bind value type. If "FILE:", then get bind value from
       * the filename. In this format the bind value is a string
       */
      if ( memcmpi( RxPackageGlobalData, RXSTRPTR(*Darg), "FILE:", 5 ) == 0 )
      {
         char *ptr = (char *)RXSTRPTR(*Darg);
         /*
          * Obtain the size of the file before attempting to get the bind
          * value length, because the bind value length will be the
          * size of the file.  Also must read the file to get the value
          * in case it is a decimal column.
          */
         if ((fp = fopen(RXSTRPTR(*Varg),"rb")) == NULL)
         {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
            sprintf(tmp,"<open> on file <%s> failed: %s.",RXSTRPTR(*Varg),strerror(errno));
#else
            sprintf(tmp,"<open> on file <%s> failed.",RXSTRPTR(*Varg));
#endif
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
         }
         stat(RXSTRPTR(*Varg),&stat_buf);
         bindlen = (int)stat_buf.st_size;
         /*
          * In an attempt to save malloc() & free() calls we keep the old
          * buffer providing it is not grossly oversized.
          */
         if ((size_t)pmd->buflen < (size_t)bindlen
         || (size_t)pmd->buflen > (size_t)(bindlen + 256))
         {
            /* Free the old buffer (if any) */
            if (pmd->buf)
            {
               FREE_TSD( RxPackageGlobalData, pmd->buf );
               pmd->buflen = 0;
            }
            /* Allocate a new buffer */
            if ( ( pmd->buf = (UCHAR*)MALLOC_TSD( RxPackageGlobalData, bindlen+1 ) ) == (UCHAR*)NULL )
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
            pmd->buflen = bindlen;
         }
         if ((LONG)fread(pmd->buf,sizeof(char),bindlen,fp) != bindlen)
         {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
            sprintf(tmp,"<read> on file <%s> failed: %s.",RXSTRPTR(*Varg),strerror(errno));
#else
            sprintf(tmp,"<read> on file <%s> failed.",RXSTRPTR(*Varg));
#endif
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
         }
         if (fclose(fp))
         {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
            sprintf(tmp,"<close> on file <%s> failed: %s.",RXSTRPTR(*Varg),strerror(errno));
#else
            sprintf(tmp,"<close> on file <%s> failed.",RXSTRPTR(*Varg));
#endif
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
         }
         pmd->buf[bindlen] = '\0';
         InternalTrace( RxPackageGlobalData, "BindByStandard:", "File: %s read successfully. Size: %d", RXSTRPTR(*Varg), bindlen);
         if ( GetValidDatatype( RxPackageGlobalData, stmt->db, ptr+5, RXSTRLEN(*Darg)-5,
                           pmd->buf,bindlen,
                           &datatype,&length,&scale))
         {
            (void)sprintf(tmp, "invalid datatype %s specified",ptr+5);
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 64, tmp) );
         }
      }
      else if ( memcmpi( RxPackageGlobalData, RXSTRPTR(*Darg), "RAWFILE:", 8 ) == 0 )
      {
         char *ptr = (char *)RXSTRPTR(*Darg);
         /*
          * Obtain the size of the file before attempting to get the bind
          * value length, because the bind value length will be the
          * size of the file.  Also must read the file to get the value
          * in case it is a decimal column.
          */
         if ((fp = fopen(RXSTRPTR(*Varg),"rb")) == NULL)
         {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
            sprintf(tmp,"<open> on file <%s> failed: %s.",RXSTRPTR(*Varg),strerror(errno));
#else
            sprintf(tmp,"<open> on file <%s> failed.",RXSTRPTR(*Varg));
#endif
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
         }
         stat(RXSTRPTR(*Varg),&stat_buf);
         bindlen = (int)stat_buf.st_size;
         /*
          * In an attempt to save malloc() & free() calls we keep the old
          * buffer providing it is not grossly oversized.
          */
         if ((size_t)pmd->buflen < (size_t)bindlen
         || (size_t)pmd->buflen > (size_t)(bindlen + 256))
         {
            /* Free the old buffer (if any) */
            if (pmd->buf)
            {
               FREE_TSD( RxPackageGlobalData, pmd->buf );
               pmd->buflen = 0;
            }
            /* Allocate a new buffer */
            if ( ( pmd->buf = (UCHAR*)MALLOC_TSD( RxPackageGlobalData, bindlen+1 ) ) == (UCHAR*)NULL )
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
            pmd->buflen = bindlen;
         }
         if ((LONG)fread(pmd->buf,sizeof(char),bindlen,fp) != bindlen)
         {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
            sprintf(tmp,"<read> on file <%s> failed: %s.",RXSTRPTR(*Varg),strerror(errno));
#else
            sprintf(tmp,"<read> on file <%s> failed.",RXSTRPTR(*Varg));
#endif
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
         }
         if (fclose(fp))
         {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
            sprintf(tmp,"<close> on file <%s> failed: %s.",RXSTRPTR(*Varg),strerror(errno));
#else
            sprintf(tmp,"<close> on file <%s> failed.",RXSTRPTR(*Varg));
#endif
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
         }
         pmd->buf[bindlen] = '\0';
         InternalTrace( RxPackageGlobalData, "BindByStandard:", "File: %s read successfully. Size: %d", RXSTRPTR(*Varg), bindlen);
         if ( GetValidDatatype( RxPackageGlobalData, stmt->db, ptr+8, RXSTRLEN(*Darg)-8,
                           pmd->buf,bindlen,
                           &datatype,&length,&scale))
         {
            (void)sprintf(tmp, "invalid datatype %s specified",ptr+8);
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 64, tmp) );
         }
      }
      else if ( memcmpi( RxPackageGlobalData, RXSTRPTR(*Darg), "LONG:", 5 ) == 0 )
      {
         char *ptr = (char *)RXSTRPTR(*Darg);
         long_value = 1;
         if ( GetValidDatatype( RxPackageGlobalData, stmt->db, ptr+5, RXSTRLEN(*Darg)-5,
                           pmd->buf,bindlen,
                           &datatype,&length,&scale))
         {
            (void)sprintf(tmp, "invalid datatype %s specified",ptr+5);
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 64, tmp) );
         }
         if ( stat(RXSTRPTR(*Varg),&stat_buf) == -1)
         {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
            sprintf(tmp,"file <%s> does not exist: %s.",RXSTRPTR(*Varg),strerror(errno));
#else
            sprintf(tmp,"file <%s> does not exist.",RXSTRPTR(*Varg));
#endif
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
         }

         bindlen = RXSTRLEN(*Varg);
         /*
          * In an attempt to save malloc() & free() calls we keep the old
          * buffer providing it is not grossly oversized.
          */
         if ((size_t)pmd->buflen < (size_t)bindlen
         || (size_t)pmd->buflen > (size_t)(bindlen + 256))
         {
            /* Free the old buffer (if any) */
            if (pmd->buf)
            {
               FREE_TSD( RxPackageGlobalData, pmd->buf );
               pmd->buflen = 0;
            }
            /* Allocate a new buffer */
            if ( ( pmd->buf = (UCHAR*)MALLOC_TSD( RxPackageGlobalData, bindlen+1 ) ) == (UCHAR*)NULL )
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
            pmd->buflen = bindlen;
         }
         memcpy( pmd->buf, RXSTRPTR(*Varg), bindlen );
         pmd->buf[bindlen] = '\0';
         /* determine which driver version is used */
         pmd->retlen = SQL_LEN_DATA_AT_EXEC(0);
      }
      else
      {
         if ( GetValidDatatype( RxPackageGlobalData, stmt->db, RXSTRPTR(*Darg), RXSTRLEN(*Darg),
                           RXSTRPTR(*Varg),RXSTRLEN(*Varg),
                           &datatype,&length,&scale))
         {
            (void)sprintf(tmp, "invalid datatype %s specified",RXSTRPTR(*Darg));
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 64, tmp) );
         }
         /*
          * In an attempt to save malloc() & free() calls we keep the old
          * buffer providing it is not grossly oversized.
          */
         if ((size_t)pmd->buflen < RXSTRLEN(*Varg)
         || (size_t)pmd->buflen > RXSTRLEN(*Varg) + 256)
         {
            /* Free the old buffer (if any) */
            if (pmd->buf)
            {
               FREE_TSD( RxPackageGlobalData, pmd->buf );
               pmd->buflen = 0;
            }
            /* Allocate a new buffer */
            if ( ( pmd->buf = (UCHAR*)MALLOC_TSD( RxPackageGlobalData, RXSTRLEN(*Varg)+1 ) ) == (UCHAR*)NULL )
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
            pmd->buflen = RXSTRLEN(*Varg);
         }
         memcpy(pmd->buf,RXSTRPTR(*Varg),RXSTRLEN(*Varg));
         pmd->buf[RXSTRLEN(*Varg)] = '\0';
      }
      /*
       * If the suppplied bind value matches the string for NULL column
       * set the value to NULL.
       */
      if ( ( memcmp( pmd->buf, RexxSQLData->NullStringIn, pmd->buflen ) ) == 0 )
         /* indicate a NULL value */
         pmd->retlen = SQL_NULL_DATA;
      else
      {
         /*
          * Don't set length if LONG: type specified; it is already
          * set!
          */
         if ( !long_value )
         {
#if 0
            pmd->retlen = pmd->buflen;
#else
            pmd->retlen = length;
#endif
         }
      }

#if defined(UDBC_ODBC) && defined(OS2)
      if (rc = SQLSetParam(stmt->hstmt,
                         colno+1,
                         SQL_C_CHAR,
                         datatype,
                         length,
                         scale,
                         pmd->buf,
                         &pmd->retlen))
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
         return DB_ERROR;
      }
#else
      if (stmt->db->have_sqlbindparameter)
      {
         if ( (rc = SQLBindParameter(stmt->hstmt,
            colno+1,
            SQL_PARAM_INPUT,
            (long_value) ? SQL_C_BINARY : SQL_C_CHAR,
            datatype,
            length,
            scale,
            pmd->buf,
# if 0
            pmd->buflen,
# else
            length,
# endif
            &pmd->retlen)) != 0 )
         {
            SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
            return DB_ERROR;
         }
         InternalTrace( RxPackageGlobalData, "BindByStandard:", "Binding with SQLBindParameter: colno: %d Datatype: %d Length: %d Scale: %d BufLen: %d Return Length: %d Long?: %d",
                        colno+1, datatype, length, scale, pmd->buflen, pmd->retlen, long_value );
      }
# if !defined(PGSQLODBC) && !defined(EASYSOFT_OOB)
      else
      {
         if ( (rc = SQLSetParam(stmt->hstmt,
                colno+1,
                SQL_C_CHAR,
                datatype,
                length,
                scale,
                pmd->buf,
                &pmd->retlen)) != 0 )
         {
            SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
            return DB_ERROR;
         }
         InternalTrace( RxPackageGlobalData, "BindByStandard:", "Binding with SQLSetParam: colno: %d Datatype: %d Length: %d Scale: %d Return Length: %d",
                        colno+1, datatype, length, scale, pmd->retlen );
      }
# endif
#endif
   }

   /*
    * If previous bind count is non-zero (i.e. a previous bind for
    * this statement then check all values are re-bound.
    */
   if (swa->bind_cnt && colno < swa->bind_cnt)
   {
      (void)sprintf(tmp, "%d bind values passed. %d expected", colno, swa->bind_cnt);
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 61, tmp) );
   }

   /*
    * save the new bind count
    */
   swa->bind_cnt = pm;

   return (0);
}

/*-----------------------------------------------------------------------------
 * This function binds all values (supplied as a list of arguments) to
 * the specified cursor.
 * Each variable to be bound, counsists of a pair of parameters:
 * The first is the datatype of the parameter marker, which can be one of:
 *      CHAR
 *      INTEGER
 *      ....
 * The second is the actual value of the variable.
 *----------------------------------------------------------------------------*/
static int BindValues( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt, ULONG argc, RXSTRING argv[] )
{
   int      bind_by_array=0;
   int      arglen1=0,arglen2=0;
   int      rc=0;

   InternalTrace( RxPackageGlobalData, "BindValues", "%x,%d,%x", stmt, argc, argv );

   if ( ( stmt->Argv = (RXSTRING*)MALLOC_TSD( RxPackageGlobalData, 2*MAX_BINDVARS*sizeof(RXSTRING) ) ) == NULL )
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
   memset(stmt->Argv,0,2*MAX_BINDVARS*sizeof(RXSTRING));
   /*
    * Determine if the bind variables are being passed as arrays
    */
   if (argc == 2)
   {
      arglen1 = RXSTRLEN(argv[0]);
      arglen2 = RXSTRLEN(argv[1]);
      if (arglen1 && *(RXSTRPTR(argv[0])+arglen1-1) == '.'
      &&  arglen2 && *(RXSTRPTR(argv[1])+arglen2-1) == '.')
      {
         bind_by_array = 1;
         if ( ( rc = ArrayToArgv( RxPackageGlobalData, &(argv[0]), &(argv[1]), &stmt->Argc, stmt->Argv ) ) != 0 )
         {
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
            return(rc);
         }
      }
   }
   if (!bind_by_array)
   {
      if ( ArgvToArgv( RxPackageGlobalData, argc, argv, &stmt->Argc, stmt->Argv) )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
      }
   }
   /*
    * Bind by standard placemarkers
    */
   rc = BindByStandard( RxPackageGlobalData, stmt, stmt->Argc, stmt->Argv );
   return (rc);
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
      if ( ( fd = (swa->fa[i] = (FLDDSCR*)MALLOC_TSD( RxPackageGlobalData, sizeof(FLDDSCR) ) ) )
                    == (FLDDSCR*)NULL)
      {
         return (FLDDSCR*)NULL;
      }
      fd->rbuf = (char*)NULL;
      fd->rbufl = 0;
      fd->retl = 0;
      fd->rcode = 0;
   }
   return fd;
}

/*-----------------------------------------------------------------------------
 * Describes columns (expressions) and defines the output buffers for each
 * column for the select statement in nominated cursor.
 * Also binds the columns in the result set to the output buffers for the
 * subsequent fetch.
 * Returns the number of expressions in the select statement.
 *----------------------------------------------------------------------------*/
static int DefineExpressions( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt )
{
   SQLWA       *swa=SWA(stmt);
   FLDDSCR     *fd=NULL;
   SWORD real_column_length=0;
   int         i=0;
   SDWORD  varlen=0;

   InternalTrace( RxPackageGlobalData, "DefineExpressions", "%x", stmt );

   /*
    * determine the number of columns in the result set
    */
   if (SQLNumResultCols(stmt->hstmt,&(swa->expr_cnt)) == SQL_ERROR)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
      return (DB_ERROR);
   }

   InternalTrace( RxPackageGlobalData, "DefineExpressions", "Number of columns: %d", swa->expr_cnt );

   /*
    * Describe & define buffer for each expression in the SELECT statement
    */
   for (i = 0; i < swa->expr_cnt ; i++)
   {
      /* Get a new field descriptor */
      if ( ( fd = GetFldDscr( RxPackageGlobalData, swa, i ) ) == (FLDDSCR*)NULL )
         return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );

      fd->cbufl = sizeof(fd->cbuf) - 1;

      /*
       * get general info about a column
       */
      if (SQLDescribeCol(stmt->hstmt,(UWORD)i+1,(UCHAR*)fd->cbuf,(SWORD)fd->cbufl,(SWORD*)&real_column_length,
                       (SWORD*)&(fd->dbtype),(UDWORD*)&(fd->prec),(SWORD*)&(fd->scale),(SWORD*)&(fd->nullok)) == SQL_ERROR)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
         return (DB_ERROR);
      }

      /*
       * get the display size of the column
       */
      if (SQLColAttributes(stmt->hstmt,(UWORD)i+1,(UWORD)SQL_COLUMN_DISPLAY_SIZE, NULL,(SWORD)0,NULL, (SDWORD*)&varlen) == SQL_ERROR)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
         return (DB_ERROR);
      }
      /* if varlen == -2 TODO SQLServer Image column type*/
      if ( varlen == (SDWORD)-2 )
      {
         varlen = strlen( UNBOUND_COLUMN );
         fd->bind = 0;
      }
      else
         fd->bind = 1;

      DEBUGDUMP(fprintf(stderr,"%s-%d: Name: %s Display Size from SQLColAttributes: %d Real Column Length from SQLDescribeCol: %d\n", __FILE__,__LINE__,fd->cbuf, varlen, real_column_length);)

      /*
       * If display size > DEFAULT_LONG_LIMIT, then restrict the size of the data,
       */
      if (varlen > DEFAULT_LONG_LIMIT)
         varlen = DEFAULT_LONG_LIMIT - 1;
      /*
       * Set the buffer length to be a couple of bytes larger than the
       * display length to account for the terminating NUL character and
       * implementations that return 1 more byte than they should on
       * SQLFetch (Velocis 2.1)
       */
#if defined(VELOCIS21)
      varlen += 2;
#else
      varlen++;
#endif

      /*
       * Terminate the Column Name
       */
      fd->cbufl = strlen(fd->cbuf);

      /*
       * Set the column name to upper case
       */
      (void)make_upper( RxPackageGlobalData, fd->cbuf );

      /*
       * In an attempt to save malloc() & free() calls we keep the old
       * buffer providing it is not grossly oversized.
       */
      if ((size_t)fd->rbufl < (size_t)varlen
      || (size_t)fd->rbufl > (size_t)(varlen + 256))
      {
         /*
          * Free the old buffer (if any)
          */
         if (fd->rbufl)
         {
            FREE_TSD( RxPackageGlobalData, fd->rbuf );
            fd->rbufl = 0;
         }
         /*
          * Allocate a new buffer
          */
         if ( ( fd->rbuf = (UCHAR *)MALLOC_TSD( RxPackageGlobalData, 1+varlen ) ) == (UCHAR *)NULL )
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
      }
      /*
       * Save the display length that the implementation has determined, so
       * we can use it later for terminating the value correctly.
       */
#if defined(VELOCIS21)
      fd->rbufl = varlen - 2;
#else
      fd->rbufl = varlen - 1;
#endif

      /*
       * bind the columns to the storage area used to save the data
       * only if stmt->bind = 1
       */
      if ( stmt->bind && fd->bind )
      {
         if (SQLBindCol(stmt->hstmt,(UWORD)i+1,(SWORD)SQL_C_CHAR,(PTR)fd->rbuf,(SDWORD)varlen,(SDWORD*)&(fd->retl)) == SQL_ERROR)
         {
            SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
            return (DB_ERROR);
         }
         DEBUGDUMP(fprintf(stderr,"%s-%d: Name: %s DISPLAY_SIZE: %d REAL_COLUMN_LENGTH: %d RETL: %d PREC: %d\n", __FILE__,__LINE__,fd->cbuf, varlen, real_column_length, fd->retl, fd->prec);)
      }
   }

   return (swa->expr_cnt);
}

/*-----------------------------------------------------------------------------
 * Converts a returned column name from the database to the "standard"
 * column names.
 *----------------------------------------------------------------------------*/
static char *convertColumnName( RxPackageGlobalDataDef *RxPackageGlobalData, char *cbuf, int special )
{
   RXCOLCONV *conv;
   int i;

   if ( special == SPECIAL_SQLTABLES )
      conv = sqltables_conv;
   else
      conv = sqlcolumns_conv;
   for ( i = 0; conv[i].odbc_colname != NULL; i++  )
   {
      if ( memcmpi( RxPackageGlobalData, cbuf, conv[i].odbc_colname, conv[i].odbc_colname_length ) == 0 )
         return (conv[i].rxsql_colname );
   }
   return NULL;
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
 * failure: database return code
 *----------------------------------------------------------------------------*/
static int FetchRow( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt, char *stem, ULONG rowcount, int special )
{
   FLDDSCR *fd=NULL;
   SQLWA   *swa=NULL;
   int     rc=0, i=0, return_code=0;
   size_t  varlen=0;
   char    varname[MAX_IDENTIFIER+1+10];
   char    tmp[128];
   char    *colname;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "FetchRow", "%x,%s,%d,%d", stmt, stem, rowcount, special );

   swa = SWA(stmt);

   rc = SQLFetch(stmt->hstmt);
   if (rc == SQL_NO_DATA_FOUND)
      return (rc);

   if (rc != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
      if (rc == SQL_SUCCESS_WITH_INFO)
      {
         return_code = DB_WARNING;
      }
      else
         return DB_ERROR;
   }

   /*
    * If the statement was prepared without binding columns to output
    * fields, then don't set any Rexx variables here; the user will have
    * to get each field value themselves.
    */
   if ( stmt->bind )
   {
      /*
       * Get each expr value in turn
       */
      for (rc=0,i=0; rc == 0 && i < swa->expr_cnt; i++)
      {
         fd = swa->fa[i];
         /*
          * If the column has not been bound, fill in the column contents with the placemarker
          */
         if ( fd->bind == 0 )
         {
            strcpy( fd->rbuf, UNBOUND_COLUMN );
            fd->retl = fd->rbufl;
         }
#ifdef USE_GETDATA
         rc = SQLGetData(stmt->hstmt,(UWORD)i+1,(SWORD)SQL_C_CHAR, (PTR)fd->rbuf, (SDWORD)((fd->rbufl)+1), (SDWORD*)&(fd->retl));
         if (rc != SQL_SUCCESS)
         {
            SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
            return (DB_ERROR);
         }
#endif
         DEBUGDUMP(fprintf(stderr,"%s-%d: Name: %s Expecting: %d got %d\n", __FILE__,__LINE__,fd->cbuf, fd->rbufl, fd->retl);)
         /*
          * Add each column value to the stem's values
          */
         if ( special )
            colname = convertColumnName( RxPackageGlobalData, fd->cbuf, special );
         else
            colname = fd->cbuf;
         if ( colname )
         {
            if ( rowcount )
               varlen = sprintf( varname, "%s.%s.%lu", stem, colname, rowcount );
            else
               varlen = sprintf( varname, "%s.%s", stem, colname );

            if (fd->retl == SQL_NULL_DATA)      /* returned value is NULL */
               rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, RexxSQLData->RXSNullStringOut.strptr, RexxSQLData->RXSNullStringOut.strlength );
            else
            {
#if defined(VELOCIS21)
               /*
                * Work around bug in Velocis.
                * For DATE fields, the display length from SQLColAttributes is 10
                * - correct, but the return length (fd->retl) from SQLFetch is 11
                * - wrong!.  It seems that SQLFetch includes the terminating NUL
                * in the returned length.
                */
               if (fd->retl == fd->rbufl + 1
               &&  fd->rbuf[fd->rbufl] == '\0')
                  fd->retl--;
#endif
               if ( fd->retl > fd->rbufl )  /* truncation or conversion occured */
               {
                  if ( RexxSQLData->IgnoreTruncate )
                     rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, fd->rbuf, fd->rbufl );
                  else
                  {
                     sprintf(tmp,"Conversion/truncation occurred on column %s: Expecting %ld, got %ld",
                             fd->cbuf,fd->rbufl,fd->retl);
                     return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 15, tmp) );
                  }
               }
               else
                  rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, fd->rbuf, fd->retl );
            }
         }
      }
   }
   if (rc)
   {
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 16, "unable to set REXX variable");
      return rc;
   }
   return return_code;
}

static int SetRowCountVar( RxPackageGlobalDataDef *RxPackageGlobalData, SQLWA *swa, char *stem_name, long rowcount, int special )
{
   int     i=0,rc=0;
   char    varname[MAX_IDENTIFIER*2+4], buf[11];
   int     varlen, buflen;
   char    *colname;

   InternalTrace( RxPackageGlobalData, "SetRowCountVar", "%x,%s,%d", swa, stem_name, rowcount );

   for (i = 0; i < swa->expr_cnt; i++)
   {
      if ( special )
         colname = convertColumnName( RxPackageGlobalData, swa->fa[i]->cbuf, special );
      else
         colname = swa->fa[i]->cbuf;
      if ( colname )
      {
         varlen = sprintf( varname, "%s.%s.0", stem_name, colname );
         buflen = sprintf( buf, "%lu", rowcount );
         if ( (rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, buf, buflen ) ) != 0 )
            return(-16);
      }
   }
   return 0;
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLTABLES([stem-name, ] [catalog], [owner], [table], [type] )
 *
 * ARGUMENTS:
 *            0 - stem_name (optional)
 *            1 - table catalog (optional)
 *            2 - table owner (optional)
 *            3 - table name (optional)
 *            4 - table type (optional)
 *
 *
 * RETURNS :  0-success, <0-error.
 *
 *----------------------------------------------------------------------------*/
rxfunc( SQLTABLES )
{
   UCHAR tabcat[MAX_IDENTIFIER+1];
   UCHAR *ptabcat=tabcat;
   SWORD tabcatlen=0;
   UCHAR tabown[MAX_IDENTIFIER+1];
   UCHAR *ptabown=tabown;
   SWORD tabownlen=0;
   UCHAR tabnam[MAX_IDENTIFIER+1];
   UCHAR *ptabnam=tabnam;
   SWORD tabnamlen=0;
   UCHAR tabtyp[MAX_IDENTIFIER+1];
   UCHAR *ptabtyp=tabtyp;
   SWORD tabtyplen=0;
   int   rc=0;
   DBCON *db=NULL;
   SDWORD      rowcount=0L;
   int         expr_cnt=0;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
   char        stem_name[MAX_IDENTIFIER+1];
   ULONG       warning=0;
   UWORD   funcsupport=0;
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

   if (argc > 1
   &&  RXSTRLEN(argv[1]))                            /* a catalog name passed */
   {
      RXSTRCPY(tabcat,tabcatlen,RXSTRPTR(argv[1]),(SWORD)RXSTRLEN(argv[1]));
      ptabcat = tabcat;
   }
   else
   {
      ptabcat = NULL;
      tabcatlen = SQL_NTS;
   }

   if (argc > 2
   &&  RXSTRLEN(argv[2]))                            /* an owner name passed */
   {
      RXSTRCPY(tabown,tabownlen,RXSTRPTR(argv[2]),(SWORD)RXSTRLEN(argv[2]));
      ptabown = tabown;
   }
   else
   {
      ptabown = NULL;
      tabownlen = SQL_NTS;
   }

   if (argc > 3
   &&  RXSTRLEN(argv[3]))                            /* a table name passed */
   {
      RXSTRCPY(tabnam,tabnamlen,RXSTRPTR(argv[3]),(SWORD)RXSTRLEN(argv[3]));
      ptabnam = tabnam;
   }
   else
   {
      ptabnam = NULL;
      tabnamlen = SQL_NTS;
   }

   if (argc > 4
   &&  RXSTRLEN(argv[4]))                            /* a table type passed */
   {
      RXSTRCPY(tabtyp,tabtyplen,RXSTRPTR(argv[4]),(SWORD)RXSTRLEN(argv[4]));
      ptabtyp = tabtyp;
   }
   else
   {
      ptabtyp = NULL;
      tabtyplen = SQL_NTS;
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: catalog: %s owner: %s table: %s type: %s\n", __FILE__,__LINE__,ptabcat, ptabown, ptabnam, ptabtyp);)

   /*
    * Get pointer to current connection
    */
   if (RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );
   if (RXSTRLEN(argv[0]) == 0) /* No stem name specified! */
      (void)strcpy(stem_name, DEFAULT_STEM);
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );
   }
   /*
    * Remove trailing '.' if stem_name has one
    */
   if ( stem_name[strlen(stem_name)-1] == '.' )
   {
      stem_name[strlen(stem_name)-1] = '\0';
   }
   /*
    * Check if driver supports this function
    */
   if (SQLGetFunctions(db->hdbc, SQL_API_SQLTABLES, &funcsupport) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      FreeObject( RxPackageGlobalData, db );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
   }
   if ( !funcsupport )
   {
      return SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 100, "Database driver does not support this function"  );
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: stem: %s\n", __FILE__,__LINE__, stem_name);)

   /*
    * If no default statement then create it!
    */
   if ((stmt = (STMT*)(db->dflt_stmt)) == (STMT*)NULL)
   {
      /*
       * Open a statement for the default statement.
       */
      if ( ( rc = OpenStatement( RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      db->dflt_stmt = (void*)stmt;
   }
   swa = SWA(stmt);


   /*
    * Execute the statement
    * Check for any truncation errors
    */
   rc = SQLTables( stmt->hstmt, ptabcat, tabcatlen, ptabown, tabownlen, ptabnam, tabnamlen, ptabtyp, tabtyplen );
   if (rc == SQL_ERROR)
   {
      SetDBError( RxPackageGlobalData,  __FILE__, __LINE__, SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa  );
#if 0
      if (sqlcode == RXSQL_TRUNCATION_SQLCODE
      &&  !RexxSQLData->IgnoreTruncate)
#else
      if (RexxSQLData->IgnoreTruncate
      &&  strcmp(RexxSQLData->SQLCA_SqlState,"22001") == 0)
         warning = DB_WARNING;
      else
#endif
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
      }
   }
   if (rc == SQL_SUCCESS_WITH_INFO)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
      warning = DB_WARNING;
   }

   /*
    * Describe the expression list & define output buffers (if any).
    */
   if ( ( expr_cnt = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt );


   /* Fetch each row in turn */
   for (rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= (SDWORD)RexxSQLData->RowLimit; rowcount++)
   {
      if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount, SPECIAL_SQLTABLES ) ) )
         break;
   }
   rowcount--;
   if (rc && rc != SQL_NO_DATA_FOUND)
   {
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   }
   if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount, SPECIAL_SQLTABLES ) ) )
   {
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   }
   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
   SetRowCount( RxPackageGlobalData, rowcount );
   /*
    * Release the statement and associated storage.
    */
   if ( ( rc = ReleaseStatement( RxPackageGlobalData, stmt ) ) )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   db->dflt_stmt = (STMT*)NULL;
   return RxReturnNumber( RxPackageGlobalData, retstr, warning );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLCOLUMNS([stem-name, ] [catalog], [owner], [table], [type] )
 *
 * ARGUMENTS:
 *            0 - stem-name (optional)
 *            1 - table catalog (optional)
 *            2 - table owner (optional)
 *            3 - table name (optional)
 *            4 - table type (optional)
 *
 *
 * RETURNS :  0-success, <0-error.
 *
 *----------------------------------------------------------------------------*/
rxfunc( SQLCOLUMNS )
{
   UCHAR tabcat[MAX_IDENTIFIER+1];
   UCHAR *ptabcat=tabcat;
   SWORD tabcatlen=0;
   UCHAR tabown[MAX_IDENTIFIER+1];
   UCHAR *ptabown=tabown;
   SWORD tabownlen=0;
   UCHAR tabnam[MAX_IDENTIFIER+1];
   UCHAR *ptabnam=tabnam;
   SWORD tabnamlen=0;
   UCHAR tabtyp[MAX_IDENTIFIER+1];
   UCHAR *ptabtyp=tabtyp;
   SWORD tabtyplen=0;
   int   rc=0;
   DBCON *db=NULL;
   SDWORD      rowcount=0L;
   int         expr_cnt=0;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
   char        stem_name[MAX_IDENTIFIER+1];
   ULONG       warning=0;
   UWORD   funcsupport=0;
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

   if (argc > 1
   &&  RXSTRLEN(argv[1]))                            /* a catalog name passed */
   {
      RXSTRCPY(tabcat,tabcatlen,RXSTRPTR(argv[1]),(SWORD)RXSTRLEN(argv[1]));
      ptabcat = tabcat;
   }
   else
   {
      ptabcat = NULL;
      tabcatlen = SQL_NTS;
   }

   if (argc > 2
   &&  RXSTRLEN(argv[2]))                            /* an owner name passed */
   {
      RXSTRCPY(tabown,tabownlen,RXSTRPTR(argv[2]),(SWORD)RXSTRLEN(argv[2]));
      ptabown = tabown;
   }
   else
   {
      ptabown = NULL;
      tabownlen = SQL_NTS;
   }

   if (argc > 3
   &&  RXSTRLEN(argv[3]))                            /* a table name passed */
   {
      RXSTRCPY(tabnam,tabnamlen,RXSTRPTR(argv[3]),(SWORD)RXSTRLEN(argv[3]));
      ptabnam = tabnam;
   }
   else
   {
      ptabnam = NULL;
      tabnamlen = SQL_NTS;
   }

   if (argc > 4
   &&  RXSTRLEN(argv[4]))                            /* a table type passed */
   {
      RXSTRCPY(tabtyp,tabtyplen,RXSTRPTR(argv[4]),(SWORD)RXSTRLEN(argv[4]));
      ptabtyp = tabtyp;
   }
   else
   {
      ptabtyp = NULL;
      tabtyplen = SQL_NTS;
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: catalog: %s owner: %s table: %s type: %s\n", __FILE__,__LINE__,ptabcat, ptabown, ptabnam, ptabtyp);)

   /*
    * Get pointer to current connection
    */
   if (RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if (RXSTRLEN(argv[0]) == 0) /* No stem name specified! */
      (void)strcpy(stem_name, DEFAULT_STEM);
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );
   }
   /*
    * Remove trailing '.' if stem_name has one
    */
   if ( stem_name[strlen(stem_name)-1] == '.' )
   {
      stem_name[strlen(stem_name)-1] = '\0';
   }
   /*
    * Check if driver supports this function
    */
   if (SQLGetFunctions(db->hdbc, SQL_API_SQLCOLUMNS, &funcsupport) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      FreeObject( RxPackageGlobalData, db );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
   }
   if ( !funcsupport )
   {
      return SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 100, "Database driver does not support this function"  );
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: stem: %s\n", __FILE__,__LINE__, stem_name);)

   /*
    * If no default statement then create it!
    */
   if ((stmt = (STMT*)(db->dflt_stmt)) == (STMT*)NULL)
   {
      /*
       * Open a statement for the default statement.
       */
      if ( ( rc = OpenStatement( RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      db->dflt_stmt = (void*)stmt;
   }
   swa = SWA(stmt);

   /*
    * Execute the statement
    * Check for any truncation errors
    */
   rc = SQLColumns( stmt->hstmt, ptabcat, tabcatlen, ptabown, tabownlen, ptabnam, tabnamlen, ptabtyp, tabtyplen );
   if (rc == SQL_ERROR)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
#if 0
      if (sqlcode == RXSQL_TRUNCATION_SQLCODE
      &&  !RexxSQLData->IgnoreTruncate)
#else
      if (RexxSQLData->IgnoreTruncate
      &&  strcmp(RexxSQLData->SQLCA_SqlState,"22001") == 0)
         warning = DB_WARNING;
      else
#endif
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
      }
   }
   if (rc == SQL_SUCCESS_WITH_INFO)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
      warning = DB_WARNING;
   }

   /*
    * Describe the expression list & define output buffers (if any).
    */
   if ( ( expr_cnt = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt );


   /* Fetch each row in turn */
   for (rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= (SDWORD)RexxSQLData->RowLimit; rowcount++)
   {
      if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount, SPECIAL_SQLCOLUMNS ) ) )
         break;
   }
   rowcount--;
   if (rc && rc != SQL_NO_DATA_FOUND)
   {
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   }
   if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount, SPECIAL_SQLCOLUMNS ) ) )
   {
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   }
   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
   SetRowCount( RxPackageGlobalData, rowcount );
   /*
    * Release the statement and associated storage.
    */
   if ( ( rc = ReleaseStatement( RxPackageGlobalData, stmt ) ) )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   db->dflt_stmt = (STMT*)NULL;
   return RxReturnNumber( RxPackageGlobalData, retstr, warning );
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
   UCHAR namebuffer[MAX_IDENTIFIER+1];
   SWORD namebufferlen=MAX_IDENTIFIER+1;
   UCHAR descbuffer[255];
   SWORD descbufferlen=255;
   SWORD namelen=0;
   SWORD desclen=0;
   int   rc=0;
   int   rc2=0;
   SQLHENV  LocHenv;
   DBCON *db=NULL;
   char        stem_name[MAX_IDENTIFIER+2];
   SDWORD      rowcount=0L;
   ULONG       warning=0;
   size_t  varlen=0;
   char    varname[MAX_IDENTIFIER+1+10];
   UWORD   funcsupport=0;
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

   /*
    * Get pointer to current connection
    */
   if (RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if (RXSTRLEN(argv[0]) == 0) /* No stem name specified! */
      (void)strcpy(stem_name, DEFAULT_STEM);
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );
   }
   /*
    * Remove trailing '.' if stem_name has one
    */
   if ( stem_name[strlen(stem_name)-1] == '.' )
   {
      stem_name[strlen(stem_name)-1] = '\0';
   }
   /*
    * Check if driver supports this function
    */
   if (SQLGetFunctions(db->hdbc, SQL_API_SQLDATASOURCES, &funcsupport) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT,NULL );
      FreeObject( RxPackageGlobalData, db );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
   }
   if ( !funcsupport )
   {
      return SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 100, "Database driver does not support this function"  );
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: stem: %s\n", __FILE__,__LINE__, stem_name);)

   if (SQLAllocEnv(&LocHenv) == SQL_ERROR)
   {
      if (RexxSQLData->henv == SQL_NULL_HENV)
         SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 8,"unable to allocate environment" );
      else
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,RexxSQLData->henv,SQL_NULL_HDBC,SQL_NULL_HSTMT,NULL );
         SQLFreeEnv(LocHenv);
      }
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   }

   /* Fetch each row in turn */
   for (rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= (SDWORD)RexxSQLData->RowLimit; rowcount++)
   {
      if ( rc = SQLDataSources(LocHenv, SQL_FETCH_NEXT, namebuffer, namebufferlen, &namelen, descbuffer, descbufferlen, &desclen ))
         break;
      DEBUGDUMP(fprintf(stderr,"%s-%d: source: %s %s\n", __FILE__,__LINE__, namebuffer, descbuffer);)
      varlen = sprintf(varname, "%s.DSN_NAME.%lu", stem_name, rowcount);
      rc2 = SetRexxVariable( RxPackageGlobalData, varname, varlen, namebuffer, namelen );
      varlen = sprintf(varname, "%s.DSN_DESCRIPTION.%lu", stem_name, rowcount);
      rc2 = SetRexxVariable( RxPackageGlobalData, varname, varlen, descbuffer, desclen );
   }
   rowcount--;
   if (rc && rc != SQL_NO_DATA_FOUND)
   {
      DEBUGDUMP(fprintf(stderr,"%s-%d: loop rc: %d\n", __FILE__,__LINE__, rc);)
      SQLFreeEnv(LocHenv);
      return RxReturnNumber( RxPackageGlobalData,retstr, (long)rc);
   }

   DEBUGDUMP(fprintf(stderr,"%s-%d: rowcount: %d\n", __FILE__,__LINE__, rowcount);)
   /*
    * Set the rowcount SQLCA member and the 0 element of the stems
    */
   SetRowCount( RxPackageGlobalData, rowcount );
   namelen = sprintf(namebuffer, "%lu", rowcount);
   varlen = sprintf(varname, "%s.DSN_NAME.0", stem_name);
   rc2 = SetRexxVariable( RxPackageGlobalData, varname, varlen, namebuffer, namelen );
   varlen = sprintf(varname, "%s.DSN_DESCRIPTION.0", stem_name);
   rc2 = SetRexxVariable( RxPackageGlobalData, varname, varlen, namebuffer, namelen );
   /*
    * Release the statement and associated storage.
    */
   SQLFreeEnv(LocHenv);
   return RxReturnNumber( RxPackageGlobalData, retstr, warning );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS: SQLCOMMAND(stem-name, sql-statement-text [, <bind-args>])
 *
 * RETURNS :  0-success < 0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLCOMMAND )
{
   int         rc = 0, i=0;
   SDWORD      rowcount=0L;
   int         expr_cnt=0;
   DBCON       *db=NULL;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
   char        stem_name[MAX_IDENTIFIER+2];
   ULONG       warning=0;
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

   /*
    * Get pointer to current connection
    */
   if (RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if (argc == 1 || RXSTRLEN(argv[0]) == 0) /* No stem name specified! */
      (void)strcpy(stem_name, DEFAULT_STEM);
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stem_name, sizeof(stem_name) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );
   }

   /*
    * If no default statement then create it!
    */
   if ((stmt = (STMT*)(db->dflt_stmt)) == (STMT*)NULL)
   {
      /*
       * Open a statement for the default statement.
       */
      if ( ( rc = OpenStatement( RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );

      db->dflt_stmt = (void*)stmt;
   }

   swa = SWA(stmt);

   /*
    * If only 1 arg then it is the SQL-statement-text. If more than 1 args
    * then arg#1 is stem-name, arg#2 is text and rest are bind values.
    * 'i' is index (base zero) to sql-statement-text arg.
    */
   i = (argc == 1) ? 0 : 1;

   /*
    * set flag indicating if SELECT statement supplied
    */
   swa->select = SelectStatement( RxPackageGlobalData, RXSTRPTR(argv[i]), RXSTRLEN(argv[i]) );

   /*
    * Save the SQL statement if required
    */
   if ( RexxSQLData->SaveSQL && SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), RXSTRPTR(argv[i]), (int)RXSTRLEN(argv[i]) ) )
      return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

   /*
    * Prepare the statement
    */
#if !defined(USE_EXECDIRECT)
   if (SQLPrepare(stmt->hstmt,(UCHAR*)RXSTRPTR(argv[i]), (SDWORD)RXSTRLEN(argv[i])) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
   }
#endif

   /*
    * Describe the expression list & define output buffers (if any).
    */
   if ( ( expr_cnt = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt );

   /*
    * Bind variables in WHERE/INSERT/UPDATE clause (if any).
    */
   if (argc > 2)
   {
      if ( ( rc = BindValues( RxPackageGlobalData, stmt, argc-2, &argv[2] ) ) != 0 )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      }
   }

   /*
    * Execute the statement
    * Check for any truncation errors
    */
   rc = SQLExecute(stmt->hstmt);
   if (rc == SQL_ERROR)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
#if 0
      if (sqlcode == RXSQL_TRUNCATION_SQLCODE
      &&  !RexxSQLData->IgnoreTruncate)
#else
      if ( RexxSQLData->IgnoreTruncate
      &&  strcmp( RexxSQLData->SQLCA_SqlState, "22001") == 0 )
         warning = DB_WARNING;
      else
#endif
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
      }
   }
   if (rc == SQL_SUCCESS_WITH_INFO)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
      warning = DB_WARNING;
   }

   /*
    * Test if select statement. If not then done else fetch rows.
    */
   if ( expr_cnt == 0 )
   {
      if ( SQLRowCount( stmt->hstmt, &rowcount ) != SQL_SUCCESS )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
         return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
      }
      if ( RexxSQLData->AutoCommit ) /* commit the statement */
      {
         if (SQLTransact(RexxSQLData->henv, db->hdbc,SQL_COMMIT) == SQL_ERROR)
         {
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
            SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
            return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
         }
      }
   }
   else /* ...then must be a SELECT statement */
   {
      /* Fetch each row in turn */
      for (rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= (SDWORD)RexxSQLData->RowLimit; rowcount++)
      {
         if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount, SPECIAL_NORMAL ) ) != 0 )
            break;
      }
      rowcount--;
      if (rc && rc != SQL_NO_DATA_FOUND)
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      }

      if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount, SPECIAL_NORMAL ) ) != 0 )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      }
   }

   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );

   SetRowCount( RxPackageGlobalData, rowcount );

   /*
    * Release the statement and associated storage.
    */
   if ( ( rc = ReleaseStatement( RxPackageGlobalData, stmt ) ) != 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
   db->dflt_stmt = (STMT*)NULL;

   return RxReturnNumber( RxPackageGlobalData, retstr, warning );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLPREPARE(statement-name, sql-statement-text [,NOFETCH] )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLPREPARE )
{
   int         rc=0;
   DBCON       *db=NULL;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
   char        stmt_name[MAX_DB_CURSOR_NAME+1];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 2, 3 ) )
      return 1;

   /*
    * Get pointer to current connection
    */
   if (RexxSQLData->DbEnv && RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if (RXSTRLEN(argv[0]) == 0)          /* No statement name specified! */
      return ReturnError( RxPackageGlobalData, retstr, 23, "statement name omitted or null" );
   else
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], stmt_name, sizeof(stmt_name) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc );
   }

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
         if ( ( rc = ReleaseStatement( RxPackageGlobalData, stmt ) ) != 0 )
            return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
      }

      /*
       * Open a statement for this statement.
       */
      if ( ( rc = OpenStatement( RxPackageGlobalData, stmt_name, db, &stmt)) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );

      /*
       * Insert this statement into the connection hash table.
       */
      (void)InsertObject( RxPackageGlobalData, stmt, RexxSQLData->DbEnv->stmt_tbl, TBL_STATEMENTS );

      db->num_statements++;
   }

   if (argc == 3)
      stmt->bind = 0;

   swa = SWA(stmt);
   /*
    * set flag indicating if SELECT statement supplied
    */
   swa->select = SelectStatement( RxPackageGlobalData, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );

   /*
    * Save the SQL statement if required
    */
   if ( RexxSQLData->SaveSQL && SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), RXSTRPTR(argv[1]), (int)RXSTRLEN(argv[1]) ) )
       return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

   swa->bind_cnt = 0;
   swa->expr_cnt = 0;

   /*
    * Prepare the statement
    */
   if (SQLPrepare(stmt->hstmt,(UCHAR*)RXSTRPTR(argv[1]), (SDWORD)RXSTRLEN(argv[1])) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
      rc = DB_ERROR;
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, rc ? DB_ERROR : 0 );
}

/*-----------------------------------------------------------------------------
 * Get a pointer to the nominated statement. Returns NULL on error.
 *----------------------------------------------------------------------------*/
static STMT *GetStatement ( RxPackageGlobalDataDef *RxPackageGlobalData, RXSTRING var, PSZ buf )
{
   STMT        *stmt=NULL;
   char        tmp[128];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "GetStatement", "%x,%d", var, buf );

   if (RexxSQLData->DbEnv == (DBENV*)NULL)
   {
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 22, "no connections open."  );
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
      SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 24, tmp  );
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
   char        stmt_name[MAX_DB_CURSOR_NAME+1];
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

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name) ) == (STMT*)NULL )
       return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   /*
    * Get pointer to statement's connection structure
    */
   db = stmt->db;

   /*
    * Dispose the statement
    */
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
   int         rc=0,warning=0;
   int         expr_cnt=0;
   SDWORD      rowcount=0L;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
   char        stmt_name[MAX_DB_CURSOR_NAME+1];
   char        tmp[256];
   char        *tmp_buf;
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

   if (argc == 0) return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   swa = SWA(stmt);

   /*
    * Make sure we have a current connection
    */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
       return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

   if (RexxSQLData->DbEnv->current_connection)
      db = RexxSQLData->DbEnv->current_connection;
   else
      return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   /*
    * Rest of args (if any) are bind values. Therefore bind the substitution
    * variables in WHERE/INSERT/UPDATE clause (if any).
    */
   argc--;

   if (argc)
   {
      if ( ( rc = BindValues( RxPackageGlobalData, stmt, argc, &argv[1] ) ) != 0 )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
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
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt );
      }

      /*
       * Since this is a call to SQLOPEN() the statement must be a query!
       */
      if (expr_cnt == 0)
      {
         if (!SEL(swa))
         {
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
            (void)sprintf(tmp,"statement \"%s\" is not a query.", stmt_name);
            return ReturnError( RxPackageGlobalData, retstr, 13, tmp );
         }
         else
         {
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
            SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
            return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
         }
      }
   }

   /*
    * Execute the SQL statement. This is required for Queries, DDL & DML!
    */
   rc = SQLExecute(stmt->hstmt);
   if (rc == SQL_ERROR)
   {
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
   }
   if (rc == SQL_SUCCESS_WITH_INFO)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
      warning = DB_WARNING;
   }
   else if ( rc == SQL_NEED_DATA )
   {
      char *fn;
      FILE *fp;
      long num;

      while( SQLParamData( stmt->hstmt, (PTR)&fn ) == SQL_NEED_DATA )
      {
         DEBUGDUMP(fprintf(stderr,"%s-%d: filename found: <%s>\n", __FILE__, __LINE__, fn );)
         if ( ( fp = fopen( fn, "rb") ) == NULL )
         {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
            sprintf(tmp,"<open> on file <%s> failed: %s.",fn,strerror(errno));
#else
            sprintf(tmp,"<open> on file <%s> failed.",fn );
#endif
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
         }
         tmp_buf = (char *)MALLOC_TSD( RxPackageGlobalData,  RexxSQLData->LongLimit * sizeof(char) );
         if ( tmp_buf == NULL )
         {
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10,"out of memory") );
         }
         for ( ; ; )
         {
            num = fread( tmp_buf, sizeof(char), RexxSQLData->LongLimit, fp );
            DEBUGDUMP(fprintf(stderr,"%s-%d: read %d bytes from: <%s>\n", __FILE__, __LINE__, num, fn );)
            if ( num != RexxSQLData->LongLimit )
            {
               if ( !feof ( fp ) )
               {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
                  sprintf(tmp,"<read> on file <%s> failed: %s.", fn ,strerror(errno));
#else
                  sprintf(tmp,"<read> on file <%s> failed.",fn );
#endif
                  fclose( fp );
                  FREE_TSD( RxPackageGlobalData,  tmp_buf  );
                  return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
               }
            }
            if ( SQLPutData( stmt->hstmt, tmp_buf, num ) == SQL_ERROR )
            {
               FREE_TSD( RxPackageGlobalData,  tmp_buf  );
               SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
               return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
            }
            if ( feof( fp ) )
               break;
         }
         FREE_TSD( RxPackageGlobalData,  tmp_buf  );

         if ( fclose( fp ) )
         {
#if defined(HAVE_ERRNO_H) && defined(HAVE_STRERROR)
            sprintf(tmp,"<close> on file <%s> failed: %s.", fn, strerror(errno));
#else
            sprintf(tmp,"<close> on file <%s> failed.", fn );
#endif
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 86, tmp) );
         }
         DEBUGDUMP(fprintf(stderr,"%s-%d: filename closed: <%s>\n", __FILE__, __LINE__, fn );)
      }
   }

   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc,stmt->Argv );

   /*
    * Return the ROWCOUNT.  For a query it will be zero at this stage.  For
    * a DML statement it will be the number of rows affected by the INSERT/
    * UPDATE/DELETE statement.
    */
   if (open)
      SetRowCount( RxPackageGlobalData, rowcount );
   else
   {
      if (SQLRowCount(stmt->hstmt,&rowcount) != SQL_SUCCESS)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
         warning = DB_WARNING;
      }
      SetRowCount( RxPackageGlobalData, rowcount );
      if ( RexxSQLData->AutoCommit ) /* commit the statement */
      {
         if (SQLTransact(RexxSQLData->henv, db->hdbc,SQL_COMMIT) == SQL_ERROR)
         {
            SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
            return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
         }
      }
   }
   return RxReturnNumber( RxPackageGlobalData, retstr, (long)warning );
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
   char        stmt_name[MAX_DB_CURSOR_NAME+1];
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

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name) ) == (STMT*)NULL )
       return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   swa = SWA(stmt);

   /*
    * Inform database that operation is complete. This should never fail!
    */
   if (SQLFreeStmt(stmt->hstmt, SQL_CLOSE) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
      rc = DB_ERROR;
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
   long        rc=0;
   int         single_fetch=0;
   ULONG       num_rows=0L;
   ULONG       rowcount=0L;
   STMT        *stmt=NULL;
   SQLWA       *swa=NULL;
   char        stem_name[MAX_DB_CURSOR_NAME+2];
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

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stem_name) ) == (STMT*)NULL )
       return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   swa = SWA(stmt);

   /*
    * Determine # of rows to fetch
    */
   if (argc > 1 && RXSTRLEN(argv[1]))
   {
      if ( RxStrToULong( RxPackageGlobalData, &argv[1], &num_rows ) )
         return ReturnError( RxPackageGlobalData, retstr, 14, "<num-rows> is not a valid integer." );
      single_fetch = FALSE;
   }
   else
      single_fetch = TRUE;

   if (single_fetch)
   {
      /* Fetch a single row */
      if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, 0L, SPECIAL_NORMAL ) ) != 0 )
         rc = (rc == SQL_NO_DATA_FOUND) ? 0 : rc;
      else
         rc = 1; /* single row fetch, must return 1 */
   }
   else
   {
     /* Fetch each row in turn */
      for (rowcount = 1; num_rows == 0 || rowcount <= num_rows; rowcount++)
      {
         if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount, SPECIAL_NORMAL ) ) != 0 )
            break;
      }
      rowcount--;

      if (rc
      &&  rc != SQL_NO_DATA_FOUND)
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );

      if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount, SPECIAL_NORMAL ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );

      rc = rowcount;
   }

   SetRowCount( RxPackageGlobalData, rc );
   return RxReturnNumber( RxPackageGlobalData, retstr, rc );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLGETDATA(statement-name, column-name|column_number [, start-byte, length [, file-name]])
 *
 * RETURNS :  0-end-of-data,
 *           >0- bytes obtained - <= length
 *           <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLGETDATA )
{
   FLDDSCR *fd=NULL;
   SDWORD  rc=0,ret_len=0;
   ULONG   num_bytes=0L;
   ULONG   start_byte=0L;
   STMT    *stmt=NULL;
   SQLWA   *swa=NULL;
   char    stmt_name[MAX_IDENTIFIER+1];
   int     long_col=0,i=0;
   size_t  varlen=0;
   char    varname[MAX_IDENTIFIER+1+10];
   FILE    *fp=NULL;
   char    tmp[128];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 2, 5 ) )
      return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   swa = SWA(stmt);

   /*
    * Check that the driver supports the SQLGetData extensions
    */
#if 0
   if ( SupportsSqlGetData == 0 )
   {
      sprintf( tmp, "Database does not support SQLGETDATA." );
      return ReturnError( RxPackageGlobalData, retstr, 85,tmp );
   }
#endif

   /*
    * Get the column number.
    */
   if ( RXSTRLEN( argv[1] ) )
   {
      if ( RxStrToULong( RxPackageGlobalData, &argv[1], (ULONG *)&long_col ) == 0 )
      {
         if ( long_col < 1
         ||   long_col > swa->expr_cnt )
         {
            sprintf(tmp,"Column number <%d> must be between 1 and %d.", long_col, swa->expr_cnt );
            return ReturnError( RxPackageGlobalData, retstr, 85,tmp );
         }
         fd = swa->fa[long_col-1];
      }
      else
      {
         for (i=0;i<swa->expr_cnt;i++)
         {
            fd = swa->fa[i];
            if ( memcmpi( RxPackageGlobalData, RXSTRPTR(argv[1]), fd->cbuf, RXSTRLEN(argv[1]) ) == 0 )
            {
               /*
                * Found matching column name.
                */
               long_col = i+1;
               break;
            }
         }
         if (long_col == 0)
         {
            sprintf(tmp,"Column <%s> not present in statement.",fd->cbuf);
            return ReturnError( RxPackageGlobalData, retstr, 85,tmp );
         }
      }
   }
   else
   {
      return ReturnError( RxPackageGlobalData, retstr, 84,"<column-name> parameter MUST be supplied." );
   }

   if ( argc == 2 )
   {
      rc = SQLGetData(stmt->hstmt,(UWORD)long_col,(SWORD)SQL_C_CHAR, (PTR)fd->rbuf, (SDWORD)((fd->rbufl)+1), (SDWORD*)&(fd->retl));
      if (rc != SQL_SUCCESS)
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt,swa );
         return (DB_ERROR);
      }
      (void)sprintf(varname, "%s.%s", stmt_name, fd->cbuf);
      varlen = strlen(varname);
      if ( ret_len == SQL_NULL_DATA )     /* returned value is NULL */
      {
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, RexxSQLData->RXSNullStringOut.strptr, RexxSQLData->RXSNullStringOut.strlength );
      }
      else
      {
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, (char*)fd->rbuf, fd->retl );
      }
      return RxReturnNumber( RxPackageGlobalData, retstr, ret_len );
   }

   /*
    * Determine starting byte
    */
   if (RXSTRLEN(argv[2]))
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
   if (RXSTRLEN(argv[3]))
   {
      if ( RxStrToULong( RxPackageGlobalData, &argv[3], &num_bytes ) )
      {
         return ReturnError( RxPackageGlobalData, retstr, 14,"<number-bytes> is not a valid integer." );
      }
      if ( num_bytes > RexxSQLData->LongLimit )
      {
         return ReturnError( RxPackageGlobalData, retstr, 14,"<number-bytes> must be <= LONGLIMIT." );
      }
   }
   else
      num_bytes = 0L;

   /*
    * Check for filename if start and length = 0
    */
   if (start_byte == 0L
   &&  num_bytes == 0L
   &&  RXSTRLEN(argv[4])==0)
   {
      return ReturnError( RxPackageGlobalData, retstr, 84,"<file-name> parameter MUST be supplied." );
   }

   if (start_byte == 0L
   &&  num_bytes == 0L)
   {
      /*
       * Process a file
       */
      char *buf=NULL;

      if ((fp = fopen(RXSTRPTR(argv[4]),"wb")) == NULL)
      {
         sprintf(tmp,"<open> on file <%s> failed: %s.",RXSTRPTR(argv[4]),strerror(errno));
         return ReturnError( RxPackageGlobalData, retstr, 86,tmp );
      }
      if ( ( buf = (char *)MALLOC_TSD( RxPackageGlobalData,  RexxSQLData->LongLimit + 1 ) ) == (char *)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );
      for (i=0;;i++)
      {
         ret_len = SQL_NO_TOTAL;
         rc = SQLGetData( stmt->hstmt, long_col, SQL_C_BINARY, buf, RexxSQLData->LongLimit, &ret_len);
         if ( rc == SQL_ERROR )
         {
            if (buf) FREE_TSD( RxPackageGlobalData, buf );
            SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
            return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
         }
         DEBUGDUMP(fprintf(stderr,"%s-%d: Constants: SQL_SUCCESS_WITH_INFO %ld, SQL_NO_DATA_FOUND %ld, SQL_NULL_DATA %ld, SQL_NO_TOTAL %ld\n", __FILE__, __LINE__, SQL_SUCCESS_WITH_INFO, SQL_NO_DATA_FOUND, SQL_NULL_DATA, SQL_NO_TOTAL ); )
         DEBUGDUMP(fprintf(stderr,"%s-%d: rc from SQLGetData %ld, Return length: %ld Requested: %ld\n", __FILE__, __LINE__, rc, ret_len, RexxSQLData->LongLimit ); )
         if ( rc == SQL_NO_DATA_FOUND )
         {
            ret_len = 0;
            break;
         }
         if ( ret_len == SQL_NO_TOTAL )
            ret_len = num_bytes;
         else if ( (ULONG)ret_len > (ULONG)RexxSQLData->LongLimit )
            ret_len = RexxSQLData->LongLimit;
         if ( ret_len == SQL_NULL_DATA )     /* returned value is NULL */
         {
            if ( (long)fwrite( (void*)RexxSQLData->RXSNullStringOut.strptr, sizeof(char), RexxSQLData->RXSNullStringOut.strlength, fp ) != ret_len )
            {
               if (buf) FREE_TSD( RxPackageGlobalData, buf );
               sprintf(tmp,"<write> on file <%s> failed: %s.",RXSTRPTR(argv[4]),strerror(errno));
               return ReturnError( RxPackageGlobalData, retstr, 86, tmp );
            }
            break;
         }
         else
         {
            if ((long)fwrite((void*)buf,sizeof(char),ret_len,fp) != ret_len)
            {
               if (buf) FREE_TSD( RxPackageGlobalData, buf );
               sprintf(tmp,"<write> on file <%s> failed: %s.",RXSTRPTR(argv[4]),strerror(errno));
               return ReturnError( RxPackageGlobalData, retstr, 86, tmp );
            }
         }
      }
      if (buf) FREE_TSD( RxPackageGlobalData, buf );
      if (fclose(fp))
      {
         sprintf(tmp,"<close> on file <%s> failed: %s.",RXSTRPTR(argv[4]),strerror(errno));
         return ReturnError( RxPackageGlobalData, retstr, 86, tmp );
      }
   }
   else
   {
      /*
       * Get the chunk of data specified
       * Size of the chunk MUST be < 64K
       */
      if (num_bytes >= 0x10000)
         return ReturnError( RxPackageGlobalData, retstr, 87,"<number-bytes> parameter must be < <65536>." );
      /*
       * In an attempt to save malloc() & free() calls we keep the old
       * buffer providing it is not grossly oversized.
       */
      if ((size_t)fd->rbufl < num_bytes
      || (size_t)fd->rbufl > num_bytes + 256)
      {
         /* Free the old buffer (if any) */
         if (fd->rbufl)
         {
            FREE_TSD( RxPackageGlobalData, fd->rbuf );
            fd->rbufl = 0;
            fd->rbuf = NULL;
         }
         /* Allocate a new buffer */
         if ( ( fd->rbuf = (UCHAR *)MALLOC_TSD( RxPackageGlobalData, num_bytes ) ) == (UCHAR *)NULL )
            return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );
      }
      DEBUGDUMP(fprintf(stderr,"%s-%d: Col Number: %d Num bytes: %d\n", __FILE__, __LINE__, long_col, num_bytes ); )
      rc = SQLGetData( stmt->hstmt, long_col, SQL_C_BINARY, fd->rbuf, num_bytes, &ret_len);
      if ( rc == SQL_ERROR )
      {
         SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, SQL_NULL_HDBC, stmt->hstmt, swa );
         return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR );
      }
      DEBUGDUMP(fprintf(stderr,"%s-%d: Constants: SQL_SUCCESS_WITH_INFO %ld, SQL_NO_DATA_FOUND %ld, SQL_NULL_DATA %ld, SQL_NO_TOTAL %ld\n", __FILE__, __LINE__, SQL_SUCCESS_WITH_INFO, SQL_NO_DATA_FOUND, SQL_NULL_DATA, SQL_NO_TOTAL ); )
      DEBUGDUMP(fprintf(stderr,"%s-%d: Available Data Length: %ld Requested: %ld\n", __FILE__,__LINE__,ret_len, num_bytes ); )
      if ( rc == SQL_NO_DATA_FOUND )
         ret_len = 0;
      else if ( ret_len == SQL_NO_TOTAL )
         ret_len = num_bytes;
      else if ( (ULONG)ret_len > (ULONG)num_bytes )
         ret_len = num_bytes;
      varlen = sprintf(varname, "%s.%s", stmt_name, fd->cbuf);
      DEBUGDUMP(fprintf(stderr,"%s-%d: After changes: Available Data Length: %ld Requested: %ld\n", __FILE__,__LINE__,ret_len, num_bytes ); )
      if ( ret_len == SQL_NULL_DATA )     /* returned value is NULL */
      {
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, RexxSQLData->RXSNullStringOut.strptr, RexxSQLData->RXSNullStringOut.strlength );
      }
      else
      {
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, (char*)fd->rbuf, ret_len );
      }
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, ret_len );

}

/*-----------------------------------------------------------------------------
 * Fetch the description for the column expression. Used by SQLDESCRIBE().
 *----------------------------------------------------------------------------*/
static int GetColumn( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt, int i, char *stem_name )
{
   FLDDSCR *fd=NULL;
   SQLWA   *swa=NULL;
   int     idx=0, rc=0;
   char    column_size[15], column_prec[15], column_scale[15], column_nullok[15];
#if OLD
   char    *column_type=NULL;
#else
   UCHAR   column_type[MAX_IDENTIFIER+1];
   SWORD   collen_not_used=0;
#endif
   char    name[MAX_IDENTIFIER+32];
   char    *value[NUM_DESCRIBE_COLUMNS];
   int     value_len[NUM_DESCRIBE_COLUMNS];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "GetColumn", "%x,%d,%s", stmt, i, stem_name );

   swa = SWA(stmt);

   if (i >= swa->expr_cnt)
       return 1;

   fd = swa->fa[i];

   /* get the column type of the column */
/* if varlen == -2 TODO SQLServer Image column type*/
   if ( SQLColAttributes( stmt->hstmt, i+1, SQL_COLUMN_TYPE_NAME, column_type, sizeof(column_type), &collen_not_used, NULL ) != SQL_SUCCESS )
      strcpy(column_type,"UNKNOWN");

   /* Set up the array */
   value[0] = fd->cbuf;
   value_len[0] = fd->cbufl;
   value[1] = column_type;
   value_len[1] = strlen(column_type);
   value[2] = column_size;
   value_len[2] = sprintf(column_size, "%ld", fd->rbufl);
   value[3] = column_prec;
   value_len[3] = sprintf(column_prec, "%ld", fd->prec);
   value[4] = column_scale;
   value_len[4] = sprintf(column_scale, "%d", fd->scale);
   value[5] = column_nullok;
   value_len[5] = sprintf(column_nullok, "%d", fd->nullok);

   /* Output into Rexx variable */
   i++;
   for (idx = 0; idx < NUM_DESCRIBE_COLUMNS; idx++)
   {
      sprintf( name, "%s.COLUMN.%s.%d", stem_name, RexxSQLData->column_attribute[idx], i );
      if ( SetRexxVariable( RxPackageGlobalData, name, strlen(name), value[idx], value_len[idx] ) )
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
   SQLWA       *swa=NULL;
   char        **p=NULL, buf1[MAX_IDENTIFIER+32], buf2[16];
   char        stmt_name[MAX_DB_CURSOR_NAME+1];
   char        stem_name[MAX_IDENTIFIER+2];
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

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name) ) == (STMT*)NULL )
       return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode );

   swa = SWA(stmt);

   /* Get the name of the stem into which to put output */
   if (argc < 2 || RXSTRLEN(argv[1]) == 0) /* No stem name specified! */
      (void)strcpy(stem_name, stmt_name);
   else if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[1], stem_name, sizeof(stem_name) ) ) != 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );

   /* Describe the expression list & define output buffers (if any). */
   if ( ( rc = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );

   /* Describe the parsed statement into REXX variables */
   for (rc = 0, i = 0; rc == 0; i++)
   {
      rc = GetColumn( RxPackageGlobalData, stmt, i, stem_name );
   }

   if (rc >= 0)
   {
      len2 = sprintf(buf2,"%d", --i);
      for (p = RexxSQLData->column_attribute; *p && rc >= 0; p++)
      {
         len1 = sprintf(buf1, "%s.COLUMN.%s.0", stem_name, *p);
         if ( SetRexxVariable( RxPackageGlobalData, buf1, len1, buf2, len2 ) )
            rc = -16;
         else
            rc = 0;
      }
      rc = rc < 0 ? rc : i;
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc );
}

int DBInitialise( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   return(0);
}

int DBTerminate( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   return(0);
}

/*-----------------------------------------------------------------------------
 * Set up the DBMSName variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetDBMSName( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   SWORD    outlen=0;
   int      i=0,rc;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;


   InternalTrace( RxPackageGlobalData, "SetDBMSName", "%x", db );

   rc = SQLGetInfo( db->hdbc, SQL_DBMS_NAME, RexxSQLData->DBMSName, 255 /*sizeof(DBMSName)*/, &outlen );
   if ( rc == -1 )
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT, NULL );
      strcpy( RexxSQLData->DBMSName, "** database cannot provide **" );
   }
   for (i=0;i<(int)strlen(RexxSQLData->DBMSName);i++)
   {
      if (RexxSQLData->DBMSName[i] == ' ')
         RexxSQLData->DBMSName[i] = '_';
   }
   MAKERXSTRING( RexxSQLData->RXSDBMSName, RexxSQLData->DBMSName, (ULONG)strlen(RexxSQLData->DBMSName) );
   return( (void*)&RexxSQLData->RXSDBMSName );
}

/*-----------------------------------------------------------------------------
 * Set up the DBMSVer variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetDBMSVer( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   SWORD    outlen=0;
   int      rc=0;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;


   InternalTrace( RxPackageGlobalData, "SetDBMSVer", "%x", db);
   rc = SQLGetInfo( db->hdbc, SQL_DBMS_VER, RexxSQLData->DBMSVer, 255 /*sizeof(DBMSVer)*/, &outlen );
   if ( rc == -1 )
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT, NULL );
      strcpy( RexxSQLData->DBMSVer, "** database cannot provide **" );
   }
   MAKERXSTRING( RexxSQLData->RXSDBMSVer, RexxSQLData->DBMSVer, (ULONG)strlen(RexxSQLData->DBMSVer) );
   return( (void*)&RexxSQLData->RXSDBMSVer );
}

/*-----------------------------------------------------------------------------
 * Set up the Datatypes supported
 *----------------------------------------------------------------------------*/
static void *SQLValSetDatatypes( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   RXSTRING_DT *dt=NULL;
   int          rc = 0, i, j;
   RXSQL_HSTMT  hstmt;
   char         datatype[MAX_IDENTIFIER+1];
   SDWORD       rlen_dt=0;
   SDWORD       rlen_int=0;
   SWORD        internal=0;

   InternalTrace( RxPackageGlobalData, "SetDatatypes", "%x", db);

   dt = (RXSTRING_DT *)MALLOC_TSD( RxPackageGlobalData, sizeof(RXSTRING_DT)*(MAX_DATATYPES+1) );

   if ((rc = SQLAllocStmt(db->hdbc, &hstmt)) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV,db->hdbc,SQL_NULL_HSTMT,NULL );
      return (NULL); /* ?? */
   }

   if ((rc = SQLGetTypeInfo(hstmt, SQL_ALL_TYPES)) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV,db->hdbc,hstmt,NULL );
      return (NULL);
   }

   if ((rc = SQLBindCol(hstmt, 1, SQL_C_CHAR, (RXSQL_SQLPOINTER)datatype, MAX_IDENTIFIER+1, &rlen_dt)) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV,db->hdbc,hstmt,NULL );
      return(NULL);
   }

   if ((rc = SQLBindCol(hstmt, 2, SQL_C_DEFAULT, (RXSQL_SQLPOINTER)&internal, sizeof(internal), &rlen_int)) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV,db->hdbc,hstmt,NULL );
      return(NULL);
   }

   i = 0;
   while ((rc = SQLFetch(hstmt)) == SQL_SUCCESS && i < MAX_DATATYPES)
   {
      dt[i].strptr = (char*)MALLOC_TSD( RxPackageGlobalData, rlen_dt + 1 );
      memcpy(dt[i].strptr,datatype,rlen_dt);
      dt[i].strptr[strlen(datatype)] = '\0';
      dt[i].strlength = strlen(datatype);
      dt[i].internal = internal;
      dt[i].binary = 0;
      for ( j = 0; j < MAX_DATATYPES && datatype_conversion[j].ext_datatype; j++ )
      {
         if ( datatype_conversion[j].int_datatype == internal )
         {
            dt[i].binary = datatype_conversion[j].long_datatype;
            break;
         }
      }
      InternalTrace( RxPackageGlobalData, "SetDatatypes:", "%s(%d) Max: %d", dt[i].strptr, dt[i].strlength,MAX_DATATYPES);
      i++;
   }
   dt[i].strptr = NULL;
   dt[i].strlength = 0;
   dt[i].internal = 0;
   dt[i].binary = 0;
   if (SQLFreeStmt(hstmt,SQL_DROP) != SQL_SUCCESS)
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV,db->hdbc,hstmt,NULL );
      return(NULL);
   }
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
   for (i=0;i<NUM_DESCRIBE_COLUMNS;i++)
   {
      dc[i].strptr = (char*)MALLOC_TSD( RxPackageGlobalData,  1 + strlen( RexxSQLData->column_attribute[i] ) );
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
   SWORD    capable=0,outlen=0;
   int      rc=0;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;


   InternalTrace( RxPackageGlobalData, "SetSupportsTransactions", "%x", db);
   rc = SQLGetInfo( db->hdbc, SQL_TXN_CAPABLE, &capable, sizeof(capable), &outlen );
   if ( rc == -1 )
   {
      SetDBError( RxPackageGlobalData, __FILE__,__LINE__,SQL_NULL_HENV, db->hdbc, SQL_NULL_HSTMT, NULL );
   }
   RexxSQLData->SupportsTransactions = (capable)?1L:0L;
   return((void*)&RexxSQLData->SupportsTransactions);
}

/*-----------------------------------------------------------------------------
 * Set up the SupportsSqlGetData variable
 *----------------------------------------------------------------------------*/
static void *SQLValSetSupportsSqlGetData( RxPackageGlobalDataDef *RxPackageGlobalData, DBCON *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetSupportsSQLGetData", "%x", db);
#if 0
   /*
    * Code below is restrictive...
    * Driver must be able to support calling SQLGetData on bound
    * columns and in any order
    */
   if ( db->sqlgetdataext & SQL_GD_BOUND
   &&   db->sqlgetdataext & SQL_GD_ANY_ORDER )
      RexxSQLData->SupportsSqlGetData = 1;
   else
      RexxSQLData->SupportsSqlGetData = 0;
#else
   RexxSQLData->SupportsSqlGetData = SUPPORTSSQLGETDATA;
#endif
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
   RexxSQLData->StandardPlacemarkers = TRUE;
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
