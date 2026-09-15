#include <oorexxapi.h>
#include <Python.h>
#include <mutex>
#include <map>
#include <string>
#include <stdexcept>
#include <sstream>
#include <vector>
#include <cctype>
#ifndef _WIN32
#include <dlfcn.h>
#endif

namespace {
std::mutex regMu;
std::map<uint64_t, PyObject*> reg;
uint64_t nextId=1;
std::once_flag initOnce;
struct BufferExportV1 { void *data; size_t size; int readonly; void *token; };
using BufferAcquireV1=int(*)(uint64_t,BufferExportV1*);
using BufferReleaseV1=void(*)(void*);
using BufferImportReleaseV1=void(*)(void*);
using BufferImportV1=uint64_t(*)(void*,size_t,int,void*,BufferImportReleaseV1);
BufferAcquireV1 bufferAcquire=nullptr; BufferReleaseV1 bufferRelease=nullptr; BufferImportV1 bufferImport=nullptr;
struct TensorImportV1 { void*data; size_t byte_size; int readonly; int device_type; int device_id; int dtype_code; int dtype_bits; int dtype_lanes; size_t ndim; const int64_t*shape; const int64_t*strides_bytes; void*token; BufferImportReleaseV1 release; };
using TensorImportFnV1=uint64_t(*)(const TensorImportV1*);
using TensorCloseFnV1=int(*)(uint64_t);
TensorImportFnV1 tensorImport=nullptr; TensorCloseFnV1 tensorClose=nullptr;
void* bufferApiHandle=nullptr;
void ensureBufferApi(){
#ifndef _WIN32
  if(!bufferApiHandle) bufferApiHandle=dlopen("libforeign_runtime.so",RTLD_NOW|RTLD_GLOBAL);
  if(!bufferAcquire) bufferAcquire=(BufferAcquireV1)dlsym(RTLD_DEFAULT,"rexx_foreign_buffer_export_acquire_v1");
  if(!bufferRelease) bufferRelease=(BufferReleaseV1)dlsym(RTLD_DEFAULT,"rexx_foreign_buffer_export_release_v1");
  if(!bufferImport) bufferImport=(BufferImportV1)dlsym(RTLD_DEFAULT,"rexx_foreign_buffer_import_v1");
  if(!tensorImport) tensorImport=(TensorImportFnV1)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_import_v1");
  if(!tensorClose) tensorClose=(TensorCloseFnV1)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_close_v1");
#endif
  if(!bufferAcquire||!bufferRelease||!bufferImport||!tensorImport||!tensorClose) throw std::runtime_error("Foreign Runtime buffer/tensor sharing API v1 unavailable");
}
typedef struct { PyObject_HEAD void* data; Py_ssize_t size; int readonly; void* token; } ForeignBufferExporter;
PyTypeObject* bufferExporterType=nullptr;
int exporterGetBuffer(PyObject*self,Py_buffer*view,int flags){
  auto*e=(ForeignBufferExporter*)self;
  return PyBuffer_FillInfo(view,self,e->data,e->size,e->readonly,flags);
}
void exporterReleaseBuffer(PyObject*,Py_buffer*){}
void exporterDealloc(PyObject*self){
  auto*e=(ForeignBufferExporter*)self;
  if(e->token && bufferRelease) bufferRelease(e->token);
  e->token=nullptr;
  Py_TYPE(self)->tp_free(self);
}
PyTypeObject* ensureBufferExporterType(){
  if(bufferExporterType) return bufferExporterType;
  static PyType_Slot slots[]={
    {Py_tp_dealloc,(void*)exporterDealloc},
    {Py_bf_getbuffer,(void*)exporterGetBuffer},
    {Py_bf_releasebuffer,(void*)exporterReleaseBuffer},
    {0,nullptr}
  };
  static PyType_Spec spec={"oorexx_foreign._BufferExport",sizeof(ForeignBufferExporter),0,Py_TPFLAGS_DEFAULT,slots};
  PyObject*t=PyType_FromSpec(&spec); if(!t)return nullptr;
  bufferExporterType=(PyTypeObject*)t; return bufferExporterType;
}
PyObject* foreignBufferMemoryView(uint64_t id){
  ensureBufferApi(); BufferExportV1 ex{};
  if(bufferAcquire(id,&ex)!=0) { PyErr_SetString(PyExc_BufferError,"ForeignBuffer is closed or unavailable"); return nullptr; }
  PyTypeObject*t=ensureBufferExporterType();
  if(!t){bufferRelease(ex.token);return nullptr;}
  auto*e=(ForeignBufferExporter*)t->tp_alloc(t,0);
  if(!e){bufferRelease(ex.token);return nullptr;}
  e->data=ex.data; e->size=(Py_ssize_t)ex.size; e->readonly=ex.readonly; e->token=ex.token;
  PyObject*mv=PyMemoryView_FromObject((PyObject*)e);
  Py_DECREF((PyObject*)e);
  return mv;
}

struct PythonBufferImportPin { Py_buffer view{}; };
void releasePythonBufferImport(void* token){
  auto*pin=static_cast<PythonBufferImportPin*>(token); if(!pin)return;
  PyGILState_STATE gs=PyGILState_Ensure(); PyBuffer_Release(&pin->view); PyGILState_Release(gs); delete pin;
}
uint64_t importPythonBuffer(PyObject*o,size_t*sizeOut,int*readonlyOut){
  ensureBufferApi(); auto*pin=new PythonBufferImportPin();
  if(PyObject_GetBuffer(o,&pin->view,PyBUF_CONTIG_RO)!=0){delete pin;PyErr_Clear();throw std::runtime_error("Python object does not expose a contiguous buffer");}
  uint64_t id=bufferImport(pin->view.buf,(size_t)pin->view.len,pin->view.readonly,pin,releasePythonBufferImport);
  if(!id){PyBuffer_Release(&pin->view);delete pin;throw std::runtime_error("Foreign Runtime rejected Python buffer import");}
  if(sizeOut) *sizeOut=(size_t)pin->view.len;
  if(readonlyOut) *readonlyOut=pin->view.readonly?1:0;
  return id;
}

struct PythonTensorPin { PyObject* owner=nullptr; };
void releasePythonTensorImport(void* token){
  auto*pin=static_cast<PythonTensorPin*>(token); if(!pin)return;
  PyGILState_STATE gs=PyGILState_Ensure(); Py_XDECREF(pin->owner); PyGILState_Release(gs); delete pin;
}
static int dtypeDescriptor(const std::string&d,int&code,int&bits,int&lanes){
  code=0;bits=0;lanes=1;std::string x=d;for(char&c:x)c=(char)tolower((unsigned char)c);
  if(x.find("bool")!=std::string::npos){code=6;bits=8;return 0;}
  if(x.find("uint8")!=std::string::npos){code=1;bits=8;return 0;} if(x.find("uint16")!=std::string::npos){code=1;bits=16;return 0;} if(x.find("uint32")!=std::string::npos){code=1;bits=32;return 0;} if(x.find("uint64")!=std::string::npos){code=1;bits=64;return 0;}
  if(x.find("int8")!=std::string::npos){code=0;bits=8;return 0;} if(x.find("int16")!=std::string::npos){code=0;bits=16;return 0;} if(x.find("int32")!=std::string::npos){code=0;bits=32;return 0;} if(x.find("int64")!=std::string::npos){code=0;bits=64;return 0;}
  if(x.find("bfloat16")!=std::string::npos){code=4;bits=16;return 0;} if(x.find("float16")!=std::string::npos){code=2;bits=16;return 0;} if(x.find("float32")!=std::string::npos){code=2;bits=32;return 0;} if(x.find("float64")!=std::string::npos||x=="double"){code=2;bits=64;return 0;}
  if(x.find("complex64")!=std::string::npos){code=5;bits=64;return 0;} if(x.find("complex128")!=std::string::npos){code=5;bits=128;return 0;}
  return -1;
}
static long long callLongNoArgs(PyObject*o,const char*name,long long def=0){PyObject*f=PyObject_GetAttrString(o,name);if(!f){PyErr_Clear();return def;}PyObject*v=PyCallable_Check(f)?PyObject_CallNoArgs(f):f;if(PyCallable_Check(f))Py_DECREF(f);if(!v){PyErr_Clear();return def;}long long n=PyLong_AsLongLong(v);Py_DECREF(v);if(PyErr_Occurred()){PyErr_Clear();return def;}return n;}
uint64_t importPythonTensor(PyObject*o){
  ensureBufferApi();
  std::string dtypeText;PyObject*dtype=PyObject_GetAttrString(o,"dtype");if(dtype){PyObject*ds=PyObject_Str(dtype);if(ds){const char*q=PyUnicode_AsUTF8(ds);if(q)dtypeText=q;Py_DECREF(ds);}Py_DECREF(dtype);}else PyErr_Clear();
  int dc=0,db=0,dl=1;if(dtypeDescriptor(dtypeText,dc,db,dl)!=0)throw std::runtime_error("unsupported tensor dtype for native descriptor: "+dtypeText);
  std::vector<int64_t> shape,strides;void*data=nullptr;size_t bytes=0;int ro=0;int devType=0,devId=0;
  PyObject*devfn=PyObject_GetAttrString(o,"__dlpack_device__");if(devfn){PyObject*dev=PyObject_CallNoArgs(devfn);Py_DECREF(devfn);if(dev&&PyTuple_Check(dev)&&PyTuple_Size(dev)>=2){PyObject*a=PyNumber_Long(PyTuple_GetItem(dev,0));PyObject*b=PyNumber_Long(PyTuple_GetItem(dev,1));if(a){devType=(int)PyLong_AsLong(a);Py_DECREF(a);}if(b){devId=(int)PyLong_AsLong(b);Py_DECREF(b);}Py_XDECREF(dev);}else{Py_XDECREF(dev);PyErr_Clear();}}else PyErr_Clear();
  Py_buffer view{}; bool haveView=(PyObject_GetBuffer(o,&view,PyBUF_STRIDES|PyBUF_FORMAT)==0);
  if(haveView){data=view.buf;bytes=(size_t)view.len;ro=view.readonly?1:0;shape.resize((size_t)view.ndim);strides.resize((size_t)view.ndim);for(int i=0;i<view.ndim;++i){shape[(size_t)i]=view.shape?view.shape[i]:0;strides[(size_t)i]=view.strides?view.strides[i]:(int64_t)view.itemsize;}PyBuffer_Release(&view);}
  else {
    PyErr_Clear(); long long ptr=callLongNoArgs(o,"data_ptr",0); long long es=callLongNoArgs(o,"element_size",db/8); long long ne=callLongNoArgs(o,"numel",0); if(!ptr)throw std::runtime_error("tensor has no host/native data pointer");data=(void*)(uintptr_t)ptr;bytes=(size_t)(ne*es);
    PyObject*sh=PyObject_GetAttrString(o,"shape");if(sh){PyObject*seq=PySequence_Fast(sh,"shape sequence");Py_DECREF(sh);if(seq){Py_ssize_t n=PySequence_Fast_GET_SIZE(seq);shape.resize((size_t)n);for(Py_ssize_t i=0;i<n;++i)shape[(size_t)i]=PyLong_AsLongLong(PySequence_Fast_GET_ITEM(seq,i));Py_DECREF(seq);}else PyErr_Clear();}
    PyObject*sf=PyObject_GetAttrString(o,"stride");if(sf&&PyCallable_Check(sf)){PyObject*sv=PyObject_CallNoArgs(sf);if(sv){PyObject*seq=PySequence_Fast(sv,"stride sequence");Py_DECREF(sv);if(seq){Py_ssize_t n=PySequence_Fast_GET_SIZE(seq);strides.resize((size_t)n);for(Py_ssize_t i=0;i<n;++i)strides[(size_t)i]=PyLong_AsLongLong(PySequence_Fast_GET_ITEM(seq,i))*es;Py_DECREF(seq);}else PyErr_Clear();}else PyErr_Clear();}Py_XDECREF(sf);
  }
  if(strides.size()!=shape.size())throw std::runtime_error("tensor shape/stride rank mismatch");
  /* v1 native tensor descriptors are host/CPU only.  A non-CPU tensor needs v2 execution-context metadata before it may be published to native consumers. */
  if(devType!=1) return 0;
  auto*pin=new PythonTensorPin();Py_INCREF(o);pin->owner=o;
  TensorImportV1 in{data,bytes,ro,devType,devId,dc,db,dl,shape.size(),shape.data(),strides.data(),pin,releasePythonTensorImport};
  uint64_t id=tensorImport(&in);if(!id){Py_DECREF(o);delete pin;throw std::runtime_error("Foreign Runtime rejected tensor descriptor import");}return id;
}


void ensurePython(){
  std::call_once(initOnce, [](){
#ifndef _WIN32
    Dl_info di{};
    if(dladdr((void*)Py_Initialize,&di) && di.dli_fname) dlopen(di.dli_fname,RTLD_NOW|RTLD_GLOBAL);
#endif
    Py_Initialize();
    PyEval_SaveThread();
  });
  if(!Py_IsInitialized()) throw std::runtime_error("Python interpreter is not initialized");
}
struct GIL { PyGILState_STATE s; GIL(){ensurePython();s=PyGILState_Ensure();} ~GIL(){PyGILState_Release(s);} };

RexxObjectPtr fail(RexxCallContext*c,const std::string&s){
  c->RaiseException1(Rexx_Error_Incorrect_call_user_defined,c->String(s.c_str()));
  return c->Nil();
}
std::string pyError(){
  if(!PyErr_Occurred()) return "Python operation failed";
  PyObject *t=nullptr,*v=nullptr,*tb=nullptr; PyErr_Fetch(&t,&v,&tb); PyErr_NormalizeException(&t,&v,&tb);
  std::string out="Python exception";
  if(t){PyObject*n=PyObject_GetAttrString(t,"__name__");if(n){const char*s=PyUnicode_AsUTF8(n);if(s)out=s;Py_DECREF(n);}}
  if(v){PyObject*s=PyObject_Str(v);if(s){const char*q=PyUnicode_AsUTF8(s);if(q){out += ": "; out += q;}Py_DECREF(s);}}
  Py_XDECREF(t);Py_XDECREF(v);Py_XDECREF(tb);PyErr_Clear();return out;
}
uint64_t store(PyObject*o){ if(!o)throw std::runtime_error(pyError()); std::lock_guard<std::mutex>g(regMu); uint64_t id=nextId++; reg[id]=o; return id; }
PyObject* acquire(uint64_t id){ std::lock_guard<std::mutex>g(regMu); auto it=reg.find(id); if(it==reg.end())throw std::runtime_error("Python foreign object is closed or unknown"); Py_INCREF(it->second); return it->second; }
void releaseId(uint64_t id){ PyObject*o=nullptr; {std::lock_guard<std::mutex>g(regMu);auto it=reg.find(id);if(it==reg.end())return;o=it->second;reg.erase(it);} Py_DECREF(o); }

bool annotationIs(PyObject*ann,const char*name){
  if(!ann || ann==Py_None) return false;
  if(ann==(PyObject*)&PyUnicode_Type && std::string(name)=="str") return true;
  if(ann==(PyObject*)&PyLong_Type && std::string(name)=="int") return true;
  if(ann==(PyObject*)&PyFloat_Type && std::string(name)=="float") return true;
  if(ann==(PyObject*)&PyBytes_Type && std::string(name)=="bytes") return true;
  if(ann==(PyObject*)&PyBool_Type && std::string(name)=="bool") return true;
  if(ann==(PyObject*)&PyList_Type && std::string(name)=="list") return true;
  if(ann==(PyObject*)&PyDict_Type && std::string(name)=="dict") return true;
  const char*n=PyUnicode_Check(ann)?PyUnicode_AsUTF8(ann):nullptr;
  return n && std::string(n)==name;
}

PyObject* rexxToPy(RexxCallContext*c,RexxObjectPtr o,PyObject*annotation=nullptr);

PyObject* pairsToDict(RexxCallContext*c,RexxArrayObject pairs){
  PyObject*d=PyDict_New(); if(!d)return nullptr;
  size_t n=c->ArraySize(pairs);
  for(size_t i=1;i<=n;++i){
    RexxObjectPtr po=c->ArrayAt(pairs,i); if(!c->IsArray(po)){Py_DECREF(d);PyErr_SetString(PyExc_TypeError,"Python dict pair must be an Array");return nullptr;}
    RexxArrayObject p=(RexxArrayObject)po; if(c->ArraySize(p)!=2){Py_DECREF(d);PyErr_SetString(PyExc_TypeError,"Python dict pair must have key and value");return nullptr;}
    PyObject*k=rexxToPy(c,c->ArrayAt(p,1),nullptr); if(!k){Py_DECREF(d);return nullptr;}
    PyObject*v=rexxToPy(c,c->ArrayAt(p,2),nullptr); if(!v){Py_DECREF(k);Py_DECREF(d);return nullptr;}
    if(PyDict_SetItem(d,k,v)<0){Py_DECREF(k);Py_DECREF(v);Py_DECREF(d);return nullptr;}
    Py_DECREF(k);Py_DECREF(v);
  }
  return d;
}

PyObject* rexxToPy(RexxCallContext*c,RexxObjectPtr o,PyObject*annotation){
  if(o==c->Nil()){Py_INCREF(Py_None);return Py_None;}
  if(c->IsArray(o)){
    RexxArrayObject a=(RexxArrayObject)o; size_t n=c->ArraySize(a);
    if(n==2){const char*m=c->ObjectToStringValue(c->ArrayAt(a,1));if(m){std::string mark=m;RexxObjectPtr value=c->ArrayAt(a,2);
      if(mark=="__python_bytes__"){RexxStringObject rs=c->ObjectToString(value);return PyBytes_FromStringAndSize(c->StringData(rs),(Py_ssize_t)c->StringLength(rs));}
      if(mark=="__python_text__"){RexxStringObject rs=c->ObjectToString(value);return PyUnicode_FromStringAndSize(c->StringData(rs),(Py_ssize_t)c->StringLength(rs));}
      if(mark=="__python_int__"){int64_t v;if(!c->ObjectToInt64(value,&v))return nullptr;return PyLong_FromLongLong(v);}
      if(mark=="__python_float__"){double v;if(!c->ObjectToDouble(value,&v))return nullptr;return PyFloat_FromDouble(v);}
      if(mark=="__foreign_buffer__"){uint64_t id=0;if(!c->ObjectToUnsignedInt64(value,&id)){PyErr_SetString(PyExc_TypeError,"ForeignBuffer handle must be an unsigned integer");return nullptr;}return foreignBufferMemoryView(id);}
      if(mark=="__foreign_python_ref__"){uint64_t id=0;if(!c->ObjectToUnsignedInt64(value,&id)){PyErr_SetString(PyExc_TypeError,"ForeignPythonObject handle must be an unsigned integer");return nullptr;}try{return acquire(id);}catch(const std::exception&e){PyErr_SetString(PyExc_RuntimeError,e.what());return nullptr;}}
      if(mark=="__python_dict__" && c->IsArray(value)) return pairsToDict(c,(RexxArrayObject)value);
    }}
    PyObject*l=PyList_New((Py_ssize_t)n); if(!l)return nullptr;
    for(size_t i=0;i<n;++i){PyObject*x=rexxToPy(c,c->ArrayAt(a,i+1),nullptr);if(!x){Py_DECREF(l);return nullptr;}PyList_SET_ITEM(l,(Py_ssize_t)i,x);}return l;
  }
  RexxStringObject rs=c->ObjectToString(o); const char*sp=c->StringData(rs); size_t sn=c->StringLength(rs);
  if(annotationIs(annotation,"str")) return PyUnicode_FromStringAndSize(sp,(Py_ssize_t)sn);
  if(annotationIs(annotation,"bytes")) return PyBytes_FromStringAndSize(sp,(Py_ssize_t)sn);
  if(annotationIs(annotation,"int")){int64_t v;if(!c->ObjectToInt64(o,&v)){PyErr_SetString(PyExc_TypeError,"value cannot be converted to annotated int");return nullptr;}return PyLong_FromLongLong(v);}
  if(annotationIs(annotation,"float")){double v;if(!c->ObjectToDouble(o,&v)){PyErr_SetString(PyExc_TypeError,"value cannot be converted to annotated float");return nullptr;}return PyFloat_FromDouble(v);}
  if(annotationIs(annotation,"bool")){logical_t v;if(!c->ObjectToLogical(o,&v)){PyErr_SetString(PyExc_TypeError,"value cannot be converted to annotated bool");return nullptr;}return PyBool_FromLong(v?1:0);}
  std::string text(sp,sn);
  if(!text.empty()){char*end=nullptr;errno=0;long long iv=strtoll(text.c_str(),&end,10);if(errno==0&&end==text.c_str()+text.size())return PyLong_FromLongLong(iv);
    end=nullptr;errno=0;double dv=strtod(text.c_str(),&end);if(errno==0&&end==text.c_str()+text.size())return PyFloat_FromDouble(dv);}
  return PyUnicode_FromStringAndSize(sp,(Py_ssize_t)sn);
}

RexxObjectPtr pyToRexx(RexxCallContext*c,PyObject*o){
  if(o==Py_None)return c->Nil();
  if(PyBool_Check(o))return c->Logical(o==Py_True);
  if(PyLong_Check(o)){long long v=PyLong_AsLongLong(o);if(!PyErr_Occurred())return c->Int64ToObject(v);PyErr_Clear();}
  if(PyFloat_Check(o))return c->DoubleToObject(PyFloat_AsDouble(o));
  if(PyUnicode_Check(o)){Py_ssize_t n=0;const char*s=PyUnicode_AsUTF8AndSize(o,&n);if(!s)throw std::runtime_error(pyError());return c->String(s,(size_t)n);}
  if(PyBytes_Check(o)){char*s=nullptr;Py_ssize_t n=0;if(PyBytes_AsStringAndSize(o,&s,&n))throw std::runtime_error(pyError());return c->String(s,(size_t)n);}
  if(PyList_Check(o)||PyTuple_Check(o)){
    Py_ssize_t n=PySequence_Size(o);RexxArrayObject a=c->NewArray((size_t)n);
    for(Py_ssize_t i=0;i<n;++i){PyObject*x=PySequence_GetItem(o,i);if(!x)throw std::runtime_error(pyError());RexxObjectPtr r=pyToRexx(c,x);Py_DECREF(x);c->ArrayPut(a,r,(size_t)i+1);}return a;
  }
  if(PyDict_Check(o)){
    RexxDirectoryObject d=c->NewDirectory(); PyObject*k=nullptr,*v=nullptr; Py_ssize_t pos=0; bool ok=true;
    while(PyDict_Next(o,&pos,&k,&v)){
      if(!PyUnicode_Check(k)){ok=false;break;} const char*ks=PyUnicode_AsUTF8(k); if(!ks){ok=false;break;}
      RexxObjectPtr rv=pyToRexx(c,v); c->DirectoryPut(d,rv,ks);
    }
    if(ok)return d;
  }
  const char*tn=Py_TYPE(o)->tp_name; Py_INCREF(o); uint64_t id=store(o);
  RexxArrayObject a=c->NewArray(3);c->ArrayPut(a,c->String("__foreign_python_object__"),1);c->ArrayPut(a,c->UnsignedInt64ToObject(id),2);c->ArrayPut(a,c->String(tn?tn:"object"),3);return a;
}

PyObject* getAttrCaseless(PyObject*base,const char*name,std::string*actual=nullptr){
  PyObject*a=PyObject_GetAttrString(base,name);
  if(a){if(actual)*actual=name?name:"";return a;}
  PyErr_Clear();
  std::string want=name?name:""; for(char&ch:want)ch=(char)tolower((unsigned char)ch);
  PyObject*d=PyObject_Dir(base); if(!d)return nullptr;
  Py_ssize_t n=PyList_Size(d);
  for(Py_ssize_t i=0;i<n;++i){PyObject*k=PyList_GetItem(d,i);if(!PyUnicode_Check(k))continue;const char*s=PyUnicode_AsUTF8(k);if(!s)continue;std::string q=s;for(char&ch:q)ch=(char)tolower((unsigned char)ch);if(q==want){a=PyObject_GetAttrString(base,s);if(actual)*actual=s;break;}}
  Py_DECREF(d);return a;
}

PyObject* getSignature(PyObject*callable){
  PyObject*inspect=PyImport_ImportModule("inspect"); if(!inspect)return nullptr;
  PyObject*sigf=PyObject_GetAttrString(inspect,"signature"); Py_DECREF(inspect); if(!sigf)return nullptr;
  PyObject*sig=PyObject_CallFunctionObjArgs(sigf,callable,NULL); Py_DECREF(sigf); return sig;
}

std::vector<PyObject*> positionalAnnotations(PyObject*callable,size_t count){
  std::vector<PyObject*> out(count,nullptr); PyObject*sig=getSignature(callable); if(!sig){PyErr_Clear();return out;}
  PyObject*params=PyObject_GetAttrString(sig,"parameters"); Py_DECREF(sig); if(!params){PyErr_Clear();return out;}
  PyObject*vals=PyMapping_Values(params); Py_DECREF(params); if(!vals){PyErr_Clear();return out;}
  Py_ssize_t n=PyList_Size(vals); size_t oi=0;
  for(Py_ssize_t i=0;i<n && oi<count;++i){
    PyObject*p=PyList_GetItem(vals,i); PyObject*kind=PyObject_GetAttrString(p,"kind"); if(!kind){PyErr_Clear();continue;}
    long kv=PyLong_AsLong(kind); Py_DECREF(kind); if(PyErr_Occurred()){PyErr_Clear();continue;}
    /* inspect.Parameter.POSITIONAL_ONLY=0, POSITIONAL_OR_KEYWORD=1, VAR_POSITIONAL=2 */
    if(kv<=2){PyObject*ann=PyObject_GetAttrString(p,"annotation"); if(ann){out[oi++]=ann;}else{PyErr_Clear();oi++;}}
  }
  Py_DECREF(vals); return out;
}
void releaseAnnotations(std::vector<PyObject*>&a){for(PyObject*x:a)Py_XDECREF(x);}

PyObject* kwargsFromPairs(RexxCallContext*c,RexxArrayObject pairs){
  PyObject*d=PyDict_New(); if(!d)return nullptr; size_t n=c->ArraySize(pairs);
  for(size_t i=1;i<=n;++i){RexxObjectPtr po=c->ArrayAt(pairs,i);if(!c->IsArray(po)){Py_DECREF(d);PyErr_SetString(PyExc_TypeError,"keyword pair must be Array");return nullptr;}RexxArrayObject p=(RexxArrayObject)po;if(c->ArraySize(p)!=2){Py_DECREF(d);PyErr_SetString(PyExc_TypeError,"keyword pair must contain name and value");return nullptr;}
    const char*name=c->ObjectToStringValue(c->ArrayAt(p,1));PyObject*v=rexxToPy(c,c->ArrayAt(p,2),nullptr);if(!v){Py_DECREF(d);return nullptr;}if(PyDict_SetItemString(d,name,v)<0){Py_DECREF(v);Py_DECREF(d);return nullptr;}Py_DECREF(v);}
  return d;
}

RexxObjectPtr invokeObject(RexxCallContext*c,PyObject*base,const char*name,RexxArrayObject args,RexxArrayObject kwpairs=nullptr){
  PyObject*callable=name?getAttrCaseless(base,name):base;if(!callable)throw std::runtime_error(pyError());if(!name)Py_INCREF(callable);
  if(!PyCallable_Check(callable)){Py_DECREF(callable);throw std::runtime_error(std::string("Python attribute is not callable: ")+(name?name:"<object>"));}
  size_t n=c->ArraySize(args);auto anns=positionalAnnotations(callable,n);PyObject*t=PyTuple_New((Py_ssize_t)n);if(!t){releaseAnnotations(anns);Py_DECREF(callable);throw std::runtime_error(pyError());}
  for(size_t i=0;i<n;++i){PyObject*x=rexxToPy(c,c->ArrayAt(args,i+1),anns[i]);if(!x){releaseAnnotations(anns);Py_DECREF(t);Py_DECREF(callable);throw std::runtime_error(pyError());}PyTuple_SET_ITEM(t,(Py_ssize_t)i,x);}releaseAnnotations(anns);
  PyObject*kw=kwpairs?kwargsFromPairs(c,kwpairs):nullptr;if(kwpairs&&!kw){Py_DECREF(t);Py_DECREF(callable);throw std::runtime_error(pyError());}
  PyObject*r=PyObject_Call(callable,t,kw);Py_XDECREF(kw);Py_DECREF(t);Py_DECREF(callable);if(!r)throw std::runtime_error(pyError());RexxObjectPtr out=pyToRexx(c,r);Py_DECREF(r);return out;
}

std::string annotationText(PyObject*ann){
  if(!ann) return "";
  PyObject*s=PyObject_Str(ann);
  if(!s){PyErr_Clear();return "";}
  const char*q=PyUnicode_AsUTF8(s);
  std::string out=q?q:"";
  Py_DECREF(s);
  if(out.rfind("<class '",0)==0 && out.size()>10 && out.substr(out.size()-2)=="'>") out=out.substr(8,out.size()-10);
  return out;
}
RexxObjectPtr methodInfo(RexxCallContext*c,PyObject*base,const char*name){
  std::string actual; PyObject*fn=getAttrCaseless(base,name,&actual);if(!fn)throw std::runtime_error(pyError());if(!PyCallable_Check(fn)){Py_DECREF(fn);throw std::runtime_error("Python attribute is not callable");}
  PyObject*sig=getSignature(fn);Py_DECREF(fn);if(!sig)throw std::runtime_error(pyError());
  PyObject*sigstr=PyObject_Str(sig);const char*ss=sigstr?PyUnicode_AsUTF8(sigstr):"";
  PyObject*ret=PyObject_GetAttrString(sig,"return_annotation");std::string retText=annotationText(ret);Py_XDECREF(ret);
  PyObject*params=PyObject_GetAttrString(sig,"parameters");Py_DECREF(sig);if(!params){Py_XDECREF(sigstr);throw std::runtime_error(pyError());}
  PyObject*vals=PyMapping_Values(params);Py_DECREF(params);if(!vals){Py_XDECREF(sigstr);throw std::runtime_error(pyError());}
  RexxArrayObject pars=c->NewArray((size_t)PyList_Size(vals));
  for(Py_ssize_t i=0;i<PyList_Size(vals);++i){PyObject*p=PyList_GetItem(vals,i);PyObject*pn=PyObject_GetAttrString(p,"name");PyObject*ann=PyObject_GetAttrString(p,"annotation");PyObject*kind=PyObject_GetAttrString(p,"kind");PyObject*def=PyObject_GetAttrString(p,"default");
    std::string an=annotationText(ann);std::string kn=annotationText(kind);std::string dv;bool required=true;
    if(def){PyObject*empty=PyObject_GetAttrString((PyObject*)Py_TYPE(p),"empty");if(empty){required=(def==empty);Py_DECREF(empty);}if(!required){PyObject*ds=PyObject_Repr(def);if(ds){const char*q=PyUnicode_AsUTF8(ds);if(q)dv=q;Py_DECREF(ds);}}}
    RexxArrayObject pi=c->NewArray(5);c->ArrayPut(pi,c->String(pn?PyUnicode_AsUTF8(pn):""),1);c->ArrayPut(pi,c->String(an.c_str()),2);c->ArrayPut(pi,c->String(kn.c_str()),3);c->ArrayPut(pi,c->Logical(required),4);c->ArrayPut(pi,c->String(dv.c_str()),5);c->ArrayPut(pars,pi,(size_t)i+1);
    Py_XDECREF(pn);Py_XDECREF(ann);Py_XDECREF(kind);Py_XDECREF(def);
  }
  Py_DECREF(vals);
  RexxArrayObject info=c->NewArray(4);c->ArrayPut(info,c->String(actual.c_str()),1);c->ArrayPut(info,c->String(retText.c_str()),2);c->ArrayPut(info,c->String(ss?ss:""),3);c->ArrayPut(info,pars,4);Py_XDECREF(sigstr);return info;
}
}


