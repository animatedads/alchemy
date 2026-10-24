/***********************************************************************
 * rexxsql.c - Rexx/SQL executable driver program.
 ***********************************************************************
 *
 * Rexx/SQL. A Rexx interface to SQL databases.
 * Copyright Impact Systems Pty Ltd, 1994-1997.
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
 *    Purpose: This module fires up the executable version of Rexx/SQL
 *    All real work is done elsewhere!
 *    This module is not compiled when building Dynamic Libraies
 */

#include "dbdefine.h"
#if defined(UNIX)
# include "dbheader.h"
#endif
#include "rexxsql.h"

#if defined(OS2) || defined(WIN32) || defined(WIN64)
# include <io.h>
#endif

/* Debugging flags */
extern int run_flags;

#ifndef HAVE_GETOPT
# ifdef HAVE_PROTO
int getopt(int argc, char *argv[], char *optstring);
# else
int getopt();
# endif
#endif

/* These are required by the getopt() function */
extern char *optarg;
extern int  optind;


/*-----------------------------------------------------------------------------
 * Checks to see if supplied filename is readable.
 *----------------------------------------------------------------------------*/
static int file_readable

#ifdef HAVE_PROTO
   (char *filename)
#else
   (filename)
   char  *filename;
#endif
{
   if ( ( access( filename, R_OK ) ) == (-1) )
      return( 0 );
   else
      return( 1 );
}


#ifdef THIS_IS_NOT_NEEDED_ANYMORE
/*-----------------------------------------------------------------------------
 * Returns a pointer to the basename of a file (i.e. to the 1st character past
 * the directory part.
 *----------------------------------------------------------------------------*/
static char *my_basename

#ifdef HAVE_PROTO
   (char *filename)
#else
   (filename)
   char  *filename;
#endif
{
   int   len = strlen(filename);
   char  *p=NULL;

   for ( p = filename + len - 1; len && !(DIRSEP(*p)); p--, len-- )
       ;
   return ++p;
}
#endif

/*-----------------------------------------------------------------------------
 * Print a usage message.
 *----------------------------------------------------------------------------*/
static void usage

#ifdef HAVE_PROTO
    (void)
#else
    ()
#endif

{
    (void)fprintf( stderr,
                   "\nVersion: %s %s %s %s %s\n\nUsage:   %s [-h]\n         %s [-idv] [REXX-script-name]\n\n",
                   DLLNAME,
                   REXXSQL_VERSION,
                   REXXSQL_DATE,
                   CURRENT_OS,
                   CURRENT_DB,
                   DLLNAME,
                   DLLNAME);
    exit( BAD_ARGS );
}

/*-----------------------------------------------------------------------------
 * Processing starts here for stand-alone rexxsql executable...
 *----------------------------------------------------------------------------*/
int main

#if HAVE_PROTO
    (int argc, char *argv[])
#else
    (argc, argv)
    int   argc;
    char  *argv[];
#endif


{
   int      c=0;
   char     *ScriptName=NULL;
   FILE     *fp;
   long     i=0, ArgCount=0;
   int      interactive = FALSE;
   short    rc=0;
   RXSTRING retstr;
   CHAR retbuf[RETBUFLEN];
   RXSTRING *Arg=(RXSTRING*)NULL, *ArgList = (RXSTRING*)NULL;
#if !defined(DYNAMIC_LIBRARY) && (defined(USE_WINREXX) || defined(USE_QUERCUS))
   RXSYSEXIT ExitList[2];
#endif

   /*
    * Get any program options.
    */
   while ( ( c = getopt( argc, argv, "Ddivh?" ) ) != EOF )
   {
      switch ( c )
      {
         case 'v': run_flags |= MODE_VERBOSE; break;
         case 'd': run_flags |= MODE_DEBUG; break;
         case 'D': run_flags = 10; break;
         case 'i': interactive = TRUE; break;
         case 'h':
         default : usage();
      }
   }

   /*
    * Check if any more arguments are presented
    */
   if ( optind >= argc )
   {
      if ( interactive )
      {
         ScriptName = tmpnam( NULL );
         if ( ( fp = fopen( ScriptName, "w" ) ) == NULL )
         {
            (void)fprintf( stderr, "Could not create temporary file for stdin\n" );
            exit( REXX_FAIL );
         }
         while( 1 )
         {
            if ( ( i = getc( stdin ) ) == EOF )
               break;
            putc( i, fp );
         }
         (void)fclose( fp );
      }
      else
         usage();
   }
   else
   {
      /*
       * Next argument is the name of the REXX script...
       */
      ScriptName = argv[optind++];
      /*
       * ... and must be readable.
       */
      if ( !file_readable( ScriptName ) )
      {
         (void)fprintf( stderr, "Could not read file: %s\n", ScriptName );
         exit( REXX_FAIL );
      }
   }
   /*
    * Get number of arguments to the REXX script
    */
   ArgCount = argc - optind;
   /*
    * Build an array of arguments if any.
    */
   if ( ArgCount )
   {
      if ( ( ArgList = (RXSTRING*)calloc( (size_t)ArgCount, sizeof(RXSTRING) ) ) == (RXSTRING*)NULL )
      {
         (void)fprintf( stderr, "%s: out of memory\n", argv[0] );
         exit( REXX_FAIL );
      }
      for ( Arg = ArgList, i = 0; i < ArgCount; Arg++, i++ )
      {
         Arg->strptr = argv[optind++];
         Arg->strlength = strlen( Arg->strptr );
      }
   }
   /*
    * Initialise the REXX/SQL interface.
    */
   FunctionPrologue( DLLNAME, 0L, NULL );
   InitRexxSQL( DLLNAME, 1 );

   MAKERXSTRING( retstr, retbuf, sizeof(retbuf) );
   /*
    * Set up the system exit for the Say and Trace redirection
    */
#if !defined(DYNAMIC_LIBRARY) && (defined(USE_WINREXX) || defined(USE_QUERCUS))
   ExitList[0].sysexit_name = DLLNAME;
   ExitList[0].sysexit_code = RXSIO;
   ExitList[1].sysexit_code = RXENDLST;
#endif
   /*
    * Execute the REXX script. Use RXSUBROUTINE mode so that an array
    * of arguments can be passed to the REXX script. This allows passing
    * strings containing spaces and is much more useful than RXCOMMAND
    * mode which passes a command as a single string!
    */
   assert( retstr.strptr );
   assert( ScriptName );
   RexxStart( ArgCount, ArgList, ScriptName, NULL, DLLNAME, RXSUBROUTINE,
#if !defined(DYNAMIC_LIBRARY) && (defined(USE_WINREXX) || defined(USE_QUERCUS))
              ExitList,
#else
              NULL,
#endif
              (PSHORT)&rc,
              (PRXSTRING)&retstr);

   /*
    * Terminate the REXX/SQL interface.
    */
   (void)TerminateRexxSQL( DLLNAME );

   if ( ArgList )
      free( ArgList );
   /*
    * Return the exit value from the script. This is useful for UNIX/DOS etc.
    * if the value is kept to 0-success, small positive numbers (say < 100)
    * to indicate errors!
    */
   if ( interactive )
      unlink( ScriptName );

   return (int)rc;
}
