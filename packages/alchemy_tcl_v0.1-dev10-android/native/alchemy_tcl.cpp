/*
 * Alchemy Tcl v0.1-dev2
 * First real ooRexx -> resident Tcl -> retained ooRexx callback crossing.
 *
 * Tcl is dynamically loaded: no Tcl development headers are required.
 * The callback context is deliberately scoped to the synchronous Tcl_Eval
 * invocation; dev3 will move retained identities into the common lifecycle
 * registry for callbacks that outlive a single crossing.
 */
#include <oorexxapi.h>
#include <dlfcn.h>
#include <mutex>
#include <string>
#include <cstring>
#include <unordered_map>
#include <cstdint>

typedef struct Tcl_Interp Tcl_Interp;
typedef struct Tcl_Obj Tcl_Obj;
typedef void *ClientData;
typedef int (*Tcl_CmdProc)(ClientData, Tcl_Interp *, int, const char **);
typedef void (*Tcl_CmdDeleteProc)(ClientData);

enum { TCL_OK = 0, TCL_ERROR = 1 };

typedef Tcl_Interp *(*pCreate)(void);
typedef void (*pDelete)(Tcl_Interp *);
typedef int (*pInit)(Tcl_Interp *);
typedef int (*pEval)(Tcl_Interp *, const char *);
typedef const char *(*pResult)(Tcl_Interp *);
typedef void *(*pCreateCommand)(Tcl_Interp *, const char *, Tcl_CmdProc,
                                 ClientData, Tcl_CmdDeleteProc);
typedef int (*pDeleteCommand)(Tcl_Interp *, const char *);
typedef void (*pSetResult)(Tcl_Interp *, char *, void (*)(char *));
typedef const char *(*pGetVar)(Tcl_Interp *, const char *, int);
typedef Tcl_Obj *(*pNewStringObj)(const char *, int);
typedef int (*pEvalObjv)(Tcl_Interp *, int, Tcl_Obj *const [], int);
typedef Tcl_Obj *(*pGetObjResult)(Tcl_Interp *);
typedef const char *(*pGetStringFromObj)(Tcl_Obj *, int *);

struct TclApi {
    void *lib = nullptr;
    Tcl_Interp *ip = nullptr;
    pCreate create = nullptr; pDelete destroy = nullptr; pInit init = nullptr;
    pEval eval = nullptr; pResult result = nullptr;
    pCreateCommand createCommand = nullptr; pDeleteCommand deleteCommand = nullptr;
    pSetResult setResult = nullptr; pGetVar getVar = nullptr;
    pNewStringObj newStringObj = nullptr; pEvalObjv evalObjv = nullptr;
    pGetObjResult getObjResult = nullptr; pGetStringFromObj getStringFromObj = nullptr;
    std::recursive_mutex lock;
    std::string provider;

    bool load() {
        if (ip) return true;
        const char *names[]={"libtcl8.7.so","libtcl8.6.so","libtcl.so",nullptr};
        for (int i=0; names[i]; ++i) {
            lib=dlopen(names[i],RTLD_NOW|RTLD_LOCAL);
            if (lib) { provider=names[i]; break; }
        }
        if (!lib) return false;
#define LOAD(member,name) member=(decltype(member))dlsym(lib,name); if(!member) return false
        LOAD(create,"Tcl_CreateInterp"); LOAD(destroy,"Tcl_DeleteInterp");
        LOAD(init,"Tcl_Init"); LOAD(eval,"Tcl_Eval");
        LOAD(result,"Tcl_GetStringResult"); LOAD(createCommand,"Tcl_CreateCommand");
        LOAD(deleteCommand,"Tcl_DeleteCommand"); LOAD(setResult,"Tcl_SetResult"); LOAD(getVar,"Tcl_GetVar");
        LOAD(newStringObj,"Tcl_NewStringObj"); LOAD(evalObjv,"Tcl_EvalObjv");
        LOAD(getObjResult,"Tcl_GetObjResult"); LOAD(getStringFromObj,"Tcl_GetStringFromObj");
#undef LOAD
        ip=create();
        return ip && init(ip)==TCL_OK;
    }
};