RexxObjectPtr tensorInfo(RexxCallContext*c,PyObject*o){
  if(!PyObject_HasAttrString(o,"__dlpack__")) throw std::runtime_error("Python object does not expose __dlpack__");
  std::string dtypeText;
  PyObject*dtype=PyObject_GetAttrString(o,"dtype");
  if(dtype){PyObject*ds=PyObject_Str(dtype);if(ds){const char*q=PyUnicode_AsUTF8(ds);if(q)dtypeText=q;Py_DECREF(ds);}Py_DECREF(dtype);} else PyErr_Clear();
  RexxArrayObject shapeOut=c->NewArray(0), stridesOut=c->NewArray(0);
  PyObject*shape=PyObject_GetAttrString(o,"shape");
  if(shape){PyObject*seq=PySequence_Fast(shape,"shape must be a sequence");if(seq){Py_ssize_t n=PySequence_Fast_GET_SIZE(seq);shapeOut=c->NewArray((size_t)n);for(Py_ssize_t i=0;i<n;++i){PyObject*x=PySequence_Fast_GET_ITEM(seq,i);long long v=PyLong_AsLongLong(x);if(PyErr_Occurred()){PyErr_Clear();v=0;}c->ArrayPut(shapeOut,c->Int64ToObject(v),(size_t)i+1);}Py_DECREF(seq);}else PyErr_Clear();Py_DECREF(shape);}else PyErr_Clear();
  PyObject*strides=PyObject_GetAttrString(o,"strides");
  long long strideScale=1;
  if(!strides){PyErr_Clear();PyObject*strideFn=PyObject_GetAttrString(o,"stride");if(strideFn&&PyCallable_Check(strideFn)){strides=PyObject_CallNoArgs(strideFn);PyObject*es=PyObject_GetAttrString(o,"element_size");if(es&&PyCallable_Check(es)){PyObject*v=PyObject_CallNoArgs(es);if(v){strideScale=PyLong_AsLongLong(v);if(PyErr_Occurred()){PyErr_Clear();strideScale=1;}Py_DECREF(v);}else PyErr_Clear();}Py_XDECREF(es);}Py_XDECREF(strideFn);}
  if(strides && strides!=Py_None){PyObject*seq=PySequence_Fast(strides,"strides must be a sequence");if(seq){Py_ssize_t n=PySequence_Fast_GET_SIZE(seq);stridesOut=c->NewArray((size_t)n);for(Py_ssize_t i=0;i<n;++i){PyObject*x=PySequence_Fast_GET_ITEM(seq,i);long long v=PyLong_AsLongLong(x);if(PyErr_Occurred()){PyErr_Clear();v=0;}v*=strideScale;c->ArrayPut(stridesOut,c->Int64ToObject(v),(size_t)i+1);}Py_DECREF(seq);}else PyErr_Clear();}
  Py_XDECREF(strides);
  long long deviceType=0,deviceId=0;
  PyObject*devfn=PyObject_GetAttrString(o,"__dlpack_device__");
  if(devfn){PyObject*dev=PyObject_CallNoArgs(devfn);Py_DECREF(devfn);if(dev){if(PyTuple_Check(dev)&&PyTuple_Size(dev)>=2){
      PyObject*dt=PyNumber_Long(PyTuple_GetItem(dev,0));if(dt){deviceType=PyLong_AsLongLong(dt);Py_DECREF(dt);if(PyErr_Occurred()){PyErr_Clear();deviceType=0;}}else PyErr_Clear();
      PyObject*di=PyNumber_Long(PyTuple_GetItem(dev,1));if(di){deviceId=PyLong_AsLongLong(di);Py_DECREF(di);if(PyErr_Occurred()){PyErr_Clear();deviceId=0;}}else PyErr_Clear();
    }Py_DECREF(dev);}else PyErr_Clear();}else PyErr_Clear();
  std::string deviceName="unknown";
  switch(deviceType){
    case 1:deviceName="cpu";break; case 2:deviceName="cuda";break; case 3:deviceName="cuda-host";break;
    case 4:deviceName="opencl";break; case 7:deviceName="vulkan";break; case 8:deviceName="metal";break;
    case 9:deviceName="vpi";break; case 10:deviceName="rocm";break; case 11:deviceName="rocm-host";break;
    case 12:deviceName="extdev";break; case 13:deviceName="cuda-managed";break; case 14:deviceName="oneapi";break;
    case 15:deviceName="webgpu";break; case 16:deviceName="hexagon";break; default:break;
  }
  int readonly=0,readonlyKnown=0;
  Py_buffer v{}; if(PyObject_GetBuffer(o,&v,PyBUF_CONTIG_RO)==0){readonlyKnown=1;readonly=v.readonly?1:0;PyBuffer_Release(&v);}else PyErr_Clear();
  RexxArrayObject a=c->NewArray(8);
  c->ArrayPut(a,c->String("dlpack"),1);
  c->ArrayPut(a,c->String(dtypeText.c_str()),2);
  c->ArrayPut(a,shapeOut,3);
  c->ArrayPut(a,stridesOut,4);
  c->ArrayPut(a,c->Int64ToObject(deviceType),5);
  c->ArrayPut(a,c->Int64ToObject(deviceId),6);
  c->ArrayPut(a,c->String(deviceName.c_str()),7);
  c->ArrayPut(a,readonlyKnown?(readonly?c->True():c->False()):c->Nil(),8);
  return a;
}

