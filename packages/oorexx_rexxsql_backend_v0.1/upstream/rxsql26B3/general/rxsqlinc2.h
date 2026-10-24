/*
 * rxsqlinc.h - common routines for Rexx/SQL
 *
 *
 * REXX/SQL. A Rexx interface to SQL databases.
 * Copyright Mark Hessling, 1996-2002.
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

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLCOMMIT( )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLCOMMIT )
{
   return( SQLTRANSACT( name, argc, argv, stck, retstr, SQL_COMMIT ) );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLROLLBACK( )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLROLLBACK )
{
   return( SQLTRANSACT( name, argc, argv, stck, retstr, SQL_ROLLBACK ) );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLOPEN(statement-name [, <bind-args>])
 *
 * RETURNS :  0-success,
 *           >0-number of rows affected for SQLEXECUTE(),
 *           <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLOPEN )
{
   return(SQLEXEC(name, argc, argv, stck, retstr,1));
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLEXECUTE(statement-name [, <bind-args>])
 *
 * RETURNS :  0-success,
 *           >0-number of rows affected for SQLEXECUTE(),
 *           <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLEXECUTE )
{
   return( SQLEXEC( name, argc, argv, stck, retstr, 0 ) );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLVARIABLE( variable_name [,variable_value] )
 *
 * ARGUMENTS:
 *            0 - variable_name
 *            1 - variable_value (if supplied, this is the new value)
 *
 * RETURNS :  Current value of "variable_name" or <0-error.
 *----------------------------------------------------------------------------*/
rxfunc( SQLVARIABLE )
{
   char        opt_name[MAX_IDENTIFIER+1];
   SQLVAL      *opt=NULL;
   char        tmp[128];
   int         rc=0;
   RXSTRING    *rxs=NULL;
   ULONG       new_num=0L;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser, RXPACKAGE_CONSTANT_PREFIX, (char*)name, argc, argv);

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if (RexxSQLData->SQLCA_SqlCode) ClearDBError( RxPackageGlobalData );
   if (RexxSQLData->SQLCA_IntCode) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 1, 2 ) )
      return 1;

   if ( RXSTRLEN(argv[0]) == 0 )
      return ReturnError( RxPackageGlobalData, retstr, 19, "null (\"\") variable name." );

   /*
    * Get the name of the variable
    */
   if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], opt_name, sizeof(opt_name) ) ) != 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);

   /*
    * Make sure the option is a valid one!
    */
   if ( ( opt = ll_find( RxPackageGlobalData, RexxSQLData->opt_tbl, opt_name ) ) == (SQLVAL*)NULL )
   {
      (void)sprintf(tmp,"unknown variable \"%s\".", opt_name);
      return ReturnError( RxPackageGlobalData, retstr, 11, tmp );
   }
   /*
    * If the option is to set debugging level, we need to do more than
    * set a variable!
    */
   if (opt->valtype == SQLVAL_DEBUG)
   {
      if (argc == 1)
         return RxReturnNumber( RxPackageGlobalData,  retstr, RxGetRunFlags( RxPackageGlobalData ) );
      else
      {
         if ( RxStrToULong( RxPackageGlobalData, &argv[1], &new_num ) )
            return ReturnError( RxPackageGlobalData, retstr, 7, "value is not a valid integer." );
         RxSetRunFlags( RxPackageGlobalData, new_num );
         return RxReturnNumber( RxPackageGlobalData, retstr, 0 );
      }
   }

   /*
    * If the option is to set debug trace file, we need to do more than
    * set a variable!
    */
   if (opt->valtype == SQLVAL_DEBUGFILE)
   {
      if (argc == 1)
         return RxReturnString( RxPackageGlobalData, retstr, RxGetTraceFile( RxPackageGlobalData ) );
      else
      {
         if ( RXSTRLEN(argv[1]) > MAX_PATH )
         {
            sprintf(tmp,"identifier is too long; max length is %d",MAX_IDENTIFIER);
            return ReturnError( RxPackageGlobalData, retstr, 6, tmp );
         }
         rc = RxSetTraceFile( RxPackageGlobalData, RXSTRPTR(argv[1]) );
         return RxReturnNumber( RxPackageGlobalData, retstr, rc);
      }
   }

   if (argc == 1)
   {
      if (opt->dtype == TYPE_INT
      ||  opt->dtype == TYPE_BOOL)
         return RxReturnNumber( RxPackageGlobalData, retstr, *(ULONG*)(opt->value));
      else
         return RxReturnString( RxPackageGlobalData, retstr, ((RXSTRING*)(opt->value))->strptr);
   }

   /*
    * Must be updateable by user
    */
   if (!opt->user_update)
   {
      (void)sprintf(tmp, "variable \"%s\" is not settable.", opt_name);
      return ReturnError( RxPackageGlobalData, retstr, 12, tmp );
   }

   /*
    * Set the value of the option
    */
   switch(opt->dtype)
   {
      case TYPE_INT:
         if ( RxStrToULong( RxPackageGlobalData, &argv[1], &new_num ) )
            return ReturnError( RxPackageGlobalData, retstr, 7, "value is not a valid integer." );
         memcpy((ULONG*)opt->value,&new_num,sizeof(ULONG));
         break;
      case TYPE_BOOL:
         if ( RxStrToBool( RxPackageGlobalData, &argv[1], &new_num ) )
            return ReturnError( RxPackageGlobalData, retstr, 97, "value is not a valid boolean." );
         memcpy((ULONG*)opt->value,&new_num,sizeof(ULONG));
         break;
      case TYPE_STRING:
         if (RXSTRLEN(argv[1]) > MAX_IDENTIFIER)
         {
            sprintf(tmp,"identifier is too long; max length is %d",MAX_IDENTIFIER);
            return ReturnError( RxPackageGlobalData, retstr, 6, tmp );
         }
         rxs = (RXSTRING*)opt->value;
         RXSTRCPY(rxs->strptr,rxs->strlength,RXSTRPTR(argv[1]),RXSTRLEN(argv[1]));
         break;
      case TYPE_ARRAY:
         break;
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, 0 );
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLGETINFO( [connection_name],  variable_name [, stem_name)
 *
 * ARGUMENTS:
 *            0 - connection_name (optional)
 *            1 - variable_name
 *            2 - stem_name (optional)
 *
 * RETURNS :  0-success, <0-error if argument 3 supplied
 *            or Current value of "variable_name" if argument 3 NOT supplied
 *----------------------------------------------------------------------------*/
rxfunc( SQLGETINFO )
{
   char     opt_name[MAX_IDENTIFIER+1];
   SQLVAL   *opt=NULL;
   char     tmp[128];
   int      rc=0,num_vars=0,i=0,len=0;
   RXSTRING *rxs=NULL;
   RXSTRING_DT *rxs_dt=NULL;
   DBCON    *db=NULL;
   char     varname[MAX_IDENTIFIER+1+10];
   char     dbname[MAX_IDENTIFIER+1];
   char     stem_name[MAX_IDENTIFIER+2];
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser, RXPACKAGE_CONSTANT_PREFIX, (char*)name, argc, argv);

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if (RexxSQLData->SQLCA_SqlCode) ClearDBError( RxPackageGlobalData );
   if (RexxSQLData->SQLCA_IntCode) ClearIntError( RxPackageGlobalData );

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 2, 3 ) )
      return 1;

   if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[1], opt_name, sizeof(opt_name) ) ) != 0 )
      return RxReturnNumber( RxPackageGlobalData, retstr, (long)rc);
   if ( argc == 3 )
   {
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[2], stem_name, sizeof(stem_name) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc);
      /*
       * If the stem name does NOT contain a trailing '.', append one.
       */
      if ( stem_name[strlen(stem_name)-1] != '.' )
         strcat( stem_name, "." );
   }
   /*
    * Find the variable in the connection table...
    */
   if ( RexxSQLData->DbEnv == (DBENV*)NULL )
   {
      return ReturnError( RxPackageGlobalData, retstr, 22, "no connections open." );
   }
   if ( RXSTRLEN(argv[0]) )
   {
      /*
       * We have a named connection, get it...
       */
      if ( ( rc = MkIdentifier( RxPackageGlobalData, argv[0], dbname, sizeof(dbname) ) ) != 0 )
         return RxReturnNumber( RxPackageGlobalData, retstr, rc);
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
      if ( RexxSQLData->DbEnv->current_connection )
         db = RexxSQLData->DbEnv->current_connection;
      else
         return ReturnError( RxPackageGlobalData, retstr, 25, "no connection is current" );
      strcpy( dbname, db->name );
   }
   /*
    * Make sure the option is a valid one!
    */
   if ( ( opt = ll_find( RxPackageGlobalData, db->db_opt, opt_name ) ) == (SQLVAL*)NULL )
   {
      (void)sprintf( tmp, "unknown variable \"%s\".", opt_name );
      return ReturnError( RxPackageGlobalData, retstr, 11, tmp );
   }
   /*
    * If caller requires return as a string, get the variable's values
    * and return it.
    */
   if ( argc == 2 )
   {
      switch( opt->dtype )
      {
         case TYPE_INT:
         case TYPE_BOOL:
            return RxReturnNumber( RxPackageGlobalData, retstr, *(ULONG*)(opt->value));
            break;
         case TYPE_STRING:
            return RxReturnString( RxPackageGlobalData, retstr,((RXSTRING*)(opt->value))->strptr);
            break;
         case TYPE_ARRAY:
            rxs =(RXSTRING*)(opt->value);
            for ( len = 0, i = 0; rxs[i].strlength; i++, len+=(rxs[i].strlength)+1 );
            if (len > 256)
            {
               if ( ( retstr->strptr = (RXSTRING_STRPTR_TYPE)MALLOC_TSD( RxPackageGlobalData, len ) ) == NULL )
                  return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );
            }
            len = 0;
            for ( i = 0; rxs[i].strlength; i++ )
            {
               memcpy( retstr->strptr+len, rxs[i].strptr, rxs[i].strlength );
               len += rxs[i].strlength;
               memcpy( retstr->strptr+len, " ", 1 );
               len++;
            }
            len--;
            retstr->strptr[len] = '\0';
            retstr->strlength = len;
            return (0);
            break;
         case TYPE_DATATYPE:
            len = 0;
            rxs_dt = (RXSTRING_DT*)(opt->value);
            if ( rxs_dt != NULL )
            {
               for ( len = 0, i = 0; rxs_dt[i].strlength; i++, len+=(rxs_dt[i].strlength)+1 );
               if ( len > 256 )
               {
                  if ( ( retstr->strptr = (RXSTRING_STRPTR_TYPE)MALLOC_TSD( RxPackageGlobalData, len ) ) == NULL )
                     return ReturnError( RxPackageGlobalData, retstr, 10, "out of memory" );
               }
               len = 0;
               for ( i = 0; rxs_dt[i].strlength; i++ )
               {
                  memcpy( retstr->strptr+len, rxs_dt[i].strptr, rxs_dt[i].strlength );
                  len += rxs_dt[i].strlength;
                  memcpy( retstr->strptr+len, " ", 1 );
                  len++;
               }
               len--;
            }
            retstr->strptr[len] = '\0';
            retstr->strlength = len;
            return (0);
            break;
      }
   }
   /*
    * To reach here the caller supplied a stem name. Use it to generate
    * a REXX array.
    */
   switch(opt->dtype)
   {
      case TYPE_INT:
      case TYPE_BOOL:
         (void)sprintf(varname, "%s%u", stem_name, 1);
         sprintf(tmp,"%lu",*(ULONG*)(opt->value));
         num_vars = 1;
         rc = SetRexxVariable( RxPackageGlobalData, varname, strlen(varname), tmp, strlen(tmp));
         break;
      case TYPE_STRING:
         (void)sprintf(varname, "%s%u", stem_name, 1);
         num_vars = 1;
         rc = SetRexxVariable( RxPackageGlobalData, varname, strlen(varname),
                       ((RXSTRING*)(opt->value))->strptr,
                       (size_t)(((RXSTRING*)(opt->value))->strlength));
         break;
      case TYPE_ARRAY:
         rxs =(RXSTRING*)(opt->value);
         for (i=0;;i++)
         {
            if (rxs[i].strlength == 0)
               break;
            (void)sprintf(varname, "%s%u", stem_name, i+1);
            rc = SetRexxVariable( RxPackageGlobalData, varname, strlen(varname), rxs[i].strptr,rxs[i].strlength);
         }
         num_vars = i;
         break;
      case TYPE_DATATYPE:
         rxs_dt =(RXSTRING_DT*)(opt->value);
         if (rxs_dt)
         {
            for (i=0;;i++)
            {
               if (rxs_dt[i].strlength == 0)
                  break;
               (void)sprintf(varname, "%s%u", stem_name, i+1);
               rc = SetRexxVariable( RxPackageGlobalData, varname, strlen(varname), rxs_dt[i].strptr,rxs_dt[i].strlength);
            }
         }
         else
         {
            i = 1;
            (void)sprintf(varname, "%s%u", stem_name, i);
            rc = SetRexxVariable( RxPackageGlobalData, varname, strlen(varname), "*** not supported ***",21);
         }
         num_vars = i;
         break;
   }
   if (!rc)
   {
      (void)sprintf(varname, "%s0", stem_name);
      sprintf(tmp,"%u",num_vars);
      rc = SetRexxVariable( RxPackageGlobalData, varname, strlen(varname), tmp, strlen(tmp));
   }

   return RxReturnNumber( RxPackageGlobalData, retstr, rc);
}

