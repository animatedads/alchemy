#ifndef RXMT_H_INCLUDED
#define RXMT_H_INCLUDED

#if !defined(MAX_PATH)
# if defined(NAME_MAX)
#  define MAX_PATH NAME_MAX
# elif defined(MAXNAMLEN)
#  define MAX_PATH MAXNAMLEN
# else
#  define MAX_PATH 255
# endif
#endif

#define RX_CONSTANT_PREFIX_MAX 50
/*
 * The following structure contains all "global" data common to all
 * external function packages.  A similar structure should exist
 * for package-specific data.
 */
typedef struct _tsd_t {
   unsigned long           thread_id;
   void *                  RXPACKAGE_tsd ;           /* local variables of package */
   void *                  mt_tsd ;                  /* local variables of mt_???.c */
   int RxRunFlags;                    /* debug/verbose flags */
   char FName[100];                   /* current function name */
   char PreviousConstantPrefix[RX_CONSTANT_PREFIX_MAX];   /* previous constant variables prefix */
   char ConstantPrefix[RX_CONSTANT_PREFIX_MAX];           /* constant variables prefix */
   FILE *RxTraceFilePointer;          /* file pointer for all output */
   char RxTraceFileName[MAX_PATH];    /* filename of output file */
   int deallocate;                    /* indicates if rxpack should deallocate this structure */
   int terminated;                    /* indicates if rxpack has called RxTermPackage() for this structure */

   void *                  (*MTMalloc)(const struct _tsd_t *TSD, long size);
   void                    (*MTFree)(const struct _tsd_t *TSD,void *chunk);
   void                    (*MTExit)(int code);
} RxPackageGlobalDataDef ;

#if (defined(POSIX) || defined(_POSIX_SOURCE) || defined(_PTHREAD_SEMANTICS)) && (defined(_REENTRANT) || defined(REENTRANT))
#  include "rxmt_posix.h"
#elif ( defined(_WIN64) || defined(_WIN32) ) && defined(RXPACKAGE_SINGLE_THREADED)
#  include "rxmt_notmt.h"
#  define SINGLE_THREADED
#elif defined(_WIN64) && defined(_MT)
#  include "rxmt_win64.h"
#elif defined(_WIN32) && defined(_MT)
#  include "rxmt_win32.h"
#elif defined(OS2) && defined(__EMX__) && defined(__MT__) && defined(RXPACK_MULTI)
#  include "rxmt_os2.h"
#elif defined(OS2) && defined(__WATCOMC__) && defined(RXPACK_MULTI)
#  include "rxmt_os2.h"
#else
#  include "rxmt_notmt.h"
#  if !defined(SINGLE_THREADED) && !defined(MULTI_THREADED)
#     define SINGLE_THREADED
#   endif
#endif

/* SINGLE_THREAD is defined explicitely, thus: */
#if !defined(SINGLE_THREADED) && !defined(MULTI_THREADED)
#  define MULTI_THREADED
#endif

#endif /* RXMT_H_INCLUDED */