static TclApi g;

/*
 * dev4 retained Rexx identity registry.
 *
 * RequestGlobalReference is the same ooRexx rooting mechanism used by the
 * qualified Rust Alchemy native package.  The stored object is durable across
 * native routine returns.  We deliberately do NOT retain RexxCallContext:
 * invocation in dev4 is performed from a later Rexx native call, whose fresh
 * context is used to send to the rooted object.
 *
 * Generation is monotonic.  A token is id:generation; stale generations fail
 * closed and can never silently resolve a recycled slot.
 */
struct RetainedRexx {
    RexxObjectPtr object = NULLOBJECT;
    uint64_t generation = 0;
};
static std::mutex g_retained_mutex;
static std::unordered_map<uint64_t, RetainedRexx> g_retained;
static uint64_t g_next_retained_id = 1;
static uint64_t g_next_generation = 1;

static std::string make_token(uint64_t id, uint64_t generation) {
    return std::to_string(id) + ":" + std::to_string(generation);
}
static bool parse_token(const char *token, uint64_t &id, uint64_t &generation) {
    if (!token) return false;
    const char *colon = std::strchr(token, ':');
    if (!colon || colon == token || !colon[1]) return false;
    try {
        id = std::stoull(std::string(token, colon - token));
        generation = std::stoull(colon + 1);
        return id != 0 && generation != 0;
    } catch (...) { return false; }
}

struct CallbackFrame {
    RexxCallContext *rexx;
    RexxObjectPtr target;
    std::string resultStorage;
};

static int rexxCallback(ClientData cd, Tcl_Interp *ip, int argc, const char **argv) {
    CallbackFrame *f=(CallbackFrame *)cd;
    const char *arg = argc > 1 ? argv[1] : "";
    RexxStringObject rarg=f->rexx->NewStringFromAsciiz(arg);
    RexxObjectPtr answer=f->rexx->SendMessage1(f->target,"CALL",rarg);
    if (f->rexx->CheckCondition()) {
        f->resultStorage="REXX_CALLBACK_ERROR";
        g.setResult(ip,(char *)f->resultStorage.c_str(),nullptr);
        return TCL_ERROR;
    }
    RexxStringObject s=f->rexx->ObjectToString(answer);
    f->resultStorage=f->rexx->StringData(s);
    /* NULL freeProc means Tcl treats this as static. Storage lives through Eval. */
    g.setResult(ip,(char *)f->resultStorage.c_str(),nullptr);
    return TCL_OK;
}

/* Evaluate Tcl in the process-resident interpreter. */
RexxRoutine1(RexxStringObject, AlchemyTclEval, CSTRING, script)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("ALCHEMY_TCL_RUNTIME_UNAVAILABLE");
    int rc=g.eval(g.ip,script);
    const char *r=g.result(g.ip);
    if (rc != TCL_OK) {
        std::string e="TCL_ERROR:";
        e += r ? r : "";
        return context->NewStringFromAsciiz(e.c_str());
    }
    return context->NewStringFromAsciiz(r ? r : "");
}

/* Synchronous same-interpreter proof:
 * Rexx calls Tcl; Tcl invokes ::alchemy::rexx_callback; native code re-enters
 * the exact Rexx callback object; Tcl continues and returns to Rexx.
 */
