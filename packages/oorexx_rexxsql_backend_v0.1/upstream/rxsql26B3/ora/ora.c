/*
 * ora.c - REXX/SQL for Oracle
 *
 *
 * REXX/SQL. A REXX interface to SQL databases.
 * Copyright (C) Mark Hessling 2006.
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
 * Mark Hessling  mark@rexx.org  http://www.rexx.org/
 */

static char RCSid[] = "$Id: ora.c,v 1.9 2010/09/20 21:43:29 mark Exp $";

#include "rxpack.h"

#define INCL_RXSHV   /* Shared variable support */
#define INCL_RXFUNC  /* External functions support */

#include "dbdefine.h"
/*
 * Set any ignore #defines for unused general code
 */
#define REXXSQL_IGNORE_SELECTSTATEMENT 1
#define REXXSQL_IGNORE_COUNTQUESTIONMARKS 1
#include "rexxsql.h"
#include "dbheader.h"
#include "dbtypes.h"

/*
 * Definition of parameter markers
 */
typedef struct
{
   ub1  *buf;   /* Pointer to buffer containing parameter marker value */
   sb4  valuelen;                      /* actual length of bound value */
   sb4  buflen;                             /* Allocated length of buf */
   OCIBind *bindhp;                             /* bind handle pointer */
} PMDSCR;

typedef struct {
   sb4   rbufl;         /* Size of buffer to hold fetched column value */
   sb4   cbufl;      /* Length of column name - reset to actual length */
   sb2   dbtype;                           /* Internal Oracle datatype */
   sb2   indp;               /* Indicator for field - after each fetch */
                   /* <0 - NULL; 0 - OK; >0 - length BEFORE truncation */
   sb2   prec;                         /* Precision of number datatype */
   sb2   scale;                            /* Scale of number datatype */
   sb2   nullok;                 /* Are nulls permitted? 0=no, <>0=yes */
   char  *rbuf;      /* Pointer to buffer to hold fetched column value */
   char  *cbuf;                          /* Buffer to hold column name */
   int   use_strlen; /* use strlen on this column to obtain actual data length returned */
   int   locator_type;
   /* the following is a union of different locator type columns */
   union
   {
      struct
      {
         OCIDateTime *ts;                       /* A TIMESTAMP locator */
         ub4   ts_dtype;             /* Datatype for TIMESTAMP locator */
      } timestamp;
      struct
      {
         OCILobLocator *lob;                            /* lob locator */
         int   lob_piece;                /* first or next piece of LOB */
         oraub8 loblen;                /* length of LOB if lob != NULL */
      } lob;
   } locator;
} FLDDSCR;

/*
 * Definition of SQL Work Area (SQLWA).  This contains the ORACLE user
 * context area plus additional information required by this interface to
 * control the processing of SQL statements.
 * Note that the oracle CURSOR structure must be physically the first object
 * in this structure!!
 */

typedef struct {
   SAVEDSQLSTMT saved_stmt;       /* structure to hold SQL statement */
   ub2 stmt_type;                               /* type of statement */
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
   char        name[MAX_IDENTIFIER+1];   /* Connection name */
   OCISession *authp;
   OCIServer  *srvhp;
   OCISvcCtx  *svchp;
   void       *dflt_stmt;      /* Pointer to implicit statement */
   int         num_statements;     /* Number of explicit statements */
   SQLVAL     *db_opt;   /* SqlGetInfo linked list */
   int        connected_as_admin; /* did we connect as SYSDBA or SYSOPER */
} DBCON;

/* Statement structure. Each statement requires one of these!
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct
{
   char      name[MAX_IDENTIFIER+1];   /* Statement name */
   OCIStmt   *stmthp; /* OCI handle */
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
   OCIEnv    *envhp;
   OCIError  *errhp;
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

#define RXSQL_LOCATOR_NONE      0
#define RXSQL_LOCATOR_TIMESTAMP 1
#define RXSQL_LOCATOR_LOB       2
/* ---------------------------------------------------------------------
 * These globals are constant and are used for NULL column indicators
 * They CAN be global and their use is thread-safe
 */
static const short  not_null = 0;
static const short  is_null = (-1);

static int ValidateDataType Args(( RxPackageGlobalDataDef *, char *, int, DBCON * ));

/*
 * #define extra database-specific entry points and function declarations just
 * before #include "rxsqlinc1.h"
 */
#define INCLUDE_ORASTARTUP_FUNC
#define INCLUDE_ORASHUTDOWN_FUNC
RexxFunctionHandler RexxORAStartup;
RexxFunctionHandler RexxORAShutdown;
#include "rxsqlinc1.h"

/*-----------------------------------------------------------------------------
 * Fetch the DB error and put into REXX "SQLCA." compound variable.
 *----------------------------------------------------------------------------*/
static void SetDBError( RxPackageGlobalDataDef *RxPackageGlobalData, char *file, int lineno, OCIError *errhp, SQLWA *swa )
{
   sb4     sqlcode = 0;
   char    *txt=NULL;
   char    msg[MAX_ERROR_TEXT] = {0};

   InternalTrace( RxPackageGlobalData, "SetDbError", "%s,%d,%x", file, lineno, swa );

   OCIErrorGet( (dvoid *)errhp, (ub4) 1, (text *) NULL, &sqlcode, msg, (ub4) sizeof(msg), OCI_HTYPE_ERROR);

   /* Remove trailing newline character */
   /*msg[strlen(msg)-1] = '\0';*/

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
   /*
    * Setup Oracle environment
    */
   OCIEnvInit( (OCIEnv **) &dbenv->envhp, OCI_DEFAULT, (size_t) 0, (dvoid **) 0 );

   OCIHandleAlloc( (dvoid *) dbenv->envhp, (dvoid **) &dbenv->errhp, OCI_HTYPE_ERROR,
                   (size_t) 0, (dvoid **) 0);
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
   memset( db, 0, sizeof(DBCON) );
   (void)strncpy(db->name, name, MAX_IDENTIFIER);
   return db;
}

/*-----------------------------------------------------------------------------
 * Open a database connection. This requires allocating a connection object
 * and making the connection to Oracle.
 *----------------------------------------------------------------------------*/
static int OpenConnection( RxPackageGlobalDataDef *RxPackageGlobalData, PSZ dbname, PSZ host, size_t hostlen, PSZ uid, size_t uidlen, PSZ pwd, size_t pwdlen, ub4 mode, DBCON **new_db )
{
   DBCON   *db=NULL;
   int     rc=0,i=0;
   void    *result=NULL;
   SQLVAL  *curr=NULL;
   PSZ     myhost=host;
   ub4     cred;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "OpenConnection", "Name: %s Host: %s(%d) User: %s(%d) Pass: %s(%d) Mode: %d", dbname, host, hostlen, uid, uidlen, pwd, pwdlen, mode );

   if ( ( db = AllocConnection( RxPackageGlobalData, dbname ) ) == (DBCON*)NULL )
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));

   /* server contexts */
   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid **) &db->srvhp, OCI_HTYPE_SERVER,
                   (size_t) 0, (dvoid **) 0 );

   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid **) &db->svchp, OCI_HTYPE_SVCCTX,
                   (size_t) 0, (dvoid **) 0 );

   if ( hostlen == 0 )
   {
      myhost = NULL;
   }
   rc = OCIServerAttach( db->srvhp, RexxSQLData->DbEnv->errhp, (text *)myhost, hostlen, 0 );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }

   /* set attribute server context in the service context */
   OCIAttrSet( (dvoid *) db->svchp, OCI_HTYPE_SVCCTX, (dvoid *)db->srvhp,
               (ub4) 0, OCI_ATTR_SERVER, (OCIError *) RexxSQLData->DbEnv->errhp );

   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid **)&db->authp,
                   (ub4) OCI_HTYPE_SESSION, (size_t) 0, (dvoid **) 0 );

   OCIAttrSet( (dvoid *) db->authp, (ub4) OCI_HTYPE_SESSION,
               (dvoid *) uid, (ub4) uidlen,
               (ub4) OCI_ATTR_USERNAME, RexxSQLData->DbEnv->errhp );

   OCIAttrSet( (dvoid *) db->authp, (ub4) OCI_HTYPE_SESSION,
               (dvoid *) pwd, (ub4) pwdlen,
               (ub4) OCI_ATTR_PASSWORD, RexxSQLData->DbEnv->errhp );
   /*
    */
   if ( uid[0] == '/'
   &&   uidlen == 1
   &&   mode != OCI_DEFAULT )
      cred = OCI_CRED_EXT;
   else
      cred = OCI_CRED_RDBMS;
   /*
    * Do the database-specific connection
    */
   rc = OCISessionBegin ( db->svchp,  RexxSQLData->DbEnv->errhp, db->authp, cred, mode );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      FreeObject( RxPackageGlobalData, db );
      return DB_ERROR;
   }

  OCIAttrSet( (dvoid *) db->svchp, (ub4) OCI_HTYPE_SVCCTX,
              (dvoid *) db->authp, (ub4) 0,
              (ub4) OCI_ATTR_SESSION, RexxSQLData->DbEnv->errhp );

   /*
    * Setup any connection-specific variable information
    */
   for ( i = 0; strlen( sqlgetinfo_vars[i].name ) != 0; i++ )
   {
      if ( sqlgetinfo_vars[i].value )
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
static int AllocStatement( RxPackageGlobalDataDef *RxPackageGlobalData, char *name, DBCON *db, STMT **new_stmt )
{
   STMT    *stmt=NULL;
   SQLWA   *swa=NULL;
   int     i=0;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "AllocateStatement", "%s,%x", name, db );

   if ( ( stmt = (STMT*)NewObject( RxPackageGlobalData, sizeof(STMT) ) ) == (STMT*)NULL )
      return DB_ERROR;
   stmt->db = db;
   (void)strncpy(stmt->name, name, MAX_IDENTIFIER);

   /* Initialise SQL Work Area */
   swa = SWA(stmt);
   swa->bind_cnt = 0;
   swa->expr_cnt = 0;
   memset( &(swa->saved_stmt), 0, sizeof(SAVEDSQLSTMT) );

   stmt->Argc = 0L;
   stmt->Argv = NULL;
   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid **) &stmt->stmthp, OCI_HTYPE_STMT, (size_t) 0, (dvoid **) 0 );

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
    * Return our new statement
    */
   *new_stmt = stmt;
   return 0;
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
    * Free up select column descriptors
    */
   for (i = 0; i < MAX_COLS; i++)
   {
      fd = swa->fa[i];
      if (fd == NULL)
         break;

      switch ( fd->locator_type )
      {
         case RXSQL_LOCATOR_TIMESTAMP:
            OCIDescriptorFree( fd->locator.timestamp.ts, fd->locator.timestamp.ts_dtype );
            break;
         case RXSQL_LOCATOR_LOB:
            if ( fd->dbtype == SQLT_FILE )
               OCIDescriptorFree( fd->locator.lob.lob, OCI_DTYPE_FILE );
            else
               OCIDescriptorFree( fd->locator.lob.lob, OCI_DTYPE_LOB );
         default:
            break;
      }
      if (fd->rbuf)
         FREE_TSD( RxPackageGlobalData, fd->rbuf);
      if (fd->cbuf)
         FREE_TSD( RxPackageGlobalData, fd->cbuf);
      FREE_TSD( RxPackageGlobalData, fd);
      fd = NULL;
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
         FREE_TSD( RxPackageGlobalData, pmd->buf);
      FREE_TSD( RxPackageGlobalData, pmd);
      pmd = NULL;
   }

   /*
    * Free sql statement buffer (if any)
    */
   if (swa->saved_stmt.sql_stmt)
   {
      FREE_TSD( RxPackageGlobalData, swa->saved_stmt.sql_stmt);
      memset( &(swa->saved_stmt), 0, sizeof(SAVEDSQLSTMT) );
   }

   /*
    * Free the input bind values (if any)
    */
   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
   /*
    * Release the handle
    */
   OCIHandleFree( stmt->stmthp, OCI_HTYPE_STMT );
   /*
    * Last; remove the statement object
    */
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
   rc = OCISessionEnd( db->svchp, RexxSQLData->DbEnv->errhp, db->authp, OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      last_error = rc;
   }

   OCIHandleFree( db->authp, OCI_HTYPE_SESSION );
   OCIServerDetach( db->srvhp, RexxSQLData->DbEnv->errhp, OCI_DEFAULT );
   OCIHandleFree( db->svchp, OCI_HTYPE_SVCCTX );
   OCIHandleFree( db->srvhp, OCI_HTYPE_SERVER );

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
   OCIHandleFree( RexxSQLData->DbEnv->errhp, OCI_HTYPE_ERROR );

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
   register int i=0,j=0,k=0;
   char buf[5];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "ConvertPlacemarkers", "%x,%d,%x", stmt, len, new_len );

   for (i=0;i<len;i++)
   {
      if (stmt[i] == '?')
        num_placemarkers++;
   }

   if ((1+len+(num_placemarkers*4)) > RexxSQLData->converted_stmt_len)
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
      if ( ( RexxSQLData->converted_stmt = (char*)MALLOC_TSD(  RxPackageGlobalData, 1+len+(num_placemarkers*4) ) ) == (char*)NULL )
         return(NULL);
      RexxSQLData->converted_stmt_len = 1+len+(num_placemarkers*4);
   }

   for (i=0,j=0;i<len;i++)
   {
      if (stmt[i] == '?')
      {
         RexxSQLData->converted_stmt[j++] = ':';
         sprintf(buf,"%d",placemarker++);
         for (k=0;k<(int)strlen(buf);k++)
            RexxSQLData->converted_stmt[j++] = buf[k];
      }
      else
        RexxSQLData->converted_stmt[j++] = stmt[i];
   }
   RexxSQLData->converted_stmt[j] = '\0';
   *new_len = j;
   return(RexxSQLData->converted_stmt);
}

