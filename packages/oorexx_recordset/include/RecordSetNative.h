#ifndef OOREXX_RECORDSET_NATIVE_H
#define OOREXX_RECORDSET_NATIVE_H

/* Native ABI size type: natural unsigned address/container width for the host.
 * MVS 3.8J/cc370 uses 4-byte unsigned long containers while effective
 * addressing remains 24-bit. */
#if defined(_WIN64)
typedef unsigned long long rs_size_t;
#else
typedef unsigned long rs_size_t;
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct RecordSetHandle RecordSetHandle;

enum RecordSetMode
{
    RS_MODE_READ = 1,
    RS_MODE_WRITE = 2,
    RS_MODE_APPEND = 3
};

enum RecordSetStatus
{
    RS_STATUS_OK = 0,
    RS_STATUS_EOF = 1,
    RS_STATUS_UNKNOWN = 2,
    RS_STATUS_ERROR = 3
};

enum RecordSetTextMetadata
{
    RS_META_NAME = 1,
    RS_META_DD_NAME = 2,
    RS_META_DATASET_NAME = 3,
    RS_META_MEMBER_NAME = 4,
    RS_META_ORGANIZATION = 5,
    RS_META_RECORD_FORMAT = 6
};

enum RecordSetNumberMetadata
{
    RS_META_LRECL = 101,
    RS_META_BLKSIZE = 102
};

/* Error buffers are optional.  When supplied, they are always NUL terminated. */
int rs_mode_from_text(const char *text, int *mode);
int rs_open(const char *resource, int mode, RecordSetHandle **handle,
            char *error, rs_size_t errorCapacity);
void rs_close(RecordSetHandle *handle);
int rs_is_open(const RecordSetHandle *handle);

/*
 * rs_read_record allocates one record payload.  The caller must release it
 * with rs_free_record().  Zero-length records have length==0 but still return
 * RS_STATUS_OK.  End-of-data is RS_STATUS_EOF and is therefore unambiguous.
 */
int rs_read_record(RecordSetHandle *handle, unsigned char **data, rs_size_t *length,
                   char *error, rs_size_t errorCapacity);
void rs_free_record(void *data);

int rs_write_record(RecordSetHandle *handle, const unsigned char *data, rs_size_t length,
                    char *error, rs_size_t errorCapacity);

/* One-based logical position of the next record.  count+1 is the EOF position. */
int rs_position_record(RecordSetHandle *handle, rs_size_t oneBasedRecord,
                       char *error, rs_size_t errorCapacity);
rs_size_t rs_record_number(const RecordSetHandle *handle);
int rs_record_count(const RecordSetHandle *handle, rs_size_t *count,
                    char *error, rs_size_t errorCapacity);
int rs_eof(const RecordSetHandle *handle);

/* Text metadata returns required bytes (excluding NUL) through actualLength. */
int rs_text_metadata(const RecordSetHandle *handle, int key,
                     char *buffer, rs_size_t capacity, rs_size_t *actualLength);
int rs_number_metadata(const RecordSetHandle *handle, int key, rs_size_t *value);
int rs_is_native_recordset(const RecordSetHandle *handle);

#ifdef __cplusplus
}
#endif

#endif
