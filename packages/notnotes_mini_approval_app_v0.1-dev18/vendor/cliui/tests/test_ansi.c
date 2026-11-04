#include "oorexx_cli_ui.h"
#include <assert.h>
static int keys=0,up=0,shift_up=0,ctrlc=0,del=0,backtab=0,page=0;
static void dispatch(void*ctx,const CliUiEvent*e){(void)ctx;if(e->kind!=CLIUI_EVENT_KEY)return;keys++;if(e->key.kind==CLIUI_KEY_UP){up++;if(e->key.modifiers&CLIUI_MOD_SHIFT)shift_up++;}if(e->key.modifiers==CLIUI_MOD_CTRL&&e->key.codepoint=='c')ctrlc++;if(e->key.kind==CLIUI_KEY_DELETE)del++;if(e->key.kind==CLIUI_KEY_BACKTAB)backtab++;if(e->key.kind==CLIUI_KEY_PAGE_UP||e->key.kind==CLIUI_KEY_PAGE_DOWN)page++;}
int main(void){CliUiRenderer*r=cliui_ansi_create(0,1);assert(r);assert(r->v->abi==OOREXX_CLI_UI_ABI);r->v->set_dispatch(r,dispatch,0);const unsigned char a[]={27,'[','A',27,'[','1',';','2','A',27,'[','3','~',27,'[','Z',27,'[','5','~',27,'[','6','~',3,'x'};assert(cliui_ansi_feed(r,a,sizeof a)==CLIUI_OK);assert(keys==8&&up==2&&shift_up==1&&ctrlc==1&&del==1&&backtab==1&&page==2);r->v->destroy(r);return 0;}