/*-----------------------------------------------------------------------------
 * Declare the initiating and terminating functions when used as a dynamic lib
 *----------------------------------------------------------------------------*/

/*
 * SYNOPSIS: SQLLOADFUNCS();
 */
rxfunc( SQLLOADFUNCS )
{
   int rc=0;

   /*
    * Get thread-safe-data for DLL. EXE global data is not thread-safe
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = GLOBAL_ENTRY_POINT();
   InitRxPackage( RxPackageGlobalData, RexxSQLInitialiser, RXPACKAGE_CONSTANT_PREFIX, &rc );
   if ( !QueryRxFunction( RxPackageGlobalData, NAME_SQLCONNECT_EXT ) )
   {
      /*
       * Register all external functions
       */
      if ( !rc )
      {
         rc = RegisterRxFunctions( RxPackageGlobalData, RexxSQLFunctions, RxPackageName );
      }
   }
   return RxReturnNumber( RxPackageGlobalData,  retstr, rc );
}

/*
 * SYNOPSIS: SQLDROPFUNCS(["UNLOAD"]);
 */
rxfunc( SQLDROPFUNCS )
{
   int rc=0;
   int unload=0;
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser, RXPACKAGE_CONSTANT_PREFIX, (char*)name, argc, argv );

   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   if ( my_checkparam( RxPackageGlobalData, (char *)name, argc, 0, 1 ) )
      return( 1 );
   if ( argv[0].strlength == 6
   &&   memcmpi( RxPackageGlobalData, argv[0].strptr, "UNLOAD", 6 ) == 0 )
      unload = 1;
   (void)TermRxPackage( RxPackageGlobalData, RexxSQLTerminator, RexxSQLFunctions, RxPackageName, unload );
   return RxReturnNumber( NULL, retstr, rc );
}

/*-----------------------------------------------------------------------------
 * Set up the Version String
 *----------------------------------------------------------------------------*/
static void *SQLValSetVersion( RxPackageGlobalDataDef *RxPackageGlobalData, void *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SQLValSetVersion", "%x", db );
   sprintf( RexxSQLData->RexxSqlVersionString, "%s %s %s %s %s",
                                               RxPackageName,
                                               REXXSQL_VERSION,
                                               REXXSQL_DATE,
                                               CURRENT_OS,
                                               CURRENT_DB);
   MAKERXSTRING( RexxSQLData->RexxSqlVersion, RexxSQLData->RexxSqlVersionString, (ULONG)strlen(RexxSQLData->RexxSqlVersionString) );
   return((void*)&RexxSQLData->RexxSqlVersion);
}

/*-----------------------------------------------------------------------------
 * Set up the string representing a NULL value
 *----------------------------------------------------------------------------*/
