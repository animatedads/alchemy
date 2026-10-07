#include "RecordSetNative.h"
#include "RecordSetMvsDriver.h"

/* Keep the MVS backend independent of a host-header set.  cc370 supplies the
 * runtime symbols, while this translation unit needs only their C89 ABI. */
extern void *malloc(rs_size_t);
extern void *calloc(rs_size_t, rs_size_t);
extern void free(void *);
extern rs_size_t strlen(const char *);
extern void *memcpy(void *, const void *, rs_size_t);
extern void *memset(void *, int, rs_size_t);
extern char *strcpy(char *, const char *);

#define RS_MVS_NAME_MAX 128
#define RS_MVS_DD_MAX 8
#define RS_MVS_MEMBER_MAX 8
#define RS_MVS_FALLBACK_LRECL 32760UL

struct RecordSetHandle
{
    int opened;
    int eof;
    int ownsAllocation;
    int mode;
    int resourceKind;
    rs_size_t nextRecord;
    MvsRecordSetDriverHandle nativeHandle;
    char resource[RS_MVS_NAME_MAX + 16];
    char ddName[RS_MVS_DD_MAX + 1];
    char dataSetName[RS_MVS_NAME_MAX + 1];
    char memberName[RS_MVS_MEMBER_MAX + 1];
    char organization[9];
    char recordFormat[9];
    rs_size_t lrecl;
    rs_size_t blockSize;
};

static void set_error(char *buffer, rs_size_t capacity, const char *message)
{
    rs_size_t i;
    if (buffer == 0 || capacity == 0) return;
    if (message == 0) message = "";
    i = 0;
    while (i + 1 < capacity && message[i] != '\0')
    {
        buffer[i] = message[i];
        ++i;
    }
    buffer[i] = '\0';
}

static int native_upper(int c)
{
    /* Written as the three alphabetic groups so this is valid both for
     * ASCII host tests and native EBCDIC MVS execution.  EBCDIC does not
     * place A-Z or a-z in one contiguous numeric range. */
    if ((c >= 'a' && c <= 'i') ||
        (c >= 'j' && c <= 'r') ||
        (c >= 's' && c <= 'z'))
        return c - ('a' - 'A');
    return c;
}

static int native_alpha_upper(int c)
{
    return (c >= 'A' && c <= 'I') ||
           (c >= 'J' && c <= 'R') ||
           (c >= 'S' && c <= 'Z');
}

static int rs_streq_ci(const char *a, const char *b)
{
    if (a == 0 || b == 0) return 0;
    while (*a != '\0' && *b != '\0')
    {
        if (native_upper((unsigned char)*a) != native_upper((unsigned char)*b)) return 0;
        ++a; ++b;
    }
    return *a == *b;
}

static int copy_upper(char *out, rs_size_t capacity, const char *in, rs_size_t length)
{
    rs_size_t i;
    if (out == 0 || capacity == 0 || in == 0 || length + 1 > capacity) return 0;
    for (i = 0; i < length; ++i) out[i] = (char)native_upper((unsigned char)in[i]);
    out[length] = '\0';
    return 1;
}

static int is_dd_first(int c)
{
    c = native_upper(c);
    return native_alpha_upper(c) || c == '@' || c == '#' || c == '$';
}

static int is_dd_rest(int c)
{
    c = native_upper(c);
    return is_dd_first(c) || (c >= '0' && c <= '9');
}

static int valid_dd(const char *name)
{
    rs_size_t i;
    if (name == 0 || name[0] == '\0' || !is_dd_first((unsigned char)name[0])) return 0;
    for (i = 1; name[i] != '\0'; ++i)
    {
        if (i >= RS_MVS_DD_MAX || !is_dd_rest((unsigned char)name[i])) return 0;
    }
    return 1;
}

static int valid_ds_qualifier(const char *s, rs_size_t n)
{
    rs_size_t i;
    if (n == 0 || n > 8 || !is_dd_first((unsigned char)s[0])) return 0;
    for (i = 1; i < n; ++i) if (!is_dd_rest((unsigned char)s[i]) && s[i] != '-') return 0;
    return 1;
}

