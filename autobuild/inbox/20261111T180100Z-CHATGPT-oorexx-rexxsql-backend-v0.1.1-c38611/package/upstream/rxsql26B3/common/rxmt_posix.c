/* This is the file to support POSIX threads.
 * We initialize the global data structure and the global access variable.
 */

#define DONT_TYPEDEF_PFN
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pwd.h>
#include <time.h>
#include <errno.h>

#include "rxmt.h"

typedef struct _MT_mem
{
   struct _MT_mem *prev;
   struct _MT_mem *next;
   /* real data follows here */
} MT_mem;

/* mt_tsd: static variables of this module (thread-safe) */
typedef struct
{
   MT_mem *           mem_base;
} mt_tsd_t; /* thread-specific but only needed by this module. see
             * RxPackInitializeThread
             */

extern void *INIT_RXPACKAGE(RxPackageGlobalDataDef *);
extern void TERM_RXPACKAGE(RxPackageGlobalDataDef *);

static pthread_key_t ThreadIndex; /* index of the TSD, no initial value */
static pthread_once_t ThreadOnce = PTHREAD_ONCE_INIT; /* for pthread_once */
/* RxPackDeinitialize is called when the thread terminates.
 * This is a wonderful position to place code which frees all allocated stuff!
 */
static void RxPackDeinitialize(void *buf)
{
   RxPackageGlobalDataDef *TSD = buf;
   mt_tsd_t *mt;
   MT_mem *chunk;

   if ( TSD == NULL ) /* Should never happen but be sure */
      return;

   TERM_RXPACKAGE( TSD );

   mt = TSD->mt_tsd;
   if ( mt )
   {
      while( (chunk = mt->mem_base) != NULL )
      {
         TSD->MTFree( TSD, chunk + 1 );
         if ( mt->mem_base == chunk )
            break; /* something goes wrong. Don't run into an endless loop */
      }
   }
   if ( mt )
      free( mt );
   free( TSD );
}

/* ThreadGetKey creates a new index key into the TSD table. This function
 * must only be used by pthread_once.
 */
static void ThreadGetKey(void)
{
   pthread_key_create( &ThreadIndex, RxPackDeinitialize );
}

/* Lowest level memory allocation function for normal circumstances. */
static void *MTMalloc( const RxPackageGlobalDataDef *TSD, size_t size )
{
   mt_tsd_t *mt;
   MT_mem *new = malloc( size + sizeof(MT_mem) );

   if ( new == NULL ) /* may happen. errors are detected in the above layers */
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
   if (chunk == NULL)
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

/* Lowest level exit handler. */
static void MTExit(int code)
{
   /* pthread_exit's argument has a different semantic as exit has. */
   pthread_exit(NULL);
}

/* RxPackInitializeThread creates a new thread structure and returns a ptr
 * to the initialized value.
 * The function may be called more than once.
 * This function needs to be renamed for each external function package in the
 * package's Makefile: -DRxPackInitializeThread=$(PACKAGE)RxPackInitializeThread
 * otherwise multiple external function packages in the one program on the Mac
 * will crash!
 */
RxPackageGlobalDataDef *RxPackInitializeThread(void)
{
   RxPackageGlobalDataDef *retval;

   /* get a unique access variable for the whole process */
   pthread_once( &ThreadOnce, ThreadGetKey );

   /* fetch the value of the access variable */
   retval = pthread_getspecific( ThreadIndex );

   if ( retval != NULL )
      return(retval);
   /* First call in this thread... */
   retval = malloc( sizeof(RxPackageGlobalDataDef) ); /* no Malloc, etc! */

   if ( retval == NULL ) /* THIS is really a problem. I don't know what we */
      return(NULL);    /* should do now. Let the caller run into a crash... */
   pthread_setspecific( ThreadIndex, retval );

   memset( retval, 0, sizeof(RxPackageGlobalDataDef) );
   retval->MTMalloc = MTMalloc;
   retval->MTFree = MTFree;
   retval->MTExit = MTExit;

   /* Since the local data structure contains a memory chain for the memory
    * management we initialize it first.
    */
   if ( ( retval->mt_tsd = malloc( sizeof(mt_tsd_t) ) ) == NULL )
      return(NULL);                     /* This is a catastrophy             */
   memset( retval->mt_tsd, 0, sizeof(mt_tsd_t) );

   if ( !INIT_RXPACKAGE( retval ) )
      return(NULL);

   retval->thread_id = (unsigned long)pthread_self();

   return(retval);
}

/* __rxpack_get_tsd returns a pointer to the thread specific data. Be sure to
 * calls this after a RxPackInitializeThread only.
 * MUST be renamed; see comment above
 */
RxPackageGlobalDataDef *__rxpack_get_tsd(void)
{
   /* See above for comments */
   return(pthread_getspecific( ThreadIndex ));
}

/* get our thread id */
unsigned long RxPackGetThreadID(void)
{
   return (unsigned long)pthread_self();
}