static void *SQLValSetDebugFile( RxPackageGlobalDataDef *RxPackageGlobalData, void *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SQLValSetDebugFile", "%x", db );

   strcpy( RexxSQLData->DebugFile, DEBUGFILE );
   MAKERXSTRING( RexxSQLData->RXSDebugFile, RexxSQLData->DebugFile, (ULONG)strlen( RexxSQLData->DebugFile ) );
   return( (void*)&RexxSQLData->RXSDebugFile );
}

/*-----------------------------------------------------------------------------
 * Set up the string representing a NULL value
 *----------------------------------------------------------------------------*/
static void *SQLValSetNullStringIn( RxPackageGlobalDataDef *RxPackageGlobalData, void *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SQLValSetNullStringIn", "%x", db );

   strcpy( RexxSQLData->NullStringIn, NULLSTRINGIN );
   MAKERXSTRING( RexxSQLData->RXSNullStringIn, RexxSQLData->NullStringIn, (ULONG)strlen( RexxSQLData->NullStringIn ) );
   return( (void*)&RexxSQLData->RXSNullStringIn );
}

/*-----------------------------------------------------------------------------
 * Set up the string representing a NULL value
 *----------------------------------------------------------------------------*/
static void *SQLValSetNullStringOut( RxPackageGlobalDataDef *RxPackageGlobalData, void *db )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SQLValSetNullStringOut", "%x", db );

   strcpy( RexxSQLData->NullStringOut, NULLSTRINGOUT );
   MAKERXSTRING( RexxSQLData->RXSNullStringOut, RexxSQLData->NullStringOut, (ULONG)strlen( RexxSQLData->NullStringOut ) );
   return( (void*)&RexxSQLData->RXSNullStringOut);
}

/*-----------------------------------------------------------------------------
 * Install all REXX/SQL variable structures.
 *----------------------------------------------------------------------------*/
void *GetSqlVariableValue( RxPackageGlobalDataDef *RxPackageGlobalData, int type, void *idb )
{
   void *result=NULL;
   DBCON *db=idb;

   InternalTrace( RxPackageGlobalData, "GetSqlVariableValue", "%d,%x", type, idb );

   switch (type)
   {
      case SQLVAL_DEBUGFILE:
         result = SQLValSetDebugFile( RxPackageGlobalData, NULL );
         break;
      case SQLVAL_NULLSTRINGIN:
         result = SQLValSetNullStringIn( RxPackageGlobalData, NULL );
         break;
      case SQLVAL_NULLSTRINGOUT:
         result = SQLValSetNullStringOut( RxPackageGlobalData, NULL );
         break;
      case SQLVAL_VERSION:
         result = SQLValSetVersion( RxPackageGlobalData, NULL );
         break;
      case SQLVAL_SUPPORTSTRANSACTIONS:
         result = SQLValSetSupportsTransactions( RxPackageGlobalData, db );
         break;
      case SQLVAL_SUPPORTSTHREADS:
         result = SQLValSetSupportsThreads( RxPackageGlobalData, db );
         break;
      case SQLVAL_SUPPORTSSQLGETDATA:
         result = SQLValSetSupportsSqlGetData( RxPackageGlobalData, db );
         break;
      case SQLVAL_DESCRIBECOLUMNS:
         result = SQLValSetDescribeColumns( RxPackageGlobalData, db );
         break;
      case SQLVAL_DATATYPES:
         result = SQLValSetDatatypes( RxPackageGlobalData, db );
         break;
      case SQLVAL_DBMSNAME:
         result = SQLValSetDBMSName( RxPackageGlobalData, db );
         break;
      case SQLVAL_DBMSVERSION:
         result = SQLValSetDBMSVer( RxPackageGlobalData, db );
         break;
      case SQLVAL_ROWLIMIT:
         result = SQLValSetRowLimit( RxPackageGlobalData, db );
         break;
      case SQLVAL_LONGLIMIT:
         result = SQLValSetLongLimit( RxPackageGlobalData, db );
         break;
      case SQLVAL_SAVESQL:
         result = SQLValSetSaveSQL( RxPackageGlobalData, db );
         break;
      case SQLVAL_AUTOCOMMIT:
         result = SQLValSetAutoCommit( RxPackageGlobalData, db );
         break;
      case SQLVAL_IGNORETRUNCATE:
         result = SQLValSetIgnoreTruncate( RxPackageGlobalData, db );
         break;
      case SQLVAL_STANDARDPLACEMARKERS:
         result = SQLValSetStandardPlacemarkers( RxPackageGlobalData, db );
         break;
      case SQLVAL_SUPPORTSDMLROWCOUNT:
         result = SQLValSetSupportsDMLRowcount( RxPackageGlobalData, db );
         break;
      case SQLVAL_SUPPORTSPLACEMARKERS:
         result = SQLValSetSupportsPlacemarkers( RxPackageGlobalData, db );
         break;
      default:
         InternalTrace( RxPackageGlobalData, "GetSqlVariableValue: Unknown type:", "%d", type );
         break;
   }
   return (result);
}

/*-----------------------------------------------------------------------------
 * Install all REXX/SQL variable structures.
 *----------------------------------------------------------------------------*/
int InstallSQLVariables( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   int     rc=0,i=0;
   SQLVAL  *curr=NULL;
   void    *result=NULL;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "InstallSQLVariables", NULL );

   for ( i = 0; strlen( sqlvariable_vars[i].name ) != 0; i++ )
   {
      result = GetSqlVariableValue( RxPackageGlobalData, sqlvariable_vars[i].valtype, NULL );
      if ((curr = InstallSQLVariable( RxPackageGlobalData,
                &rc,
                sqlvariable_vars[i].name,
                RexxSQLData->opt_tbl,
                sqlvariable_vars[i].user_update,
                sqlvariable_vars[i].dtype,
                sqlvariable_vars[i].option,
                result,
                sqlvariable_vars[i].valtype)) == NULL)
         return(rc);
      /*
       * If this is the first item added, set the pointer to our head.
       */
      if ( RexxSQLData->opt_tbl == NULL )
         RexxSQLData->opt_tbl = curr;
   }
   return (0);
}

/*-----------------------------------------------------------------------------
 * Validates datatype string
 *----------------------------------------------------------------------------*/
static int ValidateDataType( RxPackageGlobalDataDef *RxPackageGlobalData, char *buf, int len, DBCON *db )
{
   int         i=0;
   SQLVAL      *opt=NULL;
   RXSTRING_DT *rxs_dt=NULL;

   InternalTrace( RxPackageGlobalData, "ValidateDatatype", "%s,%d,%x", buf, len, db );

   /*
    * Find the internal datatype represenation for the supplied
    * datatype string. If not found, return -1.
    */
   if ( ( opt = ll_find( RxPackageGlobalData, db->db_opt, "DATATYPES" ) ) == (SQLVAL*)NULL )
      return (RXSQL_INVALID_DATATYPE);
   rxs_dt =(RXSTRING_DT*)(opt->value);
   for ( i = 0; rxs_dt[i].strlength; i++ )
   {
    if (len == rxs_dt[i].strlength
    &&  memcmpi ( RxPackageGlobalData, rxs_dt[i].strptr, buf, len ) == 0 )
       return(rxs_dt[i].internal);
   }
   return(RXSQL_INVALID_DATATYPE);
}

/***********************************************************************/
RSH_RETURN_TYPE PackageSubcomHandler

#if defined(HAVE_PROTO)
   (
   RSH_ARG0_TYPE Command,    /* Command string passed from the caller    */
   RSH_ARG1_TYPE Flags,      /* pointer to short for return of flags     */
   RSH_ARG2_TYPE Retstr)     /* pointer to RXSTRING for RC return        */
#else
   ( Command, Flags, Retstr )
   RSH_ARG0_TYPE Command;    /* Command string passed from the caller    */
   RSH_ARG1_TYPE Flags;      /* pointer to short for return of flags     */
   RSH_ARG2_TYPE Retstr;     /* pointer to RXSTRING for RC return        */
#endif
/***********************************************************************/
{
   REXXSQLDATA *RexxSQLData;
   /*
    * Get thread-safe-data
    */
   RxPackageGlobalDataDef *RxPackageGlobalData = __rxpack_get_tsd();
   RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;
   /*
    * Leave the Flags variable alone indicating we want to
    * use the default subcommand handler.
    */
   *Flags = *Flags;
   return 0;
}