RexxRoutine2(RexxStringObject, AlchemyTclRoundTrip,
             CSTRING, script, RexxObjectPtr, callback)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("ALCHEMY_TCL_RUNTIME_UNAVAILABLE");

    CallbackFrame frame{context, callback, ""};
    g.eval(g.ip,"namespace eval ::alchemy {}");
    g.deleteCommand(g.ip,"::alchemy::rexx_callback");
    if (!g.createCommand(g.ip,"::alchemy::rexx_callback",rexxCallback,&frame,nullptr))
        return context->NewStringFromAsciiz("ALCHEMY_TCL_CALLBACK_INSTALL_FAILED");

    int rc=g.eval(g.ip,script);
    std::string result=g.result(g.ip) ? g.result(g.ip) : "";
    g.deleteCommand(g.ip,"::alchemy::rexx_callback");

    if (rc != TCL_OK) result="TCL_ERROR:"+result;
    return context->NewStringFromAsciiz(result.c_str());
}


/* Persistent-command / later-evaluation proof.
 *
 * The Tcl command is installed during one Rexx native routine and survives the
 * first Tcl_Eval.  A second, separate Tcl_Eval invokes it later.  The exact
 * Rexx callback object remains the target throughout.
 *
 * IMPORTANT: the CallbackFrame and RexxCallContext still remain inside this
 * native routine's dynamic extent.  This proves Tcl-side command persistence
 * across evaluations, not cross-Rexx-call retention.  Cross-call retention
 * requires a Rexx interpreter/thread context reacquisition contract and is
 * intentionally not fabricated here.
 */
RexxRoutine3(RexxStringObject, AlchemyTclPersistentRoundTrip,
             CSTRING, installScript, CSTRING, laterScript,
             RexxObjectPtr, callback)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("ALCHEMY_TCL_RUNTIME_UNAVAILABLE");

    CallbackFrame frame{context, callback, ""};
    g.eval(g.ip,"namespace eval ::alchemy {}");
    g.deleteCommand(g.ip,"::alchemy::retained_rexx");
    if (!g.createCommand(g.ip,"::alchemy::retained_rexx",rexxCallback,&frame,nullptr))
        return context->NewStringFromAsciiz("ALCHEMY_TCL_CALLBACK_INSTALL_FAILED");

    int rc=g.eval(g.ip,installScript);
    if (rc != TCL_OK) {
        std::string e="TCL_ERROR:";
        e += g.result(g.ip) ? g.result(g.ip) : "";
        g.deleteCommand(g.ip,"::alchemy::retained_rexx");
        return context->NewStringFromAsciiz(e.c_str());
    }

    /* A distinct Tcl evaluation occurs while the command remains registered. */
    rc=g.eval(g.ip,laterScript);
    std::string result=g.result(g.ip) ? g.result(g.ip) : "";
    g.deleteCommand(g.ip,"::alchemy::retained_rexx");
    if (rc != TCL_OK) result="TCL_ERROR:"+result;
    return context->NewStringFromAsciiz(result.c_str());
}


/* Retain an exact Rexx object beyond this native call. */
RexxRoutine1(RexxStringObject, AlchemyTclRetainRexx, RexxObjectPtr, target)
{
    RexxObjectPtr rooted = context->RequestGlobalReference(target);
    if (rooted == NULLOBJECT)
        return context->NewStringFromAsciiz("RETAIN_FAILED");

    uint64_t id, generation;
    {
        std::lock_guard<std::mutex> lock(g_retained_mutex);
        id = g_next_retained_id++;
        generation = g_next_generation++;
        g_retained.emplace(id, RetainedRexx{rooted, generation});
    }
    std::string token = make_token(id, generation);
    return context->NewStringFromAsciiz(token.c_str());
}

/* Invoke a retained identity from a later Rexx call using this call's valid
 * context.  The registry lock is released before Rexx dispatch.
 */
