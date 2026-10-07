#include "RecordSetNative.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fstream>
#include <sstream>
#include <string>
#include <vector>

struct RecordSetHandle
{
    bool opened;
    bool dirty;
    int mode;
    rs_size_t nextIndex;
    std::string path;
    std::vector<std::string> records;

    RecordSetHandle() : opened(false), dirty(false), mode(RS_MODE_READ), nextIndex(0) { }
};

static void set_error(char *buffer, rs_size_t capacity, const char *message)
{
    if (buffer == NULL || capacity == 0) return;
    if (message == NULL) message = "";
    rs_size_t i = 0;
    while (i + 1 < capacity && message[i] != '\0')
    {
        buffer[i] = message[i];
        ++i;
    }
    buffer[i] = '\0';
}

static void split_records(RecordSetHandle *h, const std::string &bytes)
{
    std::string current;
    rs_size_t i;
    for (i = 0; i < bytes.size(); ++i)
    {
        char c = bytes[i];
        if (c == '\n')
        {
            if (!current.empty() && current[current.size() - 1] == '\r')
            {
                current.erase(current.size() - 1);
            }
            h->records.push_back(current);
            current.clear();
        }
        else
        {
            current.push_back(c);
        }
    }

    if (!current.empty() || (!bytes.empty() && bytes[bytes.size() - 1] != '\n'))
    {
        h->records.push_back(current);
    }
}

static int flush_records(RecordSetHandle *h, char *error, rs_size_t errorCapacity)
{
    std::ofstream out(h->path.c_str(), std::ios::out | std::ios::binary | std::ios::trunc);
    if (!out)
    {
        set_error(error, errorCapacity, "Unable to write RecordSet resource");
        return RS_STATUS_ERROR;
    }

    for (rs_size_t i = 0; i < h->records.size(); ++i)
    {
        out.write(h->records[i].data(), (std::streamsize)h->records[i].size());
        out.put('\n');
        if (!out)
        {
            set_error(error, errorCapacity, "Unable to write RecordSet record");
            return RS_STATUS_ERROR;
        }
    }
    h->dirty = false;
    return RS_STATUS_OK;
}

extern "C" int rs_mode_from_text(const char *text, int *mode)
{
    if (mode == NULL) return RS_STATUS_ERROR;
    if (text == NULL || *text == '\0')
    {
        *mode = RS_MODE_READ;
        return RS_STATUS_OK;
    }

    std::string value(text);
    for (rs_size_t i = 0; i < value.size(); ++i)
    {
        value[i] = (char)toupper((unsigned char)value[i]);
    }

    if (value == "READ" || value == "R") *mode = RS_MODE_READ;
    else if (value == "WRITE" || value == "W") *mode = RS_MODE_WRITE;
    else if (value == "APPEND" || value == "A") *mode = RS_MODE_APPEND;
    else return RS_STATUS_ERROR;
    return RS_STATUS_OK;
}

extern "C" int rs_open(const char *resource, int mode, RecordSetHandle **outHandle,
                        char *error, rs_size_t errorCapacity)
{
    if (outHandle == NULL || resource == NULL)
    {
        set_error(error, errorCapacity, "RecordSet open requires a resource");
        return RS_STATUS_ERROR;
    }
    *outHandle = NULL;

    RecordSetHandle *h = new RecordSetHandle();
    h->path = resource;
    h->mode = mode;

    if (mode == RS_MODE_READ || mode == RS_MODE_APPEND)
    {
        std::ifstream in(resource, std::ios::in | std::ios::binary);
        if (!in)
        {
            if (mode == RS_MODE_READ)
            {
                delete h;
                set_error(error, errorCapacity, "RecordSet resource not found");
                return RS_STATUS_ERROR;
            }
        }
        else
        {
            std::ostringstream bytes;
            bytes << in.rdbuf();
            if (!in.good() && !in.eof())
            {
                delete h;
                set_error(error, errorCapacity, "Unable to read RecordSet resource");
                return RS_STATUS_ERROR;
            }
            split_records(h, bytes.str());
        }
    }

    if (mode == RS_MODE_WRITE)
    {
        h->dirty = true;
    }
    else if (mode == RS_MODE_APPEND)
    {
        h->nextIndex = h->records.size();
    }
    else if (mode != RS_MODE_READ)
    {
        delete h;
        set_error(error, errorCapacity, "Invalid RecordSet mode");
        return RS_STATUS_ERROR;
    }

    h->opened = true;
    *outHandle = h;
    set_error(error, errorCapacity, "");
    return RS_STATUS_OK;
}

extern "C" void rs_close(RecordSetHandle *h)
{
    if (h == NULL) return;
    if (h->opened && h->dirty && (h->mode == RS_MODE_WRITE || h->mode == RS_MODE_APPEND))
    {
        char ignored[2];
        flush_records(h, ignored, sizeof(ignored));
    }
    h->opened = false;
    delete h;
}

extern "C" int rs_is_open(const RecordSetHandle *h)
{
    return h != NULL && h->opened;
}

