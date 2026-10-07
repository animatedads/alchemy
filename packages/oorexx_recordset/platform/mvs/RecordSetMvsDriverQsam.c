#include "RecordSetMvsDriver.h"
#include "RecordSetMvsQsam.h"

extern void *calloc(rs_size_t, rs_size_t);
extern void free(void *);
extern rs_size_t strlen(const char *);

#define DRIVER_DD_MAX 8

typedef struct QsamDriverHandle
{
    void *qsamHandle;
    int mode;
    char ddName[DRIVER_DD_MAX + 1];
} QsamDriverHandle;

static void set_error(char *buffer, rs_size_t capacity, const char *text)
{
    rs_size_t i;
    if (buffer == 0 || capacity == 0) return;
    if (text == 0) text = "";
    i = 0;
    while (i + 1 < capacity && text[i] != '\0')
    {
        buffer[i] = text[i];
        ++i;
    }
    buffer[i] = '\0';
}

static void copy_text(char *out, rs_size_t capacity, const char *in)
{
    rs_size_t i;
    if (out == 0 || capacity == 0) return;
    i = 0;
    if (in != 0)
    {
        while (i + 1 < capacity && in[i] != '\0')
        {
            out[i] = in[i];
            ++i;
        }
    }
    out[i] = '\0';
}

static int map_qsam_status(int rc, char *error, rs_size_t errorCapacity,
                           const char *operation)
{
    if (rc == MVSRS_QSAM_OK)
    {
        set_error(error, errorCapacity, "");
        return MVSRS_DRIVER_OK;
    }
    if (rc == MVSRS_QSAM_EOF)
    {
        set_error(error, errorCapacity, "");
        return MVSRS_DRIVER_EOF;
    }
    if (rc == MVSRS_QSAM_UNSUPPORTED)
    {
        set_error(error, errorCapacity, operation);
        return MVSRS_DRIVER_UNSUPPORTED;
    }
    set_error(error, errorCapacity, operation);
    return MVSRS_DRIVER_ERROR;
}

int mvsrs_driver_open(const MvsRecordSetOpenRequest *request,
                      MvsRecordSetDriverHandle *handle,
                      MvsRecordSetOpenInfo *info,
                      char *error, rs_size_t errorCapacity)
{
    QsamDriverHandle *h;
    MvsRecordSetQsamInfo qinfo;
    int qmode;
    int rc;

    if (handle != 0) *handle = 0;
    if (request == 0 || handle == 0 || info == 0)
    {
        set_error(error, errorCapacity, "QSAM open requires request, handle and info");
        return MVSRS_DRIVER_ERROR;
    }

    /* dev3 is deliberately the caller-allocated-DD slice. */
    if (request->resourceKind != MVSRS_RESOURCE_DD ||
        request->ddName == 0 || request->ddName[0] == '\0')
    {
        set_error(error, errorCapacity,
                  "QSAM dev3 opens caller-allocated DD resources only");
        return MVSRS_DRIVER_UNSUPPORTED;
    }

    if (request->mode == RS_MODE_READ) qmode = MVSRS_QSAM_READ;
    else if (request->mode == RS_MODE_WRITE) qmode = MVSRS_QSAM_WRITE;
    else if (request->mode == RS_MODE_APPEND) qmode = MVSRS_QSAM_APPEND;
    else
    {
        set_error(error, errorCapacity, "Invalid QSAM RecordSet mode");
        return MVSRS_DRIVER_ERROR;
    }

    h = (QsamDriverHandle *)calloc(1, sizeof(QsamDriverHandle));
    if (h == 0)
    {
        set_error(error, errorCapacity, "QSAM driver handle allocation failed");
        return MVSRS_DRIVER_ERROR;
    }
    copy_text(h->ddName, sizeof(h->ddName), request->ddName);
    h->mode = request->mode;

    qinfo.logicalRecordLength = 0;
    qinfo.blockSize = 0;
    qinfo.recordFormatCode = 0;
    rc = rqopen(h->ddName, qmode, &h->qsamHandle, &qinfo);
    if (rc != MVSRS_QSAM_OK)
    {
        free(h);
        return map_qsam_status(rc, error, errorCapacity, "MVS QSAM OPEN failed");
    }

    copy_text(info->organization, sizeof(info->organization), "PS");
    /* DCBRECFM: top two bits are F/V/U and X'10' is blocked. */
    if ((qinfo.recordFormatCode & 0xC0UL) == 0x80UL)
        copy_text(info->recordFormat, sizeof(info->recordFormat),
                  (qinfo.recordFormatCode & 0x10UL) ? "FB" : "F");
    else if ((qinfo.recordFormatCode & 0xC0UL) == 0x40UL)
        copy_text(info->recordFormat, sizeof(info->recordFormat),
                  (qinfo.recordFormatCode & 0x10UL) ? "VB" : "V");
    else if ((qinfo.recordFormatCode & 0xC0UL) == 0xC0UL)
        copy_text(info->recordFormat, sizeof(info->recordFormat), "U");
    else
        copy_text(info->recordFormat, sizeof(info->recordFormat), "UNKNOWN");
    info->logicalRecordLength = qinfo.logicalRecordLength;
    info->blockSize = qinfo.blockSize;
    info->allocationOwned = 0; /* caller allocated the DD */
    *handle = h;
    set_error(error, errorCapacity, "");
    return MVSRS_DRIVER_OK;
}