/*
 * These functions used by loader.c to obtain package-specific info
 */
int RexxSQLInitialiser( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   int rc=0L;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   RexxSQLData->RowLimit= 0L ;
   RexxSQLData->LongLimit = DEFAULT_LONG_LIMIT;
   RexxSQLData->SaveSQL = TRUE;
   RexxSQLData->AutoCommit = FALSE;
   RexxSQLData->IgnoreTruncate = FALSE;
   RexxSQLData->StandardPlacemarkers = FALSE;
   RexxSQLData->SupportsTransactions = SUPPORTSTRANSACTIONS;
   RexxSQLData->SupportsPlacemarkers = SUPPORTSPLACEMARKERS;
   RexxSQLData->SupportsDMLRowcount  = SUPPORTSDMLROWCOUNT;
   RexxSQLData->SupportsSqlGetData   = SUPPORTSSQLGETDATA;
   RexxSQLData->SupportsThreads = SUPPORTSTHREADS;
   RexxSQLData->SQLCA_SqlCode = (-1L);
   RexxSQLData->SQLCA_RowCount = (-1L);
   RexxSQLData->SQLCA_IntCode = (-1L);
   RexxSQLData->column_attribute = col_attribute;
#ifdef NEED_RXSQL_HENV
   RexxSQLData->henv = 0L;
#endif

   InternalTrace( RxPackageGlobalData, "InitRexxSQL", NULL );

   /*
    * Install REXX/SQL variable descriptors
    */
   if ( ( rc = InstallSQLVariables( RxPackageGlobalData ) ) != 0 )
       return(rc);

   /*
    * Call any database-specific initialisation function here
    */
   if ( ( rc = DBInitialise( RxPackageGlobalData ) ) != 0 )
      return(rc);

   return 0;
}

int RexxSQLTerminator( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   int rc=0;
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   RxPackageGlobalData = FunctionPrologue( RxPackageGlobalData, RexxSQLInitialiser, RXPACKAGE_CONSTANT_PREFIX, "TerminateRexxSQL", 0L, NULL);

   /* Release the REXX/SQL environment. */
   if ( ( rc = ReleaseDbEnvironment( RxPackageGlobalData ) ) != 0 )
      return (int)FunctionEpilogue( RxPackageGlobalData, "TerminateRexxSQL", (long)rc );

   if ( RexxSQLData->opt_tbl )
      RexxSQLData->opt_tbl = ll_free( RxPackageGlobalData, RexxSQLData->opt_tbl );

   DBTerminate( RxPackageGlobalData);
#if 0
   if ( RxPackageGlobalData
   &&   RxPackageGlobalData->MTExit )
        (*RxPackageGlobalData->MTExit)( 0 );
#endif

   return (int)FunctionEpilogue( RxPackageGlobalData, "TerminateRexxSQL", (long)0 );
}

/*
 * Every package MUST have one of these, otherwise ooRexx will crash
 */
LONG APIENTRY RexxSQLInitHandler( LONG ExitNum, LONG Subfun, PEXIT PBlock )
{
/*   SetPackageConstants( rexxdwData.RxPackageGlobalData, RexxSQLConstants, "REXXSQL", 0 ); */
   return 0L;
}

RexxSubcomHandler *getRexxSQLSubcomHandler( void )
{
   return NULL;
}

RexxExitHandler *getRexxSQLInitHandler( void )
{
   return RexxSQLInitHandler;
}

RexxFunction *getRexxSQLFunctions( void )
{
   return RexxSQLFunctions;
}

RxPackageConstantDef *getRexxDQConstants( void )
{
   return NULL;
}

PackageInitialiser *getRexxSQLInitialiser( void )
{
   return RexxSQLInitialiser;
}

PackageTerminator *getRexxSQLTerminator( void )
{
   return RexxSQLTerminator;
}

#if !defined(HAVE_STRERROR)
/*
 * This function and the following description borrowed from Regina 0.08a
 *
 * Sigh! This must probably be done this way, although it's incredibly
 * backwards. Some versions of gcc comes with a complete set of ANSI C
 * include files, which contains the definition of strerror(). However,
 * that function does not exist in the default libraries of SunOS.
 * To circumvent that problem, strerror() is #define'd to get_sys_errlist()
 * in config.h, and here follows the definition of that function.
 * Originally, strerror() was #defined to sys_errlist[x], but that does
 * not work if string.h contains a declaration of the (non-existing)
 * function strerror().
 *
 * So, this is a mismatch between the include files and the library, and
 * it should not create problems for Regina. However, the _user_ will not
 * encounter any problems until he compiles Regina, so we'll have to
 * clean up after a buggy installation of the C compiler!
 */
char *rxsql_get_sys_errlist( int num )
{
   extern char *sys_errlist[] ;
   return sys_errlist[num] ;
}
#endif

#if !defined(REXXSQL_IGNORE_SELECTSTATEMENT)
/*-----------------------------------------------------------------------------
 * Parse the supplied statement and return 1 if the first word of the
 * statement is "select" (any case) or 0 otherwise.
 *----------------------------------------------------------------------------*/
static int SelectStatement( RxPackageGlobalDataDef *RxPackageGlobalData, char *stmt, long len )
{
   char buf[7];
   char *p=stmt;
   int i=0;

   InternalTrace( RxPackageGlobalData, "SelectStatement", "%s,%d", stmt, len );
   /* Remove leading whitespace */
   while (len && isspace(*p))
   {
      p++;
      len--;
   }
   if (len<6L)
      return(0);
   buf[6] = '\0';

   for(i=0;i<6;i++)
   {
      buf[i] = (islower(*p)) ? toupper(*p) : *p;
      p++;
   }
   if (strcmp(buf,"SELECT") == 0)
      return(1);
   return(0);
}
#endif

/*-----------------------------------------------------------------------------
 * Store the error message for INTERNAL errors in SQLCA.SQLTEXT variable.
 *----------------------------------------------------------------------------*/
static int SetIntError( RxPackageGlobalDataDef *RxPackageGlobalData, char *fn, int lineno, int errcode, char *errmsg )
{
   char  msg[MAX_ERROR_TEXT];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetIntError", "%s,%d,%d,%s", fn, lineno, errcode, errmsg );

   RexxSQLData->SQLCA_IntCode = -errcode;

   /*
    * Set SQLCA.INTERRM variable
    */
   if ( RxGetRunFlags( RxPackageGlobalData ) == 10 )
      (void)sprintf(msg, "REXX/SQL-%02d: %s [%s:%d]", errcode, errmsg, fn, lineno);
   else
      (void)sprintf(msg, "REXX/SQL-%02d: %s", errcode, errmsg);
   (void)SetRexxVariable( RxPackageGlobalData, SQLCA_INTERRM, strlen(SQLCA_INTERRM),msg, strlen(msg));

   /*
    * Set SQLCA.INTCODE variable
    */
   (void)sprintf(msg, "%ld", RexxSQLData->SQLCA_IntCode);
   (void)SetRexxVariable( RxPackageGlobalData, SQLCA_INTCODE, strlen(SQLCA_INTCODE),msg, strlen(msg));

   return(RexxSQLData->SQLCA_IntCode);
}

/*-----------------------------------------------------------------------------
 * Set elements of the compound variable "SQLCA.".  SQLCA. holds the results of
 * any call to REXXSQL. It should never be set by the REXX program!
 *----------------------------------------------------------------------------*/