static int valid_dataset(const char *name)
{
    const char *p, *start;
    if (name == 0 || *name == '\0') return 0;
    p = name;
    start = p;
    while (1)
    {
        if (*p == '.' || *p == '\0')
        {
            if (!valid_ds_qualifier(start, (rs_size_t)(p - start))) return 0;
            if (*p == '\0') break;
            start = p + 1;
        }
        ++p;
    }
    return 1;
}

static int parse_resource(const char *resource, RecordSetHandle *h,
                          char *error, rs_size_t errorCapacity)
{
    const char *start;
    const char *end;
    const char *lp;
    const char *rp;
    rs_size_t n;
    if (resource == 0 || *resource == '\0')
    {
        set_error(error, errorCapacity, "RecordSet resource is empty");
        return RS_STATUS_ERROR;
    }

    n = (rs_size_t)strlen(resource);
    if (n >= sizeof(h->resource))
    {
        set_error(error, errorCapacity, "RecordSet resource name is too long");
        return RS_STATUS_ERROR;
    }
    strcpy(h->resource, resource);

    if (n >= 3 && native_upper((unsigned char)resource[0]) == 'D' &&
        native_upper((unsigned char)resource[1]) == 'D' && resource[2] == ':')
    {
        if (!copy_upper(h->ddName, sizeof(h->ddName), resource + 3, n - 3) || !valid_dd(h->ddName))
        {
            set_error(error, errorCapacity, "Invalid MVS DD name");
            return RS_STATUS_ERROR;
        }
        h->resourceKind = MVSRS_RESOURCE_DD;
        return RS_STATUS_OK;
    }

    start = resource;
    end = resource + n;
    if (n >= 2 && resource[0] == '\'' && resource[n - 1] == '\'')
    {
        ++start;
        --end;
    }
    if (start == end)
    {
        set_error(error, errorCapacity, "Empty MVS dataset name");
        return RS_STATUS_ERROR;
    }

    lp = 0;
    rp = 0;
    {
        const char *p;
        for (p = start; p < end; ++p)
        {
            if (*p == '(')
            {
                if (lp != 0) { set_error(error,errorCapacity,"Invalid dataset member syntax"); return RS_STATUS_ERROR; }
                lp = p;
            }
            else if (*p == ')') rp = p;
        }
    }

    if (lp != 0)
    {
        if (rp != end - 1 || rp <= lp + 1)
        {
            set_error(error, errorCapacity, "Invalid dataset member syntax");
            return RS_STATUS_ERROR;
        }
        if (!copy_upper(h->dataSetName, sizeof(h->dataSetName), start, (rs_size_t)(lp - start)) ||
            !copy_upper(h->memberName, sizeof(h->memberName), lp + 1, (rs_size_t)(rp - lp - 1)))
        {
            set_error(error, errorCapacity, "Dataset or member name is too long");
            return RS_STATUS_ERROR;
        }
        if (!valid_dataset(h->dataSetName) || !valid_dd(h->memberName))
        {
            set_error(error, errorCapacity, "Invalid MVS dataset or member name");
            return RS_STATUS_ERROR;
        }
        h->resourceKind = MVSRS_RESOURCE_MEMBER;
    }
    else
    {
        if (rp != 0 || !copy_upper(h->dataSetName, sizeof(h->dataSetName), start, (rs_size_t)(end - start)) ||
            !valid_dataset(h->dataSetName))
        {
            set_error(error, errorCapacity, "Invalid MVS dataset name");
            return RS_STATUS_ERROR;
        }
        h->resourceKind = MVSRS_RESOURCE_DATASET;
    }
    return RS_STATUS_OK;
}

