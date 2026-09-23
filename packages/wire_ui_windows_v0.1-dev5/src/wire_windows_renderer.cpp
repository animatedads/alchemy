#define UNICODE
#define _UNICODE
#include <windows.h>
#include <commctrl.h>
#include <unordered_map>
#include <string>
#include "wire_windows_renderer.h"
struct Node { WireElementKind kind{}; HWND hwnd{}; WireHandle parent{}; std::wstring text; std::string semanticId; };
struct Impl { HINSTANCE instance{}; HWND main{}; std::unordered_map<WireHandle,Node> nodes; WireDispatch dispatch{}; void *dispatchCtx{}; };
struct PendingEvent { std::string source; std::string trigger; };
static constexpr UINT WIRE_WM_SEMANTIC_EVENT=WM_APP+42;
static HFONT wireFont(){static HFONT f=CreateFontW(-18,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH|FF_DONTCARE,L"Segoe UI");return f;}
static void applyFont(HWND h){SendMessageW(h,WM_SETFONT,reinterpret_cast<WPARAM>(wireFont()),TRUE);}
static std::wstring wide(const char *s){ if(!s)return {}; int n=MultiByteToWideChar(CP_UTF8,0,s,-1,nullptr,0); std::wstring w(n? n-1:0,L'\0'); if(n>1) MultiByteToWideChar(CP_UTF8,0,s,-1,w.data(),n); return w; }
static Impl *implOf(HWND h){return reinterpret_cast<Impl*>(GetWindowLongPtrW(h,GWLP_USERDATA));}
static LRESULT CALLBACK wndproc(HWND h,UINT m,WPARAM w,LPARAM l){
 if(m==WM_NCCREATE){auto cs=reinterpret_cast<CREATESTRUCTW*>(l);SetWindowLongPtrW(h,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(cs->lpCreateParams));}
 auto*p=implOf(h);
 if(m==WM_COMMAND && p){WireHandle id=(WireHandle)LOWORD(w); auto it=p->nodes.find(id); if(it!=p->nodes.end() && HIWORD(w)==BN_CLICKED && p->dispatch){
   auto *pending=new PendingEvent{it->second.semanticId,"Click"}; PostMessageW(h,WIRE_WM_SEMANTIC_EVENT,0,reinterpret_cast<LPARAM>(pending)); return 0; }}
 if(m==WM_SIZE && p){int width=LOWORD(l);for(auto &x:p->nodes){auto &n=x.second;if(!n.hwnd||n.hwnd==p->main)continue;if(n.kind==WIRE_LABEL)SetWindowPos(n.hwnd,nullptr,28,n.semanticId=="heading"?28:132,width>80?width-56:100,28,SWP_NOZORDER);else if(n.kind==WIRE_BUTTON)SetWindowPos(n.hwnd,nullptr,28,76,240,38,SWP_NOZORDER);}return 0;}
 if(m==WM_DESTROY){PostQuitMessage(0);return 0;} return DefWindowProcW(h,m,w,l);
}
static void destroy(WireRenderer*r){if(!r)return;auto*p=(Impl*)r->impl;if(p){for(auto &x:p->nodes)if(x.second.hwnd&&x.second.hwnd!=p->main)DestroyWindow(x.second.hwnd);if(p->main)DestroyWindow(p->main);delete p;}delete r;}
static WireResult create(WireRenderer*r,WireHandle h,WireElementKind k,WireHandle parent){auto*p=(Impl*)r->impl;if(!p||p->nodes.count(h))return WIRE_ESTATE;HWND ph=parent&&p->nodes.count(parent)?p->nodes[parent].hwnd:nullptr;HWND hw=nullptr;DWORD style=WS_CHILD|WS_VISIBLE;
 if(k==WIRE_WINDOW){WNDCLASSW wc{};wc.lpfnWndProc=wndproc;wc.hInstance=p->instance;wc.lpszClassName=L"WireUIWindow";wc.hCursor=LoadCursor(nullptr,IDC_ARROW);wc.hbrBackground=(HBRUSH)(COLOR_WINDOW+1);RegisterClassW(&wc);hw=CreateWindowExW(0,wc.lpszClassName,L"Wire UI",WS_OVERLAPPEDWINDOW|WS_VISIBLE,CW_USEDEFAULT,CW_USEDEFAULT,760,300,nullptr,nullptr,p->instance,p);p->main=hw;}
 else if(k==WIRE_LABEL){int y=(int)p->nodes.size()==1?28:118;hw=CreateWindowW(L"STATIC",L"",style,28,y,760,28,ph,nullptr,p->instance,nullptr);}
 else if(k==WIRE_BUTTON)hw=CreateWindowW(L"BUTTON",L"",style|BS_PUSHBUTTON,28,72,240,36,ph,(HMENU)(UINT_PTR)h,p->instance,nullptr);
 else if(k==WIRE_TEXT_INPUT)hw=CreateWindowExW(WS_EX_CLIENTEDGE,L"EDIT",L"",style|ES_AUTOHSCROLL,20,110,300,26,ph,(HMENU)(UINT_PTR)h,p->instance,nullptr);
 else if(k==WIRE_SCROLL||k==WIRE_STACK||k==WIRE_SPLIT||k==WIRE_DOCUMENT)hw=CreateWindowW(L"STATIC",L"",style,0,0,100,100,ph,nullptr,p->instance,nullptr);
 else if(k==WIRE_VIRTUAL_LIST)hw=CreateWindowW(WC_LISTVIEWW,L"",style|LVS_REPORT|LVS_OWNERDATA,0,0,300,300,ph,(HMENU)(UINT_PTR)h,p->instance,nullptr);else return WIRE_ENOTSUP;
 if(!hw)return WIRE_ESTATE;applyFont(hw);p->nodes[h]=Node{k,hw,parent,{},std::to_string(h)};return WIRE_OK;}