static int ValidateAuthType( RxPackageGlobalDataDef *RxPackageGlobalData, char *authtype, int len, sb4 *mode )
{
   int rc = 0;
   if ( len == 0 )
      *mode = OCI_DEFAULT;
   else if ( memcmpi( RxPackageGlobalData, authtype, "DEFAULT", 7 ) == 0 )
      *mode = OCI_DEFAULT;
   else if ( memcmpi( RxPackageGlobalData, authtype, "SYSDBA", 6 ) == 0 )
      *mode = OCI_SYSDBA|OCI_PRELIM_AUTH;
   else if ( memcmpi( RxPackageGlobalData, authtype, "SYSOPER", 6 ) == 0 )
      *mode = OCI_SYSOPER|OCI_PRELIM_AUTH;
   else
   {
      *mode = 0;
      rc = 1;
   }
   return rc;
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLCONNECT( connection-name[, username[, password[, auth type[, host]]]])
 *
 * ARGUMENTS:
 *            0 - connection_name (mandatory)
 *            1 - username (optional)
 *            2 - password (optional)
 *            3 - auth type (optional) default is DEFAULT; SYSDBA or SYSOPER
 *            4 - host name (optional)
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLCONNECT )
{
   char   dbname[MAX_IDENTIFIER+1];
   char   uid[256]="/";
   int    uidlen=1;
   char   pwd[256];
   int    pwdlen=0;
   char   host[256]="";
   int    hostlen=0;
   int    rc=0;
   sb4    mode=OCI_DEFAULT;
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

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 5 ) )
      return 1;

   /* Allocate a DB environment if none exists! */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
   {
      if ( ( RexxSQLData->DbEnv = AllocDbEnvironment( RxPackageGlobalData ) ) == (DBENV*)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory." );
   }
   /*
    * Work out connection string of format:
    * username/password@host[:port][/service name]
    * The portion after the @ is supplied in the host argument
    */
#if 0
   switch( argc )
   {
      case 1:
         RXSTRCPY( uid, uidlen, "/", 1 );
         RXSTRCPY( pwd, pwdlen,"", 0 );
         RXSTRCPY( host, hostlen,"", 0 );
         break;
      case 2:
         if ( RXSTRLEN(argv[1]) == 0 && RXSTRLEN(argv[2]) == 0 )
         {
            RXSTRCPY( uid, uidlen, "/", 1 );
         }
         else
         {
            RXSTRCPY( uid, uidlen, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );
            RXSTRCPY( pwd, pwdlen, "", 0 );
         }
         RXSTRCPY( host, hostlen,"", 0 );
         break;
      case 3:
         if ( RXSTRLEN(argv[1]) == 0 && RXSTRLEN(argv[2]) == 0 )
         {
            RXSTRCPY( uid, uidlen, "/", 1 );
         }
         else
         {
            RXSTRCPY( uid, uidlen, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );
            RXSTRCPY( pwd, pwdlen, RXSTRPTR(argv[2]), RXSTRLEN(argv[2]) );
         }
         RXSTRCPY( host, hostlen,"", 0 );
         break;
      case 4:
         if ( RXSTRLEN(argv[1]) == 0 && RXSTRLEN(argv[2]) == 0 )
         {
            RXSTRCPY( uid, uidlen, "/", 1 );
         }
         else
         {
            RXSTRCPY( uid, uidlen, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );
            RXSTRCPY( pwd, pwdlen, RXSTRPTR(argv[2]), RXSTRLEN(argv[2]) );
         }
         RXSTRCPY( host, hostlen,"", 0 );
         if ( ValidateAuthType( RxPackageGlobalData, RXSTRPTR(argv[3]), RXSTRLEN(argv[3]), &mode ) )
         {
            char buf[200];
            sprintf( buf, "invalid value of \"%s\" for parameter 4; value should be one of \"DEFAULT, SYSDBA or SYSOPER or blank\"", RXSTRPTR(argv[3]) );
            return ReturnError( RxPackageGlobalData, retstr, 98, buf );
         }
         break;

      case 5:
         if ( RXSTRLEN(argv[1]) == 0 && RXSTRLEN(argv[2]) == 0 )
         {
            RXSTRCPY( uid, uidlen, "/", 1 );
         }
         else
         {
            RXSTRCPY( uid, uidlen, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );
            RXSTRCPY( pwd, pwdlen, RXSTRPTR(argv[2]), RXSTRLEN(argv[2]) );
         }
         if ( ValidateAuthType( RxPackageGlobalData, RXSTRPTR(argv[3]), RXSTRLEN(argv[3]), &mode ) )
         {
            char buf[200];
            sprintf( buf, "invalid value of \"%s\" for parameter 4; value should be one of \"DEFAULT, SYSDBA or SYSOPER or blank\"", RXSTRPTR(argv[3]) );
            return ReturnError( RxPackageGlobalData, retstr, 98, buf );
         }
         RXSTRCPY( host, hostlen, RXSTRPTR(argv[4]), RXSTRLEN(argv[4]) );
         break;
   }
#endif
   switch( argc )
   {
      case 5:
         RXSTRCPY( host, hostlen, RXSTRPTR(argv[4]), RXSTRLEN(argv[4]) );
         /* fall through */
      case 4:
         if ( ValidateAuthType( RxPackageGlobalData, RXSTRPTR(argv[3]), RXSTRLEN(argv[3]), &mode ) )
         {
            char buf[200];
            sprintf( buf, "invalid value of \"%s\" for parameter 4; value should be one of \"DEFAULT, SYSDBA or SYSOPER or blank\"", RXSTRPTR(argv[3]) );
            return ReturnError( RxPackageGlobalData, retstr, 98, buf );
         }
         /* fall through */
      case 3:
         RXSTRCPY( pwd, pwdlen, RXSTRPTR(argv[2]), RXSTRLEN(argv[2]) );
         /* fall through */
      case 2:
         RXSTRCPY( uid, uidlen, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );
         /* fall through */
      default:
         break;
   }

   /*
    * If a name is given it is the first argument!/
    * Get the name of the connection (default if not specified).
    */
   if ( RXSTRLEN(argv[0]) )
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
   if ( ( rc = OpenConnection( RxPackageGlobalData, dbname, host, hostlen, uid, uidlen, pwd, pwdlen, mode, &db ) ) )
       return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   /*
    * Based on our auth type, set a falg for use later in ORAStartup() or ORAShutdown()
    */
   if ( mode != OCI_DEFAULT)
      db->connected_as_admin = 1;
   else
      db->connected_as_admin = 0;
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

   if ( commit )
      rc = OCITransCommit( db->svchp, RexxSQLData->DbEnv->errhp, OCI_DEFAULT );
   else
      rc = OCITransRollback( db->svchp, RexxSQLData->DbEnv->errhp, OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );

   return RxReturnNumber( RxPackageGlobalData, retstr, (rc==0)?0:DB_ERROR);
}

/*-----------------------------------------------------------------------------
 * Binds all arguments for standard placemarkers (by number)
 *----------------------------------------------------------------------------*/