RexxRoutine2(RexxStringObject, AlchemyTclInvokeRetained,
             CSTRING, token, CSTRING, argument)
{
    uint64_t id=0, generation=0;
    if (!parse_token(token,id,generation))
        return context->NewStringFromAsciiz("STALE_OR_REVOKED");

    RexxObjectPtr target=NULLOBJECT;
    {
        std::lock_guard<std::mutex> lock(g_retained_mutex);
        auto it=g_retained.find(id);
        if (it == g_retained.end() || it->second.generation != generation)
            return context->NewStringFromAsciiz("STALE_OR_REVOKED");
        target=it->second.object;
    }

    RexxStringObject arg=context->NewStringFromAsciiz(argument);
    RexxObjectPtr answer=context->SendMessage1(target,"CALL",arg);
    if (context->CheckCondition())
        return context->NewStringFromAsciiz("REXX_CALLBACK_ERROR");
    RexxStringObject out=context->ObjectToString(answer);
    return context->NewStringFromAsciiz(context->StringData(out));
}

/* Revoke and release bridge ownership exactly once. */
RexxRoutine1(logical_t, AlchemyTclReleaseRetained, CSTRING, token)
{
    uint64_t id=0, generation=0;
    if (!parse_token(token,id,generation)) return 0;
    RexxObjectPtr target=NULLOBJECT;
    {
        std::lock_guard<std::mutex> lock(g_retained_mutex);
        auto it=g_retained.find(id);
        if (it == g_retained.end() || it->second.generation != generation) return 0;
        target=it->second.object;
        g_retained.erase(it);
    }
    context->ReleaseGlobalReference(target);
    return 1;
}


struct RetainedTclCommandFrame {
    RexxCallContext *currentContext = nullptr; /* valid only while Eval is active */
    std::string token;
    std::string resultStorage;
};

static int retainedTokenCallback(ClientData cd, Tcl_Interp *ip, int argc, const char **argv)
{
    RetainedTclCommandFrame *frame=(RetainedTclCommandFrame *)cd;
    if (!frame || !frame->currentContext) {
        frame->resultStorage="NO_ACTIVE_REXX_CONTEXT";
        g.setResult(ip,(char *)frame->resultStorage.c_str(),nullptr);
        return TCL_ERROR;
    }

    uint64_t id=0, generation=0;
    if (!parse_token(frame->token.c_str(),id,generation)) {
        frame->resultStorage="STALE_OR_REVOKED";
        g.setResult(ip,(char *)frame->resultStorage.c_str(),nullptr);
        return TCL_ERROR;
    }

    RexxObjectPtr target=NULLOBJECT;
    {
        std::lock_guard<std::mutex> lock(g_retained_mutex);
        auto it=g_retained.find(id);
        if (it == g_retained.end() || it->second.generation != generation) {
            frame->resultStorage="STALE_OR_REVOKED";
            g.setResult(ip,(char *)frame->resultStorage.c_str(),nullptr);
            return TCL_ERROR;
        }
        target=it->second.object;
    } /* foreign/Rexx dispatch is outside registry lock */

    const char *arg=argc > 1 ? argv[1] : "";
    RexxStringObject rarg=frame->currentContext->NewStringFromAsciiz(arg);
    RexxObjectPtr answer=frame->currentContext->SendMessage1(target,"CALL",rarg);
    if (frame->currentContext->CheckCondition()) {
        frame->resultStorage="REXX_CALLBACK_ERROR";
        g.setResult(ip,(char *)frame->resultStorage.c_str(),nullptr);
        return TCL_ERROR;
    }
    RexxStringObject out=frame->currentContext->ObjectToString(answer);
    frame->resultStorage=frame->currentContext->StringData(out);
    g.setResult(ip,(char *)frame->resultStorage.c_str(),nullptr);
    return TCL_OK;
}

/* dev5: install and invoke a Tcl command whose semantic target is a retained
 * Rexx identity created by an EARLIER native call.
 *
 * The Tcl command exists for this evaluation. Its target does not come from
 * this routine's Rexx argument list: it is resolved from the durable token.
 * The fresh current RexxCallContext is attached only for the dynamic extent
 * of Tcl_Eval and is never retained.
 */
