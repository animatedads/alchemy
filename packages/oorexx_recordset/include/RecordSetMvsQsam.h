#ifndef OOREXX_RECORDSET_MVS_QSAM_H
#define OOREXX_RECORDSET_MVS_QSAM_H

#include "RecordSetNative.h"

/*
 * Very small cc370 <-> assembler ABI.
 *
 * The external routine names intentionally contain no underscore and are no
 * longer than eight characters, matching the classic MVS external-name limit.
 * These routines deal only in caller-allocated DD names.  Dataset allocation
 * remains a separate service above/beside this bridge.
 */

#define MVSRS_QSAM_OK          0
#define MVSRS_QSAM_EOF         4
#define MVSRS_QSAM_ERROR       8
#define MVSRS_QSAM_UNSUPPORTED 12

#define MVSRS_QSAM_READ   1
#define MVSRS_QSAM_WRITE  2
#define MVSRS_QSAM_APPEND 3

typedef struct MvsRecordSetQsamInfo
{
    /* Raw OPEN-populated DCB metadata.  Keep this structure word-oriented so
     * the assembler bridge does not depend on C structure packing rules. */
    rs_size_t logicalRecordLength;
    rs_size_t blockSize;
    unsigned long recordFormatCode;
} MvsRecordSetQsamInfo;

#ifdef __cplusplus
extern "C" {
#endif

/* Short names are the actual linkage contract with RecordSetMvsQsam.asm. */
int rqopen(const char *ddName, int mode, void **nativeHandle,
           MvsRecordSetQsamInfo *info);
int rqclose(void *nativeHandle);
int rqread(void *nativeHandle, unsigned char *buffer,
           rs_size_t capacity, rs_size_t *actualLength);
int rqwrite(void *nativeHandle, const unsigned char *record,
            rs_size_t length);
int rqrewind(void *nativeHandle);

#ifdef __cplusplus
}
#endif

#endif