int mvsrs_driver_close(MvsRecordSetDriverHandle handle, int releaseAllocation,
                       char *error, rs_size_t errorCapacity)
{
    QsamDriverHandle *h = (QsamDriverHandle *)handle;
    int rc;
    (void)releaseAllocation;
    if (h == 0)
    {
        set_error(error, errorCapacity, "");
        return MVSRS_DRIVER_OK;
    }
    rc = rqclose(h->qsamHandle);
    free(h);
    return map_qsam_status(rc, error, errorCapacity, "MVS QSAM CLOSE failed");
}

int mvsrs_driver_read(MvsRecordSetDriverHandle handle,
                      unsigned char *buffer, rs_size_t capacity,
                      rs_size_t *actualLength,
                      char *error, rs_size_t errorCapacity)
{
    QsamDriverHandle *h = (QsamDriverHandle *)handle;
    int rc;
    if (actualLength != 0) *actualLength = 0;
    if (h == 0 || h->mode != RS_MODE_READ || buffer == 0 || actualLength == 0)
    {
        set_error(error, errorCapacity, "Invalid MVS QSAM READ request");
        return MVSRS_DRIVER_ERROR;
    }
    rc = rqread(h->qsamHandle, buffer, capacity, actualLength);
    return map_qsam_status(rc, error, errorCapacity, "MVS QSAM GET failed");
}

int mvsrs_driver_write(MvsRecordSetDriverHandle handle,
                       const unsigned char *record, rs_size_t length,
                       char *error, rs_size_t errorCapacity)
{
    QsamDriverHandle *h = (QsamDriverHandle *)handle;
    int rc;
    if (h == 0 || (h->mode != RS_MODE_WRITE && h->mode != RS_MODE_APPEND) ||
        (record == 0 && length != 0))
    {
        set_error(error, errorCapacity, "Invalid MVS QSAM WRITE request");
        return MVSRS_DRIVER_ERROR;
    }
    rc = rqwrite(h->qsamHandle, record, length);
    return map_qsam_status(rc, error, errorCapacity, "MVS QSAM PUT failed");
}

int mvsrs_driver_rewind(MvsRecordSetDriverHandle handle,
                        char *error, rs_size_t errorCapacity)
{
    QsamDriverHandle *h = (QsamDriverHandle *)handle;
    int rc;
    if (h == 0 || h->mode != RS_MODE_READ)
    {
        set_error(error, errorCapacity, "Invalid MVS QSAM rewind request");
        return MVSRS_DRIVER_ERROR;
    }
    rc = rqrewind(h->qsamHandle);
    return map_qsam_status(rc, error, errorCapacity, "MVS QSAM rewind failed");
}

int mvsrs_driver_record_count(MvsRecordSetDriverHandle handle,
                              rs_size_t *count,
                              char *error, rs_size_t errorCapacity)
{
    (void)handle;
    if (count != 0) *count = 0;
    set_error(error, errorCapacity, "");
    /* Sequential QSAM does not have an intrinsic cheap record count. */
    return MVSRS_DRIVER_UNKNOWN;
}