RexxRoutine2(RexxStringObject, AlchemyTclEvalRetained,
             CSTRING, token, CSTRING, script)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("ALCHEMY_TCL_RUNTIME_UNAVAILABLE");

    RetainedTclCommandFrame frame;
    frame.currentContext=context;
    frame.token=token ? token : "";

    g.eval(g.ip,"namespace eval ::alchemy {}");
    g.deleteCommand(g.ip,"::alchemy::retained");
    if (!g.createCommand(g.ip,"::alchemy::retained",retainedTokenCallback,&frame,nullptr))
        return context->NewStringFromAsciiz("ALCHEMY_TCL_CALLBACK_INSTALL_FAILED");

    int rc=g.eval(g.ip,script);
    std::string result=g.result(g.ip) ? g.result(g.ip) : "";
    g.deleteCommand(g.ip,"::alchemy::retained");
    frame.currentContext=nullptr;

    if (rc != TCL_OK) result="TCL_ERROR:"+result;
    return context->NewStringFromAsciiz(result.c_str());
}


/* dev6 persistent Tcl projection registry.
 *
 * A projection owns its Tcl command name and generation-bound retained Rexx
 * token.  No RexxCallContext is retained.  The active context is installed
 * only for the dynamic extent of AlchemyTclEvalProjected().
 */
enum class ProjectionState { LIVE, REVOKING, REVOKED, RELEASED };
struct TclProjection {
    std::string name;
    std::string token;
    ProjectionState state = ProjectionState::LIVE;
    uint64_t invocationPins = 0;
    bool deleteRequested = false;
};
static std::mutex g_projection_mutex;
static std::unordered_map<std::string, TclProjection *> g_projections;
static thread_local RexxCallContext *g_active_rexx_context = nullptr;

static void projectionDelete(ClientData cd)
{
    TclProjection *p=(TclProjection *)cd;
    if (!p) return;
    std::lock_guard<std::mutex> lock(g_projection_mutex);
    p->deleteRequested=true;
    if (p->state == ProjectionState::LIVE) p->state=ProjectionState::REVOKING;
    auto it=g_projections.find(p->name);
    if (it != g_projections.end() && it->second == p) g_projections.erase(it);
    if (p->invocationPins == 0) { p->state=ProjectionState::RELEASED; delete p; }
}

static int projectionCallback(ClientData cd, Tcl_Interp *ip, int argc, const char **argv)
{
    TclProjection *p=(TclProjection *)cd;
    RexxCallContext *cx=g_active_rexx_context;
    if (!p || !cx) {
        const char *m="NO_ACTIVE_REXX_CONTEXT";
        g.setResult(ip,(char *)m,nullptr);
        return TCL_ERROR;
    }

    std::string token;
    {
        std::lock_guard<std::mutex> plock(g_projection_mutex);
        if (p->state != ProjectionState::LIVE) {
            const char *m="PROJECTION_REVOKED";
            g.setResult(ip,(char *)m,nullptr);
            return TCL_ERROR;
        }
        ++p->invocationPins;
        token=p->token;
    }

    uint64_t id=0, generation=0;
    RexxObjectPtr target=NULLOBJECT;
    bool valid=parse_token(token.c_str(),id,generation);
    if (valid) {
        std::lock_guard<std::mutex> rlock(g_retained_mutex);
        auto it=g_retained.find(id);
        valid=(it != g_retained.end() && it->second.generation == generation);
        if (valid) target=it->second.object;
    }

    int rc=TCL_OK;
    std::string result;
    if (!valid) {
        result="STALE_OR_REVOKED";
        rc=TCL_ERROR;
    } else {
        const char *arg=argc > 1 ? argv[1] : "";
        RexxStringObject rarg=cx->NewStringFromAsciiz(arg);
        RexxObjectPtr answer=cx->SendMessage1(target,"CALL",rarg);
        if (cx->CheckCondition()) {
            result="REXX_CALLBACK_ERROR";
            rc=TCL_ERROR;
        } else {
            RexxStringObject out=cx->ObjectToString(answer);
            result=cx->StringData(out);
        }
    }

    {
        std::lock_guard<std::mutex> plock(g_projection_mutex);
        if (p->invocationPins) --p->invocationPins;
        if (p->deleteRequested && p->invocationPins == 0) {
            p->state=ProjectionState::RELEASED; delete p; p=nullptr;
        }
    }
    /* Tcl copies/uses this during return from the command; use volatile result
       semantics through Tcl_SetResult's TCL_VOLATILE sentinel (1). */
    g.setResult(ip,(char *)result.c_str(),(void (*)(char *))1);
    return rc;
}