int rs_mode_from_text(const char *text, int *mode)
{
    if (mode == 0) return RS_STATUS_ERROR;
    if (text == 0 || *text == '\0' || rs_streq_ci(text, "READ") || rs_streq_ci(text, "R"))
    { *mode = RS_MODE_READ; return RS_STATUS_OK; }
    if (rs_streq_ci(text, "WRITE") || rs_streq_ci(text, "W"))
    { *mode = RS_MODE_WRITE; return RS_STATUS_OK; }
    if (rs_streq_ci(text, "APPEND") || rs_streq_ci(text, "A"))
    { *mode = RS_MODE_APPEND; return RS_STATUS_OK; }
    return RS_STATUS_ERROR;
}

int rs_open(const char *resource, int mode, RecordSetHandle **outHandle,
            char *error, rs_size_t errorCapacity)
{
    RecordSetHandle *h;
    MvsRecordSetOpenRequest request;
    MvsRecordSetOpenInfo info;
    int rc;
    if (outHandle == 0) { set_error(error,errorCapacity,"RecordSet open requires a handle result"); return RS_STATUS_ERROR; }
    *outHandle = 0;
    if (mode != RS_MODE_READ && mode != RS_MODE_WRITE && mode != RS_MODE_APPEND)
    { set_error(error,errorCapacity,"Invalid RecordSet mode"); return RS_STATUS_ERROR; }

    h = (RecordSetHandle *)calloc(1, sizeof(RecordSetHandle));
    if (h == 0) { set_error(error,errorCapacity,"RecordSet handle allocation failed"); return RS_STATUS_ERROR; }
    h->mode = mode;
    h->nextRecord = 1;
    if (parse_resource(resource,h,error,errorCapacity) != RS_STATUS_OK) { free(h); return RS_STATUS_ERROR; }

    memset(&request,0,sizeof(request));
    memset(&info,0,sizeof(info));
    request.resourceKind = h->resourceKind;
    request.mode = mode;
    request.ddName = h->ddName[0] ? h->ddName : 0;
    request.dataSetName = h->dataSetName[0] ? h->dataSetName : 0;
    request.memberName = h->memberName[0] ? h->memberName : 0;

    rc = mvsrs_driver_open(&request,&h->nativeHandle,&info,error,errorCapacity);
    if (rc != MVSRS_DRIVER_OK)
    {
        free(h);
        return RS_STATUS_ERROR;
    }
    h->ownsAllocation = info.allocationOwned;
    copy_upper(h->organization,sizeof(h->organization),info.organization,(rs_size_t)strlen(info.organization));
    copy_upper(h->recordFormat,sizeof(h->recordFormat),info.recordFormat,(rs_size_t)strlen(info.recordFormat));
    h->lrecl = info.logicalRecordLength;
    h->blockSize = info.blockSize;
    h->opened = 1;
    *outHandle = h;
    set_error(error,errorCapacity,"");
    return RS_STATUS_OK;
}

void rs_close(RecordSetHandle *h)
{
    char ignored[2];
    if (h == 0) return;
    if (h->opened && h->nativeHandle != 0)
        (void)mvsrs_driver_close(h->nativeHandle,h->ownsAllocation,ignored,sizeof(ignored));
    h->opened = 0;
    free(h);
}

int rs_is_open(const RecordSetHandle *h) { return h != 0 && h->opened; }

int rs_read_record(RecordSetHandle *h, unsigned char **data, rs_size_t *length,
                   char *error, rs_size_t errorCapacity)
{
    unsigned char *buffer;
    rs_size_t capacity, actual;
    int rc;
    if (data) *data = 0;
    if (length) *length = 0;
    if (h == 0 || !h->opened) { set_error(error,errorCapacity,"RecordSet is closed"); return RS_STATUS_ERROR; }
    if (h->mode != RS_MODE_READ) { set_error(error,errorCapacity,"RecordSet is not open for reading"); return RS_STATUS_ERROR; }

    capacity = h->lrecl != 0 ? h->lrecl : RS_MVS_FALLBACK_LRECL;
    buffer = (unsigned char *)malloc(capacity == 0 ? 1 : capacity);
    if (buffer == 0) { set_error(error,errorCapacity,"RecordSet record allocation failed"); return RS_STATUS_ERROR; }
    actual = 0;
    rc = mvsrs_driver_read(h->nativeHandle,buffer,capacity,&actual,error,errorCapacity);
    if (rc == MVSRS_DRIVER_EOF)
    {
        free(buffer); h->eof = 1; return RS_STATUS_EOF;
    }
    if (rc != MVSRS_DRIVER_OK)
    {
        free(buffer); return RS_STATUS_ERROR;
    }
    if (actual > capacity)
    {
        free(buffer); set_error(error,errorCapacity,"MVS RecordSet driver returned an oversized logical record"); return RS_STATUS_ERROR;
    }
    h->nextRecord++;
    h->eof = 0;
    if (length) *length = actual;
    if (data) *data = buffer; else free(buffer);
    return RS_STATUS_OK;
}