static int BindByStandard( RxPackageGlobalDataDef *RxPackageGlobalData, STMT *stmt,ULONG argc,RXSTRING argv[] )
{
   int     i=0,file_bind=0;
   ub2     bind_type=0;
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
      }
      else
      {
         pmd = swa->pm[colno];
      }
      pmd->valuelen = 0;
      pmd->bindhp = NULL;
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
               pmd->bindhp = NULL;
            }
            /* Allocate a new buffer */
            if ( ( pmd->buf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, bindlen+1 ) ) == (ub1*)NULL )
               return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
            pmd->buflen = bindlen;
         }
         pmd->bindhp = NULL;
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
         pmd->valuelen = bindlen;
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
         pmd->bindhp = NULL;
         memcpy( (char*)pmd->buf, RXSTRPTR(*Varg), RXSTRLEN(*Varg) );
         if ( memcmp( RXSTRPTR(*Varg), RexxSQLData->NullStringIn, RXSTRLEN(*Varg) ) == 0 )
            /* indicate a NULL value */
            indp = (short*)&is_null;
         else
            indp = (short*)&not_null;
      }
      switch( bind_type )
      {
         case SQLT_BIN:
         case SQLT_LBI:
            bind_type = SQLT_LBI;
            break;
         default:
            bind_type = SQLT_CHR;
            break;
      }
      InternalTrace( RxPackageGlobalData, "BindByStandard", "ColNo: %d Arg: \"%s\" Len: %d Type: %d", colno+1, (char *)pmd->buf, pmd->buflen, bind_type );
      rc = OCIBindByPos( stmt->stmthp, &pmd->bindhp, RexxSQLData->DbEnv->errhp, colno+1, pmd->buf, pmd->valuelen, bind_type, indp, NULL, NULL, 0, NULL, OCI_DEFAULT );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
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
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 61, tmp ) );
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
   int     rc=0;
   ub2     bind_type = SQLT_STR;
   RXSTRING *Varg=NULL;
   short   *indp=NULL;
   char    tmp[128];
   SQLWA   *swa= SWA(stmt);
   PMDSCR  *pmd=(PMDSCR*)NULL;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "BindByNumber", "%x,%d,%x", stmt, argc, argv );

   /*
    * Bind all variables (if any) to placeholders in SQL statement. It is
    * assumed that the variables are static for the life of the SQL statement
    * i.e. their addresses remain fixed.
    */
   /*
    * Bind all variables (if any) to placeholders in SQL statement. It is
    * assumed that the variables are static for the life of the SQL statement
    * i.e. their addresses remain fixed.
    */
   for ( i = 0; i < (int)argc && i < MAX_BINDVARS; i++ )
   {
      Varg = &argv[i];
      /*
       * Get the parameter marker descriptor
       */
      if ( swa->pm[i] == (PMDSCR*)NULL )
      {
         if ( ( pmd = (swa->pm[i] = (PMDSCR*)MALLOC_TSD(  RxPackageGlobalData, sizeof(PMDSCR) ) ) ) == (PMDSCR*)NULL )
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
         pmd->buf = (ub1*)NULL;
         pmd->buflen = 0;
      }
      else
      {
         pmd = swa->pm[i];
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
         memcpy( (char*)pmd->buf, RXSTRPTR(*Varg), RXSTRLEN(*Varg) );
         if ( memcmp( RXSTRPTR(*Varg), RexxSQLData->NullStringIn, RXSTRLEN(*Varg) ) == 0 )
            /* indicate a NULL value */
            indp = (short*)&is_null;
         else
            indp = (short*)&not_null;
      }
      pmd->valuelen = RXSTRLEN(*Varg);
      pmd->bindhp = NULL;
      InternalTrace( RxPackageGlobalData, "BindByNumber", "ColNo: %d Arg: \"%s\" Len: %d Type: %d", i+1, (char *)pmd->buf, pmd->buflen, bind_type );
      rc = OCIBindByPos( stmt->stmthp, &pmd->bindhp, RexxSQLData->DbEnv->errhp, i+1, pmd->buf, pmd->buflen, bind_type, indp, NULL, NULL, 0, NULL, OCI_DEFAULT );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
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
   int           file_bind=0;
   ub2           bind_type=0;
   int           rc=0, bindlen=0;
   sb4           namelen;
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
      namelen = strlen( name );
      if ( namelen == 0 )
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
         bind_type = SQLT_STR;
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
         if ( bindlen == strlen( RexxSQLData->NullStringIn )
         &&   memcmp( (char*)pmd->buf, RexxSQLData->NullStringIn, bindlen ) == 0 )
            /* indicate a NULL value */
            indp = (short*)&is_null;
         else
            indp = (short*)&not_null;
         pmd->valuelen = bindlen;
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
         memcpy( (char*)pmd->buf, RXSTRPTR(*Varg), RXSTRLEN(*Varg) );
         if ( memcmp( RXSTRPTR(*Varg), RexxSQLData->NullStringIn, RXSTRLEN(*Varg) ) == 0 )
            /* indicate a NULL value */
            indp = (short*)&is_null;
         else
            indp = (short*)&not_null;
         pmd->valuelen = RXSTRLEN(*Varg);
      }
      pmd->bindhp = NULL;
      switch( bind_type )
      {
         case SQLT_BIN:
         case SQLT_LBI:
         case SQLT_BLOB:
            bind_type = SQLT_LBI;
            break;
         default:
            bind_type = SQLT_CHR;
            break;
      }
      InternalTrace( RxPackageGlobalData, "BindByName", "ColNo: %d Arg Len: %d Type: %d", colno+1, pmd->buflen, bind_type );
      rc = OCIBindByName( stmt->stmthp, &pmd->bindhp, RexxSQLData->DbEnv->errhp, (text *)name, namelen, pmd->buf, pmd->buflen, bind_type, indp, NULL, NULL, 0, NULL, OCI_DEFAULT );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
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
      memset( fd, 0, sizeof(FLDDSCR) );
      fd->cbuf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, MAX_NAMELEN+1 );
      if (fd->cbuf == (ub1*)NULL)
      {
         FREE_TSD( RxPackageGlobalData, fd);
         fd = swa->fa[i] = NULL;
         return (FLDDSCR*)NULL;
      }
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
   SQLWA     *swa= SWA(stmt);
   FLDDSCR   *fd=NULL;
   int       i=0;
   int       rc,counter;
   sb4       dsize=0;
   ub4       char_semantics;
   ub2       ext_type;
   DBCON     *db=NULL;
   OCIParam  *mypard = (OCIParam *) 0;
   OCIDefine *mydef;
   char      *cbuf;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "DefineExpressions", "%x", stmt );
   /*
    * Get pointer to connection for this statement
    */
   db = stmt->db;
   /*
    * Call OCIStmtExecute() with the OCI_DESCRIBE_ONLY to get details about the values in the SELECT
    */
   rc = OCIStmtExecute( db->svchp, stmt->stmthp, RexxSQLData->DbEnv->errhp, (ub4) 0, (ub4) 0,
                        (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL, OCI_DESCRIBE_ONLY );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      return DB_ERROR;
   }
   rc = OCIAttrGet( stmt->stmthp, (ub4) OCI_HTYPE_STMT,
                    (dvoid*) &swa->expr_cnt, (ub4 *) 0, (ub4) OCI_ATTR_PARAM_COUNT,
                    RexxSQLData->DbEnv->errhp );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      return DB_ERROR;
   }
   DEBUGDUMP(fprintf(stderr, "%s-%d: DefineExpressions: Number Columns: %d\n", __FILE__,__LINE__, swa->expr_cnt );)
   /*
    * Check if too many SELECT expressions.
    */
   if (i >= MAX_COLS)
       return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 71, "Too many columns specified in SELECT" ));
   /* Describe & define buffer for each expression in the SELECT statement */
   for ( i = 0; i < swa->expr_cnt ; i++ )
   {
      counter = i + 1;
      rc = OCIParamGet( stmt->stmthp, OCI_HTYPE_STMT, RexxSQLData->DbEnv->errhp, (dvoid **)&mypard, (ub4) counter );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      /* Get a new field descriptor */
      if ( ( fd = GetFldDscr( RxPackageGlobalData, swa, i ) ) == (FLDDSCR*)NULL )
         return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));

      /* Retrieve the datatype attribute */
      rc = OCIAttrGet( (dvoid*) mypard, (ub4) OCI_DTYPE_PARAM,
                       (dvoid*) &fd->dbtype, (ub4 *) 0, (ub4) OCI_ATTR_DATA_TYPE,
                       RexxSQLData->DbEnv->errhp );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      /* Retrieve the column name attribute into a local pointer...*/
      rc = OCIAttrGet( (dvoid*) mypard, (ub4) OCI_DTYPE_PARAM,
                       &cbuf, (ub4 *) &fd->cbufl, (ub4) OCI_ATTR_NAME,
                       RexxSQLData->DbEnv->errhp );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      /* ... then save it in our pre-allocated buffer */
      memcpy( fd->cbuf, cbuf, fd->cbufl );
      fd->cbuf[fd->cbufl] = '\0';

      /* Retrieve the length semantics for the column */
      char_semantics = 0;
      rc = OCIAttrGet( (dvoid*) mypard, (ub4) OCI_DTYPE_PARAM,
                       (dvoid*) &char_semantics, (ub4 *) 0, (ub4) OCI_ATTR_CHAR_USED,
                       RexxSQLData->DbEnv->errhp );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      dsize = 0;
      if ( char_semantics )
      {
         /* Retrieve the column width in characters */
         rc = OCIAttrGet( (dvoid*) mypard, (ub4) OCI_DTYPE_PARAM,
                          (dvoid*) &dsize, (ub4 *) 0, (ub4) OCI_ATTR_CHAR_SIZE,
                          RexxSQLData->DbEnv->errhp );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            return DB_ERROR;
         }
      }
      else
      {
         /* Retrieve the column width in bytes */
         rc = OCIAttrGet( (dvoid*) mypard, (ub4) OCI_DTYPE_PARAM,
                          (dvoid*) &dsize, (ub4 *) 0, (ub4) OCI_ATTR_DATA_SIZE,
                          RexxSQLData->DbEnv->errhp );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            return DB_ERROR;
         }
      }
      /* Retrieve the precision for the column */
      rc = OCIAttrGet( (dvoid*) mypard, (ub4) OCI_DTYPE_PARAM,
                       (dvoid*) &fd->prec, (ub4 *) 0, (ub4) OCI_ATTR_PRECISION,
                       RexxSQLData->DbEnv->errhp );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      /* Retrieve the scale for the column */
      rc = OCIAttrGet( (dvoid*) mypard, (ub4) OCI_DTYPE_PARAM,
                       (dvoid*) &fd->scale, (ub4 *) 0, (ub4) OCI_ATTR_SCALE,
                       RexxSQLData->DbEnv->errhp );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      /* Retrieve the nullability for the column */
      rc = OCIAttrGet( (dvoid*) mypard, (ub4) OCI_DTYPE_PARAM,
                       (dvoid*) &fd->nullok, (ub4 *) 0, (ub4) OCI_ATTR_IS_NULL,
                       RexxSQLData->DbEnv->errhp );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      /*
       * Free the descriptor
       */
      rc = OCIDescriptorFree( mypard, OCI_DTYPE_PARAM );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      /*
       * Because OCI returns storage information about how column data is stored in the database and
       * not how it will be displayed, we have to adjust the column buffers (rbuf and rbufl) based
       * on the datatype and arbitrary values which should be enough.
       */
      fd->locator_type = RXSQL_LOCATOR_NONE;
      fd->use_strlen = 1; /* by default use strlen() to get length of returned data */
      ext_type = SQLT_STR; /* ora7 was SQL_LNG */
      switch( fd->dbtype )
      {
         case SQLT_DAT:
            dsize = 75; /* should be plenty */
            break;
         case SQLT_TIME:
         case SQLT_TIME_TZ:
            break; /* what to do here ? */
         case SQLT_TIMESTAMP:
            fd->locator.timestamp.ts_dtype = OCI_DTYPE_TIMESTAMP;
            rc = OCIDescriptorAlloc( RexxSQLData->DbEnv->envhp, (dvoid **)&fd->locator.timestamp.ts, fd->locator.timestamp.ts_dtype, 0, (dvoid **)0 );
            if ( rc != OCI_SUCCESS )
            {
               SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
               return DB_ERROR;
            }
            fd->locator_type = RXSQL_LOCATOR_TIMESTAMP;
            fd->use_strlen = 0;
            dsize = 35; /* should be enough */
            ext_type = fd->dbtype;
            break;
         case SQLT_TIMESTAMP_TZ:
            fd->locator.timestamp.ts_dtype = OCI_DTYPE_TIMESTAMP_TZ;
            rc = OCIDescriptorAlloc( RexxSQLData->DbEnv->envhp, (dvoid **)&fd->locator.timestamp.ts, fd->locator.timestamp.ts_dtype, 0, (dvoid **)0 );
            if ( rc != OCI_SUCCESS )
            {
               SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
               return DB_ERROR;
            }
            fd->locator_type = RXSQL_LOCATOR_TIMESTAMP;
            fd->use_strlen = 0;
            dsize = 35; /* should be enough */
            ext_type = fd->dbtype;
            break;
         case SQLT_TIMESTAMP_LTZ:
            fd->locator.timestamp.ts_dtype = OCI_DTYPE_TIMESTAMP_LTZ;
            rc = OCIDescriptorAlloc( RexxSQLData->DbEnv->envhp, (dvoid **)&fd->locator.timestamp.ts, fd->locator.timestamp.ts_dtype, 0, (dvoid **)0 );
            if ( rc != OCI_SUCCESS )
            {
               SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
               return DB_ERROR;
            }
            fd->locator_type = RXSQL_LOCATOR_TIMESTAMP;
            fd->use_strlen = 0;
            dsize = 35; /* should be enough */
            ext_type = fd->dbtype;
            break;
         case SQLT_BIN:
            ext_type = SQLT_LBI;
            fd->use_strlen = 0;
            break;
         case SQLT_LBI:
            ext_type = SQLT_LBI;
            dsize = RexxSQLData->LongLimit;
            fd->use_strlen = 0;
            break;
         case SQLT_LNG:
            dsize = RexxSQLData->LongLimit;
            fd->use_strlen = 0;
            break;
         case SQLT_CLOB:
         case SQLT_BLOB:
            fd->locator_type = RXSQL_LOCATOR_LOB;
            rc = OCIDescriptorAlloc( RexxSQLData->DbEnv->envhp, (dvoid **)&fd->locator.lob.lob, OCI_DTYPE_LOB, 0, (dvoid **)0 );
            if ( rc != OCI_SUCCESS )
            {
               SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
               return DB_ERROR;
            }
            dsize = sizeof( fd->locator.lob.lob );
            fd->use_strlen = 0;
            ext_type = fd->dbtype;
            break;
         case SQLT_FILE:
            fd->locator_type = RXSQL_LOCATOR_LOB;
            rc = OCIDescriptorAlloc( RexxSQLData->DbEnv->envhp, (dvoid **)&fd->locator.lob.lob, OCI_DTYPE_FILE, 0, (dvoid **)0 );
            if ( rc != OCI_SUCCESS )
            {
               SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
               return DB_ERROR;
            }
            dsize = sizeof( fd->locator.lob.lob );
            fd->use_strlen = 0;
            ext_type = fd->dbtype;
            break;
         default:
            break;
      }
      /*
       * In an attempt to save malloc() & free() calls we keep the old
       * buffer providing it is not grossly oversized.
       */
      if ( (size_t)fd->rbufl < dsize || (size_t)fd->rbufl > dsize + 256)
      {
         /* Free the old buffer (if any) */
         if ( fd->rbuf )
         {
            FREE_TSD( RxPackageGlobalData, fd->rbuf);
            fd->rbufl = 0;
            fd->rbuf = NULL;
         }
         /* Allocate a new buffer */
         if ( ( fd->rbuf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, dsize+5 ) ) == (ub1*)NULL )
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ));
      }
      fd->rbufl = dsize;
      /*
       * TODO - define
       */
      switch( fd->dbtype )
      {
         case SQLT_BLOB:
         case SQLT_CLOB:
            rc = OCIDefineByPos( stmt->stmthp, &mydef, RexxSQLData->DbEnv->errhp,
                                 counter, (dvoid *) &fd->locator.lob.lob, (sb4) sizeof(&fd->locator.lob.lob),
                                 ext_type, &fd->indp, (ub2 *) 0,
                                 (ub2 *) 0, OCI_DEFAULT );
            DEBUGDUMP(fprintf(stderr, "%s-%d: DefineExpressions(LOB): Name: %s Type: %d Database Size: %d rbufl: %d Precision: %d Scale: %d Null: %d\n",
                                __FILE__,__LINE__, fd->cbuf, fd->dbtype, dsize, fd->rbufl, fd->prec, fd->scale, fd->nullok );)
            break;
         case SQLT_TIMESTAMP:
         case SQLT_TIMESTAMP_TZ:
         case SQLT_TIMESTAMP_LTZ:
            rc = OCIDefineByPos( stmt->stmthp, &mydef, RexxSQLData->DbEnv->errhp,
                                 counter, (dvoid *) &fd->locator.timestamp.ts, (sb4) sizeof(&fd->locator.timestamp.ts),
                                 ext_type, &fd->indp, (ub2 *) 0,
                                 (ub2 *) 0, OCI_DEFAULT );
            DEBUGDUMP(fprintf(stderr, "%s-%d: DefineExpressions(LOB): Name: %s Type: %d Database Size: %d rbufl: %d Precision: %d Scale: %d Null: %d\n",
                                __FILE__,__LINE__, fd->cbuf, fd->dbtype, dsize, fd->rbufl, fd->prec, fd->scale, fd->nullok );)
            break;
         default:
            rc = OCIDefineByPos( stmt->stmthp, &mydef, RexxSQLData->DbEnv->errhp,
                                 counter, (dvoid *) fd->rbuf, (sb4) (fd->rbufl)+1,
                                 ext_type, &fd->indp, (ub2 *) 0,
                                 (ub2 *) 0, OCI_DEFAULT );
            DEBUGDUMP(fprintf(stderr, "%s-%d: DefineExpressions: Name: %s Type: %d Database Size: %d rbufl: %d Precision: %d Scale: %d Null: %d\n",
                                __FILE__,__LINE__, fd->cbuf, fd->dbtype, dsize, fd->rbufl, fd->prec, fd->scale, fd->nullok );)
            break;
      }
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      /*
       * Other initialisations...
       */
      fd->locator.lob.loblen = 0;
      fd->locator.lob.lob_piece = OCI_FIRST_PIECE;
   } /* while */

   return (int)FunctionEpilogue( RxPackageGlobalData, "DefineExpressions", (long)swa->expr_cnt );
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

   rc = OCIStmtFetch2( stmt->stmthp, RexxSQLData->DbEnv->errhp, 1, OCI_DEFAULT, 0, OCI_DEFAULT );
   switch( rc )
   {
      case OCI_NO_DATA:
         return (int)FunctionEpilogue( RxPackageGlobalData, "FetchRow", (long)rc );
         break;
      case OCI_SUCCESS_WITH_INFO:
      case OCI_SUCCESS:
         break;
      default:
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
         break;
   }

   /* Get each expr value in turn */
   for ( i = 0; rc == 0 && i < swa->expr_cnt; i++ )
   {
      fd = swa->fa[i];

      /* Add each column value to the stem's values */
      if ( rowcount )
         varlen = sprintf( varname, "%s.%s.%lu", stem, fd->cbuf, rowcount );
      else
         varlen = sprintf( varname, "%s.%s",  stem, fd->cbuf );

      if ( fd->indp == -1 )      /* returned value is NULL */
      {
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, RexxSQLData->RXSNullStringOut.strptr, RexxSQLData->RXSNullStringOut.strlength );
      }
      else
      {
         /*
          * Check for TIMESTAMP locators and convert from an OCIDateTime structure to a string
          */
         if ( fd->locator_type == RXSQL_LOCATOR_TIMESTAMP )
         {
            rc = OCIDateTimeToText ( RexxSQLData->DbEnv->envhp, RexxSQLData->DbEnv->errhp, fd->locator.timestamp.ts, NULL, 0, fd->scale, NULL, 0, (ub4 *)&fd->rbufl, fd->rbuf );
            if ( rc != OCI_SUCCESS )
            {
               SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
               return DB_ERROR;
            }
         }
         /*
          * When a row is fetched into fd->rbuf, Oracle returns a nul-terminated value for
          * those datatypes it can convert. It does not update fd->rbufl with the actual length of the
          * data returned, so depending on the datatype we have to use strlen() to get the actual
          * data length; this sucks!
          */
         sb4 retlen;
         if ( fd->use_strlen )
            retlen = strlen( fd->rbuf );
         else
            retlen = fd->rbufl;
         if ( fd->indp > 0        /* truncation or conversion error */
         ||   fd->indp == -2 )
         {
            if (RexxSQLData->IgnoreTruncate)
            {
               rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, (char*)fd->rbuf, retlen );
            }
            else
            {
               sprintf( tmp, "Conversion/truncation occurred on column %s", fd->cbuf );
               return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 15, tmp ) );
            }
         }
         else
         {
            rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, (char*)fd->rbuf, retlen );
         }
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

   for ( i = 0; i < swa->expr_cnt; i++ )
   {
      sprintf( varname, "%s.%s.0", stem_name, swa->fa[i]->cbuf );
      sprintf( buf, "%lu", rowcount );
      if ( SetRexxVariable( RxPackageGlobalData, varname,strlen(varname), buf,strlen(buf) ) )
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
   sb4         iters = 1; /* for non-SELECTs this must be 1 */
   char        *stmt_ptr=NULL;
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
      if ( ( rc = AllocStatement( RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt ) ) )
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

   /*
    * If the request is to use "standard" placemarkers; ?, then we
    * need to convert these into Oracle's placemarkers, :1 -> :n
    */
   if ( RexxSQLData->StandardPlacemarkers )
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


   /* Prepare the statement */
   rc = OCIStmtPrepare( stmt->stmthp, RexxSQLData->DbEnv->errhp, (text *)stmt_ptr,
                        (ub4) strlen((char *) stmt_ptr),
                        (ub4) OCI_NTV_SYNTAX, (ub4) OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      return DB_ERROR;
   }

   /* determine type of statement */
   rc = OCIAttrGet ( stmt->stmthp, OCI_HTYPE_STMT, &swa->stmt_type, 0, OCI_ATTR_STMT_TYPE, RexxSQLData->DbEnv->errhp );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      return DB_ERROR;
   }

   /* Bind variables in WHERE/INSERT/UPDATE clause (if any). */
   if (argc > 2)
   {
      if ( ( rc = BindValues( RxPackageGlobalData, stmt, argc-2, &argv[2] ) ) )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
      }
   }
   /*
    * If a SELECT, prepare our output buffers...
    */
   if ( swa->stmt_type == OCI_STMT_SELECT )
   {
      /*
       * Describe the expression list & define output buffers (if any).
       */
      if ( ( expr_cnt = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
      {
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt);
      }

      if ( expr_cnt == 0 )
      {
         (void)sprintf( tmp, "statement \"%s\" is not a query.", stem_name );
         stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
         return ReturnError( RxPackageGlobalData, retstr, 13, tmp );
      }
      /*
       * Do not automatically fetch a row when calling OCIStmtExecute
       */
      iters = 0;
   }

   /*
    * Execute the SQL statement. This is required for Queries & DML!
    */
   rc = OCIStmtExecute( db->svchp, stmt->stmthp, RexxSQLData->DbEnv->errhp, (ub4) iters, (ub4) 0,
                        (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL, OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }

   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );

   /*
    * Return the ROWCOUNT.  For a query it will be zero at this stage.  For
    * a DML statement it will be the number of rows affected by the INSERT/
    * UPDATE/DELETE statement.
    */
   if ( swa->stmt_type == OCI_STMT_SELECT )
   {
      /* Fetch each row in turn */
      for (rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= RexxSQLData->RowLimit; rowcount++)
      {
         if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount ) ) )
            break;
      }
      rowcount--;

      if ( rc && rc != OCI_NO_DATA )
      {
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
      }

      if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   }
   else
   {
      rc = OCIAttrGet ( stmt->stmthp, OCI_HTYPE_STMT, &rowcount, 0, OCI_ATTR_ROW_COUNT, RexxSQLData->DbEnv->errhp );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      /*
       * If the statement is NOT a SELECT and we have AUTOCOMMIT
       * ON, then commit the statement.
       */
      if ( RexxSQLData->AutoCommit )
      {
         rc = OCITransCommit ( db->svchp, RexxSQLData->DbEnv->errhp, OCI_DEFAULT );
         if ( rc != OCI_SUCCESS )
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
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
   if ( RexxSQLData->DbEnv == (DBENV*)NULL )
      return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );

   /* Get pointer to current connection */
   if ( RexxSQLData->DbEnv->current_connection )
      db = RexxSQLData->DbEnv->current_connection;
   else
       return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );

   if ( RXSTRLEN(argv[0]) == 0 ) /* No statement name specified! */
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
     if ( ( rc = AllocStatement( RxPackageGlobalData, stmt_name, db, &stmt ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

     /* Insert this statement into the connection hash table. */
     (void)InsertObject( RxPackageGlobalData, stmt, RexxSQLData->DbEnv->stmt_tbl, TBL_STATEMENTS );

     db->num_statements++;
   }

   swa = SWA(stmt);

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

   /* Prepare the statement */
   rc = OCIStmtPrepare( stmt->stmthp, RexxSQLData->DbEnv->errhp, (text *)stmt_ptr,
                        (ub4) strlen((char *) stmt_ptr),
                        (ub4) OCI_NTV_SYNTAX, (ub4) OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      return DB_ERROR;
   }

   /* determine type of statement */
   rc = OCIAttrGet ( stmt->stmthp, OCI_HTYPE_STMT, &swa->stmt_type, 0, OCI_ATTR_STMT_TYPE, RexxSQLData->DbEnv->errhp );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      return DB_ERROR;
   }
   return RxReturnNumber( RxPackageGlobalData, retstr,  0 );
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
   sb4         iters = 1; /* for non-SELECTs this must be 1 */
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

   /*
    * Get pointer to connection for this statement
    */
   db = stmt->db;
   /*
    * Rest of args (if any) are bind values. Therefore bind the substitution
    * variables in WHERE/INSERT/UPDATE clause (if any).
    */
   argc--;
   if ( argc )
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
   if ( open )
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
      if ( expr_cnt == 0 )
      {
         if ( swa->stmt_type == OCI_STMT_SELECT )
         {
            (void)sprintf(tmp,"statement \"%s\" is not a query.", stmt_name);
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
            return ReturnError( RxPackageGlobalData, retstr, 13, tmp );
         }
         else
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
            return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
         }
      }
      /*
       * Do not automatically fetch a row when calling OCIStmtExecute
       */
      iters = 0;
   }

   /*
    * Execute the SQL statement. This is required for Queries & DML!
    */
   rc = OCIStmtExecute( db->svchp, stmt->stmthp, RexxSQLData->DbEnv->errhp, iters, (ub4) 0,
                        (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL, OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }

   stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );

   /*
    * Return the ROWCOUNT.  For a query it will be zero at this stage.  For
    * a DML statement it will be the number of rows affected by the INSERT/
    * UPDATE/DELETE statement.
    */
   if ( !open )
   {
      rc = OCIAttrGet ( stmt->stmthp, OCI_HTYPE_STMT, &rowcount, 0, OCI_ATTR_ROW_COUNT, RexxSQLData->DbEnv->errhp );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
   }
   SetRowCount( RxPackageGlobalData, rowcount );

   /*
    * If the statement is NOT called from SQLOPEN(), and we have AUTOCOMMIT
    * ON, then commit the statement.
    */
   if ( !open
   &&   RexxSQLData->AutoCommit )
   {
      rc = OCITransCommit ( db->svchp, RexxSQLData->DbEnv->errhp, OCI_DEFAULT );
      if ( rc != OCI_SUCCESS )
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
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

   /*
    * This function is obsolete; Oracle8 OCI does not have an equivalent function
    */
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
         rc = (rc == OCI_NO_DATA) ? 0 : rc;
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

      if (rc && rc != OCI_NO_DATA)
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
 *            We can only call this for LOB columns. A LOB column has a not-null fd->locator.lob.lob
 *            either a CLOB/BLOB or BFILE
 * RETURNS :  0-end-of-data,
 *           >0- bytes obtained - <= length
 *           <0-error.
 Implement this by:
 Always define output to LOB locator or BFILE locator
 When fetching,
   OCILobOpen
   get length of LOB using OCILobGetLength()
   get first piece (or all if length <= long_limit,
   OCILobClose

 When sqlgetdata
   First call; OCILobOpen (set flag)
     OCILobRead( FIRST )
   Subsequent calls
     Check flag
     OCILobRead( NEXT )
   Last call????
 *----------------------------------------------------------------------------*/
rxfunc( SQLGETDATA )
{
#define LONG_BLOCK_SIZE 0x8000      /* 32k */
   FLDDSCR *fd=NULL;
   long    rc=0;
   rx_long_long num_bytes=0L;
   rx_long_long start_byte=0L;
   oraub8  byte_amt = 0;
   oraub8  char_amt = 0;
   oraub8  offset = 1;
   ub4     chunk_size;
   STMT    *stmt=NULL;
   SQLWA   *swa=NULL;
   DBCON   *db=NULL;
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

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 4, 5 ) )
      return 1;

   if ( ( stmt = GetStatement( RxPackageGlobalData, argv[0], stmt_name ) ) == (STMT*)NULL )
      return RxReturnNumber( RxPackageGlobalData, retstr, RexxSQLData->SQLCA_IntCode);

   swa = SWA(stmt);
   /*
    * Get pointer to connection for this statement
    */
   db = stmt->db;

   /*
    * Check that the column name specified is a LOB or BFILE and
    * get column number.
    */
   if ( RXSTRLEN(argv[1]) )
   {
      for ( i = 0; i < swa->expr_cnt; i++ )
      {
         fd = swa->fa[i];
         if ( fd->cbufl == RXSTRLEN(argv[1])
         &&   memcmpi( RxPackageGlobalData, RXSTRPTR(argv[1]), fd->cbuf, fd->cbufl ) == 0 )
         {
            /*
             * Found column name, is it a "LONG" ?
            if ( fd->dbtype != SQLT_CLOB
            &&   fd->dbtype != SQLT_BLOB
            &&   fd->dbtype != SQLT_FILE )
             */
            if ( fd->locator_type == RXSQL_LOCATOR_LOB )
            {
               sprintf( tmp, "Column <%s> does not have a 'LOB' datatype.", fd->cbuf );
               return ReturnError( RxPackageGlobalData, retstr, 85,tmp );
            }
            if ( fd->indp == -1 )
            {
               sprintf( tmp, "Column <%s> has NULL value; cannot call this function.", fd->cbuf );
               return ReturnError( RxPackageGlobalData, retstr, 89,tmp );
            }
            long_col = i+1;
            break;
         }
      }
      if ( long_col == 0 )
      {
         sprintf( tmp, "Column <%s> not present in statement.", fd->cbuf );
         return ReturnError( RxPackageGlobalData, retstr, 88, tmp );
      }
   }
   else
   {
      return ReturnError( RxPackageGlobalData, retstr, 84, "<column-name> parameter MUST be supplied." );
   }

   /*
    * Determine starting byte
    */
   if ( RXSTRLEN(argv[2]) )
   {
      if ( RxStrToLongLong( RxPackageGlobalData, &argv[2], &start_byte ) )
      {
         return ReturnError( RxPackageGlobalData, retstr, 14, "<start-byte> is not a valid integer." );
      }
   }
   else
      start_byte = 0L;

   /*
    * Determine length
    */
   if ( RXSTRLEN(argv[3]) )
   {
      if ( RxStrToLongLong( RxPackageGlobalData, &argv[3], &num_bytes ) )
      {
         return ReturnError( RxPackageGlobalData, retstr, 14, "<number-bytes> is not a valid integer." );
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
      return ReturnError( RxPackageGlobalData, retstr, 84, "<file-name> parameter MUST be supplied." );
   }

   //ext_type = (fd->dbtype==ORA_RAW||fd->dbtype==ORA_LONGRAW)?EXT_LONGRAW:EXT_LONG;
   if ( start_byte == 0L
   &&   num_bytes == 0L )
   {
      /*
       * Process a file
       * We get the LOB chunk size and use that to get each piece; its more efficient
       */
      ub1 *buf=NULL;

      if ( ( fp = fopen( RXSTRPTR(argv[4]), "wb" ) ) == NULL )
      {
         sprintf( tmp, "<open> on file <%s> failed: %s.", RXSTRPTR(argv[4]), strerror( errno ) );
         return ReturnError( RxPackageGlobalData, retstr, 86, tmp );
      }
      /*
       * Get LOB chunk size for efficiency
       */
      rc = OCILobGetChunkSize ( db->svchp, RexxSQLData->DbEnv->errhp, fd->locator.lob.lob, &chunk_size );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         return DB_ERROR;
      }
      fd->locator.lob.lob_piece = OCI_FIRST_PIECE;

      if ( ( buf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, chunk_size+1 ) ) == (ub1*)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

      if ( fd->dbtype == SQLT_FILE )
      {
         /*
          * If a BFILE column, open the BFILE
          */
         rc = OCILobFileOpen( db->svchp, RexxSQLData->DbEnv->errhp, fd->locator.lob.lob, OCI_FILE_READONLY );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            return DB_ERROR;
         }
      }
      /*
       * Get the complete LOB in chunk_size pieces...
       */
      for ( i = 0 ; ; i++ )
      {
         rc = OCILobRead2( db->svchp, RexxSQLData->DbEnv->errhp, fd->locator.lob.lob, &byte_amt, &char_amt, offset, buf, chunk_size, fd->locator.lob.lob_piece, NULL, NULL, 0, SQLCS_IMPLICIT );
         buf[chunk_size] = '\0';
         /*
          * OCI_SUCCESS and OCI_NEED_DATA are successful results
          */
         if ( rc != OCI_SUCCESS
         &&   rc != OCI_NEED_DATA )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            return DB_ERROR;
         }
         /*
          * Workaround BUG in OCI: on first call to OCILobRead2() with OCI_FIRST_PIECE, the returned
          * value in char_amt is 0, when it should be chunk_size (the data IS returned in buf).
          * So we "fix" char_amt
          */
         if ( fd->locator.lob.lob_piece == OCI_FIRST_PIECE
         &&   rc == OCI_NEED_DATA
         &&   char_amt == 0 )
            char_amt = chunk_size;
         /*
          * If we have something to write to the file do it!
          */
         if ( char_amt )
         {
            if ( (long)fwrite( (void*)buf, sizeof(ub1), char_amt, fp ) != char_amt )
            {
               if (buf) FREE_TSD( RxPackageGlobalData, buf);
               sprintf(tmp, "<write> on file <%s> failed: %s.", RXSTRPTR(argv[4]), strerror(errno) );
               return ReturnError( RxPackageGlobalData, retstr, 86, tmp );
            }
         }
         /*
          * If we have finished extracting the data, leave the loop
          */
         if ( rc == OCI_SUCCESS )
         {
            break;
         }
         /*
          * Ensure the next time around we get the next piece of the LOB
          */
         fd->locator.lob.lob_piece = OCI_NEXT_PIECE;
      }

      if ( fd->dbtype == SQLT_FILE )
      {
         /*
          * If a BFILE column, close the BFILE
          */
         rc = OCILobFileClose( db->svchp, RexxSQLData->DbEnv->errhp, fd->locator.lob.lob );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            return DB_ERROR;
         }
      }
      if (buf)
         FREE_TSD( RxPackageGlobalData, buf);
      if ( fclose(fp ) )
      {
         sprintf(tmp,"<close> on file <%s> failed: %s.",RXSTRPTR(argv[4]),strerror(errno));
         return ReturnError( RxPackageGlobalData, retstr, 86, tmp );
      }
   }
   else
   {
      /*
       * First time through save some things. Getting LOB length cannot be done if in the middle of
       * getting the LOB, so we have to save it.
       */
      if ( fd->locator.lob.lob_piece == OCI_FIRST_PIECE )
      {
         /*
          * Get the length of the LOB and check if we are requesting past the start of the LOB
          * or the number of bytes requested goes past the end. Adjust input variables as appropriate
          */
         rc = OCILobGetLength2( db->svchp, RexxSQLData->DbEnv->errhp, fd->locator.lob.lob, &fd->locator.lob.loblen );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            return DB_ERROR;
         }
      }
      if ( start_byte <= fd->locator.lob.loblen )
      {
         if ( start_byte + num_bytes > fd->locator.lob.loblen )
         {
            num_bytes = fd->locator.lob.loblen - start_byte + 1;
         }
         /*
          * Get the chunk of data specified
          * Size of the chunk MUST be < 64K
          */
         if ( num_bytes >= 0x10000 )
            return ReturnError( RxPackageGlobalData, retstr, 87, "<number-bytes> parameter must be < <65536>." );
         /*
          * In an attempt to save malloc() & free() calls we keep the old
          * buffer providing it is not grossly oversized.
          */
         if ( (size_t)fd->rbufl < num_bytes
         ||   (size_t)fd->rbufl > num_bytes + 256 )
         {
            /* Free the old buffer (if any) */
            if ( fd->rbufl )
            {
               FREE_TSD( RxPackageGlobalData, fd->rbuf);
               fd->rbufl = 0;
               fd->rbuf = NULL;
            }
            /* Allocate a new buffer */
            if ( ( fd->rbuf = (ub1*)MALLOC_TSD(  RxPackageGlobalData, num_bytes+1 ) ) == (ub1*)NULL )
               return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );
         }
         fd->rbufl = num_bytes;
         byte_amt = char_amt = num_bytes;
         fd->locator.lob.lob_piece = OCI_ONE_PIECE;
         rc = OCILobRead2( db->svchp, RexxSQLData->DbEnv->errhp, fd->locator.lob.lob, &byte_amt, &char_amt, start_byte, fd->rbuf, num_bytes, fd->locator.lob.lob_piece, NULL, NULL, 0, SQLCS_IMPLICIT );
         /*
          * As we are reading ONE piece we can't get OCI_NEED_DATA
          */
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            return DB_ERROR;
         }

         /*
          * Workaround BUG in OCI: on first call to OCILobRead2() with OCI_FIRST_PIECE, the returned
          * value in char_amt is 0, when it should be chunk_size (the data IS returned in buf).
          * So we "fix" char_amt. This is not needed for OCI_ONE_TIME; the correct value is actually returned.
         if ( char_amt == 0 )
            char_amt = num_bytes;
          */
         fd->rbuf[char_amt] = '\0';

         (void)sprintf(varname, "%s.%s", stmt_name, fd->cbuf);
         varlen = strlen(varname);
         rc = SetRexxVariable( RxPackageGlobalData, varname, varlen, (char*)fd->rbuf, char_amt);
      }
      else
      {
         char_amt = 0;
      }
   }
   return RxReturnNumber( RxPackageGlobalData, retstr, char_amt);
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

   for ( idx = 0; datatype_conversion[idx].ext_datatype; idx++ )
   {
      if ( datatype_conversion[idx].int_datatype == fd->dbtype )
      {
         column_type = datatype_conversion[idx].ext_datatype;
         break;
      }
   }
   if ( column_type == NULL )
      column_type = "UNKNOWN";

   /* Set up the array */
   value[0] = (char*)fd->cbuf;
   value_len[0] = fd->cbufl;

   value[1] = column_type;
   value_len[1] = strlen(column_type);

   (void)sprintf(column_size, "%ld", (long)fd->rbufl);
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
   for ( idx = 0; idx < NUM_DESCRIBE_COLUMNS; idx++ )
   {
      sprintf( name, "%s.COLUMN.%s.%d", stem_name, RexxSQLData->column_attribute[idx], i );
      if ( SetRexxVariable( RxPackageGlobalData, name,strlen(name),value[idx],value_len[idx]) )
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

   len1 = strlen( stem_name );
   if ( stem_name[len1] == '.' )
      stem_name[len1-1] = '\0';
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
 *
 * RETURNS :  0-success, <0-error.
 *            TODO - see ora.c for implementation!
 *
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
      if ( ( rc = AllocStatement( RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

      db->dflt_stmt = (void*)stmt;
   }

   swa = SWA(stmt);

   /* Save the SQL statement. MUST do this as oexec fails if you don't */
   if ( SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), stmt_ptr, stmt_len ) )
      return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

   /* Prepare the statement */
   rc = OCIStmtPrepare( stmt->stmthp, RexxSQLData->DbEnv->errhp, (text *)stmt_ptr,
                        (ub4) strlen((char *) stmt_ptr),
                        (ub4) OCI_NTV_SYNTAX, (ub4) OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      return DB_ERROR;
   }

   /* Describe the expression list & define output buffers (if any). */
   if ( ( expr_cnt = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
   {
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt);
   }

   /*
    * Execute the SQL statement. This is required for Queries & DML!
    */
   rc = OCIStmtExecute( db->svchp, stmt->stmthp, RexxSQLData->DbEnv->errhp, (ub4) 0, (ub4) 0,
                        (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL, OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }

   /* Fetch each row in turn */
   for (rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= RexxSQLData->RowLimit; rowcount++)
   {
      if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount ) ) )
         break;
   }
   rowcount--;

   if ( rc && rc != OCI_NO_DATA )
   {
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   }

   if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount ) ) )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

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
 *            TODO - see ora.c for implementation!
 *
 *----------------------------------------------------------------------------*/