static WireResult set_property(WireRenderer*r,WireHandle h,const WireProperty*pr){auto*p=(Impl*)r->impl;if(!p||!pr||!pr->key||!p->nodes.count(h))return WIRE_EINVAL;auto &n=p->nodes[h];std::string k=pr->key;if(k=="semanticId"){n.semanticId=pr->value?pr->value:"";return n.semanticId.empty()?WIRE_EINVAL:WIRE_OK;}if(k=="text"||k=="label"||k=="title"){n.text=wide(pr->value);SetWindowTextW(n.hwnd,n.text.c_str());return WIRE_OK;}if(k=="visible"){ShowWindow(n.hwnd,pr->value&&std::string(pr->value)=="false"?SW_HIDE:SW_SHOW);return WIRE_OK;}if(k=="enabled"){EnableWindow(n.hwnd,!(pr->value&&std::string(pr->value)=="false"));return WIRE_OK;}return WIRE_ENOTSUP;}
static WireResult remove_node(WireRenderer*r,WireHandle h){auto*p=(Impl*)r->impl;if(!p||!p->nodes.count(h))return WIRE_EINVAL;if(p->nodes[h].hwnd)DestroyWindow(p->nodes[h].hwnd);p->nodes.erase(h);return WIRE_OK;}
static WireResult set_dispatch(WireRenderer*r,WireDispatch fn,void*ctx){auto*p=(Impl*)r->impl;if(!p)return WIRE_EINVAL;p->dispatch=fn;p->dispatchCtx=ctx;return WIRE_OK;}
static WireResult bind_list(WireRenderer*,WireHandle,const WireListSource*){return WIRE_ENOTSUP;}static WireResult show_list(WireRenderer*,WireHandle,uint64_t,size_t){return WIRE_ENOTSUP;}static WireResult rowprop(WireRenderer*,WireHandle,const WireListRowProperty*){return WIRE_ENOTSUP;}
static WireResult run(WireRenderer*r){auto*p=(Impl*)r->impl;if(!p)return WIRE_EINVAL;MSG msg;while(GetMessageW(&msg,nullptr,0,0)>0){if(msg.message==WIRE_WM_SEMANTIC_EVENT){auto *pending=reinterpret_cast<PendingEvent*>(msg.lParam);if(pending&&p->dispatch){WireNativeEvent ev{pending->source.c_str(),pending->trigger.c_str(),nullptr,nullptr};p->dispatch(p->dispatchCtx,&ev);}delete pending;continue;}TranslateMessage(&msg);DispatchMessageW(&msg);}return WIRE_OK;}
static const WireRendererVTable VT={WIRE_RENDERER_ABI,destroy,create,set_property,remove_node,set_dispatch,bind_list,show_list,rowprop,run};
extern "C" WireRenderer *wire_windows_renderer_create(void){auto*r=new WireRenderer;auto*p=new Impl;p->instance=GetModuleHandleW(nullptr);r->v=&VT;r->impl=p;return r;}
