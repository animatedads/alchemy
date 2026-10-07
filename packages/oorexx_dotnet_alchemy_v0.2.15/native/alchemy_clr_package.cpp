#include <oorexxapi.h>
#include <stdint.h>

#include <cstdlib>
#include <string>
#include <vector>

typedef int (*invoke_fn)(uint64_t, const char *, size_t, const char **, char **, uint64_t *);
typedef int (*isa_fn)(uint64_t, const char *);
typedef void (*free_fn)(char *);

static invoke_fn g_invoke = nullptr;
static isa_fn g_isa = nullptr;
static free_fn g_free = nullptr;

/* The managed host owns CLR identity and invocation.  This package only holds
   process-lifetime callbacks into that authority; it never caches CLR members. */
extern "C" void ar_clr_callbacks(invoke_fn invokeCallback, isa_fn isaCallback, free_fn freeCallback)
{
    g_invoke = invokeCallback;
    g_isa = isaCallback;
    g_free = freeCallback;
}

/* Bind one stable managed-registry handle to the Rexx projection. */
RexxMethod1(RexxObjectPtr, dotnet_init, uint64_t, handle)
{
    context->SetObjectVariable("ALCHEMYHANDLE", context->UnsignedInt64(handle));
    return NULLOBJECT;
}

/* Return the stable registry handle without resolving or invoking the CLR object. */
RexxMethod0(uint64_t, dotnet_handle)
{
    uint64_t handle = 0;
    context->ObjectToUnsignedInt64(context->GetObjectVariable("ALCHEMYHANDLE"), &handle);
    return handle;
}

/* Ask the managed CLR authority about type membership; Rexx does not emulate System.Type. */
RexxMethod1(logical_t, dotnet_isa, CSTRING, typeName)
{
    uint64_t handle = 0;
    context->ObjectToUnsignedInt64(context->GetObjectVariable("ALCHEMYHANDLE"), &handle);
    return g_isa ? g_isa(handle, typeName) : 0;
}

/* Encode Rexx arguments for the managed bridge while preserving omitted, nil,
   projected-object and scalar distinctions. */
static void encodeArguments(
    RexxMethodContext *context,
    RexxArrayObject arguments,
    std::vector<std::string> &storage,
    std::vector<const char *> &slots)
{
    const size_t count = arguments == NULLOBJECT ? 0 : context->ArraySize(arguments);
    storage.reserve(count);
    slots.reserve(count);

    for (size_t index = 1; index <= count; ++index)
    {
        RexxObjectPtr argument = context->ArrayAt(arguments, index);
        if (argument == NULLOBJECT)
        {
            storage.emplace_back("O");
        }
        else if (argument == context->Nil())
        {
            storage.emplace_back("N");
        }
        else if (context->IsOfType(argument, "ALCHEMYDOTNETOBJECT") ||
                 context->IsOfType(argument, "ALCHEMYDOTNETCLASS"))
        {
            RexxObjectPtr handleObject = context->SendMessage0(argument, "ALCHEMYHANDLE");
            uint64_t argumentHandle = 0;
            context->ObjectToUnsignedInt64(handleObject, &argumentHandle);
            storage.emplace_back("H" + std::to_string(argumentHandle));
        }
        else
        {
            RexxStringObject stringObject = context->ObjectToString(argument);
            const char *value = context->CString(stringObject);
            storage.emplace_back(std::string("S") + (value ? value : ""));
        }
        slots.push_back(storage.back().c_str());
    }
}

/* Decode a successful scalar result.  The managed bridge owns the allocation
   behind text, so release it only through the callback supplied by that bridge. */
static RexxObjectPtr decodeScalar(RexxMethodContext *context, char *text)
{
    const std::string value = text ? text : "";
    RexxObjectPtr result = NULLOBJECT;

    if (value.rfind("I", 0) == 0)
    {
        result = context->Int64(strtoll(value.c_str() + 1, nullptr, 10));
    }
    else if (value.rfind("D", 0) == 0)
    {
        result = context->Double(strtod(value.c_str() + 1, nullptr));
    }
    else
    {
        result = context->String(value.rfind("S", 0) == 0 ? value.c_str() + 1 : value.c_str());
    }

    if (text && g_free)
        g_free(text);
    return result;
}

/* Dispatch through the managed bridge.  The bridge resolves the current CLR
   member for every invocation; this native layer deliberately retains no MethodInfo
   or other stale implementation target between calls. */
static RexxObjectPtr invoke(RexxMethodContext *context, const char *message, RexxArrayObject arguments)
{
    uint64_t handle = 0;
    uint64_t resultHandle = 0;
    char *text = nullptr;

    context->ObjectToUnsignedInt64(context->GetObjectVariable("ALCHEMYHANDLE"), &handle);
    if (!g_invoke)
        return NULLOBJECT;

    std::vector<std::string> storage;
    std::vector<const char *> slots;
    encodeArguments(context, arguments, storage, slots);

    const int kind = g_invoke(handle, message, slots.size(), slots.data(), &text, &resultHandle);
    if (kind == 1)
        return decodeScalar(context, text);

    if (kind == 2 || kind == 4)
    {
        if (resultHandle == handle)
            return context->GetSelf();

        const char *className = kind == 4 ? "ALCHEMYDOTNETCLASS" : "ALCHEMYDOTNETOBJECT";
        RexxClassObject projectionClass = context->FindContextClass(className);
        return projectionClass
            ? context->SendMessage1(projectionClass, "NEW", context->UnsignedInt64(resultHandle))
            : NULLOBJECT;
    }

    if (kind == 3)
    {
        const std::string detail = text ? text : "CLR invocation failed";
        if (text && g_free)
            g_free(text);
        context->RaiseException1(
            48900,
            context->String((std::string("DOTNET_EXCEPTION:") + detail).c_str()));
        return NULLOBJECT;
    }

    if (text && g_free)
        g_free(text);
    return NULLOBJECT;
}

RexxMethod1(RexxObjectPtr, dotnet_invoke0, CSTRING, message)
{
    return invoke(context, message, NULLOBJECT);
}

RexxMethod2(RexxObjectPtr, dotnet_invoke, CSTRING, message, RexxArrayObject, arguments)
{
    return invoke(context, message, arguments);
}

static RexxMethodEntry methods[] = {
    REXX_METHOD(dotnet_init, dotnet_init),
    REXX_METHOD(dotnet_handle, dotnet_handle),
    REXX_METHOD(dotnet_isa, dotnet_isa),
    REXX_METHOD(dotnet_invoke0, dotnet_invoke0),
    REXX_METHOD(dotnet_invoke, dotnet_invoke),
    REXX_LAST_METHOD()
};

RexxPackageEntry AlchemyDotNetNative_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "AlchemyDotNetNative",
    "0.2.15",
    NULL,
    NULL,
    NULL,
    methods
};

OOREXX_GET_PACKAGE(AlchemyDotNetNative);