rxfunc( SQLCOLUMNS )
{
   int    rc;
   char   stem_name[MAX_IDENTIFIER+1];
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

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 4, 5 ) )
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
   if ( RXSTRLEN( argv[2] ) )
   {
      sprintf( buf, " and a.owner like '%s'", RXSTRPTR(argv[2]) );
      strcat( whereclause, buf );
   }
   if ( RXSTRLEN( argv[3] ) )
   {
      sprintf( buf, " and table_name like '%s'", RXSTRPTR(argv[3]) );
      strcat( whereclause, buf );
   }
   if ( argc > 4 && RXSTRLEN( argv[4] ) )
   {
      sprintf( buf, " and table_type like '%s'", RXSTRPTR(argv[4]) );
      strcat( whereclause, buf );
   }
   stmt_len = sprintf( buf, "select '' as column_description, '' as table_catalog, a.owner as table_owner, table_name, column_name, data_type as column_type, data_length as column_size, decode(data_precision, NULL,0,data_precision) as column_precision, decode(data_scale,NULL,0,data_scale) as column_scale, nullable as column_nullable, object_type as table_type from all_tab_columns a, all_objects b where a.owner = b.owner and object_name = table_name %s order by table_owner, table_name", whereclause );
   stmt_ptr = buf;

   DEBUGDUMP(fprintf(stderr,"%s-%d: stem: %s\n", __FILE__,__LINE__, stem_name);)

   /* If no default statement then create it! */
   if ((stmt = (STMT*)(db->dflt_stmt)) == (STMT*)NULL)
   {
      /* Open a statement for the default statement. */
      if ( ( rc = AllocStatement( RxPackageGlobalData, DEFAULT_STATEMENT, db, &stmt ) ) )
         return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

      db->dflt_stmt = (void*)stmt;
   }

   swa = SWA(stmt);

   /* Save the SQL statement. MUST do this as oexec fails if you don't */
   if ( SaveSqlStatement( RxPackageGlobalData, &(swa->saved_stmt), stmt_ptr, stmt_len ) )
      return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );

   /* Prepare the statement */
   rc = OCIStmtPrepare( stmt->stmthp, RexxSQLData->DbEnv->errhp, (text *)stmt_ptr,
                        (ub4) strlen((char *) stmt_ptr),
                        (ub4) OCI_NTV_SYNTAX, (ub4) OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      return DB_ERROR;
   }

   /* Describe the expression list & define output buffers (if any). */
   if ( ( expr_cnt = DefineExpressions( RxPackageGlobalData, stmt ) ) < 0 )
   {
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)expr_cnt);
   }

   /*
    * Execute the SQL statement. This is required for Queries & DML!
    */
   rc = OCIStmtExecute( db->svchp, stmt->stmthp, RexxSQLData->DbEnv->errhp, (ub4) 0, (ub4) 0,
                        (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL, OCI_DEFAULT );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      stmt->Argv = FreeArgv( RxPackageGlobalData, &stmt->Argc, stmt->Argv );
      return RxReturnNumber( RxPackageGlobalData, retstr, DB_ERROR);
   }

   /* Fetch each row in turn */
   for (rowcount = 1; RexxSQLData->RowLimit == 0 || rowcount <= RexxSQLData->RowLimit; rowcount++)
   {
      if ( ( rc = FetchRow( RxPackageGlobalData, stmt, stem_name, rowcount ) ) )
         break;
   }
   rowcount--;

   if ( rc && rc != OCI_NO_DATA )
   {
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   }

   if ( ( rc = SetRowCountVar( RxPackageGlobalData, swa, stem_name, rowcount ) ) )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

   /*
    * Release the statement and associated storage.
    */
   if ( ( rc = ReleaseStatement( RxPackageGlobalData, stmt ) ) )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   db->dflt_stmt = (STMT*)NULL;

   return RxReturnNumber( RxPackageGlobalData, retstr, 0 );
}

