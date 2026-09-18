#include <oorexxapi.h>
#include <stdint.h>
#include <string>
#include <vector>
typedef int (*invoke_fn)(uint64_t,const char*,size_t,const char**,char**,uint64_t*); typedef int (*isa_fn)(uint64_t,const char*); typedef void (*free_fn)(char*);
static invoke_fn g_invoke=nullptr; static isa_fn g_isa=nullptr; static free_fn g_free=nullptr;
extern "C" void ar_clr_callbacks(invoke_fn i,isa_fn t,free_fn f){g_invoke=i;g_isa=t;g_free=f;}
RexxMethod1(RexxObjectPtr, dotnet_init, uint64_t, handle){context->SetObjectVariable("ALCHEMYHANDLE",context->UnsignedInt64(handle));return NULLOBJECT;}
RexxMethod0(uint64_t, dotnet_handle){uint64_t h=0;context->ObjectToUnsignedInt64(context->GetObjectVariable("ALCHEMYHANDLE"),&h);return h;}
RexxMethod1(logical_t, dotnet_isa, CSTRING, n){uint64_t h=0;context->ObjectToUnsignedInt64(context->GetObjectVariable("ALCHEMYHANDLE"),&h);return g_isa?g_isa(h,n):0;}
static RexxObjectPtr invoke(RexxMethodContext *context,const char *message,RexxArrayObject arguments){
 uint64_t h=0,rh=0;char*text=nullptr;context->ObjectToUnsignedInt64(context->GetObjectVariable("ALCHEMYHANDLE"),&h);if(!g_invoke)return NULLOBJECT;
 size_t n=arguments==NULLOBJECT?0:context->ArraySize(arguments); std::vector<std::string> storage; std::vector<const char*> slots; storage.reserve(n);slots.reserve(n);
 for(size_t i=1;i<=n;i++){RexxObjectPtr a=context->ArrayAt(arguments,i); if(a==NULLOBJECT) storage.emplace_back("O"); else if(a==context->Nil()) storage.emplace_back("N"); else if(context->IsOfType(a,"ALCHEMYDOTNETOBJECT") || context->IsOfType(a,"ALCHEMYDOTNETCLASS")){RexxObjectPtr ho=context->SendMessage0(a,"ALCHEMYHANDLE");uint64_t ah=0;context->ObjectToUnsignedInt64(ho,&ah);storage.emplace_back("H"+std::to_string(ah));} else {RexxStringObject s=context->ObjectToString(a); const char *p=context->CString(s); storage.emplace_back(std::string("S")+(p?p:""));} slots.push_back(storage.back().c_str());}
 int k=g_invoke(h,message,n,slots.data(),&text,&rh); if(k==1){std::string v=text?text:""; RexxObjectPtr r=NULLOBJECT; if(v.rfind("I",0)==0){int64_t x=strtoll(v.c_str()+1,nullptr,10);r=context->Int64(x);} else if(v.rfind("D",0)==0){double d=strtod(v.c_str()+1,nullptr);r=context->Double(d);} else r=context->String(v.rfind("S",0)==0?v.c_str()+1:v.c_str());if(text&&g_free)g_free(text);return r;} if(k==2 || k==4){if(rh==h)return context->GetSelf();const char *cn=k==4?"ALCHEMYDOTNETCLASS":"ALCHEMYDOTNETOBJECT";auto c=context->FindContextClass(cn);return c?context->SendMessage1(c,"NEW",context->UnsignedInt64(rh)):NULLOBJECT;} if(k==3){std::string detail=text?text:"CLR invocation failed";if(text&&g_free)g_free(text);context->RaiseException1(48900,context->String((std::string("DOTNET_EXCEPTION:")+detail).c_str()));return NULLOBJECT;} if(text&&g_free)g_free(text);return NULLOBJECT;
}
RexxMethod1(RexxObjectPtr, dotnet_invoke0, CSTRING, message){return invoke(context,message,NULLOBJECT);}
RexxMethod2(RexxObjectPtr, dotnet_invoke, CSTRING, message, RexxArrayObject, arguments){return invoke(context,message,arguments);}
static RexxMethodEntry methods[]={REXX_METHOD(dotnet_init,dotnet_init),REXX_METHOD(dotnet_handle,dotnet_handle),REXX_METHOD(dotnet_isa,dotnet_isa),REXX_METHOD(dotnet_invoke0,dotnet_invoke0),REXX_METHOD(dotnet_invoke,dotnet_invoke),REXX_LAST_METHOD()};
RexxPackageEntry AlchemyDotNetNative_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,"AlchemyDotNetNative","0.2.11",NULL,NULL,NULL,methods}; OOREXX_GET_PACKAGE(AlchemyDotNetNative);