void rs_free_record(void *data) { free(data); }

static int fixed_record_format(const char *format)
{
    return format != 0 && format[0] == 'F';
}

int rs_write_record(RecordSetHandle *h, const unsigned char *data, rs_size_t length,
                    char *error, rs_size_t errorCapacity)
{
    int rc;
    unsigned char *fixed;
    if (h == 0 || !h->opened) { set_error(error,errorCapacity,"RecordSet is closed"); return RS_STATUS_ERROR; }
    if (h->mode == RS_MODE_READ) { set_error(error,errorCapacity,"RecordSet is not open for writing"); return RS_STATUS_ERROR; }
    if (length != 0 && data == 0) { set_error(error,errorCapacity,"RecordSet write has no record data"); return RS_STATUS_ERROR; }

    if (fixed_record_format(h->recordFormat) && h->lrecl != 0)
    {
        rs_size_t i;
        if (length > h->lrecl) { set_error(error,errorCapacity,"Record exceeds fixed MVS LRECL"); return RS_STATUS_ERROR; }
        fixed = (unsigned char *)malloc(h->lrecl == 0 ? 1 : h->lrecl);
        if (fixed == 0) { set_error(error,errorCapacity,"RecordSet fixed-record allocation failed"); return RS_STATUS_ERROR; }
        for (i = 0; i < h->lrecl; ++i) fixed[i] = (unsigned char)0x40; /* EBCDIC blank */
        if (length != 0) memcpy(fixed,data,length);
        rc = mvsrs_driver_write(h->nativeHandle,fixed,h->lrecl,error,errorCapacity);
        free(fixed);
    }
    else
    {
        rs_size_t maximumPayload;
        maximumPayload = h->lrecl;
        /* MVS variable-format LRECL includes the four-byte RDW.  RecordSet
         * exposes the logical payload, so do not let the descriptor become
         * part of the public record length contract. */
        if ((rs_streq_ci(h->recordFormat,"V") || rs_streq_ci(h->recordFormat,"VB")) && maximumPayload >= 4)
            maximumPayload -= 4;
        if (maximumPayload != 0 && length > maximumPayload) { set_error(error,errorCapacity,"Record exceeds MVS maximum logical payload length"); return RS_STATUS_ERROR; }
        rc = mvsrs_driver_write(h->nativeHandle,data,length,error,errorCapacity);
    }
    if (rc != MVSRS_DRIVER_OK) return RS_STATUS_ERROR;
    h->nextRecord++;
    h->eof = 0;
    return RS_STATUS_OK;
}