RexxRoutine2(logical_t, AlchemyTclProjectRetained,
             CSTRING, commandName, CSTRING, token)
{
    (void)context;
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return 0;

    uint64_t id=0, generation=0;
    if (!parse_token(token,id,generation)) return 0;
    {
        std::lock_guard<std::mutex> rlock(g_retained_mutex);
        auto it=g_retained.find(id);
        if (it == g_retained.end() || it->second.generation != generation) return 0;
    }

    std::string name=commandName ? commandName : "";
    if (name.empty()) return 0;
    auto *p=new TclProjection{name,token,ProjectionState::LIVE,0,false};
    if (!g.createCommand(g.ip,name.c_str(),projectionCallback,p,projectionDelete)) {
        delete p;
        return 0;
    }
    {
        std::lock_guard<std::mutex> plock(g_projection_mutex);
        g_projections[name]=p;
    }
    return 1;
}

RexxRoutine1(logical_t, AlchemyTclDeleteProjection, CSTRING, commandName)
{
    (void)context;
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return 0;
    return g.deleteCommand(g.ip,commandName) == 0 ? 1 : 0;
}

RexxRoutine1(RexxStringObject, AlchemyTclEvalProjected, CSTRING, script)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("ALCHEMY_TCL_RUNTIME_UNAVAILABLE");
    RexxCallContext *prior=g_active_rexx_context;
    g_active_rexx_context=context;
    int rc=g.eval(g.ip,script);
    std::string result=g.result(g.ip) ? g.result(g.ip) : "";
    g_active_rexx_context=prior;
    if (rc != TCL_OK) result="TCL_ERROR:"+result;
    return context->NewStringFromAsciiz(result.c_str());
}

RexxRoutine1(RexxStringObject, AlchemyTclProjectionState, CSTRING, commandName)
{
    std::string name=commandName ? commandName : "";
    std::lock_guard<std::mutex> lock(g_projection_mutex);
    auto it=g_projections.find(name);
    if (it == g_projections.end()) return context->NewStringFromAsciiz("ABSENT");
    const char *v="UNKNOWN";
    switch(it->second->state) {
      case ProjectionState::LIVE:v="LIVE";break;
      case ProjectionState::REVOKING:v="REVOKING";break;
      case ProjectionState::REVOKED:v="REVOKED";break;
      case ProjectionState::RELEASED:v="RELEASED";break;
    }
    return context->NewStringFromAsciiz(v);
}


/* dev8 structured Tcl completion record.
 * Netstring-like fields avoid ambiguity from Tcl messages containing newlines,
 * braces or separators:
 *   rc=<n>;result=<len>:...;errorCode=<len>:...;errorInfo=<len>:...
 * errorCode/errorInfo are captured immediately after Tcl_Eval, before another
 * Tcl operation can overwrite interpreter error state.
 */
static void appendField(std::string &out, const char *name, const std::string &value)
{
    out += name;
    out += "=";
    out += std::to_string(value.size());
    out += ":";
    out += value;
    out += ";";
}