static void SetSQLCA( RxPackageGlobalDataDef *RxPackageGlobalData, RXSQL_SQLCODE_TYPE sqlcode, RXSQL_SQLSTATE_TYPE *sqlstate, RXSQL_SQLERRM_TYPE *errm, char *txt )
{
   char    buf[50];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetSQLCA", "%d,%s,%s,%s", sqlcode, sqlstate, errm, txt );

   RexxSQLData->SQLCA_SqlCode = sqlcode;
   strcpy( RexxSQLData->SQLCA_SqlState, sqlstate );

   (void)sprintf(buf, "%ld", sqlcode);
   (void)SetRexxVariable( RxPackageGlobalData, SQLCA_SQLCODE,  strlen(SQLCA_SQLCODE),buf, strlen(buf));
   (void)SetRexxVariable( RxPackageGlobalData, SQLCA_SQLERRM,  strlen(SQLCA_SQLERRM),errm, strlen(errm));
   (void)SetRexxVariable( RxPackageGlobalData, SQLCA_SQLTEXT,  strlen(SQLCA_SQLTEXT),txt, strlen(txt));
   (void)SetRexxVariable( RxPackageGlobalData, SQLCA_SQLSTATE, strlen(SQLCA_SQLSTATE),sqlstate, strlen(sqlstate));

   if (!(sqlcode==0 && strcmp(sqlstate,"")==0 && strcmp(errm,"")==0))
   {
      (void)SetRexxVariable( RxPackageGlobalData, SQLCA_INTCODE, strlen(SQLCA_INTCODE),"-1", 2);
      (void)sprintf(buf, "REXX/SQL-1: Database Error");
      (void)SetRexxVariable( RxPackageGlobalData, SQLCA_INTERRM, strlen(SQLCA_INTERRM),buf, strlen(buf));
   }
   return;
}

/*-----------------------------------------------------------------------------
 * Set RowCount and put into REXX "SQLCA.ROWCOUNT" compound variable.
 *----------------------------------------------------------------------------*/
static void SetRowCount( RxPackageGlobalDataDef *RxPackageGlobalData, RXSQL_ROWCOUNT_TYPE rowcount )
{
   char    buf[50];
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "SetRowCount", "%lu", rowcount );

   if ( RexxSQLData->SQLCA_RowCount != rowcount )
   {
      RexxSQLData->SQLCA_RowCount = rowcount;
      (void)sprintf( buf, "%lu", rowcount );
      (void)SetRexxVariable( RxPackageGlobalData, SQLCA_ROWCOUNT, strlen(SQLCA_ROWCOUNT), buf, strlen(buf) );
   }
   return;
}

#if defined(USES_COMPUTE_COUNT)
/*-----------------------------------------------------------------------------
 * Set ComputeCount and put into REXX "SQLCA.COMPUTECOUNT" compound variable.
 *----------------------------------------------------------------------------*/
static void SetComputeCount( RxPackageGlobalDataDef *RxPackageGlobalData, RXSQL_COMPUTECOUNT_TYPE computecount )
{
   char    buf[50];

   InternalTrace( RxPackageGlobalData, "SetComputeCount", "%d", computecount );

   if (RexxSQLData->SQLCA_ComputeCount != computecount)
   {
      RexxSQLData->SQLCA_ComputeCount = computecount;
      (void)sprintf(buf, "%lu", computecount);
      (void)SetRexxVariable( RxPackageGlobalData, SQLCA_COMPUTECOUNT,  strlen(SQLCA_COMPUTECOUNT),buf, strlen(buf));
   }
   return;
}
#endif

/*-----------------------------------------------------------------------------
 * Clear the error code, error message etc.
 *----------------------------------------------------------------------------*/
static void ClearDBError( RxPackageGlobalDataDef *RxPackageGlobalData )
{
#if defined(USES_MULTIPLE_ERRORS)
   char tmp[50];
#endif

   InternalTrace( RxPackageGlobalData, "ClearDBError", NULL );

   SetRowCount( RxPackageGlobalData, 0L );
#if defined(USES_COMPUTE_COUNT)
   SetComputeCount( RxPackageGlobalData, 0L );
#endif
#if defined(USES_MULTIPLE_ERRORS)
   sprintf( tmp,"%s.0", SQLCA_SQLERRM );
   (void)SetRexxVariable( RxPackageGlobalData, tmp, strlen(tmp), "0", 1 );
   sprintf( tmp, "%s.0", SQLCA_SQLSTATE );
   (void)SetRexxVariable( RxPackageGlobalData, tmp, strlen(tmp), "0", 1 );
#endif
   SetSQLCA( RxPackageGlobalData, 0L, "", "", "" );
   return;
}

/*-----------------------------------------------------------------------------
 * Clear the internal error code, error message etc.
 *----------------------------------------------------------------------------*/
static void ClearIntError( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;

   InternalTrace( RxPackageGlobalData, "ClearIntError", NULL );

   RexxSQLData->SQLCA_IntCode = 0L;
   /*
    * Set SQLCA.INTERRM variable
    */
   (void)SetRexxVariable( RxPackageGlobalData, SQLCA_INTERRM, strlen(SQLCA_INTERRM),"", 0);

   /*
    * Set SQLCA.INTCODE variable
    */
   (void)SetRexxVariable( RxPackageGlobalData, SQLCA_INTCODE, strlen(SQLCA_INTCODE),"0", 1);

   return;
}


/*-----------------------------------------------------------------------------
 * Return an error to REXX interpreter.
 *----------------------------------------------------------------------------*/
static ULONG ReturnError( RxPackageGlobalDataDef *RxPackageGlobalData, RXSTRING *retptr, int errcode, char *errmsg )
{
   SetIntError( RxPackageGlobalData, __FILE__, __LINE__, errcode, errmsg);
   return RxReturnNumber( RxPackageGlobalData, retptr, -errcode);
}


/*-----------------------------------------------------------------------------
 * Makes an identifier (for a Connection, Stem or Statement) from a given
 * string. Leading and trailing whitespace is removed and the string is
 * capitalised. The variable must be the following regular expression:
 *   [A-Za-z!?][A-Za-z0-9!?_\.]*
 * That is the variable :-
 *   (i) The variable name must start with an alpha character or '!' or '?'.
 *  (ii) The rest of the variable name must be one of the above characters or
 *       a decimal digit or underscore or period.
 * NOTE Only removal of leading and trailing spaces now done!
 *----------------------------------------------------------------------------*/
static int MkIdentifier( RxPackageGlobalDataDef *RxPackageGlobalData, RXSTRING var, PSZ buf, size_t buflen )
{
   char      *p = RXSTRPTR(var);
   size_t    len = RXSTRLEN(var);
   size_t    cnt = 0;

   if ( len == 0 )
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 51, "zero length identifier" ));

   /*
    * Make room for the terminating byte.
    */
   buflen--;

   /*
    * Remove leading whitespace
    */
   while( len && isspace(*p) )
   {
      p++;
      len--;
   }

#if 0
   /*
    * Special check for 1st character
    */
   if (len && (isalpha(*p) || *p == '!' || *p == '?'))
   {
      *buf++ = (islower(*p)) ? toupper(*p) : *p;
      p++;
      len--;
   }
#endif

#if 0
   /*
    * Copy identifier to destination
    */
   while (len && (isalnum(*p) || *p == '_' || *p == '!' || *p == '?' || *p== '.'))
   {
      *buf = (islower(*p)) ? toupper(*p) : *p;
      p++;
      len--;
      if (++cnt <= buflen)
         buf++;
   }
#else
   /*
    * Copy identifier to destination
    */
   while( len )
   {
      *buf = (islower(*p)) ? toupper(*p) : *p;
      p++;
      len--;
      if (++cnt <= buflen)
         buf++;
   }
#endif

   /*
    * Remove trailing whitespace
    */
   while( len && isspace(*p) )
   {
      p++;
      len--;
   }

#if 0
   /*
    * Check for garbage
    */
   if (len)
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 52, "garbage in identifier name" ));
#endif

   *buf = '\0';
   return 0;
}

/*-----------------------------------------------------------------------------
 * Save SQL statement in cursor statement buffer.  Dynamically extends the
 * statement buffer when required.
 *----------------------------------------------------------------------------*/
