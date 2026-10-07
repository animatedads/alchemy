#include "RecordSetMvsQsam.h"
#include <stdlib.h>
#include <string.h>

typedef struct FakeQsam
{
    int index;
    int mode;
} FakeQsam;

static const char *records[] = { "ONE", "TWO", "", "FOUR" };
static int openCount;
static int closeCount;
static int writeCount;
static rs_size_t lastWriteLength;
static unsigned char lastWriteTail;

int rqopen(const char *ddName, int mode, void **nativeHandle,
           MvsRecordSetQsamInfo *info)
{
    FakeQsam *h;
    if (ddName == 0 || (strcmp(ddName, "INPUT") != 0 && strcmp(ddName, "VARIN") != 0) ||
        nativeHandle == 0 || info == 0)
        return MVSRS_QSAM_ERROR;
    h = (FakeQsam *)calloc(1, sizeof(FakeQsam));
    if (h == 0) return MVSRS_QSAM_ERROR;
    h->mode = mode;
    *nativeHandle = h;
    info->logicalRecordLength = 80;
    info->blockSize = 3120;
    info->recordFormatCode = strcmp(ddName, "VARIN") == 0 ? 0x50UL : 0x90UL; /* VB or FB */
    ++openCount;
    return MVSRS_QSAM_OK;
}

int rqclose(void *nativeHandle)
{
    if (nativeHandle == 0) return MVSRS_QSAM_ERROR;
    free(nativeHandle);
    ++closeCount;
    return MVSRS_QSAM_OK;
}

int rqread(void *nativeHandle, unsigned char *buffer,
           rs_size_t capacity, rs_size_t *actualLength)
{
    FakeQsam *h = (FakeQsam *)nativeHandle;
    rs_size_t n;
    if (h == 0 || h->mode != MVSRS_QSAM_READ || actualLength == 0) return MVSRS_QSAM_ERROR;
    if (h->index >= 4) return MVSRS_QSAM_EOF;
    n = (rs_size_t)strlen(records[h->index]);
    if (n > capacity) return MVSRS_QSAM_ERROR;
    if (n != 0) memcpy(buffer, records[h->index], n);
    *actualLength = n;
    ++h->index;
    return MVSRS_QSAM_OK;
}

int rqwrite(void *nativeHandle, const unsigned char *record, rs_size_t length)
{
    FakeQsam *h = (FakeQsam *)nativeHandle;
    if (h == 0 || (h->mode != MVSRS_QSAM_WRITE && h->mode != MVSRS_QSAM_APPEND))
        return MVSRS_QSAM_ERROR;
    ++writeCount;
    lastWriteLength = length;
    lastWriteTail = (record != 0 && length != 0) ? record[length - 1] : 0;
    return MVSRS_QSAM_OK;
}

int rqrewind(void *nativeHandle)
{
    FakeQsam *h = (FakeQsam *)nativeHandle;
    if (h == 0 || h->mode != MVSRS_QSAM_READ) return MVSRS_QSAM_ERROR;
    h->index = 0;
    return MVSRS_QSAM_OK;
}

int qfake_open_count(void) { return openCount; }
int qfake_close_count(void) { return closeCount; }
int qfake_write_count(void) { return writeCount; }
rs_size_t qfake_last_write_length(void) { return lastWriteLength; }
int qfake_last_write_tail(void) { return (int)lastWriteTail; }
