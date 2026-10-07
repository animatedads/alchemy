#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <oorexxapi.h>
#include <rexx.h>
#include <cstring>
#include <algorithm>
#include <cctype>
#include <map>
#include <mutex>
#include <string>
#include <vector>
#include <stdint.h>
#include <cstdlib>

static PyObject *receiver = nullptr;
static std::map<uint64_t, PyObject *> py_objects;
static std::map<PyObject *, uint64_t> py_object_handles;
static std::map<uint64_t, size_t> py_object_retain_counts;
static std::map<uint64_t, std::map<std::string, std::string>> py_method_cases;
static uint64_t next_py_handle = 1;
static std::mutex py_object_mutex;
static std::string method_name;
static RexxInstance *instance = nullptr;
static RexxThreadContext *tc = nullptr;
static std::map<uint64_t, RexxObjectPtr> objects;
static uint64_t next_handle = 1;
static std::mutex object_mutex;
static PyObject *RexxError = nullptr;

/* Lazily create the single embedded ooRexx interpreter used by this POC. */
static bool ensure_interpreter()
{
    if (instance != nullptr) return true;
    return RexxCreateInterpreter(&instance, &tc, nullptr) != 0;
}

static std::mutex package_mutex;
static std::map<std::string, RexxPackageObject> loaded_packages;

static size_t REXXENTRY py_class_load(CONSTANT_STRING, size_t, PCONSTRXSTRING, CONSTANT_STRING, PRXSTRING);
static size_t REXXENTRY py_class_construct(CONSTANT_STRING, size_t, PCONSTRXSTRING, CONSTANT_STRING, PRXSTRING);
static size_t REXXENTRY py_object_call(CONSTANT_STRING, size_t, PCONSTRXSTRING, CONSTANT_STRING, PRXSTRING);
static size_t REXXENTRY py_type_query(CONSTANT_STRING, size_t, PCONSTRXSTRING, CONSTANT_STRING, PRXSTRING);
static size_t REXXENTRY py_type_relation(CONSTANT_STRING, size_t, PCONSTRXSTRING, CONSTANT_STRING, PRXSTRING);
static size_t REXXENTRY py_object_release(CONSTANT_STRING, size_t, PCONSTRXSTRING, CONSTANT_STRING, PRXSTRING);

/* Establish REXX_PATH before interpreter creation, then load and globally root
 * the requested package exactly once so ooRexx resolves its own ::requires. */
static PyObject *bootstrap_rexx_package_space(PyObject *, PyObject *args)
{
    const char *rexx_path,*entry;
    if(!PyArg_ParseTuple(args,"ss",&rexx_path,&entry)) return nullptr;
    {
        std::lock_guard<std::mutex> lock(package_mutex);
        if(instance==nullptr) {
#ifdef _WIN32
            _putenv_s("REXX_PATH",rexx_path);
#else
            setenv("REXX_PATH",rexx_path,1);
#endif
        }
    }
    if(!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError,"RexxCreateInterpreter failed");
    RexxRegisterFunctionExe("PYCALL", (REXXPFN)py_object_call);
    RexxRegisterFunctionExe("PYTYPEQUERY", (REXXPFN)py_type_query);
    RexxRegisterFunctionExe("PYTYPERELATION", (REXXPFN)py_type_relation);
    RexxRegisterFunctionExe("PYCLASSLOAD", (REXXPFN)py_class_load);
    RexxRegisterFunctionExe("PYCLASSCONSTRUCT", (REXXPFN)py_class_construct);
    RexxRegisterFunctionExe("PYRELEASE", (REXXPFN)py_object_release);
    std::lock_guard<std::mutex> lock(package_mutex);
    auto it=loaded_packages.find(entry);
    if(it!=loaded_packages.end()) Py_RETURN_TRUE;
    RexxPackageObject pkg=tc->LoadPackage(entry);
    if(pkg==NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError,"ooRexx package-space bootstrap failed: %s",entry); }
    loaded_packages[entry]=(RexxPackageObject)tc->RequestGlobalReference(pkg);
    Py_RETURN_TRUE;
}

/* Convert an ooRexx object to a byte-preserving std::string via ObjectToString. */
static std::string rexx_string(RexxObjectPtr o)
{
    if (o == NULLOBJECT) return std::string();
    RexxStringObject s = tc->ObjectToString(o);
    CSTRING p = tc->StringData(s);
    size_t n = tc->StringLength(s);
    return std::string(p, n);
}

/* Give a Rexx object an independent global-reference-backed bridge handle. */
static uint64_t retain(RexxObjectPtr o)
{
    RexxObjectPtr g = tc->RequestGlobalReference(o);
    std::lock_guard<std::mutex> lock(object_mutex);
    uint64_t h = next_handle++;
    objects[h] = g;
    return h;
}

/* Resolve a Rexx bridge handle without transferring ownership. */
static RexxObjectPtr lookup(uint64_t h)
{
    std::lock_guard<std::mutex> lock(object_mutex);
    auto i = objects.find(h);
    return i == objects.end() ? NULLOBJECT : i->second;
}