static int SaveSqlStatement( RxPackageGlobalDataDef *RxPackageGlobalData, SAVEDSQLSTMT *saved_stmt, char *statement, int length )
{
   int len=length+1;

   InternalTrace( RxPackageGlobalData, "SaveSqlStatement", "In: Saved: Length %d Buffer Size: %d New: \"%s\" %d", saved_stmt->sql_stmt_sz, saved_stmt->sql_buffer_sz, statement, length );

   if (len > saved_stmt->sql_buffer_sz)
   {
      /* New statement size is > than previous */
      if ( saved_stmt->sql_stmt != (char*)NULL )
      {
         /* Free old statement */
         FREE_TSD( RxPackageGlobalData, saved_stmt->sql_stmt );
         saved_stmt->sql_stmt = (char*)NULL;
         saved_stmt->sql_stmt_sz = 0;
         saved_stmt->sql_buffer_sz = 0;
      }

      /* Allocate a buffer for the new statement */
      if ( ( saved_stmt->sql_stmt = (char *)MALLOC_TSD( RxPackageGlobalData, len ) ) == (char*)NULL )
      {
         return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
      }
      saved_stmt->sql_buffer_sz = len;
   }
   saved_stmt->sql_stmt_sz = length;

   /* Save the statement */
   (void)memcpy( saved_stmt->sql_stmt, statement, length );
   saved_stmt->sql_stmt[length] = '\0';
   /* set SQLCA.SQLTEXT */
   (void)SetRexxVariable( RxPackageGlobalData, SQLCA_SQLTEXT, strlen(SQLCA_SQLTEXT), statement, length );
   InternalTrace( RxPackageGlobalData, "SaveSqlStatement", "Out: Saved: \"%s\" %d Buffer Size: %d", saved_stmt->sql_stmt, saved_stmt->sql_stmt_sz, saved_stmt->sql_buffer_sz );
   return 0;
}

#if !defined(REXXSQL_IGNORE_COUNTQUESTIONMARKS)
/*-----------------------------------------------------------------------------
 * Count the number of '?' in a SQL statement. This is a kludge for ODBC
 * drivers that don't support SQLNumParams.
 *----------------------------------------------------------------------------*/
static int CountQuestionMarks( RxPackageGlobalDataDef *RxPackageGlobalData, char *sql_stmt )
{
   int num=0;

   InternalTrace( RxPackageGlobalData, "CountQuestionMarks", "%s", sql_stmt );

   while(*sql_stmt++)
   {
      if (*sql_stmt == '?')
         num++;
   }
   return num;
}
#endif

/*-----------------------------------------------------------------------------
 * Install a REXX/SQL variable structure.
 *----------------------------------------------------------------------------*/
static SQLVAL *InstallSQLVariable( RxPackageGlobalDataDef *RxPackageGlobalData, int *rc,char *name, SQLVAL *first, int upd, int dtype, int option, void *val, int valtype )
{
   SQLVAL  *opt=NULL;

   InternalTrace( RxPackageGlobalData, "InstallSQLVariable", "%x,%s,%x,%d,%d,%d,%x,%d", rc,name, first, upd, dtype, option, val, valtype );

   if ( ( opt = (SQLVAL*)ll_add( RxPackageGlobalData, first, first ) ) == (SQLVAL*)NULL )
   {
      *rc = SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory");
      return(NULL);
   }
   (void)strcpy(opt->name, name);
   opt->user_update = (char)upd;
   opt->dtype = (char)dtype;
   opt->value = val;
   opt->option = option;
   opt->valtype = valtype;
   *rc = 0;
   return(opt);
}

/*-----------------------------------------------------------------------------
 * This function converts a REXX array into an array of argv's
 *----------------------------------------------------------------------------*/
static int ArrayToArgv( RxPackageGlobalDataDef *RxPackageGlobalData, RXSTRING *names, RXSTRING *values, ULONG *Argc, RXSTRING *Argv )
{
   int i=0,num_args=1;
   RXSTRING counter;
   char *new_name=NULL;
   char *new_value=NULL;
   int num_names=0,num_values=0;

   InternalTrace( RxPackageGlobalData, "ArrayToArgv", "%x,%x,%x,%x", names, values, Argc, Argv );

   if ( ( new_name = (char *)MALLOC_TSD( RxPackageGlobalData, RXSTRLEN(*names)+1 ) ) == NULL )
      return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory") );
   memcpy( new_name, RXSTRPTR(*names), RXSTRLEN(*names) );
   new_name[RXSTRLEN(*names)] = '\0';
   if ( ( GetRexxVariable( RxPackageGlobalData, new_name,&counter,0 ) ) == NULL )
   {
      FREE_TSD( RxPackageGlobalData, new_name );
      FREE_TSD( RxPackageGlobalData, counter.strptr );
      return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "rexx variable not found") );
   }
   num_names = atoi(RXSTRPTR(counter));

   if (values != NULL)
   {
      num_args = 2;
      if ( ( new_value = (char *)MALLOC_TSD( RxPackageGlobalData, RXSTRLEN(*values)+1 ) ) == NULL )
      {
         FREE_TSD( RxPackageGlobalData, new_name );
         FREE_TSD( RxPackageGlobalData, counter.strptr );
         return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ) );
      }
      memcpy( new_value, RXSTRPTR(*values), RXSTRLEN(*values) );
      new_value[RXSTRLEN(*values)] = '\0';
      if ( ( GetRexxVariable( RxPackageGlobalData, new_value ,&counter, 0 ) ) == NULL )
      {
         FREE_TSD( RxPackageGlobalData, new_name );
         FREE_TSD( RxPackageGlobalData, counter.strptr );
         return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ) );
      }
      num_values = atoi( RXSTRPTR(counter) );
      if (num_names != num_values)
      {
         FREE_TSD( RxPackageGlobalData, new_name );
         FREE_TSD( RxPackageGlobalData, counter.strptr );
         return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 88, "array index counts not equal" ) );
      }
   }
   FREE_TSD( RxPackageGlobalData, counter.strptr );

   for ( i = 1; i <= num_names; i++ )
   {
      if ( ( GetRexxVariable( RxPackageGlobalData, new_name, Argv, i ) ) == NULL )
      {
         FREE_TSD( RxPackageGlobalData, new_name );
         return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ) );
      }
      Argv++;
      if ( values != NULL )
      {
         if ( ( GetRexxVariable( RxPackageGlobalData, new_value, Argv, i ) ) == NULL )
         {
            FREE_TSD( RxPackageGlobalData, new_name );
            return( SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory" ) );
         }
         Argv++;
         InternalTrace( RxPackageGlobalData, "ArrayToArgv","Arg: %d Name: %s Value: %s", i, new_name, new_value );
      }
   }
   FREE_TSD( RxPackageGlobalData, new_name );
   FREE_TSD( RxPackageGlobalData, new_value );
   *Argc = num_names*num_args;
   return 0;
}

/*-----------------------------------------------------------------------------
 * This function copies an array of argvs to another
 *----------------------------------------------------------------------------*/
static int ArgvToArgv( RxPackageGlobalDataDef *RxPackageGlobalData, ULONG argc, RXSTRING *argv, ULONG *Argc, RXSTRING *Argv )
{
   ULONG i=0L;

   InternalTrace( RxPackageGlobalData, "ArgvToArgv","%d,%x,%x,%x", argc, argv, Argc, Argv );

   for ( i = 0; i < argc; i++ )
   {
      if ( ( Argv[i].strptr = (char *)MALLOC_TSD( RxPackageGlobalData, RXSTRLEN(argv[i])+1 ) ) == NULL )
         return(SetIntError( RxPackageGlobalData, __FILE__, __LINE__, 10, "out of memory"));
      memcpy( RXSTRPTR(Argv[i]), RXSTRPTR(argv[i]), RXSTRLEN(argv[i]) );
      Argv[i].strptr[RXSTRLEN(argv[i])] = '\0';
      Argv[i].strlength = RXSTRLEN(argv[i]);
      InternalTrace( RxPackageGlobalData, "ArgvToArgv","Arg: %d Value: %s Length: %d", i, Argv[i].strptr, Argv[i].strlength );
   }
   *Argc = argc;
   return 0;
}

/*-----------------------------------------------------------------------------
 * This function frees an array of argvs
 *----------------------------------------------------------------------------*/
static RXSTRING *FreeArgv( RxPackageGlobalDataDef *RxPackageGlobalData, ULONG *Argc, RXSTRING *Argv )
{
   int i=0;

   InternalTrace( RxPackageGlobalData, "FreeArgv", "%x,%x", Argc,Argv );

   if (*Argc == 0
   || Argv == NULL)
      return(NULL);

   for ( i = 0; i < MAX_BINDVARS*2; i++ )
   {
      if ( RXSTRPTR(Argv[i]) != NULL )
         FREE_TSD( RxPackageGlobalData, Argv[i].strptr );
      Argv[i].strptr = NULL;
      Argv[i].strlength = 0;
   }
   *Argc = 0;
   FREE_TSD( RxPackageGlobalData, Argv );
   return(NULL);
}


