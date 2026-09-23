#define UNICODE
#include <windows.h>
#include <commctrl.h>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>
#include "wire_windows_renderer.h"
#include "wire_windows_rexx_host.h"
struct App { WireWindowsRexxHost rexx; WireRenderer *renderer{}; std::unordered_map<std::string,WireHandle> handles; };
static std::wstring appDir(){wchar_t path[MAX_PATH];GetModuleFileNameW(nullptr,path,MAX_PATH);return std::filesystem::path(path).parent_path().wstring();}
static WireElementKind kindOf(const std::string&s){if(s=="WINDOW")return WIRE_WINDOW;if(s=="LABEL")return WIRE_LABEL;if(s=="BUTTON")return WIRE_BUTTON;if(s=="TEXT_INPUT")return WIRE_TEXT_INPUT;if(s=="VIRTUAL_LIST")return WIRE_VIRTUAL_LIST;if(s=="STACK")return WIRE_STACK;if(s=="SPLIT")return WIRE_SPLIT;if(s=="SCROLL")return WIRE_SCROLL;return WIRE_DOCUMENT;}
static std::vector<std::string> split(const std::string&s,char d){std::vector<std::string>v;std::stringstream q(s);std::string x;while(std::getline(q,x,d))v.push_back(x);while(v.size()<4)v.push_back("");return v;}
static bool materialize(App&a,const std::filesystem::path&file,std::string&error){std::ifstream in(file);if(!in){error="semantic definition missing";return false;}std::string line;WireHandle next=1;while(std::getline(in,line)){if(line.empty()||line[0]=='#')continue;auto f=split(line,'|');if(f[0].empty()||f[1].empty()){error="invalid semantic definition";return false;}WireHandle parent=0;if(!f[2].empty()){auto p=a.handles.find(f[2]);if(p==a.handles.end()){error="unknown semantic parent: "+f[2];return false;}parent=p->second;}WireHandle h=next++;if(a.renderer->v->create(a.renderer,h,kindOf(f[1]),parent)!=WIRE_OK){error="renderer create failed for "+f[0];return false;}a.handles[f[0]]=h;WireProperty sid{"semanticId",f[0].c_str()};a.renderer->v->set_property(a.renderer,h,&sid);if(!f[3].empty()){WireProperty text{f[1]=="WINDOW"?"title":"text",f[3].c_str()};a.renderer->v->set_property(a.renderer,h,&text);}}return true;}
static bool applyPatchLine(App&a,const std::string&line){auto f=split(line,'|');if(f.size()<4||f[0]!="WIRE_PATCH")return false;auto it=a.handles.find(f[1]);if(it==a.handles.end())return false;WireProperty p{f[2].c_str(),f[3].c_str()};return a.renderer->v->set_property(a.renderer,it->second,&p)==WIRE_OK;}
static bool applyPatchBatch(App&a,const std::string&result){std::stringstream lines(result);std::string line;bool any=false;while(std::getline(lines,line)){if(line.empty())continue;if(!applyPatchLine(a,line))return false;any=true;}return any;}
static void dispatch(void *ctx,const WireNativeEvent *event){auto*a=(App*)ctx;std::string result,error;if(a->rexx.dispatch(event->source_id,event->trigger,event->detail_key,event->detail_value,result,error)){if(!applyPatchBatch(*a,result))MessageBoxA(nullptr,result.c_str(),"Wire semantic result",MB_OK);}else MessageBoxA(nullptr,error.c_str(),"Wire ooRexx dispatch",MB_ICONERROR);}
int WINAPI wWinMain(HINSTANCE,HINSTANCE,PWSTR,int){InitCommonControls();App app;std::string error;if(!app.rexx.start(appDir(),error)){MessageBoxA(nullptr,error.c_str(),"Wire UI ooRexx startup",MB_ICONERROR);return 10;}app.renderer=wire_windows_renderer_create();if(!app.renderer)return 2;if(app.renderer->v->abi!=WIRE_RENDERER_ABI){app.renderer->v->destroy(app.renderer);return 3;}auto def=std::filesystem::path(appDir())/L"definitions"/L"windows-qualification.wiredef";if(!materialize(app,def,error)){MessageBoxA(nullptr,error.c_str(),"Wire definition",MB_ICONERROR);app.renderer->v->destroy(app.renderer);return 4;}app.renderer->v->set_dispatch(app.renderer,dispatch,&app);auto rc=app.renderer->v->run(app.renderer);app.renderer->v->destroy(app.renderer);return rc==WIRE_OK?0:5;}