RexxRoutine1(RexxStringObject, AlchemyTclEvalDetailed, CSTRING, script)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz(
        "rc=1;result=31:ALCHEMY_TCL_RUNTIME_UNAVAILABLE;errorCode=0:;errorInfo=0:;");

    RexxCallContext *prior=g_active_rexx_context;
    g_active_rexx_context=context;
    int rc=g.eval(g.ip,script);
    std::string result=g.result(g.ip) ? g.result(g.ip) : "";
    std::string errorCode, errorInfo;
    if (rc != TCL_OK) {
        const char *ec=g.getVar(g.ip,"errorCode",1 /* TCL_GLOBAL_ONLY */);
        const char *ei=g.getVar(g.ip,"errorInfo",1 /* TCL_GLOBAL_ONLY */);
        if (ec) errorCode=ec;
        if (ei) errorInfo=ei;
    }
    g_active_rexx_context=prior;

    std::string record="rc="+std::to_string(rc)+";";
    appendField(record,"result",result);
    appendField(record,"errorCode",errorCode);
    appendField(record,"errorInfo",errorInfo);
    return context->NewString(record.c_str(),record.size());
}

/* dev9: TclOO-authoritative object seam. TclOO instances remain Tcl commands;
 * Rexx never fabricates a parallel class hierarchy.  The one-argument call is
 * deliberately bounded here; the general Tcl_Obj value codec follows later. */
RexxRoutine1(RexxStringObject, AlchemyTclOoExists, CSTRING, objectName)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("0");
    std::string q="info object isa object {"; q += objectName ? objectName : ""; q += "}";
    int rc=g.eval(g.ip,q.c_str());
    if (rc != TCL_OK) return context->NewStringFromAsciiz("0");
    return context->NewStringFromAsciiz(g.result(g.ip));
}

RexxRoutine1(RexxStringObject, AlchemyTclOoClass, CSTRING, objectName)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("TCL_ERROR:ALCHEMY_TCL_RUNTIME_UNAVAILABLE");
    std::string q="info object class {"; q += objectName ? objectName : ""; q += "}";
    int rc=g.eval(g.ip,q.c_str()); std::string out=g.result(g.ip) ? g.result(g.ip) : "";
    if (rc != TCL_OK) out="TCL_ERROR:"+out;
    return context->NewString(out.c_str(),out.size());
}

RexxRoutine3(RexxStringObject, AlchemyTclOoCall1,
             CSTRING, objectName, CSTRING, methodName, CSTRING, argument)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("TCL_ERROR:ALCHEMY_TCL_RUNTIME_UNAVAILABLE");
    /* Build a Tcl list using [list] around brace-quoted bounded strings. */
    std::string q="uplevel #0 [list {"; q += objectName ? objectName : "";
    q += "} {"; q += methodName ? methodName : ""; q += "} {";
    q += argument ? argument : ""; q += "}]";
    RexxCallContext *prior=g_active_rexx_context; g_active_rexx_context=context;
    int rc=g.eval(g.ip,q.c_str()); std::string out=g.result(g.ip) ? g.result(g.ip) : "";
    g_active_rexx_context=prior;
    if (rc != TCL_OK) out="TCL_ERROR:"+out;
    return context->NewString(out.c_str(),out.size());
}


/* dev10: Tcl_Obj vector dispatch.
 *
 * No Tcl script is assembled. Each command/method/argument becomes its own
 * Tcl_Obj and Tcl_EvalObjv performs Tcl's command dispatch directly. This
 * preserves arbitrary string values (spaces, braces, semicolons, newlines,
 * substitutions) as values rather than re-parsing them as script.
 *
 * Tcl_NewStringObj returns refcount-zero temporaries. They remain valid for
 * this synchronous Tcl_EvalObjv call; this routine does not retain them.
 */
