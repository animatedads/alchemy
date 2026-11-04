#include "oorexx_cli_ui.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
 CliUiIo io;
 CliUiDispatch dispatch; void *dispatch_ctx;
 CliUiSize size;
} Ansi;
static Ansi *A(CliUiRenderer *r){ return (Ansi*)r->impl; }
static int wr(CliUiRenderer *r,const char*s){size_t n=strlen(s);return A(r)->io.write&&A(r)->io.write(A(r)->io.ctx,(const unsigned char*)s,n)==0?0:-1;}
static CliUiResult emit_key(CliUiRenderer*r,CliUiKeyKind kind,uint32_t mods,uint32_t cp){Ansi*a=A(r);if(!a->dispatch)return CLIUI_OK;CliUiEvent e;memset(&e,0,sizeof e);e.kind=CLIUI_EVENT_KEY;e.key.kind=kind;e.key.modifiers=mods;e.key.codepoint=cp;a->dispatch(a->dispatch_ctx,&e);return CLIUI_OK;}
static CliUiResult ansi_set_dispatch(CliUiRenderer*r,CliUiDispatch fn,void*ctx){A(r)->dispatch=fn;A(r)->dispatch_ctx=ctx;return CLIUI_OK;}
static CliUiResult ansi_set_size(CliUiRenderer*r,CliUiSize s){if(s.rows<1||s.cols<1)return CLIUI_EINVAL;A(r)->size=s;return CLIUI_OK;}
static CliUiResult ansi_begin(CliUiRenderer*r){return wr(r,"\x1b[H\x1b[2J")?CLIUI_EIO:CLIUI_OK;}
static const char* sgr(CliUiStyleClass s){switch(s){case CLIUI_STYLE_KEYWORD:return"\x1b[1;34m";case CLIUI_STYLE_STRING:return"\x1b[32m";case CLIUI_STYLE_COMMENT:return"\x1b[2;37m";case CLIUI_STYLE_NUMBER:return"\x1b[35m";case CLIUI_STYLE_TYPE:return"\x1b[36m";case CLIUI_STYLE_SYMBOL:return"\x1b[33m";case CLIUI_STYLE_ERROR:return"\x1b[1;31m";case CLIUI_STYLE_SELECTION:return"\x1b[7m";case CLIUI_STYLE_STATUS:return"\x1b[1m";default:return"\x1b[0m";}}
static CliUiResult ansi_text(CliUiRenderer*r,int row,int col,const char*t,CliUiStyleClass s){char b[64];if(row<0||col<0||!t)return CLIUI_EINVAL;snprintf(b,sizeof b,"\x1b[%d;%dH",row+1,col+1);if(wr(r,b)||wr(r,sgr(s))||wr(r,t)||wr(r,"\x1b[0m"))return CLIUI_EIO;return CLIUI_OK;}
static CliUiResult ansi_rule(CliUiRenderer*r,int row,int col,int width,uint32_t glyph,CliUiStyleClass s){if(width<0||glyph>127)return CLIUI_EINVAL;char *b=(char*)malloc((size_t)width+1);if(!b)return CLIUI_EIO;memset(b,(int)(glyph?glyph:'-'),(size_t)width);b[width]=0;CliUiResult q=ansi_text(r,row,col,b,s);free(b);return q;}
static CliUiResult ansi_cursor(CliUiRenderer*r,int row,int col,int visible){char b[64];if(row<0||col<0)return CLIUI_EINVAL;snprintf(b,sizeof b,"\x1b[%d;%dH\x1b[?25%c",row+1,col+1,visible?'h':'l');return wr(r,b)?CLIUI_EIO:CLIUI_OK;}
static CliUiResult ansi_end(CliUiRenderer*r){return wr(r,"\x1b[0m")?CLIUI_EIO:CLIUI_OK;}
static void destroy(CliUiRenderer*r){if(!r)return;Ansi*a=A(r);if(a&&a->io.close)a->io.close(a->io.ctx);free(r->impl);free(r);}
static CliUiResult decode_seq(CliUiRenderer*r,const unsigned char*s,size_t n){uint32_t mods=0;unsigned final=0;if(n==3&&s[0]==27&&s[1]=='['){final=s[2];switch(final){case'A':return emit_key(r,CLIUI_KEY_UP,0,0);case'B':return emit_key(r,CLIUI_KEY_DOWN,0,0);case'C':return emit_key(r,CLIUI_KEY_RIGHT,0,0);case'D':return emit_key(r,CLIUI_KEY_LEFT,0,0);case'H':return emit_key(r,CLIUI_KEY_HOME,0,0);case'F':return emit_key(r,CLIUI_KEY_END,0,0);case'Z':return emit_key(r,CLIUI_KEY_BACKTAB,CLIUI_MOD_SHIFT,0);}}if(n==6&&s[0]==27&&s[1]=='['&&s[2]=='1'&&s[3]==';'&&s[4]=='2'){mods=CLIUI_MOD_SHIFT;final=s[5];switch(final){case'A':return emit_key(r,CLIUI_KEY_UP,mods,0);case'B':return emit_key(r,CLIUI_KEY_DOWN,mods,0);case'C':return emit_key(r,CLIUI_KEY_RIGHT,mods,0);case'D':return emit_key(r,CLIUI_KEY_LEFT,mods,0);case'H':return emit_key(r,CLIUI_KEY_HOME,mods,0);case'F':return emit_key(r,CLIUI_KEY_END,mods,0);}}if(n==4&&s[0]==27&&s[1]=='['&&s[3]=='~'){switch(s[2]){case'1':return emit_key(r,CLIUI_KEY_HOME,0,0);case'3':return emit_key(r,CLIUI_KEY_DELETE,0,0);case'4':return emit_key(r,CLIUI_KEY_END,0,0);case'5':return emit_key(r,CLIUI_KEY_PAGE_UP,0,0);case'6':return emit_key(r,CLIUI_KEY_PAGE_DOWN,0,0);}}if(n==1&&s[0]==27)return emit_key(r,CLIUI_KEY_ESCAPE,0,0);return CLIUI_ENOTSUP;}
CliUiResult cliui_ansi_feed(CliUiRenderer*r,const unsigned char*b,size_t n){if(!r||!b)return CLIUI_EINVAL;for(size_t i=0;i<n;i++){unsigned c=b[i];if(c==27){if(i+5<n&&b[i+1]=='['&&b[i+2]=='1'&&b[i+3]==';'&&b[i+4]=='2'){decode_seq(r,b+i,6);i+=5;continue;}if(i+3<n&&b[i+1]=='['&&b[i+3]=='~'){decode_seq(r,b+i,4);i+=3;continue;}if(i+2<n&&b[i+1]=='['){decode_seq(r,b+i,3);i+=2;continue;}emit_key(r,CLIUI_KEY_ESCAPE,0,0);continue;}if(c==127||c==8){emit_key(r,CLIUI_KEY_BACKSPACE,0,0);continue;}if(c=='\r'||c=='\n'){emit_key(r,CLIUI_KEY_ENTER,0,0);continue;}if(c=='\t'){emit_key(r,CLIUI_KEY_TAB,0,0);continue;}if(c>=1&&c<=26){emit_key(r,CLIUI_KEY_TEXT,CLIUI_MOD_CTRL,(uint32_t)('a'+c-1));continue;}emit_key(r,CLIUI_KEY_TEXT,0,c);}return CLIUI_OK;}
static CliUiResult ansi_poll(CliUiRenderer*r,int timeout_ms){Ansi*a=A(r);unsigned char b[64];size_t n=0;if(!a->io.read)return CLIUI_ENOTSUP;if(a->io.read(a->io.ctx,b,sizeof b,timeout_ms,&n)!=0)return CLIUI_EIO;if(n==0)return CLIUI_OK;return cliui_ansi_feed(r,b,n);}
static const CliUiRendererVTable VT={OOREXX_CLI_UI_ABI,destroy,ansi_set_dispatch,ansi_set_size,ansi_begin,ansi_text,ansi_rule,ansi_cursor,ansi_end,ansi_poll};
CliUiRenderer *cliui_ansi_create_with_io(const CliUiIo *io){if(!io||!io->write)return NULL;CliUiRenderer*r=(CliUiRenderer*)calloc(1,sizeof*r);Ansi*a=(Ansi*)calloc(1,sizeof*a);if(!r||!a){free(r);free(a);return NULL;}a->io=*io;a->size.rows=24;a->size.cols=80;r->v=&VT;r->impl=a;return r;}
#ifndef CLIUI_WITH_CURSES
CliUiRenderer *cliui_curses_create(void){return NULL;}
#endif
