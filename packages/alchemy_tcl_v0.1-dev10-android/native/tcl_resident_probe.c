/*
 * Alchemy Tcl v0.1-dev1 resident Tcl probe.
 *
 * Uses dlopen/dlsym so the qualification probe does not require Tcl headers.
 * This is NOT the final ooRexx native package; it proves the resident Tcl
 * runtime/lifecycle and live command mutation seam without subprocess RPC.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Tcl_Interp Tcl_Interp;
typedef Tcl_Interp *(*p_Tcl_CreateInterp)(void);
typedef void (*p_Tcl_DeleteInterp)(Tcl_Interp *);
typedef int (*p_Tcl_Init)(Tcl_Interp *);
typedef int (*p_Tcl_Eval)(Tcl_Interp *, const char *);
typedef const char *(*p_Tcl_GetStringResult)(Tcl_Interp *);

enum { TCL_OK = 0, TCL_ERROR = 1 };

static void *sym(void *h, const char *name) {
    void *p = dlsym(h, name);
    if (!p) {
        fprintf(stderr, "missing Tcl symbol %s: %s\n", name, dlerror());
        exit(3);
    }
    return p;
}

static int expect_eval(p_Tcl_Eval eval, p_Tcl_GetStringResult result,
                       Tcl_Interp *ip, const char *script,
                       int expected_rc, const char *expected) {
    int rc = eval(ip, script);
    const char *got = result(ip);
    if (rc != expected_rc) {
        fprintf(stderr, "FAIL rc script=%s expected=%d got=%d result=%s\n",
                script, expected_rc, rc, got ? got : "");
        return 0;
    }
    if (expected && strcmp(got ? got : "", expected) != 0) {
        fprintf(stderr, "FAIL result script=%s expected=%s got=%s\n",
                script, expected, got ? got : "");
        return 0;
    }
    return 1;
}

int main(void) {
    const char *libs[] = {
        "libtcl8.7.so", "libtcl8.6.so", "libtcl.so", NULL
    };
    void *h = NULL;
    const char *chosen = NULL;
    for (int i = 0; libs[i]; ++i) {
        h = dlopen(libs[i], RTLD_NOW | RTLD_LOCAL);
        if (h) { chosen = libs[i]; break; }
    }
    if (!h) {
        fprintf(stderr, "SKIP no supported Tcl shared library found\n");
        return 77;
    }

    p_Tcl_CreateInterp createInterp = (p_Tcl_CreateInterp)sym(h, "Tcl_CreateInterp");
    p_Tcl_DeleteInterp deleteInterp = (p_Tcl_DeleteInterp)sym(h, "Tcl_DeleteInterp");
    p_Tcl_Init init = (p_Tcl_Init)sym(h, "Tcl_Init");
    p_Tcl_Eval eval = (p_Tcl_Eval)sym(h, "Tcl_Eval");
    p_Tcl_GetStringResult result = (p_Tcl_GetStringResult)sym(h, "Tcl_GetStringResult");

    Tcl_Interp *ip = createInterp();
    if (!ip) {
        fprintf(stderr, "FAIL Tcl_CreateInterp\n");
        dlclose(h);
        return 2;
    }
    if (init(ip) != TCL_OK) {
        fprintf(stderr, "FAIL Tcl_Init: %s\n", result(ip));
        deleteInterp(ip);
        dlclose(h);
        return 2;
    }

    int ok = 1;
    ok &= expect_eval(eval, result, ip, "set ::alchemy_counter 41", TCL_OK, "41");
    ok &= expect_eval(eval, result, ip, "incr ::alchemy_counter", TCL_OK, "42");
    ok &= expect_eval(eval, result, ip,
        "proc ::alchemy::live {x} {expr {$x + $::alchemy_counter}}",
        TCL_ERROR, NULL); /* namespace does not yet exist: prove real Tcl error */
    ok &= expect_eval(eval, result, ip, "namespace eval ::alchemy {}", TCL_OK, "");
    ok &= expect_eval(eval, result, ip,
        "proc ::alchemy::live {x} {expr {$x + $::alchemy_counter}}", TCL_OK, "");
    ok &= expect_eval(eval, result, ip, "::alchemy::live 8", TCL_OK, "50");
    ok &= expect_eval(eval, result, ip,
        "rename ::alchemy::live ::alchemy::renamed", TCL_OK, "");
    ok &= expect_eval(eval, result, ip, "::alchemy::live 8", TCL_ERROR, NULL);
    ok &= expect_eval(eval, result, ip, "::alchemy::renamed 8", TCL_OK, "50");

    deleteInterp(ip);
    dlclose(h);

    if (!ok) return 1;
    printf("PASS resident Tcl interpreter; persistent state; TCL_ERROR; live rename; clean destroy; library=%s\n",
           chosen);
    return 0;
}