/*-----------------------------------------------------------------------------
 * This function is called to initiate REXX/SQL interface.
 *----------------------------------------------------------------------------*/
int InitRexxSQL( RxPackageGlobalDataDef *RxPackageGlobalData, char *progname,int regfunc )
{
   return 0;
}


/*-----------------------------------------------------------------------------
 * This function is called to terminate all activity with REXX/SQL.
 *----------------------------------------------------------------------------*/
int TerminateRexxSQL( RxPackageGlobalDataDef *RxPackageGlobalData, char *progname )
{
   return 0;
}

/*-----------------------------------------------------------------------------
 * Add a SQLVAL structure to single linked list.
 *----------------------------------------------------------------------------*/
static SQLVAL *ll_add ( RxPackageGlobalDataDef *RxPackageGlobalData, SQLVAL *first, SQLVAL *curr )
{
   SQLVAL *next=NULL;
   if ( ( next = (SQLVAL *)MALLOC_TSD( RxPackageGlobalData, sizeof(SQLVAL) ) ) != (SQLVAL *)NULL )
   {
      memset( next, 0, sizeof(SQLVAL) );
      if (curr == NULL)
      {
         first = next;
         next->next = NULL;
      }
      else
      {
         next->next = curr->next;
         curr->next = next;
      }
   }
   return(next);
}

/*-----------------------------------------------------------------------------
 * Free a SQLVAL linked list.
 *----------------------------------------------------------------------------*/
static SQLVAL *ll_free( RxPackageGlobalDataDef *RxPackageGlobalData, SQLVAL *first )
{
   SQLVAL *curr=first;
   SQLVAL *new_curr=NULL;
   RXSTRING *rxs=NULL;
   RXSTRING_DT *rxs_dt=NULL;
   int i=0;

   InternalTrace( RxPackageGlobalData, "ll_free","" );

   while (curr != NULL)
   {
      if ( (curr->option)&OPT_DYNAMIC )
      {
         InternalTrace( RxPackageGlobalData, "ll_free: freeing DYNAMIC:", "%s", curr->name );
         switch( curr->dtype )
         {
            case TYPE_INT:
            case TYPE_BOOL:
               if (curr->value)
                  FREE_TSD( RxPackageGlobalData, curr->value );
               break;
            case TYPE_STRING:
               rxs =(RXSTRING*)(curr->value);
               if (rxs)
               {
                  if ( rxs->strptr ) FREE_TSD( RxPackageGlobalData, rxs->strptr );
                  FREE_TSD( RxPackageGlobalData, rxs );
               }
               break;
            case TYPE_ARRAY:
               rxs =(RXSTRING*)(curr->value);
               if (rxs)
               {
                  for ( i = 0;; i++ )
                  {
                     if (rxs[i].strlength == 0)
                        break;
                     if (rxs[i].strptr) FREE_TSD( RxPackageGlobalData, rxs[i].strptr );
                  }
                  FREE_TSD( RxPackageGlobalData, rxs );
               }
               break;
            case TYPE_DATATYPE:
               rxs_dt =(RXSTRING_DT*)(curr->value);
               if (rxs_dt)
               {
                  for ( i = 0;; i++ )
                  {
                     if (rxs_dt[i].strlength == 0)
                        break;
                     if ( rxs_dt[i].strptr ) FREE_TSD( RxPackageGlobalData, rxs_dt[i].strptr );
                  }
               }
               FREE_TSD( RxPackageGlobalData, rxs_dt );
               break;
         }
      }
      else
         InternalTrace( RxPackageGlobalData, "ll_free: freeing STATIC:", "%s", curr->name );
      new_curr = curr->next;
      FREE_TSD( RxPackageGlobalData, curr );
      curr = new_curr;
   }
   return((SQLVAL *)NULL);
}

/*-----------------------------------------------------------------------------
 * Find an entry in a SQLVAL linked list.
 *----------------------------------------------------------------------------*/
static SQLVAL *ll_find( RxPackageGlobalDataDef *RxPackageGlobalData, SQLVAL *first, char *name )
{
   SQLVAL *curr=NULL;
   curr = first;
   while (curr != NULL)
   {
      if (strcmp(curr->name,name) == 0)
      {
         return(curr);
      }
      curr = curr->next;
   }
   return(NULL);
}

/*-----------------------------------------------------------------------------
 * Print a usage message.
 *----------------------------------------------------------------------------*/
void RexxSQLUsage

#ifdef HAVE_PROTO
    (void)
#else
    ()
#endif

{
    (void)fprintf(stderr,
                  "\nVersion: %s %s %s %s %s\n\nUsage:   %s [-h]\n         %s [-idvDu] [REXX-script-name] [arguments...]\n\n",
                  RxPackageName,
                  REXXSQL_VERSION,
                  REXXSQL_DATE,
                  CURRENT_OS,
                  CURRENT_DB,
                  RxPackageName,
                  RxPackageName);
    exit(BAD_ARGS);
}

/*-----------------------------------------------------------------------------
 * This function is used to initialise the external functions from
 * within a dynamic library when the SysAddFunc() REXX function
 * is called.
 *----------------------------------------------------------------------------*/
#if defined(USE_REXX6000)
USHORT InitFunc(RXFUNCBLOCK **FuncBlock)
{
   static RXFUNCBLOCK funcarray[] =
   {
      { NAME_SQLCONNECT_EXT,    SQLCONNECT   ,NULL },
      { NAME_SQLDISCONNECT_EXT, SQLDISCONNECT,NULL },
      { NAME_SQLDEFAULT_EXT,    SQLDEFAULT   ,NULL },
      { NAME_SQLCOMMIT_EXT,     SQLCOMMIT    ,NULL },
      { NAME_SQLROLLBACK_EXT,   SQLROLLBACK  ,NULL },
      { NAME_SQLCOMMAND_EXT,    SQLCOMMAND   ,NULL },
      { NAME_SQLPREPARE_EXT,    SQLPREPARE   ,NULL },
      { NAME_SQLDISPOSE_EXT,    SQLDISPOSE   ,NULL },
      { NAME_SQLEXECUTE_EXT,    SQLEXECUTE   ,NULL },
      { NAME_SQLOPEN_EXT,       SQLOPEN      ,NULL },
      { NAME_SQLCLOSE_EXT,      SQLCLOSE     ,NULL },
      { NAME_SQLFETCH_EXT,      SQLFETCH     ,NULL },
      { NAME_SQLGETDATA_EXT,    SQLGETDATA   ,NULL },
      { NAME_SQLVARIABLE_EXT,   SQLVARIABLE  ,NULL },
      { NAME_SQLGETINFO_EXT,    SQLGETINFO   ,NULL },
      { NAME_SQLDESCRIBE_EXT,   SQLDESCRIBE  ,NULL },
      { NAME_SQLDATASOURCES_EXT,SQLDATASOURCES,NULL },
      { NAME_SQLTABLES_EXT,     SQLTABLES,NULL },
      { NAME_SQLCOLUMNS_EXT,    SQLCOLUMNS   ,NULL },
      { NAME_SQLDROPFUNCS_EXT,  SQLDROPFUNCS ,NULL },
      { NULL,                   NULL,         NULL }
   };
   *FuncBlock = funcarray;
   return (USHORT)0;
}
#endif

#ifdef MAY_USE_FOR_DEBUG
/*
 * Dump a bucket
 */
static void DumpBucket( RxPackageGlobalDataDef *RxPackageGlobalData, BUCKET *tbl[], int tblsz )
{
   BUCKET  *p=NULL;
   int i;

   for ( i =0; i < tblsz; i++ )
   {
      p = tbl[i];
      while ( p )
      {
         p = p->next;
      }
   }
   return;
}
#endif
/*
 * Calculate the hash function of a given string.
 */
static int Hash( RxPackageGlobalDataDef *RxPackageGlobalData, char *s, int table_size )
{
   int     h=0;
   int     ch=0;

   while( (ch = *s++) )
      h = (3*h + ch) % table_size;
   return (h);
}


