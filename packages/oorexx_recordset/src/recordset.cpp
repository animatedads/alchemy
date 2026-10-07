#include "oorexxapi.h"
#include "RecordSetNative.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static RecordSetHandle *backendFrom(CSELF self)
{
    return (RecordSetHandle *)self;
}

static RexxObjectPtr raiseRecordSetError(RexxMethodContext *context, const char *error)
{
    context->RaiseException1(Rexx_Error_System_service_user_defined,
                             context->NewStringFromAsciiz(error == NULL ? "RecordSet error" : error));
    return NULLOBJECT;
}

RexxMethod3(int, RecordSet_Init, CSTRING, resource, OPTIONAL_CSTRING, modeText,
            OPTIONAL_RexxObjectPtr, options)
{
    (void)options;
    int mode = RS_MODE_READ;
    if (rs_mode_from_text(modeText == NULL ? "READ" : modeText, &mode) != RS_STATUS_OK)
    {
        raiseRecordSetError(context, "RecordSet mode must be READ, WRITE, or APPEND");
        return 0;
    }

    RecordSetHandle *handle = NULL;
    char error[256];
    if (rs_open(resource, mode, &handle, error, sizeof(error)) != RS_STATUS_OK)
    {
        raiseRecordSetError(context, error);
        return 0;
    }
    context->SetObjectVariable("CSELF", context->NewPointer(handle));
    return 0;
}

RexxMethod1(int, RecordSet_Uninit, CSELF, self)
{
    if (self != NULL) rs_close(backendFrom(self));
    context->DropObjectVariable("CSELF");
    return 0;
}

RexxMethod1(int, RecordSet_Close, CSELF, self)
{
    if (self != NULL)
    {
        rs_close(backendFrom(self));
        context->DropObjectVariable("CSELF");
    }
    return 0;
}

RexxMethod1(RexxObjectPtr, RecordSet_Read, CSELF, self)
{
    RecordSetHandle *h = backendFrom(self);
    unsigned char *data = NULL;
    rs_size_t length = 0;
    char error[256];
    int status;
    if (h == NULL) return raiseRecordSetError(context, "RecordSet is closed");

    status = rs_read_record(h, &data, &length, error, sizeof(error));
    if (status == RS_STATUS_EOF) return context->Nil();
    if (status != RS_STATUS_OK) return raiseRecordSetError(context, error);

    RexxStringObject result = context->NewString((const char *)(data == NULL ? (const unsigned char *)"" : data), length);
    rs_free_record(data);
    return result;
}

RexxMethod2(int, RecordSet_Write, RexxStringObject, value, CSELF, self)
{
    RecordSetHandle *h = backendFrom(self);
    char error[256];
    if (h == NULL) { raiseRecordSetError(context, "RecordSet is closed"); return 0; }
    if (rs_write_record(h, (const unsigned char *)context->StringData(value), context->StringLength(value),
                        error, sizeof(error)) != RS_STATUS_OK)
    { raiseRecordSetError(context, error); return 0; }
    return 1;
}

RexxMethod3(size_t, RecordSet_ReadStem, RexxStemObject, stem, OPTIONAL_size_t, maximum, CSELF, self)
{
    RecordSetHandle *h = backendFrom(self);
    rs_size_t limit = argumentExists(2) ? maximum : (rs_size_t)-1;
    rs_size_t count = 0;
    char index[32];
    char error[256];
    if (h == NULL) { raiseRecordSetError(context, "RecordSet is closed"); return 0; }

    while (count < limit)
    {
        unsigned char *data = NULL;
        rs_size_t length = 0;
        int status = rs_read_record(h, &data, &length, error, sizeof(error));
        if (status == RS_STATUS_EOF) break;
        if (status != RS_STATUS_OK) { raiseRecordSetError(context,error); break; }
        ++count;
        sprintf(index, "%lu", (unsigned long)count);
        context->SetStemElement(stem, index, context->NewString((const char *)(data == NULL ? (const unsigned char *)"" : data), length));
        rs_free_record(data);
    }
    context->SetStemElement(stem, "0", context->UnsignedInt64ToObject((uint64_t)count));
    return count;
}

RexxMethod3(size_t, RecordSet_WriteStem, RexxStemObject, stem, OPTIONAL_size_t, maximum, CSELF, self)
{
    RecordSetHandle *h = backendFrom(self);
    rs_size_t count = 0, written = 0, i;
    char index[32], error[256];
    if (h == NULL) { raiseRecordSetError(context, "RecordSet is closed"); return 0; }

    if (argumentExists(2)) count = maximum;
    else
    {
        RexxObjectPtr zero = context->GetStemElement(stem, "0");
        uint64_t n = 0;
        if (zero == NULLOBJECT || !context->ObjectToUnsignedInt64(zero, &n))
        { raiseRecordSetError(context, "RecordSet writeStem requires stem.0 or an explicit count"); return 0; }
        count = (rs_size_t)n;
    }

    for (i = 1; i <= count; ++i)
    {
        sprintf(index, "%lu", (unsigned long)i);
        RexxObjectPtr item = context->GetStemElement(stem, index);
        if (item == NULLOBJECT)
        { raiseRecordSetError(context, "RecordSet writeStem encountered a missing stem element"); return written; }
        RexxStringObject s = context->ObjectToString(item);
        if (rs_write_record(h, (const unsigned char *)context->StringData(s), context->StringLength(s), error, sizeof(error)) != RS_STATUS_OK)
        { raiseRecordSetError(context,error); return written; }
        ++written;
    }
    return written;
}

