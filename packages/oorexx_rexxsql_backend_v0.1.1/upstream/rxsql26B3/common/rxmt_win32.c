/* This is the file to support WIN32 threads.
 * We initialize the global data structure and the global access variable.
 */

#define DONT_TYPEDEF_PFN
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <assert.h>

#define WIN32_LEAN_AND_MEAN
#ifdef _MSC_VER
# if _MSC_VER >= 1100
/* Stupid MSC can't compile own headers without warning at least in VC 5.0 */
#  pragma warning(disable: 4115 4201 4214 4514)
# endif
#endif
#include <windows.h>
#ifdef _MSC_VER
# if _MSC_VER >= 1100
#  pragma warning(default: 4115 4201 4214)
# endif
#endif

#include "rxmt.h"

/* mt_tsd: static variables of this module (thread-safe) */
typedef struct
{
   HANDLE Heap;
} mt_tsd_t; /* thread-specific but only needed by this module. see
             * RxPackInitializeThread
             */

static DWORD ThreadIndex = 0xFFFFFFFF; /* index of the TSD, not yet got */

extern void *INIT_RXPACKAGE(RxPackageGlobalDataDef *);
extern void TERM_RXPACKAGE(RxPackageGlobalDataDef *);

/* We use only one critical section for all purposes. That's enough since
 * we use it very rarely.
 */
static CRITICAL_SECTION cs = {0,};

#if defined(DYNAMIC) || (defined(__MINGW32__) && (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 4)))
static void DestroyHeap( RxPackageGlobalDataDef *TSD )
{
   mt_tsd_t *mt = TSD->mt_tsd;

   if ( mt == NULL )
      return;
   if ( mt->Heap != (HANDLE) 0 )
      HeapDestroy( mt->Heap );
   free( mt );
   free( TSD );
}

int IfcRxPackCleanup( VOID )
{
   RxPackageGlobalDataDef *TSD = __rxpack_get_tsd();

   if ( TSD == NULL )
      return 0;

/*
   deinit_rexxsaa(TSD);
*/
   DestroyHeap( TSD );
   TlsSetValue( ThreadIndex, NULL );

   return 1;
}
#endif

#ifdef DYNAMIC
#define AcquireCriticalSection(cs) EnterCriticalSection(cs)
#define AcquireThreadIndex() ThreadIndex

/* We provide a DLL entry function. Look at the standard documentation */
BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD Reason, LPVOID reserved)
{
   RxPackageGlobalDataDef *TSD;

   switch (Reason) {
      case DLL_PROCESS_ATTACH:
         /* Two things to do */
         InitializeCriticalSection(&cs);
         ThreadIndex = TlsAlloc();
         if (ThreadIndex == 0xFFFFFFFF)
            return FALSE; /* FIXME, FGC: Do we have to call SetLastError()? */
         break;
      case DLL_PROCESS_DETACH:
         break;
      case DLL_THREAD_ATTACH:
         break;
      case DLL_THREAD_DETACH:
         TSD = __rxpack_get_tsd();
         if ( TSD != NULL )
         {
            TERM_RXPACKAGE( TSD );
            DestroyHeap( TSD );
         }
         break;
   }
   return(TRUE);
}
#else
/* The DLL will do this work in DllMain above. This is for a MT library: */

/* AcquireCriticalSection locks the given critical section and
 * initializes it on the first use.
 */
static void AcquireCriticalSection(CRITICAL_SECTION *cs)
{
   /* double initializing the critical section won't produce an error.
    * We must do this on thread attachment if an error occurs in later
    * implementations of WIN32.
    */
   InitializeCriticalSection(cs);

   EnterCriticalSection(cs);
}

/* AcquireThreadIndex returns a valid ThreadIndex. */
static DWORD AcquireThreadIndex(void)
{
   if (ThreadIndex == 0xFFFFFFFF)
   {  /* get a unique access variable for the whole process */
      AcquireCriticalSection(&cs);
      if (ThreadIndex == 0xFFFFFFFF) /* may've changed just before Acquire */
         ThreadIndex = TlsAlloc();
      LeaveCriticalSection(&cs);
      /* give back a possible error value. nothing will help at this point */
   }
   return(ThreadIndex);
}
#endif

/* This should prevent some error messages and is used as a #define */
static unsigned sizeof_ptr(void)
{
   return(sizeof(void *));
}

/* Lowest level memory allocation function for normal circumstances. */
static void *MTMalloc( const RxPackageGlobalDataDef *TSD, long size )
{
   mt_tsd_t *mt = TSD->mt_tsd;
   void *ptr;

   if ( mt == NULL )
      return( NULL ); /* Let it die */
   ptr = HeapAlloc( mt->Heap, HEAP_NO_SERIALIZE, size );
   return(ptr);
}

/* Lowest level memory deallocation function for normal circumstances. */
static void MTFree( const RxPackageGlobalDataDef *TSD, void *chunk )
{
   mt_tsd_t *mt = TSD->mt_tsd;

   /*
    * Just in case...
    */
   if ( chunk == NULL)
      return;

   if ( mt == NULL )
      return; /* ??? */
   HeapFree( mt->Heap, HEAP_NO_SERIALIZE, chunk );
}