RexxObjectPtr tensorToDLPack(RexxCallContext*c,PyObject*source,const char*module,const char*functionName){
  if(!PyObject_HasAttrString(source,"__dlpack__")) throw std::runtime_error("Python object does not expose __dlpack__");
  PyObject*m=PyImport_ImportModule(module);if(!m)throw std::runtime_error(pyError());
  PyObject*fn=PyObject_GetAttrString(m,functionName);Py_DECREF(m);if(!fn)throw std::runtime_error(pyError());
  if(!PyCallable_Check(fn)){Py_DECREF(fn);throw std::runtime_error("DLPack target is not callable");}
  PyObject*r=PyObject_CallOneArg(fn,source);Py_DECREF(fn);if(!r)throw std::runtime_error(pyError());
  RexxObjectPtr out=pyToRexx(c,r);Py_DECREF(r);return out;
}

RexxRoutine1(RexxObjectPtr,rexx_foreign_python_can_import,CSTRING,module){try{GIL gil;PyObject*m=PyImport_ImportModule(module);if(m){Py_DECREF(m);return context->True();}PyErr_Clear();return context->False();}catch(...){PyErr_Clear();return context->False();}}
RexxRoutine1(RexxObjectPtr,rexx_foreign_python_import,CSTRING,module){try{GIL gil;PyObject*m=PyImport_ImportModule(module);if(!m)throw std::runtime_error(pyError());uint64_t id=store(m);RexxArrayObject a=context->NewArray(2);context->ArrayPut(a,context->UnsignedInt64ToObject(id),1);context->ArrayPut(a,context->String(module),2);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,rexx_foreign_python_as_buffer,uint64_t,id){try{GIL gil;PyObject*o=acquire(id);size_t n=0;int ro=0;uint64_t bid=0;try{bid=importPythonBuffer(o,&n,&ro);}catch(...){Py_DECREF(o);throw;}Py_DECREF(o);RexxArrayObject a=context->NewArray(3);context->ArrayPut(a,context->UnsignedInt64ToObject(bid),1);context->ArrayPut(a,context->UnsignedInt64ToObject(n),2);context->ArrayPut(a,ro?context->True():context->False(),3);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,rexx_foreign_python_close,uint64_t,id){try{GIL gil;releaseId(id);return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr,rexx_foreign_python_invoke,uint64_t,id,CSTRING,name,RexxArrayObject,args){try{GIL gil;PyObject*o=acquire(id);try{auto r=invokeObject(context,o,name,args);Py_DECREF(o);return r;}catch(...){Py_DECREF(o);throw;}}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine4(RexxObjectPtr,rexx_foreign_python_invoke_kw,uint64_t,id,CSTRING,name,RexxArrayObject,args,RexxArrayObject,kwargs){try{GIL gil;PyObject*o=acquire(id);try{auto r=invokeObject(context,o,name,args,kwargs);Py_DECREF(o);return r;}catch(...){Py_DECREF(o);throw;}}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr,rexx_foreign_python_call,uint64_t,id,RexxArrayObject,args){try{GIL gil;PyObject*o=acquire(id);try{auto r=invokeObject(context,o,nullptr,args);Py_DECREF(o);return r;}catch(...){Py_DECREF(o);throw;}}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,rexx_foreign_python_length,uint64_t,id){try{GIL gil;PyObject*o=acquire(id);Py_ssize_t n=PyObject_Length(o);Py_DECREF(o);if(n<0)throw std::runtime_error(pyError());return context->UnsignedInt64ToObject((uint64_t)n);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr,rexx_foreign_python_getitem,uint64_t,id,RexxObjectPtr,key){try{GIL gil;PyObject*o=acquire(id);PyObject*k=rexxToPy(context,key,nullptr);if(!k){Py_DECREF(o);throw std::runtime_error(pyError());}PyObject*v=PyObject_GetItem(o,k);Py_DECREF(k);Py_DECREF(o);if(!v)throw std::runtime_error(pyError());RexxObjectPtr r=pyToRexx(context,v);Py_DECREF(v);return r;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr,rexx_foreign_python_get,uint64_t,id,CSTRING,name){try{GIL gil;PyObject*o=acquire(id);PyObject*x=getAttrCaseless(o,name);Py_DECREF(o);if(!x)throw std::runtime_error(pyError());auto r=pyToRexx(context,x);Py_DECREF(x);return r;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,rexx_foreign_python_methods,uint64_t,id){try{GIL gil;PyObject*o=acquire(id);PyObject*d=PyObject_Dir(o);Py_DECREF(o);if(!d)throw std::runtime_error(pyError());std::vector<std::string> names;Py_ssize_t n=PyList_Size(d);for(Py_ssize_t i=0;i<n;++i){PyObject*k=PyList_GetItem(d,i);const char*s=PyUnicode_Check(k)?PyUnicode_AsUTF8(k):nullptr;if(!s||s[0]=='_')continue;PyObject*base=acquire(id);PyObject*a=PyObject_GetAttrString(base,s);Py_DECREF(base);if(a){if(PyCallable_Check(a))names.emplace_back(s);Py_DECREF(a);}else PyErr_Clear();}Py_DECREF(d);RexxArrayObject a=context->NewArray(names.size());for(size_t i=0;i<names.size();++i)context->ArrayPut(a,context->String(names[i].c_str()),i+1);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr,rexx_foreign_python_signature,uint64_t,id,CSTRING,name){try{GIL gil;PyObject*o=acquire(id);PyObject*fn=getAttrCaseless(o,name);Py_DECREF(o);if(!fn)throw std::runtime_error(pyError());PyObject*sig=getSignature(fn);Py_DECREF(fn);if(!sig)throw std::runtime_error(pyError());PyObject*s=PyObject_Str(sig);Py_DECREF(sig);if(!s)throw std::runtime_error(pyError());const char*q=PyUnicode_AsUTF8(s);RexxObjectPtr r=context->String(q?q:"");Py_DECREF(s);return r;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr,rexx_foreign_python_method_info,uint64_t,id,CSTRING,name){try{GIL gil;PyObject*o=acquire(id);try{RexxObjectPtr r=methodInfo(context,o,name);Py_DECREF(o);return r;}catch(...){Py_DECREF(o);throw;}}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr,rexx_foreign_python_method_by_inputs,uint64_t,id,CSTRING,name,RexxArrayObject,args){try{GIL gil;PyObject*o=acquire(id);try{
  PyObject*fn=getAttrCaseless(o,name); if(!fn)throw std::runtime_error(pyError());
  PyObject*sig=getSignature(fn); if(!sig){Py_DECREF(fn);throw std::runtime_error(pyError());}
  size_t n=context->ArraySize(args); auto anns=positionalAnnotations(fn,n); PyObject*t=PyTuple_New((Py_ssize_t)n);
  if(!t){releaseAnnotations(anns);Py_DECREF(sig);Py_DECREF(fn);throw std::runtime_error(pyError());}
  for(size_t i=0;i<n;++i){PyObject*x=rexxToPy(context,context->ArrayAt(args,i+1),anns[i]);if(!x){releaseAnnotations(anns);Py_DECREF(t);Py_DECREF(sig);Py_DECREF(fn);throw std::runtime_error(pyError());}PyTuple_SET_ITEM(t,(Py_ssize_t)i,x);}
  releaseAnnotations(anns); PyObject*bind=PyObject_GetAttrString(sig,"bind"); Py_DECREF(sig);
  if(!bind){Py_DECREF(t);Py_DECREF(fn);throw std::runtime_error(pyError());}
  PyObject*bound=PyObject_Call(bind,t,nullptr); Py_DECREF(bind); Py_DECREF(t);
  if(!bound){Py_DECREF(fn);throw std::runtime_error(pyError());} Py_DECREF(bound); Py_DECREF(fn);
  RexxObjectPtr r=methodInfo(context,o,name); Py_DECREF(o); return r;
}catch(...){Py_DECREF(o);throw;}}catch(const std::exception&e){return fail(context,e.what());}}

RexxRoutine1(RexxObjectPtr,rexx_foreign_python_as_tensor,uint64_t,id){try{GIL gil;PyObject*o=acquire(id);try{RexxObjectPtr info=tensorInfo(context,o);uint64_t nativeTid=importPythonTensor(o);uint64_t tid=store(o);RexxArrayObject a=context->NewArray(3);context->ArrayPut(a,context->UnsignedInt64ToObject(tid),1);context->ArrayPut(a,info,2);context->ArrayPut(a,context->UnsignedInt64ToObject(nativeTid),3);return a;}catch(...){Py_DECREF(o);throw;}}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,rexx_foreign_python_tensor_native_close,uint64_t,id){try{ensureBufferApi();tensorClose(id);return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,rexx_foreign_python_tensor_info,uint64_t,id){try{GIL gil;PyObject*o=acquire(id);try{RexxObjectPtr r=tensorInfo(context,o);Py_DECREF(o);return r;}catch(...){Py_DECREF(o);throw;}}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr,rexx_foreign_python_tensor_to_dlpack,uint64_t,id,CSTRING,module,CSTRING,functionName){try{GIL gil;PyObject*o=acquire(id);try{RexxObjectPtr r=tensorToDLPack(context,o,module,functionName);Py_DECREF(o);return r;}catch(...){Py_DECREF(o);throw;}}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,rexx_foreign_python_info,uint64_t,id){try{GIL gil;PyObject*o=acquire(id);const char*tn=Py_TYPE(o)->tp_name;PyObject*r=PyObject_Repr(o);PyObject*f=PyObject_GetAttrString(o,"__file__");RexxArrayObject a=context->NewArray(5);context->ArrayPut(a,context->String("python"),1);context->ArrayPut(a,context->String(tn?tn:"object"),2);context->ArrayPut(a,context->String(r?PyUnicode_AsUTF8(r):""),3);context->ArrayPut(a,context->String((f&&PyUnicode_Check(f))?PyUnicode_AsUTF8(f):""),4);context->ArrayPut(a,context->String(Py_GetVersion()),5);Py_XDECREF(f);Py_XDECREF(r);Py_DECREF(o);return a;}catch(const std::exception&e){return fail(context,e.what());}}

static RexxRoutineEntry routines[]={
 REXX_TYPED_ROUTINE(rexx_foreign_python_import,rexx_foreign_python_import),
 REXX_TYPED_ROUTINE(rexx_foreign_python_can_import,rexx_foreign_python_can_import),
 REXX_TYPED_ROUTINE(rexx_foreign_python_as_buffer,rexx_foreign_python_as_buffer),
 REXX_TYPED_ROUTINE(rexx_foreign_python_close,rexx_foreign_python_close),
 REXX_TYPED_ROUTINE(rexx_foreign_python_invoke,rexx_foreign_python_invoke),
 REXX_TYPED_ROUTINE(rexx_foreign_python_invoke_kw,rexx_foreign_python_invoke_kw),
 REXX_TYPED_ROUTINE(rexx_foreign_python_length,rexx_foreign_python_length),
 REXX_TYPED_ROUTINE(rexx_foreign_python_getitem,rexx_foreign_python_getitem),
 REXX_TYPED_ROUTINE(rexx_foreign_python_call,rexx_foreign_python_call),
 REXX_TYPED_ROUTINE(rexx_foreign_python_get,rexx_foreign_python_get),
 REXX_TYPED_ROUTINE(rexx_foreign_python_methods,rexx_foreign_python_methods),
 REXX_TYPED_ROUTINE(rexx_foreign_python_signature,rexx_foreign_python_signature),
 REXX_TYPED_ROUTINE(rexx_foreign_python_method_info,rexx_foreign_python_method_info),
 REXX_TYPED_ROUTINE(rexx_foreign_python_method_by_inputs,rexx_foreign_python_method_by_inputs),
 REXX_TYPED_ROUTINE(rexx_foreign_python_as_tensor,rexx_foreign_python_as_tensor),
 REXX_TYPED_ROUTINE(rexx_foreign_python_tensor_info,rexx_foreign_python_tensor_info),
 REXX_TYPED_ROUTINE(rexx_foreign_python_tensor_native_close,rexx_foreign_python_tensor_native_close),
 REXX_TYPED_ROUTINE(rexx_foreign_python_tensor_to_dlpack,rexx_foreign_python_tensor_to_dlpack),
 REXX_TYPED_ROUTINE(rexx_foreign_python_info,rexx_foreign_python_info),
 REXX_LAST_ROUTINE()};
RexxPackageEntry foreign_python_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,"ooRexxForeignPython","0.22.6",NULL,NULL,routines,NULL};
OOREXX_GET_PACKAGE(foreign_python);
