#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <rexx.h>
#include <cstring>
#include <string>

static PyObject *receiver = nullptr;
static std::string method_name;

static size_t REXXENTRY py_callback(CONSTANT_STRING, size_t argc,
                                    PCONSTRXSTRING argv, CONSTANT_STRING,
                                    PRXSTRING result)
{
    PyGILState_STATE gil = PyGILState_Ensure();
    std::string msg;
    if (argc > 0 && argv[0].strptr != nullptr)
        msg.assign(argv[0].strptr, argv[0].strlength);

    PyObject *ret = nullptr;
    if (receiver != nullptr)
        ret = PyObject_CallMethod(receiver, method_name.c_str(), "s#",
                                  msg.data(), (Py_ssize_t)msg.size());

    std::string answer = "PYTHON_CALLBACK_ERROR";
    if (ret != nullptr) {
        PyObject *s = PyObject_Str(ret);
        if (s != nullptr) {
            const char *utf8 = PyUnicode_AsUTF8(s);
            if (utf8 != nullptr) answer = utf8;
            Py_DECREF(s);
        }
        Py_DECREF(ret);
    } else {
        PyErr_Print();
    }

    if (result->strptr != nullptr) {
        size_t n = answer.size();
        if (n > 255) n = 255;  // POC deliberately keeps callback returns tiny.
        memcpy(result->strptr, answer.data(), n);
        result->strlength = n;
    }
    PyGILState_Release(gil);
    return 0;
}

static PyObject *run_demo(PyObject *, PyObject *args)
{
    PyObject *obj;
    const char *method;
    const char *demo;
    const char *macro;
    if (!PyArg_ParseTuple(args, "Osss", &obj, &method, &demo, &macro)) return nullptr;

    Py_XINCREF(obj);
    Py_XDECREF(receiver);
    receiver = obj;
    method_name = method;

    RexxReturnCode frc = RexxRegisterFunctionExe("PYCALLBACK", (REXXPFN)py_callback);
    if (frc != RXFUNC_OK && frc != RXFUNC_DEFINED)
        return PyErr_Format(PyExc_RuntimeError, "RexxRegisterFunctionExe rc=%zu", (size_t)frc);

    RexxReturnCode mrc = RexxAddMacro("PYALARM", macro, RXMACRO_SEARCH_BEFORE);
    if (mrc != 0) {
        RexxDeregisterFunction("PYCALLBACK");
        return PyErr_Format(PyExc_RuntimeError, "RexxAddMacro rc=%zu", (size_t)mrc);
    }

    unsigned short pos = 0;
    RexxReturnCode qrc = RexxQueryMacro("PYALARM", &pos);
    if (qrc != 0) {
        RexxDropMacro("PYALARM");
        RexxDeregisterFunction("PYCALLBACK");
        return PyErr_Format(PyExc_RuntimeError, "RexxQueryMacro rc=%zu", (size_t)qrc);
    }

    short rc = 0;
    RXSTRING result;
    char result_buffer[256] = {0};
    result.strptr = result_buffer;
    result.strlength = sizeof(result_buffer);
    int api_rc = RexxStart(0, nullptr, demo, nullptr, "SYSTEM", RXCOMMAND,
                           nullptr, &rc, &result);

    RexxDropMacro("PYALARM");
    RexxDeregisterFunction("PYCALLBACK");

    if (api_rc != 0)
        return PyErr_Format(PyExc_RuntimeError, "RexxStart api_rc=%d rexx_rc=%d", api_rc, (int)rc);

    return Py_BuildValue("{s:i,s:i,s:i,s:s#}",
                         "api_rc", api_rc,
                         "rexx_rc", (int)rc,
                         "macro_position", (int)pos,
                         "result", result.strptr, (Py_ssize_t)result.strlength);
}

static PyMethodDef methods[] = {
    {"run_demo", run_demo, METH_VARARGS, "Run the minimal ooRexx/Macrospace/Python callback demo."},
    {nullptr, nullptr, 0, nullptr}
};
static struct PyModuleDef module = {PyModuleDef_HEAD_INIT, "_rexxpython_poc", nullptr, -1, methods};
PyMODINIT_FUNC PyInit__rexxpython_poc(void) { return PyModule_Create(&module); }
