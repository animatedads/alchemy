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

static PyObject *receiver = nullptr;
static std::map<uint64_t, PyObject *> py_objects;
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
            PyObject *ret = PyObject_CallMethod(obj, mn.c_str(), nullptr);
            if (ret != nullptr) { PyObject *st=PyObject_Str(ret); if(st){ const char *u=PyUnicode_AsUTF8(st); if(u) answer=u; Py_DECREF(st);} Py_DECREF(ret); }
            else PyErr_Print();
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
    uint64_t ph; {
        std::lock_guard<std::mutex> lock(py_object_mutex); ph=next_py_handle++; Py_INCREF(obj); py_objects[ph]=obj;
        if(case_map != Py_None) {
            PyObject *key, *value; Py_ssize_t pos=0;
            while(PyDict_Next(case_map,&pos,&key,&value)) {
                if(!PyUnicode_Check(key) || !PyUnicode_Check(value)) {
                    Py_DECREF(obj); py_objects.erase(ph);
                    return PyErr_Format(PyExc_TypeError,"method casing keys and values must be strings");
                }
                const char *k=PyUnicode_AsUTF8(key), *v=PyUnicode_AsUTF8(value);
                if(k==nullptr || v==nullptr) { Py_DECREF(obj); py_objects.erase(ph); return nullptr; }
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

static PyObject *release_python_object(PyObject *, PyObject *args)
{
    unsigned long long h; if(!PyArg_ParseTuple(args,"K",&h)) return nullptr;
    std::lock_guard<std::mutex> lock(py_object_mutex); auto i=py_objects.find(h); if(i!=py_objects.end()){Py_DECREF(i->second);py_objects.erase(i);} py_method_cases.erase(h); Py_RETURN_NONE;
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
 {"create_animal", create_animal, METH_VARARGS, nullptr}, {"create_object_collection", create_object_collection, METH_VARARGS, nullptr}, {"wrap_python_object", wrap_python_object, METH_VARARGS, nullptr}, {"create_collection", create_collection, METH_VARARGS, nullptr},
 {"send0", send0, METH_VARARGS, nullptr}, {"send1_handle", send1_handle, METH_VARARGS, nullptr}, {"send1_index_handle", send1_index_handle, METH_VARARGS, nullptr},
 {"send2_index_string", send2_index_string, METH_VARARGS, nullptr}, {"release_python_object", release_python_object, METH_VARARGS, nullptr}, {"release_handle", release_handle, METH_VARARGS, nullptr}, {"run_demo", run_demo, METH_VARARGS, nullptr}, {nullptr,nullptr,0,nullptr}};
static struct PyModuleDef module = {PyModuleDef_HEAD_INIT, "_rexxpython_poc", nullptr, -1, methods};
PyMODINIT_FUNC PyInit__rexxpython_poc(void) { return PyModule_Create(&module); }