/*-----------------------------------------------------------------------------
 * Database initialisation
 *----------------------------------------------------------------------------*/
static int DBInitialise( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   OCIInitialize( (ub4) OCI_DEFAULT, (dvoid *)0, (dvoid * (*)(dvoid *, size_t)) 0,
                  (dvoid * (*)(dvoid *, dvoid *, size_t)) 0,
                  (void (*)(dvoid *, dvoid *)) 0 );
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

   OCIServerVersion( db->srvhp, RexxSQLData->DbEnv->errhp, RexxSQLData->DBMSVer, sizeof(RexxSQLData->DBMSVer),OCI_HTYPE_SERVER );
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

#define ORA_STARTUP_NOMOUNT  0
#define ORA_STARTUP_MOUNT    1
#define ORA_STARTUP_OPEN     2
/*-----------------------------------------------------------------------------
 * SYNOPSIS:  ORASTARTUP( [username, password[, connect type[, host[, startup mode[, pfile]]]]])
 *
 * RETURNS : 0 success
 *           1 error
 *----------------------------------------------------------------------------*/
rxfunc( RexxORAStartup )
{
   char   uid[256]="";
   int    uidlen=0;
   char   pwd[256]="";
   int    pwdlen=0;
   char   host[256]="";
   int    hostlen=0;
   int    rc=0;
   sb4    mode=OCI_SYSDBA;
   ub4    startup=ORA_STARTUP_OPEN;
   text   *mount_stmt = (text *)"ALTER DATABASE MOUNT";
   text   *open_stmt = (text *)"ALTER DATABASE OPEN";
   char   *myhost;
   ub4    cred;
   char   *pfile=NULL;
   int    pfile_len=0;
   OCISession  *authp=NULL;
   OCIStmt     *stmthp=NULL;
   OCIServer   *srvhp=NULL;
   OCISvcCtx   *svchp=NULL;
   OCIAdmin    *adminhp=NULL;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 6 ) )
      return 1;

   /* Allocate a DB environment if none exists! */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
   {
      if ( ( RexxSQLData->DbEnv = AllocDbEnvironment( RxPackageGlobalData ) ) == (DBENV*)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory." );
   }
   /*
    * Work out connection string of format:
    * username/password@host[:port][/service name]
    * The portion after the @ is supplied in the host argument
    */
   switch( argc )
   {
      case 6:
         pfile = RXSTRPTR(argv[5]);
         pfile_len = RXSTRLEN(argv[5]);
         /* fall through */
      case 5:
         if ( RXSTRLEN(argv[4]) == 0 )
            startup = ORA_STARTUP_OPEN;
         else if ( RXSTRLEN(argv[4]) == 7 && memcmpi( RxPackageGlobalData, RXSTRPTR(argv[4]), "NOMOUNT", 7 ) == 0 )
            startup = ORA_STARTUP_NOMOUNT;
         else if ( RXSTRLEN(argv[4]) == 5 && memcmpi( RxPackageGlobalData, RXSTRPTR(argv[4]), "MOUNT", 5 ) == 0 )
            startup = ORA_STARTUP_MOUNT;
         else if ( RXSTRLEN(argv[4]) == 4 && memcmpi( RxPackageGlobalData, RXSTRPTR(argv[4]), "OPEN", 4 ) == 0 )
            startup = ORA_STARTUP_OPEN;
         else
         {
            char buf[200];
            sprintf( buf, "invalid value of \"%s\" for parameter 5; value should be one of \"NOMOUNT\", \"MOUNT\", \"OPEN\" or blank\"", RXSTRPTR(argv[4]) );
            return ReturnError( RxPackageGlobalData, retstr, 98, buf );
         }
         /* fall through */
      case 4:
         RXSTRCPY( host, hostlen, RXSTRPTR(argv[3]), RXSTRLEN(argv[3]) );
         /* fall through */
      case 3:
         if ( ValidateAuthType( RxPackageGlobalData, RXSTRPTR(argv[2]), RXSTRLEN(argv[2]), &mode ) )
         {
            char buf[200];
            sprintf( buf, "invalid value of \"%s\" for parameter 3; value should be one of \"DEFAULT\", \"SYSDBA\", \"SYSOPER\" or blank\"", RXSTRPTR(argv[2]) );
            return ReturnError( RxPackageGlobalData, retstr, 98, buf );
         }
         /* fall through */
      case 2:
         RXSTRCPY( pwd, pwdlen, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );
         /* fall through */
      case 1:
         if ( RXSTRLEN(argv[0]) == 0 )
         {
            RXSTRCPY( uid, uidlen, "/", 1 );
         }
         else
         {
            RXSTRCPY( uid, uidlen, RXSTRPTR(argv[0]), RXSTRLEN(argv[0]) );
         }
         break;
      case 0:
//         RXSTRCPY( uid, uidlen, "/", 1 );
         break;
   }
   InternalTrace( RxPackageGlobalData, "ORAStartup", "Host: %s(%d) User: %s(%d) Pass: %s(%d) Mode: %d PFILE: \"%s\"(%d)", host, hostlen, uid, uidlen, pwd, pwdlen, mode, pfile, pfile_len );
   /*
    * Allocate server handle
    */
   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid **) &srvhp, OCI_HTYPE_SERVER, (size_t) 0, (dvoid **) 0 );

   if ( hostlen == 0 )
   {
      myhost = NULL;
   }
   else
      myhost = host;
   /*
    * Attach to server and initialise srvhp
    */
   rc = OCIServerAttach( srvhp, RexxSQLData->DbEnv->errhp, (text *)myhost, hostlen, 0 );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
      return DB_ERROR;
   }
   /*
    * Allocate a service context and associate it to server
    */
   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid **) &svchp, OCI_HTYPE_SVCCTX, (size_t) 0, (dvoid **) 0 );
   OCIAttrSet( (dvoid *) svchp, OCI_HTYPE_SVCCTX, (dvoid *)srvhp, (ub4) 0, OCI_ATTR_SERVER, (OCIError *) RexxSQLData->DbEnv->errhp );
   /*
    * Allocate an authorisation handle and associate username/password with it
    */
   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid *)&authp, (ub4) OCI_HTYPE_SESSION, (size_t) 0, (dvoid **) 0 );
   OCIAttrSet( (dvoid *) authp, (ub4) OCI_HTYPE_SESSION, (dvoid *) uid, (ub4) uidlen, (ub4) OCI_ATTR_USERNAME, RexxSQLData->DbEnv->errhp );
   OCIAttrSet( (dvoid *) authp, (ub4) OCI_HTYPE_SESSION, (dvoid *) pwd, (ub4) pwdlen, (ub4) OCI_ATTR_PASSWORD, RexxSQLData->DbEnv->errhp );
   if ( uid[0] == '/'
   &&   uidlen == 1
   &&   mode != OCI_DEFAULT )
      cred = OCI_CRED_EXT;
   else
      cred = OCI_CRED_RDBMS;
   /*
    * Do our preliminary connection
    */
