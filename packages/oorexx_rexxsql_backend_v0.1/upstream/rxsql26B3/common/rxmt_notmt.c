/* This is the file to support single-threading.
 * We initialize the global data structure and the global access variable.
 */

#include "rxpack.h"
#if 0
#define DONT_TYPEDEF_PFN
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#include "rxmt.h"
#endif

typedef struct _MT_mem
{
   struct _MT_mem *prev;
   struct _MT_mem *next;
   /* real data follows here */
} MT_mem;

typedef struct
{ /* mt_tsd: static variables of this module (thread-safe) */
   MT_mem *mem_base;
} mt_tsd_t; /* thread-specific but only needed by this module. see
             * RxPackInitializeThread
             */

int __rxpack_tsd_initialized = 0;
RxPackageGlobalDataDef __rxpack_tsd = {0,}; /* Be sure the var is initialized here   */

extern int INIT_RXPACKAGE(RxPackageGlobalDataDef *);

/* Lowest level memory allocation function for normal circumstances. */
static void *MTMalloc( const RxPackageGlobalDataDef *TSD, long size )
{
   mt_tsd_t *mt;
   MT_mem *new = malloc(size + sizeof(MT_mem));

   if (new == NULL) /* may happen. errors are detected in the above layers */
      return(NULL);

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
   if ( chunk == NULL)
      return;

   this = chunk;
   this--; /* Go to the header of the chunk */

   if (this->prev)
   {
      if (this->prev->next != this)
         return;
   }
   if (this->next)
   {
      if (this->next->prev != this)
         return;
   }

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
   free(this);
}

/* Lowest level exit handler. Use this indirection to prevent errors. */
static void MTExit(int code)
{
   /*
    * Don't actually do anything!!
    */
   code = code;
}

int IfcRxPackCleanup( VOID )
{
   RxPackageGlobalDataDef *TSD = &__rxpack_tsd;
   mt_tsd_t *mt;
   MT_mem *chunk;

   if (!__rxpack_tsd_initialized)
      return 0;

   __rxpack_tsd_initialized = 0;
#if 0
   deinit_rexxsaa(TSD);
#endif
   mt = TSD->mt_tsd;
   if (mt)
   {
      while ((chunk = mt->mem_base) != NULL)
      {
         TSD->MTFree(TSD,chunk + 1);
         if (mt->mem_base == chunk)
            break; /* something goes wrong. Don't run into an endless loop */
      }
   }
   if (mt)
      free(mt);
   memset( TSD, 0, sizeof(RxPackageGlobalDataDef) );
   return 1;
}

RxPackageGlobalDataDef *RxPackInitializeProcess(void)
{
   if (__rxpack_tsd_initialized)
      return(&__rxpack_tsd);
   __rxpack_tsd_initialized = 1;

                                        /* Set up the current (single) tsd_t:*/
                                        /* Default all values to zero        */
   memset( &__rxpack_tsd, 0, sizeof(RxPackageGlobalDataDef) );
   __rxpack_tsd.MTMalloc = MTMalloc;
   __rxpack_tsd.MTFree = MTFree;
   __rxpack_tsd.MTExit = MTExit;

   /* Since the local data structure contains a memory chain for the memory
    * management we initialize it first.
    */
   if ((__rxpack_tsd.mt_tsd = malloc(sizeof(mt_tsd_t))) == NULL)
      return(NULL);                     /* This is a catastrophy             */
   memset(__rxpack_tsd.mt_tsd,0,sizeof(mt_tsd_t));


   if ( !INIT_RXPACKAGE( &__rxpack_tsd ) )
      return(NULL);

   __rxpack_tsd.thread_id = 1;

   return(&__rxpack_tsd);
}

/* get our thread id */
unsigned long RxPackGetThreadID(void)
{
   return (unsigned long)0;
}

#ifdef TRACK_TSD_USAGE
/* We may want to check the counts of calls to __rxpack_get_tsd() which may do
 * MUCH work on different platforms. We do some not optimizable work here.
 * If you really wanna track down all calls to figure out WHERE to
 * optimize try under a GNU friendly system:
 * 1) In Makefile: Add "-pg -a" to the variable called "CFLAGS".
 * 2) "make rexx" (Other targets might not work)
 * 3) "./rexx whatyoulike.rexx"
 * 4) "gprof rexx >usage.lst"
 * 5) look at usage.lst for occurances of "WorkHeavy".
 */

volatile int __rxpack_Calls = 300; /* factor to get a "feel" for multithreading */
volatile int __rxpack_Point = 1;

void __rxpack_Nop(void)
{
   __rxpack_Point = 2;
}

/* WorkHeavy does some work and returns the correct thread-specific data. */
RxPackageGlobalDataDef *__rxpack_WorkHeavy(void)
{
   int todo = __rxpack_Calls;
   while (todo--)
      __rxpack_Nop();
   return(&__rxpack_tsd);
}
#endif
