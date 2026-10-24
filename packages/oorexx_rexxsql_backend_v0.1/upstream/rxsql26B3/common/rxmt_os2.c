/* This is the file to support OS/2 threads.
 * This file is under construction. We partially support EMX. The EMX
 * environment must currently be "OS2". Thus, usage is provided for
 * makefile.os2.emx. Others may run.
 * We initialize the global data structure and the global access variable.
 */

#define INCL_NOCOMMON
#define INCL_DOSPROCESS
#define INCL_DOSSEMAPHORES
#define INCL_DOSERRORS
#define INCL_DOSMEMMGR

#ifdef __EMX__
# define DONT_TYPEDEF_PFN
# include <io.h>
# include <os2emx.h>
#elif defined (__WATCOMC__)
# define DONT_TYPEDEF_PFN
# include <os2.h>
#endif

#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>
#include <string.h>
#include <errno.h>
#include <assert.h>

#include "rxmt.h"

static ULONG *TSD_ptrs = NULL;

typedef struct _MT_mem
{
   struct _MT_mem *prev;
   struct _MT_mem *next;
   /* real data follows here */
} MT_mem;

/* mt_tsd: static variables of this module (thread-safe) */
typedef struct
{
   MT_mem *mem_base; /* From DosAllocMem, we use this memory scheme since it is
                      * native OS/2. emx has its own heap allocation functions.
                      */
} mt_tsd_t; /* thread-specific but only needed by this module. see
             * RxPackInitializeThread
             */

extern void * INIT_RXPACKAGE (RxPackageGlobalDataDef *);
extern void TERM_RXPACKAGE (RxPackageGlobalDataDef *);

/* Returns a pointer to the TSD pointer */
static RxPackageGlobalDataDef **FindThreadDataIdx(void)
{
   RxPackageGlobalDataDef **retval = NULL;
   ULONG rc;

   DosEnterCritSec();
   if (TSD_ptrs != NULL)
   {
      retval = (RxPackageGlobalDataDef **) TSD_ptrs;
      goto Leave;
   }
   if ((rc = DosAllocThreadLocalMemory(1,&TSD_ptrs)) != NO_ERROR)
   {
      fprintf(stderr,"rc = %lu from DosAllocThreadLocalMemory, await SIGSEGV!\n",
                     (unsigned long) rc);
      TSD_ptrs = NULL;
   }
   if (TSD_ptrs != NULL)
      retval = (RxPackageGlobalDataDef **) TSD_ptrs;
Leave:
   DosExitCritSec();
   return(retval);
}

static void RxPackDeinitialize(void *buf)
{
   RxPackageGlobalDataDef *TSD = buf;
   mt_tsd_t *mt;
   MT_mem *chunk;

   if (TSD == NULL) /* Should never happen but be sure */
      return;

   TERM_RXPACKAGE(TSD);

   mt = TSD->mt_tsd;
   if (mt)
   {
      while ((chunk = mt->mem_base) != NULL)
      {
         TSD->MTFree(TSD,chunk + 1);
         if (mt->mem_base == chunk)
            break; /* something goes wrong. Don't run into an endless loop */
      }
      free(mt);
   }
   free(TSD);
}

int IfcRxPackCleanup( VOID )
{
   RxPackageGlobalDataDef **ptsd = FindThreadDataIdx();

   if (*ptsd == NULL)
      return 0;
   RxPackDeinitialize(*ptsd);
   *ptsd = NULL;

   return 1;
}

#ifdef DYNAMIC
/* Deinitialize is called when the thread terminates.
 * This is a wonderful position to place code which frees all allocated stuff!
 */
#ifdef __EMX__
/* We provide a DLL entry function. Look at the standard documentation for
 * EMX. See emxdev.doc and testdll6.c. We may use the macros CRT_INIT1 and
 * CRT_TERM1 from sys/startup.h instead but that's undocumented stuff.
 */
int _CRT_init (void);
void _CRT_term (void);
void __ctordtorInit (void);
void __ctordtorTerm (void);

unsigned long _DLL_InitTerm (unsigned long mod_handle, unsigned long flag)
{
   switch (flag)
   {
      case 0:
         if (_CRT_init() != 0)
            return 0;
         __ctordtorInit();
         return 1;
      case 1:
         /*
          * This will run ONLY if called on dynamic unload of the complete
          * library. This means, the last thread will receive an unload
          * command. Stupid OS/2.
          */
         IfcRxPackCleanup();
         __ctordtorTerm();
         _CRT_term();
         return 1;
      default:
         break;
   }
   return 0;
}
#endif /* EMX */
#endif /* DYNAMIC */

/* This should prevent some error messages and is used as a #define */
static unsigned sizeof_ptr(void)
{
   return(sizeof(void *));
}