int rs_position_record(RecordSetHandle *h, rs_size_t oneBasedRecord,
                       char *error, rs_size_t errorCapacity)
{
    rs_size_t n, actual;
    unsigned char *scratch;
    rs_size_t capacity;
    int rc;
    if (h == 0 || !h->opened) { set_error(error,errorCapacity,"RecordSet is closed"); return RS_STATUS_ERROR; }
    if (h->mode != RS_MODE_READ) { set_error(error,errorCapacity,"Record positioning is only defined for input RecordSets"); return RS_STATUS_ERROR; }
    if (oneBasedRecord < 1) { set_error(error,errorCapacity,"RecordSet positions are one-based"); return RS_STATUS_ERROR; }
    if (oneBasedRecord == h->nextRecord) return RS_STATUS_OK;

    rc = mvsrs_driver_rewind(h->nativeHandle,error,errorCapacity);
    if (rc != MVSRS_DRIVER_OK) return RS_STATUS_ERROR;
    h->nextRecord = 1;
    h->eof = 0;
    if (oneBasedRecord == 1) return RS_STATUS_OK;

    capacity = h->lrecl != 0 ? h->lrecl : RS_MVS_FALLBACK_LRECL;
    scratch = (unsigned char *)malloc(capacity == 0 ? 1 : capacity);
    if (scratch == 0) { set_error(error,errorCapacity,"RecordSet positioning buffer allocation failed"); return RS_STATUS_ERROR; }
    for (n = 1; n < oneBasedRecord; ++n)
    {
        actual = 0;
        rc = mvsrs_driver_read(h->nativeHandle,scratch,capacity,&actual,error,errorCapacity);
        if (rc == MVSRS_DRIVER_EOF)
        {
            free(scratch); h->eof = 1; h->nextRecord = n; set_error(error,errorCapacity,"RecordSet position is beyond end of data"); return RS_STATUS_ERROR;
        }
        if (rc != MVSRS_DRIVER_OK) { free(scratch); return RS_STATUS_ERROR; }
        h->nextRecord++;
    }
    free(scratch);
    return RS_STATUS_OK;
}

rs_size_t rs_record_number(const RecordSetHandle *h) { return h == 0 ? 0 : h->nextRecord; }

int rs_record_count(const RecordSetHandle *h, rs_size_t *count,
                    char *error, rs_size_t errorCapacity)
{
    int rc;
    if (count) *count = 0;
    if (h == 0 || !h->opened) { set_error(error,errorCapacity,"RecordSet is closed"); return RS_STATUS_ERROR; }
    rc = mvsrs_driver_record_count(h->nativeHandle,count,error,errorCapacity);
    if (rc == MVSRS_DRIVER_OK) return RS_STATUS_OK;
    if (rc == MVSRS_DRIVER_UNKNOWN || rc == MVSRS_DRIVER_UNSUPPORTED) return RS_STATUS_UNKNOWN;
    return RS_STATUS_ERROR;
}

int rs_eof(const RecordSetHandle *h) { return h != 0 && h->opened && h->eof; }

static const char *text_meta(const RecordSetHandle *h, int key)
{
    if (h == 0) return "";
    switch (key)
    {
        case RS_META_NAME: return h->resource;
        case RS_META_DD_NAME: return h->ddName;
        case RS_META_DATASET_NAME: return h->dataSetName;
        case RS_META_MEMBER_NAME: return h->memberName;
        case RS_META_ORGANIZATION: return h->organization;
        case RS_META_RECORD_FORMAT: return h->recordFormat;
        default: return "";
    }
}

int rs_text_metadata(const RecordSetHandle *h, int key,
                     char *buffer, rs_size_t capacity, rs_size_t *actualLength)
{
    const char *value;
    rs_size_t n, i;
    value = text_meta(h,key);
    n = (rs_size_t)strlen(value);
    if (actualLength) *actualLength = n;
    if (buffer != 0 && capacity != 0)
    {
        i = n < capacity - 1 ? n : capacity - 1;
        if (i != 0) memcpy(buffer,value,i);
        buffer[i] = '\0';
    }
    return RS_STATUS_OK;
}

int rs_number_metadata(const RecordSetHandle *h, int key, rs_size_t *value)
{
    if (h == 0 || value == 0) return RS_STATUS_ERROR;
    if (key == RS_META_LRECL) { *value = h->lrecl; return h->lrecl ? RS_STATUS_OK : RS_STATUS_UNKNOWN; }
    if (key == RS_META_BLKSIZE) { *value = h->blockSize; return h->blockSize ? RS_STATUS_OK : RS_STATUS_UNKNOWN; }
    return RS_STATUS_ERROR;
}

int rs_is_native_recordset(const RecordSetHandle *h) { return h != 0; }
