#include <oorexxapi.h>
#include <stdint.h>
#include <cstdlib>
#include <cerrno>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <map>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>
#include <mutex>
#include <condition_variable>
#include <cctype>
#include <algorithm>
#include <type_traits>
#include <thread>
#include <set>
#ifdef _WIN32
# include <windows.h>
#else
# include <dlfcn.h>
# include <link.h>
# include <sys/types.h>
# include <sys/socket.h>
#endif

namespace {
struct J { enum K{N,B,NUM,STR,ARR,OBJ} k=N; bool b=false; double n=0; std::string s; std::vector<J>a; std::map<std::string,J>o; };
struct JP { const std::string&s; size_t p=0; JP(const std::string&x):s(x){} void ws(){while(p<s.size()&&isspace((unsigned char)s[p]))p++;} char get(){if(p>=s.size())throw std::runtime_error("unexpected eof");return s[p++];} bool eat(char c){ws();if(p<s.size()&&s[p]==c){p++;return true;}return false;} J val(){ws(); if(p>=s.size())throw std::runtime_error("empty json"); char c=s[p]; if(c=='{')return obj(); if(c=='[')return arr(); if(c=='\"'){J j;j.k=J::STR;j.s=str();return j;} if(c=='t'||c=='f'){J j;j.k=J::B;if(s.compare(p,4,"true")==0){j.b=true;p+=4;}else if(s.compare(p,5,"false")==0){j.b=false;p+=5;}else throw std::runtime_error("bad bool");return j;} if(c=='n'){if(s.compare(p,4,"null"))throw std::runtime_error("bad null");p+=4;return J();} return num(); }
std::string str(){if(get()!='\"')throw std::runtime_error("string expected");std::string r;while(p<s.size()){char c=get();if(c=='\"')return r;if(c=='\\'){char e=get();switch(e){case '\"':r+='\"';break;case '\\':r+='\\';break;case '/':r+='/';break;case 'b':r+='\b';break;case 'f':r+='\f';break;case 'n':r+='\n';break;case 'r':r+='\r';break;case 't':r+='\t';break;default:throw std::runtime_error("unsupported json escape");}}else r+=c;}throw std::runtime_error("unterminated string");}
J num(){ws();size_t q=p;if(s[p]=='-')p++;while(p<s.size()&&isdigit((unsigned char)s[p]))p++;if(p<s.size()&&s[p]=='.'){p++;while(p<s.size()&&isdigit((unsigned char)s[p]))p++;} J j;j.k=J::NUM;j.n=std::stod(s.substr(q,p-q));return j;}
J arr(){J j;j.k=J::ARR;get();ws();if(eat(']'))return j;for(;;){j.a.push_back(val());ws();if(eat(']'))return j;if(!eat(','))throw std::runtime_error("expected comma");}}
J obj(){J j;j.k=J::OBJ;get();ws();if(eat('}'))return j;for(;;){ws();std::string k=str();if(!eat(':'))throw std::runtime_error("expected colon");j.o[k]=val();ws();if(eat('}'))return j;if(!eat(','))throw std::runtime_error("expected comma");}}
};
const J* jo(const J&j,const char*k){auto it=j.o.find(k);return it==j.o.end()?nullptr:&it->second;}
std::string js(const J&j,const char*k,const std::string&d=""){auto*x=jo(j,k);return x&&x->k==J::STR?x->s:d;}
std::string lower(std::string s){for(auto&c:s)c=(char)tolower((unsigned char)c);return s;}
std::string runtimeOsFamily(){
#if defined(_WIN32)
  return "windows";
#elif defined(__linux__)
  return "linux";
#elif defined(__APPLE__)
  return "darwin";
#elif defined(__FreeBSD__)
  return "freebsd";
#else
  return "posix";
#endif
}
std::string runtimeArchitecture(){
#if defined(__x86_64__) || defined(_M_X64)
  return "x86_64";
#elif defined(__aarch64__) || defined(_M_ARM64)
  return "aarch64";
#elif defined(__i386__) || defined(_M_IX86)
  return "x86";
#elif defined(__arm__) || defined(_M_ARM)
  return "arm";
#else
  return "unknown";
#endif
}
std::string runtimeEndianness(){uint16_t x=1;return (*(uint8_t*)&x)?"le":"be";}
std::string runtimeDataModel(){
#ifdef _WIN32
  if(sizeof(void*)==8 && sizeof(long)==4)return "llp64";
#else
  if(sizeof(void*)==8 && sizeof(long)==8 && sizeof(int)==4)return "lp64";
#endif
  if(sizeof(void*)==4 && sizeof(long)==4 && sizeof(int)==4)return "ilp32";
  std::ostringstream q;q<<"p"<<(sizeof(void*)*8)<<"-l"<<(sizeof(long)*8)<<"-i"<<(sizeof(int)*8);return q.str();
}
std::string runtimeAbiProfile(){return runtimeOsFamily()+"-"+runtimeArchitecture()+"-"+runtimeEndianness()+"-"+runtimeDataModel();}
const std::vector<std::string>& qualifiedAbiProfiles(){static const std::vector<std::string> q={"linux-x86_64-le-lp64"};return q;}
bool isQualifiedAbiProfile(const std::string&p){const auto&q=qualifiedAbiProfiles();return std::find(q.begin(),q.end(),p)!=q.end();}

enum class T{VOID,I8,U8,I16,U16,I32,U32,I64,U64,IPTR,UPTR,F64,BOOL,UTF8,UTF16,PTR,BYTES};
struct TypeInfo { T carrier; const char* semantic; size_t size; size_t align; bool isSigned; const char* carrierName; const char* pointerTo; const char* handleKind; const char* encoding; const char* cc; };
TypeInfo typeInfo(std::string s){
  s=lower(s);
  if(s=="void") return {T::VOID,"void",0,0,false,"void","","","","native"};
  if(s=="i8"||s=="int8"||s=="int8_t"||s=="signed char") return {T::I8,"integer",1,alignof(int8_t),true,"i8","","","","native"};
  if(s=="u8"||s=="uint8"||s=="uint8_t"||s=="unsigned char") return {T::U8,"integer",1,alignof(uint8_t),false,"u8","","","","native"};
  if(s=="i16"||s=="int16") return {T::I16,"integer",2,alignof(int16_t),true,"i16","","","","native"};
  if(s=="u16"||s=="uint16") return {T::U16,"integer",2,alignof(uint16_t),false,"u16","","","","native"};
  if(s=="i32"||s=="int32") return {T::I32,"integer",4,alignof(int32_t),true,"i32","","","","native"};
  if(s=="u32"||s=="uint32"||s=="dword") return {T::U32,s=="dword"?"windows-integer":"integer",4,alignof(uint32_t),false,"u32","","","","native"};
  if(s=="i64"||s=="int64") return {T::I64,"integer",8,alignof(int64_t),true,"i64","","","","native"};
  if(s=="u64"||s=="uint64") return {T::U64,"integer",8,alignof(uint64_t),false,"u64","","","","native"};
  if(s=="short"||s=="signed short"||s=="short int"||s=="signed short int") {
    if(sizeof(short)==2) return {T::I16,"c-native-integer",sizeof(short),alignof(short),true,"i16","","","","native"};
    throw std::runtime_error("unsupported C short width");
  }
  if(s=="unsigned short"||s=="unsigned short int") {
    if(sizeof(unsigned short)==2) return {T::U16,"c-native-integer",sizeof(unsigned short),alignof(unsigned short),false,"u16","","","","native"};
    throw std::runtime_error("unsupported C unsigned short width");
  }
  if(s=="int"||s=="signed int"||s=="signed") {
    if(sizeof(int)==4) return {T::I32,"c-native-integer",sizeof(int),alignof(int),true,"i32","","","","native"};
    if(sizeof(int)==2) return {T::I16,"c-native-integer",sizeof(int),alignof(int),true,"i16","","","","native"};
    if(sizeof(int)==8) return {T::I64,"c-native-integer",sizeof(int),alignof(int),true,"i64","","","","native"};
    throw std::runtime_error("unsupported C int width");
  }
  if(s=="unsigned int"||s=="unsigned") {
    if(sizeof(unsigned int)==4) return {T::U32,"c-native-integer",sizeof(unsigned int),alignof(unsigned int),false,"u32","","","","native"};
    if(sizeof(unsigned int)==2) return {T::U16,"c-native-integer",sizeof(unsigned int),alignof(unsigned int),false,"u16","","","","native"};
    if(sizeof(unsigned int)==8) return {T::U64,"c-native-integer",sizeof(unsigned int),alignof(unsigned int),false,"u64","","","","native"};
    throw std::runtime_error("unsupported C unsigned int width");
  }
  if(s=="long long"||s=="signed long long"||s=="long long int"||s=="signed long long int") {
    if(sizeof(long long)==8) return {T::I64,"c-native-integer",sizeof(long long),alignof(long long),true,"i64","","","","native"};
    throw std::runtime_error("unsupported C long long width");
  }
  if(s=="unsigned long long"||s=="unsigned long long int") {
    if(sizeof(unsigned long long)==8) return {T::U64,"c-native-integer",sizeof(unsigned long long),alignof(unsigned long long),false,"u64","","","","native"};
    throw std::runtime_error("unsupported C unsigned long long width");
  }
  if(s=="long"||s=="signed long"||s=="long int"||s=="signed long int") {
    if(sizeof(long)==8) return {T::I64,"c-native-integer",sizeof(long),alignof(long),true,"i64","","","","native"};
    if(sizeof(long)==4) return {T::I32,"c-native-integer",sizeof(long),alignof(long),true,"i32","","","","native"};
    throw std::runtime_error("unsupported C long width");
  }
  if(s=="unsigned long"||s=="unsigned long int") {
    if(sizeof(unsigned long)==8) return {T::U64,"c-native-integer",sizeof(unsigned long),alignof(unsigned long),false,"u64","","","","native"};
    if(sizeof(unsigned long)==4) return {T::U32,"c-native-integer",sizeof(unsigned long),alignof(unsigned long),false,"u32","","","","native"};
    throw std::runtime_error("unsupported C unsigned long width");
  }
  if(s=="size_t") {
    if(sizeof(size_t)==8) return {T::U64,"c-size",sizeof(size_t),alignof(size_t),false,"u64","","","","native"};
    if(sizeof(size_t)==4) return {T::U32,"c-size",sizeof(size_t),alignof(size_t),false,"u32","","","","native"};
    throw std::runtime_error("unsupported size_t width");
  }
  if(s=="ptrdiff_t") {
    if(sizeof(ptrdiff_t)==8) return {T::I64,"c-pointer-difference",sizeof(ptrdiff_t),alignof(ptrdiff_t),true,"i64","","","","native"};
    if(sizeof(ptrdiff_t)==4) return {T::I32,"c-pointer-difference",sizeof(ptrdiff_t),alignof(ptrdiff_t),true,"i32","","","","native"};
    throw std::runtime_error("unsupported ptrdiff_t width");
  }
#ifndef _WIN32
  if(s=="ssize_t") {
    if(sizeof(ssize_t)==8) return {T::I64,"posix-signed-size",sizeof(ssize_t),alignof(ssize_t),true,"i64","","","","native"};
    if(sizeof(ssize_t)==4) return {T::I32,"posix-signed-size",sizeof(ssize_t),alignof(ssize_t),true,"i32","","","","native"};
    throw std::runtime_error("unsupported ssize_t width");
  }
  if(s=="socklen_t") {
    if(sizeof(socklen_t)==8) return {T::U64,"posix-socket-length",sizeof(socklen_t),alignof(socklen_t),false,"u64","","","","native"};
    if(sizeof(socklen_t)==4) return {T::U32,"posix-socket-length",sizeof(socklen_t),alignof(socklen_t),false,"u32","","","","native"};
    if(sizeof(socklen_t)==2) return {T::U16,"posix-socket-length",sizeof(socklen_t),alignof(socklen_t),false,"u16","","","","native"};
    throw std::runtime_error("unsupported socklen_t width");
  }
#endif
  if(s=="intptr"||s=="lparam"||s=="lresult") return {T::IPTR,s=="intptr"?"pointer-sized-integer":"windows-message-integer",sizeof(intptr_t),alignof(intptr_t),true,"intptr","","","","native"};
  if(s=="uintptr"||s=="wparam") return {T::UPTR,s=="uintptr"?"pointer-sized-integer":"windows-message-integer",sizeof(uintptr_t),alignof(uintptr_t),false,"uintptr","","","","native"};
  if(s=="handle"||s=="hwnd"||s=="hmodule"||s=="hdc"||s=="hinstance") return {T::UPTR,"handle",sizeof(void*),alignof(void*),false,"uintptr","","handle","","native"};
  if(s=="f64"||s=="double") return {T::F64,"floating",8,alignof(double),true,"f64","","","","native"};
  if(s=="bool") return {T::BOOL,"boolean",4,alignof(int32_t),true,"i32","","","","native"};
  if(s=="utf8"||s=="string"||s=="cstring") return {T::UTF8,"string",sizeof(void*),alignof(void*),false,"pointer","char","","UTF-8","native"};
  if(s=="utf16"||s=="wstring"||s=="lpcwstr"||s=="lpwstr") return {T::UTF16,"string",sizeof(void*),alignof(void*),false,"pointer","char16","","UTF-16LE","native"};
  if(s=="bytes"||s=="byte-buffer"||s=="const-bytes") return {T::BYTES,"bytes",sizeof(void*),alignof(void*),false,"pointer","u8","","binary","native"};
  if(s=="ptr"||s=="pointer"||s=="lpvoid"||s=="lpcvoid") return {T::PTR,"pointer",sizeof(void*),alignof(void*),false,"pointer","void","","","native"};
  throw std::runtime_error("unsupported datatype: "+s);
}
T typeOf(const std::string&s){return typeInfo(s).carrier;}

std::u16string utf8to16(const std::string &in){std::u16string out;for(size_t i=0;i<in.size();){uint32_t cp;unsigned char c=in[i++];if(c<0x80)cp=c;else if((c>>5)==6&&i<in.size()){cp=((c&31)<<6)|(in[i++]&63);}else if((c>>4)==14&&i+1<in.size()){cp=((c&15)<<12)|((in[i]&63)<<6)|(in[i+1]&63);i+=2;}else if((c>>3)==30&&i+2<in.size()){cp=((c&7)<<18)|((in[i]&63)<<12)|((in[i+1]&63)<<6)|(in[i+2]&63);i+=3;}else throw std::runtime_error("invalid UTF-8");if(cp<=0xFFFF)out.push_back((char16_t)cp);else{cp-=0x10000;out.push_back((char16_t)(0xD800+(cp>>10)));out.push_back((char16_t)(0xDC00+(cp&0x3FF)));}}return out;}
std::string utf16to8(const char16_t *p){if(!p)return {};std::string out;for(size_t i=0;p[i];++i){uint32_t cp=p[i];if(cp>=0xD800&&cp<=0xDBFF&&p[i+1]>=0xDC00&&p[i+1]<=0xDFFF){cp=0x10000+((cp-0xD800)<<10)+(p[++i]-0xDC00);}if(cp<0x80)out.push_back((char)cp);else if(cp<0x800){out.push_back((char)(0xC0|(cp>>6)));out.push_back((char)(0x80|(cp&63)));}else if(cp<0x10000){out.push_back((char)(0xE0|(cp>>12)));out.push_back((char)(0x80|((cp>>6)&63)));out.push_back((char)(0x80|(cp&63)));}else{out.push_back((char)(0xF0|(cp>>18)));out.push_back((char)(0x80|((cp>>12)&63)));out.push_back((char)(0x80|((cp>>6)&63)));out.push_back((char)(0x80|(cp&63)));}}return out;}

struct DynamicLibrary{
  std::string loadedName;
#ifdef _WIN32
  HMODULE h=nullptr;
#else
  void*h=nullptr;
#endif
  void open(const std::string&path){
#ifdef _WIN32
    auto w=utf8to16(path); h=LoadLibraryW((LPCWSTR)w.c_str()); if(!h)throw std::runtime_error("LoadLibraryW failed: "+path); loadedName=path;
#else
    h=dlopen(path.c_str(),RTLD_NOW|RTLD_LOCAL); if(!h)throw std::runtime_error(std::string("dlopen failed for ")+path+": "+dlerror());
    loadedName=path;
# if defined(__linux__)
    struct link_map *lm=nullptr;
    if(dlinfo(h,RTLD_DI_LINKMAP,&lm)==0 && lm && lm->l_name && *lm->l_name) loadedName=lm->l_name;
# endif
#endif
  }
  void* symbol(const std::string&name){
#ifdef _WIN32
    auto p=(void*)GetProcAddress(h,name.c_str()); if(!p)throw std::runtime_error("GetProcAddress failed: "+name); return p;
#else
    dlerror(); void*p=dlsym(h,name.c_str());const char*e=dlerror();if(e)throw std::runtime_error(std::string("dlsym failed: ")+e);return p;
#endif
  }
  ~DynamicLibrary(){
#ifdef _WIN32
    if(h)FreeLibrary(h);
#else
    if(h)dlclose(h);
#endif
  }
};
struct Constant{std::string datatype; std::string value;};
struct StructField{std::string name;std::string type;size_t offset=0;};
struct StructType{std::string name;size_t size=0;size_t align=1;std::vector<StructField>fields;};
struct CallbackSpec{std::string name;std::string ret="void";std::vector<std::string> args;std::string threadPolicy="call-thread";std::string lifetime="call";};
struct ArgSpec{std::string type; std::string direction="in"; std::string objectType; std::string callbackType; std::string name; size_t size=0; std::string resultType="buffer"; int pointerDepth=1; std::string ownership="borrowed"; std::string destructor; int destructorPointerDepth=1; std::string addressSpace="any"; size_t byteLength=0;std::string resourceType;std::string resourceCarrier="i32";std::string invalid="-1";std::string outputsOnReturn="always";};
struct Function{std::string logicalName;std::string symbol; std::string ret; std::vector<ArgSpec> args; std::string callingConvention="native"; bool returnsObject=false; std::string objectType; std::string ownership="borrowed"; std::string destructor; int destructorPointerDepth=1; std::string addressSpace="host"; size_t byteLength=0;bool captureErrno=false;bool returnsHandle=false;std::string resourceType;std::string resourceCarrier;std::string invalid="-1";};
struct Lib{std::string definitionPath;std::string path;std::string requested;std::string provider="native";std::string threadingMode="thread-safe";std::string affinity="none";std::string abiProfile;bool abiQualified=false;std::mutex invokeMu;std::vector<std::string> candidates;DynamicLibrary dl;std::map<std::string,Constant>constants;std::map<std::string,StructType>structs;std::map<std::string,CallbackSpec>callbacks;std::map<std::string,std::vector<Function>>funcs;};
using ExternalBufferReleaseV1=void(*)(void*);
struct BufferRecord{
  std::vector<uint8_t> data;
  void* externalPtr=nullptr; size_t externalSize=0; bool readonly=false;
  void* externalToken=nullptr; ExternalBufferReleaseV1 externalRelease=nullptr;
  std::mutex stateMu; std::condition_variable cv; size_t active=0; bool closing=false;
};
static void* bufferData(BufferRecord&r){return r.externalPtr?r.externalPtr:(r.data.empty()?nullptr:r.data.data());}
static const void* bufferData(const BufferRecord&r){return r.externalPtr?r.externalPtr:(r.data.empty()?nullptr:r.data.data());}
static size_t bufferSize(const BufferRecord&r){return r.externalPtr?r.externalSize:r.data.size();}
struct ObjectRecord{void* ptr=nullptr;std::string type;std::string ownership;std::string destructor;int destructorPointerDepth=1;std::string addressSpace="host";size_t byteLength=0;std::shared_ptr<Lib> lib;std::mutex stateMu;std::condition_variable cv;size_t active=0;bool closing=false;};
struct PointerArrayRecord;
struct StructArrayRecord;
struct StructRecord{
  std::shared_ptr<Lib> lib; StructType type; std::vector<uint8_t>data; void*externalPtr=nullptr; std::shared_ptr<ObjectRecord> ownerObject;
  std::map<std::string,std::shared_ptr<BufferRecord>> bufferRefs;
  std::map<std::string,std::shared_ptr<ObjectRecord>> objectRefs;
  std::map<std::string,std::shared_ptr<StructRecord>> structRefs;
  std::map<std::string,std::shared_ptr<PointerArrayRecord>> pointerArrayRefs;
  std::map<std::string,std::shared_ptr<StructArrayRecord>> structArrayRefs;
  std::mutex stateMu; std::condition_variable cv; size_t active=0; bool closing=false;
};
struct PointerArrayRecord{std::string elementType="pointer";std::vector<void*> slots;std::vector<std::shared_ptr<BufferRecord>> bufferRefs;std::vector<std::shared_ptr<ObjectRecord>> objectRefs;std::mutex stateMu;std::condition_variable cv;size_t active=0;bool closing=false;};
struct HandleRecord{uint64_t value=0;std::string type;std::string carrier="i32";std::string ownership="owned";std::string destructor;std::shared_ptr<Lib> lib;std::mutex stateMu;std::condition_variable cv;size_t active=0;bool closing=false;};
struct StructArrayRecord{std::shared_ptr<Lib> lib;StructType type;size_t count=0;std::vector<uint8_t> data;std::mutex stateMu;std::condition_variable cv;size_t active=0;bool closing=false;};
struct CallbackRecord{CallbackSpec spec;RexxObjectPtr target=nullptr;std::string method;bool closed=false;};
std::mutex mu; std::mutex structGraphMu; std::map<uint64_t,std::shared_ptr<Lib>> libs; std::map<uint64_t,std::shared_ptr<BufferRecord>> buffers; std::map<uint64_t,std::shared_ptr<ObjectRecord>> objects; std::map<uint64_t,std::shared_ptr<StructRecord>> structs; std::map<uint64_t,std::shared_ptr<PointerArrayRecord>> pointerArrays;std::map<uint64_t,std::shared_ptr<HandleRecord>> handles;std::map<uint64_t,std::shared_ptr<StructArrayRecord>> structArrays; std::map<uint64_t,std::shared_ptr<CallbackRecord>> callbackObjects; uint64_t nextId=1, defaultId=0, nextBufferId=1, nextObjectId=1, nextStructId=1, nextPointerArrayId=1,nextHandleId=1,nextStructArrayId=1, nextCallbackId=1;
struct BufferPin{std::shared_ptr<BufferRecord> r; void* ptr=nullptr; explicit BufferPin(std::shared_ptr<BufferRecord>x):r(std::move(x)){std::unique_lock<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");++r->active;ptr=bufferData(*r);}~BufferPin(){if(!r)return;std::lock_guard<std::mutex>g(r->stateMu);if(r->active)--r->active;if(r->active==0)r->cv.notify_all();}BufferPin(BufferPin&&o)noexcept:r(std::move(o.r)),ptr(o.ptr){o.ptr=nullptr;}BufferPin(const BufferPin&)=delete;};
struct ObjectPin{std::shared_ptr<ObjectRecord> r; void* ptr=nullptr; explicit ObjectPin(std::shared_ptr<ObjectRecord>x):r(std::move(x)){std::unique_lock<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign object handle not found or closed");++r->active;ptr=r->ptr;}~ObjectPin(){if(!r)return;std::lock_guard<std::mutex>g(r->stateMu);if(r->active)--r->active;if(r->active==0)r->cv.notify_all();}ObjectPin(ObjectPin&&o)noexcept:r(std::move(o.r)),ptr(o.ptr){o.ptr=nullptr;}ObjectPin(const ObjectPin&)=delete;};
struct HandlePin{std::shared_ptr<HandleRecord> r;uint64_t value=0;explicit HandlePin(std::shared_ptr<HandleRecord>x):r(std::move(x)){std::unique_lock<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign handle not found or closed");++r->active;value=r->value;}~HandlePin(){if(!r)return;std::lock_guard<std::mutex>g(r->stateMu);if(r->active)--r->active;if(r->active==0)r->cv.notify_all();}HandlePin(HandlePin&&o)noexcept:r(std::move(o.r)),value(o.value){}HandlePin(const HandlePin&)=delete;};
struct StructArrayPin{std::shared_ptr<StructArrayRecord> r;void*ptr=nullptr;explicit StructArrayPin(std::shared_ptr<StructArrayRecord>x):r(std::move(x)){std::unique_lock<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign struct array not found or closed");++r->active;ptr=r->data.empty()?nullptr:r->data.data();}~StructArrayPin(){if(!r)return;std::lock_guard<std::mutex>g(r->stateMu);if(r->active)--r->active;if(r->active==0)r->cv.notify_all();}StructArrayPin(StructArrayPin&&o)noexcept:r(std::move(o.r)),ptr(o.ptr){o.ptr=nullptr;}StructArrayPin(const StructArrayPin&)=delete;};
struct PointerArrayPin{std::shared_ptr<PointerArrayRecord> r;void*ptr=nullptr;std::vector<std::unique_ptr<BufferPin>>bp;std::vector<std::unique_ptr<ObjectPin>>op;explicit PointerArrayPin(std::shared_ptr<PointerArrayRecord>x):r(std::move(x)){std::unique_lock<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign pointer array handle not found or closed");++r->active;auto br=r->bufferRefs;auto orr=r->objectRefs;ptr=r->slots.empty()?nullptr:r->slots.data();g.unlock();for(auto&q:br)if(q)bp.emplace_back(new BufferPin(q));for(auto&q:orr)if(q)op.emplace_back(new ObjectPin(q));}~PointerArrayPin(){bp.clear();op.clear();if(!r)return;std::lock_guard<std::mutex>g(r->stateMu);if(r->active)--r->active;if(r->active==0)r->cv.notify_all();}PointerArrayPin(PointerArrayPin&&o)noexcept:r(std::move(o.r)),ptr(o.ptr),bp(std::move(o.bp)),op(std::move(o.op)){o.ptr=nullptr;}PointerArrayPin(const PointerArrayPin&)=delete;};
struct StructPin{
  std::shared_ptr<StructRecord> r; void*ptr=nullptr; std::unique_ptr<ObjectPin> ownerPin;
  std::vector<std::unique_ptr<BufferPin>> bufferPins;
  std::vector<std::unique_ptr<ObjectPin>> objectPins;
  std::vector<std::unique_ptr<StructPin>> structPins;
  std::vector<std::unique_ptr<PointerArrayPin>> pointerArrayPins;
  std::vector<std::unique_ptr<StructArrayPin>> structArrayPins;
  explicit StructPin(std::shared_ptr<StructRecord>x):r(std::move(x)){
    std::shared_ptr<ObjectRecord> owner;
    std::vector<std::shared_ptr<BufferRecord>> br; std::vector<std::shared_ptr<ObjectRecord>> obr;
    std::vector<std::shared_ptr<StructRecord>> sr; std::vector<std::shared_ptr<PointerArrayRecord>> par; std::vector<std::shared_ptr<StructArrayRecord>> sar;
    {
      std::unique_lock<std::mutex>g(r->stateMu);
      if(r->closing)throw std::runtime_error("foreign struct handle not found or closed");
      ++r->active; owner=r->ownerObject; ptr=r->externalPtr?r->externalPtr:(r->data.empty()?nullptr:r->data.data());
      for(auto&kv:r->bufferRefs)if(kv.second)br.push_back(kv.second);
      for(auto&kv:r->objectRefs)if(kv.second)obr.push_back(kv.second);
      for(auto&kv:r->structRefs)if(kv.second)sr.push_back(kv.second);
      for(auto&kv:r->pointerArrayRefs)if(kv.second)par.push_back(kv.second);
      for(auto&kv:r->structArrayRefs)if(kv.second)sar.push_back(kv.second);
    }
    try{
      if(owner)ownerPin=std::make_unique<ObjectPin>(owner);
      for(auto&q:br)bufferPins.emplace_back(std::make_unique<BufferPin>(q));
      for(auto&q:obr)objectPins.emplace_back(std::make_unique<ObjectPin>(q));
      for(auto&q:sr)structPins.emplace_back(std::make_unique<StructPin>(q));
      for(auto&q:par)pointerArrayPins.emplace_back(std::make_unique<PointerArrayPin>(q));
      for(auto&q:sar)structArrayPins.emplace_back(std::make_unique<StructArrayPin>(q));
    }catch(...){
      std::lock_guard<std::mutex>g(r->stateMu); if(r->active)--r->active; if(r->active==0)r->cv.notify_all(); throw;
    }
  }
  ~StructPin(){
    structArrayPins.clear(); pointerArrayPins.clear(); structPins.clear(); objectPins.clear(); bufferPins.clear(); ownerPin.reset();
    if(!r)return;
    std::lock_guard<std::mutex>g(r->stateMu);
    if(r->active)--r->active;
    if(r->active==0)r->cv.notify_all();
  }
  StructPin(StructPin&&o)noexcept:r(std::move(o.r)),ptr(o.ptr),ownerPin(std::move(o.ownerPin)),bufferPins(std::move(o.bufferPins)),objectPins(std::move(o.objectPins)),structPins(std::move(o.structPins)),pointerArrayPins(std::move(o.pointerArrayPins)),structArrayPins(std::move(o.structArrayPins)){o.ptr=nullptr;}
  StructPin(const StructPin&)=delete;
};
std::string definitionRelative(const std::string&definition,const std::string&candidate){
  if(candidate.empty())return candidate;
#ifdef _WIN32
  if(candidate.size()>2 && std::isalpha((unsigned char)candidate[0]) && candidate[1]==':')return candidate;
  if(candidate[0]=='/' || candidate[0]=='\\')return candidate;
#else
  if(candidate[0]=='/')return candidate;
#endif
  auto slash=definition.find_last_of("/\\");
  return slash==std::string::npos?candidate:definition.substr(0,slash+1)+candidate;
}
Function parseFunction(const std::string&logical,const J&spec){
  if(spec.k!=J::OBJ)throw std::runtime_error("function signature must be an object: "+logical);
  Function fn;fn.logicalName=logical;fn.symbol=js(spec,"symbol",logical);fn.callingConvention=js(spec,"callingConvention","native");
  if(auto*r=jo(spec,"return")){if(r->k==J::STR)fn.ret=r->s;else if(r->k==J::OBJ){fn.ret=js(*r,"type","pointer");fn.objectType=js(*r,"object");fn.resourceType=js(*r,"resource");fn.resourceCarrier=js(*r,"carrier",fn.ret);fn.ownership=lower(js(*r,"ownership","borrowed"));fn.destructor=js(*r,"destructor");fn.addressSpace=lower(js(*r,"addressSpace","host"));fn.invalid=js(*r,"invalid","-1");if(auto*z=jo(*r,"invalid");z&&z->k==J::NUM){std::ostringstream q;q.precision(17);q<<z->n;fn.invalid=q.str();}if(auto*z=jo(*r,"byteLength");z&&z->k==J::NUM)fn.byteLength=(size_t)z->n;if(auto*z=jo(*r,"destructorPointerDepth");z&&z->k==J::NUM)fn.destructorPointerDepth=(int)z->n;fn.returnsObject=!fn.objectType.empty();fn.returnsHandle=!fn.resourceType.empty();}}if(auto*z=jo(spec,"errno");z&&z->k==J::B)fn.captureErrno=z->b;
  if(fn.ret.empty()) fn.ret="void";
  (void)typeInfo(fn.ret);
  if(fn.returnsObject&&typeOf(fn.ret)!=T::PTR)throw std::runtime_error("foreign object return must use pointer carrier: "+logical);
  if(fn.returnsHandle){T ht=typeOf(fn.resourceCarrier);if(ht==T::PTR||ht==T::UTF8||ht==T::UTF16||ht==T::BYTES||ht==T::VOID||ht==T::F64)throw std::runtime_error("foreign resource return requires integer carrier: "+logical);if(typeOf(fn.ret)!=ht)throw std::runtime_error("foreign resource return carrier must match return type: "+logical);}
  if(fn.destructorPointerDepth<1||fn.destructorPointerDepth>2)throw std::runtime_error("destructorPointerDepth must be 1 or 2: "+logical);
  if(fn.ownership!="owned"&&fn.ownership!="borrowed")throw std::runtime_error("invalid object ownership: "+fn.ownership);
  if(fn.ownership=="owned"&&fn.destructor.empty())throw std::runtime_error("owned object return requires destructor: "+logical);
  if(fn.addressSpace!="host"&&fn.addressSpace!="pinned-host"&&fn.addressSpace!="device"&&fn.addressSpace!="unified"&&fn.addressSpace!="opaque")throw std::runtime_error("invalid foreign addressSpace: "+fn.addressSpace);
  if(auto*a=jo(spec,"args");a&&a->k==J::ARR){
    for(auto&x:a->a){ArgSpec as;if(x.k==J::STR)as.type=x.s;else if(x.k==J::OBJ){as.type=js(x,"type");as.direction=lower(js(x,"direction","in"));as.objectType=js(x,"object");as.callbackType=js(x,"callback");as.name=js(x,"name");as.resultType=lower(js(x,"resultType","buffer"));as.ownership=lower(js(x,"ownership","borrowed"));as.destructor=js(x,"destructor");as.addressSpace=lower(js(x,"addressSpace","any"));as.resourceType=js(x,"resource");as.resourceCarrier=js(x,"carrier","i32");as.invalid=js(x,"invalid","-1");as.outputsOnReturn=lower(js(x,"outputsOnReturn","always"));if(auto*z=jo(x,"invalid");z&&z->k==J::NUM){std::ostringstream q;q.precision(17);q<<z->n;as.invalid=q.str();}if(auto*z=jo(x,"byteLength");z&&z->k==J::NUM)as.byteLength=(size_t)z->n;if(auto*z=jo(x,"destructorPointerDepth");z&&z->k==J::NUM)as.destructorPointerDepth=(int)z->n;if(auto*z=jo(x,"size");z&&z->k==J::NUM)as.size=(size_t)z->n;if(auto*z=jo(x,"pointerDepth");z&&z->k==J::NUM)as.pointerDepth=(int)z->n;}if(as.type.empty())throw std::runtime_error("argument type missing: "+logical);(void)typeInfo(as.type);if(as.direction!="in"&&as.direction!="out"&&as.direction!="inout")throw std::runtime_error("invalid argument direction: "+as.direction);if(as.destructorPointerDepth<1||as.destructorPointerDepth>2)throw std::runtime_error("destructorPointerDepth must be 1 or 2: "+logical);if(as.pointerDepth<1||as.pointerDepth>2)throw std::runtime_error("pointerDepth must be 1 or 2: "+logical);if(as.pointerDepth==2&&typeOf(as.type)!=T::PTR)throw std::runtime_error("pointerDepth 2 requires pointer carrier: "+logical);if(as.pointerDepth==2&&as.objectType.empty())throw std::runtime_error("pointerDepth 2 currently requires object metadata: "+logical);if(!as.callbackType.empty()&&typeOf(as.type)!=T::PTR)throw std::runtime_error("callback argument requires pointer carrier: "+logical);if(as.addressSpace!="any"&&as.addressSpace!="host"&&as.addressSpace!="pinned-host"&&as.addressSpace!="device"&&as.addressSpace!="unified"&&as.addressSpace!="opaque")throw std::runtime_error("invalid argument addressSpace: "+as.addressSpace);if(!as.resourceType.empty()){T ht=typeOf(as.resourceCarrier);if(ht==T::PTR||ht==T::UTF8||ht==T::UTF16||ht==T::BYTES||ht==T::VOID||ht==T::F64)throw std::runtime_error("foreign resource requires integer carrier: "+logical);if(as.resultType!="handle")as.resultType="handle";if(as.direction=="out"&&as.size==0)as.size=typeInfo(as.resourceCarrier).size;if(as.ownership=="owned"&&as.destructor.empty())throw std::runtime_error("owned output resource requires destructor: "+logical);}if(as.outputsOnReturn!="always"&&as.outputsOnReturn!="zero"&&as.outputsOnReturn!="nonnegative"&&as.outputsOnReturn!="positive")throw std::runtime_error("invalid outputsOnReturn: "+logical);if(as.direction=="out"&&as.name.empty())as.name="out"+std::to_string(fn.args.size()+1);fn.args.push_back(as);}
  }
  return fn;
}
std::shared_ptr<Lib> load(const std::string&path){
  std::ifstream f(path);if(!f)throw std::runtime_error("cannot open definition: "+path);std::stringstream b;b<<f.rdbuf();J root=JP(b.str()).val();auto L=std::make_shared<Lib>();L->definitionPath=path;L->path=js(root,"library");bool explicitPath=false;
  const std::string runtimeProfile=runtimeAbiProfile();
  const J* profileSection=nullptr;
  std::string requiredProfile=js(root,"abiProfile");
  if(!requiredProfile.empty()){
    if(requiredProfile!=runtimeProfile)throw std::runtime_error("ABI_PROFILE_MISMATCH: bridge requires "+requiredProfile+" but runtime is "+runtimeProfile);
    if(!isQualifiedAbiProfile(requiredProfile))throw std::runtime_error("ABI_PROFILE_UNQUALIFIED: Foreign Runtime has no qualified bridge profile for "+requiredProfile);
    L->abiProfile=requiredProfile;L->abiQualified=true;
  }
  if(auto*profiles=jo(root,"abiProfiles");profiles&&profiles->k==J::OBJ){
    auto it=profiles->o.find(runtimeProfile);
    if(it==profiles->o.end())throw std::runtime_error("ABI_PROFILE_MISMATCH: bridge has no profile for runtime "+runtimeProfile);
    if(it->second.k!=J::OBJ)throw std::runtime_error("ABI profile section must be an object: "+runtimeProfile);
    if(!isQualifiedAbiProfile(runtimeProfile))throw std::runtime_error("ABI_PROFILE_UNQUALIFIED: Foreign Runtime has no qualified bridge profile for "+runtimeProfile);
    profileSection=&it->second;L->abiProfile=runtimeProfile;L->abiQualified=true;
  }
  if(auto*x=jo(root,"library");x&&x->k==J::OBJ){L->path=js(*x,"path",L->path);explicitPath=!L->path.empty();L->provider=js(*x,"provider","native");L->threadingMode=lower(js(*x,"threading","thread-safe"));L->affinity=lower(js(*x,"affinity","none"));if(auto*n=jo(*x,"names");n&&n->k==J::ARR)for(auto&v:n->a)if(v.k==J::STR&&!v.s.empty())L->candidates.push_back(v.s);}
  if(explicitPath)L->candidates.insert(L->candidates.begin(),definitionRelative(path,L->path));
  if(L->candidates.empty()&&!L->path.empty())L->candidates.push_back(definitionRelative(path,L->path));
  if(L->candidates.empty())throw std::runtime_error("definition has no library path or names");
  if(L->threadingMode!="thread-safe"&&L->threadingMode!="serialized")throw std::runtime_error("unsupported library threading mode in v0.14.0: "+L->threadingMode);
  if(L->affinity!="none")throw std::runtime_error("provider affinity is descriptive-only and must be none in v0.14.0");
  L->requested=L->candidates.front();std::string errors;for(const auto&candidate:L->candidates){try{L->dl.open(candidate);L->path=L->dl.loadedName;break;}catch(const std::exception&e){if(!errors.empty())errors+=" | ";errors+=e.what();}}if(L->dl.loadedName.empty())throw std::runtime_error("no library candidate could be loaded: "+errors);
  std::vector<const J*> metadataSources{&root};if(profileSection)metadataSources.push_back(profileSection);
  for(const J* source:metadataSources){
    if(auto*ts=jo(*source,"types");ts&&ts->k==J::OBJ)for(auto&kv:ts->o){if(kv.second.k!=J::OBJ)continue;if(lower(js(kv.second,"kind"))!="struct")continue;StructType st;st.name=kv.first;if(auto*z=jo(kv.second,"size");z&&z->k==J::NUM)st.size=(size_t)z->n;if(auto*z=jo(kv.second,"alignment");z&&z->k==J::NUM)st.align=(size_t)z->n;if(auto*fs=jo(kv.second,"fields");fs&&fs->k==J::ARR)for(auto&fv:fs->a){if(fv.k!=J::OBJ)throw std::runtime_error("struct field must be object: "+kv.first);StructField sf;sf.name=js(fv,"name");sf.type=js(fv,"type");if(auto*z=jo(fv,"offset");z&&z->k==J::NUM)sf.offset=(size_t)z->n;if(sf.name.empty()||sf.type.empty())throw std::runtime_error("struct field name/type missing: "+kv.first);auto ti=typeInfo(sf.type);if(sf.offset+ti.size>st.size)throw std::runtime_error("struct field outside declared size: "+kv.first+"."+sf.name);st.fields.push_back(sf);}if(st.size==0)throw std::runtime_error("struct requires explicit size: "+kv.first);L->structs[lower(kv.first)]=st;}
    if(auto*c=jo(*source,"constants");c&&c->k==J::OBJ)for(auto &kv:c->o){Constant z;if(kv.second.k==J::OBJ){z.datatype=js(kv.second,"type","i64");auto*v=jo(kv.second,"value");if(!v)throw std::runtime_error("constant has no value: "+kv.first);if(v->k==J::STR)z.value=v->s;else if(v->k==J::NUM){std::ostringstream q;q.precision(17);q<<v->n;z.value=q.str();}else if(v->k==J::B)z.value=v->b?"1":"0";}else if(kv.second.k==J::NUM){z.datatype="i64";std::ostringstream q;q.precision(17);q<<kv.second.n;z.value=q.str();}else if(kv.second.k==J::STR){z.datatype="utf8";z.value=kv.second.s;}(void)typeInfo(z.datatype);L->constants[kv.first]=z;}
  }
  if(auto*cs=jo(root,"callbacks");cs&&cs->k==J::OBJ)for(auto&kv:cs->o){if(kv.second.k!=J::OBJ)throw std::runtime_error("callback definition must be object: "+kv.first);CallbackSpec cb;cb.name=kv.first;cb.ret=js(kv.second,"return","void");cb.threadPolicy=lower(js(kv.second,"threadPolicy","call-thread"));cb.lifetime=lower(js(kv.second,"lifetime","call"));(void)typeInfo(cb.ret);if(cb.threadPolicy!="call-thread"||cb.lifetime!="call")throw std::runtime_error("v0.13 callbacks require threadPolicy=call-thread and lifetime=call: "+kv.first);if(auto*a=jo(kv.second,"args");a&&a->k==J::ARR)for(auto&x:a->a){if(x.k!=J::STR)throw std::runtime_error("callback args must be scalar type names: "+kv.first);T t=typeOf(x.s);if(t==T::PTR||t==T::UTF8||t==T::UTF16||t==T::BYTES)throw std::runtime_error("v0.13 callback pointer/string arguments are not yet exposed: "+kv.first);cb.args.push_back(x.s);}T rt=typeOf(cb.ret);if(rt==T::PTR||rt==T::UTF8||rt==T::UTF16||rt==T::BYTES)throw std::runtime_error("v0.13 callback pointer/string returns are not yet exposed: "+kv.first);L->callbacks[lower(kv.first)]=cb;}
  if(auto*fs=jo(root,"functions");fs&&fs->k==J::OBJ)for(auto&kv:fs->o){auto&bucket=L->funcs[lower(kv.first)];if(kv.second.k==J::ARR){for(auto&spec:kv.second.a)bucket.push_back(parseFunction(kv.first,spec));}else bucket.push_back(parseFunction(kv.first,kv.second));if(bucket.empty())throw std::runtime_error("function has no signatures: "+kv.first);}
  return L;
}

std::string objectToken(RexxCallContext*c,RexxObjectPtr o){if(!c->IsString(o))throw std::runtime_error("Foreign Runtime native boundary requires pre-normalized Rexx string argument");auto rs=(RexxStringObject)o;const char*v=c->StringData(rs);size_t n=c->StringLength(rs);return v?std::string(v,n):std::string();}
uint64_t tokenId(const std::string&s,const std::string&prefix){if(s.rfind(prefix,0)!=0)return 0;return strtoull(s.c_str()+prefix.size(),nullptr,10);}
std::shared_ptr<BufferRecord> bufferRecord(uint64_t id){std::lock_guard<std::mutex>g(mu);auto it=buffers.find(id);if(it==buffers.end())throw std::runtime_error("foreign buffer handle not found or closed");return it->second;}
std::shared_ptr<ObjectRecord> objectRecord(uint64_t id){std::lock_guard<std::mutex>g(mu);auto it=objects.find(id);if(it==objects.end())throw std::runtime_error("foreign object handle not found or closed");return it->second;}
std::shared_ptr<StructRecord> structRecord(uint64_t id){std::lock_guard<std::mutex>g(mu);auto it=structs.find(id);if(it==structs.end())throw std::runtime_error("foreign struct handle not found or closed");return it->second;}
static bool structReachesImpl(const std::shared_ptr<StructRecord>&cur,const StructRecord*target,std::set<const StructRecord*>&seen){
  if(!cur)return false;
  if(cur.get()==target)return true;
  if(!seen.insert(cur.get()).second)return false;
  std::vector<std::shared_ptr<StructRecord>> children;
  {std::lock_guard<std::mutex>g(cur->stateMu);for(auto&kv:cur->structRefs)if(kv.second)children.push_back(kv.second);}
  for(auto&c:children)if(structReachesImpl(c,target,seen))return true;
  return false;
}
static bool structReaches(const std::shared_ptr<StructRecord>&cur,const StructRecord*target){std::set<const StructRecord*>seen;return structReachesImpl(cur,target,seen);}
std::shared_ptr<PointerArrayRecord> pointerArrayRecord(uint64_t id){std::lock_guard<std::mutex>g(mu);auto it=pointerArrays.find(id);if(it==pointerArrays.end())throw std::runtime_error("foreign pointer array handle not found or closed");return it->second;}
std::shared_ptr<HandleRecord> handleRecord(uint64_t id){std::lock_guard<std::mutex>g(mu);auto it=handles.find(id);if(it==handles.end())throw std::runtime_error("foreign handle not found or closed");return it->second;}
std::shared_ptr<StructArrayRecord> structArrayRecord(uint64_t id){std::lock_guard<std::mutex>g(mu);auto it=structArrays.find(id);if(it==structArrays.end())throw std::runtime_error("foreign struct array not found or closed");return it->second;}
std::shared_ptr<CallbackRecord> callbackRecord(uint64_t id){std::lock_guard<std::mutex>g(mu);auto it=callbackObjects.find(id);if(it==callbackObjects.end())throw std::runtime_error("foreign callback handle not found or closed");return it->second;}
struct CallbackActivation;
struct A {T t; int8_t i8=0;uint8_t u8=0;int32_t i32=0;uint32_t u32=0;int64_t i=0;uint64_t u=0;double d=0;std::string s;std::u16string s16;void*p=nullptr;void*outPtr=nullptr;uint64_t autoBufferId=0;std::shared_ptr<BufferRecord> autoBuffer;bool pointerToPointer=false;std::unique_ptr<BufferPin> bufferPin;std::unique_ptr<ObjectPin> objectPin;std::unique_ptr<StructPin> structPin;std::unique_ptr<PointerArrayPin> pointerArrayPin;std::unique_ptr<HandlePin> handlePin;std::unique_ptr<StructArrayPin> structArrayPin;std::shared_ptr<CallbackActivation> callbackActivation;A()=default;A(A&&)=default;A& operator=(A&&)=default;A(const A&)=delete;};
A argFrom(RexxCallContext*c,RexxObjectPtr o,T t){A a;a.t=t;std::string v=objectToken(c,o);if(auto hid=tokenId(v,"@foreign-handle:")){a.handlePin=std::make_unique<HandlePin>(handleRecord(hid));uint64_t hv=a.handlePin->value;switch(t){case T::I8:a.i8=(int8_t)hv;a.i32=a.i8;a.i=a.i8;return a;case T::U8:a.u8=(uint8_t)hv;a.u32=a.u8;a.u=a.u8;return a;case T::I16:case T::I32:a.i32=(int32_t)hv;a.i=a.i32;return a;case T::U16:case T::U32:a.u32=(uint32_t)hv;a.u=a.u32;return a;case T::I64:case T::IPTR:a.i=(int64_t)hv;return a;case T::U64:case T::UPTR:a.u=hv;return a;default:throw std::runtime_error("foreign handle used with non-integer parameter");}}switch(t){
case T::I8:{char*end=nullptr;errno=0;long x=strtol(v.c_str(),&end,0);if(errno||!end||*end||x<INT8_MIN||x>INT8_MAX)throw std::runtime_error("i8 argument out of range: "+v);a.i8=(int8_t)x;a.i32=a.i8;a.i=a.i8;break;}
case T::U8:{if(!v.empty()&&v[0]=='-')throw std::runtime_error("u8 argument out of range: "+v);char*end=nullptr;errno=0;unsigned long x=strtoul(v.c_str(),&end,0);if(errno||!end||*end||x>UINT8_MAX)throw std::runtime_error("u8 argument out of range: "+v);a.u8=(uint8_t)x;a.u32=a.u8;a.u=a.u8;break;}
case T::I16:case T::I32:a.i32=(int32_t)strtol(v.c_str(),nullptr,0);a.i=a.i32;break;case T::I64:case T::IPTR:a.i=strtoll(v.c_str(),nullptr,0);break;
case T::U16:case T::U32:a.u32=(uint32_t)strtoul(v.c_str(),nullptr,0);a.u=a.u32;break;case T::U64:case T::UPTR:a.u=(uint64_t)strtoull(v.c_str(),nullptr,0);break;
case T::F64:a.d=strtod(v.c_str(),nullptr);break;
case T::BOOL:{auto q=lower(v);a.i32=(q=="true"||q=="1");a.i=a.i32;break;}
case T::UTF8:a.s=v;break;case T::UTF16:a.s16=utf8to16(v);break;
case T::BYTES:{if(!c->IsString(o))throw std::runtime_error("bytes argument was not pre-normalized to Rexx string");RexxStringObject rs=(RexxStringObject)o;const char*data=c->StringData(rs);size_t n=c->StringLength(rs);a.s.assign(data,n);break;}
case T::PTR:{if(v=="@foreign-null")a.p=nullptr;else if(auto id=tokenId(v,"@foreign-buffer:")){a.bufferPin=std::make_unique<BufferPin>(bufferRecord(id));a.p=a.bufferPin->ptr;}else if(auto id=tokenId(v,"@foreign-object:")){a.objectPin=std::make_unique<ObjectPin>(objectRecord(id));a.p=a.objectPin->ptr;}else if(auto id=tokenId(v,"@foreign-struct:")){a.structPin=std::make_unique<StructPin>(structRecord(id));a.p=a.structPin->ptr;}else if(auto id=tokenId(v,"@foreign-pointer-array:")){a.pointerArrayPin=std::make_unique<PointerArrayPin>(pointerArrayRecord(id));a.p=a.pointerArrayPin->ptr;}else if(auto id=tokenId(v,"@foreign-struct-array:")){a.structArrayPin=std::make_unique<StructArrayPin>(structArrayRecord(id));a.p=a.structArrayPin->ptr;}else a.p=(void*)(uintptr_t)strtoull(v.c_str(),nullptr,0);break;}
default:break;}return a;}


void validateAddressSpace(RexxCallContext*c,RexxObjectPtr o,const ArgSpec&as){
  if(as.addressSpace=="any")return;
  std::string tok=objectToken(c,o);
  if(tok=="@foreign-null")return;
  std::string actual;
  if(auto id=tokenId(tok,"@foreign-object:")){auto r=objectRecord(id);std::lock_guard<std::mutex>g(r->stateMu);actual=r->addressSpace;}
  else if(tokenId(tok,"@foreign-buffer:")||tokenId(tok,"@foreign-struct:")||tokenId(tok,"@foreign-pointer-array:"))actual="host";
  else { if(as.addressSpace=="host")return; throw std::runtime_error("foreign argument address space requires managed resource: "+as.addressSpace); }
  if(actual!=as.addressSpace)throw std::runtime_error("foreign argument address space mismatch: expected "+as.addressSpace+", got "+actual);
}

RexxObjectPtr foreignObjectResult(RexxCallContext*,void*,const Function&,const std::shared_ptr<Lib>&);

/* Minimal libffi 3.x public ABI used only with runtime-loaded libffi.so.8.
   The x86-64 ffi_cif layout is stable across the qualified 3.4.x ABI.
   Other platforms fall back to the legacy fixed-arity dispatcher until a
   native libffi header-backed provider is qualified there. */
#if !defined(_WIN32) && defined(__x86_64__)
struct rf_ffi_type { size_t size; unsigned short alignment; unsigned short type; rf_ffi_type **elements; };
enum rf_ffi_status { RF_FFI_OK=0, RF_FFI_BAD_TYPEDEF, RF_FFI_BAD_ABI, RF_FFI_BAD_ARGTYPE };
using rf_ffi_abi=int;
struct rf_ffi_cif { rf_ffi_abi abi; unsigned nargs; rf_ffi_type **arg_types; rf_ffi_type *rtype; unsigned bytes; unsigned flags; };
struct LibFFI {
  void*h=nullptr;
  using Prep=rf_ffi_status(*)(rf_ffi_cif*,rf_ffi_abi,unsigned,rf_ffi_type*,rf_ffi_type**);
  using Call=void(*)(rf_ffi_cif*,void(*)(void),void*,void**); using ClosureAlloc=void*(*)(size_t,void**); using ClosureFree=void(*)(void*); using PrepClosure=rf_ffi_status(*)(void*,rf_ffi_cif*,void(*)(rf_ffi_cif*,void*,void**,void*),void*,void*);
  Prep prep=nullptr; Call call=nullptr; ClosureAlloc closureAlloc=nullptr; ClosureFree closureFree=nullptr; PrepClosure prepClosure=nullptr;
  rf_ffi_type *tv=nullptr,*tsi8=nullptr,*tui8=nullptr,*tsi16=nullptr,*tui16=nullptr,*tsi32=nullptr,*tui32=nullptr,*tsi64=nullptr,*tui64=nullptr,*tdouble=nullptr,*tptr=nullptr;
  LibFFI(){h=dlopen("libffi.so.8",RTLD_NOW|RTLD_LOCAL);if(!h)return;prep=(Prep)dlsym(h,"ffi_prep_cif");call=(Call)dlsym(h,"ffi_call");closureAlloc=(ClosureAlloc)dlsym(h,"ffi_closure_alloc");closureFree=(ClosureFree)dlsym(h,"ffi_closure_free");prepClosure=(PrepClosure)dlsym(h,"ffi_prep_closure_loc");tv=(rf_ffi_type*)dlsym(h,"ffi_type_void");tsi8=(rf_ffi_type*)dlsym(h,"ffi_type_sint8");tui8=(rf_ffi_type*)dlsym(h,"ffi_type_uint8");tsi16=(rf_ffi_type*)dlsym(h,"ffi_type_sint16");tui16=(rf_ffi_type*)dlsym(h,"ffi_type_uint16");tsi32=(rf_ffi_type*)dlsym(h,"ffi_type_sint32");tui32=(rf_ffi_type*)dlsym(h,"ffi_type_uint32");tsi64=(rf_ffi_type*)dlsym(h,"ffi_type_sint64");tui64=(rf_ffi_type*)dlsym(h,"ffi_type_uint64");tdouble=(rf_ffi_type*)dlsym(h,"ffi_type_double");tptr=(rf_ffi_type*)dlsym(h,"ffi_type_pointer");if(!prep||!call||!tv||!tsi8||!tui8||!tsi16||!tui16||!tsi32||!tui32||!tsi64||!tui64||!tdouble||!tptr){dlclose(h);h=nullptr;}}
  ~LibFFI(){if(h)dlclose(h);} bool available()const{return h!=nullptr;}
};
LibFFI& libffi(){static LibFFI f;return f;}
rf_ffi_type* ffiTypeFor(T t){auto&f=libffi();switch(t){case T::VOID:return f.tv;case T::I8:return f.tsi8;case T::U8:return f.tui8;case T::I16:return f.tsi16;case T::U16:return f.tui16;case T::I32:case T::BOOL:return f.tsi32;case T::U32:return f.tui32;case T::I64:case T::IPTR:return f.tsi64;case T::U64:case T::UPTR:return f.tui64;case T::F64:return f.tdouble;case T::UTF8:case T::UTF16:case T::BYTES:case T::PTR:return f.tptr;}return nullptr;}
struct CallbackActivation{RexxCallContext*c=nullptr;std::shared_ptr<CallbackRecord> rec;rf_ffi_cif cif{};std::vector<rf_ffi_type*> at;void*closure=nullptr;void*code=nullptr;std::thread::id owner;bool threadViolation=false;std::string error;~CallbackActivation(){if(closure&&libffi().closureFree)libffi().closureFree(closure);}};
static void zeroCallbackReturn(T t,void*ret){if(!ret)return;switch(t){case T::F64:*(double*)ret=0;break;case T::I8:case T::U8:*(uint8_t*)ret=0;break;case T::I16:case T::U16:*(uint16_t*)ret=0;break;case T::I32:case T::U32:case T::BOOL:*(uint32_t*)ret=0;break;case T::I64:case T::U64:case T::IPTR:case T::UPTR:*(uint64_t*)ret=0;break;default:break;}}
static RexxObjectPtr callbackArgToRexx(RexxCallContext*c,T t,void*p){switch(t){case T::I8:return c->Int64ToObject(*(int8_t*)p);case T::U8:return c->UnsignedInt64ToObject(*(uint8_t*)p);case T::I16:return c->Int64ToObject(*(int16_t*)p);case T::U16:return c->UnsignedInt64ToObject(*(uint16_t*)p);case T::I32:return c->Int64ToObject(*(int32_t*)p);case T::U32:return c->UnsignedInt64ToObject(*(uint32_t*)p);case T::I64:case T::IPTR:return c->Int64ToObject(*(int64_t*)p);case T::U64:case T::UPTR:return c->UnsignedInt64ToObject(*(uint64_t*)p);case T::F64:return c->DoubleToObject(*(double*)p);case T::BOOL:return c->Logical(*(int32_t*)p!=0);default:return c->Nil();}}
static void callbackThunk(rf_ffi_cif*,void*ret,void**args,void*user){auto*a=(CallbackActivation*)user;T rt=typeOf(a->rec->spec.ret);if(std::this_thread::get_id()!=a->owner){a->threadViolation=true;zeroCallbackReturn(rt,ret);return;}try{RexxArrayObject ra=a->c->NewArray(a->rec->spec.args.size());for(size_t i=0;i<a->rec->spec.args.size();++i)a->c->ArrayPut(ra,callbackArgToRexx(a->c,typeOf(a->rec->spec.args[i]),args[i]),i+1);RexxObjectPtr rv=a->c->SendMessage(a->rec->target,a->rec->method.c_str(),ra);const char*cv=a->c->ObjectToStringValue(rv);std::string v=cv?cv:"";switch(rt){case T::VOID:break;case T::I8:{long x=strtol(v.c_str(),nullptr,0);if(x<INT8_MIN||x>INT8_MAX)throw std::runtime_error("i8 callback return out of range");*(int8_t*)ret=(int8_t)x;break;}case T::U8:{if(!v.empty()&&v[0]=='-')throw std::runtime_error("u8 callback return out of range");unsigned long x=strtoul(v.c_str(),nullptr,0);if(x>UINT8_MAX)throw std::runtime_error("u8 callback return out of range");*(uint8_t*)ret=(uint8_t)x;break;}case T::I32:*(int32_t*)ret=(int32_t)strtol(v.c_str(),nullptr,0);break;case T::U32:*(uint32_t*)ret=(uint32_t)strtoul(v.c_str(),nullptr,0);break;case T::I64:case T::IPTR:*(int64_t*)ret=strtoll(v.c_str(),nullptr,0);break;case T::U64:case T::UPTR:*(uint64_t*)ret=strtoull(v.c_str(),nullptr,0);break;case T::F64:*(double*)ret=strtod(v.c_str(),nullptr);break;case T::BOOL:*(int32_t*)ret=(lower(v)=="true"||v=="1");break;default:zeroCallbackReturn(rt,ret);break;}}catch(...){a->error="ooRexx callback raised an unsupported native condition";zeroCallbackReturn(rt,ret);}}
static std::shared_ptr<CallbackActivation> activateCallback(RexxCallContext*c,const std::shared_ptr<CallbackRecord>&rec){auto&f=libffi();if(!f.available()||!f.closureAlloc||!f.closureFree||!f.prepClosure)throw std::runtime_error("libffi closure support unavailable");auto a=std::make_shared<CallbackActivation>();a->c=c;a->rec=rec;a->owner=std::this_thread::get_id();for(auto&t:rec->spec.args)a->at.push_back(ffiTypeFor(typeOf(t)));if(f.prep(&a->cif,2,(unsigned)a->at.size(),ffiTypeFor(typeOf(rec->spec.ret)),a->at.data())!=RF_FFI_OK)throw std::runtime_error("libffi could not prepare callback signature");a->closure=f.closureAlloc(256,&a->code);if(!a->closure)throw std::runtime_error("libffi could not allocate callback closure");if(f.prepClosure(a->closure,&a->cif,callbackThunk,a.get(),a->code)!=RF_FFI_OK)throw std::runtime_error("libffi could not prepare callback closure");return a;}
void* ffiArgAddress(A&a){switch(a.t){case T::I8:return &a.i8;case T::U8:return &a.u8;case T::I16:return &a.i32;case T::U16:return &a.u32;case T::I32:case T::BOOL:return &a.i32;case T::U32:return &a.u32;case T::I64:case T::IPTR:return &a.i;case T::U64:case T::UPTR:return &a.u;case T::F64:return &a.d;case T::UTF8:a.p=(void*)a.s.c_str();return &a.p;case T::UTF16:a.p=(void*)a.s16.c_str();return &a.p;case T::BYTES:a.p=(void*)a.s.data();return &a.p;case T::PTR:if(a.pointerToPointer)a.p=&a.outPtr;return &a.p;default:return nullptr;}}
thread_local int lastNativeErrno=0;
thread_local std::string lastNativeReturnText;
union FfiReturn { uint8_t u8; int8_t i8; uint64_t u64; int64_t i64; double d; void*p; };
RexxObjectPtr invokeLibFFI(RexxCallContext*c,void*p,const Function&fn,std::vector<A>&a,const std::vector<T>&ts,const std::shared_ptr<Lib>&L){auto&f=libffi();if(!f.available())throw std::runtime_error("libffi runtime unavailable");std::vector<rf_ffi_type*>atypes;std::vector<void*>avalues;atypes.reserve(ts.size());avalues.reserve(ts.size());for(size_t i=0;i<ts.size();++i){atypes.push_back(ffiTypeFor(ts[i]));avalues.push_back(ffiArgAddress(a[i]));}rf_ffi_type*rt=ffiTypeFor(typeOf(fn.ret));rf_ffi_cif cif{};/* x86-64 SysV libffi ABI: FFI_UNIX64 == 2 */if(f.prep(&cif,2,(unsigned)atypes.size(),rt,atypes.data())!=RF_FFI_OK)throw std::runtime_error("libffi could not prepare foreign signature");FfiReturn r{};T ft=typeOf(fn.ret);void*rp=ft==T::VOID?nullptr:&r;errno=0;f.call(&cif,(void(*)(void))p,rp,avalues.data());lastNativeErrno=errno;switch(ft){case T::VOID:lastNativeReturnText="0";break;case T::I8:lastNativeReturnText=std::to_string((int)r.i8);break;case T::U8:lastNativeReturnText=std::to_string((unsigned)r.u8);break;case T::I16:case T::I32:lastNativeReturnText=std::to_string((int32_t)r.i64);break;case T::U16:case T::U32:lastNativeReturnText=std::to_string((uint32_t)r.u64);break;case T::I64:case T::IPTR:lastNativeReturnText=std::to_string(r.i64);break;case T::U64:case T::UPTR:lastNativeReturnText=std::to_string(r.u64);break;case T::F64:{std::ostringstream q;q.precision(17);q<<r.d;lastNativeReturnText=q.str();break;}case T::BOOL:lastNativeReturnText=((int32_t)r.i64)?"1":"0";break;case T::UTF8:lastNativeReturnText=r.p?(const char*)r.p:"";break;case T::UTF16:lastNativeReturnText.clear();break;case T::PTR:lastNativeReturnText=std::to_string((uintptr_t)r.p);break;case T::BYTES:lastNativeReturnText.clear();break;}switch(ft){case T::VOID:return c->Nil();case T::I8:return c->Int64ToObject((int8_t)r.i8);case T::U8:return c->UnsignedInt64ToObject((uint8_t)r.u8);case T::I16:case T::I32:return c->Int64ToObject((int32_t)r.i64);case T::U16:case T::U32:return c->UnsignedInt64ToObject((uint32_t)r.u64);case T::I64:case T::IPTR:return c->Int64ToObject(r.i64);case T::U64:case T::UPTR:return c->UnsignedInt64ToObject(r.u64);case T::F64:return c->DoubleToObject(r.d);case T::BOOL:return c->Logical((int32_t)r.i64);case T::UTF8:{const char*q=(const char*)r.p;return q?c->String(q):c->Nil();}case T::UTF16:{const char16_t*q=(const char16_t*)r.p;if(!q)return c->Nil();auto u=utf16to8(q);return c->String(u.c_str());}case T::PTR:if(fn.returnsObject)return foreignObjectResult(c,r.p,fn,L);return c->UnsignedInt64ToObject((uintptr_t)r.p);case T::BYTES:break;}return c->Nil();}
void invokeHandleDestructor(const std::shared_ptr<HandleRecord>&r){if(!r||r->ownership!="owned"||r->destructor.empty())return;void*p=r->lib->dl.symbol(r->destructor);switch(typeOf(r->carrier)){case T::I8:((int32_t(*)(int8_t))p)((int8_t)r->value);break;case T::U8:((int32_t(*)(uint8_t))p)((uint8_t)r->value);break;case T::I16:((int32_t(*)(int16_t))p)((int16_t)r->value);break;case T::U16:((int32_t(*)(uint16_t))p)((uint16_t)r->value);break;case T::I32:((int32_t(*)(int32_t))p)((int32_t)r->value);break;case T::U32:((int32_t(*)(uint32_t))p)((uint32_t)r->value);break;case T::I64:case T::IPTR:((int32_t(*)(int64_t))p)((int64_t)r->value);break;case T::U64:case T::UPTR:((int32_t(*)(uint64_t))p)(r->value);break;default:throw std::runtime_error("unsupported foreign handle destructor carrier");}}
#else
struct LibFFI { bool available()const{return false;} }; LibFFI& libffi(){static LibFFI f;return f;}
void invokeHandleDestructor(const std::shared_ptr<HandleRecord>&r){if(!r||r->ownership!="owned"||r->destructor.empty())return;void*p=r->lib->dl.symbol(r->destructor);switch(typeOf(r->carrier)){case T::I8:((int32_t(*)(int8_t))p)((int8_t)r->value);break;case T::U8:((int32_t(*)(uint8_t))p)((uint8_t)r->value);break;case T::I16:((int32_t(*)(int16_t))p)((int16_t)r->value);break;case T::U16:((int32_t(*)(uint16_t))p)((uint16_t)r->value);break;case T::I32:((int32_t(*)(int32_t))p)((int32_t)r->value);break;case T::U32:((int32_t(*)(uint32_t))p)((uint32_t)r->value);break;case T::I64:case T::IPTR:((int32_t(*)(int64_t))p)((int64_t)r->value);break;case T::U64:case T::UPTR:((int32_t(*)(uint64_t))p)(r->value);break;default:throw std::runtime_error("unsupported foreign handle destructor carrier");}}
#endif

template<typename X> X av(const A&a); template<> int32_t av<int32_t>(const A&a){return (int32_t)a.i;}template<> uint32_t av<uint32_t>(const A&a){return (uint32_t)a.u;}template<> int64_t av<int64_t>(const A&a){return a.i;}template<> uint64_t av<uint64_t>(const A&a){return a.u;}template<> double av<double>(const A&a){return a.d;}template<> const char* av<const char*>(const A&a){return a.s.c_str();}template<> const char16_t* av<const char16_t*>(const A&a){return a.s16.c_str();}template<> void* av<void*>(const A&a){if(a.pointerToPointer)return (void*)&const_cast<A&>(a).outPtr;return a.t==T::BYTES?(void*)a.s.data():a.p;}
template<typename R,typename...X,size_t...I> R calli(void*p,const std::vector<A>&a,std::index_sequence<I...>){return ((R(*)(X...))p)(av<X>(a[I])...);}template<typename...X,size_t...I> void callv(void*p,const std::vector<A>&a,std::index_sequence<I...>){((void(*)(X...))p)(av<X>(a[I])...);}
RexxObjectPtr foreignObjectResult(RexxCallContext*c,void*ptr,const Function&fn,const std::shared_ptr<Lib>&L){if(!ptr)return c->Nil();uint64_t id;{std::lock_guard<std::mutex>g(mu);id=nextObjectId++;auto r=std::make_shared<ObjectRecord>();r->ptr=ptr;r->type=fn.objectType;r->ownership=fn.ownership;r->destructor=fn.destructor;r->destructorPointerDepth=fn.destructorPointerDepth;r->addressSpace=fn.addressSpace;r->byteLength=fn.byteLength;r->lib=L;objects[id]=r;}RexxArrayObject a=c->NewArray(6);c->ArrayPut(a,c->String("__foreign_object__"),1);c->ArrayPut(a,c->UnsignedInt64ToObject(id),2);c->ArrayPut(a,c->String(fn.objectType.c_str()),3);c->ArrayPut(a,c->String(fn.ownership.c_str()),4);c->ArrayPut(a,c->String(fn.addressSpace.c_str()),5);c->ArrayPut(a,c->UnsignedInt64ToObject(fn.byteLength),6);return a;}
template<typename...X> RexxObjectPtr doRet(RexxCallContext*c,void*p,const Function&fn,const std::vector<A>&a,const std::shared_ptr<Lib>&L){auto ix=std::index_sequence_for<X...>{};T r=typeOf(fn.ret);switch(r){case T::VOID:callv<X...>(p,a,ix);lastNativeReturnText="0";return c->Nil();case T::I8:{auto v=calli<int8_t,X...>(p,a,ix);lastNativeReturnText=std::to_string((int)v);return c->Int64ToObject(v);}case T::U8:{auto v=calli<uint8_t,X...>(p,a,ix);lastNativeReturnText=std::to_string((unsigned)v);return c->UnsignedInt64ToObject(v);}case T::I16:case T::I32:{auto v=calli<int32_t,X...>(p,a,ix);lastNativeReturnText=std::to_string(v);return c->Int64ToObject(v);}case T::U16:case T::U32:{auto v=calli<uint32_t,X...>(p,a,ix);lastNativeReturnText=std::to_string(v);return c->UnsignedInt64ToObject(v);}case T::I64:case T::IPTR:{auto v=calli<int64_t,X...>(p,a,ix);lastNativeReturnText=std::to_string(v);return c->Int64ToObject(v);}case T::U64:case T::UPTR:{auto v=calli<uint64_t,X...>(p,a,ix);lastNativeReturnText=std::to_string(v);return c->UnsignedInt64ToObject(v);}case T::F64:{auto v=calli<double,X...>(p,a,ix);std::ostringstream q;q.precision(17);q<<v;lastNativeReturnText=q.str();return c->DoubleToObject(v);}case T::BOOL:{auto v=calli<int32_t,X...>(p,a,ix);lastNativeReturnText=v?"1":"0";return c->Logical(v);}case T::UTF8:{const char*v=calli<const char*,X...>(p,a,ix);lastNativeReturnText=v?v:"";return v?c->String(v):c->Nil();}case T::UTF16:{const char16_t*v=calli<const char16_t*,X...>(p,a,ix);lastNativeReturnText.clear();if(!v)return c->Nil();auto u=utf16to8(v);return c->String(u.c_str());}case T::PTR:{void*v=calli<void*,X...>(p,a,ix);lastNativeReturnText=std::to_string((uintptr_t)v);if(fn.returnsObject)return foreignObjectResult(c,v,fn,L);return c->UnsignedInt64ToObject((uintptr_t)v);}case T::BYTES:break;}lastNativeReturnText.clear();return c->Nil();}
template<typename...X> RexxObjectPtr pick(RexxCallContext*c,void*p,const Function&fn,const std::vector<A>&a,const std::vector<T>&ts,size_t n,const std::shared_ptr<Lib>&L){if(n==ts.size())return doRet<X...>(c,p,fn,a,L);if constexpr(sizeof...(X)>=3){throw std::runtime_error("Foreign Runtime v0.14.0 fallback dispatcher supports at most three arguments");}else switch(ts[n]){case T::I8:case T::U8:throw std::runtime_error("8-bit scalar arguments require runtime libffi");case T::I16:case T::U16:throw std::runtime_error("16-bit scalar arguments require runtime libffi");case T::I32:return pick<X...,int32_t>(c,p,fn,a,ts,n+1,L);case T::U32:return pick<X...,uint32_t>(c,p,fn,a,ts,n+1,L);case T::I64:case T::IPTR:return pick<X...,int64_t>(c,p,fn,a,ts,n+1,L);case T::U64:case T::UPTR:return pick<X...,uint64_t>(c,p,fn,a,ts,n+1,L);case T::F64:return pick<X...,double>(c,p,fn,a,ts,n+1,L);case T::BOOL:return pick<X...,int32_t>(c,p,fn,a,ts,n+1,L);case T::UTF8:return pick<X...,const char*>(c,p,fn,a,ts,n+1,L);case T::UTF16:return pick<X...,const char16_t*>(c,p,fn,a,ts,n+1,L);case T::PTR:case T::BYTES:return pick<X...,void*>(c,p,fn,a,ts,n+1,L);default:throw std::runtime_error("void argument invalid");}}
RexxObjectPtr fail(RexxCallContext*c,const std::string&m){c->RaiseException1(Rexx_Error_Incorrect_call_user_defined,c->String(m.c_str()));return c->Nil();}
std::string normalizedConstant(const Constant&z){auto t=typeOf(z.datatype);if(t==T::UPTR){if(!z.value.empty()&&z.value[0]=='-'){intptr_t x=(intptr_t)strtoll(z.value.c_str(),nullptr,0);std::ostringstream q;q<<(uint64_t)(uintptr_t)x;return q.str();}}return z.value;}
}

extern "C" {
struct RexxForeignBufferExportV1 { void *data; size_t size; int readonly; void *token; };
int rexx_foreign_buffer_export_acquire_v1(uint64_t id, RexxForeignBufferExportV1 *out) noexcept {
  if(!out) return -2;
  try {
    auto *pin=new BufferPin(bufferRecord(id));
    out->data=pin->ptr; out->size=pin->r->data.size(); out->readonly=0; out->token=pin;
    return 0;
  } catch(...) { out->data=nullptr; out->size=0; out->readonly=1; out->token=nullptr; return -1; }
}
void rexx_foreign_buffer_export_release_v1(void *token) noexcept { delete static_cast<BufferPin*>(token); }
extern "C" uint64_t rexx_foreign_buffer_import_v1(void* data,size_t size,int readonly,void* token,ExternalBufferReleaseV1 release) noexcept {
  try {
    if(!data && size) return 0;
    auto r=std::make_shared<BufferRecord>(); r->externalPtr=data; r->externalSize=size; r->readonly=readonly!=0; r->externalToken=token; r->externalRelease=release;
    std::lock_guard<std::mutex>g(mu); uint64_t id=nextBufferId++; buffers[id]=r; return id;
  } catch(...) { return 0; }
}

/* Provider-neutral tensor descriptor ABI v1.  Shape/stride arrays are copied on import;
   the data pointer remains provider-owned and is protected by the release token. */
struct RexxForeignTensorImportV1 {
  void *data;
  size_t byte_size;
  int readonly;
  int device_type;
  int device_id;
  int dtype_code;      /* DLPack: int=0,uint=1,float=2,bfloat=4,complex=5,bool=6 */
  int dtype_bits;
  int dtype_lanes;
  size_t ndim;
  const int64_t *shape;
  const int64_t *strides_bytes;
  void *token;
  ExternalBufferReleaseV1 release;
};
struct RexxForeignTensorExportV1 {
  void *data;
  size_t byte_size;
  int readonly;
  int device_type;
  int device_id;
  int dtype_code;
  int dtype_bits;
  int dtype_lanes;
  size_t ndim;
  const int64_t *shape;
  const int64_t *strides_bytes;
  void *token;
};
struct TensorRecordV1 {
  void *data=nullptr; size_t byteSize=0; bool readonly=false;
  int deviceType=0,deviceId=0,dtypeCode=0,dtypeBits=0,dtypeLanes=1;
  std::vector<int64_t> shape,strides;
  std::string executionProvider; uint64_t streamHandle=0,fenceHandle=0; int syncPolicy=0,affinityKind=0;
  void *providerToken=nullptr; ExternalBufferReleaseV1 release=nullptr;
  std::mutex mu; std::condition_variable cv; size_t pins=0; bool closing=false;
  ~TensorRecordV1(){ if(release&&providerToken) release(providerToken); }
};
std::mutex tensorMu; std::map<uint64_t,std::shared_ptr<TensorRecordV1>> tensors; uint64_t nextTensorId=1;
struct TensorPinV1 { std::shared_ptr<TensorRecordV1> rec; explicit TensorPinV1(std::shared_ptr<TensorRecordV1> r):rec(std::move(r)){} ~TensorPinV1(){if(!rec)return;std::lock_guard<std::mutex>g(rec->mu);if(rec->pins)rec->pins--;rec->cv.notify_all();} };
extern "C" uint64_t rexx_foreign_tensor_import_v1(const RexxForeignTensorImportV1 *in) noexcept {
  try {
    if(!in || !in->data || in->dtype_bits<=0 || in->dtype_lanes<=0) return 0;
    if(in->ndim && (!in->shape || !in->strides_bytes)) return 0;
    auto r=std::make_shared<TensorRecordV1>(); r->data=in->data;r->byteSize=in->byte_size;r->readonly=in->readonly!=0;
    r->deviceType=in->device_type;r->deviceId=in->device_id;r->dtypeCode=in->dtype_code;r->dtypeBits=in->dtype_bits;r->dtypeLanes=in->dtype_lanes;
    r->providerToken=in->token;r->release=in->release;
    if(in->ndim){r->shape.assign(in->shape,in->shape+in->ndim);r->strides.assign(in->strides_bytes,in->strides_bytes+in->ndim);}
    std::lock_guard<std::mutex>g(tensorMu);uint64_t id=nextTensorId++;tensors[id]=r;return id;
  } catch(...) { return 0; }
}
extern "C" int rexx_foreign_tensor_export_acquire_v1(uint64_t id,RexxForeignTensorExportV1 *out) noexcept {
  try {
    if(!out) return -1;
    std::shared_ptr<TensorRecordV1> r;
    {std::lock_guard<std::mutex>g(tensorMu);auto it=tensors.find(id);if(it==tensors.end())return -2;r=it->second;}
    {std::lock_guard<std::mutex>g(r->mu);if(r->closing)return -3;r->pins++;}
    auto *pin=new TensorPinV1(r);out->data=r->data;out->byte_size=r->byteSize;out->readonly=r->readonly?1:0;out->device_type=r->deviceType;out->device_id=r->deviceId;
    out->dtype_code=r->dtypeCode;out->dtype_bits=r->dtypeBits;out->dtype_lanes=r->dtypeLanes;out->ndim=r->shape.size();out->shape=r->shape.data();out->strides_bytes=r->strides.data();out->token=pin;return 0;
  } catch(...) { return -9; }
}
extern "C" void rexx_foreign_tensor_export_release_v1(void *token) noexcept { delete static_cast<TensorPinV1*>(token); }
extern "C" int rexx_foreign_tensor_close_v1(uint64_t id) noexcept {
  try {std::shared_ptr<TensorRecordV1>r;{std::lock_guard<std::mutex>g(tensorMu);auto it=tensors.find(id);if(it==tensors.end())return 0;r=it->second;tensors.erase(it);}std::unique_lock<std::mutex>lk(r->mu);r->closing=true;r->cv.wait(lk,[&]{return r->pins==0;});lk.unlock();r.reset();return 0;}catch(...){return -1;}
}

/* Tensor descriptor ABI v2: v1 storage/type metadata plus opaque execution context.
   v2 does not authorize CPU dereference of device memory; consumers must interpret
   device_type and synchronization policy before touching data. */
struct RexxForeignTensorImportV2 {
  void *data; size_t byte_size; int readonly; int device_type; int device_id;
  int dtype_code; int dtype_bits; int dtype_lanes; size_t ndim;
  const int64_t *shape; const int64_t *strides_bytes;
  void *token; ExternalBufferReleaseV1 release;
  const char *execution_provider; uint64_t stream_handle; uint64_t fence_handle;
  int sync_policy;       /* 0=synchronous/none, 1=stream-ordered, 2=explicit-fence */
  int affinity_kind;     /* 0=none, 1=thread, 2=context */
};
struct RexxForeignTensorExportV2 {
  void *data; size_t byte_size; int readonly; int device_type; int device_id;
  int dtype_code; int dtype_bits; int dtype_lanes; size_t ndim;
  const int64_t *shape; const int64_t *strides_bytes; void *token;
  const char *execution_provider; uint64_t stream_handle; uint64_t fence_handle;
  int sync_policy; int affinity_kind;
};
extern "C" uint64_t rexx_foreign_tensor_import_v2(const RexxForeignTensorImportV2 *in) noexcept {
  try {
    if(!in || !in->data || in->dtype_bits<=0 || in->dtype_lanes<=0) return 0;
    if(in->ndim && (!in->shape || !in->strides_bytes)) return 0;
    if(in->sync_policy<0 || in->sync_policy>2 || in->affinity_kind<0 || in->affinity_kind>2) return 0;
    auto r=std::make_shared<TensorRecordV1>();
    r->data=in->data; r->byteSize=in->byte_size; r->readonly=in->readonly!=0;
    r->deviceType=in->device_type; r->deviceId=in->device_id; r->dtypeCode=in->dtype_code; r->dtypeBits=in->dtype_bits; r->dtypeLanes=in->dtype_lanes;
    r->providerToken=in->token; r->release=in->release;
    if(in->ndim){r->shape.assign(in->shape,in->shape+in->ndim);r->strides.assign(in->strides_bytes,in->strides_bytes+in->ndim);}
    if(in->execution_provider) r->executionProvider=in->execution_provider;
    r->streamHandle=in->stream_handle; r->fenceHandle=in->fence_handle; r->syncPolicy=in->sync_policy; r->affinityKind=in->affinity_kind;
    std::lock_guard<std::mutex>g(tensorMu); uint64_t id=nextTensorId++; tensors[id]=r; return id;
  } catch(...) { return 0; }
}
extern "C" int rexx_foreign_tensor_export_acquire_v2(uint64_t id,RexxForeignTensorExportV2 *out) noexcept {
  try {
    if(!out) return -1;
    std::shared_ptr<TensorRecordV1> r;
    {std::lock_guard<std::mutex>g(tensorMu);auto it=tensors.find(id);if(it==tensors.end())return -2;r=it->second;}
    {std::lock_guard<std::mutex>g(r->mu);if(r->closing)return -3;r->pins++;}
    auto *pin=new TensorPinV1(r); out->data=r->data; out->byte_size=r->byteSize; out->readonly=r->readonly?1:0; out->device_type=r->deviceType; out->device_id=r->deviceId;
    out->dtype_code=r->dtypeCode; out->dtype_bits=r->dtypeBits; out->dtype_lanes=r->dtypeLanes; out->ndim=r->shape.size(); out->shape=r->shape.data(); out->strides_bytes=r->strides.data(); out->token=pin;
    out->execution_provider=r->executionProvider.c_str(); out->stream_handle=r->streamHandle; out->fence_handle=r->fenceHandle; out->sync_policy=r->syncPolicy; out->affinity_kind=r->affinityKind; return 0;
  } catch(...) { return -9; }
}
extern "C" void rexx_foreign_tensor_export_release_v2(void *token) noexcept { delete static_cast<TensorPinV1*>(token); }

}

RexxRoutine1(RexxObjectPtr, rexx_foreign_load_definition, CSTRING, path){try{auto L=load(path);std::lock_guard<std::mutex>g(mu);uint64_t id=nextId++;libs[id]=L;defaultId=id;return context->UnsignedInt64ToObject(id);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_close, uint64_t, id){std::lock_guard<std::mutex>g(mu);libs.erase(id);if(defaultId==id)defaultId=0;return context->Nil();}
RexxRoutine2(RexxObjectPtr, rexx_foreign_constant_raw, OPTIONAL_uint64_t, id, CSTRING, name){try{if(argumentOmitted(1))id=defaultId;std::shared_ptr<Lib>L;{std::lock_guard<std::mutex>g(mu);auto it=libs.find(id);if(it==libs.end())throw std::runtime_error("foreign library handle not found");L=it->second;}auto it=L->constants.find(name);if(it==L->constants.end())throw std::runtime_error(std::string("foreign constant not found: ")+name);RexxArrayObject a=context->NewArray(2);context->ArrayPut(a,context->String(it->second.datatype.c_str()),1);auto v=normalizedConstant(it->second);context->ArrayPut(a,context->String(v.c_str()),2);return a;}catch(const std::exception&e){return fail(context,e.what());}}

std::shared_ptr<Lib> libraryById(uint64_t id){std::lock_guard<std::mutex>g(mu);auto it=libs.find(id);if(it==libs.end())throw std::runtime_error("foreign library handle not found");return it->second;}
bool numericText(const std::string&s){if(s.empty())return false;char*e=nullptr;errno=0;std::strtod(s.c_str(),&e);return errno==0&&e&&*e=='\0';}
int compatibilityScore(RexxCallContext*c,RexxObjectPtr o,const ArgSpec&as){std::string tok=objectToken(c,o);T t=typeOf(as.type);if(tok=="@foreign-out")return (as.direction=="out"&&t==T::PTR&&((as.pointerDepth==1&&as.size>0)||(as.pointerDepth==2&&!as.objectType.empty())))?140:-1;if(tok=="@foreign-null")return (t==T::PTR||t==T::UTF8||t==T::UTF16||t==T::BYTES)?100:-1;if(tokenId(tok,"@foreign-object:")){if(t!=T::PTR)return -1;if(as.objectType.empty())return 90;uint64_t oid=tokenId(tok,"@foreign-object:");auto rec=objectRecord(oid);std::lock_guard<std::mutex>g(rec->stateMu);return !rec->closing&&lower(rec->type)==lower(as.objectType)?120:-1;}if(tokenId(tok,"@foreign-buffer:"))return t==T::PTR?110:-1;if(tokenId(tok,"@foreign-struct:"))return t==T::PTR?115:-1;if(tokenId(tok,"@foreign-pointer-array:"))return t==T::PTR?115:-1;if(tokenId(tok,"@foreign-struct-array:"))return t==T::PTR?115:-1;if(tokenId(tok,"@foreign-handle:"))return (t==T::I8||t==T::U8||t==T::I16||t==T::U16||t==T::I32||t==T::U32||t==T::I64||t==T::U64||t==T::IPTR||t==T::UPTR)?125:-1;if(auto id=tokenId(tok,"@foreign-callback:")){if(t!=T::PTR||as.callbackType.empty())return -1;auto r=callbackRecord(id);return lower(r->spec.name)==lower(as.callbackType)?130:-1;}switch(t){case T::UTF8:case T::UTF16:case T::BYTES:return 50;case T::PTR:return -1;case T::F64:return numericText(tok)?70:-1;case T::I8:case T::U8:case T::I16:case T::U16:case T::I32:case T::U32:case T::I64:case T::U64:case T::IPTR:case T::UPTR:case T::BOOL:return numericText(tok)?80:-1;default:return 0;}}
bool autoOut(const ArgSpec&as){return as.direction=="out"&&typeOf(as.type)==T::PTR&&((as.pointerDepth==1&&as.size>0)||(as.pointerDepth==2&&!as.objectType.empty()));}
const Function& resolveFunction(RexxCallContext*c,const std::vector<Function>&cands,RexxArrayObject arr){size_t n=c->ArraySize(arr);const Function*best=nullptr;int bestScore=-1;bool tie=false;for(const auto&fn:cands){if(n>fn.args.size())continue;bool ok=true;for(size_t i=n;i<fn.args.size();++i)if(!autoOut(fn.args[i])){ok=false;break;}if(!ok)continue;int score=0;for(size_t i=0;i<n;++i){int q=compatibilityScore(c,c->ArrayAt(arr,i+1),fn.args[i]);if(q<0){ok=false;break;}score+=q;}if(!ok)continue;score+=(int)(fn.args.size()-n);if(score>bestScore){best=&fn;bestScore=score;tie=false;}else if(score==bestScore)tie=true;}if(!best)throw std::runtime_error("no foreign signature matches supplied inputs");if(tie)throw std::runtime_error("ambiguous foreign signatures for supplied inputs");return *best;}
RexxArrayObject signatureArray(RexxCallContext*c,const Function&fn){RexxArrayObject a=c->NewArray(15);c->ArrayPut(a,c->String(fn.logicalName.c_str()),1);c->ArrayPut(a,c->String(fn.symbol.c_str()),2);RexxArrayObject inputs=c->NewArray(fn.args.size());for(size_t i=0;i<fn.args.size();++i){RexxArrayObject q=c->NewArray(17);c->ArrayPut(q,c->String(fn.args[i].type.c_str()),1);c->ArrayPut(q,c->String(fn.args[i].direction.c_str()),2);c->ArrayPut(q,c->String(fn.args[i].objectType.c_str()),3);c->ArrayPut(q,c->String(fn.args[i].name.c_str()),4);c->ArrayPut(q,c->UnsignedInt64ToObject(fn.args[i].size),5);c->ArrayPut(q,c->String(fn.args[i].resultType.c_str()),6);c->ArrayPut(q,c->Int64ToObject(fn.args[i].pointerDepth),7);c->ArrayPut(q,c->String(fn.args[i].ownership.c_str()),8);c->ArrayPut(q,c->String(fn.args[i].destructor.c_str()),9);c->ArrayPut(q,c->Int64ToObject(fn.args[i].destructorPointerDepth),10);c->ArrayPut(q,c->String(fn.args[i].addressSpace.c_str()),11);c->ArrayPut(q,c->UnsignedInt64ToObject(fn.args[i].byteLength),12);c->ArrayPut(q,c->String(fn.args[i].callbackType.c_str()),13);c->ArrayPut(q,c->String(fn.args[i].resourceType.c_str()),14);c->ArrayPut(q,c->String(fn.args[i].resourceCarrier.c_str()),15);c->ArrayPut(q,c->String(fn.args[i].invalid.c_str()),16);c->ArrayPut(q,c->String(fn.args[i].outputsOnReturn.c_str()),17);c->ArrayPut(inputs,q,i+1);}c->ArrayPut(a,inputs,3);c->ArrayPut(a,c->String(fn.ret.c_str()),4);c->ArrayPut(a,c->String(fn.objectType.c_str()),5);c->ArrayPut(a,c->String(fn.ownership.c_str()),6);c->ArrayPut(a,c->String(fn.callingConvention.c_str()),7);c->ArrayPut(a,c->String(fn.destructor.c_str()),8);c->ArrayPut(a,c->Int64ToObject(fn.destructorPointerDepth),9);c->ArrayPut(a,c->String(fn.addressSpace.c_str()),10);c->ArrayPut(a,c->UnsignedInt64ToObject(fn.byteLength),11);c->ArrayPut(a,fn.captureErrno?c->True():c->False(),12);c->ArrayPut(a,c->String(fn.resourceType.c_str()),13);c->ArrayPut(a,c->String(fn.resourceCarrier.c_str()),14);c->ArrayPut(a,c->String(fn.invalid.c_str()),15);return a;}
RexxRoutine2(RexxObjectPtr, rexx_foreign_function_exists, uint64_t, id, CSTRING, name){try{auto L=libraryById(id);return L->funcs.find(lower(name))!=L->funcs.end()?context->True():context->False();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_library_info, uint64_t, id){try{auto L=libraryById(id);RexxArrayObject a=context->NewArray(8);context->ArrayPut(a,context->String(L->provider.c_str()),1);context->ArrayPut(a,context->String(L->requested.c_str()),2);context->ArrayPut(a,context->String(L->path.c_str()),3);context->ArrayPut(a,context->String(L->definitionPath.c_str()),4);context->ArrayPut(a,context->String(L->threadingMode.c_str()),5);context->ArrayPut(a,context->String(L->affinity.c_str()),6);context->ArrayPut(a,context->String(L->abiProfile.c_str()),7);context->ArrayPut(a,L->abiQualified?context->True():context->False(),8);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_method_names, uint64_t, id){try{auto L=libraryById(id);RexxArrayObject a=context->NewArray(L->funcs.size());size_t i=1;for(const auto&kv:L->funcs)context->ArrayPut(a,context->String(kv.second.front().logicalName.c_str()),i++);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr, rexx_foreign_method_signatures, uint64_t, id, CSTRING, name){try{auto L=libraryById(id);auto it=L->funcs.find(lower(name));if(it==L->funcs.end())throw std::runtime_error(std::string("foreign method not found: ")+name);RexxArrayObject a=context->NewArray(it->second.size());for(size_t i=0;i<it->second.size();++i)context->ArrayPut(a,signatureArray(context,it->second[i]),i+1);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr, rexx_foreign_method_by_inputs, uint64_t, id, CSTRING, name, RexxArrayObject, arr){try{auto L=libraryById(id);auto it=L->funcs.find(lower(name));if(it==L->funcs.end())throw std::runtime_error(std::string("foreign method not found: ")+name);return signatureArray(context,resolveFunction(context,it->second,arr));}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr, rexx_foreign_method_by_inputs_index, uint64_t, id, CSTRING, name, RexxArrayObject, arr){try{auto L=libraryById(id);auto it=L->funcs.find(lower(name));if(it==L->funcs.end())throw std::runtime_error(std::string("foreign method not found: ")+name);const Function&fn=resolveFunction(context,it->second,arr);size_t index=(size_t)(&fn-it->second.data())+1;return context->UnsignedInt64ToObject(index);}catch(const std::exception&e){return fail(context,e.what());}}
RexxObjectPtr foreignHandleResult(RexxCallContext*c,uint64_t value,const std::string&type,const std::string&carrier,const std::string&ownership,const std::string&destructor,const std::shared_ptr<Lib>&L){uint64_t id;auto r=std::make_shared<HandleRecord>();r->value=value;r->type=type;r->carrier=carrier;r->ownership=ownership;r->destructor=destructor;r->lib=L;{std::lock_guard<std::mutex>g(mu);id=nextHandleId++;handles[id]=r;}RexxArrayObject a=c->NewArray(6);c->ArrayPut(a,c->String("__foreign_handle__"),1);c->ArrayPut(a,c->UnsignedInt64ToObject(id),2);c->ArrayPut(a,c->String(type.c_str()),3);c->ArrayPut(a,c->String(carrier.c_str()),4);c->ArrayPut(a,c->String(ownership.c_str()),5);c->ArrayPut(a,c->UnsignedInt64ToObject(value),6);return a;}
bool outputValid(const ArgSpec&as,const std::string&ret){if(as.outputsOnReturn=="always")return true;long long v=strtoll(ret.c_str(),nullptr,0);if(as.outputsOnReturn=="zero")return v==0;if(as.outputsOnReturn=="nonnegative")return v>=0;if(as.outputsOnReturn=="positive")return v>0;return false;}
uint64_t readResourceValue(const BufferRecord&r,const std::string&carrier){auto t=typeOf(carrier);if(t==T::I16){int16_t v=0;memcpy(&v,bufferData(r),2);return (uint64_t)(int64_t)v;}if(t==T::U16){uint16_t v=0;memcpy(&v,bufferData(r),2);return v;}if(t==T::I32){int32_t v=0;memcpy(&v,bufferData(r),4);return (uint64_t)(int64_t)v;}if(t==T::U32){uint32_t v=0;memcpy(&v,bufferData(r),4);return v;}if(t==T::I64||t==T::IPTR){int64_t v=0;memcpy(&v,bufferData(r),8);return (uint64_t)v;}uint64_t v=0;memcpy(&v,bufferData(r),8);return v;}
RexxRoutine3(RexxObjectPtr, rexx_foreign_invoke, uint64_t, id, CSTRING, name, RexxArrayObject, arr){
 try{
  auto L=libraryById(id);auto fi=L->funcs.find(lower(name));if(fi==L->funcs.end())throw std::runtime_error(std::string("foreign function not found: ")+name);
  const Function&fn=resolveFunction(context,fi->second,arr);void*p=L->dl.symbol(fn.symbol);
  std::vector<A>a;std::vector<T>ts;std::vector<bool>generated(fn.args.size(),false);a.reserve(fn.args.size());ts.reserve(fn.args.size());
  size_t supplied=context->ArraySize(arr);bool hasAuto=false;
  for(size_t i=0;i<fn.args.size();++i){
   T t=typeOf(fn.args[i].type);ts.push_back(t);const auto&as=fn.args[i];
   bool explicitOut=false;
   if(i<supplied){auto o=context->ArrayAt(arr,i+1);explicitOut=(objectToken(context,o)=="@foreign-out");if(!explicitOut){validateAddressSpace(context,o,as);std::string tok=objectToken(context,o);if(!as.callbackType.empty()){auto cid=tokenId(tok,"@foreign-callback:");if(!cid)throw std::runtime_error("callback parameter requires ForeignCallback");auto cr=callbackRecord(cid);if(lower(cr->spec.name)!=lower(as.callbackType))throw std::runtime_error("foreign callback signature mismatch");A x;x.t=T::PTR;x.callbackActivation=activateCallback(context,cr);x.p=x.callbackActivation->code;a.push_back(std::move(x));}else {A x=argFrom(context,o,t);if(x.bufferPin && x.bufferPin->r->readonly && (as.direction=="out"||as.direction=="inout"))throw std::runtime_error("foreign buffer is readonly for writable parameter");a.push_back(std::move(x));}continue;}}
   if(!autoOut(as))throw std::runtime_error(explicitOut?"foreign output placeholder requires safely-described out parameter":"missing non-output foreign argument");
   A x;x.t=t;hasAuto=true;generated[i]=true;
   if(as.pointerDepth==2)x.pointerToPointer=true;
   else{uint64_t bid;auto r=std::make_shared<BufferRecord>();r->data.resize(as.size);{std::lock_guard<std::mutex>g(mu);bid=nextBufferId++;buffers[bid]=r;}x.autoBufferId=bid;x.autoBuffer=r;x.bufferPin=std::make_unique<BufferPin>(r);x.p=x.bufferPin->ptr;}
   a.push_back(std::move(x));
  }
  RexxObjectPtr rv; if(L->threadingMode=="serialized"){std::lock_guard<std::mutex> callGuard(L->invokeMu);rv=libffi().available()?invokeLibFFI(context,p,fn,a,ts,L):pick(context,p,fn,a,ts,0,L);}else rv=libffi().available()?invokeLibFFI(context,p,fn,a,ts,L):pick(context,p,fn,a,ts,0,L);
  if(fn.returnsHandle){std::string raw=lastNativeReturnText;if(raw!=fn.invalid){uint64_t hv=(uint64_t)strtoll(raw.c_str(),nullptr,0);rv=foreignHandleResult(context,hv,fn.resourceType,fn.resourceCarrier,fn.ownership,fn.destructor,L);}}
  for(auto&x:a)if(x.callbackActivation){if(x.callbackActivation->threadViolation)throw std::runtime_error("foreign callback attempted ooRexx entry from a non-calling thread");if(!x.callbackActivation->error.empty())throw std::runtime_error(x.callbackActivation->error);}
  if(!hasAuto&&!fn.captureErrno)return rv;
  size_t outCount=0;for(bool x:generated)if(x)++outCount;RexxArrayObject outs=context->NewArray(outCount);size_t oi=1;
  std::string rvText=lastNativeReturnText;for(size_t i=0;i<fn.args.size();++i)if(generated[i]){const auto&as=fn.args[i];if(!outputValid(as,rvText)){if(a[i].autoBufferId){std::lock_guard<std::mutex>g(mu);buffers.erase(a[i].autoBufferId);}continue;}RexxArrayObject q=context->NewArray(5);context->ArrayPut(q,context->String(as.name.c_str()),1);if(as.pointerDepth==2){context->ArrayPut(q,context->String("object"),2);Function tmp;tmp.objectType=as.objectType;tmp.ownership=as.ownership;tmp.destructor=as.destructor;tmp.destructorPointerDepth=as.destructorPointerDepth;tmp.addressSpace=as.addressSpace;tmp.byteLength=as.byteLength;auto obj=foreignObjectResult(context,a[i].outPtr,tmp,L);context->ArrayPut(q,obj,3);}else if(as.resultType=="handle"){uint64_t hv=readResourceValue(*a[i].autoBuffer,as.resourceCarrier);std::string hs=std::to_string((int64_t)hv);if(hs==as.invalid){std::lock_guard<std::mutex>g(mu);buffers.erase(a[i].autoBufferId);continue;}context->ArrayPut(q,context->String("handle"),2);auto h=foreignHandleResult(context,hv,as.resourceType,as.resourceCarrier,as.ownership,as.destructor,L);context->ArrayPut(q,h,3);{std::lock_guard<std::mutex>g(mu);buffers.erase(a[i].autoBufferId);}}else{context->ArrayPut(q,context->String(as.resultType.c_str()),2);context->ArrayPut(q,context->UnsignedInt64ToObject(a[i].autoBufferId),3);context->ArrayPut(q,context->UnsignedInt64ToObject(as.size),4);}context->ArrayPut(outs,q,oi++);}
  RexxArrayObject result=context->NewArray(5);context->ArrayPut(result,context->String("__foreign_result__"),1);context->ArrayPut(result,rv,2);context->ArrayPut(result,outs,3);context->ArrayPut(result,context->Int64ToObject(fn.captureErrno?lastNativeErrno:0),4);context->ArrayPut(result,context->String(fn.captureErrno?strerror(lastNativeErrno):""),5);return result;
 }catch(const std::exception&e){return fail(context,e.what());}
}

RexxRoutine1(RexxObjectPtr, rexx_foreign_buffer_create, uint64_t, size){try{uint64_t id;auto r=std::make_shared<BufferRecord>();r->data.resize((size_t)size);{std::lock_guard<std::mutex>g(mu);id=nextBufferId++;buffers[id]=r;}return context->UnsignedInt64ToObject(id);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_buffer_close, uint64_t, id){try{std::shared_ptr<BufferRecord>r;{std::lock_guard<std::mutex>g(mu);auto it=buffers.find(id);if(it==buffers.end())return context->Nil();r=it->second;buffers.erase(it);}std::unique_lock<std::mutex>g(r->stateMu);r->closing=true;r->cv.wait(g,[&]{return r->active==0;});auto rel=r->externalRelease;void*tok=r->externalToken;r->externalRelease=nullptr;r->externalToken=nullptr;r->externalPtr=nullptr;r->externalSize=0;r->data.clear();g.unlock();if(rel)rel(tok);return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_buffer_size, uint64_t, id){try{auto r=bufferRecord(id);std::lock_guard<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");return context->UnsignedInt64ToObject(bufferSize(*r));}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_buffer_readonly, uint64_t, id){try{auto r=bufferRecord(id);std::lock_guard<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");return r->readonly?context->True():context->False();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_buffer_hex, uint64_t, id){try{auto r=bufferRecord(id);std::lock_guard<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");std::ostringstream q;q<<std::hex<<std::setfill('0');const uint8_t*p=(const uint8_t*)bufferData(*r);for(size_t i=0;i<bufferSize(*r);++i)q<<std::setw(2)<<(unsigned)p[i];auto s=q.str();return context->String(s.c_str());}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_buffer_bytes, uint64_t, id){try{auto r=bufferRecord(id);std::lock_guard<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");return context->String((const char*)bufferData(*r),bufferSize(*r));}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_buffer_u32, uint64_t, id){try{auto r=bufferRecord(id);std::lock_guard<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");if(bufferSize(*r)<4)throw std::runtime_error("foreign buffer too small for u32");uint32_t v;memcpy(&v,bufferData(*r),4);return context->UnsignedInt64ToObject(v);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr, rexx_foreign_buffer_get_bytes, uint64_t, id, uint64_t, offset, uint64_t, size){try{
  auto r=bufferRecord(id);std::unique_lock<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");r->cv.wait(g,[&]{return r->active==0||r->closing;});if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");size_t n=bufferSize(*r);if(offset>n||size>n-offset)throw std::runtime_error("foreign buffer getBytes range out of bounds");const char*p=(const char*)bufferData(*r);return context->String(p?(p+(size_t)offset):"",(size_t)size);
}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr, rexx_foreign_buffer_put_bytes, uint64_t, id, uint64_t, offset, RexxObjectPtr, value){try{
  auto r=bufferRecord(id);if(!context->IsString(value))throw std::runtime_error("ForeignBuffer putBytes requires a pre-normalized Rexx string");auto rs=(RexxStringObject)value;const char*src=context->StringData(rs);size_t len=context->StringLength(rs);std::unique_lock<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");if(r->readonly)throw std::runtime_error("foreign buffer is readonly");r->cv.wait(g,[&]{return r->active==0||r->closing;});if(r->closing)throw std::runtime_error("foreign buffer handle not found or closed");size_t n=bufferSize(*r);if(offset>n||len>n-offset)throw std::runtime_error("foreign buffer putBytes range out of bounds");if(len)memcpy((uint8_t*)bufferData(*r)+(size_t)offset,src,len);return context->UnsignedInt64ToObject(len);
}catch(const std::exception&e){return fail(context,e.what());}}

RexxRoutine1(RexxObjectPtr, rexx_foreign_object_close, uint64_t, id){try{std::shared_ptr<ObjectRecord>r;{std::lock_guard<std::mutex>g(mu);auto it=objects.find(id);if(it==objects.end())return context->Nil();r=it->second;objects.erase(it);}std::unique_lock<std::mutex>g(r->stateMu);if(r->closing)return context->Nil();r->closing=true;r->cv.wait(g,[&]{return r->active==0;});void*ptr=r->ptr;r->ptr=nullptr;auto ownership=r->ownership;auto destructor=r->destructor;auto L=r->lib;g.unlock();if(ptr&&ownership=="owned"){void*d=L->dl.symbol(destructor);if(r->destructorPointerDepth==2){void*slot=ptr;((void(*)(void**))d)(&slot);}else ((void(*)(void*))d)(ptr);}return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_object_info, uint64_t, id){try{auto r=objectRecord(id);std::lock_guard<std::mutex>g(r->stateMu);if(r->closing)throw std::runtime_error("foreign object handle not found or closed");RexxArrayObject a=context->NewArray(5);context->ArrayPut(a,context->String(r->type.c_str()),1);context->ArrayPut(a,context->String(r->ownership.c_str()),2);context->ArrayPut(a,context->True(),3);context->ArrayPut(a,context->String(r->addressSpace.c_str()),4);context->ArrayPut(a,context->UnsignedInt64ToObject(r->byteLength),5);return a;}catch(const std::exception&e){return fail(context,e.what());}}

RexxRoutine1(RexxObjectPtr, rexx_foreign_handle_close, uint64_t, id){try{std::shared_ptr<HandleRecord>r;{std::lock_guard<std::mutex>g(mu);auto it=handles.find(id);if(it==handles.end())return context->Nil();r=it->second;handles.erase(it);}std::unique_lock<std::mutex>g(r->stateMu);r->closing=true;r->cv.wait(g,[&]{return r->active==0;});g.unlock();invokeHandleDestructor(r);return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_handle_info, uint64_t, id){try{auto r=handleRecord(id);std::lock_guard<std::mutex>g(r->stateMu);RexxArrayObject a=context->NewArray(5);context->ArrayPut(a,context->String(r->type.c_str()),1);context->ArrayPut(a,context->String(r->carrier.c_str()),2);context->ArrayPut(a,context->String(r->ownership.c_str()),3);context->ArrayPut(a,context->UnsignedInt64ToObject(r->value),4);context->ArrayPut(a,r->closing?context->True():context->False(),5);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr, rexx_foreign_struct_create, uint64_t, id, CSTRING, name){try{auto L=libraryById(id);auto it=L->structs.find(lower(name));if(it==L->structs.end())throw std::runtime_error(std::string("foreign struct type not found: ")+name);uint64_t sid;auto r=std::make_shared<StructRecord>();r->lib=L;r->type=it->second;r->data.resize(r->type.size);{std::lock_guard<std::mutex>g(mu);sid=nextStructId++;structs[sid]=r;}return context->UnsignedInt64ToObject(sid);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr, rexx_foreign_struct_view, uint64_t, id, CSTRING, name, RexxObjectPtr, source){try{
  auto L=libraryById(id);auto it=L->structs.find(lower(name));if(it==L->structs.end())throw std::runtime_error(std::string("foreign struct type not found: ")+name);
  std::string tok=objectToken(context,source);void*ptr=nullptr;std::shared_ptr<ObjectRecord>owner;
  if(auto oid=tokenId(tok,"@foreign-object:")){owner=objectRecord(oid);std::lock_guard<std::mutex>og(owner->stateMu);if(owner->closing)throw std::runtime_error("foreign object closed");ptr=owner->ptr;}
  else {uintptr_t raw=(uintptr_t)strtoull(tok.c_str(),nullptr,0);ptr=(void*)raw;}
  if(!ptr)throw std::runtime_error("foreign struct view requires a non-null pointer");
  uint64_t sid;auto r=std::make_shared<StructRecord>();r->lib=L;r->type=it->second;r->externalPtr=ptr;r->ownerObject=owner;
  {std::lock_guard<std::mutex>g(mu);sid=nextStructId++;structs[sid]=r;}
  return context->UnsignedInt64ToObject(sid);
}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr, rexx_foreign_pointer_at, uint64_t, address, uint64_t, index){try{
  if(!address)throw std::runtime_error("foreign pointerAt requires a non-null address");
  void**base=(void**)(uintptr_t)address;void*value=base[index];
  return context->UnsignedInt64ToObject((uintptr_t)value);
}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr, rexx_foreign_peek_bytes, uint64_t, address, uint64_t, size){try{
  if(!address&&size)throw std::runtime_error("foreign peekBytes requires a non-null address");
  if(size>16777216ULL)throw std::runtime_error("foreign peekBytes size exceeds 16 MiB safety bound");
  return context->String((const char*)(uintptr_t)address,(size_t)size);
}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_struct_close, uint64_t, id){try{std::shared_ptr<StructRecord>r;{std::lock_guard<std::mutex>g(mu);auto it=structs.find(id);if(it==structs.end())return context->Nil();r=it->second;structs.erase(it);}std::unique_lock<std::mutex>g(r->stateMu);r->closing=true;r->cv.wait(g,[&]{return r->active==0;});r->data.clear();r->externalPtr=nullptr;r->ownerObject.reset();r->bufferRefs.clear();r->objectRefs.clear();r->structRefs.clear();r->pointerArrayRefs.clear();r->structArrayRefs.clear();return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_struct_info, uint64_t, id){try{auto r=structRecord(id);std::lock_guard<std::mutex>g(r->stateMu);RexxArrayObject a=context->NewArray(4);context->ArrayPut(a,context->String(r->type.name.c_str()),1);context->ArrayPut(a,context->UnsignedInt64ToObject(r->type.size),2);context->ArrayPut(a,context->UnsignedInt64ToObject(r->type.align),3);RexxArrayObject fs=context->NewArray(r->type.fields.size());for(size_t i=0;i<r->type.fields.size();++i){RexxArrayObject q=context->NewArray(3);context->ArrayPut(q,context->String(r->type.fields[i].name.c_str()),1);context->ArrayPut(q,context->String(r->type.fields[i].type.c_str()),2);context->ArrayPut(q,context->UnsignedInt64ToObject(r->type.fields[i].offset),3);context->ArrayPut(fs,q,i+1);}context->ArrayPut(a,fs,4);return a;}catch(const std::exception&e){return fail(context,e.what());}}
static StructField structFieldType(const StructType&t,const std::string&name){for(auto&f:t.fields)if(lower(f.name)==lower(name))return f;throw std::runtime_error("foreign struct field not found: "+name);}
static StructField structField(const StructRecord&r,const std::string&name){return structFieldType(r.type,name);}
RexxRoutine2(RexxObjectPtr, rexx_foreign_struct_get, uint64_t, id, CSTRING, field){try{auto r=structRecord(id);std::lock_guard<std::mutex>g(r->stateMu);auto f=structField(*r,field);auto t=typeOf(f.type);const uint8_t*base=r->externalPtr?(const uint8_t*)r->externalPtr:r->data.data();const uint8_t*p=base+f.offset;switch(t){case T::I8:{int8_t v;memcpy(&v,p,1);return context->Int64ToObject(v);}case T::U8:{uint8_t v;memcpy(&v,p,1);return context->UnsignedInt64ToObject(v);}case T::I16:{int16_t v;memcpy(&v,p,2);return context->Int64ToObject(v);}case T::U16:{uint16_t v;memcpy(&v,p,2);return context->UnsignedInt64ToObject(v);}case T::I32:{int32_t v;memcpy(&v,p,4);return context->Int64ToObject(v);}case T::U32:case T::BOOL:{uint32_t v;memcpy(&v,p,4);return context->UnsignedInt64ToObject(v);}case T::I64:case T::IPTR:{int64_t v;memcpy(&v,p,8);return context->Int64ToObject(v);}case T::U64:case T::UPTR:{uint64_t v;memcpy(&v,p,8);return context->UnsignedInt64ToObject(v);}case T::F64:{double v;memcpy(&v,p,8);return context->DoubleToObject(v);}case T::PTR:{void*v;memcpy(&v,p,sizeof v);return context->UnsignedInt64ToObject((uintptr_t)v);}default:throw std::runtime_error("unsupported readable struct field type: "+f.type);}}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr, rexx_foreign_struct_set, uint64_t, id, CSTRING, field, RexxObjectPtr, value){try{
  auto r=structRecord(id); auto f=structField(*r,field); auto ft=typeOf(f.type); std::string key=lower(field);
  if(ft==T::PTR){
    std::string tok=objectToken(context,value); void*pv=nullptr;
    std::shared_ptr<BufferRecord> br; std::shared_ptr<ObjectRecord> obr; std::shared_ptr<StructRecord> sr;
    std::shared_ptr<PointerArrayRecord> par; std::shared_ptr<StructArrayRecord> sar;
    std::unique_ptr<BufferPin> bp; std::unique_ptr<ObjectPin> op; std::unique_ptr<StructPin> sp;
    std::unique_ptr<PointerArrayPin> pap; std::unique_ptr<StructArrayPin> sap;
    if(tok=="@foreign-null")pv=nullptr;
    else if(auto rid=tokenId(tok,"@foreign-buffer:")){br=bufferRecord(rid);bp=std::make_unique<BufferPin>(br);pv=bp->ptr;}
    else if(auto rid=tokenId(tok,"@foreign-object:")){obr=objectRecord(rid);op=std::make_unique<ObjectPin>(obr);pv=op->ptr;}
    else if(auto rid=tokenId(tok,"@foreign-struct:")){sr=structRecord(rid);}
    else if(auto rid=tokenId(tok,"@foreign-pointer-array:")){par=pointerArrayRecord(rid);pap=std::make_unique<PointerArrayPin>(par);pv=pap->ptr;}
    else if(auto rid=tokenId(tok,"@foreign-struct-array:")){sar=structArrayRecord(rid);sap=std::make_unique<StructArrayPin>(sar);pv=sap->ptr;}
    else { if(tok.rfind("@foreign-",0)==0)throw std::runtime_error("unsupported managed resource for foreign struct pointer field");pv=(void*)(uintptr_t)strtoull(tok.c_str(),nullptr,0); }
    std::lock_guard<std::mutex> graphGuard(structGraphMu);
    if(sr){if(structReaches(sr,r.get()))throw std::runtime_error("foreign struct managed pointer relationship would create a cycle");sp=std::make_unique<StructPin>(sr);pv=sp->ptr;}
    std::unique_lock<std::mutex>g(r->stateMu); if(r->closing)throw std::runtime_error("foreign struct handle not found or closed"); r->cv.wait(g,[&]{return r->active==0||r->closing;}); if(r->closing)throw std::runtime_error("foreign struct handle not found or closed");
    uint8_t*base=r->externalPtr?(uint8_t*)r->externalPtr:r->data.data(); memcpy(base+f.offset,&pv,sizeof pv);
    r->bufferRefs.erase(key);r->objectRefs.erase(key);r->structRefs.erase(key);r->pointerArrayRefs.erase(key);r->structArrayRefs.erase(key);
    if(br)r->bufferRefs[key]=br;
    if(obr)r->objectRefs[key]=obr;
    if(sr)r->structRefs[key]=sr;
    if(par)r->pointerArrayRefs[key]=par;
    if(sar)r->structArrayRefs[key]=sar;
    return context->Nil();
  }
  auto a=argFrom(context,value,ft); std::unique_lock<std::mutex>g(r->stateMu); if(r->closing)throw std::runtime_error("foreign struct handle not found or closed"); r->cv.wait(g,[&]{return r->active==0||r->closing;}); if(r->closing)throw std::runtime_error("foreign struct handle not found or closed");
  uint8_t*base=r->externalPtr?(uint8_t*)r->externalPtr:r->data.data(); uint8_t*p=base+f.offset;
  switch(ft){case T::I8:memcpy(p,&a.i8,1);break;case T::U8:memcpy(p,&a.u8,1);break;case T::I16:{int16_t v=(int16_t)a.i32;memcpy(p,&v,2);break;}case T::U16:{uint16_t v=(uint16_t)a.u32;memcpy(p,&v,2);break;}case T::I32:case T::BOOL:memcpy(p,&a.i32,4);break;case T::U32:memcpy(p,&a.u32,4);break;case T::I64:case T::IPTR:memcpy(p,&a.i,8);break;case T::U64:case T::UPTR:memcpy(p,&a.u,8);break;case T::F64:memcpy(p,&a.d,8);break;default:throw std::runtime_error("unsupported writable struct field type: "+f.type);}return context->Nil();
}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr, rexx_foreign_struct_array_create, uint64_t, libId, CSTRING, name, uint64_t, count){try{auto L=libraryById(libId);auto it=L->structs.find(lower(name));if(it==L->structs.end())throw std::runtime_error(std::string("foreign struct type not found: ")+name);auto r=std::make_shared<StructArrayRecord>();r->lib=L;r->type=it->second;r->count=(size_t)count;if(count&&r->type.size>SIZE_MAX/(size_t)count)throw std::runtime_error("foreign struct array size overflow");r->data.resize(r->type.size*(size_t)count);uint64_t id;{std::lock_guard<std::mutex>g(mu);id=nextStructArrayId++;structArrays[id]=r;}return context->UnsignedInt64ToObject(id);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_struct_array_close, uint64_t, id){try{std::shared_ptr<StructArrayRecord>r;{std::lock_guard<std::mutex>g(mu);auto it=structArrays.find(id);if(it==structArrays.end())return context->Nil();r=it->second;structArrays.erase(it);}std::unique_lock<std::mutex>g(r->stateMu);r->closing=true;r->cv.wait(g,[&]{return r->active==0;});r->data.clear();return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_struct_array_count, uint64_t, id){try{auto r=structArrayRecord(id);std::lock_guard<std::mutex>g(r->stateMu);return context->UnsignedInt64ToObject(r->count);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr, rexx_foreign_struct_array_get, uint64_t, id, uint64_t, index, CSTRING, field){try{auto r=structArrayRecord(id);std::lock_guard<std::mutex>g(r->stateMu);if(index<1||index>r->count)throw std::runtime_error("foreign struct array index out of range");auto f=structFieldType(r->type,field);const uint8_t*p=r->data.data()+(index-1)*r->type.size+f.offset;switch(typeOf(f.type)){case T::I8:{int8_t v;memcpy(&v,p,1);return context->Int64ToObject(v);}case T::U8:{uint8_t v;memcpy(&v,p,1);return context->UnsignedInt64ToObject(v);}case T::I16:{int16_t v;memcpy(&v,p,2);return context->Int64ToObject(v);}case T::U16:{uint16_t v;memcpy(&v,p,2);return context->UnsignedInt64ToObject(v);}case T::I32:{int32_t v;memcpy(&v,p,4);return context->Int64ToObject(v);}case T::U32:case T::BOOL:{uint32_t v;memcpy(&v,p,4);return context->UnsignedInt64ToObject(v);}case T::I64:case T::IPTR:{int64_t v;memcpy(&v,p,8);return context->Int64ToObject(v);}case T::U64:case T::UPTR:{uint64_t v;memcpy(&v,p,8);return context->UnsignedInt64ToObject(v);}case T::F64:{double v;memcpy(&v,p,8);return context->DoubleToObject(v);}case T::PTR:{void*v;memcpy(&v,p,sizeof v);return context->UnsignedInt64ToObject((uintptr_t)v);}default:throw std::runtime_error("unsupported readable struct array field type: "+f.type);}}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine4(RexxObjectPtr, rexx_foreign_struct_array_set, uint64_t, id, uint64_t, index, CSTRING, field, RexxObjectPtr, value){try{auto r=structArrayRecord(id);std::lock_guard<std::mutex>g(r->stateMu);if(index<1||index>r->count)throw std::runtime_error("foreign struct array index out of range");auto f=structFieldType(r->type,field);auto ft=typeOf(f.type);if(ft==T::PTR){auto tok=objectToken(context,value);if(tok.rfind("@foreign-",0)==0&&tok!="@foreign-null")throw std::runtime_error("managed pointer fields in ForeignStructArray are not supported; use ForeignStruct for retained pointer relationships");}auto a=argFrom(context,value,ft);uint8_t*p=r->data.data()+(index-1)*r->type.size+f.offset;switch(ft){case T::I8:memcpy(p,&a.i8,1);break;case T::U8:memcpy(p,&a.u8,1);break;case T::I16:{int16_t v=(int16_t)a.i32;memcpy(p,&v,2);break;}case T::U16:{uint16_t v=(uint16_t)a.u32;memcpy(p,&v,2);break;}case T::I32:case T::BOOL:memcpy(p,&a.i32,4);break;case T::U32:memcpy(p,&a.u32,4);break;case T::I64:case T::IPTR:memcpy(p,&a.i,8);break;case T::U64:case T::UPTR:memcpy(p,&a.u,8);break;case T::F64:memcpy(p,&a.d,8);break;case T::PTR:memcpy(p,&a.p,sizeof a.p);break;default:throw std::runtime_error("unsupported writable struct array field type: "+f.type);}return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr, rexx_foreign_pointer_array_create, uint64_t, count, CSTRING, elementType){try{uint64_t id;auto r=std::make_shared<PointerArrayRecord>();r->elementType=elementType;r->slots.resize((size_t)count);r->bufferRefs.resize((size_t)count);r->objectRefs.resize((size_t)count);{std::lock_guard<std::mutex>g(mu);id=nextPointerArrayId++;pointerArrays[id]=r;}return context->UnsignedInt64ToObject(id);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine3(RexxObjectPtr, rexx_foreign_pointer_array_set, uint64_t, id, uint64_t, index, RexxObjectPtr, value){try{auto r=pointerArrayRecord(id);if(index<1||index>r->slots.size())throw std::runtime_error("foreign pointer array index out of range");std::string tok=objectToken(context,value);std::lock_guard<std::mutex>g(r->stateMu);size_t i=(size_t)index-1;r->bufferRefs[i].reset();r->objectRefs[i].reset();if(tok=="@foreign-null")r->slots[i]=nullptr;else if(auto bid=tokenId(tok,"@foreign-buffer:")){auto b=bufferRecord(bid);r->bufferRefs[i]=b;std::lock_guard<std::mutex>bg(b->stateMu);if(b->closing)throw std::runtime_error("foreign buffer closed");r->slots[i]=b->data.empty()?nullptr:b->data.data();}else if(auto oid=tokenId(tok,"@foreign-object:")){auto o=objectRecord(oid);r->objectRefs[i]=o;std::lock_guard<std::mutex>og(o->stateMu);if(o->closing)throw std::runtime_error("foreign object closed");r->slots[i]=o->ptr;}else throw std::runtime_error("pointer array accepts ForeignBuffer, ForeignObject, or .nil");return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_pointer_array_close, uint64_t, id){try{std::shared_ptr<PointerArrayRecord>r;{std::lock_guard<std::mutex>g(mu);auto it=pointerArrays.find(id);if(it==pointerArrays.end())return context->Nil();r=it->second;pointerArrays.erase(it);}std::unique_lock<std::mutex>g(r->stateMu);r->closing=true;r->cv.wait(g,[&]{return r->active==0;});r->slots.clear();r->bufferRefs.clear();r->objectRefs.clear();return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_pointer_array_size, uint64_t, id){try{auto r=pointerArrayRecord(id);std::lock_guard<std::mutex>g(r->stateMu);return context->UnsignedInt64ToObject(r->slots.size());}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine4(RexxObjectPtr, rexx_foreign_callback_create, uint64_t, libId, CSTRING, name, RexxObjectPtr, target, CSTRING, method){try{auto L=libraryById(libId);auto it=L->callbacks.find(lower(name));if(it==L->callbacks.end())throw std::runtime_error(std::string("foreign callback signature not found: ")+name);auto r=std::make_shared<CallbackRecord>();r->spec=it->second;r->target=context->RequestGlobalReference(target);r->method=method;uint64_t id;{std::lock_guard<std::mutex>g(mu);id=nextCallbackId++;callbackObjects[id]=r;}return context->UnsignedInt64ToObject(id);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_callback_close, uint64_t, id){try{std::shared_ptr<CallbackRecord>r;{std::lock_guard<std::mutex>g(mu);auto it=callbackObjects.find(id);if(it==callbackObjects.end())return context->Nil();r=it->second;callbackObjects.erase(it);}if(r->target){context->ReleaseGlobalReference(r->target);r->target=nullptr;}r->closed=true;return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine2(RexxObjectPtr, rexx_foreign_callback_info, uint64_t, libId, CSTRING, name){try{auto L=libraryById(libId);auto it=L->callbacks.find(lower(name));if(it==L->callbacks.end())throw std::runtime_error(std::string("foreign callback signature not found: ")+name);RexxArrayObject a=context->NewArray(5);context->ArrayPut(a,context->String(it->second.name.c_str()),1);context->ArrayPut(a,context->String(it->second.ret.c_str()),2);RexxArrayObject xs=context->NewArray(it->second.args.size());for(size_t i=0;i<it->second.args.size();++i)context->ArrayPut(xs,context->String(it->second.args[i].c_str()),i+1);context->ArrayPut(a,xs,3);context->ArrayPut(a,context->String(it->second.threadPolicy.c_str()),4);context->ArrayPut(a,context->String(it->second.lifetime.c_str()),5);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_callback_names, uint64_t, libId){try{auto L=libraryById(libId);RexxArrayObject a=context->NewArray(L->callbacks.size());size_t i=1;for(auto&kv:L->callbacks)context->ArrayPut(a,context->String(kv.second.name.c_str()),i++);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_struct_type_names, uint64_t, id){try{auto L=libraryById(id);RexxArrayObject a=context->NewArray(L->structs.size());size_t i=1;for(auto&kv:L->structs)context->ArrayPut(a,context->String(kv.second.name.c_str()),i++);return a;}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr, rexx_foreign_datatype_info, CSTRING, name){try{auto z=typeInfo(name);RexxArrayObject a=context->NewArray(9);context->ArrayPut(a,context->String(z.semantic),1);context->ArrayPut(a,context->UnsignedInt64ToObject(z.size),2);context->ArrayPut(a,context->UnsignedInt64ToObject(z.align),3);context->ArrayPut(a,z.isSigned?context->True():context->False(),4);context->ArrayPut(a,context->String(z.carrierName),5);context->ArrayPut(a,context->String(z.pointerTo),6);std::string hk=(lower(name)=="handle"||lower(name)=="hwnd"||lower(name)=="hmodule"||lower(name)=="hdc"||lower(name)=="hinstance")?name:"";context->ArrayPut(a,context->String(hk.c_str()),7);context->ArrayPut(a,context->String(z.encoding),8);context->ArrayPut(a,context->String(z.cc),9);return a;}catch(...){return context->Nil();}}
RexxRoutine0(RexxObjectPtr, rexx_foreign_datatype_names){std::vector<std::string> names={"i8","u8","i16","u16","i32","u32","i64","u64","signed char","unsigned char","short","unsigned short","int","unsigned int","long","unsigned long","long long","unsigned long long","size_t","ptrdiff_t","intptr","uintptr","double","bool","utf8","utf16","bytes","pointer","DWORD","HANDLE","HWND","HMODULE","HDC","HINSTANCE","WPARAM","LPARAM","LRESULT"};
#ifndef _WIN32
 names.push_back("ssize_t");names.push_back("socklen_t");
#endif
 RexxArrayObject a=context->NewArray(names.size());for(size_t i=0;i<names.size();++i)context->ArrayPut(a,context->String(names[i].c_str()),i+1);return a;}
std::string rexxVersionString(uint64_t raw){std::ostringstream out;out<<((raw>>16)&0xff)<<"."<<((raw>>8)&0xff)<<"."<<(raw&0xff);return out.str();}
RexxRoutine0(RexxObjectPtr, rexx_foreign_runtime_info){RexxArrayObject a=context->NewArray(20);context->ArrayPut(a,context->String("0.22.6"),1);const uint64_t requiredRaw=REXX_INTERPRETER_5_0_0;const uint64_t actualRaw=context->InterpreterVersion();auto requiredText=rexxVersionString(requiredRaw),actualText=rexxVersionString(actualRaw);context->ArrayPut(a,context->String(requiredText.c_str()),2);context->ArrayPut(a,context->String(actualText.c_str()),3);context->ArrayPut(a,context->UnsignedInt64ToObject(context->LanguageLevel()),4);context->ArrayPut(a,context->UnsignedInt64ToObject(REXX_PACKAGE_API_NO),5);context->ArrayPut(a,context->UnsignedInt64ToObject(sizeof(void*)),6);
#ifdef _WIN32
context->ArrayPut(a,context->String("windows"),7);context->ArrayPut(a,context->String("LoadLibraryW/GetProcAddress"),8);
#else
context->ArrayPut(a,context->String("posix"),7);context->ArrayPut(a,context->String("dlopen/dlsym"),8);
#endif
context->ArrayPut(a,context->String("published-ooRexx-native-package-api"),9);
#ifdef __VERSION__
context->ArrayPut(a,context->String(__VERSION__),10);
#else
context->ArrayPut(a,context->String("unknown"),10);
#endif
uint16_t endianProbe=1;context->ArrayPut(a,context->String(*(uint8_t*)&endianProbe?"little":"big"),11);context->ArrayPut(a,context->UnsignedInt64ToObject(libffi().available()?0:3),12);context->ArrayPut(a,context->UnsignedInt64ToObject(requiredRaw),13);context->ArrayPut(a,context->UnsignedInt64ToObject(actualRaw),14);context->ArrayPut(a,context->String(libffi().available()?"libffi.so.8":"typed-template"),15);context->ArrayPut(a,context->String(runtimeAbiProfile().c_str()),16);context->ArrayPut(a,isQualifiedAbiProfile(runtimeAbiProfile())?context->True():context->False(),17);context->ArrayPut(a,context->String(runtimeArchitecture().c_str()),18);context->ArrayPut(a,context->String(runtimeDataModel().c_str()),19);context->ArrayPut(a,context->String(runtimeOsFamily().c_str()),20);return a;}
RexxRoutine0(RexxObjectPtr, rexx_foreign_qualified_abi_profiles){const auto&q=qualifiedAbiProfiles();RexxArrayObject a=context->NewArray(q.size());for(size_t i=0;i<q.size();++i)context->ArrayPut(a,context->String(q[i].c_str()),i+1);return a;}
RexxRoutine0(RexxObjectPtr, rexx_foreign_runtime_capabilities){
 std::vector<std::string> names={"metadata-json","c-abi-dispatch","first-class-datatypes","typed-constants","utf8","utf16","bytes","pointer-sized-integers","opaque-handles","semantic-windows-types","runtime-abi-report","library-name-fallback","foreign-buffers","writable-out-buffers","foreign-objects","owned-object-destructors","borrowed-object-lifetimes","nullable-pointers","optional-system-library-probes","openssl-evp-sha256-probe","unknown-method-dispatch","reserved-native-routine-prefix","foreign-introspection","resolved-signatures","method-by-inputs","overloaded-logical-methods","thread-safe-registries","pinned-call-resources","concurrent-invocation","close-waits-for-active-calls","library-lifetime-pinning","binary-exact-bytes","automatic-out-allocation","structured-foreign-results","pointer-to-pointer-object-outputs","nontrailing-output-placeholders","pointer-to-pointer-destructor-adapters","optional-runtime-libffi","metadata-defined-structs","foreign-struct-storage","typed-pointer-arrays","address-space-semantics","foreign-resource-extents","provider-threading-metadata","provider-affinity-metadata","call-scoped-callbacks","callback-thread-policy","borrowed-struct-views","raw-memory-peek","scalar-owned-resources","errno-capture","foreign-struct-arrays","output-validity-rules","optional-python-provider","python-object-proxies","python-runtime-introspection","foreign-buffer-export-v1","python-zero-copy-buffer","foreign-buffer-import-v1","python-buffer-import","foreign-tensor-import-v1","foreign-tensor-export-v1","native-tensor-descriptors","managed-struct-pointer-fields","transitive-struct-pinning","binary-buffer-slices","i8-u8-scalars","i8-u8-struct-fields","abi-profile-enforcement","profile-scoped-layouts","profile-scoped-constants","abi-native-c-scalars"};
 if(libffi().available()){names.push_back("runtime-loaded-libffi");names.push_back("dynamic-native-arity");}
 RexxArrayObject a=context->NewArray(names.size());for(size_t i=0;i<names.size();++i)context->ArrayPut(a,context->String(names[i].c_str()),i+1);return a;
}
static RexxRoutineEntry routines[]={REXX_TYPED_ROUTINE(rexx_foreign_load_definition,rexx_foreign_load_definition),REXX_TYPED_ROUTINE(rexx_foreign_close,rexx_foreign_close),REXX_TYPED_ROUTINE(rexx_foreign_constant_raw,rexx_foreign_constant_raw),REXX_TYPED_ROUTINE(rexx_foreign_invoke,rexx_foreign_invoke),REXX_TYPED_ROUTINE(rexx_foreign_function_exists,rexx_foreign_function_exists),REXX_TYPED_ROUTINE(rexx_foreign_library_info,rexx_foreign_library_info),REXX_TYPED_ROUTINE(rexx_foreign_method_names,rexx_foreign_method_names),REXX_TYPED_ROUTINE(rexx_foreign_method_signatures,rexx_foreign_method_signatures),REXX_TYPED_ROUTINE(rexx_foreign_method_by_inputs,rexx_foreign_method_by_inputs),REXX_TYPED_ROUTINE(rexx_foreign_method_by_inputs_index,rexx_foreign_method_by_inputs_index),REXX_TYPED_ROUTINE(rexx_foreign_buffer_create,rexx_foreign_buffer_create),REXX_TYPED_ROUTINE(rexx_foreign_buffer_close,rexx_foreign_buffer_close),REXX_TYPED_ROUTINE(rexx_foreign_buffer_size,rexx_foreign_buffer_size),REXX_TYPED_ROUTINE(rexx_foreign_buffer_readonly,rexx_foreign_buffer_readonly),REXX_TYPED_ROUTINE(rexx_foreign_buffer_hex,rexx_foreign_buffer_hex),REXX_TYPED_ROUTINE(rexx_foreign_buffer_bytes,rexx_foreign_buffer_bytes),REXX_TYPED_ROUTINE(rexx_foreign_buffer_u32,rexx_foreign_buffer_u32),REXX_TYPED_ROUTINE(rexx_foreign_buffer_get_bytes,rexx_foreign_buffer_get_bytes),REXX_TYPED_ROUTINE(rexx_foreign_buffer_put_bytes,rexx_foreign_buffer_put_bytes),REXX_TYPED_ROUTINE(rexx_foreign_object_close,rexx_foreign_object_close),REXX_TYPED_ROUTINE(rexx_foreign_object_info,rexx_foreign_object_info),REXX_TYPED_ROUTINE(rexx_foreign_handle_close,rexx_foreign_handle_close),REXX_TYPED_ROUTINE(rexx_foreign_handle_info,rexx_foreign_handle_info),REXX_TYPED_ROUTINE(rexx_foreign_struct_create,rexx_foreign_struct_create),REXX_TYPED_ROUTINE(rexx_foreign_struct_view,rexx_foreign_struct_view),REXX_TYPED_ROUTINE(rexx_foreign_pointer_at,rexx_foreign_pointer_at),REXX_TYPED_ROUTINE(rexx_foreign_peek_bytes,rexx_foreign_peek_bytes),REXX_TYPED_ROUTINE(rexx_foreign_struct_close,rexx_foreign_struct_close),REXX_TYPED_ROUTINE(rexx_foreign_struct_info,rexx_foreign_struct_info),REXX_TYPED_ROUTINE(rexx_foreign_struct_get,rexx_foreign_struct_get),REXX_TYPED_ROUTINE(rexx_foreign_struct_set,rexx_foreign_struct_set),REXX_TYPED_ROUTINE(rexx_foreign_struct_array_create,rexx_foreign_struct_array_create),REXX_TYPED_ROUTINE(rexx_foreign_struct_array_close,rexx_foreign_struct_array_close),REXX_TYPED_ROUTINE(rexx_foreign_struct_array_count,rexx_foreign_struct_array_count),REXX_TYPED_ROUTINE(rexx_foreign_struct_array_get,rexx_foreign_struct_array_get),REXX_TYPED_ROUTINE(rexx_foreign_struct_array_set,rexx_foreign_struct_array_set),REXX_TYPED_ROUTINE(rexx_foreign_pointer_array_create,rexx_foreign_pointer_array_create),REXX_TYPED_ROUTINE(rexx_foreign_pointer_array_set,rexx_foreign_pointer_array_set),REXX_TYPED_ROUTINE(rexx_foreign_pointer_array_close,rexx_foreign_pointer_array_close),REXX_TYPED_ROUTINE(rexx_foreign_pointer_array_size,rexx_foreign_pointer_array_size),REXX_TYPED_ROUTINE(rexx_foreign_callback_create,rexx_foreign_callback_create),REXX_TYPED_ROUTINE(rexx_foreign_callback_close,rexx_foreign_callback_close),REXX_TYPED_ROUTINE(rexx_foreign_callback_info,rexx_foreign_callback_info),REXX_TYPED_ROUTINE(rexx_foreign_callback_names,rexx_foreign_callback_names),REXX_TYPED_ROUTINE(rexx_foreign_struct_type_names,rexx_foreign_struct_type_names),REXX_TYPED_ROUTINE(rexx_foreign_datatype_info,rexx_foreign_datatype_info),REXX_TYPED_ROUTINE(rexx_foreign_datatype_names,rexx_foreign_datatype_names),REXX_TYPED_ROUTINE(rexx_foreign_runtime_info,rexx_foreign_runtime_info),REXX_TYPED_ROUTINE(rexx_foreign_qualified_abi_profiles,rexx_foreign_qualified_abi_profiles),REXX_TYPED_ROUTINE(rexx_foreign_runtime_capabilities,rexx_foreign_runtime_capabilities),REXX_LAST_ROUTINE()};
RexxPackageEntry foreign_runtime_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,"ooRexxForeignRuntime","0.22.6",NULL,NULL,routines,NULL};
OOREXX_GET_PACKAGE(foreign_runtime);
