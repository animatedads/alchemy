/* GTK4 is private to this translation unit: public Wire ABI contains no GTK/GObject types. */
#include "wire_renderer.h"
#ifdef WIRE_WITH_GTK4
#include <gtk/gtk.h>
#include <stdlib.h>
#include <string.h>
#define MAX_ELEMS 256
#define MAX_ROWS 512
#define WIRE_STABLE_ID_KEY "wire-stable-id"
#define WIRE_SUBJECT_KEY "wire-subject"
typedef struct GtkElem GtkElem;
struct GtkElem {
 WireHandle h; WireElementKind kind; GtkWidget *widget; WireListSource list; char *semantic_id;
 uint64_t range_start; size_t range_count; size_t window_size; gboolean range_switching;
 GtkWidget *scroll_view; GtkWidget *virtual_bar; GtkAdjustment *virtual_adjustment; GtkElem *scroll_owner;
};
typedef struct { GtkApplication *app; WireDispatch dispatch; void *dispatch_ctx; GtkElem elems[MAX_ELEMS]; size_t n; } GtkState;
static GtkElem *find(GtkState*s,WireHandle h){for(size_t i=0;i<s->n;i++)if(s->elems[i].h==h)return &s->elems[i];return NULL;}
static WireResult show_range_r(WireRenderer*r,WireHandle h,uint64_t start,size_t count);
static void clicked(GtkButton*b,gpointer data){(void)b;GtkElem*e=data;WireNativeEvent ev={NULL,"Click",NULL,NULL};char id[32];g_snprintf(id,sizeof id,"%" G_GUINT64_FORMAT,(guint64)e->h);ev.source_id=e->semantic_id?e->semantic_id:id;GtkState*s=g_object_get_data(G_OBJECT(e->widget),"wire-state");if(s&&s->dispatch)s->dispatch(s->dispatch_ctx,&ev);}
static void list_row_activated(GtkListBox *box,GtkListBoxRow *row,gpointer data){
 (void)box;
 GtkElem *e=data;
 GtkState *s=g_object_get_data(G_OBJECT(e->widget),"wire-state");
 if(!s||!s->dispatch)return;
 const char *stable=g_object_get_data(G_OBJECT(row),WIRE_STABLE_ID_KEY);
 if(!stable)return;
 char id[32];
 g_snprintf(id,sizeof id,"%" G_GUINT64_FORMAT,(guint64)e->h);
 WireNativeEvent ev={e->semantic_id?e->semantic_id:id,"SelectionChanged","identity",stable};
 s->dispatch(s->dispatch_ctx,&ev);
}
static const WireRendererVTable VT;
static void virtual_scroll_changed(GtkAdjustment *adj,gpointer data){
 GtkElem *e=data;
 if(!e||e->range_switching||!e->list.count||!e->list.range||!e->window_size)return;
 uint64_t total=e->list.count(e->list.ctx);
 if(!total)return;
 double raw=gtk_adjustment_get_value(adj);
 uint64_t start=(uint64_t)raw;
 if(start+e->window_size>total)start=total>e->window_size?total-e->window_size:0;
 if(start==e->range_start)return;
 GtkState *s=g_object_get_data(G_OBJECT(e->widget),"wire-state");
 if(!s||!s->dispatch)return;
 char source[32];
 char requested[32];
 g_snprintf(source,sizeof source,"%" G_GUINT64_FORMAT,(guint64)e->h);
 g_snprintf(requested,sizeof requested,"%" G_GUINT64_FORMAT,(guint64)start);
 WireNativeEvent ev={e->semantic_id?e->semantic_id:source,"RangeRequested","start",requested};
 s->dispatch(s->dispatch_ctx,&ev);
}
static gboolean virtual_wheel(GtkEventControllerScroll *controller,double dx,double dy,gpointer data){
 (void)controller;(void)dx;
 GtkElem *e=data;
 if(!e||!e->scroll_owner||!e->scroll_owner->virtual_adjustment||dy==0.0)return FALSE;
 GtkAdjustment *a=e->scroll_owner->virtual_adjustment;
 double v=gtk_adjustment_get_value(a)+(dy>0.0?3.0:-3.0);
 double hi=gtk_adjustment_get_upper(a)-gtk_adjustment_get_page_size(a);
 if(v<0.0)v=0.0;
 if(v>hi)v=hi;
 gtk_adjustment_set_value(a,v);
 return TRUE;
}
static void destroy_r(WireRenderer*r){if(!r)return;GtkState*s=r->impl;if(s){for(size_t i=0;i<s->n;i++)g_free(s->elems[i].semantic_id);if(s->app)g_object_unref(s->app);}free(s);free(r);}
static GtkWidget *make_widget(GtkState *s,WireElementKind k){switch(k){case WIRE_WINDOW:return gtk_application_window_new(s->app);case WIRE_STACK:return gtk_box_new(GTK_ORIENTATION_VERTICAL,0);case WIRE_SPLIT:return gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);case WIRE_LABEL:return gtk_label_new("");case WIRE_BUTTON:return gtk_button_new();case WIRE_TEXT_INPUT:return gtk_entry_new();case WIRE_SCROLL:return gtk_box_new(GTK_ORIENTATION_HORIZONTAL,0);case WIRE_VIRTUAL_LIST:return gtk_list_box_new();case WIRE_DOCUMENT:return gtk_text_view_new();default:return NULL;}}
static WireResult create_r(WireRenderer*r,WireHandle h,WireElementKind k,WireHandle parent){if(!r)return WIRE_EINVAL;GtkState*s=r->impl;if(s->n==MAX_ELEMS||find(s,h))return WIRE_ESTATE;GtkWidget*w=make_widget(s,k);if(!w)return WIRE_ENOTSUP;GtkElem*e=&s->elems[s->n++];*e=(GtkElem){0};e->h=h;e->kind=k;e->widget=w;g_object_set_data(G_OBJECT(w),"wire-state",s);
if(k==WIRE_SCROLL){e->scroll_view=gtk_scrolled_window_new();e->virtual_adjustment=GTK_ADJUSTMENT(gtk_adjustment_new(0.0,0.0,1.0,1.0,1.0,1.0));e->virtual_bar=gtk_scrollbar_new(GTK_ORIENTATION_VERTICAL,e->virtual_adjustment);gtk_widget_set_visible(e->virtual_bar,FALSE);gtk_widget_set_hexpand(e->scroll_view,TRUE);gtk_widget_set_vexpand(e->scroll_view,TRUE);gtk_box_append(GTK_BOX(w),e->scroll_view);gtk_box_append(GTK_BOX(w),e->virtual_bar);}if(k==WIRE_BUTTON)g_signal_connect(w,"clicked",G_CALLBACK(clicked),e);if(k==WIRE_VIRTUAL_LIST)g_signal_connect(w,"row-activated",G_CALLBACK(list_row_activated),e);if(parent){GtkElem*p=find(s,parent);if(!p)return WIRE_ESTATE;if(GTK_IS_WINDOW(p->widget))gtk_window_set_child(GTK_WINDOW(p->widget),w);else if(p->kind==WIRE_SCROLL&&p->scroll_view)gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(p->scroll_view),w);else if(GTK_IS_BOX(p->widget))gtk_box_append(GTK_BOX(p->widget),w);else if(GTK_IS_PANED(p->widget)){if(!gtk_paned_get_start_child(GTK_PANED(p->widget)))gtk_paned_set_start_child(GTK_PANED(p->widget),w);else gtk_paned_set_end_child(GTK_PANED(p->widget),w);}else return WIRE_ENOTSUP;}if(k==WIRE_VIRTUAL_LIST&&parent){GtkElem*p=find(s,parent);if(p&&p->kind==WIRE_SCROLL&&p->scroll_view){e->scroll_owner=p;gtk_widget_set_visible(p->virtual_bar,TRUE);gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(p->scroll_view),GTK_POLICY_AUTOMATIC,GTK_POLICY_NEVER);g_signal_connect(p->virtual_adjustment,"value-changed",G_CALLBACK(virtual_scroll_changed),e);GtkEventController*wheel=gtk_event_controller_scroll_new(GTK_EVENT_CONTROLLER_SCROLL_VERTICAL);g_signal_connect(wheel,"scroll",G_CALLBACK(virtual_wheel),e);gtk_widget_add_controller(e->widget,wheel);}}return WIRE_OK;}
static WireResult prop_r(WireRenderer*r,WireHandle h,const WireProperty*p){if(!r||!p||!p->key)return WIRE_EINVAL;GtkElem*e=find(r->impl,h);if(!e)return WIRE_ESTATE;if(!strcmp(p->key,"id")){g_free(e->semantic_id);e->semantic_id=g_strdup(p->value?p->value:"");return e->semantic_id?WIRE_OK:WIRE_ESTATE;}if(!strcmp(p->key,"text")||!strcmp(p->key,"value")){if(GTK_IS_LABEL(e->widget))gtk_label_set_text(GTK_LABEL(e->widget),p->value?p->value:"");else if(GTK_IS_BUTTON(e->widget))gtk_button_set_label(GTK_BUTTON(e->widget),p->value?p->value:"");else if(GTK_IS_EDITABLE(e->widget))gtk_editable_set_text(GTK_EDITABLE(e->widget),p->value?p->value:"");else if(GTK_IS_TEXT_VIEW(e->widget)){GtkTextBuffer*b=gtk_text_view_get_buffer(GTK_TEXT_VIEW(e->widget));gtk_text_buffer_set_text(b,p->value?p->value:"",-1);}else return WIRE_ENOTSUP;return WIRE_OK;}if(!strcmp(p->key,"title")&&GTK_IS_WINDOW(e->widget)){gtk_window_set_title(GTK_WINDOW(e->widget),p->value?p->value:"");return WIRE_OK;}if((!strcmp(p->key,"width")||!strcmp(p->key,"height"))&&GTK_IS_WINDOW(e->widget)){int w=0,hgt=0;gtk_window_get_default_size(GTK_WINDOW(e->widget),&w,&hgt);int n=p->value?atoi(p->value):0;if(n<=0)return WIRE_EINVAL;if(!strcmp(p->key,"width"))w=n;else hgt=n;gtk_window_set_default_size(GTK_WINDOW(e->widget),w,hgt);return WIRE_OK;}if(!strcmp(p->key,"width")){int n=p->value?atoi(p->value):0;if(n<=0)return WIRE_EINVAL;gtk_widget_set_size_request(e->widget,n,-1);return WIRE_OK;}if(!strcmp(p->key,"height")){int n=p->value?atoi(p->value):0;if(n<=0)return WIRE_EINVAL;gtk_widget_set_size_request(e->widget,-1,n);return WIRE_OK;}if(!strcmp(p->key,"expand")){gboolean on=p->value&&(!strcmp(p->value,"true")||!strcmp(p->value,"1"));gtk_widget_set_hexpand(e->widget,on);gtk_widget_set_vexpand(e->widget,on);return WIRE_OK;}if(!strcmp(p->key,"orientation")&&GTK_IS_PANED(e->widget)){gtk_orientable_set_orientation(GTK_ORIENTABLE(e->widget),p->value&&!strcmp(p->value,"vertical")?GTK_ORIENTATION_VERTICAL:GTK_ORIENTATION_HORIZONTAL);return WIRE_OK;}if(!strcmp(p->key,"position")&&GTK_IS_PANED(e->widget)){int n=p->value?atoi(p->value):0;if(n<0)return WIRE_EINVAL;gtk_paned_set_position(GTK_PANED(e->widget),n);return WIRE_OK;}return WIRE_ENOTSUP;}
static WireResult remove_r(WireRenderer*r,WireHandle h){GtkElem*e=r?find(r->impl,h):NULL;if(!e)return WIRE_EINVAL;gtk_widget_unparent(e->widget);e->widget=NULL;return WIRE_OK;}
static WireResult dispatch_r(WireRenderer*r,WireDispatch f,void*c){if(!r)return WIRE_EINVAL;GtkState*s=r->impl;s->dispatch=f;s->dispatch_ctx=c;return WIRE_OK;}
static WireResult bind_list_r(WireRenderer*r,WireHandle h,const WireListSource*src){GtkElem*e=r?find(r->impl,h):NULL;if(!e||e->kind!=WIRE_VIRTUAL_LIST||!src||!src->count||!src->range)return WIRE_EINVAL;e->list=*src;return WIRE_OK;}
static WireResult show_range_r(WireRenderer*r,WireHandle h,uint64_t start,size_t count){GtkElem*e=r?find(r->impl,h):NULL;if(!e||e->kind!=WIRE_VIRTUAL_LIST||!e->list.range||count>MAX_ROWS)return WIRE_EINVAL;GtkWidget*child;while((child=gtk_widget_get_first_child(e->widget)))gtk_list_box_remove(GTK_LIST_BOX(e->widget),child);uint64_t total=e->list.count(e->list.ctx);if(start>=total)return WIRE_OK;if(!e->window_size)e->window_size=count;if(count>total-start)count=(size_t)(total-start);WireListRow rows[MAX_ROWS];size_t got=e->list.range(e->list.ctx,start,count,rows);for(size_t i=0;i<got;i++){const char *subject=rows[i].subject?rows[i].subject:"";GtkWidget*line=gtk_box_new(GTK_ORIENTATION_HORIZONTAL,12);GtkWidget*from=gtk_label_new(rows[i].from?rows[i].from:"");GtkWidget*label=gtk_label_new(subject);GtkWidget*date=gtk_label_new(rows[i].date?rows[i].date:"");gtk_widget_set_size_request(from,180,-1);gtk_widget_set_hexpand(label,TRUE);gtk_label_set_ellipsize(GTK_LABEL(label),PANGO_ELLIPSIZE_END);gtk_label_set_xalign(GTK_LABEL(from),0.0f);gtk_label_set_xalign(GTK_LABEL(label),0.0f);gtk_label_set_xalign(GTK_LABEL(date),1.0f);g_object_set_data_full(G_OBJECT(label),WIRE_SUBJECT_KEY,g_strdup(subject),g_free);gtk_box_append(GTK_BOX(line),from);gtk_box_append(GTK_BOX(line),label);gtk_box_append(GTK_BOX(line),date);GtkWidget*row=gtk_list_box_row_new();gtk_list_box_row_set_child(GTK_LIST_BOX_ROW(row),line);g_object_set_data(G_OBJECT(row),"wire-subject-label",label);const char *stable=rows[i].stable_id;if(stable)g_object_set_data_full(G_OBJECT(row),WIRE_STABLE_ID_KEY,g_strdup(stable),g_free);gtk_list_box_append(GTK_LIST_BOX(e->widget),row);}e->range_start=start;e->range_count=count;
if(e->scroll_owner&&e->scroll_owner->virtual_adjustment){GtkAdjustment*a=e->scroll_owner->virtual_adjustment;e->range_switching=TRUE;gtk_adjustment_configure(a,(double)start,0.0,(double)total,(double)e->window_size,(double)e->window_size,(double)e->window_size);e->range_switching=FALSE;}
return WIRE_OK;}
static WireResult row_prop_r(WireRenderer*r,WireHandle h,const WireListRowProperty*p){GtkElem*e=r?find(r->impl,h):NULL;if(!e||e->kind!=WIRE_VIRTUAL_LIST||!p||!p->stable_id||!p->key)return WIRE_EINVAL;for(GtkWidget*row=gtk_widget_get_first_child(e->widget);row;row=gtk_widget_get_next_sibling(row)){const char*stable=g_object_get_data(G_OBJECT(row),WIRE_STABLE_ID_KEY);if(!stable||strcmp(stable,p->stable_id))continue;GtkWidget*label=g_object_get_data(G_OBJECT(row),"wire-subject-label");if(!GTK_IS_LABEL(label))return WIRE_ESTATE;if(!strcmp(p->key,"annotation")||!strcmp(p->key,"assessment")){const char*subject=g_object_get_data(G_OBJECT(label),WIRE_SUBJECT_KEY);char*text=g_strdup_printf("%s%s%s",subject?subject:"",p->value&&*p->value?"   [":"",p->value&&*p->value?p->value:"");if(p->value&&*p->value){char*closed=g_strconcat(text,"]",NULL);g_free(text);text=closed;}gtk_label_set_text(GTK_LABEL(label),text);g_free(text);return WIRE_OK;}return WIRE_ENOTSUP;}return WIRE_ESTATE;}
static WireResult run_r(WireRenderer*r){if(!r)return WIRE_EINVAL;GtkState*s=r->impl;for(size_t i=0;i<s->n;i++)if(s->elems[i].kind==WIRE_WINDOW)gtk_window_present(GTK_WINDOW(s->elems[i].widget));int status=g_application_run(G_APPLICATION(s->app),0,NULL);return status==0?WIRE_OK:WIRE_ESTATE;}
static const WireRendererVTable VT={WIRE_RENDERER_ABI,destroy_r,create_r,prop_r,remove_r,dispatch_r,bind_list_r,show_range_r,row_prop_r,run_r};
WireRenderer *wire_gtk4_renderer_new(void){WireRenderer*r=calloc(1,sizeof(*r));GtkState*s=calloc(1,sizeof(*s));if(!r||!s){free(r);free(s);return NULL;}s->app=gtk_application_new("org.oorexx.wire.direct",G_APPLICATION_DEFAULT_FLAGS);GError*error=NULL;if(!g_application_register(G_APPLICATION(s->app),NULL,&error)){if(error)g_error_free(error);g_object_unref(s->app);free(s);free(r);return NULL;}r->v=&VT;r->impl=s;return r;}
#else
int wire_gtk4_renderer_source_boundary(void){return WIRE_RENDERER_ABI;}
#endif