static PyObject *create_animal(PyObject *, PyObject *args)
{
    const char *factory, *name, *species, *sound;
    if (!PyArg_ParseTuple(args, "ssss", &factory, &name, &species, &sound)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxArrayObject a = tc->NewArray(4);
    tc->ArrayPut(a, tc->String("ANIMAL"), 1);
    tc->ArrayPut(a, tc->String(name), 2);
    tc->ArrayPut(a, tc->String(species), 3);
    tc->ArrayPut(a, tc->String(sound), 4);
    RexxObjectPtr o = tc->CallProgram(factory, a);
    if (o == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx animal factory failed"); }
    return PyLong_FromUnsignedLongLong(retain(o));
}

static PyObject *create_guarded(PyObject *, PyObject *args)
{
    const char *factory, *name;
    if (!PyArg_ParseTuple(args, "ss", &factory, &name)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxArrayObject a = tc->NewArray(2);
    tc->ArrayPut(a, tc->String("GUARDED"), 1);
    tc->ArrayPut(a, tc->String(name), 2);
    RexxObjectPtr o = tc->CallProgram(factory, a);
    if (o == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx guarded factory failed"); }
    return PyLong_FromUnsignedLongLong(retain(o));
}

static PyObject *create_argument_probe(PyObject *, PyObject *args)
{
    const char *factory;
    if (!PyArg_ParseTuple(args, "s", &factory)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxArrayObject a = tc->NewArray(1);
    tc->ArrayPut(a, tc->String("ARGPROBE"), 1);
    RexxObjectPtr o = tc->CallProgram(factory, a);
    if (o == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx argument probe factory failed"); }
    return PyLong_FromUnsignedLongLong(retain(o));
}

static PyObject *argument_probe_call(PyObject *, PyObject *args)
{
    unsigned long long h; int mode; const char *value = "";
    if (!PyArg_ParseTuple(args, "Ki|s", &h, &mode, &value)) return nullptr;
    RexxObjectPtr o = lookup(h);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx argument probe handle");

    RexxObjectPtr r = NULLOBJECT;
    if (mode == 0) {
        /* Send the message with zero arguments: genuinely omitted. */
        r = tc->SendMessage0(o, "PROBE");
    } else if (mode == 1) {
        r = tc->SendMessage1(o, "PROBE", tc->Nil());
    } else if (mode == 2) {
        r = tc->SendMessage1(o, "PROBE", tc->String(""));
    } else if (mode == 3) {
        r = tc->SendMessage1(o, "PROBE", tc->String(value));
    } else {
        return PyErr_Format(PyExc_ValueError, "bad argument probe mode");
    }
    if (r == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx argument probe call failed"); }
    std::string v = rexx_string(r);
    return PyUnicode_DecodeUTF8(v.data(), v.size(), "strict");
}

static PyObject *create_stem(PyObject *, PyObject *args)
{
    const char *factory;
    if (!PyArg_ParseTuple(args, "s", &factory)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxArrayObject a = tc->NewArray(1);
    tc->ArrayPut(a, tc->String("STEM"), 1);
    RexxObjectPtr o = tc->CallProgram(factory, a);
    if (o == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx stem factory failed"); }
    return PyLong_FromUnsignedLongLong(retain(o));
}

static PyObject *stem_get(PyObject *, PyObject *args)
{
    unsigned long long h; const char *tail;
    if (!PyArg_ParseTuple(args, "Ks", &h, &tail)) return nullptr;
    RexxObjectPtr o = lookup(h);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx stem handle");
    RexxObjectPtr r = tc->SendMessage1(o, "[]", tc->String(tail));
    if (r == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx stem read failed for %s", tail); }
    std::string v = rexx_string(r);
    return PyUnicode_DecodeUTF8(v.data(), v.size(), "strict");
}

static PyObject *stem_set(PyObject *, PyObject *args)
{
    unsigned long long h; const char *tail, *value;
    if (!PyArg_ParseTuple(args, "Kss", &h, &tail, &value)) return nullptr;
    RexxObjectPtr o = lookup(h);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx stem handle");
    RexxObjectPtr r = tc->SendMessage2(o, "[]=", tc->String(value), tc->String(tail));
    if (tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx stem write failed for %s", tail); }
    Py_RETURN_NONE;
}

static PyObject *consume_stem_rexx(PyObject *, PyObject *args)
{
    unsigned long long h; const char *factory;
    if(!PyArg_ParseTuple(args,"Ks",&h,&factory)) return nullptr;
    RexxObjectPtr stem=lookup(h);
    if(stem==NULLOBJECT) return PyErr_Format(PyExc_KeyError,"unknown Rexx stem handle");
    RexxArrayObject a=tc->NewArray(1); tc->ArrayPut(a,tc->String("STEMCONSUMER"),1);
    RexxObjectPtr consumer=tc->CallProgram(factory,a);
    if(consumer==NULLOBJECT||tc->CheckCondition()){tc->ClearCondition();return PyErr_Format(PyExc_RuntimeError,"StemConsumer factory failed");}
    RexxObjectPtr r=tc->SendMessage1(consumer,"CONSUME",stem);
    if(r==NULLOBJECT||tc->CheckCondition()){tc->ClearCondition();return PyErr_Format(PyExc_RuntimeError,"StemConsumer consume failed");}
    std::string v=rexx_string(r); return PyUnicode_DecodeUTF8(v.data(),v.size(),"strict");
}

static PyObject *create_collection(PyObject *, PyObject *args)
{
    const char *factory;
    if (!PyArg_ParseTuple(args, "s", &factory)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxArrayObject a = tc->NewArray(1);
    tc->ArrayPut(a, tc->String("COLLECTION"), 1);
    RexxObjectPtr o = tc->CallProgram(factory, a);
    if (o == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx collection factory failed"); }
    return PyLong_FromUnsignedLongLong(retain(o));
}


/* Send a zero-argument message from an arbitrary Python thread by attaching a
 * thread-local ooRexx context and releasing the GIL while Rexx may block. */
static PyObject *send0_attached(PyObject *, PyObject *args)
{
    unsigned long long h; const char *message;
    if (!PyArg_ParseTuple(args, "Ks", &h, &message)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxObjectPtr o = lookup(h);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx object handle");

    RexxThreadContext *local = nullptr;
    if (!instance->AttachThread(&local) || local == nullptr)
        return PyErr_Format(PyExc_RuntimeError, "ooRexx AttachThread failed");

    RexxObjectPtr r = NULLOBJECT;
    bool condition = false;
    Py_BEGIN_ALLOW_THREADS
    r = local->SendMessage0(o, message);
    condition = local->CheckCondition();
    Py_END_ALLOW_THREADS

    if (condition) {
        local->ClearCondition();
        local->DetachThread();
        return PyErr_Format(PyExc_RuntimeError, "ooRexx attached message %s failed", message);
    }
    std::string value;
    if (r != NULLOBJECT) {
        RexxStringObject rs = local->ObjectToString(r);
        value.assign(local->StringData(rs), local->StringLength(rs));
    }
    local->DetachThread();
    return PyUnicode_DecodeUTF8(value.data(), value.size(), "strict");
}

static PyObject *send0(PyObject *, PyObject *args)
{
    unsigned long long h; const char *message;
    if (!PyArg_ParseTuple(args, "Ks", &h, &message)) return nullptr;
    RexxObjectPtr o = lookup(h);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx object handle");
    RexxObjectPtr r = tc->SendMessage0(o, message);
    if (tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx message %s failed", message); }
    std::string s = rexx_string(r);
    return PyUnicode_DecodeUTF8(s.data(), s.size(), "strict");
}

static PyObject *send0_handle(PyObject *, PyObject *args)
{
    unsigned long long h; const char *message;
    if (!PyArg_ParseTuple(args, "Ks", &h, &message)) return nullptr;
    RexxObjectPtr o = lookup(h);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx object handle");
    RexxObjectPtr r = tc->SendMessage0(o, message);
    if (r == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx message %s failed", message); }
    return PyLong_FromUnsignedLongLong(retain(r));
}

static PyObject *send1_handle(PyObject *, PyObject *args)
{
    unsigned long long h, arg; const char *message;
    if (!PyArg_ParseTuple(args, "KsK", &h, &message, &arg)) return nullptr;
    RexxObjectPtr o = lookup(h), a = lookup(arg);
    if (o == NULLOBJECT || a == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx object handle");
    RexxObjectPtr r = tc->SendMessage1(o, message, a);
    if (tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx message %s failed", message); }
    std::string s = rexx_string(r);
    return PyUnicode_DecodeUTF8(s.data(), s.size(), "strict");
}

static PyObject *send1_index_handle(PyObject *, PyObject *args)
{
    unsigned long long h; const char *message; long index;
    if (!PyArg_ParseTuple(args, "Ksl", &h, &message, &index)) return nullptr;
    RexxObjectPtr o = lookup(h);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx object handle");
    RexxObjectPtr r = tc->SendMessage1(o, message, tc->Int64ToObject(index));
    if (r == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx message %s failed", message); }
    return PyLong_FromUnsignedLongLong(retain(r));
}

/* Drop the registry-owned global reference for a Rexx bridge handle. */
static PyObject *release_handle(PyObject *, PyObject *args)
{
    unsigned long long h;
    if (!PyArg_ParseTuple(args, "K", &h)) return nullptr;
    std::lock_guard<std::mutex> lock(object_mutex);
    auto i = objects.find(h);
    if (i != objects.end()) { tc->ReleaseGlobalReference(i->second); objects.erase(i); }
    Py_RETURN_NONE;
}

static size_t REXXENTRY py_callback(CONSTANT_STRING, size_t argc, PCONSTRXSTRING argv, CONSTANT_STRING, PRXSTRING result)
{
    PyGILState_STATE gil = PyGILState_Ensure();
    std::string msg;
    if (argc > 0 && argv[0].strptr != nullptr) msg.assign(argv[0].strptr, argv[0].strlength);
    PyObject *ret = receiver == nullptr ? nullptr : PyObject_CallMethod(receiver, method_name.c_str(), "s#", msg.data(), (Py_ssize_t)msg.size());
    std::string answer = "PYTHON_CALLBACK_ERROR";
    if (ret != nullptr) { PyObject *s = PyObject_Str(ret); if (s != nullptr) { const char *u = PyUnicode_AsUTF8(s); if (u) answer = u; Py_DECREF(s); } Py_DECREF(ret); }
    else PyErr_Print();
    if (result->strptr != nullptr) { size_t n = answer.size(); if (n > 255) n = 255; memcpy(result->strptr, answer.data(), n); result->strlength = n; }
    PyGILState_Release(gil); return 0;
}

/* Retain OBJ in the Python-object registry and return its stable bridge handle.
 * Repeated retention of the same PyObject preserves identity and increments a
 * logical owner count; exactly one matching release is required per retain. */
static uint64_t retain_python_object(PyObject *obj)
{
    std::lock_guard<std::mutex> lock(py_object_mutex);
    auto existing = py_object_handles.find(obj);
    if (existing != py_object_handles.end()) {
        py_object_retain_counts[existing->second]++;
        return existing->second;
    }
    uint64_t h = next_py_handle++;
    Py_INCREF(obj);
    py_objects[h] = obj;
    py_object_handles[obj] = h;
    py_object_retain_counts[h] = 1;
    return h;
}

/* Release one logical owner while PY_OBJECT_MUTEX is already held.  Keeping
 * all registry teardown here prevents identity-map and retain-count drift on
 * normal release and, importantly, on construction rollback paths. */
static void release_python_object_locked(uint64_t h)
{
    auto i = py_objects.find(h);
    if (i == py_objects.end()) return;

    auto count = py_object_retain_counts.find(h);
    if (count != py_object_retain_counts.end() && count->second > 1) {
        count->second--;
        return;
    }

    PyObject *obj = i->second;
    py_object_retain_counts.erase(h);
    py_object_handles.erase(obj);
    py_method_cases.erase(h);
    py_objects.erase(i);
    Py_DECREF(obj);
}

/* Release one logical Python-object owner.  Stale releases are deliberately
 * harmless because Rexx and Python proxy destruction can be independently
 * ordered during interpreter shutdown and torture tests. */
static void release_python_object_handle(uint64_t h)
{
    std::lock_guard<std::mutex> lock(py_object_mutex);
    release_python_object_locked(h);
}

/* Rexx-side proxy finalizer.  Each projected Rexx object/class owns exactly one
 * logical registry retain.  Stale/double release remains harmless by contract. */
static size_t REXXENTRY py_object_release(CONSTANT_STRING, size_t argc, PCONSTRXSTRING argv, CONSTANT_STRING, PRXSTRING result)
{
    if (argc != 1) return RXFUNC_BADTYPE;
    uint64_t h = strtoull(argv[0].strptr, nullptr, 10);
    PyGILState_STATE gil = PyGILState_Ensure();
    release_python_object_handle(h);
    PyGILState_Release(gil);
    if (result->strptr == nullptr || result->strlength < 1) result->strptr=(char *)RexxAllocateMemory(2);
    result->strptr[0]='1'; result->strptr[1]='\0'; result->strlength=1;
    return RXFUNC_OK;
}


/* A Python callable that retains only an ooRexx global-reference handle.
 * Each invocation resolves that handle afresh, so Rexx object-local method
 * replacement is observed live rather than snapshotting a Method object. */
typedef struct {
    PyObject_HEAD
    uint64_t rexx_handle;
    std::string *message;
    bool skip_python_receiver;
    PyObject *owner;
} RexxLiveCallable;

/* Forward layout for identity-preserving Rexx arguments/returns. */
typedef struct { PyObject_HEAD uint64_t rexx_handle; } RexxProjectedObject;
static PyTypeObject RexxProjectedObjectType={PyVarObject_HEAD_INIT(nullptr,0)};

static PyObject *RexxLiveCallable_call(PyObject *selfobj, PyObject *args, PyObject *)
{
    RexxLiveCallable *self=(RexxLiveCallable *)selfobj;
    Py_ssize_t argc=PyTuple_GET_SIZE(args);
    Py_ssize_t first=self->skip_python_receiver && argc>0 ? 1 : 0;
    if(!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError,"RexxCreateInterpreter failed");

    RexxThreadContext *local=nullptr;
    if(!instance->AttachThread(&local) || local==nullptr)
        return PyErr_Format(PyExc_RuntimeError,"ooRexx AttachThread failed for Rexx live callable");

    RexxObjectPtr target=NULLOBJECT;
    {
        std::lock_guard<std::mutex> lock(object_mutex);
        auto i=objects.find(self->rexx_handle);
        if(i!=objects.end()) target=local->RequestGlobalReference(i->second);
    }
    if(target==NULLOBJECT) { local->DetachThread(); return PyErr_Format(PyExc_RuntimeError,"revoked Rexx callable"); }

    RexxArrayObject ra=local->NewArray((size_t)(argc-first));
    std::vector<RexxObjectPtr> pins;
    bool bad=false;
    std::string why;
    for(Py_ssize_t i=first;i<argc;i++) {
        PyObject *a=PyTuple_GET_ITEM(args,i);
        RexxObjectPtr ro=NULLOBJECT;
        if(a==Py_None) ro=local->Nil();
        else if(PyBool_Check(a)) ro=(a==Py_True)?local->True():local->False();
        else if(PyLong_Check(a)) {
            long long v=PyLong_AsLongLong(a);
            if(PyErr_Occurred()){ PyErr_Clear(); bad=true; why="integer outside Rexx Int64 range"; break; }
            ro=local->Int64ToObject(v);
        } else if(PyUnicode_Check(a)) {
            Py_ssize_t n=0; const char *v=PyUnicode_AsUTF8AndSize(a,&n);
            if(v==nullptr){ PyErr_Clear(); bad=true; why="invalid Python text argument"; break; }
            ro=local->String(v,(size_t)n);
        } else if(PyObject_TypeCheck(a,&RexxProjectedObjectType)) {
            uint64_t h=((RexxProjectedObject *)a)->rexx_handle;
            std::lock_guard<std::mutex> lock(object_mutex);
            auto it=objects.find(h);
            if(it==objects.end()){ bad=true; why="released Rexx object argument"; break; }
            ro=local->RequestGlobalReference(it->second); pins.push_back(ro);
        } else { bad=true; why="unsupported Python argument type for Rexx message"; break; }
        local->ArrayPut(ra,ro,(size_t)(i-first+1));
    }
    if(bad) {
        for(auto p:pins) local->ReleaseGlobalReference(p);
        local->ReleaseGlobalReference(target); local->DetachThread();
        return PyErr_Format(PyExc_TypeError,"%s",why.c_str());
    }

    RexxObjectPtr r=NULLOBJECT; bool condition=false;
    Py_BEGIN_ALLOW_THREADS
    r=local->SendMessage(target,self->message->c_str(),ra);
    condition=local->CheckCondition();
    Py_END_ALLOW_THREADS
    for(auto p:pins) local->ReleaseGlobalReference(p);

    /* Preserve the Rexx condition instead of collapsing every failure to a
     * generic RuntimeError.  The Python exception carries the authoritative
     * ooRexx code/rc/position/name/message/program/description fields. */
    PyObject *rexx_failure=nullptr;
    if(condition) {
        RexxDirectoryObject info=local->GetConditionInfo();
        RexxCondition c{};
        local->DecodeConditionInfo(info,&c);
        auto text_of=[&](RexxStringObject x)->std::string {
            if(x==NULLOBJECT) return std::string();
            return std::string(local->StringData(x),local->StringLength(x));
        };
        std::string name=text_of(c.conditionName), message=text_of(c.message);
        std::string program=text_of(c.program), description=text_of(c.description);
        std::string summary="ooRexx "+name+" "+std::to_string((long long)c.code);
        if(!message.empty()) summary += ": "+message;
        PyObject *etype=RexxError ? RexxError : PyExc_RuntimeError;
        rexx_failure=PyObject_CallFunction(etype,"s",summary.c_str());
        if(rexx_failure!=nullptr) {
            auto set_attr=[&](const char *key,PyObject *value) {
                if(value!=nullptr) { PyObject_SetAttrString(rexx_failure,key,value); Py_DECREF(value); }
            };
            set_attr("code",PyLong_FromLongLong((long long)c.code));
            set_attr("rc",PyLong_FromLongLong((long long)c.rc));
            set_attr("position",PyLong_FromSize_t(c.position));
            set_attr("condition_name",PyUnicode_FromStringAndSize(name.data(),name.size()));
            set_attr("rexx_message",PyUnicode_FromStringAndSize(message.data(),message.size()));
            set_attr("program",PyUnicode_FromStringAndSize(program.data(),program.size()));
            set_attr("description",PyUnicode_FromStringAndSize(description.data(),description.size()));
        }
        local->ClearCondition();
    }
    local->ReleaseGlobalReference(target);
    if(condition || r==NULLOBJECT) {
        local->DetachThread();
        if(rexx_failure!=nullptr) { PyErr_SetObject((PyObject *)Py_TYPE(rexx_failure),(PyObject *)rexx_failure); Py_DECREF(rexx_failure); return nullptr; }
        return PyErr_Format(PyExc_RuntimeError,"Rexx message %s failed",self->message->c_str());
    }

    PyObject *out=nullptr;
    if(r==local->Nil()) { Py_INCREF(Py_None); out=Py_None; }
    else if(r==local->True()) { Py_INCREF(Py_True); out=Py_True; }
    else if(r==local->False()) { Py_INCREF(Py_False); out=Py_False; }
    else if(local->IsInstanceOf(r,local->FindClass("STRING"))) {
        RexxStringObject rs=local->ObjectToString(r);
        out=PyUnicode_DecodeUTF8(local->StringData(rs),local->StringLength(rs),"strict");
    } else {
        uint64_t h;
        {
            std::lock_guard<std::mutex> lock(object_mutex);
            h=next_handle++;
            objects[h]=local->RequestGlobalReference(r);
        }
        RexxProjectedObject *po=PyObject_New(RexxProjectedObject,&RexxProjectedObjectType);
        if(po==nullptr) {
            std::lock_guard<std::mutex> lock(object_mutex);
            auto it=objects.find(h); if(it!=objects.end()){ local->ReleaseGlobalReference(it->second); objects.erase(it); }
        } else { po->rexx_handle=h; out=(PyObject *)po; }
    }
    local->DetachThread();
    return out;
}
static void RexxLiveCallable_dealloc(PyObject *selfobj)
{
    RexxLiveCallable *self=(RexxLiveCallable *)selfobj;
    delete self->message;
    Py_XDECREF(self->owner);
    Py_TYPE(selfobj)->tp_free(selfobj);
}
static PyObject *RexxLiveCallable_descr_get(PyObject *selfobj, PyObject *obj, PyObject *)
{
    if(obj==nullptr || obj==Py_None) { Py_INCREF(selfobj); return selfobj; }
    return PyMethod_New(selfobj,obj);
}
static PyTypeObject RexxLiveCallableType={PyVarObject_HEAD_INIT(nullptr,0)};

static PyObject *make_rexx_live_callable(PyObject *, PyObject *args)
{
    unsigned long long h; const char *message;
    if(!PyArg_ParseTuple(args,"Ks",&h,&message)) return nullptr;
    if(lookup(h)==NULLOBJECT) return PyErr_Format(PyExc_KeyError,"unknown Rexx object handle");
    RexxLiveCallable *o=PyObject_New(RexxLiveCallable,&RexxLiveCallableType);
    if(!o) return nullptr;
    o->rexx_handle=h; o->message=new std::string(message); o->skip_python_receiver=true; o->owner=nullptr;
    return (PyObject *)o;
}
static PyObject *revoke_rexx_handle(PyObject *, PyObject *args)
{
    unsigned long long h; if(!PyArg_ParseTuple(args,"K",&h)) return nullptr;
    std::lock_guard<std::mutex> lock(object_mutex); auto i=objects.find(h); if(i!=objects.end()){tc->ReleaseGlobalReference(i->second);objects.erase(i);} Py_RETURN_NONE;
}

/* v0.31.4: a Python-side live projection for an arbitrary retained ooRexx
 * object.  R: argument frames transfer one registry-owned global reference
 * into this Python object; destruction releases it.  SEND() deliberately uses
 * normal ooRexx message dispatch, so Python operates the original object rather
 * than a serialized copy. */
static PyObject *RexxProjectedObject_send(PyObject *selfobj, PyObject *args)
{
    RexxProjectedObject *self=(RexxProjectedObject *)selfobj;
    const char *message;
    if(!PyArg_ParseTuple(args,"s",&message)) return nullptr;
    if(!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError,"RexxCreateInterpreter failed");
    RexxThreadContext *local=nullptr;
    if(!instance->AttachThread(&local) || local==nullptr)
        return PyErr_Format(PyExc_RuntimeError,"ooRexx AttachThread failed");
    RexxObjectPtr target=NULLOBJECT;
    {
        std::lock_guard<std::mutex> lock(object_mutex);
        auto i=objects.find(self->rexx_handle);
        if(i!=objects.end()) target=local->RequestGlobalReference(i->second);
    }
    if(target==NULLOBJECT){ local->DetachThread(); return PyErr_Format(PyExc_RuntimeError,"released Rexx projection"); }
    RexxObjectPtr r=local->SendMessage0(target,message);
    bool condition=local->CheckCondition();
    std::string out;
    if(!condition && r!=NULLOBJECT){ RexxStringObject rs=local->ObjectToString(r); out.assign(local->StringData(rs),local->StringLength(rs)); }
    if(condition) local->ClearCondition();
    local->ReleaseGlobalReference(target); local->DetachThread();
    if(condition || r==NULLOBJECT) return PyErr_Format(PyExc_RuntimeError,"ooRexx message %s failed",message);
    return PyUnicode_DecodeUTF8(out.data(),out.size(),"strict");
}
static void RexxProjectedObject_dealloc(PyObject *selfobj)
{
    RexxProjectedObject *self=(RexxProjectedObject *)selfobj;
    if(self->rexx_handle && ensure_interpreter()) {
        RexxThreadContext *local=nullptr;
        if(instance->AttachThread(&local) && local!=nullptr) {
            std::lock_guard<std::mutex> lock(object_mutex);
            auto i=objects.find(self->rexx_handle);
            if(i!=objects.end()){ local->ReleaseGlobalReference(i->second); objects.erase(i); }
            local->DetachThread();
        }
        self->rexx_handle=0;
    }
    Py_TYPE(selfobj)->tp_free(selfobj);
}
static PyMethodDef RexxProjectedObject_methods[]={
    {"send",RexxProjectedObject_send,METH_VARARGS,"Send a zero-argument message to the retained ooRexx object."},
    {nullptr,nullptr,0,nullptr}
};
/* v0.31.5: natural Python member spelling for retained Rexx objects.  Keep
 * actual Python attributes (notably send) authoritative; otherwise project an
 * attribute name as a live Rexx message callable.  The callable resolves the
 * Rexx object at invocation time, preserving live Rexx dispatch rather than
 * snapshotting a method. */
static PyObject *RexxProjectedObject_getattro(PyObject *selfobj, PyObject *nameobj)
{
    PyObject *ordinary=PyObject_GenericGetAttr(selfobj,nameobj);
    if(ordinary!=nullptr) return ordinary;
    if(!PyErr_ExceptionMatches(PyExc_AttributeError)) return nullptr;
    PyErr_Clear();
    if(!PyUnicode_Check(nameobj)) return PyErr_Format(PyExc_AttributeError,"Rexx member name is not text");
    const char *name=PyUnicode_AsUTF8(nameobj);
    if(name==nullptr) return nullptr;
    std::string message(name);
    std::transform(message.begin(),message.end(),message.begin(),[](unsigned char c){return (char)std::toupper(c);});
    RexxProjectedObject *self=(RexxProjectedObject *)selfobj;
    { std::lock_guard<std::mutex> lock(object_mutex); if(objects.find(self->rexx_handle)==objects.end()) return PyErr_Format(PyExc_RuntimeError,"released Rexx projection"); }
    RexxLiveCallable *callable=PyObject_New(RexxLiveCallable,&RexxLiveCallableType);
    if(!callable) return nullptr;
    callable->rexx_handle=self->rexx_handle;
    callable->message=new std::string(message);
    callable->skip_python_receiver=false;
    callable->owner=selfobj; Py_INCREF(selfobj);
    return (PyObject *)callable;
}
static PyObject *make_rexx_projected_object(uint64_t h)
{
    { std::lock_guard<std::mutex> lock(object_mutex); if(objects.find(h)==objects.end()) return PyErr_Format(PyExc_KeyError,"unknown Rexx projection handle"); }
    RexxProjectedObject *o=PyObject_New(RexxProjectedObject,&RexxProjectedObjectType);
    if(!o) return nullptr; o->rexx_handle=h; return (PyObject *)o;
}

static PyObject *decode_rexx_arg(const std::string &encoded)
{
    /* v0.31.3: identity-bearing Python projections are arguments too.  P: and
     * C: carry retained registry handles; the temporary INCREF pins the target
     * for the duration of the Python call even if the Rexx projection is
     * concurrently finalized.  Python remains authoritative for object/type
     * identity -- this is not serialization. */
    if (encoded.rfind("P:", 0) == 0 || encoded.rfind("C:", 0) == 0) {
        char *end = nullptr;
        unsigned long long h = strtoull(encoded.c_str() + 2, &end, 10);
        if (end != nullptr && *end == '\0') {
            std::lock_guard<std::mutex> lock(py_object_mutex);
            auto i = py_objects.find((uint64_t)h);
            if (i != py_objects.end()) {
                if (encoded[0] == 'C' && !PyType_Check(i->second)) {
                    PyErr_SetString(PyExc_TypeError, "Python class argument handle does not name a type");
                    return nullptr;
                }
                Py_INCREF(i->second);
                return i->second;
            }
        }
        PyErr_SetString(PyExc_KeyError, "unknown Python projection argument handle");
        return nullptr;
    }
    if (encoded.rfind("R:", 0) == 0) {
        char *end=nullptr; unsigned long long h=strtoull(encoded.c_str()+2,&end,10);
        if(end!=nullptr && *end=='\0') return make_rexx_projected_object((uint64_t)h);
        PyErr_SetString(PyExc_ValueError,"malformed Rexx object argument handle"); return nullptr;
    }
    if (encoded.rfind("I:", 0) == 0) {
        char *end = nullptr;
        long long v = strtoll(encoded.c_str() + 2, &end, 10);
        if (end != nullptr && *end == '\0') return PyLong_FromLongLong(v);
    }
    if (encoded.rfind("S:", 0) == 0)
        return PyUnicode_DecodeUTF8(encoded.data() + 2, encoded.size() - 2, "strict");
    return PyUnicode_DecodeUTF8(encoded.data(), encoded.size(), "strict");
}

/* v0.31.2: arbitrary positional scalar arguments travel in one length-framed
 * packet so the Rexx side no longer needs a fixed external-function arity.
 * Frame: @ARGS:<decimal-length>:<encoded-arg>... where each encoded argument
 * retains the existing I:/S: scalar codec.  Length framing makes separators in
 * strings inert and keeps this an extension of, not a replacement for, the
 * established argument semantics. */
static PyObject *decode_rexx_arg_packet(const std::string &packet)
{
    if (packet.rfind("@ARGS:", 0) != 0) return nullptr;
    PyObject *tuple = PyTuple_New(0);
    if (tuple == nullptr) return nullptr;
    size_t pos = 6;
    std::vector<PyObject *> values;
    while (pos < packet.size()) {
        size_t colon = packet.find(':', pos);
        if (colon == std::string::npos || colon == pos) goto bad;
        char *end = nullptr;
        unsigned long long n = strtoull(packet.substr(pos, colon-pos).c_str(), &end, 10);
        if (end == nullptr || *end != '\0') goto bad;
        pos = colon + 1;
        if (n > packet.size() - pos) goto bad;
        {
            PyObject *v = decode_rexx_arg(packet.substr(pos, (size_t)n));
            if (v == nullptr) goto bad;
            values.push_back(v);
        }
        pos += (size_t)n;
    }
    Py_DECREF(tuple);
    tuple = PyTuple_New((Py_ssize_t)values.size());
    if (tuple == nullptr) goto bad_no_tuple;
    for (Py_ssize_t i=0; i<(Py_ssize_t)values.size(); ++i) PyTuple_SET_ITEM(tuple, i, values[(size_t)i]);
    return tuple;
bad:
    Py_DECREF(tuple);
bad_no_tuple:
    for (PyObject *v : values) Py_DECREF(v);
    PyErr_SetString(PyExc_ValueError, "malformed Rexx argument packet");
    return nullptr;
}

/* Rexx external-function trampoline for projected Python members.  The Python
 * target is INCREF-pinned outside the registry lock so concurrent release cannot
 * invalidate it while descriptor lookup or invocation is in progress. */
static size_t REXXENTRY py_object_call(CONSTANT_STRING, size_t argc, PCONSTRXSTRING argv, CONSTANT_STRING, PRXSTRING result)
{
    PyGILState_STATE gil = PyGILState_Ensure();
    std::string answer = "PYTHON_OBJECT_ERROR";
    if (argc >= 2) {
        std::string hs(argv[0].strptr, argv[0].strlength);
        std::string rexx_name(argv[1].strptr, argv[1].strlength);
        uint64_t h = strtoull(hs.c_str(), nullptr, 10);
        PyObject *obj = nullptr;
        std::string mn;
        {
            std::lock_guard<std::mutex> lock(py_object_mutex);
            auto i=py_objects.find(h);
            if(i!=py_objects.end()) { obj=i->second; Py_INCREF(obj); }
            auto cm=py_method_cases.find(h);
            if(cm!=py_method_cases.end()) {
                auto exact=cm->second.find(rexx_name);
                if(exact!=cm->second.end()) mn=exact->second;
            }
        }
        if(mn.empty()) {
            mn=rexx_name;
            std::transform(mn.begin(), mn.end(), mn.begin(), [](unsigned char c){ return (char)std::tolower(c); });
        }
        if (obj != nullptr) {
            PyObject *tuple = nullptr;
            bool ok = true;
            if (argc == 3) {
                std::string maybe_packet(argv[2].strptr, argv[2].strlength);
                if (maybe_packet.rfind("@ARGS:", 0) == 0) tuple = decode_rexx_arg_packet(maybe_packet);
            }
            if (tuple == nullptr && !PyErr_Occurred()) {
                tuple = PyTuple_New(argc > 2 ? (Py_ssize_t)(argc - 2) : 0);
                ok = tuple != nullptr;
                for (size_t n = 2; ok && n < argc; ++n) {
                    std::string encoded(argv[n].strptr, argv[n].strlength);
                    PyObject *a = decode_rexx_arg(encoded);
                    if (a == nullptr) ok = false;
                    else PyTuple_SET_ITEM(tuple, (Py_ssize_t)(n - 2), a);
                }
            } else if (tuple == nullptr) ok = false;
            PyObject *ret = nullptr;
            if (ok) {
                PyObject *callable = PyObject_GetAttrString(obj, mn.c_str());
                if (callable != nullptr) { ret = PyObject_CallObject(callable, tuple); Py_DECREF(callable); }
            }
            Py_XDECREF(tuple);
            if (ret != nullptr) {
                if (PyUnicode_Check(ret)) {
                    const char *u=PyUnicode_AsUTF8(ret); if(u) answer=u;
                } else if (PyLong_Check(ret)) {
                    PyObject *st=PyObject_Str(ret); if(st){const char *u=PyUnicode_AsUTF8(st); if(u) answer=u; Py_DECREF(st);}
                } else if (ret == Py_None) {
                    answer = "";
                } else if (PyType_Check(ret)) {
                    uint64_t rh = retain_python_object(ret);
                    answer = "@PYCLASS:" + std::to_string(rh);
                } else {
                    uint64_t rh = retain_python_object(ret);
                    answer = "@PYOBJ:" + std::to_string(rh);
                }
                Py_DECREF(ret);
            } else {
                /* PYCALL still uses the legacy string status channel.  Do not dump
                 * an expected foreign lookup/call failure to stderr: callers receive
                 * PYTHON_OBJECT_ERROR until the structured foreign-error channel
                 * replaces this compatibility path. */
                PyErr_Clear();
            }
            Py_DECREF(obj);
        }
    }
    if (result->strptr != nullptr) { size_t n=answer.size(); if(n>255)n=255; memcpy(result->strptr, answer.data(), n); result->strlength=n; }
    PyGILState_Release(gil); return 0;
}

static PyObject *create_live_rexx_target(PyObject *, PyObject *args)
{
 const char *factory;if(!PyArg_ParseTuple(args,"s",&factory))return nullptr;if(!ensure_interpreter())return PyErr_Format(PyExc_RuntimeError,"RexxCreateInterpreter failed");
 RexxArrayObject a=tc->NewArray(1);tc->ArrayPut(a,tc->String("LIVE_REXX_TARGET"),1);RexxObjectPtr o=tc->CallProgram(factory,a);
 if(o==NULLOBJECT||tc->CheckCondition()){tc->ClearCondition();return PyErr_Format(PyExc_RuntimeError,"ooRexx live target factory failed");}return PyLong_FromUnsignedLongLong(retain(o));
}

static PyObject *create_object_collection(PyObject *, PyObject *args)
{
    const char *factory; if(!PyArg_ParseTuple(args,"s",&factory)) return nullptr;
    if(!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError,"RexxCreateInterpreter failed");
    RexxArrayObject a=tc->NewArray(1); tc->ArrayPut(a,tc->String("OBJECT_COLLECTION"),1);
    RexxObjectPtr o=tc->CallProgram(factory,a);
    if(o==NULLOBJECT || tc->CheckCondition()){tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError,"ooRexx object collection factory failed");}
    return PyLong_FromUnsignedLongLong(retain(o));
}

static size_t REXXENTRY py_type_query(CONSTANT_STRING, size_t, PCONSTRXSTRING, CONSTANT_STRING, PRXSTRING);
static size_t REXXENTRY py_type_relation(CONSTANT_STRING, size_t, PCONSTRXSTRING, CONSTANT_STRING, PRXSTRING);

/* Create a Rexx proxy for OBJ and one logical Python-registry ownership.
 * Construction is transactional: metadata is validated first and any failed
 * Rexx factory call rolls back exactly the ownership acquired here. */
static PyObject *wrap_python_object(PyObject *, PyObject *args)
{
    PyObject *obj; const char *factory; PyObject *case_map=Py_None;
    if(!PyArg_ParseTuple(args,"Os|O",&obj,&factory,&case_map)) return nullptr;
    if(case_map != Py_None && !PyDict_Check(case_map)) return PyErr_Format(PyExc_TypeError,"method casing argument must be a dict or None");
    if(!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError,"RexxCreateInterpreter failed");
    RexxReturnCode frc=RexxRegisterFunctionExe("PYCALL",(REXXPFN)py_object_call);
    RexxRegisterFunctionExe("PYTYPEQUERY",(REXXPFN)py_type_query);
    RexxRegisterFunctionExe("PYTYPERELATION",(REXXPFN)py_type_relation);
    RexxRegisterFunctionExe("PYCLASSLOAD",(REXXPFN)py_class_load);
    RexxRegisterFunctionExe("PYCLASSCONSTRUCT",(REXXPFN)py_class_construct);
    RexxRegisterFunctionExe("PYRELEASE",(REXXPFN)py_object_release);
    if(frc!=RXFUNC_OK && frc!=RXFUNC_DEFINED) return PyErr_Format(PyExc_RuntimeError,"RexxRegisterFunctionExe PYCALL rc=%zu",(size_t)frc);
    /* Validate and normalize the case map before retaining OBJ so malformed
     * metadata cannot leak a registry ownership count. */
    std::map<std::string, std::string> normalized_cases;
    if(case_map != Py_None) {
        PyObject *key, *value; Py_ssize_t pos=0;
        while(PyDict_Next(case_map,&pos,&key,&value)) {
            if(!PyUnicode_Check(key) || !PyUnicode_Check(value))
                return PyErr_Format(PyExc_TypeError,"method casing keys and values must be strings");
            const char *k=PyUnicode_AsUTF8(key), *v=PyUnicode_AsUTF8(value);
            if(k==nullptr || v==nullptr) return nullptr;
            std::string rk(k);
            std::transform(rk.begin(),rk.end(),rk.begin(),[](unsigned char c){return (char)std::toupper(c);});
            normalized_cases[rk]=v;
        }
    }

    uint64_t ph = retain_python_object(obj);
    {
        std::lock_guard<std::mutex> lock(py_object_mutex);
        if(!normalized_cases.empty()) py_method_cases[ph]=normalized_cases;
    }
    std::string hs=std::to_string(ph);
    RexxArrayObject a=tc->NewArray(2); tc->ArrayPut(a,tc->String("PYTHON_PROXY"),1); tc->ArrayPut(a,tc->String(hs.c_str()),2);
    RexxObjectPtr o=tc->CallProgram(factory,a);
    if(o==NULLOBJECT || tc->CheckCondition()) {
        tc->ClearCondition();
        release_python_object_handle(ph);
        return PyErr_Format(PyExc_RuntimeError,"ooRexx Python proxy factory failed");
    }
    return Py_BuildValue("KK",(unsigned long long)retain(o),(unsigned long long)ph);
}

static PyObject *send2_index_string(PyObject *, PyObject *args)
{
    unsigned long long h; const char *message,*text; long index;
    if(!PyArg_ParseTuple(args,"Ksls",&h,&message,&index,&text)) return nullptr;
    RexxObjectPtr o=lookup(h); if(o==NULLOBJECT) return PyErr_Format(PyExc_KeyError,"unknown Rexx object handle");
    RexxObjectPtr r=tc->SendMessage2(o,message,tc->Int64ToObject(index),tc->String(text));
    if(tc->CheckCondition()){tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError,"ooRexx message %s failed",message);}
    std::string st=rexx_string(r); return PyUnicode_DecodeUTF8(st.data(),st.size(),"strict");
}

static PyObject *send2_string_int(PyObject *, PyObject *args)
{
    unsigned long long h; const char *message,*text; long long number;
    if(!PyArg_ParseTuple(args,"KssL",&h,&message,&text,&number)) return nullptr;
    RexxObjectPtr o=lookup(h); if(o==NULLOBJECT) return PyErr_Format(PyExc_KeyError,"unknown Rexx object handle");
    RexxObjectPtr r=tc->SendMessage2(o,message,tc->String(text),tc->Int64ToObject(number));
    if(tc->CheckCondition()){tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError,"ooRexx message %s failed",message);}
    std::string st=rexx_string(r); return PyUnicode_DecodeUTF8(st.data(),st.size(),"strict");
}

static PyObject *py_retain_python_object(PyObject *, PyObject *args)
{
    PyObject *obj;
    if (!PyArg_ParseTuple(args, "O", &obj)) return nullptr;
    return PyLong_FromUnsignedLongLong(retain_python_object(obj));
}

static PyObject *rexx_slots_to_python(PyObject *, PyObject *args)
{
    unsigned long long h;
    PyObject *omitted;
    if (!PyArg_ParseTuple(args, "KO", &h, &omitted)) return nullptr;

    PyObject *target = nullptr;
    {
        std::lock_guard<std::mutex> lock(py_object_mutex);
        auto it = py_objects.find((uint64_t)h);
        if (it != py_objects.end()) {
            target = it->second;
            Py_INCREF(target);
        }
    }
    if (target == nullptr)
        return PyErr_Format(PyExc_KeyError, "unknown Python object handle");

    PyObject *callable = PyObject_GetAttrString(target, "receive_slots");
    Py_DECREF(target);
    if (callable == nullptr) return nullptr;

    PyObject *none = Py_None; Py_INCREF(none);
    PyObject *empty = PyUnicode_FromString("");
    PyObject *value = PyUnicode_FromString("hello");
    if (empty == nullptr || value == nullptr) {
        Py_DECREF(callable); Py_DECREF(none);
        Py_XDECREF(empty); Py_XDECREF(value);
        return nullptr;
    }

    PyObject *callargs = PyTuple_Pack(4, omitted, none, empty, value);
    Py_DECREF(none); Py_DECREF(empty); Py_DECREF(value);
    if (callargs == nullptr) { Py_DECREF(callable); return nullptr; }

    PyObject *result = PyObject_CallObject(callable, callargs);
    Py_DECREF(callargs);
    Py_DECREF(callable);
    return result;
}


static void set_rexx_result(PRXSTRING result, const std::string &answer)
{
    if (result->strptr == nullptr || result->strlength < answer.size())
        result->strptr = (char *)RexxAllocateMemory(answer.size() + 1);
    if (!answer.empty()) memcpy(result->strptr, answer.data(), answer.size());
    result->strptr[answer.size()] = '\0';
    result->strlength = answer.size();
}

/* Resolve a Python type by module + qualified name.  Python remains the owner
 * of class identity; Rexx receives only a retained opaque handle.  Optional
 * class-path entries are scoped to this import operation and removed again
 * before control returns to Rexx. */
static size_t REXXENTRY py_class_load(CONSTANT_STRING, size_t argc, PCONSTRXSTRING argv, CONSTANT_STRING, PRXSTRING result)
{
    if (argc < 2 || argc > 3) return RXFUNC_BADTYPE;
    std::string module_name(argv[0].strptr, argv[0].strlength);
    std::string qual_name(argv[1].strptr, argv[1].strlength);
    std::string path_text = argc == 3 ? std::string(argv[2].strptr, argv[2].strlength) : std::string();
    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *sys_path = PySys_GetObject("path"); /* borrowed */
    std::vector<PyObject *> inserted;
    if (!path_text.empty() && sys_path != nullptr) {
#ifdef _WIN32
        const char sep = ';';
#else
        const char sep = ':';
#endif
        size_t start = 0;
        while (start <= path_text.size()) {
            size_t end = path_text.find(sep, start);
            std::string one = path_text.substr(start, end == std::string::npos ? std::string::npos : end - start);
            if (!one.empty()) {
                PyObject *u = PyUnicode_FromStringAndSize(one.data(), (Py_ssize_t)one.size());
                if (u != nullptr && PyList_Insert(sys_path, 0, u) == 0) inserted.push_back(u);
                else Py_XDECREF(u);
            }
            if (end == std::string::npos) break;
            start = end + 1;
        }
    }
    PyObject *obj = PyImport_ImportModule(module_name.c_str());
    if (obj != nullptr) {
        size_t start = 0;
        while (start < qual_name.size() && obj != nullptr) {
            size_t dot = qual_name.find('.', start);
            std::string part = qual_name.substr(start, dot == std::string::npos ? std::string::npos : dot - start);
            PyObject *next = PyObject_GetAttrString(obj, part.c_str());
            Py_DECREF(obj); obj = next;
            if (dot == std::string::npos) break;
            start = dot + 1;
        }
    }
    for (auto it = inserted.rbegin(); it != inserted.rend(); ++it) {
        Py_ssize_t pos = PySequence_Index(sys_path, *it);
        if (pos >= 0) PySequence_DelItem(sys_path, pos); else PyErr_Clear();
        Py_DECREF(*it);
    }
    std::string answer;
    if (obj == nullptr) {
        PyErr_Clear(); answer = "ERROR:class-load";
    } else if (!PyType_Check(obj)) {
        Py_DECREF(obj); answer = "ERROR:not-a-class";
    } else {
        uint64_t h = retain_python_object(obj);
        Py_DECREF(obj);
        answer = "@PYCLASS:" + std::to_string(h);
    }
    set_rexx_result(result, answer);
    PyGILState_Release(gil);
    return RXFUNC_OK;
}

/* Invoke a retained Python type as a constructor.  Argument encoding is the
 * same deliberately small scalar codec currently used by Rexx UNKNOWN. */
static size_t REXXENTRY py_class_construct(CONSTANT_STRING, size_t argc, PCONSTRXSTRING argv, CONSTANT_STRING, PRXSTRING result)
{
    if (argc < 1) return RXFUNC_BADTYPE;
    uint64_t h = strtoull(argv[0].strptr, nullptr, 10);
    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *cls = nullptr;
    {
        std::lock_guard<std::mutex> lock(py_object_mutex);
        auto i = py_objects.find(h);
        if (i != py_objects.end()) { cls = i->second; Py_INCREF(cls); }
    }
    std::string answer;
    if (cls == nullptr || !PyType_Check(cls)) answer = "ERROR:unknown-class";
    else {
        PyObject *tuple = nullptr;
        bool ok = true;
        if (argc == 2) {
            std::string maybe_packet(argv[1].strptr, argv[1].strlength);
            if (maybe_packet.rfind("@ARGS:", 0) == 0) tuple = decode_rexx_arg_packet(maybe_packet);
        }
        if (tuple == nullptr && !PyErr_Occurred()) {
            tuple = PyTuple_New((Py_ssize_t)(argc - 1));
            ok = tuple != nullptr;
            for (size_t n = 1; ok && n < argc; ++n) {
                std::string encoded(argv[n].strptr, argv[n].strlength);
                PyObject *a = decode_rexx_arg(encoded);
                if (a == nullptr) ok = false;
                else PyTuple_SET_ITEM(tuple, (Py_ssize_t)(n - 1), a);
            }
        } else if (tuple == nullptr) ok = false;
        PyObject *obj = ok ? PyObject_CallObject(cls, tuple) : nullptr;
        Py_XDECREF(tuple);
        if (obj == nullptr) { PyErr_Clear(); answer = "ERROR:construct"; }
        else {
            uint64_t oh = retain_python_object(obj); Py_DECREF(obj);
            answer = "@PYOBJ:" + std::to_string(oh);
        }
    }
    Py_XDECREF(cls);
    set_rexx_result(result, answer);
    PyGILState_Release(gil);
    return RXFUNC_OK;
}



static size_t REXXENTRY py_type_query(CONSTANT_STRING, size_t argc, PCONSTRXSTRING argv, CONSTANT_STRING, PRXSTRING result)
{
    if(argc < 2) return RXFUNC_BADTYPE;
    uint64_t h=strtoull(argv[0].strptr,nullptr,10);
    std::string op(argv[1].strptr,argv[1].strlength);
    PyGILState_STATE gil=PyGILState_Ensure();
    PyObject *obj=nullptr;
    { std::lock_guard<std::mutex> lock(py_object_mutex); auto i=py_objects.find(h); if(i!=py_objects.end()){obj=i->second;Py_INCREF(obj);} }
    std::string answer;
    if(obj==nullptr) answer="ERROR:unknown-handle";
    else if(op=="CLASS") {
        PyObject *cls=(PyObject *)Py_TYPE(obj); Py_INCREF(cls);
        uint64_t ch=retain_python_object(cls); Py_DECREF(cls); answer="@PYCLASS:"+std::to_string(ch);
    } else if(op=="INFO") {
        PyObject *m=PyObject_GetAttrString(obj,"__module__"),*q=PyObject_GetAttrString(obj,"__qualname__");
        if(m&&q) answer=std::string(PyUnicode_AsUTF8(m))+":"+PyUnicode_AsUTF8(q);
        else {PyErr_Clear();answer="ERROR:class-info";}
        Py_XDECREF(m);Py_XDECREF(q);
    } else if(op=="BASES" || op=="MRO") {
        PyObject *seq=PyObject_GetAttrString(obj,op=="BASES"?"__bases__":"__mro__");
        if(seq && PyTuple_Check(seq)) {
            for(Py_ssize_t i=0;i<PyTuple_GET_SIZE(seq);++i) {
                PyObject *cls=PyTuple_GET_ITEM(seq,i);
                uint64_t ch=retain_python_object(cls);
                if(i) answer += ",";
                answer += std::to_string(ch);
            }
        } else { PyErr_Clear(); answer="ERROR:not-class"; }
        Py_XDECREF(seq);
    } else answer="ERROR:bad-op";
    Py_XDECREF(obj);
    PyGILState_Release(gil);
    if(result->strptr==nullptr || result->strlength<answer.size()) result->strptr=(char *)RexxAllocateMemory(answer.size()+1);
    memcpy(result->strptr,answer.data(),answer.size());result->strptr[answer.size()]='\0';result->strlength=answer.size();
    return RXFUNC_OK;
}
static size_t REXXENTRY py_type_relation(CONSTANT_STRING, size_t argc, PCONSTRXSTRING argv, CONSTANT_STRING, PRXSTRING result)
{
    if(argc<3)return RXFUNC_BADTYPE;
    uint64_t a=strtoull(argv[0].strptr,nullptr,10),b=strtoull(argv[1].strptr,nullptr,10);
    std::string op(argv[2].strptr,argv[2].strlength);
    PyGILState_STATE gil=PyGILState_Ensure(); PyObject *ao=nullptr,*bo=nullptr;
    {std::lock_guard<std::mutex> lock(py_object_mutex);auto ai=py_objects.find(a),bi=py_objects.find(b);if(ai!=py_objects.end()&&bi!=py_objects.end()){ao=ai->second;bo=bi->second;Py_INCREF(ao);Py_INCREF(bo);}}
    int rc=-1;if(ao&&bo) rc=(op=="INSTANCE")?PyObject_IsInstance(ao,bo):(op=="SUBCLASS")?PyObject_IsSubclass(ao,bo):-1;
    Py_XDECREF(ao);Py_XDECREF(bo);if(rc<0)PyErr_Clear();PyGILState_Release(gil);
    const char *ans=rc==1?"1":"0"; if(result->strptr==nullptr||result->strlength<1)result->strptr=(char*)RexxAllocateMemory(2);
    result->strptr[0]=ans[0];result->strptr[1]='\0';result->strlength=1;return RXFUNC_OK;
}
static PyObject *py_direct_base_handles(PyObject *, PyObject *args)
{
    unsigned long long h;
    if(!PyArg_ParseTuple(args,"K",&h)) return nullptr;
    PyObject *cls=nullptr;
    { std::lock_guard<std::mutex> lock(py_object_mutex); auto i=py_objects.find(h);
      if(i==py_objects.end()) return PyErr_Format(PyExc_KeyError,"unknown Python class handle");
      cls=i->second; Py_INCREF(cls); }
    PyObject *bases=PyObject_GetAttrString(cls,"__bases__");
    Py_DECREF(cls);
    if(!bases) return nullptr;
    PyObject *answer=PyList_New(PyTuple_GET_SIZE(bases));
    for(Py_ssize_t i=0;i<PyTuple_GET_SIZE(bases);++i) {
        PyObject *b=PyTuple_GET_ITEM(bases,i); Py_INCREF(b);
        uint64_t bh=retain_python_object(b); Py_DECREF(b);
        PyList_SET_ITEM(answer,i,PyLong_FromUnsignedLongLong(bh));
    }
    Py_DECREF(bases);
    return answer;
}

static PyObject *py_type_handle(PyObject *, PyObject *args)
{
    unsigned long long h;
    if (!PyArg_ParseTuple(args, "K", &h)) return nullptr;
    PyObject *obj = nullptr;
    {
        std::lock_guard<std::mutex> lock(py_object_mutex);
        auto i = py_objects.find(h);
        if (i == py_objects.end()) return PyErr_Format(PyExc_KeyError, "unknown Python object handle");
        obj = (PyObject *)Py_TYPE(i->second);
        Py_INCREF(obj);
    }
    uint64_t result = retain_python_object(obj);
    Py_DECREF(obj);
    return PyLong_FromUnsignedLongLong(result);
}

static PyObject *py_isinstance_handle(PyObject *, PyObject *args)
{
    unsigned long long oh, ch;
    if (!PyArg_ParseTuple(args, "KK", &oh, &ch)) return nullptr;
    PyObject *obj = nullptr, *cls = nullptr;
    {
        std::lock_guard<std::mutex> lock(py_object_mutex);
        auto oi=py_objects.find(oh), ci=py_objects.find(ch);
        if (oi==py_objects.end() || ci==py_objects.end())
            return PyErr_Format(PyExc_KeyError, "unknown Python object/class handle");
        obj=oi->second; cls=ci->second; Py_INCREF(obj); Py_INCREF(cls);
    }
    int rc=PyObject_IsInstance(obj, cls);
    Py_DECREF(obj); Py_DECREF(cls);
    if (rc < 0) return nullptr;
    return PyBool_FromLong(rc);
}

static PyObject *py_issubclass_handle(PyObject *, PyObject *args)
{
    unsigned long long ah, bh;
    if (!PyArg_ParseTuple(args, "KK", &ah, &bh)) return nullptr;
    PyObject *a=nullptr,*b=nullptr;
    {
        std::lock_guard<std::mutex> lock(py_object_mutex);
        auto ai=py_objects.find(ah), bi=py_objects.find(bh);
        if(ai==py_objects.end() || bi==py_objects.end())
            return PyErr_Format(PyExc_KeyError, "unknown Python class handle");
        a=ai->second;b=bi->second;Py_INCREF(a);Py_INCREF(b);
    }
    int rc=PyObject_IsSubclass(a,b);
    Py_DECREF(a);Py_DECREF(b);
    if(rc<0)return nullptr;
    return PyBool_FromLong(rc);
}

static PyObject *py_class_info(PyObject *, PyObject *args)
{
    unsigned long long h;
    if (!PyArg_ParseTuple(args, "K", &h)) return nullptr;
    PyObject *cls=nullptr;
    {
        std::lock_guard<std::mutex> lock(py_object_mutex);
        auto i=py_objects.find(h);
        if(i==py_objects.end()) return PyErr_Format(PyExc_KeyError,"unknown Python class handle");
        cls=i->second;Py_INCREF(cls);
    }
    PyObject *module=PyObject_GetAttrString(cls,"__module__");
    PyObject *qual=PyObject_GetAttrString(cls,"__qualname__");
    PyObject *mro=PyObject_GetAttrString(cls,"__mro__");
    if(!module||!qual||!mro){Py_XDECREF(module);Py_XDECREF(qual);Py_XDECREF(mro);Py_DECREF(cls);return nullptr;}
    PyObject *names=PyList_New(PyTuple_GET_SIZE(mro));
    for(Py_ssize_t i=0;i<PyTuple_GET_SIZE(mro);++i){
        PyObject *c=PyTuple_GET_ITEM(mro,i);
        PyObject *cm=PyObject_GetAttrString(c,"__module__");
        PyObject *cq=PyObject_GetAttrString(c,"__qualname__");
        PyObject *full=PyUnicode_FromFormat("%U.%U",cm,cq);
        Py_DECREF(cm);Py_DECREF(cq);PyList_SET_ITEM(names,i,full);
    }
    PyObject *answer=Py_BuildValue("{s:O,s:O,s:O}","module",module,"qualname",qual,"mro",names);
    Py_DECREF(module);Py_DECREF(qual);Py_DECREF(mro);Py_DECREF(names);Py_DECREF(cls);
    return answer;
}

/* Python API wrapper for one idempotent logical registry release. */
static PyObject *release_python_object(PyObject *, PyObject *args)
{
    unsigned long long h; if(!PyArg_ParseTuple(args,"K",&h)) return nullptr;
    release_python_object_handle(h);
    Py_RETURN_NONE;
}

/* Diagnostic used by lifetime torture tests; not part of semantic dispatch. */
static PyObject *python_object_retain_count(PyObject *, PyObject *args)
{
    unsigned long long h; if(!PyArg_ParseTuple(args,"K",&h)) return nullptr;
    std::lock_guard<std::mutex> lock(py_object_mutex);
    auto i=py_object_retain_counts.find(h);
    return PyLong_FromSize_t(i==py_object_retain_counts.end()?0:i->second);
}

static PyObject *run_demo(PyObject *, PyObject *args)
{
    PyObject *obj; const char *method, *demo, *macro;
    if (!PyArg_ParseTuple(args, "Osss", &obj, &method, &demo, &macro)) return nullptr;
    Py_XINCREF(obj); Py_XDECREF(receiver); receiver = obj; method_name = method;
    RexxReturnCode frc = RexxRegisterFunctionExe("PYCALLBACK", (REXXPFN)py_callback);
    if (frc != RXFUNC_OK && frc != RXFUNC_DEFINED) return PyErr_Format(PyExc_RuntimeError, "RexxRegisterFunctionExe rc=%zu", (size_t)frc);
    RexxReturnCode mrc = RexxAddMacro("PYALARM", macro, RXMACRO_SEARCH_BEFORE);
    if (mrc != 0) { RexxDeregisterFunction("PYCALLBACK"); return PyErr_Format(PyExc_RuntimeError, "RexxAddMacro rc=%zu", (size_t)mrc); }
    unsigned short pos = 0; RexxReturnCode qrc = RexxQueryMacro("PYALARM", &pos);
    if (qrc != 0) { RexxDropMacro("PYALARM"); RexxDeregisterFunction("PYCALLBACK"); return PyErr_Format(PyExc_RuntimeError, "RexxQueryMacro rc=%zu", (size_t)qrc); }
    short rc = 0; RXSTRING result; char buf[256] = {0}; result.strptr = buf; result.strlength = sizeof(buf);
    int api_rc = RexxStart(0, nullptr, demo, nullptr, "SYSTEM", RXCOMMAND, nullptr, &rc, &result);
    RexxDropMacro("PYALARM"); RexxDeregisterFunction("PYCALLBACK");
    if (api_rc != 0) return PyErr_Format(PyExc_RuntimeError, "RexxStart api_rc=%d rexx_rc=%d", api_rc, (int)rc);
    return Py_BuildValue("{s:i,s:i,s:i,s:s#}", "api_rc", api_rc, "rexx_rc", (int)rc, "macro_position", (int)pos, "result", result.strptr, (Py_ssize_t)result.strlength);
}

static PyObject *create_unknown_collision(PyObject *, PyObject *args)
{
    const char *factory;
    if (!PyArg_ParseTuple(args, "s", &factory)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxArrayObject a = tc->NewArray(1);
    tc->ArrayPut(a, tc->String("UNKNOWN_COLLISION"), 1);
    RexxObjectPtr o = tc->CallProgram(factory, a);
    if (o == NULLOBJECT || tc->CheckCondition()) {
        tc->ClearCondition();
        return PyErr_Format(PyExc_RuntimeError, "ooRexx UNKNOWN collision factory failed");
    }
    return PyLong_FromUnsignedLongLong(retain(o));
}

static PyObject *install_unknown_projection(PyObject *, PyObject *args)
{
    unsigned long long rh, ph; const char *names;
    if (!PyArg_ParseTuple(args, "KKs", &rh, &ph, &names)) return nullptr;
    RexxReturnCode frc = RexxRegisterFunctionExe("PYCALL", (REXXPFN)py_object_call);
    if (frc != RXFUNC_OK && frc != RXFUNC_DEFINED)
        return PyErr_Format(PyExc_RuntimeError, "RexxRegisterFunctionExe PYCALL rc=%zu", (size_t)frc);
    RexxObjectPtr o = lookup(rh);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx object handle");
    RexxArrayObject a = tc->NewArray(2);
    tc->ArrayPut(a, tc->UnsignedInt64ToObject(ph), 1);
    tc->ArrayPut(a, tc->String(names), 2);
    RexxObjectPtr r = tc->SendMessage(o, "INSTALLPYTHONPROJECTION", a);
    if (r == NULLOBJECT || tc->CheckCondition()) {
        tc->ClearCondition();
        return PyErr_Format(PyExc_RuntimeError, "installPythonProjection failed");
    }
    std::string v = rexx_string(r);
    return PyUnicode_DecodeUTF8(v.data(), v.size(), "strict");
}

static PyObject *send0_text(PyObject *, PyObject *args)
{
    unsigned long long h; const char *message;
    if (!PyArg_ParseTuple(args, "Ks", &h, &message)) return nullptr;
    RexxObjectPtr o = lookup(h);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx object handle");
    RexxObjectPtr r = tc->SendMessage0(o, message);
    if (r == NULLOBJECT || tc->CheckCondition()) {
        tc->ClearCondition();
        return PyErr_Format(PyExc_RuntimeError, "Rexx send failed for %s", message);
    }
    std::string v = rexx_string(r);
    return PyUnicode_DecodeUTF8(v.data(), v.size(), "strict");
}


static PyObject *call_program0_text(PyObject *, PyObject *args)
{
    const char *program;
    if (!PyArg_ParseTuple(args, "s", &program)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxArrayObject a = tc->NewArray(0);
    RexxObjectPtr r = tc->CallProgram(program, a);
    if (r == NULLOBJECT || tc->CheckCondition()) {
        tc->DisplayCondition();
        tc->ClearCondition();
        return PyErr_Format(PyExc_RuntimeError, "ooRexx program failed: %s", program);
    }
    std::string v = rexx_string(r);
    return PyUnicode_DecodeUTF8(v.data(), v.size(), "strict");
}

/* Native ooRexx method seam: unlike the classic external-function ABI this
 * receives the actual RexxObjectPtr.  It is therefore the correct place to
 * retain an arbitrary Rexx argument without stringifying it. */
RexxMethod1(RexxObjectPtr, retain_rexx_argument, RexxObjectPtr, object)
{
    if(object==NULLOBJECT) return NULLOBJECT;
    uint64_t h=retain(object);
    return context->UnsignedInt64ToObject(h);
}
static RexxMethodEntry rexxpython_methods[]={
    REXX_METHOD(RETAIN_REXX_ARGUMENT, retain_rexx_argument),
    REXX_LAST_METHOD()
};
RexxPackageEntry rexxpython_package_entry={
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_3_0,
    "rexxpython_poc",
    "0.31.7",
    nullptr,nullptr,nullptr,rexxpython_methods
};
OOREXX_GET_PACKAGE(rexxpython);

static PyMethodDef methods[] = {
 {"bootstrap_rexx_package_space", bootstrap_rexx_package_space, METH_VARARGS, nullptr}, {"create_animal", create_animal, METH_VARARGS, nullptr}, {"create_guarded", create_guarded, METH_VARARGS, nullptr}, {"create_argument_probe", create_argument_probe, METH_VARARGS, nullptr}, {"argument_probe_call", argument_probe_call, METH_VARARGS, nullptr}, {"create_stem", create_stem, METH_VARARGS, nullptr}, {"stem_get", stem_get, METH_VARARGS, nullptr}, {"stem_set", stem_set, METH_VARARGS, nullptr}, {"consume_stem_rexx", consume_stem_rexx, METH_VARARGS, nullptr}, {"create_live_rexx_target", create_live_rexx_target, METH_VARARGS, nullptr}, {"create_object_collection", create_object_collection, METH_VARARGS, nullptr}, {"wrap_python_object", wrap_python_object, METH_VARARGS, nullptr}, {"create_collection", create_collection, METH_VARARGS, nullptr},
 {"send0_attached", send0_attached, METH_VARARGS, nullptr}, {"send0", send0, METH_VARARGS, nullptr}, {"send0_handle", send0_handle, METH_VARARGS, nullptr}, {"send1_handle", send1_handle, METH_VARARGS, nullptr}, {"send1_index_handle", send1_index_handle, METH_VARARGS, nullptr},
 {"send2_index_string", send2_index_string, METH_VARARGS, nullptr}, {"send2_string_int", send2_string_int, METH_VARARGS, nullptr}, {"send0_text", send0_text, METH_VARARGS, nullptr}, {"call_program0_text", call_program0_text, METH_VARARGS, nullptr},
 {"create_unknown_collision", create_unknown_collision, METH_VARARGS, nullptr},
 {"install_unknown_projection", install_unknown_projection, METH_VARARGS, nullptr},
 {"retain_python_object", py_retain_python_object, METH_VARARGS, nullptr},
 {"rexx_slots_to_python", rexx_slots_to_python, METH_VARARGS, nullptr},
 {"py_direct_base_handles", py_direct_base_handles, METH_VARARGS, nullptr}, {"py_type_handle", py_type_handle, METH_VARARGS, nullptr}, {"py_isinstance_handle", py_isinstance_handle, METH_VARARGS, nullptr}, {"py_issubclass_handle", py_issubclass_handle, METH_VARARGS, nullptr}, {"py_class_info", py_class_info, METH_VARARGS, nullptr}, {"python_object_retain_count", python_object_retain_count, METH_VARARGS, nullptr}, {"release_python_object", release_python_object, METH_VARARGS, nullptr}, {"release_handle", release_handle, METH_VARARGS, nullptr}, {"make_rexx_live_callable", make_rexx_live_callable, METH_VARARGS, nullptr}, {"revoke_rexx_handle", revoke_rexx_handle, METH_VARARGS, nullptr}, {"run_demo", run_demo, METH_VARARGS, nullptr}, {nullptr,nullptr,0,nullptr}};
static struct PyModuleDef module = {PyModuleDef_HEAD_INIT, "_rexxpython_poc", nullptr, -1, methods};
PyMODINIT_FUNC PyInit__rexxpython_poc(void) {
 RexxLiveCallableType.tp_name="_rexxpython_poc.RexxLiveCallable"; RexxLiveCallableType.tp_basicsize=sizeof(RexxLiveCallable); RexxLiveCallableType.tp_flags=Py_TPFLAGS_DEFAULT; RexxLiveCallableType.tp_call=RexxLiveCallable_call; RexxLiveCallableType.tp_dealloc=RexxLiveCallable_dealloc; RexxLiveCallableType.tp_descr_get=RexxLiveCallable_descr_get; if(PyType_Ready(&RexxLiveCallableType)<0)return nullptr;
 RexxProjectedObjectType.tp_name="_rexxpython_poc.RexxObject"; RexxProjectedObjectType.tp_basicsize=sizeof(RexxProjectedObject); RexxProjectedObjectType.tp_flags=Py_TPFLAGS_DEFAULT; RexxProjectedObjectType.tp_methods=RexxProjectedObject_methods; RexxProjectedObjectType.tp_getattro=RexxProjectedObject_getattro; RexxProjectedObjectType.tp_dealloc=RexxProjectedObject_dealloc; if(PyType_Ready(&RexxProjectedObjectType)<0)return nullptr;
 PyObject *m=PyModule_Create(&module); if(!m)return nullptr;
 RexxError=PyErr_NewException("_rexxpython_poc.RexxError",PyExc_RuntimeError,nullptr);
 if(!RexxError){Py_DECREF(m);return nullptr;}
 Py_INCREF(RexxError); if(PyModule_AddObject(m,"RexxError",RexxError)<0){Py_DECREF(RexxError);Py_DECREF(m);return nullptr;}
 Py_INCREF(&RexxProjectedObjectType); if(PyModule_AddObject(m,"RexxObject",(PyObject *)&RexxProjectedObjectType)<0){Py_DECREF(&RexxProjectedObjectType);Py_DECREF(m);return nullptr;} return m; }