//   rc = OCISessionBegin ( svchp,  RexxSQLData->DbEnv->errhp, authp, cred, mode|OCI_PRELIM_AUTH );
   rc = OCISessionBegin ( svchp,  RexxSQLData->DbEnv->errhp, authp, cred, OCI_SYSDBA|OCI_PRELIM_AUTH );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      OCIHandleFree( authp, OCI_HTYPE_SESSION );
      OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
      OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
      return DB_ERROR;
   }
   /*
    * Allocate an admin handle and associate username/password with it
    */
   OCIHandleAlloc( RexxSQLData->DbEnv->envhp, (dvoid *)&adminhp, (ub4) OCI_HTYPE_ADMIN, (size_t) 0, (dvoid **) 0 );
   /*
    * Check for a pfile...
    */
   if ( pfile_len )
   {
      /*
       * Specify a pfile - TODO
       */
   }
   /*
    * Start database in NOMOUNT
    */
   rc = OCIDBStartup( svchp, RexxSQLData->DbEnv->errhp, adminhp, OCI_DEFAULT, 0 );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      OCIHandleFree( authp, OCI_HTYPE_SESSION );
      OCIHandleFree( adminhp, OCI_HTYPE_ADMIN );
      OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
      OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
      return DB_ERROR;
   }
   /*
    * Free our admin handle
    */
   OCIHandleFree( adminhp, OCI_HTYPE_ADMIN );
   /*
    * End our preliminary session
    */
   OCISessionEnd( svchp, RexxSQLData->DbEnv->errhp, authp, OCI_DEFAULT );

   if ( startup >= ORA_STARTUP_MOUNT )
   {
      /*
       * Open our DBA session
       */
      rc = OCISessionBegin ( svchp,  RexxSQLData->DbEnv->errhp, authp, OCI_CRED_RDBMS, mode );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         OCIHandleFree( authp, OCI_HTYPE_SESSION );
         OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
         OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
         return DB_ERROR;
      }
      /*
       * Mount the database
       */
      rc = OCIStmtPrepare2( svchp, &stmthp, RexxSQLData->DbEnv->errhp, mount_stmt, strlen((char *)mount_stmt), 0, 0, OCI_NTV_SYNTAX, OCI_DEFAULT );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         OCIHandleFree( authp, OCI_HTYPE_SESSION );
         OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
         OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
         return DB_ERROR;
      }
      rc = OCIStmtExecute( svchp, stmthp, RexxSQLData->DbEnv->errhp, 1, 0, (OCISnapshot *)NULL, (OCISnapshot *)NULL, OCI_DEFAULT );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         OCIHandleFree( authp, OCI_HTYPE_SESSION );
         OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
         OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
         return DB_ERROR;
      }
      rc = OCIStmtRelease( stmthp, RexxSQLData->DbEnv->errhp, (OraText *)0, 0, OCI_DEFAULT );
      if ( rc != OCI_SUCCESS )
      {
         SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
         OCIHandleFree( authp, OCI_HTYPE_SESSION );
         OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
         OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
         return DB_ERROR;
      }
      if ( startup >= ORA_STARTUP_OPEN )
      {
         /*
          * Open the database
          */
         rc = OCIStmtPrepare2( svchp, &stmthp, RexxSQLData->DbEnv->errhp, open_stmt, strlen((char *)open_stmt), 0, 0, OCI_NTV_SYNTAX, OCI_DEFAULT );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            OCIHandleFree( authp, OCI_HTYPE_SESSION );
            OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
            OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
            return DB_ERROR;
         }
         rc = OCIStmtExecute( svchp, stmthp, RexxSQLData->DbEnv->errhp, 1, 0, (OCISnapshot *)NULL, (OCISnapshot *)NULL, OCI_DEFAULT );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            OCIHandleFree( authp, OCI_HTYPE_SESSION );
            OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
            OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
            return DB_ERROR;
         }
         rc = OCIStmtRelease( stmthp, RexxSQLData->DbEnv->errhp, (OraText *)0, 0, OCI_DEFAULT );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            OCIHandleFree( authp, OCI_HTYPE_SESSION );
            OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
            OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
            return DB_ERROR;
         }
      }
      OCISessionEnd( svchp, RexxSQLData->DbEnv->errhp, authp, OCI_DEFAULT );
   }
   OCIHandleFree( authp, OCI_HTYPE_SESSION );
   OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
   OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
   return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
}

