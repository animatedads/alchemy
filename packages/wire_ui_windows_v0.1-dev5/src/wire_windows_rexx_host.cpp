#include "wire_windows_rexx_host.h"
#include <windows.h>
#include <oorexxapi.h>
#include <filesystem>
#include <vector>
struct WireWindowsRexxHost::State { RexxInstance *instance{}; RexxThreadContext *thread{}; std::filesystem::path bootstrap; };
WireWindowsRexxHost::WireWindowsRexxHost():state_(new State){}
WireWindowsRexxHost::~WireWindowsRexxHost(){ if(state_){ if(state_->instance) state_->instance->Terminate(); delete state_; } }
static std::string narrowPath(const std::filesystem::path &p){ return p.u8string(); }
bool WireWindowsRexxHost::start(const std::wstring &applicationDir,std::string &error){
  auto base=std::filesystem::path(applicationDir); state_->bootstrap=base/L"rexx"/L"WireWindowsBootstrap.rex";
  auto rexxDir=base/L"rexx"; auto runtimeBin=base/L"runtime"/L"oorexx"/L"bin";
  if(!std::filesystem::exists(state_->bootstrap)){error="WireWindowsBootstrap.rex missing";return false;}
  SetDllDirectoryW(runtimeBin.c_str());
  std::string path=narrowPath(rexxDir);
  RexxOption options[2]; options[0].optionName=DIRECTORY_INTERFACE; options[0].option=path.c_str(); options[1].optionName=nullptr; options[1].option=nullptr;
  if(RexxCreateInterpreter(&state_->instance,&state_->thread,options)==0){error="RexxCreateInterpreter failed";return false;}
  return true;
}
bool WireWindowsRexxHost::dispatch(const char *source,const char *trigger,const char *detailKey,const char *detailValue,std::string &result,std::string &error){
  if(!state_->thread){error="ooRexx host not started";return false;}
  RexxArrayObject args=state_->thread->NewArray(4);
  state_->thread->ArrayPut(args,state_->thread->String(source?source:""),1);
  state_->thread->ArrayPut(args,state_->thread->String(trigger?trigger:""),2);
  state_->thread->ArrayPut(args,state_->thread->String(detailKey?detailKey:""),3);
  state_->thread->ArrayPut(args,state_->thread->String(detailValue?detailValue:""),4);
  std::string program=narrowPath(state_->bootstrap);
  RexxObjectPtr value=state_->thread->CallProgram(program.c_str(),args);
  if(state_->thread->CheckCondition()){ state_->thread->ClearCondition(); error="ooRexx condition while dispatching Wire event"; return false; }
  if(value==NULLOBJECT){result.clear();return true;}
  result=state_->thread->ObjectToStringValue(value); return true;
}