/* Lowest level memory allocation function for normal circumstances. */
static void *MTMalloc( const RxPackageGlobalDataDef *TSD, size_t size )
{
   mt_tsd_t *mt;
   MT_mem *new;

   if (DosAllocMem((PPVOID) &new,
                   size + sizeof(MT_mem),
                   PAG_READ|PAG_WRITE|PAG_COMMIT) != NO_ERROR)
      return(NULL); /* may happen. errors are detected in the above layers */

   mt = TSD->mt_tsd;
   new->prev = NULL;
   new->next = mt->mem_base;
   if (mt->mem_base)
      mt->mem_base->prev = new;
   mt->mem_base = new;
   return(new + 1); /* jump over the head */
}

/* Lowest level memory deallocation function for normal circumstances. */
static void MTFree( const RxPackageGlobalDataDef *TSD, void *chunk )
{
   mt_tsd_t *mt = TSD->mt_tsd;
   MT_mem *this;

   /*
    * Just in case...
    */
   if (chunk == NULL)
      return;

   this = chunk;
   this--; /* Go to the header of the chunk */

   if (this->prev)
      if (this->prev->next != this)
         return;
   if (this->next)
      if (this->next->prev != this)
         return;

   /* This is a chunk allocated by MTMalloc */
   if (this->prev)
      this->prev->next = this->next;
   if (this->next)
      this->next->prev = this->prev;
   if (this == mt->mem_base)
      mt->mem_base = this->next;

   /* Last not least we set the pointers to NULL. This prevents a double-free*/
   this->next = NULL;
   this->prev = NULL;
   DosFreeMem(this);
}

/* Lowest level exit handler. */
static void MTExit(int code)
{
   DosExit(EXIT_THREAD,code);
}

/* RxPackInitializeThread creates a new thread structure and returns a ptr
 * to the initialized value.
 * The function may be called more than once.
 */
RxPackageGlobalDataDef *RxPackInitializeThread(void)
{
   RxPackageGlobalDataDef *retval,**ptsd;
   mt_tsd_t *mt;

   /* If you run into trouble here, you must change the code in
    * ReginsSetMutex/RxPackUnsetMutex. The argument there assumes the
    * following rule. This is an ugly hack.
    */
   assert(sizeof_ptr() >= sizeof(HMTX));
   if (sizeof_ptr() < sizeof(HMTX))
      return(NULL); /* Be absolutely sure that we HAVE a problem */

   ptsd = FindThreadDataIdx();
   if (ptsd == NULL) /* can't initialize? */
      return(NULL);

   if (*ptsd != NULL) /* already initialized? */
      return(*ptsd);

   /* First call in this thread, a atexit() per thread will be great, sigh...*/
   retval = malloc(sizeof(RxPackageGlobalDataDef)); /* no Malloc, etc! */

   if (retval == NULL) /* THIS is really a problem. I don't know what we */
      return(NULL);    /* should do now. Let the caller run into a crash... */

   *ptsd = retval;

   memset(retval,0,sizeof(RxPackageGlobalDataDef));
   retval->MTMalloc = (void *)MTMalloc;
   retval->MTFree = (void *)MTFree;
   retval->MTExit = (void *)MTExit;

   /* Since the local data structure contains a Heap object for the memory
    * management we initialize it first.
    */
   if ((mt = malloc(sizeof(mt_tsd_t))) == NULL)
      return(NULL);                     /* This is a catastrophy             */
   retval->mt_tsd = mt;
   mt->mem_base = NULL;

   if ( !INIT_RXPACKAGE( retval ) )
      return(NULL);

#if defined(__WATCOMC__)
   retval->thread_id = *_threadid;
#else
   retval->thread_id = _gettid();
#endif

   return(retval);
}

/* __rxpack_get_tsd returns a pointer to the thread specific data. Be sure to
 * calls this after a RxPackInitializeThread only.
 */
RxPackageGlobalDataDef *__rxpack_get_tsd(void)
{
   /* See above for comments */
   return(*FindThreadDataIdx());
}

/* RxPackSetMutex is the opposite of RxPackUnsetMutex and sets a mutex
 * variable. The "true" mutex is "*arg" since we have hidden the type
 * HMTX which is the correct type. Thus, we have used "HMTX" and
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
   HMTX *os2_mutex = (HMTX *) mutex;

   if (*os2_mutex == (HMTX) 0)
   {
      DosEnterCritSec();
      if (*os2_mutex == (HMTX) 0) /* may have changed due MT */
      {
         if (DosCreateMutexSem(NULL,os2_mutex,0,FALSE) != NO_ERROR)
            OK = 0;
      }
      DosExitCritSec();
      if (!OK)
      { /* We must die now! There is no other chance. */
         *((int *) NULL) = 1;
      }
   }

   DosRequestMutexSem(*os2_mutex,SEM_INDEFINITE_WAIT);
   /* ignore errors, we continue especially if ERROR_INTERRUPTED occurs.
    * FIXME, ignoring ERROR_INTERRUPTED OK?
    */
}

/* see RxPackSetMutex */
void RxPackUnsetMutex(void **mutex)
{
   HMTX *os2_mutex = (HMTX *) mutex;

   DosReleaseMutexSem(*os2_mutex);
}

/* get our thread id */
unsigned long RxPackGetThreadID(void)
{
#if defined(__WATCOMC__)
   return (unsigned long)*_threadid;
#else
   return (unsigned long)_gettid();
#endif
}