#define ORA_SHUTDOWN_FINAL       3
#define ORA_SHUTDOWN_DISMOUNT    2
#define ORA_SHUTDOWN_CLOSE       1
#define ORA_SHUTDOWN_INITIAL     0
/*-----------------------------------------------------------------------------
 * SYNOPSIS:  ORASHUTDOWN( [username, password[, connect type[, host[, shutdown mode[, shutdown state]]]])
 *
 * RETURNS : 0 success
 *           1 error
 *----------------------------------------------------------------------------*/
rxfunc( RexxORAShutdown )
{
   char   uid[256]="/";
   int    uidlen=1;
   char   pwd[256]="";
   int    pwdlen=0;
   char   host[256]="localhost";
   int    hostlen=9;
   int    rc=0;
   sb4    mode=OCI_SYSDBA;
   ub4    how=OCI_DEFAULT;
   ub4    shutdown=ORA_SHUTDOWN_FINAL;
   text   *dismount_stmt = (text *)"ALTER DATABASE DISMOUNT";
   text   *close_stmt = (text *)"ALTER DATABASE CLOSE";
   char   *myhost;
   ub4    cred;
   OCISession  *authp=NULL;
   OCIStmt     *stmthp=NULL;
   OCIServer   *srvhp=NULL;
   OCISvcCtx   *svchp=NULL;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser,RXPACKAGE_CONSTANT_PREFIX, (char *)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( RexxSQLData->SQLCA_SqlCode ) ClearDBError( RxPackageGlobalData );
   if ( RexxSQLData->SQLCA_IntCode ) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 6 ) )
      return 1;

   /* Allocate a DB environment if none exists! */
   if (RexxSQLData->DbEnv == (DBENV*)NULL)
   {
      if ( ( RexxSQLData->DbEnv = AllocDbEnvironment( RxPackageGlobalData ) ) == (DBENV*)NULL )
         return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory." );
   }
   /*
    * Work out connection string of format:
    * username/password@host[:port][/service name]
    * The portion after the @ is supplied in the host argument
    */
   switch( argc )
   {
      case 6:
         if ( RXSTRLEN(argv[5]) == 0 )
            shutdown = ORA_SHUTDOWN_FINAL;
         else if ( RXSTRLEN(argv[5]) == 8 && memcmpi( RxPackageGlobalData, RXSTRPTR(argv[5]), "DISMOUNT", 8 ) == 0 )
            shutdown = ORA_SHUTDOWN_DISMOUNT;
         else if ( RXSTRLEN(argv[5]) == 5 && memcmpi( RxPackageGlobalData, RXSTRPTR(argv[5]), "CLOSE", 5 ) == 0 )
            shutdown = ORA_SHUTDOWN_CLOSE;
         else if ( RXSTRLEN(argv[5]) == 7 && memcmpi( RxPackageGlobalData, RXSTRPTR(argv[5]), "INITIAL", 7 ) == 0 )
            shutdown = ORA_SHUTDOWN_INITIAL;
         else if ( RXSTRLEN(argv[5]) == 5 && memcmpi( RxPackageGlobalData, RXSTRPTR(argv[5]), "FINAL", 5 ) == 0 )
            shutdown = ORA_SHUTDOWN_FINAL;
         else
         {
            char buf[200];
            sprintf( buf, "invalid value of \"%s\" for parameter 6; value should be one of \"INITIAL\", \"DISMOUNT\", \"CLOSE\", \"FINAL\" or blank\"", RXSTRPTR(argv[5]) );
            return ReturnError( RxPackageGlobalData, retstr, 98, buf );
         }
         /* fall through */
      case 5:
         if ( RXSTRLEN(argv[4]) == 0 ) /* No mode specified; default to default */
            how = OCI_DEFAULT;
         else if ( memcmpi( RxPackageGlobalData, RXSTRPTR(argv[4]), "TRANSACTIONAL", 13 ) == 0 )
            how = OCI_DBSHUTDOWN_TRANSACTIONAL;
         else if ( memcmpi( RxPackageGlobalData, RXSTRPTR(argv[4]), "TRANSACTIONAL_LOCAL", 19 ) == 0 )
            how = OCI_DBSHUTDOWN_TRANSACTIONAL_LOCAL;
         else if ( memcmpi( RxPackageGlobalData, RXSTRPTR(argv[4]), "IMMEDIATE", 9 ) == 0 )
            how = OCI_DBSHUTDOWN_IMMEDIATE;
         else if ( memcmpi( RxPackageGlobalData, RXSTRPTR(argv[4]), "ABORT", 5 ) == 0 )
            how = OCI_DBSHUTDOWN_ABORT;
         else
         {
            char buf[200];
            sprintf( buf, "invalid value of \"%s\" for parameter 5; value should be one of \"ABORT\", \"IMMEDIATE\", \"TRANSACTIONAL\", \"TRANSACTIONAL_LOCAL\" or blank", RXSTRPTR(argv[4]) );
            return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 98, buf ));
         }
         /* fall through */
      case 4:
         RXSTRCPY( host, hostlen, RXSTRPTR(argv[3]), RXSTRLEN(argv[3]) );
         /* fall through */
      case 3:
         if ( ValidateAuthType( RxPackageGlobalData, RXSTRPTR(argv[2]), RXSTRLEN(argv[2]), &mode ) )
         {
            char buf[200];
            sprintf( buf, "invalid value of \"%s\" for parameter 3; value should be one of \"DEFAULT\", \"SYSDBA\", \"SYSOPER\" or blank\"", RXSTRPTR(argv[2]) );
            return ReturnError( RxPackageGlobalData, retstr, 98, buf );
         }
         /* fall through */
      case 2:
         RXSTRCPY( pwd, pwdlen, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]) );
         /* fall through */
      case 1:
         if ( RXSTRLEN(argv[0]) == 0 )
         {
            RXSTRCPY( uid, uidlen, "/", 1 );
         }
         else
         {
            RXSTRCPY( uid, uidlen, RXSTRPTR(argv[0]), RXSTRLEN(argv[0]) );
         }
         break;
   }
   InternalTrace( RxPackageGlobalData, "ORAShutdown", "Host: %s(%d) User: %s(%d) Pass: %s(%d) Mode: %d Status: %d How: %d", host, hostlen, uid, uidlen, pwd, pwdlen, mode, shutdown, how );
   /* server contexts */
   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid **) &srvhp, OCI_HTYPE_SERVER, (size_t) 0, (dvoid **) 0 );
   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid **) &svchp, OCI_HTYPE_SVCCTX, (size_t) 0, (dvoid **) 0 );

   if ( hostlen == 0 )
   {
      myhost = NULL;
   }
   else
      myhost = host;

   rc = OCIServerAttach( srvhp, RexxSQLData->DbEnv->errhp, (text *)myhost, hostlen, 0 );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
      OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
      return DB_ERROR;
   }

   /* set attribute server context in the service context */
   OCIAttrSet( (dvoid *) svchp, OCI_HTYPE_SVCCTX, (dvoid *)srvhp, (ub4) 0, OCI_ATTR_SERVER, (OCIError *) RexxSQLData->DbEnv->errhp );
   OCIHandleAlloc( (dvoid *) RexxSQLData->DbEnv->envhp, (dvoid *)&authp, (ub4) OCI_HTYPE_SESSION, (size_t) 0, (dvoid **) 0 );
   OCIAttrSet( (dvoid *) authp, (ub4) OCI_HTYPE_SESSION, (dvoid *) uid, (ub4) uidlen, (ub4) OCI_ATTR_USERNAME, RexxSQLData->DbEnv->errhp );
   OCIAttrSet( (dvoid *) authp, (ub4) OCI_HTYPE_SESSION, (dvoid *) pwd, (ub4) pwdlen, (ub4) OCI_ATTR_PASSWORD, RexxSQLData->DbEnv->errhp );
   if ( uid[0] == '/'
   &&   uidlen == 1
   &&   mode != OCI_DEFAULT )
      cred = OCI_CRED_EXT;
   else
      cred = OCI_CRED_RDBMS;
   /*
    * Create our session
    */
   rc = OCISessionBegin ( svchp,  RexxSQLData->DbEnv->errhp, authp, cred, mode );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      OCIHandleFree( authp, OCI_HTYPE_SESSION );
      OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
      OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
      return DB_ERROR;
   }

   OCIAttrSet( (dvoid *) svchp, (ub4) OCI_HTYPE_SVCCTX, (dvoid *) authp, (ub4) 0, (ub4) OCI_ATTR_SESSION, RexxSQLData->DbEnv->errhp );

   /*
    * Shutdown database in NOMOUNT
    */
   rc = OCIDBShutdown( svchp, RexxSQLData->DbEnv->errhp, 0, how );
   if ( rc != OCI_SUCCESS )
   {
      SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
      OCIHandleFree( authp, OCI_HTYPE_SESSION );
      OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
      OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
      return DB_ERROR;
   }
   if ( mode != OCI_DBSHUTDOWN_ABORT )
   {
      if ( shutdown >= ORA_SHUTDOWN_CLOSE )
      {
         /*
          * Close the database
          */
         rc = OCIStmtPrepare2( svchp, &stmthp, RexxSQLData->DbEnv->errhp, close_stmt, strlen((char *)close_stmt), 0, 0, OCI_NTV_SYNTAX, OCI_DEFAULT );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            OCIHandleFree( authp, OCI_HTYPE_SESSION );
            OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
            OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
            return DB_ERROR;
         }
         rc = OCIStmtExecute( svchp, stmthp, RexxSQLData->DbEnv->errhp, 1, 0, (OCISnapshot *)NULL, (OCISnapshot *)NULL, OCI_DEFAULT );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            OCIHandleFree( authp, OCI_HTYPE_SESSION );
            OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
            OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
            return DB_ERROR;
         }
         rc = OCIStmtRelease( stmthp, RexxSQLData->DbEnv->errhp, (OraText *)0, 0, OCI_DEFAULT );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            OCIHandleFree( authp, OCI_HTYPE_SESSION );
            OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
            OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
            return DB_ERROR;
         }
         if ( shutdown >= ORA_SHUTDOWN_DISMOUNT )
         {
            /*
             * Dismount the database
             */
            rc = OCIStmtPrepare2( svchp, &stmthp, RexxSQLData->DbEnv->errhp, dismount_stmt, strlen((char *)dismount_stmt), 0, 0, OCI_NTV_SYNTAX, OCI_DEFAULT );
            if ( rc != OCI_SUCCESS )
            {
               SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
               OCIHandleFree( authp, OCI_HTYPE_SESSION );
               OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
               OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
               return DB_ERROR;
            }
            rc = OCIStmtExecute( svchp, stmthp, RexxSQLData->DbEnv->errhp, 1, 0, (OCISnapshot *)NULL, (OCISnapshot *)NULL, OCI_DEFAULT );
            if ( rc != OCI_SUCCESS )
            {
               SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
               OCIHandleFree( authp, OCI_HTYPE_SESSION );
               OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
               OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
               return DB_ERROR;
            }
            rc = OCIStmtRelease( stmthp, RexxSQLData->DbEnv->errhp, (OraText *)0, 0, OCI_DEFAULT );
            if ( rc != OCI_SUCCESS )
            {
               SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
               OCIHandleFree( authp, OCI_HTYPE_SESSION );
               OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
               OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
               return DB_ERROR;
            }
         }
         /*
          * Final shutdown
          */
         rc = OCIDBShutdown( svchp, RexxSQLData->DbEnv->errhp, 0, OCI_DBSHUTDOWN_FINAL );
         if ( rc != OCI_SUCCESS )
         {
            SetDBError( RxPackageGlobalData, __FILE__, __LINE__, RexxSQLData->DbEnv->errhp, NULL );
            OCIHandleFree( authp, OCI_HTYPE_SESSION );
            OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
            OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
            return DB_ERROR;
         }
      }
   }

   OCISessionEnd( svchp, RexxSQLData->DbEnv->errhp, authp, OCI_DEFAULT );
   OCIHandleFree( authp, OCI_HTYPE_SESSION );
   OCIHandleFree( srvhp, OCI_HTYPE_SERVER );
   OCIHandleFree( svchp, OCI_HTYPE_SVCCTX );
   return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
}

#include "rxsqlinc2.h"
