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
#include <stdint.h>
#include <cstdlib>

static PyObject *receiver = nullptr;
static std::map<uint64_t, PyObject *> py_objects;
static std::map<PyObject *, uint64_t> py_object_handles;
static std::map<uint64_t, std::map<std::string, std::string>> py_method_cases;
static uint64_t next_py_handle = 1;
static std::mutex py_object_mutex;
static std::string method_name;
static RexxInstance *instance = nullptr;
static RexxThreadContext *tc = nullptr;
static std::map<uint64_t, RexxObjectPtr> objects;
static uint64_t next_handle = 1;
static std::mutex object_mutex;

static bool ensure_interpreter()
{
    if (instance != nullptr) return true;
    return RexxCreateInterpreter(&instance, &tc, nullptr) != 0;
}

static std::string rexx_string(RexxObjectPtr o)
{
    if (o == NULLOBJECT) return std::string();
    RexxStringObject s = tc->ObjectToString(o);
    CSTRING p = tc->StringData(s);
    size_t n = tc->StringLength(s);
    return std::string(p, n);
}

static uint64_t retain(RexxObjectPtr o)
{
    RexxObjectPtr g = tc->RequestGlobalReference(o);
    std::lock_guard<std::mutex> lock(object_mutex);
    uint64_t h = next_handle++;
    objects[h] = g;
    return h;
}

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