static RexxStringObject evalObjvStrings(RexxCallContext *context,
                                        const char *const *parts, int count)
{
    Tcl_Obj *objv[8];
    if (count < 1 || count > 8)
        return context->NewStringFromAsciiz("TCL_ERROR:ARGUMENT_VECTOR_RANGE");
    for (int i=0;i<count;++i) {
        const char *v=parts[i] ? parts[i] : "";
        objv[i]=g.newStringObj(v,(int)std::strlen(v));
        if (!objv[i]) return context->NewStringFromAsciiz("TCL_ERROR:TCL_OBJ_ALLOCATION");
    }
    RexxCallContext *prior=g_active_rexx_context;
    g_active_rexx_context=context;
    int rc=g.evalObjv(g.ip,count,objv,0);
    Tcl_Obj *answer=g.getObjResult(g.ip);
    int n=0; const char *bytes=answer ? g.getStringFromObj(answer,&n) : "";
    std::string out(bytes ? bytes : "", n >= 0 ? (size_t)n : 0);
    g_active_rexx_context=prior;
    if (rc != TCL_OK) out="TCL_ERROR:"+out;
    return context->NewString(out.data(),out.size());
}

RexxRoutine2(RexxStringObject, AlchemyTclCommandObj1,
             CSTRING, commandName, CSTRING, argument)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("TCL_ERROR:ALCHEMY_TCL_RUNTIME_UNAVAILABLE");
    const char *v[]={commandName,argument};
    return evalObjvStrings(context,v,2);
}

RexxRoutine3(RexxStringObject, AlchemyTclOoCallObj1,
             CSTRING, objectName, CSTRING, methodName, CSTRING, argument)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("TCL_ERROR:ALCHEMY_TCL_RUNTIME_UNAVAILABLE");
    const char *v[]={objectName,methodName,argument};
    return evalObjvStrings(context,v,3);
}

RexxRoutine0(RexxStringObject, AlchemyTclProvider)
{
    std::lock_guard<std::recursive_mutex> guard(g.lock);
    if (!g.load()) return context->NewStringFromAsciiz("UNAVAILABLE");
    return context->NewStringFromAsciiz(g.provider.c_str());
}

static RexxRoutineEntry routines[] = {
    REXX_TYPED_ROUTINE(AlchemyTclEval, AlchemyTclEval),
    REXX_TYPED_ROUTINE(AlchemyTclRoundTrip, AlchemyTclRoundTrip),
    REXX_TYPED_ROUTINE(AlchemyTclPersistentRoundTrip, AlchemyTclPersistentRoundTrip),
    REXX_TYPED_ROUTINE(AlchemyTclRetainRexx, AlchemyTclRetainRexx),
    REXX_TYPED_ROUTINE(AlchemyTclInvokeRetained, AlchemyTclInvokeRetained),
    REXX_TYPED_ROUTINE(AlchemyTclReleaseRetained, AlchemyTclReleaseRetained),
    REXX_TYPED_ROUTINE(AlchemyTclEvalRetained, AlchemyTclEvalRetained),
    REXX_TYPED_ROUTINE(AlchemyTclProjectRetained, AlchemyTclProjectRetained),
    REXX_TYPED_ROUTINE(AlchemyTclDeleteProjection, AlchemyTclDeleteProjection),
    REXX_TYPED_ROUTINE(AlchemyTclEvalProjected, AlchemyTclEvalProjected),
    REXX_TYPED_ROUTINE(AlchemyTclProjectionState, AlchemyTclProjectionState),
    REXX_TYPED_ROUTINE(AlchemyTclEvalDetailed, AlchemyTclEvalDetailed),
    REXX_TYPED_ROUTINE(AlchemyTclOoExists, AlchemyTclOoExists),
    REXX_TYPED_ROUTINE(AlchemyTclOoClass, AlchemyTclOoClass),
    REXX_TYPED_ROUTINE(AlchemyTclOoCall1, AlchemyTclOoCall1),
    REXX_TYPED_ROUTINE(AlchemyTclCommandObj1, AlchemyTclCommandObj1),
    REXX_TYPED_ROUTINE(AlchemyTclOoCallObj1, AlchemyTclOoCallObj1),
    REXX_TYPED_ROUTINE(AlchemyTclProvider, AlchemyTclProvider),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry alchemy_tcl_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "AlchemyTcl",
    "0.1-dev10",
    NULL, NULL, routines, NULL
};
OOREXX_GET_PACKAGE(alchemy_tcl);
