#include "RecordSetNative.h"

static int prefix(const unsigned char *p, rs_size_t n, const char *s)
{
    rs_size_t i;
    if (p == 0 || s == 0) return 0;
    i = 0;
    while (s[i] != '\0')
    {
        if (i >= n || p[i] != (unsigned char)s[i]) return 0;
        ++i;
    }
    return 1;
}

int main(void)
{
    RecordSetHandle *in;
    RecordSetHandle *out;
    unsigned char *record;
    rs_size_t length;
    char error[160];
    int rc;

    in = 0;
    out = 0;
    record = 0;
    length = 0;

    rc = rs_open("DD:RSIN", RS_MODE_READ, &in, error, sizeof(error));
    if (rc != RS_STATUS_OK) return 20;
    rc = rs_read_record(in, &record, &length, error, sizeof(error));
    if (rc != RS_STATUS_OK) { rs_close(in); return 21; }
    if (!prefix(record, length, "ALPHA")) { rs_free_record(record); rs_close(in); return 22; }
    rs_free_record(record);
    record = 0;
    if (rs_position_record(in, 1, error, sizeof(error)) != RS_STATUS_OK) { rs_close(in); return 23; }
    rc = rs_read_record(in, &record, &length, error, sizeof(error));
    if (rc != RS_STATUS_OK || !prefix(record, length, "ALPHA")) { if (record) rs_free_record(record); rs_close(in); return 24; }
    rs_free_record(record);
    rs_close(in);

    rc = rs_open("DD:RSOUT", RS_MODE_WRITE, &out, error, sizeof(error));
    if (rc != RS_STATUS_OK) return 30;
    if (rs_write_record(out, (const unsigned char *)"ONE", 3, error, sizeof(error)) != RS_STATUS_OK) { rs_close(out); return 31; }
    if (rs_write_record(out, (const unsigned char *)"TWO", 3, error, sizeof(error)) != RS_STATUS_OK) { rs_close(out); return 32; }
    rs_close(out);
    return 0;
}