static PyObject *rexx_slots_to_python(PyObject *, PyObject *args)
{
    unsigned long long pyh; unsigned long long arrayh; PyObject *omitted;
    if (!PyArg_ParseTuple(args, "KKO", &pyh, &arrayh, &omitted)) return nullptr;
    PyObject *target = reinterpret_cast<PyObject *>(static_cast<uintptr_t>(pyh));
    if (target == nullptr) return PyErr_Format(PyExc_KeyError, "null Python object handle");
    RexxObjectPtr raw = lookup(arrayh);
    if (raw == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx array handle");
    RexxArrayObject a = (RexxArrayObject)raw;
    size_t n = tc->ArraySize(a);
    PyObject *tuple = PyTuple_New((Py_ssize_t)n);
    if (!tuple) return nullptr;
    for (size_t i=1; i<=n; ++i) {
        RexxObjectPtr item = tc->ArrayAt(a, i);
        PyObject *v = nullptr;
        if (item == NULLOBJECT) {
            v = omitted; Py_INCREF(v);
        } else if (item == tc->Nil()) {
            v = Py_None; Py_INCREF(v);
        } else {
            std::string text = rexx_string(item);
            v = PyUnicode_DecodeUTF8(text.data(), text.size(), "strict");
        }
        if (!v) { Py_DECREF(tuple); return nullptr; }
        PyTuple_SET_ITEM(tuple, (Py_ssize_t)i-1, v);
    }
    PyObject *method = PyObject_GetAttrString(target, "receive_slots");
    if (!method) { Py_DECREF(tuple); return nullptr; }
    PyObject *result = PyObject_CallObject(method, tuple);
    Py_DECREF(method); Py_DECREF(tuple);
    return result;
}

static PyObject *create_existing_unknown(PyObject *, PyObject *args)
{
    const char *factory; unsigned long long pyh; const char *methods;
    if (!PyArg_ParseTuple(args, "sKs", &factory, &pyh, &methods)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxArrayObject a = tc->NewArray(3);
    tc->ArrayPut(a, tc->String("EXISTINGUNKNOWN"), 1);
    tc->ArrayPut(a, tc->UnsignedInt64ToObject(pyh), 2);
    tc->ArrayPut(a, tc->String(methods), 3);
    RexxObjectPtr o = tc->CallProgram(factory, a);
    if (o == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx existing-UNKNOWN factory failed"); }
    return PyLong_FromUnsignedLongLong(retain(o));
}

static PyObject *install_unknown_projection(PyObject *, PyObject *args)
{
    unsigned long long h;
    if (!PyArg_ParseTuple(args, "K", &h)) return nullptr;
    RexxObjectPtr o = lookup(h);
    if (o == NULLOBJECT) return PyErr_Format(PyExc_KeyError, "unknown Rexx object handle");
    RexxObjectPtr r = tc->SendMessage0(o, "INSTALLPYTHONPROJECTION");
    if (r == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "installPythonProjection failed"); }
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
    if (r == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "Rexx send failed for %s", message); }
    std::string v = rexx_string(r);
    const std::string prefix("!PYDISPATCH:");
    if (v.compare(0, prefix.size(), prefix) == 0) {
        RexxObjectPtr fh = tc->SendMessage0(o, "FOREIGNHANDLE");
        if (fh == NULLOBJECT || tc->CheckCondition()) {
            tc->ClearCondition();
            return PyErr_Format(PyExc_RuntimeError, "cannot obtain FOREIGNHANDLE");
        }
        uint64_t pyh = 0;
        if (!tc->ObjectToUnsignedInt64(fh, &pyh)) {
            return PyErr_Format(PyExc_RuntimeError, "invalid FOREIGNHANDLE");
        }
        PyObject *target = reinterpret_cast<PyObject *>(static_cast<uintptr_t>(pyh));
        if (target == nullptr) return PyErr_Format(PyExc_RuntimeError, "null Python target");
        std::string methodName = v.substr(prefix.size());
        PyObject *result = PyObject_CallMethod(target, methodName.c_str(), nullptr);
        if (!result) return nullptr;
        if (!PyUnicode_Check(result)) {
            PyObject *tmp = PyObject_Str(result);
            Py_DECREF(result);
            result = tmp;
        }
        return result;
    }
    return PyUnicode_DecodeUTF8(v.data(), v.size(), "strict");
}

static PyObject *create_slot_array(PyObject *, PyObject *args)
{
    const char *factory;
    if (!PyArg_ParseTuple(args, "s", &factory)) return nullptr;
    if (!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError, "RexxCreateInterpreter failed");
    RexxArrayObject a = tc->NewArray(1);
    tc->ArrayPut(a, tc->String("SLOTARRAY"), 1);
    RexxObjectPtr o = tc->CallProgram(factory, a);
    if (o == NULLOBJECT || tc->CheckCondition()) { tc->ClearCondition(); return PyErr_Format(PyExc_RuntimeError, "ooRexx slot array factory failed"); }
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

static uint64_t retain_python_object(PyObject *obj)
{
    std::lock_guard<std::mutex> lock(py_object_mutex);
    auto existing = py_object_handles.find(obj);
    if (existing != py_object_handles.end()) return existing->second;
    uint64_t h = next_py_handle++;
    Py_INCREF(obj);
    py_objects[h] = obj;
    py_object_handles[obj] = h;
    return h;
}

static PyObject *decode_rexx_arg(const std::string &encoded)
{
    if (encoded.rfind("I:", 0) == 0) {
        char *end = nullptr;
        long long v = strtoll(encoded.c_str() + 2, &end, 10);
        if (end != nullptr && *end == '\0') return PyLong_FromLongLong(v);
    }
    if (encoded.rfind("S:", 0) == 0)
        return PyUnicode_DecodeUTF8(encoded.data() + 2, encoded.size() - 2, "strict");
    return PyUnicode_DecodeUTF8(encoded.data(), encoded.size(), "strict");
}

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
            auto i=py_objects.find(h); if(i!=py_objects.end()) obj=i->second;
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
            PyObject *tuple = PyTuple_New(argc > 2 ? (Py_ssize_t)(argc - 2) : 0);
            bool ok = tuple != nullptr;
            for (size_t n = 2; ok && n < argc; ++n) {
                std::string encoded(argv[n].strptr, argv[n].strlength);
                PyObject *a = decode_rexx_arg(encoded);
                if (a == nullptr) ok = false;
                else PyTuple_SET_ITEM(tuple, (Py_ssize_t)(n - 2), a);
            }
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
                } else {
                    uint64_t rh = retain_python_object(ret);
                    answer = "@PYOBJ:" + std::to_string(rh);
                }
                Py_DECREF(ret);
            } else PyErr_Print();
        }
    }
    if (result->strptr != nullptr) { size_t n=answer.size(); if(n>255)n=255; memcpy(result->strptr, answer.data(), n); result->strlength=n; }
    PyGILState_Release(gil); return 0;
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

