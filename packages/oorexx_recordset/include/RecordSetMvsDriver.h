#ifndef OOREXX_RECORDSET_MVS_DRIVER_H
#define OOREXX_RECORDSET_MVS_DRIVER_H

#include "RecordSetNative.h"

#ifdef __cplusplus
extern "C" {
#endif

enum MvsRecordSetResourceKind
{
    MVSRS_RESOURCE_DD = 1,
    MVSRS_RESOURCE_DATASET = 2,
    MVSRS_RESOURCE_MEMBER = 3
};

enum MvsRecordSetDriverStatus
{
    MVSRS_DRIVER_OK = 0,
    MVSRS_DRIVER_EOF = 1,
    MVSRS_DRIVER_UNKNOWN = 2,
    MVSRS_DRIVER_UNSUPPORTED = 3,
    MVSRS_DRIVER_ERROR = 4
};

typedef struct MvsRecordSetOpenRequest
{
    int resourceKind;
    int mode;
    const char *ddName;
    const char *dataSetName;
    const char *memberName;
} MvsRecordSetOpenRequest;

typedef struct MvsRecordSetOpenInfo
{
    char organization[9];
    char recordFormat[9];
    rs_size_t logicalRecordLength;
    rs_size_t blockSize;
    int allocationOwned;
} MvsRecordSetOpenInfo;

typedef void *MvsRecordSetDriverHandle;

/*
 * Native MVS record driver contract.
 *
 * This ABI is intentionally C-only.  The eventual MVS implementation may be
 * assembler, C, or a mixture, but MUST expose logical records: callers never
 * see BDWs/RDWs and never receive blocked physical buffers for FB/VB data.
 *
 * A DD supplied by the caller has allocationOwned == 0.  A driver which
 * dynamically allocates a dataset/member may report allocationOwned == 1;
 * close() then receives releaseAllocation == 1.
 */
int mvsrs_driver_open(const MvsRecordSetOpenRequest *request,
                      MvsRecordSetDriverHandle *handle,
                      MvsRecordSetOpenInfo *info,
                      char *error, rs_size_t errorCapacity);
int mvsrs_driver_close(MvsRecordSetDriverHandle handle, int releaseAllocation,
                       char *error, rs_size_t errorCapacity);
int mvsrs_driver_read(MvsRecordSetDriverHandle handle,
                      unsigned char *buffer, rs_size_t capacity,
                      rs_size_t *actualLength,
                      char *error, rs_size_t errorCapacity);
int mvsrs_driver_write(MvsRecordSetDriverHandle handle,
                       const unsigned char *record, rs_size_t length,
                       char *error, rs_size_t errorCapacity);

/* Sequential datasets need not support arbitrary seek.  rewind() is enough
 * for RecordSet to implement record positioning by rewind-and-skip. */
int mvsrs_driver_rewind(MvsRecordSetDriverHandle handle,
                        char *error, rs_size_t errorCapacity);

/* Optional.  UNKNOWN is valid for sequential resources whose count would
 * require a complete scan. */
int mvsrs_driver_record_count(MvsRecordSetDriverHandle handle,
                              rs_size_t *count,
                              char *error, rs_size_t errorCapacity);

#ifdef __cplusplus
}
#endif

#endif