void* NewObject( RxPackageGlobalDataDef *RxPackageGlobalData, int size )
{
   /* Allocate space for a new object contained within a bucket structure.
    * Return a pointer to the object (not the encapsulating bucket).
    */
   BUCKET  *obj=NULL;

   if ( !( obj = (BUCKET*)MALLOC_TSD( RxPackageGlobalData, size+sizeof(BUCKET) ) ) )
   {
        return NULL;
   }
   memset( obj, 0, size+sizeof(BUCKET) );
   return (void*)(obj+1); /* Return pointer to user object */
}


/*
 * Free a user object (and encapsulating bucket).
 */
void FreeObject( RxPackageGlobalDataDef *RxPackageGlobalData, void *obj )
{
   FREE_TSD( RxPackageGlobalData, (BUCKET*)obj-1 );
}


/*
 * Insert an object into the hashed table.
 */
void* InsertObject( RxPackageGlobalDataDef *RxPackageGlobalData, void *obj, BUCKET *tbl[], int tblsz )
{
   BUCKET  **p=NULL, *tmp=NULL;
   BUCKET  *bkt = (BUCKET*)obj - 1;

   p = &tbl[Hash( RxPackageGlobalData, (char*)obj, tblsz )];
   tmp = *p;
   *p = bkt;
   bkt->prev = p;
   bkt->next = tmp;

   if (tmp)
      tmp->prev = &bkt->next;

   return (void*)(bkt+1);
}


/*
 * Remove an object from the table.
 */
void RemoveObject( RxPackageGlobalDataDef *RxPackageGlobalData, void *obj )
{
   BUCKET  *bkt = (BUCKET*)obj - 1;

   if ( ( *(bkt->prev) = bkt->next ) )
      bkt->next->prev = bkt->prev;
}


void* FindObject( RxPackageGlobalDataDef *RxPackageGlobalData, char *name, BUCKET *tbl[], int tblsz )
{
   BUCKET  *p=NULL;

   p = tbl[Hash( RxPackageGlobalData, name, tblsz )];
   while ( p && (strcmp(name,(char*)(p+1))) )
      p = p->next;
   return (void*)(p ? p+1 : NULL);
}


void* FirstObject( RxPackageGlobalDataDef *RxPackageGlobalData, int idx, BUCKET *tbl[] )
{
   BUCKET  *p=NULL;

   p = tbl[idx];
   return (void*)(p ? p+1 : NULL);
}


void* NextObject( RxPackageGlobalDataDef *RxPackageGlobalData, void *obj )
{
   BUCKET  *bkt = (BUCKET*)obj - 1;

   bkt = bkt->next;
   return (void*)(bkt ? bkt+1 : NULL);
}


#if !defined(DYNAMIC_LIBRARY) && (defined(USE_WINREXX) || defined(USE_QUERCUS))
# if defined(USE_WINREXX)
int RXSQL_APIENTRY RxExitHandlerForSayTraceRedirection
   ( int ExitNumber, int Subfunction, PEXIT ParmBlock )
# else
LONG RxExitHandlerForSayTraceRedirection
   ( LONG ExitNumber, LONG Subfunction, PEXIT ParmBlock )
# endif
{
   long i = 0;
   int rc = 0;

   switch( Subfunction )
   {
      case RXSIOSAY:
      {
         RXSIOSAY_PARM *say_parm = (RXSIOSAY_PARM *)ParmBlock;
         if ( say_parm->rxsio_string.strptr != NULL )
         {
            for( i = 0; i < (long)say_parm->rxsio_string.strlength; i++ )
               fputc( ( char )say_parm->rxsio_string.strptr[i], stdout );
         }
         fputc( '\n', stdout );
         rc = RXEXIT_HANDLED;
         break;
      }
      case RXSIOTRC:
      {
         RXSIOTRC_PARM *trc_parm = (RXSIOTRC_PARM *)ParmBlock;
         if ( trc_parm->rxsio_string.strptr != NULL )
         {
            for( i = 0; i < (long)trc_parm->rxsio_string.strlength; i++ )
               fputc( ( char )trc_parm->rxsio_string.strptr[i], stdout );
         }
         fputc( '\n', stdout );
         rc = RXEXIT_HANDLED;
         break;
      }
      case RXSIOTRD:
      {
         RXSIOTRD_PARM *trd_parm = (RXSIOTRD_PARM *)ParmBlock;
         int i = 0, ch = 0;
         do
         {
            if ( i < 256 )
               trd_parm->rxsiotrd_retc.strptr[i++] = ch = getc( stdin ) ;
         } while( ch != '\012' && (ch != EOF ) ) ;
         trd_parm->rxsiotrd_retc.strlength = i - 1;
         rc = RXEXIT_HANDLED;
         break;
      }
      case RXSIODTR:
      {
         RXSIODTR_PARM *dtr_parm = (RXSIODTR_PARM *)ParmBlock;
         int i = 0, ch = 0;
         do
         {
            if ( i < 256 )
               dtr_parm->rxsiodtr_retc.strptr[i++] = ch = getc( stdin ) ;
         } while( ch != '\012' && (ch != EOF ) ) ;
         dtr_parm->rxsiodtr_retc.strlength = i - 1;
         rc = RXEXIT_HANDLED;
         break;
      }
         break;
      default:
         rc = RXEXIT_NOT_HANDLED;
         break;
   }
  return rc;
}
#endif

void *INIT_RXPACKAGE ( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   /*
    * This needs to allocate memory for RexxSQLData structure,
    * set values for sqlvariable() array
    */
   RxPackageGlobalData->RXPACKAGE_tsd = (REXXSQLDATA *)MALLOC_TSD( RxPackageGlobalData, sizeof(REXXSQLDATA) );
   if ( RxPackageGlobalData->RXPACKAGE_tsd )
      memset( RxPackageGlobalData->RXPACKAGE_tsd , 0, sizeof(REXXSQLDATA) );
   return (void *)RxPackageGlobalData->RXPACKAGE_tsd;
}

void TERM_RXPACKAGE ( RxPackageGlobalDataDef *RxPackageGlobalData )
{
   REXXSQLDATA *RexxSQLData=(REXXSQLDATA *)RxPackageGlobalData->RXPACKAGE_tsd;
   /*
    * This needs to free memory allocated in INIT_RXPACKAGE()
    * and call any database-specific termination code
    */
   /*
    * Free items in the RexxSQLData struct
    */
   if ( RexxSQLData->opt_tbl )
      RexxSQLData->opt_tbl = ll_free( RxPackageGlobalData, RexxSQLData->opt_tbl );
   if ( RexxSQLData->converted_stmt )
      FREE_TSD( RxPackageGlobalData, RexxSQLData->converted_stmt );
   /*
    * Free the RexxSQLData struct
    */
   FREE_TSD( RxPackageGlobalData, RxPackageGlobalData->RXPACKAGE_tsd );
   RxPackageGlobalData = NULL;
}

#if 0
/*
 * Because WinRexx and Personal Rexx load and unload the Rexx/SQL DLL
 * each time an external function is called, we need to ensure that
 * the DLL stays loaded in memory, so that memory we have initialised
 * stays set.
 * Why they do this is beyond me :-(
 */
#if defined(DYNAMIC_LIBRARY) && (defined(USE_WINREXX) || defined(USE_QUERCUS))
BOOL WINAPI DllMain( HINSTANCE hDLL, DWORD dwReason, LPVOID pReserved)
{
   switch( dwReason)
   {
      case DLL_PROCESS_ATTACH:
         LoadLibrary( RxPackageName );
         break;
      case DLL_PROCESS_DETACH:
         FreeLibrary( GetModuleHandle( RxPackageName ) );
         break;
      case DLL_THREAD_ATTACH:
         break;
      case DLL_THREAD_DETACH:
         break;
   }
   return(TRUE);
}
#endif
#endif

void *getRexxSQLFunctionAddress( char *name )
{
   int i, size = sizeof( RexxSQLFunctions ) / sizeof( RexxFunction ) ;

   for (i = 0; i < size; i++)
   {
      if ( strcmp( RexxSQLFunctions[i].InternalName, name) == 0 )
         return RexxSQLFunctions[i].EntryPoint;
   }
   return NULL;
}