static PyObject *wrap_python_object(PyObject *, PyObject *args)
{
    PyObject *obj; const char *factory; PyObject *case_map=Py_None;
    if(!PyArg_ParseTuple(args,"Os|O",&obj,&factory,&case_map)) return nullptr;
    if(case_map != Py_None && !PyDict_Check(case_map)) return PyErr_Format(PyExc_TypeError,"method casing argument must be a dict or None");
    if(!ensure_interpreter()) return PyErr_Format(PyExc_RuntimeError,"RexxCreateInterpreter failed");
    RexxReturnCode frc=RexxRegisterFunctionExe("PYCALL",(REXXPFN)py_object_call);
    if(frc!=RXFUNC_OK && frc!=RXFUNC_DEFINED) return PyErr_Format(PyExc_RuntimeError,"RexxRegisterFunctionExe PYCALL rc=%zu",(size_t)frc);
    uint64_t ph = retain_python_object(obj); {
        std::lock_guard<std::mutex> lock(py_object_mutex);
        if(case_map != Py_None) {
            PyObject *key, *value; Py_ssize_t pos=0;
            while(PyDict_Next(case_map,&pos,&key,&value)) {
                if(!PyUnicode_Check(key) || !PyUnicode_Check(value)) {
                    return PyErr_Format(PyExc_TypeError,"method casing keys and values must be strings");
                }
                const char *k=PyUnicode_AsUTF8(key), *v=PyUnicode_AsUTF8(value);
                if(k==nullptr || v==nullptr) return nullptr;
                std::string rk(k); std::transform(rk.begin(),rk.end(),rk.begin(),[](unsigned char c){return (char)std::toupper(c);});
                py_method_cases[ph][rk]=v;
            }
        }
    }
    std::string hs=std::to_string(ph);
    RexxArrayObject a=tc->NewArray(2); tc->ArrayPut(a,tc->String("PYTHON_PROXY"),1); tc->ArrayPut(a,tc->String(hs.c_str()),2);
    RexxObjectPtr o=tc->CallProgram(factory,a);
    if(o==NULLOBJECT || tc->CheckCondition()){tc->ClearCondition(); std::lock_guard<std::mutex> lock(py_object_mutex); auto i=py_objects.find(ph); if(i!=py_objects.end()){Py_DECREF(i->second);py_objects.erase(i); py_method_cases.erase(ph);} return PyErr_Format(PyExc_RuntimeError,"ooRexx Python proxy factory failed");}
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

static PyObject *retain_python_object(PyObject *, PyObject *args)
{
    PyObject *object;
    if (!PyArg_ParseTuple(args, "O", &object)) return nullptr;
    Py_INCREF(object);
    return PyLong_FromUnsignedLongLong(
        static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(object)));
}

static PyObject *release_python_object(PyObject *, PyObject *args)
{
    unsigned long long h; if(!PyArg_ParseTuple(args,"K",&h)) return nullptr;
    std::lock_guard<std::mutex> lock(py_object_mutex); auto i=py_objects.find(h); if(i!=py_objects.end()){py_object_handles.erase(i->second); Py_DECREF(i->second);py_objects.erase(i);} py_method_cases.erase(h); Py_RETURN_NONE;
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

static PyMethodDef methods[] = {
 {"create_animal", create_animal, METH_VARARGS, nullptr}, {"create_guarded", create_guarded, METH_VARARGS, nullptr}, {"create_existing_unknown", create_existing_unknown, METH_VARARGS, nullptr},
    {"install_unknown_projection", install_unknown_projection, METH_VARARGS, nullptr},
    {"send0_text", send0_text, METH_VARARGS, nullptr},
    {"create_slot_array", create_slot_array, METH_VARARGS, nullptr}, {"rexx_slots_to_python", rexx_slots_to_python, METH_VARARGS, nullptr}, {"create_argument_probe", create_argument_probe, METH_VARARGS, nullptr}, {"argument_probe_call", argument_probe_call, METH_VARARGS, nullptr}, {"create_stem", create_stem, METH_VARARGS, nullptr}, {"stem_get", stem_get, METH_VARARGS, nullptr}, {"stem_set", stem_set, METH_VARARGS, nullptr}, {"create_object_collection", create_object_collection, METH_VARARGS, nullptr}, {"wrap_python_object", wrap_python_object, METH_VARARGS, nullptr}, {"create_collection", create_collection, METH_VARARGS, nullptr},
 {"send0", send0, METH_VARARGS, nullptr}, {"send0_handle", send0_handle, METH_VARARGS, nullptr}, {"send1_handle", send1_handle, METH_VARARGS, nullptr}, {"send1_index_handle", send1_index_handle, METH_VARARGS, nullptr},
 {"send2_index_string", send2_index_string, METH_VARARGS, nullptr}, {"send2_string_int", send2_string_int, METH_VARARGS, nullptr}, {"retain_python_object", retain_python_object, METH_VARARGS, nullptr},
    {"release_python_object", release_python_object, METH_VARARGS, nullptr}, {"release_handle", release_handle, METH_VARARGS, nullptr}, {"run_demo", run_demo, METH_VARARGS, nullptr}, {nullptr,nullptr,0,nullptr}};
static struct PyModuleDef module = {PyModuleDef_HEAD_INIT, "_rexxpython_poc", nullptr, -1, methods};
PyMODINIT_FUNC PyInit__rexxpython_poc(void) { return PyModule_Create(&module); }