RexxMethod2(int, RecordSet_Position, size_t, recordNumber, CSELF, self)
{
    char error[256];
    RecordSetHandle *h=backendFrom(self);
    if (h == NULL || rs_position_record(h,recordNumber,error,sizeof(error)) != RS_STATUS_OK)
    { if (h == NULL) strcpy(error,"RecordSet is closed"); raiseRecordSetError(context,error); return 0; }
    return 1;
}

RexxMethod1(uint64_t, RecordSet_RecordNumber, CSELF, self)
{ return self == NULL ? 0 : (uint64_t)rs_record_number(backendFrom(self)); }

RexxMethod1(RexxObjectPtr, RecordSet_RecordCount, CSELF, self)
{
    rs_size_t count=0; char error[256]; int status;
    if (self == NULL) return context->Nil();
    status=rs_record_count(backendFrom(self),&count,error,sizeof(error));
    if (status == RS_STATUS_UNKNOWN) return context->Nil();
    if (status != RS_STATUS_OK) return raiseRecordSetError(context,error);
    return context->UnsignedInt64ToObject((uint64_t)count);
}

RexxMethod1(logical_t, RecordSet_Eof, CSELF, self)
{ return self != NULL && rs_eof(backendFrom(self)); }
RexxMethod1(logical_t, RecordSet_IsOpen, CSELF, self)
{ return self != NULL && rs_is_open(backendFrom(self)); }

static RexxStringObject textMetadata(RexxMethodContext *context, RecordSetHandle *h, int key)
{
    char local[512]; rs_size_t actual=0;
    if (h == NULL) return context->NullString();
    rs_text_metadata(h,key,local,sizeof(local),&actual);
    if (actual < sizeof(local)) return context->NewString(local,actual);
    char *buffer=(char *)malloc(actual+1);
    if (buffer == NULL) return context->NullString();
    rs_text_metadata(h,key,buffer,actual+1,&actual);
    RexxStringObject result=context->NewString(buffer,actual);
    free(buffer);
    return result;
}

#define RS_TEXT_METHOD(fn,key) RexxMethod1(RexxStringObject, fn, CSELF, self) \
{ return textMetadata(context, backendFrom(self), key); }
RS_TEXT_METHOD(RecordSet_Name,RS_META_NAME)
RS_TEXT_METHOD(RecordSet_DdName,RS_META_DD_NAME)
RS_TEXT_METHOD(RecordSet_DataSetName,RS_META_DATASET_NAME)
RS_TEXT_METHOD(RecordSet_MemberName,RS_META_MEMBER_NAME)
RS_TEXT_METHOD(RecordSet_Organization,RS_META_ORGANIZATION)
RS_TEXT_METHOD(RecordSet_RecordFormat,RS_META_RECORD_FORMAT)

static uint64_t numberMetadata(RecordSetHandle *h,int key)
{ rs_size_t v=0; return h != NULL && rs_number_metadata(h,key,&v)==RS_STATUS_OK ? (uint64_t)v : 0; }
RexxMethod1(uint64_t,RecordSet_LogicalRecordLength,CSELF,self)
{ (void)context; return numberMetadata(backendFrom(self),RS_META_LRECL); }
RexxMethod1(uint64_t,RecordSet_BlockSize,CSELF,self)
{ (void)context; return numberMetadata(backendFrom(self),RS_META_BLKSIZE); }
RexxMethod1(logical_t,RecordSet_IsNativeRecordSet,CSELF,self)
{ (void)context; return self != NULL && rs_is_native_recordset(backendFrom(self)); }

RexxMethodEntry recordset_methods[] =
{
    REXX_METHOD(RecordSet_Init,RecordSet_Init), REXX_METHOD(RecordSet_Uninit,RecordSet_Uninit),
    REXX_METHOD(RecordSet_Close,RecordSet_Close), REXX_METHOD(RecordSet_Read,RecordSet_Read),
    REXX_METHOD(RecordSet_Write,RecordSet_Write), REXX_METHOD(RecordSet_ReadStem,RecordSet_ReadStem),
    REXX_METHOD(RecordSet_WriteStem,RecordSet_WriteStem), REXX_METHOD(RecordSet_Position,RecordSet_Position),
    REXX_METHOD(RecordSet_RecordNumber,RecordSet_RecordNumber), REXX_METHOD(RecordSet_RecordCount,RecordSet_RecordCount),
    REXX_METHOD(RecordSet_Eof,RecordSet_Eof), REXX_METHOD(RecordSet_IsOpen,RecordSet_IsOpen),
    REXX_METHOD(RecordSet_Name,RecordSet_Name), REXX_METHOD(RecordSet_DdName,RecordSet_DdName),
    REXX_METHOD(RecordSet_DataSetName,RecordSet_DataSetName), REXX_METHOD(RecordSet_MemberName,RecordSet_MemberName),
    REXX_METHOD(RecordSet_Organization,RecordSet_Organization), REXX_METHOD(RecordSet_RecordFormat,RecordSet_RecordFormat),
    REXX_METHOD(RecordSet_LogicalRecordLength,RecordSet_LogicalRecordLength), REXX_METHOD(RecordSet_BlockSize,RecordSet_BlockSize),
    REXX_METHOD(RecordSet_IsNativeRecordSet,RecordSet_IsNativeRecordSet), REXX_LAST_METHOD()
};

RexxPackageEntry recordset_package_entry =
{
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_4_0_0, "recordset", "0.1-dev2", NULL, NULL, NULL, recordset_methods
};
OOREXX_GET_PACKAGE(recordset);