extern "C" int rs_read_record(RecordSetHandle *h, unsigned char **data, rs_size_t *length,
                               char *error, rs_size_t errorCapacity)
{
    if (data != NULL) *data = NULL;
    if (length != NULL) *length = 0;
    if (h == NULL || !h->opened)
    {
        set_error(error, errorCapacity, "RecordSet is closed");
        return RS_STATUS_ERROR;
    }
    if (h->mode != RS_MODE_READ)
    {
        set_error(error, errorCapacity, "RecordSet is not open for reading");
        return RS_STATUS_ERROR;
    }
    if (h->nextIndex >= h->records.size())
    {
        set_error(error, errorCapacity, "");
        return RS_STATUS_EOF;
    }

    const std::string &record = h->records[h->nextIndex++];
    if (length != NULL) *length = record.size();
    if (data != NULL && !record.empty())
    {
        *data = (unsigned char *)malloc(record.size());
        if (*data == NULL)
        {
            set_error(error, errorCapacity, "RecordSet record allocation failed");
            return RS_STATUS_ERROR;
        }
        memcpy(*data, record.data(), record.size());
    }
    set_error(error, errorCapacity, "");
    return RS_STATUS_OK;
}

extern "C" void rs_free_record(void *data)
{
    free(data);
}

extern "C" int rs_write_record(RecordSetHandle *h, const unsigned char *data, rs_size_t length,
                                char *error, rs_size_t errorCapacity)
{
    if (h == NULL || !h->opened)
    {
        set_error(error, errorCapacity, "RecordSet is closed");
        return RS_STATUS_ERROR;
    }
    if (h->mode == RS_MODE_READ)
    {
        set_error(error, errorCapacity, "RecordSet is not open for writing");
        return RS_STATUS_ERROR;
    }

    std::string record;
    if (data != NULL && length != 0)
    {
        record.assign((const char *)data, length);
    }

    if (h->mode == RS_MODE_APPEND)
    {
        h->records.push_back(record);
        h->nextIndex = h->records.size();
    }
    else
    {
        if (h->nextIndex < h->records.size()) h->records[h->nextIndex] = record;
        else h->records.push_back(record);
        ++h->nextIndex;
    }
    h->dirty = true;
    set_error(error, errorCapacity, "");
    return RS_STATUS_OK;
}

extern "C" int rs_position_record(RecordSetHandle *h, rs_size_t oneBasedRecord,
                                   char *error, rs_size_t errorCapacity)
{
    if (h == NULL || !h->opened)
    {
        set_error(error, errorCapacity, "RecordSet is closed");
        return RS_STATUS_ERROR;
    }
    if (oneBasedRecord < 1 || oneBasedRecord > h->records.size() + 1)
    {
        set_error(error, errorCapacity, "RecordSet position is outside the logical record range");
        return RS_STATUS_ERROR;
    }
    h->nextIndex = oneBasedRecord - 1;
    set_error(error, errorCapacity, "");
    return RS_STATUS_OK;
}

extern "C" rs_size_t rs_record_number(const RecordSetHandle *h)
{
    return h == NULL ? 0 : h->nextIndex + 1;
}

extern "C" int rs_record_count(const RecordSetHandle *h, rs_size_t *count,
                                char *error, rs_size_t errorCapacity)
{
    if (h == NULL || !h->opened)
    {
        set_error(error, errorCapacity, "RecordSet is closed");
        return RS_STATUS_ERROR;
    }
    if (count != NULL) *count = h->records.size();
    set_error(error, errorCapacity, "");
    return RS_STATUS_OK;
}

extern "C" int rs_eof(const RecordSetHandle *h)
{
    return h != NULL && h->opened && h->nextIndex >= h->records.size();
}

static std::string text_meta(const RecordSetHandle *h, int key)
{
    if (h == NULL) return std::string();
    switch (key)
    {
        case RS_META_NAME: return h->path;
        case RS_META_ORGANIZATION: return "FILE";
        case RS_META_RECORD_FORMAT: return "TEXT";
        default: return std::string();
    }
}

extern "C" int rs_text_metadata(const RecordSetHandle *h, int key,
                                 char *buffer, rs_size_t capacity, rs_size_t *actualLength)
{
    std::string value = text_meta(h, key);
    if (actualLength != NULL) *actualLength = value.size();
    if (buffer != NULL && capacity != 0)
    {
        rs_size_t n = value.size() < capacity - 1 ? value.size() : capacity - 1;
        if (n != 0) memcpy(buffer, value.data(), n);
        buffer[n] = '\0';
    }
    return RS_STATUS_OK;
}

extern "C" int rs_number_metadata(const RecordSetHandle *, int key, rs_size_t *value)
{
    if (value != NULL) *value = 0;
    if (key == RS_META_LRECL || key == RS_META_BLKSIZE) return RS_STATUS_UNKNOWN;
    return RS_STATUS_ERROR;
}

extern "C" int rs_is_native_recordset(const RecordSetHandle *)
{
    return 0;
}