/* Lowest level exit handler. */
static void MTExit(int code)
{
   ExitThread(code);
}

/* RxPackInitializeThread creates a new thread structure and returns a ptr
 * to the initialized value.
 * The function may be called more than once.
 */
RxPackageGlobalDataDef *RxPackInitializeThread(void)
{
   DWORD idx;
   RxPackageGlobalDataDef *retval=NULL;
   mt_tsd_t *mt;

   /* If you run into trouble here, you must change the code in
    * ReginsSetMutex/RxPackUnsetMutex. The argument there assumes the
    * following rule. This is an ugly hack.
    */
   assert(sizeof_ptr() >= sizeof(HANDLE));
   if (sizeof_ptr() < sizeof(HANDLE))
      return(NULL); /* Be absolutely sure that we HAVE a problem */

   idx = AcquireThreadIndex();

   /* fetch the value of the access variable */
   retval = TlsGetValue(idx);

   if ( retval != NULL ) /* already initialized? */
      return(retval);

   /* First call in this thread... */
   retval = (RxPackageGlobalDataDef *)( GlobalLock( GlobalAlloc( GMEM_FIXED, sizeof(RxPackageGlobalDataDef) ) ) ); /* no MALLOC_TSD, etc! */

   if ( retval == NULL ) /* THIS is really a problem. I don't know what we */
      return(NULL);    /* should do now. Let the caller run into a crash... */

   TlsSetValue( idx, retval );

   memset( retval, 0, sizeof(RxPackageGlobalDataDef) );
   retval->MTMalloc = MTMalloc;
   retval->MTFree = MTFree;
   retval->MTExit = MTExit;

   /* Since the local data structure contains a Heap object for the memory
    * management we initialize it first.
    */
   if ( ( mt = GlobalLock( GlobalAlloc( GMEM_FIXED, sizeof(mt_tsd_t) ) ) ) == NULL )
      return(NULL);                     /* This is a catastrophy             */
   retval->mt_tsd = mt;
   memset( mt, 0, sizeof(mt_tsd_t) );
   if ( ( mt->Heap = HeapCreate( HEAP_NO_SERIALIZE, 0x10000, 0 ) ) == NULL )
      return(NULL);                     /* This is a catastrophy             */

   if ( !INIT_RXPACKAGE( retval ) )
   {
      return(NULL);
   }
   retval->thread_id = (unsigned long)GetCurrentThreadId();
   return(retval);
}

/* __rxpack_get_tsd returns a pointer to the thread specific data. Be sure to
 * call this after a RxPackInitializeThread only.
 */
RxPackageGlobalDataDef *__rxpack_get_tsd(void)
{
   /* See above for comments */
   return(TlsGetValue(ThreadIndex));
}

/* RxPackSetMutex is the opposite of RxPackUnsetMutex and sets a mutex
 * variable. The "true" mutex is "*arg" since we have hidden the type
 * HANDLE which is the correct type. Thus, we have used "HANDLE" and
 * "void *" in the same manner. If we include windows.h for the
 * definition of HANDLE we cant include windows later and may run
 * into trouble. The initialization code will check of errors of
 * this assumption.
 * The argument (*mutex) may be NULL. We initialize the mutex in this
 * case. This prevents the calling functions to initialize the mutex.
 * The is a little speed penalty but the mutexes are not used very
 * often. YOU should change it if it hurts you.
 */
void RxPackSetMutex(void **mutex)
{
   int OK = 1;
   volatile HANDLE *w32_mutex = (volatile HANDLE *) mutex;

   if (*w32_mutex == (HANDLE) 0)
   {
      AcquireCriticalSection(&cs);
      if (*w32_mutex == (HANDLE)0) /* may have changed due MT */
      {
         *w32_mutex = CreateMutex(NULL,FALSE,NULL);
         if (*w32_mutex == NULL)
            OK = 0;
      }
      LeaveCriticalSection(&cs);
      if (!OK)
      { /* We must die now! There is no other chance. */
         *((int *) NULL) = 1;
      }
   }

   WaitForSingleObject(*w32_mutex,INFINITE);
   /* ignore errors, we continue especially if WAIT_ABANDONED occurs */
}

/* see RxPackSetMutex */
void RxPackUnsetMutex(void **mutex)
{
   volatile HANDLE *w32_mutex = (volatile HANDLE *) mutex;

   ReleaseMutex(*w32_mutex);
}

/* get our thread id */
unsigned long RxPackGetThreadID(void)
{
   return (unsigned long)GetCurrentThreadId();
}

/*
 * Following useful for finding heap corruptions
 */
void CheckHeap( RxPackageGlobalDataDef *TSD, char filename, int lineno )
{
   mt_tsd_t *mt = TSD->mt_tsd;
   if ( HeapValidate( mt->Heap, 0, NULL ) == 0 )
   {
      fprintf( stderr, "\n\n\n ************* Heap invalid: In %s at line %d\n\n\n\n", filename, lineno );
   }
}
